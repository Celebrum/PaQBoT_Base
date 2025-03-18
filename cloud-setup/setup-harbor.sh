#!/bin/bash

# Make sure we're in the right directory
cd "$(dirname "$0")"

# Stop any running containers
echo "Cleaning up existing containers..."
sudo docker-compose down

# Clean up existing directories
echo "Cleaning up directories..."
sudo rm -rf /data/harbor
sudo rm -rf ./certs

# Create directories
echo "Creating directories..."
sudo mkdir -p /data/harbor/{core,database,registry,redis}
sudo mkdir -p ./certs

# Set permissions (use actual user instead of UID)
echo "Setting permissions..."
sudo chown -R $(whoami):$(whoami) /data/harbor
sudo chmod -R 755 /data/harbor
sudo chmod 700 /data/harbor/database
sudo chown -R $(whoami):$(whoami) ./certs
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

# Pull images first to avoid timeout issues
echo "Pulling Docker images..."
sudo docker-compose pull

# Start services
echo "Starting Harbor services..."
sudo docker-compose up -d

echo "Setup complete! Waiting for services to be ready..."
echo "You can check the status with: docker-compose ps"