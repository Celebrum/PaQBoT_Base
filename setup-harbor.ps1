# Create required directories
$harborPaths = @(
    "C:\data\harbor\core",
    "C:\data\harbor\database",
    "C:\data\harbor\registry",
    "C:\data\harbor\redis",
    "C:\data\harbor\clair",
    ".\certs"
)

foreach ($path in $harborPaths) {
    if (!(Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force
        Write-Host "Created directory: $path"
    }
}

# Create docker networks if they don't exist
docker network create harbor-net --driver bridge 2>$null
docker network create paqbot_network --driver bridge 2>$null

Write-Host "Setup completed. You can now run 'docker-compose up -d'"