#!/bin/bash

# Create directories
mkdir -p certs
mkdir -p /data/harbor/{core,database,registry,redis}
mkdir -p /data/harpoon

# Set up permissions
chmod 700 /data/harbor/database
chmod -R 755 /data/harbor/{core,registry,redis}
chmod -R 755 /data/harpoon

# Check if certificates exist in Windows cert path
WINDOWS_CERT_PATH="/mnt/c/ProgramData/Microsoft/Crypto/RSA"
if [ -d "$WINDOWS_CERT_PATH" ]; then
    echo "Found Windows certificate store"
    # Import certificates if they exist
    if [ -f "$WINDOWS_CERT_PATH/harbor.crt" ] && [ -f "$WINDOWS_CERT_PATH/harbor.key" ]; then
        cp "$WINDOWS_CERT_PATH/harbor.crt" certs/
        cp "$WINDOWS_CERT_PATH/harbor.key" certs/
        echo "Imported Harbor certificates from Windows store"
    fi
    
    if [ -f "$WINDOWS_CERT_PATH/harpoon.crt" ] && [ -f "$WINDOWS_CERT_PATH/harpoon.key" ]; then
        cp "$WINDOWS_CERT_PATH/harpoon.crt" certs/
        cp "$WINDOWS_CERT_PATH/harpoon.key" certs/
        echo "Imported Harpoon certificates from Windows store"
    fi
fi

# Generate self-signed certificates if they don't exist
if [ ! -f "certs/harbor.crt" ] || [ ! -f "certs/harbor.key" ]; then
    echo "Generating self-signed certificates for Harbor..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout certs/harbor.key -out certs/harbor.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=harbor.local" \
        -addext "subjectAltName=DNS:harbor.local,DNS:localhost,IP:127.0.0.1"
    echo "Self-signed certificates generated for Harbor"
fi

# Set proper permissions for certificates
chmod 644 certs/*.crt
chmod 600 certs/*.key

echo "Certificate initialization complete"