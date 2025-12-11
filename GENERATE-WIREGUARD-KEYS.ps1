#!/usr/bin/env powershell
<#
.SYNOPSIS
    WireGuard Key Generation and Management Utility

.DESCRIPTION
    Generates WireGuard keypairs, creates client configurations, and generates QR codes
    for distribution to mobile and desktop clients. Manages existing keys on TrueNAS.

.PARAMETER ServerIP
    TrueNAS server IP (default: 10.0.0.89)

.PARAMETER ServerUser
    SSH username for TrueNAS (default: root)

.PARAMETER SSHKeyPath
    Path to SSH private key (default: $HOME\.ssh\truenas_admin_10_0_0_89)

.PARAMETER Operation
    Operation to perform: "generate-keypair", "generate-client", "list-clients", "add-peer", "remove-peer"
    (default: "generate-client")

.PARAMETER ClientName
    Name of client to generate (e.g., "windows", "mac1", "iphone")

.PARAMETER ClientIP
    VPN IP address for client (e.g., "10.99.0.4")

.PARAMETER DeviceType
    Device type: desktop, mac, iphone, android (for identification)

.PARAMETER AllClients
    Generate configs for all predefined clients

.PARAMETER QRCode
    Generate QR code for specified client

.EXAMPLE
    .\GENERATE-WIREGUARD-KEYS.ps1 -Operation generate-client -ClientName windows -ClientIP 10.99.0.4
    # Generate client keypair and configuration for Windows

.EXAMPLE
    .\GENERATE-WIREGUARD-KEYS.ps1 -Operation list-clients
    # List all existing clients on server

.EXAMPLE
    .\GENERATE-WIREGUARD-KEYS.ps1 -Operation add-peer -ClientName mobile -ClientIP 10.99.0.10
    # Add new peer to server configuration

.NOTES
    Requires: SSH client, WireGuard tools on TrueNAS
    Dependencies: qrencode (for QR code generation)
#>

param(
    [string]$ServerIP = "10.0.0.89",
    [string]$ServerUser = "root",
    [string]$SSHKeyPath = "$HOME\.ssh\truenas_admin_10_0_0_89",
    [ValidateSet("generate-keypair", "generate-client", "list-clients", "add-peer", "remove-peer", "show-pubkeys")]
    [string]$Operation = "generate-client",
    [string]$ClientName = "",
    [string]$ClientIP = "",
    [string]$DeviceType = "desktop",
    [switch]$AllClients,
    [switch]$QRCode
)

# Configuration
$WireGuardDir = "/etc/wireguard"
$ConfigsRemotePath = "/mnt/tank/wireguard-configs"
$ServerPublicKey = "apOX664DHGsPXIAhqjYk1SwzpY9cqeF5uvvC3giaX14="
$ServerEndpoint = "73.140.158.252:51820"
$VPNNetwork = "10.99.0.0/24"
$HomeNetwork = "10.0.0.0/24"

# Predefined clients
$PredefinedClients = @{
    "windows"   = @{ IP = "10.99.0.4";  Type = "desktop"; Desc = "Windows PC" }
    "mac1"      = @{ IP = "10.99.0.2";  Type = "mac";     Desc = "Mac 1" }
    "mac2"      = @{ IP = "10.99.0.3";  Type = "mac";     Desc = "Mac 2" }
    "laptop1"   = @{ IP = "10.99.0.5";  Type = "desktop"; Desc = "Laptop 1" }
    "laptop2"   = @{ IP = "10.99.0.6";  Type = "desktop"; Desc = "Laptop 2" }
    "laptop3"   = @{ IP = "10.99.0.7";  Type = "desktop"; Desc = "Laptop 3" }
    "iphone"    = @{ IP = "10.99.0.8";  Type = "ios";     Desc = "iPhone" }
    "android"   = @{ IP = "10.99.0.9";  Type = "android"; Desc = "Android Phone" }
    "tablet1"   = @{ IP = "10.99.0.10"; Type = "android"; Desc = "Tablet 1" }
    "tablet2"   = @{ IP = "10.99.0.11"; Type = "android"; Desc = "Tablet 2" }
}

# Colors for output
$Colors = @{
    Success = "Green"
    Error   = "Red"
    Warning = "Yellow"
    Info    = "Cyan"
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "[✓] $Text" -ForegroundColor Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "[✗] $Text" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Text)
    Write-Host "[!] $Text" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Text)
    Write-Host "[→] $Text" -ForegroundColor Cyan
}

# Execute SSH command on TrueNAS
function Invoke-SSHCommand {
    param(
        [string]$Command,
        [switch]$Quiet
    )

    try {
        $sshPath = if (Get-Command ssh -ErrorAction SilentlyContinue) { "ssh" } else { "C:\Windows\System32\OpenSSH\ssh.exe" }

        if (-not (Test-Path $sshPath) -and $sshPath -like "C:\Windows\*") {
            Write-Error "SSH client not found. Please install OpenSSH."
            return $false
        }

        # Execute command via SSH
        $result = & $sshPath -i $SSHKeyPath `
                             -o StrictHostKeyChecking=accept-new `
                             -o ConnectTimeout=10 `
                             "$ServerUser@$ServerIP" `
                             $Command 2>&1

        if ($LASTEXITCODE -eq 0) {
            if (-not $Quiet) {
                return $result
            }
            return $true
        }
        else {
            Write-Error "SSH command failed: $result"
            return $false
        }
    }
    catch {
        Write-Error "SSH execution error: $_"
        return $false
    }
}

# Check SSH connectivity
function Test-SSHConnectivity {
    Write-Info "Testing SSH connectivity to $ServerIP..."

    try {
        $result = Invoke-SSHCommand -Command "whoami" -Quiet
        if ($result) {
            Write-Success "SSH connection successful"
            return $true
        }
        else {
            Write-Error "SSH connection failed"
            return $false
        }
    }
    catch {
        Write-Error "SSH connectivity test failed: $_"
        return $false
    }
}

# Generate keypair on TrueNAS
function New-WireGuardKeypair {
    param(
        [string]$ClientName,
        [string]$ClientIP
    )

    Write-Header "Generating WireGuard Keypair"
    Write-Info "Client: $ClientName"
    Write-Info "VPN IP: $ClientIP"

    # Generate private key
    Write-Info "Generating private key..."
    $privateKeyCmd = "wg genkey | tee /tmp/${ClientName}_private.key"
    $privateKey = Invoke-SSHCommand -Command $privateKeyCmd -Quiet

    if (-not $privateKey) {
        Write-Error "Failed to generate private key"
        return $false
    }

    # Generate public key from private key
    Write-Info "Generating public key..."
    $publicKeyCmd = "cat /tmp/${ClientName}_private.key | wg pubkey > /tmp/${ClientName}_public.key && cat /tmp/${ClientName}_public.key"
    $publicKey = Invoke-SSHCommand -Command $publicKeyCmd -Quiet

    if (-not $publicKey) {
        Write-Error "Failed to generate public key"
        return $false
    }

    Write-Success "Keypair generated successfully"
    Write-Info ""
    Write-Info "Private Key: $privateKey"
    Write-Info "Public Key:  $publicKey"

    return @{
        PrivateKey = $privateKey
        PublicKey  = $publicKey
    }
}

# Create client configuration
function New-WireGuardClientConfig {
    param(
        [string]$ClientName,
        [string]$ClientIP,
        [string]$PrivateKey
    )

    Write-Info "Creating client configuration..."

    $config = @"
[Interface]
PrivateKey = $PrivateKey
Address = $ClientIP/24
DNS = $ServerEndpoint.Split(':')[0]

[Peer]
PublicKey = $ServerPublicKey
Endpoint = $ServerEndpoint
AllowedIPs = $HomeNetwork, $VPNNetwork
PersistentKeepalive = 25
"@

    return $config
}

# Generate QR code for client config
function New-WireGuardQRCode {
    param(
        [string]$ClientName,
        [string]$ConfigContent
    )

    Write-Info "Generating QR code for $ClientName..."

    # Create temporary config file
    $tempConfig = "$env:TEMP\${ClientName}_temp.conf"
    Set-Content -Path $tempConfig -Value $ConfigContent -Encoding UTF8

    # Check if qrencode is available on TrueNAS
    $checkCmd = "which qrencode"
    $hasQREncode = Invoke-SSHCommand -Command $checkCmd -Quiet

    if (-not $hasQREncode) {
        Write-Warning "qrencode not found on server. Installing..."
        $installCmd = "apt-get install -y qrencode"
        Invoke-SSHCommand -Command $installCmd | Out-Null
    }

    # Upload config and generate QR code via SSH
    Write-Info "Uploading config and generating QR code..."

    $qrCmd = @"
cat > /tmp/${ClientName}_qr.conf << 'EOF'
$ConfigContent
EOF
qrencode -o /mnt/tank/wireguard-configs/${ClientName}-qr.png -t png -s 10 < /tmp/${ClientName}_qr.conf
echo "QR code generated at /mnt/tank/wireguard-configs/${ClientName}-qr.png"
"@

    $result = Invoke-SSHCommand -Command $qrCmd -Quiet

    if ($result -and $result -like "*generated*") {
        Write-Success "QR code generated successfully"
        Write-Info "Location: /mnt/tank/wireguard-configs/${ClientName}-qr.png"
        return $true
    }
    else {
        Write-Warning "QR code generation may have failed"
        return $false
    }
}

# Operation: Generate client configuration
function Op-GenerateClient {
    param(
        [string]$ClientName,
        [string]$ClientIP
    )

    Write-Header "Generate WireGuard Client"

    if ([string]::IsNullOrEmpty($ClientName)) {
        Write-Error "ClientName is required"
        return $false
    }

    if ([string]::IsNullOrEmpty($ClientIP)) {
        Write-Error "ClientIP is required"
        return $false
    }

    # Generate keypair
    $keys = New-WireGuardKeypair -ClientName $ClientName -ClientIP $ClientIP
    if (-not $keys) {
        return $false
    }

    # Create client configuration
    $config = New-WireGuardClientConfig -ClientName $ClientName -ClientIP $ClientIP -PrivateKey $keys.PrivateKey

    # Save configuration locally
    $localPath = "$env:TEMP\${ClientName}.conf"
    Set-Content -Path $localPath -Value $config -Encoding UTF8
    Write-Success "Configuration saved to $localPath"

    # Copy to server
    Write-Info "Copying configuration to TrueNAS..."
    $copyCmd = @"
cat > $ConfigsRemotePath/${ClientName}.conf << 'EOF'
$config
EOF
chmod 600 $ConfigsRemotePath/${ClientName}.conf
"@

    if (Invoke-SSHCommand -Command $copyCmd -Quiet) {
        Write-Success "Configuration saved on server"
    }
    else {
        Write-Warning "Could not save configuration on server"
    }

    # Generate QR code
    if ($QRCode) {
        New-WireGuardQRCode -ClientName $ClientName -ConfigContent $config | Out-Null
    }

    Write-Info ""
    Write-Info "Client configuration created:"
    Write-Host "  Name: $ClientName" -ForegroundColor Green
    Write-Host "  VPN IP: $ClientIP" -ForegroundColor Green
    Write-Host "  Public Key: $($keys.PublicKey)" -ForegroundColor Green
    Write-Host "  Private Key: [hidden for security]" -ForegroundColor Yellow

    return $true
}

# Operation: Generate all predefined clients
function Op-GenerateAllClients {
    Write-Header "Generate All Predefined Clients"

    $successCount = 0
    $failureCount = 0

    foreach ($clientName in $PredefinedClients.Keys) {
        $clientInfo = $PredefinedClients[$clientName]
        Write-Info "Generating $($clientInfo.Desc) ($clientName)..."

        if (Op-GenerateClient -ClientName $clientName -ClientIP $clientInfo.IP) {
            $successCount++
        }
        else {
            $failureCount++
        }

        Write-Host ""
    }

    Write-Header "Batch Generation Summary"
    Write-Host "Successfully generated: $successCount clients" -ForegroundColor Green
    if ($failureCount -gt 0) {
        Write-Host "Failed: $failureCount clients" -ForegroundColor Red
    }
}

# Operation: List clients
function Op-ListClients {
    Write-Header "List WireGuard Clients"

    Write-Info "Retrieving client list from server..."

    $listCmd = @"
cd $ConfigsRemotePath
echo "Saved Client Configurations:"
ls -lh *.conf 2>/dev/null | awk '{print \$9, "("$5")"}' || echo "No configurations found"

echo ""
echo "Predefined Clients (for reference):"
echo "desktop:  windows, laptop1, laptop2, laptop3"
echo "mac:      mac1, mac2"
echo "ios:      iphone"
echo "android:  android, tablet1, tablet2"
"@

    Invoke-SSHCommand -Command $listCmd

    Write-Info ""
    Write-Info "To add a new client to server:"
    Write-Host "  .\GENERATE-WIREGUARD-KEYS.ps1 -Operation add-peer -ClientName NewClient -ClientIP 10.99.0.X" -ForegroundColor Gray
}

# Operation: Show public keys
function Op-ShowPublicKeys {
    Write-Header "WireGuard Public Keys"

    Write-Info "Retrieving public keys from server..."

    $keysCmd = @"
echo "Server Public Key:"
grep 'PrivateKey' $WireGuardDir/wg0.conf > /dev/null && wg show wg0 | grep 'public key' | awk '{print \$3}'

echo ""
echo "Client Public Keys (from configs):"
cd $ConfigsRemotePath
for file in *.conf; do
    echo "=== \$file ==="
    grep 'PrivateKey' \$file | head -1 | awk '{print \$3}' | wg pubkey
done
"@

    Invoke-SSHCommand -Command $keysCmd
}

# Operation: Add peer to server
function Op-AddPeer {
    param(
        [string]$ClientName,
        [string]$ClientIP
    )

    Write-Header "Add Peer to Server Configuration"

    if ([string]::IsNullOrEmpty($ClientName) -or [string]::IsNullOrEmpty($ClientIP)) {
        Write-Error "ClientName and ClientIP are required"
        return $false
    }

    # First, generate the client configuration
    Write-Info "Generating client keypair..."
    $keys = New-WireGuardKeypair -ClientName $ClientName -ClientIP $ClientIP
    if (-not $keys) {
        return $false
    }

    # Add to server configuration
    Write-Info "Adding peer to server configuration..."

    $peerConfig = @"
# Client: $ClientName ($ClientIP)
[Peer]
PublicKey = $($keys.PublicKey)
AllowedIPs = $ClientIP/32
"@

    $addCmd = @"
# Backup current config
cp $WireGuardDir/wg0.conf $WireGuardDir/wg0.conf.backup-$(date +%Y%m%d-%H%M%S)

# Add peer to config
cat >> $WireGuardDir/wg0.conf << 'EOF'

$peerConfig
EOF

# Reload WireGuard
systemctl restart wg-quick@wg0

echo "Peer added and WireGuard reloaded"
"@

    if (Invoke-SSHCommand -Command $addCmd -Quiet) {
        Write-Success "Peer added to server configuration"
        Write-Info "ClientName: $ClientName"
        Write-Info "VPN IP: $ClientIP"
        Write-Info "Public Key: $($keys.PublicKey)"

        # Create client config
        $config = New-WireGuardClientConfig -ClientName $ClientName -ClientIP $ClientIP -PrivateKey $keys.PrivateKey

        # Save client config on server
        $saveCmd = @"
cat > $ConfigsRemotePath/${ClientName}.conf << 'EOF'
$config
EOF
chmod 600 $ConfigsRemotePath/${ClientName}.conf
"@

        Invoke-SSHCommand -Command $saveCmd -Quiet | Out-Null

        Write-Success "Client configuration saved"
        return $true
    }
    else {
        Write-Error "Failed to add peer to server"
        return $false
    }
}

# Operation: Remove peer from server
function Op-RemovePeer {
    param(
        [string]$ClientName
    )

    Write-Header "Remove Peer from Server"

    if ([string]::IsNullOrEmpty($ClientName)) {
        Write-Error "ClientName is required"
        return $false
    }

    Write-Warning "This will remove $ClientName from the WireGuard server"
    Write-Host "Type 'yes' to confirm removal: " -ForegroundColor Yellow -NoNewLine
    $confirm = Read-Host

    if ($confirm -ne 'yes') {
        Write-Info "Removal cancelled"
        return $false
    }

    # Remove from server config
    $removeCmd = @"
# Backup current config
cp $WireGuardDir/wg0.conf $WireGuardDir/wg0.conf.backup-$(date +%Y%m%d-%H%M%S)

# Remove peer section (this is simplified - edit manually for exact control)
sed -i "/$ClientName/,/^$/d" $WireGuardDir/wg0.conf

# Reload WireGuard
systemctl restart wg-quick@wg0

echo "Peer removal completed"
"@

    if (Invoke-SSHCommand -Command $removeCmd -Quiet) {
        Write-Success "Peer removed from server"

        # Remove client config file
        $rmCmd = "rm -f $ConfigsRemotePath/${ClientName}.conf && echo 'Client config removed'"
        Invoke-SSHCommand -Command $rmCmd -Quiet | Out-Null

        Write-Info "Client configuration file removed"
        return $true
    }
    else {
        Write-Error "Failed to remove peer"
        return $false
    }
}

# Main execution
function Main {
    Write-Header "WireGuard Key Generation and Management"
    Write-Info "Server: $ServerIP"
    Write-Info "Operation: $Operation"

    # Verify SSH connectivity
    if (-not (Test-SSHConnectivity)) {
        Write-Error "Cannot connect to TrueNAS server"
        exit 1
    }

    # Execute operation
    switch ($Operation) {
        "generate-keypair" {
            if ([string]::IsNullOrEmpty($ClientName) -or [string]::IsNullOrEmpty($ClientIP)) {
                Write-Error "ClientName and ClientIP required for this operation"
                exit 1
            }
            New-WireGuardKeypair -ClientName $ClientName -ClientIP $ClientIP | Out-Null
        }

        "generate-client" {
            if ($AllClients) {
                Op-GenerateAllClients
            }
            else {
                if ([string]::IsNullOrEmpty($ClientName) -or [string]::IsNullOrEmpty($ClientIP)) {
                    Write-Error "ClientName and ClientIP required (or use -AllClients)"
                    exit 1
                }
                Op-GenerateClient -ClientName $ClientName -ClientIP $ClientIP
            }
        }

        "list-clients" {
            Op-ListClients
        }

        "show-pubkeys" {
            Op-ShowPublicKeys
        }

        "add-peer" {
            if ([string]::IsNullOrEmpty($ClientName) -or [string]::IsNullOrEmpty($ClientIP)) {
                Write-Error "ClientName and ClientIP required for this operation"
                exit 1
            }
            Op-AddPeer -ClientName $ClientName -ClientIP $ClientIP
        }

        "remove-peer" {
            if ([string]::IsNullOrEmpty($ClientName)) {
                Write-Error "ClientName required for this operation"
                exit 1
            }
            Op-RemovePeer -ClientName $ClientName
        }

        default {
            Write-Error "Unknown operation: $Operation"
            exit 1
        }
    }

    Write-Header "Operation Complete"
}

# Execute main function
Main
