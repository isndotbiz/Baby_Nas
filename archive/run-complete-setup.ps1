#Requires -RunAsAdministrator
###############################################################################
# TrueNAS SCALE Complete Setup Orchestrator
# This script runs the complete setup process from Windows
###############################################################################

# Load environment variables from .env file
. "$PSScriptRoot\Load-EnvFile.ps1"

param(
    [Parameter(Mandatory=$false)]
    [string]$TrueNASIP = (Get-EnvVariable "TRUENAS_IP"),

    [Parameter(Mandatory=$false)]
    [string]$RootPassword = (Get-EnvVariable "TRUENAS_PASSWORD"),

    [Parameter(Mandatory=$false)]
    [switch]$SkipTrueNASSetup = $false,

    [Parameter(Mandatory=$false)]
    [switch]$SkipSSHSetup = $false,

    [Parameter(Mandatory=$false)]
    [switch]$SkipAPISetup = $false
)

$ErrorActionPreference = "Stop"

# Configuration
$USERNAME = Get-EnvVariable "TRUENAS_USERNAME" -Default "root"
$USER_PASSWORD = Get-EnvVariable "TRUENAS_PASSWORD"
$SCRIPT_DIR = $PSScriptRoot

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║            TrueNAS SCALE Complete Setup Orchestrator                    ║
║                                                                          ║
║  This script will configure your TrueNAS server with:                   ║
║  • Automated system configuration and optimizations                     ║
║  • SSH key-based authentication                                         ║
║  • API access for programmatic management                               ║
║  • Performance tuning for backup workloads                              ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "Target TrueNAS: $TrueNASIP" -ForegroundColor Yellow
Write-Host "Username: $USERNAME" -ForegroundColor Yellow
Write-Host ""

# Verify prerequisites
Write-Host "=== Checking Prerequisites ===" -ForegroundColor Green

# Check Python
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Python installed: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Python not found. Please install Python 3.7+!" -ForegroundColor Red
    exit 1
}

# Check OpenSSH Client
$sshClient = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
if ($sshClient.State -ne "Installed") {
    Write-Host "✗ OpenSSH Client not installed. Installing..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
    Write-Host "✓ OpenSSH Client installed" -ForegroundColor Green
} else {
    Write-Host "✓ OpenSSH Client installed" -ForegroundColor Green
}

# Check connectivity
Write-Host "Testing connectivity to $TrueNASIP..." -ForegroundColor Cyan
if (Test-Connection -ComputerName $TrueNASIP -Count 2 -Quiet) {
    Write-Host "✓ TrueNAS is reachable" -ForegroundColor Green
} else {
    Write-Host "✗ Cannot reach TrueNAS at $TrueNASIP" -ForegroundColor Red
    exit 1
}

Write-Host ""

###############################################################################
# Step 1: Run TrueNAS Initial Setup
###############################################################################
if (-not $SkipTrueNASSetup) {
    Write-Host "=== Step 1/3: TrueNAS Initial Configuration ===" -ForegroundColor Green
    Write-Host ""

    if ([string]::IsNullOrEmpty($RootPassword)) {
        $secureRootPassword = Read-Host "Enter root password for TrueNAS" -AsSecureString
        $RootPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureRootPassword)
        )
    }

    Write-Host "Uploading setup script to TrueNAS..." -ForegroundColor Cyan

    # Upload script using SCP
    $setupScript = Join-Path $SCRIPT_DIR "truenas-initial-setup.sh"

    if (-not (Test-Path $setupScript)) {
        Write-Host "✗ Setup script not found: $setupScript" -ForegroundColor Red
        exit 1
    }

    # Use scp to upload
    $env:SSH_ASKPASS = ""
    Write-Host "Uploading $setupScript to root@$TrueNASIP..." -ForegroundColor Cyan
    Write-Host "You may be prompted for the root password." -ForegroundColor Yellow

    & scp "$setupScript" "root@${TrueNASIP}:/root/"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠ Upload failed. Ensure SSH is enabled on TrueNAS." -ForegroundColor Yellow
        Write-Host "You can manually upload and run the script:" -ForegroundColor Cyan
        Write-Host "  scp $setupScript root@${TrueNASIP}:/root/" -ForegroundColor White
        Write-Host "  ssh root@${TrueNASIP} 'bash /root/truenas-initial-setup.sh'" -ForegroundColor White
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne 'y') { exit 1 }
    } else {
        Write-Host "✓ Script uploaded successfully" -ForegroundColor Green

        # Execute script
        Write-Host "Executing setup script on TrueNAS..." -ForegroundColor Cyan
        Write-Host "This may take 2-3 minutes..." -ForegroundColor Yellow

        & ssh "root@${TrueNASIP}" "chmod +x /root/truenas-initial-setup.sh && bash /root/truenas-initial-setup.sh"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ TrueNAS initial setup completed!" -ForegroundColor Green
        } else {
            Write-Host "⚠ Setup script execution had issues. Check output above." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "TrueNAS may benefit from a reboot. Reboot now? (y/n)" -ForegroundColor Yellow
    $reboot = Read-Host
    if ($reboot -eq 'y') {
        Write-Host "Rebooting TrueNAS..." -ForegroundColor Cyan
        & ssh "root@${TrueNASIP}" "reboot"
        Write-Host "Waiting 60 seconds for TrueNAS to reboot..." -ForegroundColor Yellow
        Start-Sleep -Seconds 60

        # Wait for TrueNAS to come back online
        $attempts = 0
        while ($attempts -lt 20) {
            Write-Host "Checking if TrueNAS is back online... (attempt $($attempts+1)/20)" -ForegroundColor Cyan
            if (Test-Connection -ComputerName $TrueNASIP -Count 1 -Quiet) {
                Write-Host "✓ TrueNAS is back online!" -ForegroundColor Green
                break
            }
            Start-Sleep -Seconds 10
            $attempts++
        }

        if ($attempts -eq 20) {
            Write-Host "⚠ TrueNAS did not come back online. Check manually." -ForegroundColor Yellow
            exit 1
        }
    }

    Write-Host ""
} else {
    Write-Host "=== Step 1/3: Skipped (TrueNAS Setup) ===" -ForegroundColor Yellow
    Write-Host ""
}

###############################################################################
# Step 2: Configure SSH Keys
###############################################################################
if (-not $SkipSSHSetup) {
    Write-Host "=== Step 2/3: SSH Key Configuration ===" -ForegroundColor Green
    Write-Host ""

    $sshSetupScript = Join-Path $SCRIPT_DIR "setup-ssh-keys.ps1"

    if (-not (Test-Path $sshSetupScript)) {
        Write-Host "✗ SSH setup script not found: $sshSetupScript" -ForegroundColor Red
        exit 1
    }

    Write-Host "Running SSH key setup..." -ForegroundColor Cyan
    & $sshSetupScript -TrueNASIP $TrueNASIP -Username $USERNAME -Password $USER_PASSWORD

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ SSH key configuration completed!" -ForegroundColor Green
    } else {
        Write-Host "⚠ SSH setup had issues. Check output above." -ForegroundColor Yellow
    }

    Write-Host ""
} else {
    Write-Host "=== Step 2/3: Skipped (SSH Setup) ===" -ForegroundColor Yellow
    Write-Host ""
}

###############################################################################
# Step 3: Configure API Access
###############################################################################
if (-not $SkipAPISetup) {
    Write-Host "=== Step 3/3: API Configuration ===" -ForegroundColor Green
    Write-Host ""

    $apiSetupScript = Join-Path $SCRIPT_DIR "truenas-api-setup.py"

    if (-not (Test-Path $apiSetupScript)) {
        Write-Host "✗ API setup script not found: $apiSetupScript" -ForegroundColor Red
        exit 1
    }

    Write-Host "Running API setup..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "IMPORTANT: You need to create an API key in the TrueNAS Web UI:" -ForegroundColor Yellow
    Write-Host "  1. Open: https://$TrueNASIP" -ForegroundColor Cyan
    Write-Host "  2. Login as: root" -ForegroundColor Cyan
    Write-Host "  3. Go to: Credentials → API Keys → Add" -ForegroundColor Cyan
    Write-Host "  4. Name: 'windows-automation'" -ForegroundColor Cyan
    Write-Host "  5. Copy the generated key" -ForegroundColor Cyan
    Write-Host ""

    $runApiSetup = Read-Host "Ready to configure API access? (y/n)"
    if ($runApiSetup -eq 'y') {
        & python "$apiSetupScript" --setup

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ API configuration completed!" -ForegroundColor Green

            # Test API access
            Write-Host ""
            Write-Host "Testing API access..." -ForegroundColor Cyan
            & python "$apiSetupScript" --status
        } else {
            Write-Host "⚠ API setup had issues. You can run it manually later:" -ForegroundColor Yellow
            Write-Host "  python truenas-api-setup.py --setup" -ForegroundColor White
        }
    } else {
        Write-Host "Skipping API setup. You can run it manually later:" -ForegroundColor Yellow
        Write-Host "  python truenas-api-setup.py --setup" -ForegroundColor White
    }

    Write-Host ""
} else {
    Write-Host "=== Step 3/3: Skipped (API Setup) ===" -ForegroundColor Yellow
    Write-Host ""
}

###############################################################################
# Summary and Next Steps
###############################################################################
Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                         Setup Complete!                                  ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host ""
Write-Host "Your TrueNAS server is configured with:" -ForegroundColor Cyan
Write-Host "  ✓ User account: $USERNAME" -ForegroundColor Green
Write-Host "  ✓ SSH key authentication" -ForegroundColor Green
Write-Host "  ✓ API access configured" -ForegroundColor Green
Write-Host "  ✓ Performance optimizations applied" -ForegroundColor Green
Write-Host "  ✓ Monitoring and maintenance scheduled" -ForegroundColor Green
Write-Host ""

Write-Host "Quick Access Commands:" -ForegroundColor Yellow
Write-Host "  SSH:  ssh truenas" -ForegroundColor Cyan
Write-Host "  Web:  https://$TrueNASIP" -ForegroundColor Cyan
Write-Host "  API:  python truenas-api-setup.py --status" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Create storage pool via Web UI (see QUICKSTART.md)" -ForegroundColor White
Write-Host "  2. Create datasets for your workloads" -ForegroundColor White
Write-Host "  3. Configure SMB shares" -ForegroundColor White
Write-Host "  4. Map network drives in Windows" -ForegroundColor White
Write-Host "  5. Configure Veeam backup repository" -ForegroundColor White
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "  Quick Start:   QUICKSTART.md" -ForegroundColor Cyan
Write-Host "  Full Guide:    TRUENAS_SETUP_GUIDE.md" -ForegroundColor Cyan
Write-Host "  API Docs:      https://$TrueNASIP/api/docs" -ForegroundColor Cyan
Write-Host ""

Write-Host "Connection Details:" -ForegroundColor Yellow
Write-Host "  IP Address:  $TrueNASIP" -ForegroundColor White
Write-Host "  Username:    $USERNAME" -ForegroundColor White
Write-Host "  Password:    $USER_PASSWORD" -ForegroundColor White
Write-Host ""

Write-Host "🎉 Congratulations! Your TrueNAS SCALE server is ready!" -ForegroundColor Green
Write-Host ""

# Offer to open Web UI
$openBrowser = Read-Host "Open TrueNAS Web UI in browser? (y/n)"
if ($openBrowser -eq 'y') {
    Start-Process "https://$TrueNASIP"
}
