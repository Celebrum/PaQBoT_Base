#!/bin/bash

# Update system
sudo yum update -y

# Install Docker
sudo yum install -y docker-engine

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
sudo usermod -aG docker $USER

# Install kubectl
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

sudo yum install -y kubectl

# Install minikube for local kubernetes
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Install ODBC dependencies
echo "Configuring ODBC drivers..."
cat > /etc/odbcinst.ini << EOL
[ODBC Driver 17 for SQL Server]
Description=Microsoft ODBC Driver 17 for SQL Server
Driver=/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so.1.1
UsageCount=1
EOL

# Create system DSN configuration
cat > /etc/odbc.ini << EOL
[HARBOR_DB]
Driver=ODBC Driver 17 for SQL Server
Server=harbor-db
Port=5432
Database=harbor_db
EOL

# Set required environment variables
echo "export ODBCSYSINI=/etc" >> /etc/profile.d/harbor-env.sh
echo "export ODBCINI=/etc/odbc.ini" >> /etc/profile.d/harbor-env.sh

# Install Docker buildx dependencies
echo "Configuring Docker buildx..."
mkdir -p /etc/buildkit
cat > /etc/buildkit/buildkitd.toml << EOL
[worker.oci]
  enabled = true
  platforms = ["linux/amd64", "linux/arm64"]

[worker.containerd]
  enabled = true
  platforms = ["linux/amd64", "linux/arm64"]

[[worker.oci.gcpolicy]]
  keepDuration = "48h"
  keepBytes = 10000000000
EOL

# Remove existing buildx builders
echo "Removing existing buildx builders..."
docker buildx rm -f harbor-builder || true
docker buildx rm -f default || true

# Create the new builder using the specific moby/buildkit version
echo "Creating new buildx builder..."
docker buildx create --name harbor-builder \
  --driver-opt network=host \
  --driver docker-container \
  --buildkitd-flags '--allow-insecure-entitlement security.insecure' \
  --use \
  --platform=linux/amd64,linux/arm64 \
  --config /etc/buildkit/buildkitd.toml \
  moby/buildkit:buildx-stable-1

# Configure buildkit
mkdir -p /etc/buildkit
cat > /etc/buildkit/buildkitd.toml << EOL
debug = true
[registry."docker.io"]
  mirrors = ["harbor.local:443"]

[registry."harbor.local:443"]
  http = true
  insecure = true

[worker.oci]
  enabled = true
  platforms = ["linux/amd64", "linux/arm64"]
  gc = true
  gckeepstorage = 20000

[worker.containerd]
  enabled = true
  platforms = ["linux/amd64", "linux/arm64"]

[[worker.oci.gcpolicy]]
  keepDuration = "48h"
  keepBytes = 10000000000

[grpc]
  address = ["tcp://0.0.0.0:1234"]
EOL

# Configure Docker daemon for Harbor
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOL
{
    "insecure-registries": [
        "harbor.local:443",
        "hubproxy.docker.internal:5555",
        "::1/128",
        "127.0.0.0/8"
    ],
    "experimental": true,
    "features": {
        "buildkit": true
    },
    "builder": {
        "gc": {
            "enabled": true,
            "defaultKeepStorage": "20GB"
        }
    },
    "default-runtime": "runc",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "buildkit": {
        "builder": "harbor-builder"
    }
}
EOL

# Create necessary directories for Harbor
mkdir -p /data/harbor/{core,database,registry,redis}
mkdir -p /data/harpoon
chmod -R 755 /data/harbor
chmod 700 /data/harbor/database
chmod -R 755 /data/harpoon

# Set up environment variables
cat > /etc/profile.d/docker-env.sh << EOL
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export BUILDKIT_PROGRESS=plain
export DOCKER_HOST=unix:///var/run/docker.sock
export BUILDX_CONFIG=/etc/buildkit/buildkitd.toml
export BUILDX_BUILDER=harbor-builder
EOL

# Source the new environment
source /etc/profile.d/docker-env.sh

echo "BuildKit configuration complete!"
echo "Dependencies installation complete!"
