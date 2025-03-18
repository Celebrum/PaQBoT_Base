#!/bin/bash
set -e

# Install curl for healthcheck
apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Function to handle application shutdown
cleanup() {
    echo "Stopping application gracefully..."
    kill -TERM "$child"
    wait "$child"
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Start the Python application
python server.py &

# Store the PID
child=$!

# Wait for the process to finish
wait "$child"