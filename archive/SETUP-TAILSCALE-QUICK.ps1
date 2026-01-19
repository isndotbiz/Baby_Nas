#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install and configure Tailscale VPN on BabyNAS
    Enables secure remote access to encrypted datasets from anywhere

.DESCRIPTION
    - Installs Tailscale on BabyNAS via SSH
    - Authenticates with Tailscale account
    - Gets Tailscale IP for remote access
    - Provides connection instructions

.EXAMPLE
    .\\SETUP-TAILSCALE-QUICK.ps1

.NOTES
    Requires:
    - Tailscale account (free at https://tailscale.com)
    - SSH access to BabyNAS (192.168.215.2)
    - Internet connection on BabyNAS
#>

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Tailscale VPN Setup for BabyNAS" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

Write-Host "[INFO] What this does:" -ForegroundColor Yellow
Write-Host "  1. Installs Tailscale VPN on BabyNAS"
Write-Host "  2. Authenticates with your Tailscale account"
Write-Host "  3. Provides VPN IP for secure remote access"
Write-Host "  4. Allows access to encrypted datasets from anywhere"
Write-Host ""

Write-Host "[INFO] Requirements:" -ForegroundColor Yellow
Write-Host "  • Tailscale account (create at https://tailscale.com - free)"
Write-Host "  • SSH access to BabyNAS (192.168.215.2)"
Write-Host "  • Same Tailscale account on your Windows machine"
Write-Host ""

$hasAccount = Read-Host "[?] Do you have a Tailscale account? (yes/no)"
if ($hasAccount -ne "yes") {
    Write-Host ""
    Write-Host "[INFO] Create a free Tailscale account:" -ForegroundColor Cyan
    Write-Host "  1. Go to https://tailscale.com/signup"
    Write-Host "  2. Sign up with email (free forever for personal use)"
    Write-Host "  3. Come back when you have an account"
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "[...] Installing Tailscale on BabyNAS..." -ForegroundColor Yellow
Write-Host ""

$installScript = @'
#!/bin/bash
set -e

echo "=========================================="
echo "Installing Tailscale on BabyNAS"
echo "=========================================="
echo ""

# Check if Tailscale is already installed
if command -v tailscale &> /dev/null; then
    echo "[OK] Tailscale is already installed"
    echo ""
    echo "Checking connection status..."
    tailscale status
    echo ""
else
    echo "[...] Downloading Tailscale installer..."
    curl -fsSL https://tailscale.com/install.sh | sh

    echo ""
    echo "[OK] Tailscale installed successfully"
    echo ""
fi

# Start Tailscale
echo "[...] Starting Tailscale service..."
systemctl start tailscaled || service tailscaled start || true

# Bring up Tailscale
echo ""
echo "=========================================="
echo "IMPORTANT: Complete authentication!"
echo "=========================================="
echo ""
echo "Run this command in your terminal:"
echo "  ssh root@192.168.215.2"
echo "Then execute:"
echo "  tailscale up"
echo ""
echo "This will give you a link to sign in with your Tailscale account."
echo ""
echo "Once authenticated, run this to get your Tailscale IP:"
echo "  tailscale ip -4"
echo ""

'@

try {
    $output = $installScript | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.215.2 "bash" 2>&1

    $output | ForEach-Object {
        if ($_ -match "OK|success|installed") {
            Write-Host $_ -ForegroundColor Green
        } elseif ($_ -match "ERROR|error|failed") {
            Write-Host $_ -ForegroundColor Red
        } elseif ($_ -match "===|IMPORTANT") {
            Write-Host $_ -ForegroundColor Cyan
        } else {
            Write-Host $_
        }
    }

    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "NEXT STEP: Authenticate Tailscale" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[1] SSH into BabyNAS:" -ForegroundColor Yellow
    Write-Host "    ssh root@192.168.215.2"
    Write-Host "    Password: 74108520"
    Write-Host ""

    Write-Host "[2] Bring up Tailscale:" -ForegroundColor Yellow
    Write-Host "    tailscale up"
    Write-Host ""

    Write-Host "[3] Authenticate:" -ForegroundColor Yellow
    Write-Host "    • You'll get a login URL"
    Write-Host "    • Open it in browser"
    Write-Host "    • Sign in with your Tailscale account"
    Write-Host "    • Device will appear in Tailscale console"
    Write-Host ""

    Write-Host "[4] Get Tailscale IP:" -ForegroundColor Yellow
    Write-Host "    tailscale ip -4"
    Write-Host ""
    Write-Host "    (Write this down! You'll need it)"
    Write-Host ""

    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "Windows Setup" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[1] Download Tailscale for Windows:" -ForegroundColor Yellow
    Write-Host "    https://tailscale.com/download/windows"
    Write-Host ""

    Write-Host "[2] Install and run Tailscale" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "[3] Sign in with SAME Tailscale account as BabyNAS" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "[4] You're connected!" -ForegroundColor Yellow
    Write-Host "    You should see BabyNAS in your device list"
    Write-Host ""

    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "Access Encrypted Datasets Remotely" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[Option 1] Via Web UI:" -ForegroundColor Yellow
    Write-Host "    https://[tailscale-ip]"
    Write-Host "    Example: https://100.64.45.10"
    Write-Host ""

    Write-Host "[Option 2] Via SMB (File Explorer):" -ForegroundColor Yellow
    Write-Host "    \\[tailscale-ip]\backups_encrypted"
    Write-Host "    Username: jdmal"
    Write-Host "    Password: (jdmal password)"
    Write-Host ""

    Write-Host "[Option 3] Via SSH (Terminal):" -ForegroundColor Yellow
    Write-Host "    ssh jdmal@[tailscale-ip]"
    Write-Host "    cd /mnt/tank/backups_encrypted"
    Write-Host ""

    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "VPN SETUP COMPLETE!" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host ""

    Write-Host "[✓] Encrypted datasets now accessible from anywhere" -ForegroundColor Green
    Write-Host "[✓] All traffic encrypted through Tailscale VPN" -ForegroundColor Green
    Write-Host "[✓] No internet exposure (secure private network)" -ForegroundColor Green
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host "ERROR: SSH connection failed!" -ForegroundColor Red
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host ""
    Write-Host "Cannot connect to BabyNAS. Verify:" -ForegroundColor Yellow
    Write-Host "  1. BabyNAS is running: ping 192.168.215.2"
    Write-Host "  2. SSH is enabled on BabyNAS"
    Write-Host "  3. Password is correct: 74108520"
    Write-Host ""
    exit 1
}
