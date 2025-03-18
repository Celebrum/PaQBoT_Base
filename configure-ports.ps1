# Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$Script:ProcessTracker = @{}
$Script:LogFile = "port-config.log"

# Enable logging
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Tee-Object -FilePath $Script:LogFile -Append
    Write-Host $Message
}

# Cleanup function for script termination
function Cleanup {
    Write-Log "Starting cleanup process..."
    
    foreach ($port in $Script:ProcessTracker.Keys) {
        try {
            $processId = $Script:ProcessTracker[$port]
            if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
                Write-Log "Cleaning up process on port $port (PID: $processId)"
                Stop-Process -Id $processId -Force
            }
        } catch {
            $errorMessage = $_.Exception.Message
            Write-Log "Error cleaning up port $port`: $errorMessage"
        }
    }
    
    Write-Log "Cleanup completed"
}

# Register cleanup on script exit
trap {
    Write-Log "Script interrupted"
    Cleanup
    exit 1
}

# Main script starts here
Write-Log "PaQBoT Port Cleanup and Firewall Configuration"
Write-Log "============================================="

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
    param(
        [Parameter(Mandatory=$true)]
        [int]$port
    )
    try {
        $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                      Where-Object LocalPort -eq $port
        return $null -ne $connections
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Error checking port $port`: $errorMessage"
        return $false
    }
}

# Function to gracefully stop process using a port
function Stop-ProcessOnPort {
    param($port)
    try {
        $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                      Where-Object LocalPort -eq $port
        
        foreach ($conn in $connections) {
            $process = Get-Process -Id $conn.OwningProcess
            Write-Log "Stopping process: $($process.ProcessName) (PID: $($process.Id)) on port $port"
            
            # Try graceful shutdown first
            $process.CloseMainWindow()
            Start-Sleep -Seconds 2
            
            if (!$process.HasExited) {
                Stop-Process -Id $process.Id -Force
            }
            
            # Remove from process tracker
            $Script:ProcessTracker.Remove($port)
        }
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Error stopping process on port $port`: $errorMessage"
    }
}

# Function to open port
function Open-Port {
    param(
        [Parameter(Mandatory=$true)]
        [int]$port,
        [Parameter(Mandatory=$false)]
        [string]$service = "Generic"
    )
    try {
        Write-Log "Opening port $port for $service..."
        
        # Sanitize service name for firewall rule
        $sanitizedService = $service.Replace(' ', '').Replace('-', '').Replace('_', '')
        if ([string]::IsNullOrEmpty($sanitizedService)) {
            $sanitizedService = "Generic"
        }
        $ruleName = "PaQBoT-$sanitizedService"
        
        # Check if rules already exist
        $existingRules = Get-NetFirewallRule -DisplayName "$ruleName-*" -ErrorAction SilentlyContinue
        if ($existingRules) {
            Write-Log "Removing existing rules for $ruleName"
            $existingRules | Remove-NetFirewallRule
        }
        
        # Create new firewall rules
        Write-Log "Creating inbound rule for port $port"
        $params = @{
            DisplayName = "$ruleName-In"
            Direction = "Inbound"
            Protocol = "TCP"
            LocalPort = $port
            Action = "Allow"
            Description = "PaQBoT inbound port $port for $service"
        }
        New-NetFirewallRule @params | Out-Null
        
        Write-Log "Creating outbound rule for port $port"
        $params.DisplayName = "$ruleName-Out"
        $params.Direction = "Outbound"
        New-NetFirewallRule @params | Out-Null
        
        Write-Log "Successfully opened port $port"
        return $true
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Error opening port $port`: $errorMessage"
        return $false
    }
}

# Function to close port
function Close-Port {
    param(
        [Parameter(Mandatory=$true)]
        [int]$port,
        [Parameter(Mandatory=$false)]
        [string]$service = "Generic"
    )
    try {
        Write-Log "Closing port $port for $service..."
        
        # Sanitize service name for firewall rule
        $sanitizedService = $service.Replace(' ', '').Replace('-', '').Replace('_', '')
        if ([string]::IsNullOrEmpty($sanitizedService)) {
            $sanitizedService = "Generic"
        }
        $ruleName = "PaQBoT-$sanitizedService"
        
        # Remove firewall rules
        $existingRules = Get-NetFirewallRule -DisplayName "$ruleName-*" -ErrorAction SilentlyContinue
        if ($existingRules) {
            Write-Log "Removing rules for $ruleName"
            $existingRules | Remove-NetFirewallRule
        }
        
        # Stop any process using the port
        if (Test-PortInUse $port) {
            Stop-ProcessOnPort -port $port
        }
        
        Write-Log "Successfully closed port $port"
        return $true
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Error closing port $port`: $errorMessage"
        return $false
    }
}

# Check and manage required ports
Write-Log "`nChecking required ports..."
foreach ($port in $requiredPorts.Keys) {
    $service = $requiredPorts[$port]
    Write-Log "Managing port $port ($service)..."
    
    if (Test-PortInUse($port)) {
        Write-Log "Port $port is IN USE"
        $response = Read-Host "Do you want to close this port? (Y/N)"
        if ($response -eq 'Y') {
            Close-Port($port, $service)
        }
    } else {
        Write-Log "Port $port is AVAILABLE"
        $response = Read-Host "Do you want to open this port? (Y/N)"
        if ($response -eq 'Y') {
            Open-Port($port, $service)
        }
    }
}

# Docker network configuration check
Write-Log "`nChecking Docker network configuration..."
$dockerNetwork = "paqbot_network"
try {
    docker network inspect $dockerNetwork 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Creating Docker network $dockerNetwork..."
        docker network create $dockerNetwork
        Write-Log "Docker network created successfully"
    } else {
        Write-Log "Docker network $dockerNetwork already exists"
    }
} catch {
    $errorMessage = $_.Exception.Message
    Write-Log "Error managing Docker network: $errorMessage"
}

Write-Log "`nPort cleanup and firewall configuration completed!"
Write-Log "Docker and IIS services are properly configured."

# Final cleanup on normal exit
Cleanup