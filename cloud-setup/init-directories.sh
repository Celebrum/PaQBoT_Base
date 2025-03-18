#!/bin/bash

# Create directories
mkdir -p /data/harbor/core
mkdir -p /data/harbor/database
mkdir -p /data/harbor/registry
mkdir -p /data/harbor/redis
mkdir -p ./certs

# Set permissions
chown -R 10000:10000 /data/harbor
chmod -R 755 /data/harbor
chown -R 10000:10000 ./certs
chmod -R 755 ./certs
