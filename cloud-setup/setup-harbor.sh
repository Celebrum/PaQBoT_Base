#!/bin/bash

# Make sure we're in the right directory
cd "$(dirname "$0")"

# Stop any running containers
echo "Cleaning up existing containers..."
docker-compose down 2>/dev/null || true

# Clean up existing directories
echo "Cleaning up directories..."
sudo rm -rf /data/harbor
sudo rm -rf ./certs

# Create directories
echo "Creating directories..."
sudo mkdir -p /data/harbor/{core,database,registry,redis}
sudo mkdir -p ./certs

# Set permissions (using current user)
echo "Setting permissions..."
CURRENT_USER=$(whoami)
CURRENT_GROUP=$(id -gn)
sudo chown -R $CURRENT_USER:$CURRENT_GROUP /data/harbor
sudo chmod -R 755 /data/harbor
sudo chmod 700 /data/harbor/database
sudo chown -R $CURRENT_USER:$CURRENT_GROUP ./certs
sudo chmod 755 ./certs

# Generate certificates
echo "Generating certificates..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout certs/harbor.key -out certs/harbor.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=harbor.local" \
    -addext "subjectAltName=DNS:harbor.local,DNS:localhost,IP:127.0.0.1"

# Set certificate permissions
chmod 644 certs/harbor.crt
chmod 600 certs/harbor.key

# Create docker-compose.yml
cat > docker-compose.yml << 'EOL'
services:
  harbor-core:
    image: goharbor/harbor-core:v2.10.0
    container_name: harbor-core
    restart: always
    networks:
      - harbor
    volumes:
      - /data/harbor/core:/data
      - ./certs:/certs:ro
      - ../harbor.yml:/etc/harbor/harbor.yml:ro
    depends_on:
      - harbor-db
      - redis
    environment:
      - CORE_SECRET=change-this-password
      - REGISTRY_URL=http://registry:5000
      - PORTAL_URL=http://portal:8080
      - TOKEN_SERVICE_URL=http://core:8080/service/token
      - HARBOR_ADMIN_PASSWORD=Harbor12345

  harbor-db:
    image: goharbor/harbor-db:v2.10.0
    container_name: harbor-db
    restart: always
    networks:
      - harbor
    volumes:
      - /data/harbor/database:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=root123

  registry:
    image: goharbor/registry-photon:v2.10.0
    container_name: registry
    restart: always
    networks:
      - harbor
    volumes:
      - /data/harbor/registry:/storage
      - ./certs:/certs:ro
    environment:
      - REGISTRY_HTTP_SECRET=change-this-secret
      - REGISTRY_STORAGE_DELETE_ENABLED=true

  redis:
    image: goharbor/redis-photon:v2.10.0
    container_name: redis
    restart: always
    networks:
      - harbor
    volumes:
      - /data/harbor/redis:/var/lib/redis

networks:
  harbor:
    driver: overlay
    attachable: true
EOL

# Pull images first to avoid timeout issues
echo "Pulling Docker images..."
docker-compose pull

# Start services
echo "Starting Harbor services..."
docker-compose up -d

echo "Setup complete! Waiting for services to be ready..."
echo "You can check the status with: docker-compose ps"