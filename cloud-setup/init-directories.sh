#!/bin/bash

# Create base directories
sudo mkdir -p /data/harbor/core
sudo mkdir -p /data/harbor/database
sudo mkdir -p /data/harbor/registry
sudo mkdir -p /data/harbor/redis
sudo mkdir -p ./certs

# Set permissions that allow docker containers to access
sudo chown -R 10000:10000 /data/harbor
sudo chmod -R 755 /data/harbor
sudo chmod 700 /data/harbor/database

# Make sure current user can write to certs
sudo chown -R $USER:$USER ./certs
sudo chmod -R 755 ./certs

echo "Directories created and permissions set successfully"#!/bin/bash

# Get current user and group IDs
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Create base directories with sudo
sudo mkdir -p /data/harbor/core
sudo mkdir -p /data/harbor/database
sudo mkdir -p /data/harbor/registry
sudo mkdir -p /data/harbor/redis
sudo mkdir -p ./certs

# Set ownership for all directories
sudo chown -R ${CURRENT_UID}:${CURRENT_GID} /data/harbor/
sudo chown -R ${CURRENT_UID}:${CURRENT_GID} ./certs

# Set proper permissions
sudo chmod -R 755 /data/harbor/core
sudo chmod -R 755 /data/harbor/registry
sudo chmod -R 755 /data/harbor/redis
sudo chmod 700 /data/harbor/database
sudo chmod 755 ./certs

# Export user and group IDs for docker-compose
export UID=${CURRENT_UID}
export GID=${CURRENT_GID}

echo "Directories created and permissions set successfully"
echo "UID=${CURRENT_UID}"
echo "GID=${CURRENT_GID}"#!/bin/bash

# Create base directories with sudo
sudo mkdir -p /data/harbor/core
sudo mkdir -p /data/harbor/database
sudo mkdir -p /data/harbor/registry
sudo mkdir -p /data/harbor/redis
sudo mkdir -p ./certs

# Set ownership and permissions
sudo chown -R 10000:10000 /data/harbor
sudo chmod -R 755 /data/harbor
sudo chmod 700 /data/harbor/database  # More restrictive for database

# Set current user as owner of certs directory
sudo chown -R $(id -u):$(id -g) ./certs
sudo chmod -R 755 ./certs

echo "Directories created and permissions set successfully"
