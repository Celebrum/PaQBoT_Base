# Requires -RunAsAdministrator

# Error handling
$ErrorActionPreference = "Stop"

function Write-Step {
    param($Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Wait-Script {
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

try 
{
    Write-Step "Starting Harbor Deployment"
    Wait-Script

    Write-Step "Creating Docker network"
    docker network create --driver bridge --subnet 172.20.0.0/16 harbor-net 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Network may already exist, continuing..." -ForegroundColor Yellow
    }

    Write-Step "Configuring hosts file"
    $hostEntries = @"
172.20.0.1 harbor.local
172.20.0.1 harbor-core.local
172.20.0.1 harbor-db.local
172.20.0.1 registry.local
172.20.0.1 redis.local
"@
    Add-Content -Path $env:windir\System32\drivers\etc\hosts -Value $hostEntries -Force

    Write-Step "Configuring IIS bindings"
    if (Get-Module -ListAvailable -Name WebAdministration) {
        Import-Module WebAdministration
        Set-WebBinding -Name "Default Web Site" -BindingInformation "*:80:" -PropertyName "Port" -Value 81
    } else {
        Write-Warning "WebAdministration module not found. Skipping IIS configuration."
    }

    Write-Step "Creating directories"
    $harborPaths = @(
        "C:\data\harbor",
        "C:\data\harbor\certs",
        "C:\data\harbor\core",
        "C:\data\harbor\database",
        "C:\data\harbor\registry",
        "C:\data\harbor\redis"
    )

    foreach ($path in $harborPaths) {
        Write-Host "Creating $path"
        New-Item -Path $path -ItemType Directory -Force
        $acl = Get-Acl $path
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($accessRule)
        Set-Acl $path $acl
    }

    Write-Step "Generating certificates"
    $certParams = @{
        DnsName = "harbor.local", "harbor-core.local", "harbor-db.local", "registry.local", "redis.local"
        CertStoreLocation = "Cert:\LocalMachine\My"
        KeyUsage = "DigitalSignature", "KeyEncipherment"
        KeyAlgorithm = "RSA"
        KeyLength = 2048
        HashAlgorithm = "SHA256"
        NotAfter = (Get-Date).AddYears(5)
    }
    $cert = New-SelfSignedCertificate @certParams

    $certPassword = ConvertTo-SecureString -String "Harbor12345" -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath "C:\data\harbor\certs\harbor.pfx" -Password $certPassword
    $cert | Export-Certificate -FilePath "C:\data\harbor\certs\harbor.crt" -Type CERT
    
    # Ensure certs directory exists in current location
    New-Item -Path ".\certs" -ItemType Directory -Force
    Copy-Item "C:\data\harbor\certs\harbor.pfx" ".\certs\harbor.pfx" -Force
    Copy-Item "C:\data\harbor\certs\harbor.crt" ".\certs\harbor.crt" -Force

    Write-Step "Importing certificates"
    Import-PfxCertificate -FilePath "C:\data\harbor\certs\harbor.pfx" -CertStoreLocation "Cert:\LocalMachine\Root" -Password $certPassword

    Write-Step "Starting Harbor services"
    Write-Host "Starting Docker Compose..."
    docker-compose up -d

    Write-Host "`nWaiting for services to start..." -ForegroundColor Yellow
    $counter = 30
    while ($counter -gt 0) {
        Write-Host -NoNewline "."
        Start-Sleep -Seconds 1
        $counter--
    }

    Write-Host @"
`n
Harbor has been deployed successfully!
Access the Harbor portal at:
- HTTP: http://harbor.local:8084
- HTTPS: https://harbor.local:8444

Default admin credentials:
Username: admin
Password: Harbor12345
"@ -ForegroundColor Green

} catch {
    Write-Host "`nError occurred: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
} finally {
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
