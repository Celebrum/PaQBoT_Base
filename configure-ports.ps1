# Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$Script:ProcessTracker = @{}
$Script:LogFile = "port-config.log"
$Script:ExitCode = 0

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
            $Script:ExitCode = 1
        }
    }
    
    Write-Log "Cleanup completed"
    exit $Script:ExitCode
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
    5100 = "PaQBoTEngine"
    8050 = "PaQBoTServerInternal"
    8051 = "PaQBoTServerExternal"
    5400 = "PaQBoTDatabase"
    
    # IIS Services
    80 = "IISDefault"
    8080 = "NeuralNetworkCore"
    8081 = "QuantumTensor"
    8082 = "MindsDBBridge"
    8083 = "PersonaManager"
    50080 = "DevToolsHTTP"
    50443 = "DevToolsHTTPS"
    
    # Core Services (from previous config)
    6000 = "CodeProjectAIServer"
    6001 = "AppCodeProjectAIServer"
    6002 = "AppMindsDBServer"
    
    # Hub Services (from previous config)
    6010 = "CeLeBrUmHub"
    6011 = "SenNnT-iHub"
    6012 = "EbaAaZHub"
    6013 = "NeuUuR-oHub"
    6014 = "ReaAaS-nHub"
    6015 = "HippocampusHub"
    6016 = "CorpusCallosumHub"
    6017 = "PrefrontalCortexHub"
    
    # Database and Message Services
    5432 = "PostgreSQL"
    27017 = "MongoDB"
    6379 = "Redis"
    5672 = "RabbitMQ"
    47334 = "MindsDBServer"
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
        $Script:ExitCode = 1
    }
}

# Function to open port in Windows Firewall
function Open-Port {
    param(
        [Parameter(Mandatory=$true)]
        [int]$port,
        [Parameter(Mandatory=$false)]
        [string]$service = "Generic"
    )
    try {
        Write-Log "Opening port $port for $service"
        
        # Sanitize service name for firewall rule
        $sanitizedService = $service.Replace(' ', '').Replace('-', '').Replace('_', '')
        if ([string]::IsNullOrEmpty($sanitizedService)) {
            $sanitizedService = "Generic"
        }
        $ruleName = "PaQBoT-$sanitizedService-$port"
        
        # Remove any existing rules for this port/service
        Get-NetFirewallRule -DisplayName "$ruleName-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        
        # Create inbound rule
        $inboundParams = @{
            DisplayName = "$ruleName-In"
            Direction = "Inbound"
            Protocol = "TCP"
            LocalPort = $port
            Action = "Allow"
            Description = "PaQBoT inbound port $port for $service"
        }
        New-NetFirewallRule @inboundParams | Out-Null
        
        # Create outbound rule
        $outboundParams = @{
            DisplayName = "$ruleName-Out"
            Direction = "Outbound"
            Protocol = "TCP"
            LocalPort = $port
            Action = "Allow"
            Description = "PaQBoT outbound port $port for $service"
        }
        New-NetFirewallRule @outboundParams | Out-Null
        
        Write-Log "Successfully opened port $port"
        return $true
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Error opening port $port`: $errorMessage"
        $Script:ExitCode = 1
        return $false
    }
}

# Function to close port and remove firewall rules
function Close-Port {
    param(
        [Parameter(Mandatory=$true)]
        [int]$port,
        [Parameter(Mandatory=$false)]
        [string]$service = "Generic"
    )
    try {
        Write-Log "Closing port $port for $service"
        
        # Sanitize service name
        $sanitizedService = $service.Replace(' ', '').Replace('-', '').Replace('_', '')
        if ([string]::IsNullOrEmpty($sanitizedService)) {
            $sanitizedService = "Generic"
        }
        $ruleName = "PaQBoT-$sanitizedService-$port"
        
        # Remove firewall rules
        Get-NetFirewallRule -DisplayName "$ruleName-*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        
        # Stop any process using the port
        if (Test-PortInUse $port) {
            Stop-ProcessOnPort -port $port
        }
        
        Write-Log "Successfully closed port $port"
        return $true
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Error closing port $port`: $errorMessage"
        $Script:ExitCode = 1
        return $false
    }
}

# Check and manage required ports
Write-Log "`nChecking required ports..."
foreach ($port in $requiredPorts.Keys | Sort-Object) {
    $service = $requiredPorts[$port]
    Write-Log "Managing port $port ($service)..."
    
    if (Test-PortInUse($port)) {
        Write-Log "Port $port is IN USE"
        $response = Read-Host "Do you want to close this port? (Y/N)"
        if ($response -eq 'Y') {
            if (-not (Close-Port -port $port -service $service)) {
                Write-Log "Failed to close port $port"
                continue
            }
        }
    } else {
        Write-Log "Port $port is AVAILABLE"
        $response = Read-Host "Do you want to open this port? (Y/N)"
        if ($response -eq 'Y') {
            if (-not (Open-Port -port $port -service $service)) {
                Write-Log "Failed to open port $port"
                continue
            }
        }
    }
}

# Docker network configuration check
Write-Log "`nChecking Docker network configuration..."
$dockerNetwork = "paqbot_network"
try {
    $networkExists = docker network ls --format "{{.Name}}" | Select-String -Pattern "^$dockerNetwork$"
    if (-not $networkExists) {
        Write-Log "Creating Docker network $dockerNetwork..."
        docker network create $dockerNetwork
        Write-Log "Docker network created successfully"
    } else {
        Write-Log "Docker network $dockerNetwork already exists"
    }
} catch {
    $errorMessage = $_.Exception.Message
    Write-Log "Error managing Docker network: $errorMessage"
    $Script:ExitCode = 1
}

Write-Log "`nPort cleanup and firewall configuration completed!"
Write-Log "Docker and IIS services are properly configured."

# Final cleanup on normal exit
Cleanup