#!/bin/bash

# Make sure we're in the right directory
cd "$(dirname "$0")"

# Stop any running containers
echo "Stopping any running containers..."
sudo docker-compose down

# Clean up old directories
echo "Cleaning up old directories..."
sudo rm -rf /data/harbor
sudo rm -rf ./certs

# Create directories with proper ownership
echo "Creating directories..."
sudo mkdir -p /data/harbor/{core,database,registry,redis}
sudo mkdir -p ./certs

# Set correct ownership and permissions
echo "Setting permissions..."
sudo chown -R $USER:$USER /data/harbor
sudo chmod -R 755 /data/harbor
sudo chmod 700 /data/harbor/database
sudo chown -R $USER:$USER ./certs
sudo chmod -R 755 ./certs

# Generate certificates
echo "Generating certificates..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout certs/harbor.key -out certs/harbor.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=harbor.local" \
    -addext "subjectAltName=DNS:harbor.local,DNS:localhost,IP:127.0.0.1"

# Set certificate permissions
chmod 644 certs/harbor.crt
chmod 600 certs/harbor.key

# Export current user ID and group ID for docker-compose
export UID=$(id -u)
export GID=$(id -g)

echo "Starting Harbor services..."
docker-compose up -d

echo "Setup complete. Please wait a few moments for all services to start."
echo "You can check the status with: docker-compose ps"