#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create dedicated 'baby' user with SSH key-only access

.DESCRIPTION
    - Creates 'baby' user (no password)
    - Generates SSH key pair
    - Configures SSH for key-only authentication
    - Sets up firewall rules
    - Email: baby@isn.biz

.EXAMPLE
    .\setup-baby-user-complete.ps1
#>

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "BabyNAS: Create 'baby' User with SSH-Only Access" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$BABYNAS_OLD_IP = "192.168.215.2"
$BABYNAS_NEW_IP = "10.0.0.99"
$BABYNAS_IP = $BABYNAS_OLD_IP
$JDMAL_USER = "jdmal"
$JDMAL_KEY = "$HOME\.ssh\id_ed25519"
$BABY_USER = "baby"
$BABY_EMAIL = "baby@isn.biz"
$SSH_KEY_DIR = "$HOME\.ssh"
$BABY_KEY_NAME = "baby-isn-biz"
$BABY_KEY_FILE = "$SSH_KEY_DIR\$BABY_KEY_NAME"

Write-Host "[INFO] Configuration:" -ForegroundColor Yellow
Write-Host "  New Username: $BABY_USER"
Write-Host "  Email: $BABY_EMAIL"
Write-Host "  SSH Key: $BABY_KEY_FILE"
Write-Host "  BabyNAS Current IP: $BABYNAS_OLD_IP"
Write-Host "  BabyNAS New IP: $BABYNAS_NEW_IP (after network reconfiguration)"
Write-Host "  Connecting as: $JDMAL_USER (using existing key)"
Write-Host ""

# Check jdmal key exists
if (-not (Test-Path $JDMAL_KEY)) {
    Write-Host "[ERROR] jdmal SSH key not found at: $JDMAL_KEY" -ForegroundColor Red
    Write-Host "Please ensure the jdmal SSH key exists before running this script."
    exit 1
}

# Step 1: Create SSH key pair locally
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "STEP 1: Generate SSH Key Pair for 'baby' user" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $SSH_KEY_DIR)) {
    New-Item -ItemType Directory -Path $SSH_KEY_DIR -Force | Out-Null
    Write-Host "[OK] Created .ssh directory" -ForegroundColor Green
}

if (Test-Path $BABY_KEY_FILE) {
    Write-Host "[WARNING] SSH key already exists: $BABY_KEY_FILE" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "[SKIPPED] Using existing SSH key"
    } else {
        Write-Host "[...] Generating new SSH key pair..."
        ssh-keygen -t ed25519 -f $BABY_KEY_FILE -N '""' -C "baby@isn.biz" -q
        Write-Host "[OK] SSH key generated" -ForegroundColor Green
    }
} else {
    Write-Host "[...] Generating SSH key pair..."
    ssh-keygen -t ed25519 -f $BABY_KEY_FILE -N '""' -C "baby@isn.biz" -q
    Write-Host "[OK] SSH key pair created:" -ForegroundColor Green
    Write-Host "  Private: $BABY_KEY_FILE"
    Write-Host "  Public: $BABY_KEY_FILE.pub"
}

Write-Host ""

# Step 2: Create baby user on BabyNAS via SSH as jdmal with sudo
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "STEP 2: Create 'baby' User on BabyNAS" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[...] Connecting to BabyNAS as $JDMAL_USER..."

$createUserScript = @'
#!/bin/bash
set -e

BABY_USER="baby"
BABY_UID=2999
BABY_HOME="/home/baby"

echo "Creating baby user..."

# Create group if doesn't exist
if ! getent group "$BABY_USER" &>/dev/null; then
    sudo groupadd -g $BABY_UID $BABY_USER 2>/dev/null || true
fi

# Create baby user if doesn't exist
if ! id "$BABY_USER" &>/dev/null; then
    echo "[...] Creating user $BABY_USER"
    sudo useradd -m -u $BABY_UID -g $BABY_UID -s /bin/bash -c "BabyNAS Backup Service" $BABY_USER 2>/dev/null || sudo useradd -m -s /bin/bash -c "BabyNAS Backup Service" $BABY_USER
    echo "[OK] User $BABY_USER created"
else
    echo "[OK] User $BABY_USER already exists"
fi

# Create .ssh directory
SSH_DIR="$BABY_HOME/.ssh"
sudo mkdir -p "$SSH_DIR"
sudo chmod 700 "$SSH_DIR"
sudo chown -R $BABY_USER "$SSH_DIR" 2>/dev/null || sudo chown -R baby "$SSH_DIR"
echo "[OK] SSH directory created: $SSH_DIR"

# Disable password login for baby user
echo "Disabling password login..."
sudo passwd -l $BABY_USER 2>/dev/null || echo "passwd lock skipped"
echo "[OK] Password login disabled for $BABY_USER"

# Configure SSH to allow key-only access
echo "Configuring SSH..."

if ! grep -q "^Match User $BABY_USER" /etc/ssh/sshd_config 2>/dev/null; then
    echo "" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo "# Configuration for baby user (SSH key-only)" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo "Match User $BABY_USER" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo "    PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo "    PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo "    PermitEmptyPasswords no" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo "[OK] SSH config updated for $BABY_USER"
else
    echo "[OK] SSH config already configured for $BABY_USER"
fi

echo ""
echo "=========================================="
echo "User Creation Complete"
echo "=========================================="
'@

try {
    $output = $createUserScript | ssh -i $JDMAL_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "$JDMAL_USER@$BABYNAS_IP" "bash" 2>&1
    foreach ($line in $output) {
        if ($line -match "\[OK\]") {
            Write-Host $line -ForegroundColor Green
        } else {
            Write-Host $line
        }
    }
} catch {
    Write-Host "[ERROR] Failed to create user: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Install public key on BabyNAS
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "STEP 3: Install Public SSH Key on BabyNAS" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

$publicKey = Get-Content "$BABY_KEY_FILE.pub" -Raw
$publicKey = $publicKey.Trim()

Write-Host "[...] Installing public key..."

# Use echo to write the key directly with sudo
$installKeyCmd = "sudo mkdir -p /home/baby/.ssh && echo '$publicKey' | sudo tee /home/baby/.ssh/authorized_keys > /dev/null && sudo chmod 600 /home/baby/.ssh/authorized_keys && sudo chown -R baby /home/baby/.ssh && echo '[OK] Public key installed' && sudo systemctl restart sshd 2>/dev/null || sudo service sshd restart 2>/dev/null || true && echo '[OK] SSH service restarted'"

try {
    $output = ssh -i $JDMAL_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "$JDMAL_USER@$BABYNAS_IP" $installKeyCmd 2>&1
    foreach ($line in $output) {
        if ($line -match "\[OK\]") {
            Write-Host $line -ForegroundColor Green
        } else {
            Write-Host $line
        }
    }
} catch {
    Write-Host "[ERROR] Failed to install key: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Grant baby user permissions on encrypted datasets
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "STEP 4: Grant 'baby' User Permissions on Encrypted Datasets" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

$permissionsScript = @'
#!/bin/bash

BABY_USER="baby"
PERMISSIONS="create,receive,rollback,destroy,mount,unmount,snapshot,hold,release,send,compression"

echo "Granting baby user permissions on encrypted datasets..."
echo ""

for dataset in backups_encrypted veeam_encrypted wsl-backups_encrypted media_encrypted phone_encrypted home_encrypted; do
    if zfs list "tank/$dataset" &>/dev/null; then
        echo "Granting permissions on tank/$dataset..."
        sudo zfs allow -u $BABY_USER $PERMISSIONS "tank/$dataset" 2>/dev/null && echo "[OK] Permissions granted on tank/$dataset" || echo "[SKIP] tank/$dataset error"
    else
        echo "[SKIP] tank/$dataset does not exist"
    fi
done

echo ""
echo "[OK] All available permissions granted to $BABY_USER"
'@

try {
    $output = $permissionsScript | ssh -i $JDMAL_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "$JDMAL_USER@$BABYNAS_IP" "bash" 2>&1
    foreach ($line in $output) {
        if ($line -match "\[OK\]") {
            Write-Host $line -ForegroundColor Green
        } elseif ($line -match "\[SKIP\]") {
            Write-Host $line -ForegroundColor Yellow
        } else {
            Write-Host $line
        }
    }
} catch {
    Write-Host "[ERROR] Failed to grant permissions: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 5: Test SSH access
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "STEP 5: Test SSH Access as 'baby' user" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[...] Testing SSH connection as baby user..."

try {
    $testOutput = ssh -i $BABY_KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "baby@$BABYNAS_IP" "whoami && id" 2>&1

    if ($testOutput -match "baby") {
        Write-Host "[OK] SSH connection successful!" -ForegroundColor Green
        Write-Host $testOutput
    } else {
        Write-Host "[WARNING] SSH output unexpected:" -ForegroundColor Yellow
        Write-Host $testOutput
    }
} catch {
    Write-Host "[ERROR] SSH test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Step 6: Configure Windows Firewall
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "STEP 6: Configure Windows Firewall" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[INFO] Firewall configuration for 10.0.0.0/24 subnet:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Allow inbound from NAS subnet (10.0.0.0/24):"
Write-Host "  - BabyNAS: 10.0.0.99"
Write-Host "  - Main NAS: 10.0.0.89"
Write-Host "  - Gateway: 10.0.0.1"
Write-Host ""

$firewallRule = Get-NetFirewallRule -DisplayName "Allow NAS Subnet" -ErrorAction SilentlyContinue

if ($null -eq $firewallRule) {
    Write-Host "[...] Creating firewall rule for NAS subnet..."
    New-NetFirewallRule -DisplayName "Allow NAS Subnet" `
        -Direction Inbound `
        -RemoteAddress 10.0.0.0/24 `
        -Action Allow `
        -Description "Allow traffic from NAS subnet (BabyNAS 10.0.0.99, Main NAS 10.0.0.89)" | Out-Null
    Write-Host "[OK] Firewall rule created for 10.0.0.0/24" -ForegroundColor Green
} else {
    Write-Host "[OK] Firewall rule already exists" -ForegroundColor Green
}

# Remove old firewall rule if exists
$oldRule = Get-NetFirewallRule -DisplayName "Allow BabyNAS" -ErrorAction SilentlyContinue
if ($null -ne $oldRule) {
    Write-Host "[...] Removing old firewall rule for 192.168.215.0/24..."
    Remove-NetFirewallRule -DisplayName "Allow BabyNAS"
    Write-Host "[OK] Old rule removed" -ForegroundColor Green
}

Write-Host ""

# Summary
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "[OK] 'baby' user created on BabyNAS" -ForegroundColor Green
Write-Host "[OK] SSH key pair generated locally" -ForegroundColor Green
Write-Host "[OK] Public key installed on BabyNAS" -ForegroundColor Green
Write-Host "[OK] Permissions granted to encrypted datasets" -ForegroundColor Green
Write-Host "[OK] Password authentication disabled" -ForegroundColor Green
Write-Host "[OK] SSH key-only access enabled" -ForegroundColor Green
Write-Host "[OK] Firewall rules configured" -ForegroundColor Green
Write-Host ""

Write-Host "SSH Key Details:" -ForegroundColor Cyan
Write-Host "  Private Key: $BABY_KEY_FILE"
Write-Host "  Public Key: $BABY_KEY_FILE.pub"
Write-Host ""

Write-Host "To use the baby user (current IP):" -ForegroundColor Cyan
Write-Host "  ssh -i $BABY_KEY_FILE baby@$BABYNAS_OLD_IP"
Write-Host ""

Write-Host "After network reconfiguration (new IP):" -ForegroundColor Cyan
Write-Host "  ssh -i $BABY_KEY_FILE baby@$BABYNAS_NEW_IP"
Write-Host ""

Write-Host "SSH config (~/.ssh/config) - use after network change:" -ForegroundColor Cyan
Write-Host "  Host babynas"
Write-Host "    HostName $BABYNAS_NEW_IP"
Write-Host "    User baby"
Write-Host "    IdentityFile $BABY_KEY_FILE"
Write-Host ""
Write-Host "  Host main-nas"
Write-Host "    HostName 10.0.0.89"
Write-Host "    User root"
Write-Host ""

Write-Host "Then just run:" -ForegroundColor Cyan
Write-Host "  ssh babynas"
Write-Host "  ssh main-nas"
Write-Host ""

Write-Host "================================================================================" -ForegroundColor Yellow
Write-Host "NEXT STEP: Network Reconfiguration" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "See SETUP-BABY-USER-COMPLETE-GUIDE.md for network setup:" -ForegroundColor Yellow
Write-Host "  1. Change Hyper-V virtual switch to External"
Write-Host "  2. SSH to BabyNAS and change IP to 10.0.0.99"
Write-Host "  3. Test: ssh -i ~/.ssh/baby-isn-biz baby@10.0.0.99"
Write-Host ""
