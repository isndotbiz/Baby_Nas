#Requires -RunAsAdministrator
###############################################################################
# Baby NAS Configuration Script
# Configures TrueNAS Baby NAS from Windows after installation
###############################################################################

# Load environment variables from .env file
. "$PSScriptRoot\Load-EnvFile.ps1"

param(
    [Parameter(Mandatory=$false)]
    [string]$BabyNasIP = (Get-EnvVariable "TRUENAS_IP"),

    [Parameter(Mandatory=$false)]
    [string]$Username = (Get-EnvVariable "TRUENAS_USERNAME" -Default "root"),

    [Parameter(Mandatory=$false)]
    [string]$Password = (Get-EnvVariable "TRUENAS_PASSWORD"),

    [Parameter(Mandatory=$false)]
    [string]$RootPassword = (Get-EnvVariable "TRUENAS_PASSWORD")
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║              Baby NAS Configuration from Windows                         ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "Target: $BabyNasIP" -ForegroundColor Yellow
Write-Host "User: $Username" -ForegroundColor Yellow
Write-Host ""

###############################################################################
# Step 1: Test Connectivity
###############################################################################
Write-Host "=== Testing Connectivity ===" -ForegroundColor Green

if (-not (Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet)) {
    Write-Host "✗ Cannot reach Baby NAS at $BabyNasIP" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Baby NAS is reachable" -ForegroundColor Green

# Test web UI
try {
    $response = Invoke-WebRequest -Uri "https://$BabyNasIP" -SkipCertificateCheck -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✓ Web UI is accessible at https://$BabyNasIP" -ForegroundColor Green
} catch {
    Write-Host "⚠ Web UI may not be ready yet" -ForegroundColor Yellow
}

###############################################################################
# Step 2: Install OpenSSH Client (if not already installed)
###############################################################################
Write-Host ""
Write-Host "=== Checking SSH Client ===" -ForegroundColor Green

$sshClient = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
if ($sshClient.State -ne "Installed") {
    Write-Host "Installing OpenSSH Client..." -ForegroundColor Cyan
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
    Write-Host "✓ OpenSSH Client installed" -ForegroundColor Green
} else {
    Write-Host "✓ OpenSSH Client already installed" -ForegroundColor Green
}

###############################################################################
# Step 3: Generate SSH Keys
###############################################################################
Write-Host ""
Write-Host "=== Configuring SSH Keys ===" -ForegroundColor Green

$sshDir = "$env:USERPROFILE\.ssh"
$keyFile = "$sshDir\id_babynas"
$pubKeyFile = "$keyFile.pub"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

if (-not (Test-Path $keyFile)) {
    Write-Host "Generating SSH key for Baby NAS..." -ForegroundColor Cyan
    ssh-keygen -t ed25519 -f $keyFile -N '""' -C "babynas-$env:USERNAME"
    Write-Host "✓ SSH key generated" -ForegroundColor Green
} else {
    Write-Host "✓ SSH key already exists" -ForegroundColor Green
}

# Display public key
$pubKey = Get-Content $pubKeyFile
Write-Host "Public key:" -ForegroundColor Yellow
Write-Host $pubKey -ForegroundColor Cyan

###############################################################################
# Step 4: Copy SSH Key to Baby NAS
###############################################################################
Write-Host ""
Write-Host "=== Copying SSH Key to Baby NAS ===" -ForegroundColor Green
Write-Host "You may be prompted for the root password: $RootPassword" -ForegroundColor Yellow

# Create authorized_keys for root
try {
    $sshCommand = "mkdir -p /root/.ssh && chmod 700 /root/.ssh && cat >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
    Get-Content $pubKeyFile | ssh root@$BabyNasIP $sshCommand
    Write-Host "✓ SSH key copied to root account" -ForegroundColor Green
} catch {
    Write-Host "⚠ Failed to copy key automatically. Manual method:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. SSH into Baby NAS: ssh root@$BabyNasIP" -ForegroundColor Cyan
    Write-Host "2. Run: mkdir -p ~/.ssh && chmod 700 ~/.ssh" -ForegroundColor Cyan
    Write-Host "3. Run: echo '$pubKey' >> ~/.ssh/authorized_keys" -ForegroundColor Cyan
    Write-Host "4. Run: chmod 600 ~/.ssh/authorized_keys" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter after completing manual setup"
}

# Test SSH connection
Write-Host "Testing SSH connection..." -ForegroundColor Cyan
$testResult = ssh -i $keyFile -o StrictHostKeyChecking=no root@$BabyNasIP "echo 'SSH key auth successful'"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ SSH key authentication working!" -ForegroundColor Green
} else {
    Write-Host "✗ SSH key authentication failed" -ForegroundColor Red
    exit 1
}

###############################################################################
# Step 5: Create SSH Config
###############################################################################
Write-Host ""
Write-Host "=== Creating SSH Config ===" -ForegroundColor Green

$sshConfig = "$sshDir\config"
$configContent = @"

Host babynas
    HostName $BabyNasIP
    User root
    IdentityFile ~/.ssh/id_babynas
    StrictHostKeyChecking no

Host babynas-admin
    HostName $BabyNasIP
    User $Username
    IdentityFile ~/.ssh/id_babynas
    StrictHostKeyChecking no
"@

if (Test-Path $sshConfig) {
    # Append if not already there
    $existingConfig = Get-Content $sshConfig -Raw
    if ($existingConfig -notmatch "Host babynas") {
        Add-Content -Path $sshConfig -Value $configContent
        Write-Host "✓ SSH config updated" -ForegroundColor Green
    } else {
        Write-Host "• SSH config already contains babynas entry" -ForegroundColor Gray
    }
} else {
    Set-Content -Path $sshConfig -Value $configContent
    Write-Host "✓ SSH config created" -ForegroundColor Green
}

###############################################################################
# Step 6: Upload Configuration Script
###############################################################################
Write-Host ""
Write-Host "=== Uploading Configuration Script ===" -ForegroundColor Green

$configScript = Join-Path $PSScriptRoot "truenas-baby-nas-config.sh"

# Create the config script if it doesn't exist
if (-not (Test-Path $configScript)) {
    Write-Host "Creating configuration script..." -ForegroundColor Cyan

    @'
#!/bin/bash
###############################################################################
# TrueNAS Baby NAS Configuration Script
###############################################################################

set -e

echo "=== TrueNAS Baby NAS Configuration ==="
echo "Applying optimizations and creating datasets..."

# Wait for system to be ready
sleep 5

# ZFS Tuning
echo "Configuring ZFS tuning..."
if [ -f /etc/modprobe.d/zfs.conf ]; then
    grep -q "zfs_arc_max" /etc/modprobe.d/zfs.conf || \
        echo "options zfs zfs_arc_max=8589934592" >> /etc/modprobe.d/zfs.conf
else
    echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf
fi

# Network Tuning
echo "Applying network tuning..."
cat >> /etc/sysctl.conf << 'EOF'
# Baby NAS Network Tuning
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_window_scaling = 1
vm.swappiness = 10
EOF
sysctl -p 2>/dev/null || true

# Create datasets if pool exists
if zpool list tank &>/dev/null; then
    echo "Creating dataset structure..."

    # Windows backups
    zfs create -o recordsize=128K -o compression=lz4 tank/windows-backups 2>/dev/null || true
    zfs create -o quota=500G tank/windows-backups/c-drive 2>/dev/null || true
    zfs create -o quota=2T tank/windows-backups/d-workspace 2>/dev/null || true
    zfs create -o quota=500G tank/windows-backups/wsl 2>/dev/null || true

    # Veeam
    zfs create -o recordsize=1M -o compression=lz4 -o sync=standard tank/veeam 2>/dev/null || true
    zfs set quota=3T tank/veeam 2>/dev/null || true

    # Home directories
    zfs create tank/home 2>/dev/null || true
    zfs create tank/home/truenas_admin 2>/dev/null || true

    echo "✓ Datasets created"

    # Set permissions
    chown -R 3000:3000 /mnt/tank/home/truenas_admin 2>/dev/null || true
    chmod 700 /mnt/tank/home/truenas_admin 2>/dev/null || true

    echo "✓ Permissions set"
else
    echo "⚠ Pool 'tank' not found - create it first via Web UI"
fi

echo ""
echo "=== Configuration Complete ==="
echo "Next steps:"
echo "1. Create pool 'tank' via Web UI if not done"
echo "2. Create user 'truenas_admin' via Web UI"
echo "3. Configure SMB shares"
echo "4. Set up replication to Main NAS"
'@ | Out-File -FilePath $configScript -Encoding UTF8 -Force

    Write-Host "✓ Configuration script created" -ForegroundColor Green
}

# Upload script
Write-Host "Uploading to Baby NAS..." -ForegroundColor Cyan
scp -i $keyFile $configScript root@${BabyNasIP}:/root/baby-nas-config.sh

Write-Host "Making executable..." -ForegroundColor Cyan
ssh -i $keyFile root@$BabyNasIP "chmod +x /root/baby-nas-config.sh"

Write-Host "✓ Configuration script uploaded" -ForegroundColor Green

###############################################################################
# Step 7: Run Configuration Script
###############################################################################
Write-Host ""
Write-Host "=== Running Configuration Script ===" -ForegroundColor Green
Write-Host "This will apply system tuning and create datasets..." -ForegroundColor Cyan

$runNow = Read-Host "Run configuration script now? (yes/no)"
if ($runNow -eq "yes") {
    ssh -i $keyFile root@$BabyNasIP "/root/baby-nas-config.sh"
    Write-Host "✓ Configuration applied" -ForegroundColor Green
} else {
    Write-Host "⚠ Skipped - run manually later with:" -ForegroundColor Yellow
    Write-Host "  ssh babynas '/root/baby-nas-config.sh'" -ForegroundColor White
}

###############################################################################
# Step 8: Configure API Access
###############################################################################
Write-Host ""
Write-Host "=== Configuring API Access ===" -ForegroundColor Green
Write-Host ""
Write-Host "To configure API access:" -ForegroundColor Yellow
Write-Host "  1. Open Web UI: https://$BabyNasIP" -ForegroundColor Cyan
Write-Host "  2. Login as: root / $RootPassword" -ForegroundColor Cyan
Write-Host "  3. Go to: Credentials → API Keys → Add" -ForegroundColor Cyan
Write-Host "  4. Name: 'windows-automation'" -ForegroundColor Cyan
Write-Host "  5. Copy the generated key" -ForegroundColor Cyan
Write-Host ""

$setupApi = Read-Host "Configure API now? (yes/no)"
if ($setupApi -eq "yes") {
    $apiScript = Join-Path $PSScriptRoot "truenas-api-setup.py"

    if (Test-Path $apiScript) {
        Write-Host "Running API setup..." -ForegroundColor Cyan
        python $apiScript --setup
    } else {
        Write-Host "⚠ API setup script not found: $apiScript" -ForegroundColor Yellow
    }
}

###############################################################################
# Step 9: Create PowerShell Aliases
###############################################################################
Write-Host ""
Write-Host "=== Creating PowerShell Shortcuts ===" -ForegroundColor Green

$profileContent = @"

# Baby NAS Shortcuts
function Connect-BabyNAS {
    ssh -i `$env:USERPROFILE\.ssh\id_babynas root@$BabyNasIP
}

function Get-BabyNASStatus {
    ssh -i `$env:USERPROFILE\.ssh\id_babynas root@$BabyNasIP "zpool status tank; zfs list -o name,used,avail,compression,compressratio"
}

Set-Alias -Name babynas -Value Connect-BabyNAS -Force
Set-Alias -Name babystatus -Value Get-BabyNASStatus -Force

Write-Host "Baby NAS shortcuts loaded:" -ForegroundColor Green
Write-Host "  babynas     - SSH to Baby NAS" -ForegroundColor Cyan
Write-Host "  babystatus  - Show pool status" -ForegroundColor Cyan
"@

if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
}

$existingProfile = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($existingProfile -notmatch "Baby NAS Shortcuts") {
    Add-Content -Path $PROFILE -Value $profileContent
    Write-Host "✓ PowerShell profile updated: $PROFILE" -ForegroundColor Green
    Write-Host "  Restart PowerShell to activate shortcuts" -ForegroundColor Yellow
} else {
    Write-Host "• Shortcuts already configured" -ForegroundColor Gray
}

###############################################################################
# Summary
###############################################################################
Write-Host ""
Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║              Baby NAS Configuration Complete!                            ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host ""
Write-Host "Connection Details:" -ForegroundColor Yellow
Write-Host "  IP: $BabyNasIP" -ForegroundColor White
Write-Host "  SSH: ssh babynas (or ssh -i ~/.ssh/id_babynas root@$BabyNasIP)" -ForegroundColor White
Write-Host "  Web UI: https://$BabyNasIP" -ForegroundColor White
Write-Host "  Username: root / $Username (after creation)" -ForegroundColor White
Write-Host "  Password: $RootPassword" -ForegroundColor White
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Access Web UI: https://$BabyNasIP" -ForegroundColor Cyan
Write-Host "  2. Create pool 'tank' (RAIDZ1 + SLOG + L2ARC)" -ForegroundColor Cyan
Write-Host "  3. Create user '$Username' via Credentials → Local Users" -ForegroundColor Cyan
Write-Host "  4. Run: ssh babynas '/root/baby-nas-config.sh'" -ForegroundColor Cyan
Write-Host "  5. Create SMB shares via Shares → Windows (SMB) Shares" -ForegroundColor Cyan
Write-Host "  6. Set up replication to Main NAS (10.0.0.89)" -ForegroundColor Cyan
Write-Host ""

$openBrowser = Read-Host "Open Baby NAS Web UI now? (yes/no)"
if ($openBrowser -eq "yes") {
    Start-Process "https://$BabyNasIP"
}

Write-Host ""
Write-Host "✓ Setup complete!" -ForegroundColor Green
Write-Host ""
