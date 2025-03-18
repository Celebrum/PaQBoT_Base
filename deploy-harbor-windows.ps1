# Create Docker network
docker network create --driver bridge --subnet 172.20.0.0/16 harbor-net

# Configure Windows hosts file
Add-Content -Path $env:windir\System32\drivers\etc\hosts -Value "`n172.20.0.1 harbor.local" -Force

# Set IIS bindings to avoid port conflicts
Import-Module WebAdministration
Set-WebBinding -Name "Default Web Site" -BindingInformation "*:80:" -PropertyName "Port" -Value 81

# Create required directories
New-Item -Path "C:\data\harbor" -ItemType Directory -Force
New-Item -Path "C:\data\harbor\certs" -ItemType Directory -Force

# Generate self-signed certificate for internal use
$cert = New-SelfSignedCertificate -DnsName "harbor.local" -CertStoreLocation "Cert:\LocalMachine\My"
Export-PfxCertificate -Cert $cert -FilePath "C:\data\harbor\certs\harbor.pfx" -Password (ConvertTo-SecureString -String "Harbor12345" -Force -AsPlainText)

# Start Harbor
docker-compose up -d
