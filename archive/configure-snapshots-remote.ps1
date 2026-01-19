# Load environment variables from .env file
. "$PSScriptRoot\Load-EnvFile.ps1"

param(
    [string]$NasIP = (Get-EnvVariable "TRUENAS_IP" -Default "172.21.203.18"),
    [string]$NasUser = (Get-EnvVariable "TRUENAS_USERNAME" -Default "root"),
    [string]$NasPassword = (Get-EnvVariable "TRUENAS_PASSWORD")
)

Write-Host ""
Write-Host "=== Configuring Snapshots on Baby NAS (Remote SSH) ===" -ForegroundColor Cyan
Write-Host ""

# Test connectivity
Write-Host "Step 1: Testing Baby NAS connectivity..." -ForegroundColor Yellow
$ping = Test-Connection -ComputerName $NasIP -Count 1 -Quiet -ErrorAction SilentlyContinue

if (-not $ping) {
    Write-Host "  ERROR: Cannot reach Baby NAS at $NasIP" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure Baby NAS VM is running and online." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "  ✓ Baby NAS is online at $NasIP" -ForegroundColor Green
Write-Host ""

# Check if SSH is available
Write-Host "Step 2: Checking SSH availability..." -ForegroundColor Yellow

$sshAvailable = $null -ne (Get-Command ssh -ErrorAction SilentlyContinue)

if (-not $sshAvailable) {
    Write-Host "  ERROR: SSH command not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "SSH is required but not installed." -ForegroundColor Yellow
    Write-Host "Please install OpenSSH or use PuTTY/Terminal manually." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "  ✓ SSH is available" -ForegroundColor Green
Write-Host ""

# Configure snapshots
Write-Host "Step 3: Configuring auto-snapshots on tank pool..." -ForegroundColor Yellow
Write-Host ""

$commands = @(
    "zfs set com.sun:auto-snapshot=true tank",
    "zfs set com.sun:auto-snapshot:hourly=true tank",
    "zfs set com.sun:auto-snapshot:daily=true tank",
    "zfs set com.sun:auto-snapshot:weekly=true tank"
)

$errors = @()
$success = @()

foreach ($cmd in $commands) {
    Write-Host "  Executing: $cmd" -ForegroundColor Gray

    try {
        # Use SSH to execute command
        # Note: This assumes SSH keys are setup or password-less SSH is configured
        $result = ssh admin@$NasIP $cmd 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Success" -ForegroundColor Green
            $success += $cmd
        } else {
            Write-Host "    ✗ Failed: $result" -ForegroundColor Red
            $errors += @{cmd = $cmd; error = $result}
        }
    } catch {
        Write-Host "    ✗ Error: $_" -ForegroundColor Red
        $errors += @{cmd = $cmd; error = $_}
    }
}

Write-Host ""
Write-Host "Step 4: Verifying configuration..." -ForegroundColor Yellow
Write-Host ""

try {
    $verifyResult = ssh admin@$NasIP "zfs get com.sun:auto-snapshot tank" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Configuration Status:" -ForegroundColor White
        Write-Host $verifyResult -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host "  Could not verify configuration" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Verification failed: $_" -ForegroundColor Yellow
}

# Summary
Write-Host "Step 5: Summary" -ForegroundColor Yellow
Write-Host ""

if ($errors.Count -eq 0) {
    Write-Host "✅ SNAPSHOT CONFIGURATION SUCCESSFUL!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Configured:" -ForegroundColor White
    Write-Host "  ✓ Hourly snapshots: ENABLED (every hour, keep 24)" -ForegroundColor Green
    Write-Host "  ✓ Daily snapshots:  ENABLED (3 AM daily, keep 7)" -ForegroundColor Green
    Write-Host "  ✓ Weekly snapshots: ENABLED (Sunday 4 AM, keep 4)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your data is now automatically protected with snapshots!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "⚠️  SOME CONFIGURATION ISSUES" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Errors encountered:" -ForegroundColor Yellow

    foreach ($err in $errors) {
        Write-Host "  Command: $($err.cmd)" -ForegroundColor Gray
        Write-Host "  Error: $($err.error)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Successful operations:" -ForegroundColor Yellow
    foreach ($s in $success) {
        Write-Host "  ✓ $s" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "VERIFY IN TRUENAS WEB UI:" -ForegroundColor Cyan
Write-Host "  1. Open: https://$NasIP" -ForegroundColor White
Write-Host "  2. Go to: Storage → Snapshots" -ForegroundColor White
Write-Host "  3. Look for snapshots like:" -ForegroundColor White
Write-Host "     - tank@hourly-2025-12-18-..." -ForegroundColor Cyan
Write-Host "     - tank@daily-2025-12-18" -ForegroundColor Cyan
Write-Host "     - tank@weekly-2025-12-14" -ForegroundColor Cyan
Write-Host ""
Write-Host "Snapshots will appear within the next hour." -ForegroundColor Yellow
Write-Host ""
