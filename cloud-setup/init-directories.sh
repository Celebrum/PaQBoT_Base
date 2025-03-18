#!/bin/bash

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
