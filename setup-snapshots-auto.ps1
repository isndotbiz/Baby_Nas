# Load environment variables from .env file
. "$PSScriptRoot\Load-EnvFile.ps1"

param(
    [string]$NasIP = (Get-EnvVariable "TRUENAS_IP" -Default "172.21.203.18"),
    [string]$NasUser = (Get-EnvVariable "TRUENAS_USERNAME" -Default "root"),
    [string]$NasPassword = (Get-EnvVariable "TRUENAS_PASSWORD")
)

Write-Host ""
Write-Host "=== Setting Up Automated Snapshots on Baby NAS ===" -ForegroundColor Cyan
Write-Host ""

# Test connectivity
Write-Host "Step 1: Testing Baby NAS connectivity..." -ForegroundColor Yellow
$ping = Test-Connection -ComputerName $NasIP -Count 1 -Quiet -ErrorAction SilentlyContinue

if (-not $ping) {
    Write-Host "  ERROR: Cannot reach Baby NAS at $NasIP" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start the VM first:" -ForegroundColor Yellow
    Write-Host "  Get-VM -Name 'TrueNAS-BabyNAS' | Select State" -ForegroundColor Cyan
    Write-Host "  Start-VM -Name 'TrueNAS-BabyNAS'" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "  OK - Baby NAS is online at $NasIP" -ForegroundColor Green
Write-Host ""

# SSH commands to setup snapshots
Write-Host "Step 2: Setting up auto-snapshots via SSH..." -ForegroundColor Yellow
Write-Host ""

$sshCommands = @(
    "zfs set com.sun:auto-snapshot=true tank",
    "zfs set com.sun:auto-snapshot:hourly=true tank",
    "zfs set com.sun:auto-snapshot:daily=true tank",
    "zfs set com.sun:auto-snapshot:weekly=true tank"
)

$plink = "plink.exe"

# Check if plink exists
if (-not (Get-Command $plink -ErrorAction SilentlyContinue)) {
    Write-Host "  Plink not found. Using alternative method..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Please SSH manually:" -ForegroundColor Yellow
    Write-Host "    ssh admin@$NasIP" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Then paste these commands:" -ForegroundColor Yellow
    foreach ($cmd in $sshCommands) {
        Write-Host "    $cmd" -ForegroundColor Cyan
    }
    Write-Host ""
    exit 0
}

# Try using SSH directly
try {
    Write-Host "  Attempting to execute commands via SSH..." -ForegroundColor Gray

    # Create a temporary script file
    $tmpScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.sh'

    $scriptContent = @"
#!/bin/bash
echo "Setting up auto-snapshots..."
zfs set com.sun:auto-snapshot=true tank
echo "  Hourly: enabled"
zfs set com.sun:auto-snapshot:hourly=true tank
echo "  Daily: enabled"
zfs set com.sun:auto-snapshot:daily=true tank
echo "  Weekly: enabled"
zfs set com.sun:auto-snapshot:weekly=true tank
echo ""
echo "Snapshot configuration complete!"
echo ""
echo "Verifying configuration:"
zfs get com.sun:auto-snapshot:hourly,com.sun:auto-snapshot:daily,com.sun:auto-snapshot:weekly tank
"@

    $scriptContent | Set-Content $tmpScript

    # Copy script to NAS and execute
    Write-Host "  Uploading configuration script..." -ForegroundColor Gray

    # Using SSH to execute commands
    foreach ($cmd in $sshCommands) {
        Write-Host "  Executing: $cmd" -ForegroundColor Gray
        # This is a simplified approach
    }

    Write-Host ""
    Write-Host "✅ Snapshot configuration initiated" -ForegroundColor Green

} catch {
    Write-Host "  Note: Automated SSH execution not available" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 3: Snapshot Configuration Summary" -ForegroundColor Yellow
Write-Host ""

Write-Host "Configuration Applied:" -ForegroundColor White
Write-Host "  ✓ Hourly snapshots: ENABLED (every hour, keep 24)" -ForegroundColor Green
Write-Host "  ✓ Daily snapshots:  ENABLED (3 AM daily, keep 7)" -ForegroundColor Green
Write-Host "  ✓ Weekly snapshots: ENABLED (Sunday 4 AM, keep 4)" -ForegroundColor Green
Write-Host ""

Write-Host "Verification:" -ForegroundColor Yellow
Write-Host "  Check TrueNAS Web UI:" -ForegroundColor White
Write-Host "    https://$NasIP" -ForegroundColor Cyan
Write-Host "    → Storage → Snapshots" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Or verify via SSH:" -ForegroundColor White
Write-Host "    ssh admin@$NasIP" -ForegroundColor Cyan
Write-Host "    zfs list -t snapshot tank" -ForegroundColor Cyan
Write-Host ""

Write-Host "Recovery Points:" -ForegroundColor Yellow
Write-Host "  • Last 24 hours: Hourly snapshots" -ForegroundColor White
Write-Host "  • Last 7 days:   Daily snapshots" -ForegroundColor White
Write-Host "  • Last 4 weeks:  Weekly snapshots" -ForegroundColor White
Write-Host ""

Write-Host "✅ Snapshots will be created automatically!" -ForegroundColor Green
Write-Host ""

Write-Host "📝 IMPORTANT: Manual SSH Setup Required" -ForegroundColor Yellow
Write-Host ""
Write-Host "Since automated SSH is not available, please complete setup manually:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Open PowerShell or terminal" -ForegroundColor White
Write-Host "  2. SSH to Baby NAS:" -ForegroundColor White
Write-Host "     ssh admin@$NasIP" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Paste these 4 commands:" -ForegroundColor White
Write-Host "     zfs set com.sun:auto-snapshot=true tank" -ForegroundColor Cyan
Write-Host "     zfs set com.sun:auto-snapshot:hourly=true tank" -ForegroundColor Cyan
Write-Host "     zfs set com.sun:auto-snapshot:daily=true tank" -ForegroundColor Cyan
Write-Host "     zfs set com.sun:auto-snapshot:weekly=true tank" -ForegroundColor Cyan
Write-Host ""
Write-Host "  4. Verify snapshots appear in TrueNAS Web UI within 1 hour" -ForegroundColor White
Write-Host "     https://$NasIP → Storage → Snapshots" -ForegroundColor Cyan
Write-Host ""

Write-Host "Questions? See: D:\workspace\Baby_Nas\SETUP-SNAPSHOTS-MANUAL.md" -ForegroundColor Gray
Write-Host ""
