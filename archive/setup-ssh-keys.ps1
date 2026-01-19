#Requires -RunAsAdministrator
###############################################################################
# Windows SSH Key Setup for TrueNAS
# This script generates SSH keys and configures SSH client on Windows
###############################################################################

# Load environment variables from .env file
. "$PSScriptRoot\Load-EnvFile.ps1"

param(
    [Parameter(Mandatory=$false)]
    [string]$TrueNASIP = (Get-EnvVariable "TRUENAS_IP"),

    [Parameter(Mandatory=$false)]
    [string]$Username = (Get-EnvVariable "TRUENAS_USERNAME" -Default "root"),

    [Parameter(Mandatory=$false)]
    [string]$Password = (Get-EnvVariable "TRUENAS_PASSWORD")
)

$ErrorActionPreference = "Stop"

Write-Host "=== TrueNAS SSH Key Setup ===" -ForegroundColor Green
Write-Host ""

# Get TrueNAS IP if not provided
if ([string]::IsNullOrEmpty($TrueNASIP)) {
    $TrueNASIP = Read-Host "Enter TrueNAS IP address"
}

###############################################################################
# Step 1: Install OpenSSH Client (if not already installed)
###############################################################################
Write-Host "[1/6] Checking OpenSSH Client..." -ForegroundColor Yellow

$sshClient = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
if ($sshClient.State -ne "Installed") {
    Write-Host "Installing OpenSSH Client..." -ForegroundColor Cyan
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
    Write-Host "✓ OpenSSH Client installed" -ForegroundColor Green
} else {
    Write-Host "✓ OpenSSH Client already installed" -ForegroundColor Green
}

###############################################################################
# Step 2: Generate SSH Keys
###############################################################################
Write-Host "[2/6] Generating SSH keys..." -ForegroundColor Yellow

$sshDir = "$env:USERPROFILE\.ssh"
$keyFile = "$sshDir\id_rsa"
$pubKeyFile = "$sshDir\id_rsa.pub"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    # Set proper permissions on .ssh directory
    $acl = Get-Acl $sshDir
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
    )
    $acl.AddAccessRule($rule)
    Set-Acl $sshDir $acl
}

if (-not (Test-Path $keyFile)) {
    Write-Host "Generating RSA key pair..." -ForegroundColor Cyan
    ssh-keygen -t rsa -b 4096 -f $keyFile -N '""' -C "$env:USERNAME@windows"
    Write-Host "✓ SSH key pair generated" -ForegroundColor Green
} else {
    Write-Host "✓ SSH key already exists: $keyFile" -ForegroundColor Green
}

###############################################################################
# Step 3: Display Public Key
###############################################################################
Write-Host "[3/6] Your SSH public key:" -ForegroundColor Yellow
$pubKey = Get-Content $pubKeyFile
Write-Host $pubKey -ForegroundColor Cyan
Write-Host ""

###############################################################################
# Step 4: Copy Public Key to TrueNAS
###############################################################################
Write-Host "[4/6] Copying public key to TrueNAS..." -ForegroundColor Yellow

# Create SSH config file
$sshConfigFile = "$sshDir\config"
$sshConfigContent = @"
Host truenas
    HostName $TrueNASIP
    User $Username
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts

Host $TrueNASIP
    User $Username
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
"@

Set-Content -Path $sshConfigFile -Value $sshConfigContent -Force
Write-Host "✓ SSH config created: $sshConfigFile" -ForegroundColor Green

# Try to copy key using ssh-copy-id alternative
Write-Host "Attempting to copy key to TrueNAS..." -ForegroundColor Cyan
Write-Host "You may be prompted for the password: $Password" -ForegroundColor Yellow

# Method 1: Use type and ssh to add key
$sshCommand = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

try {
    # Add to known hosts first
    ssh-keyscan -H $TrueNASIP 2>$null | Out-File -Append "$sshDir\known_hosts" -Encoding ASCII

    # Copy the key
    Get-Content $pubKeyFile | ssh "${Username}@${TrueNASIP}" $sshCommand

    Write-Host "✓ Public key copied to TrueNAS" -ForegroundColor Green
} catch {
    Write-Host "⚠ Automatic key copy failed. Manual method:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Copy this public key:" -ForegroundColor Cyan
    Write-Host $pubKey -ForegroundColor White
    Write-Host ""
    Write-Host "2. SSH into TrueNAS:" -ForegroundColor Cyan
    Write-Host "   ssh ${Username}@${TrueNASIP}" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Add to authorized_keys:" -ForegroundColor Cyan
    Write-Host "   mkdir -p ~/.ssh && echo 'YOUR_PUBLIC_KEY' >> ~/.ssh/authorized_keys" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter after completing manual setup"
}

###############################################################################
# Step 5: Test SSH Connection
###############################################################################
Write-Host "[5/6] Testing SSH connection..." -ForegroundColor Yellow

try {
    $testResult = ssh -o BatchMode=yes -o ConnectTimeout=5 "${Username}@${TrueNASIP}" "echo 'SSH key authentication successful!'" 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ SSH key authentication working!" -ForegroundColor Green
        Write-Host $testResult -ForegroundColor Cyan
    } else {
        Write-Host "⚠ Key authentication not working yet, trying with password..." -ForegroundColor Yellow
        Write-Host "Connection command: ssh ${Username}@${TrueNASIP}" -ForegroundColor Cyan
    }
} catch {
    Write-Host "⚠ Connection test failed. Verify network connectivity." -ForegroundColor Yellow
}

###############################################################################
# Step 6: Create Connection Shortcuts
###############################################################################
Write-Host "[6/6] Creating connection shortcuts..." -ForegroundColor Yellow

# Create PowerShell connection function
$profileContent = @"

# TrueNAS Connection Shortcuts
function Connect-TrueNAS {
    ssh ${Username}@${TrueNASIP}
}

function Connect-TrueNASRoot {
    ssh root@${TrueNASIP}
}

Set-Alias -Name tn -Value Connect-TrueNAS
Set-Alias -Name tnroot -Value Connect-TrueNASRoot

Write-Host "TrueNAS shortcuts loaded:" -ForegroundColor Green
Write-Host "  tn       - Connect as $Username" -ForegroundColor Cyan
Write-Host "  tnroot   - Connect as root" -ForegroundColor Cyan
"@

# Append to PowerShell profile
if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
}

if (-not (Select-String -Path $PROFILE -Pattern "Connect-TrueNAS" -Quiet)) {
    Add-Content -Path $PROFILE -Value $profileContent
    Write-Host "✓ PowerShell profile updated: $PROFILE" -ForegroundColor Green
} else {
    Write-Host "✓ PowerShell shortcuts already configured" -ForegroundColor Green
}

# Create batch file for quick connection
$batchFile = "$env:USERPROFILE\Desktop\Connect-TrueNAS.bat"
$batchContent = @"
@echo off
ssh ${Username}@${TrueNASIP}
pause
"@
Set-Content -Path $batchFile -Value $batchContent -Force
Write-Host "✓ Desktop shortcut created: $batchFile" -ForegroundColor Green

###############################################################################
# Summary
###############################################################################
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "    SSH Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Connection Details:" -ForegroundColor Yellow
Write-Host "  TrueNAS IP: $TrueNASIP" -ForegroundColor White
Write-Host "  Username: $Username" -ForegroundColor White
Write-Host "  SSH Key: $keyFile" -ForegroundColor White
Write-Host ""
Write-Host "Connect to TrueNAS:" -ForegroundColor Yellow
Write-Host "  Method 1: ssh ${Username}@${TrueNASIP}" -ForegroundColor Cyan
Write-Host "  Method 2: ssh truenas" -ForegroundColor Cyan
Write-Host "  Method 3: Type 'tn' in PowerShell (after restarting shell)" -ForegroundColor Cyan
Write-Host "  Method 4: Double-click Desktop\Connect-TrueNAS.bat" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files Created:" -ForegroundColor Yellow
Write-Host "  SSH Config: $sshConfigFile" -ForegroundColor White
Write-Host "  Private Key: $keyFile" -ForegroundColor White
Write-Host "  Public Key: $pubKeyFile" -ForegroundColor White
Write-Host "  Desktop Shortcut: $batchFile" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test connection: ssh truenas" -ForegroundColor Cyan
Write-Host "  2. Generate API key in TrueNAS Web UI" -ForegroundColor Cyan
Write-Host "  3. Run: .\truenas-api-setup.py" -ForegroundColor Cyan
Write-Host ""
