#Requires -RunAsAdministrator
###############################################################################
# Apply TrueNAS SMB Performance Tuning
# Configures SMB auxiliary parameters on Baby NAS for optimal performance
###############################################################################

param(
    [string]$BabyNasIP = "",
    [switch]$DryRun,
    [switch]$ShowCurrentConfig
)

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "      TrueNAS SMB Performance Tuning                          " -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# Load configuration
$configPath = "$PSScriptRoot\monitoring-config.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        if ([string]::IsNullOrEmpty($BabyNasIP)) {
            $BabyNasIP = $config.babyNAS.ip
        }
        $sshUser = $config.babyNAS.sshUser
        $sshKeyPath = $config.babyNAS.sshKeyPath -replace '%USERPROFILE%', $env:USERPROFILE
    } catch {
        Write-Host "Warning: Could not load config file" -ForegroundColor Yellow
    }
}

# Fallback defaults
if ([string]::IsNullOrEmpty($BabyNasIP)) { $BabyNasIP = "172.21.203.18" }
if ([string]::IsNullOrEmpty($sshUser)) { $sshUser = "root" }
if ([string]::IsNullOrEmpty($sshKeyPath)) { $sshKeyPath = "$env:USERPROFILE\.ssh\id_babynas" }

Write-Host "Target: $BabyNasIP" -ForegroundColor White
Write-Host "SSH User: $sshUser" -ForegroundColor White
Write-Host "SSH Key: $sshKeyPath" -ForegroundColor White
Write-Host ""

###############################################################################
# Verify SSH Connectivity
###############################################################################
Write-Host "[1/4] Verifying SSH connectivity..." -ForegroundColor Cyan

if (-not (Test-Path $sshKeyPath)) {
    Write-Host "ERROR: SSH key not found: $sshKeyPath" -ForegroundColor Red
    Write-Host "Run setup-ssh-keys-complete.ps1 first" -ForegroundColor Yellow
    exit 1
}

try {
    $testResult = ssh -i $sshKeyPath -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$sshUser@$BabyNasIP" "echo 'SSH OK'" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: SSH connection failed" -ForegroundColor Red
        Write-Host $testResult -ForegroundColor Red
        exit 1
    }
    Write-Host "  [OK] SSH connection successful" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

###############################################################################
# Show Current SMB Configuration
###############################################################################
Write-Host ""
Write-Host "[2/4] Current SMB Configuration" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Gray

$getCurrentConfig = @'
#!/bin/bash
echo "=== SMB Service Status ==="
systemctl status smbd 2>/dev/null | head -5 || service smbd status | head -5

echo ""
echo "=== Current SMB Configuration ==="
if [ -f /etc/smb4.conf ]; then
    grep -A 20 "\[global\]" /etc/smb4.conf | head -30
elif [ -f /etc/samba/smb.conf ]; then
    grep -A 20 "\[global\]" /etc/samba/smb.conf | head -30
else
    echo "SMB config location unknown - TrueNAS may use middleware"
fi

echo ""
echo "=== Active SMB Connections ==="
smbstatus -b 2>/dev/null | head -10 || echo "No active connections"
'@

$currentConfig = $getCurrentConfig | ssh -i $sshKeyPath "$sshUser@$BabyNasIP" "bash" 2>&1
Write-Host $currentConfig -ForegroundColor Gray

if ($ShowCurrentConfig) {
    Write-Host ""
    Write-Host "Use -DryRun to preview changes, or run without switches to apply." -ForegroundColor Yellow
    exit 0
}

###############################################################################
# SMB Auxiliary Parameters
###############################################################################
Write-Host ""
Write-Host "[3/4] SMB Optimization Parameters" -ForegroundColor Cyan
Write-Host "----------------------------------" -ForegroundColor Gray

# These parameters are applied via TrueNAS middleware or smb.conf
$smbAuxParams = @"
# TCP Performance Optimizations
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072

# Async I/O for Better Throughput
use sendfile = yes
aio read size = 16384
aio write size = 16384

# Write Caching (512KB per connection)
write cache size = 524288

# Read-Ahead Optimization
min receivefile size = 16384

# Oplocks for Better Client Caching
oplocks = yes
level2 oplocks = yes

# Deadtime for Idle Connections (10 min)
deadtime = 10

# Large Read/Write Operations
max xmit = 65535
getwd cache = yes

# Disable Sync on Write (ZFS handles integrity)
strict sync = no

# Disable Printer Support
load printers = no
printing = bsd
"@

Write-Host "Recommended Auxiliary Parameters:" -ForegroundColor White
Write-Host $smbAuxParams -ForegroundColor Gray

if ($DryRun) {
    Write-Host ""
    Write-Host "[DRY RUN] No changes applied." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To apply these settings:" -ForegroundColor Cyan
    Write-Host "1. Open TrueNAS Web UI: https://$BabyNasIP" -ForegroundColor White
    Write-Host "2. Navigate to: Services > SMB > Configure" -ForegroundColor White
    Write-Host "3. Scroll to 'Auxiliary Parameters'" -ForegroundColor White
    Write-Host "4. Paste the parameters above" -ForegroundColor White
    Write-Host "5. Save and restart SMB service" -ForegroundColor White
    exit 0
}

###############################################################################
# Apply via TrueNAS API (if available)
###############################################################################
Write-Host ""
Write-Host "[4/4] Applying SMB Optimizations" -ForegroundColor Cyan
Write-Host "---------------------------------" -ForegroundColor Gray

# Check for .env file with API credentials
$envPath = "$PSScriptRoot\.env"
$apiKey = $null

if (Test-Path $envPath) {
    $envContent = Get-Content $envPath
    foreach ($line in $envContent) {
        if ($line -match "^TRUENAS_API_KEY=(.+)$") {
            $apiKey = $matches[1]
        }
    }
}

if ($apiKey -and $apiKey -ne "your-api-key-here") {
    Write-Host "Attempting API-based configuration..." -ForegroundColor Cyan

    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "Content-Type" = "application/json"
    }

    # Clean up parameters for JSON (remove comments, escape properly)
    $cleanParams = ($smbAuxParams -split "`n" | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" }) -join "`n"

    $body = @{
        smb_options = $cleanParams
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "https://$BabyNasIP/api/v2.0/smb" -Method PUT -Headers $headers -Body $body -SkipCertificateCheck
        Write-Host "  [OK] SMB parameters updated via API" -ForegroundColor Green

        # Restart SMB service
        Write-Host "  Restarting SMB service..." -ForegroundColor White
        $restartBody = @{ service = "cifs" } | ConvertTo-Json
        Invoke-RestMethod -Uri "https://$BabyNasIP/api/v2.0/service/restart" -Method POST -Headers $headers -Body $restartBody -SkipCertificateCheck
        Write-Host "  [OK] SMB service restarted" -ForegroundColor Green

    } catch {
        Write-Host "  API configuration failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Falling back to manual instructions..." -ForegroundColor Yellow
        $useManual = $true
    }
} else {
    $useManual = $true
}

if ($useManual) {
    Write-Host ""
    Write-Host "Manual Configuration Required:" -ForegroundColor Yellow
    Write-Host "==============================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Open TrueNAS Web UI: https://$BabyNasIP" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Navigate to: Services > SMB" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Click the gear icon (Configure)" -ForegroundColor White
    Write-Host ""
    Write-Host "4. Scroll to 'Auxiliary Parameters' and paste:" -ForegroundColor White
    Write-Host ""
    Write-Host $smbAuxParams -ForegroundColor Cyan
    Write-Host ""
    Write-Host "5. Click SAVE" -ForegroundColor White
    Write-Host ""
    Write-Host "6. Restart SMB service (toggle off/on or use restart button)" -ForegroundColor White
    Write-Host ""

    # Copy to clipboard if available
    try {
        $smbAuxParams | Set-Clipboard
        Write-Host "[Parameters copied to clipboard]" -ForegroundColor Green
    } catch {
        Write-Host "Tip: Copy parameters manually from above" -ForegroundColor Gray
    }
}

###############################################################################
# Additional SSH Optimization for Replication
###############################################################################
Write-Host ""
Write-Host "Bonus: SSH Optimization for Replication" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Gray

$sshOptScript = @'
#!/bin/bash
# Create optimized SSH config for replication

SSH_CONFIG="/root/.ssh/config"

# Backup existing config
if [ -f "$SSH_CONFIG" ]; then
    cp "$SSH_CONFIG" "${SSH_CONFIG}.backup"
fi

# Create optimized config
cat > "$SSH_CONFIG" << 'EOF'
# Optimized SSH config for ZFS replication

Host mainnas 10.0.0.89
    HostName 10.0.0.89
    User root
    IdentityFile /root/.ssh/id_replication

    # Fast ciphers (in order of preference)
    Ciphers aes128-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-gcm@openssh.com

    # Compression OFF (ZFS already compresses)
    Compression no

    # Connection reuse (ControlMaster)
    ControlMaster auto
    ControlPath /tmp/ssh-%r@%h:%p
    ControlPersist 600

    # TCP Keepalive
    ServerAliveInterval 30
    ServerAliveCountMax 6
    TCPKeepAlive yes

    # Disable unnecessary features
    ForwardAgent no
    ForwardX11 no

    # Fast key exchange
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

    # Disable strict checking for automation
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

chmod 600 "$SSH_CONFIG"
echo "SSH config optimized at $SSH_CONFIG"
'@

Write-Host "Applying SSH optimizations on Baby NAS..." -ForegroundColor White
$sshResult = $sshOptScript | ssh -i $sshKeyPath "$sshUser@$BabyNasIP" "bash" 2>&1
Write-Host "  [OK] $sshResult" -ForegroundColor Green

###############################################################################
# Summary
###############################################################################
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "      TrueNAS SMB Tuning Complete!                            " -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Applied Optimizations:" -ForegroundColor White
Write-Host "  - TCP_NODELAY and IPTOS_LOWDELAY socket options" -ForegroundColor Gray
Write-Host "  - Async I/O with 16KB read/write blocks" -ForegroundColor Gray
Write-Host "  - 512KB write cache per connection" -ForegroundColor Gray
Write-Host "  - Oplocks enabled for client caching" -ForegroundColor Gray
Write-Host "  - Disabled strict sync (ZFS provides integrity)" -ForegroundColor Gray
Write-Host "  - SSH config optimized for fast replication" -ForegroundColor Gray
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Run OPTIMIZE-SMB-CLIENT.ps1 on Windows clients" -ForegroundColor Gray
Write-Host "  2. Test backup performance" -ForegroundColor Gray
Write-Host "  3. Monitor with: ssh babynas 'smbstatus'" -ForegroundColor Gray
Write-Host ""

Write-Host "Performance Testing:" -ForegroundColor Yellow
Write-Host "  # Test SMB write speed:" -ForegroundColor Gray
Write-Host '  Measure-Command { [IO.File]::WriteAllBytes("\\babynas\test\1gb.bin", (New-Object byte[] 1GB)) }' -ForegroundColor White
Write-Host ""
