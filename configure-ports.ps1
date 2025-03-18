# Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "PaQBoT Port Cleanup and Firewall Configuration" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Define required ports and their services
$requiredPorts = @{
    # Docker Services
    5100 = "PaQBoT Engine"
    8050 = "PaQBoT Server Internal"
    8051 = "PaQBoT Server External"
    5400 = "PaQBoT Database"
    
    # IIS Services
    80 = "IIS Default"
    8080 = "NeuralNetworkCore"
    8081 = "QuantumTensor"
    8082 = "MindsDBBridge"
    8083 = "PersonaManager"
    50080 = "DevTools HTTP"
    50443 = "DevTools HTTPS"
    
    # Core Services (from previous config)
    6000 = "CodeProject AI Server"
    6001 = "App CodeProject AI Server"
    6002 = "App MindsDB Server"
    
    # Hub Services (from previous config)
    6010 = "CeLeBrUm Hub"
    6011 = "SenNnT-i Hub"
    6012 = "EbaAaZ Hub"
    6013 = "NeuUuR-o Hub"
    6014 = "ReaAaS-n Hub"
    6015 = "Hippocampus Hub"
    6016 = "Corpus Callosum Hub"
    6017 = "Prefrontal Cortex Hub"
    
    # Database and Message Services
    5432 = "PostgreSQL"
    27017 = "MongoDB"
    6379 = "Redis"
    5672 = "RabbitMQ"
    47334 = "MindsDB Server"
}

# Function to check if a port is in use
function Test-PortInUse {
    param($port)
    
    $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                  Where-Object LocalPort -eq $port
    
    return $null -ne $connections
}

# Function to stop process using a port
function Stop-ProcessOnPort {
    param($port)
    
    $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                  Where-Object LocalPort -eq $port
    
    foreach ($conn in $connections) {
        $process = Get-Process -Id $conn.OwningProcess
        Write-Host "Stopping process: $($process.ProcessName) (PID: $($process.Id)) on port $port"
        Stop-Process -Id $process.Id -Force
    }
}

# Check and free required ports
Write-Host "`nChecking required ports..." -ForegroundColor Cyan
foreach ($port in $requiredPorts.Keys) {
    $service = $requiredPorts[$port]
    Write-Host "Checking port $port ($service)..." -NoNewline
    
    if (Test-PortInUse $port) {
        Write-Host " IN USE" -ForegroundColor Red
        $response = Read-Host "Do you want to free this port? (Y/N)"
        if ($response -eq 'Y') {
            Stop-ProcessOnPort $port
            Write-Host "Port $port has been freed" -ForegroundColor Green
        }
    } else {
        Write-Host " AVAILABLE" -ForegroundColor Green
    }
}

# Configure firewall rules
Write-Host "`nConfiguring firewall rules..." -ForegroundColor Cyan

# Remove existing PaQBoT rules
Get-NetFirewallRule -DisplayName "PaQBoT-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

# Create new firewall rules for each port
foreach ($port in $requiredPorts.Keys) {
    $service = $requiredPorts[$port]
    $ruleName = "PaQBoT-$($service.Replace(' ', ''))"
    
    # Inbound rule
    Write-Host "Creating inbound rule for $service (Port $port)..." -NoNewline
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow | Out-Null
    Write-Host " DONE" -ForegroundColor Green
    
    # Outbound rule
    Write-Host "Creating outbound rule for $service (Port $port)..." -NoNewline
    New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Protocol TCP -LocalPort $port -Action Allow | Out-Null
    Write-Host " DONE" -ForegroundColor Green
}

# Docker network configuration check
Write-Host "`nChecking Docker network configuration..." -ForegroundColor Cyan
$dockerNetwork = "paqbot_network"
docker network inspect $dockerNetwork 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating Docker network $dockerNetwork..." -NoNewline
    docker network create $dockerNetwork
    Write-Host " DONE" -ForegroundColor Green
} else {
    Write-Host "Docker network $dockerNetwork already exists" -ForegroundColor Green
}

Write-Host "`nPort cleanup and firewall configuration completed!" -ForegroundColor Green
Write-Host "Docker and IIS services are properly configured."