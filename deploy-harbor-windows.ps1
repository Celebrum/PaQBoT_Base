# Create Docker network with specific subnet for Harbor
docker network create --driver bridge --subnet 172.20.0.0/16 harbor-net

# Configure Windows hosts file for Harbor services
$hostEntries = @"
172.20.0.1 harbor.local
172.20.0.1 harbor-core.local
172.20.0.1 harbor-db.local
172.20.0.1 registry.local
172.20.0.1 redis.local
"@
Add-Content -Path $env:windir\System32\drivers\etc\hosts -Value $hostEntries -Force

# Set IIS bindings to avoid port conflicts
Import-Module WebAdministration
Set-WebBinding -Name "Default Web Site" -BindingInformation "*:80:" -PropertyName "Port" -Value 81

# Create required directories with proper permissions
$harborPaths = @(
    "C:\data\harbor",
    "C:\data\harbor\certs",
    "C:\data\harbor\core",
    "C:\data\harbor\database",
    "C:\data\harbor\registry",
    "C:\data\harbor\redis"
)

foreach ($path in $harborPaths) {
    New-Item -Path $path -ItemType Directory -Force
    $acl = Get-Acl $path
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl $path $acl
}

# Generate self-signed certificate for internal use
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

# Export certificates
$certPassword = ConvertTo-SecureString -String "Harbor12345" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath "C:\data\harbor\certs\harbor.pfx" -Password $certPassword
$cert | Export-Certificate -FilePath "C:\data\harbor\certs\harbor.crt" -Type CERT
Get-Content "C:\data\harbor\certs\harbor.pfx" | Set-Content ".\certs\harbor.pfx" -Force
Get-Content "C:\data\harbor\certs\harbor.crt" | Set-Content ".\certs\harbor.crt" -Force

# Import certificate to trusted root
Import-PfxCertificate -FilePath "C:\data\harbor\certs\harbor.pfx" -CertStoreLocation "Cert:\LocalMachine\Root" -Password $certPassword

# Start Harbor
Write-Host "Starting Harbor services..."
docker-compose up -d

# Wait for services to be ready
Start-Sleep -Seconds 30

Write-Host @"
Harbor has been deployed successfully!
Access the Harbor portal at:
- HTTP: http://harbor.local:8084
- HTTPS: https://harbor.local:8444

Default admin credentials:
Username: admin
Password: Harbor12345
"@
