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

# Set proper permissions for certificates
chmod 644 certs/*.crt
chmod 600 certs/*.key

echo "Certificate initialization complete"