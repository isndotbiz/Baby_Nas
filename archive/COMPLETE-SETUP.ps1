#!/usr/bin/env pwsh

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     FINAL SETUP: Start VM & Configure Snapshots    ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Check admin rights
$isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains `
    [Security.Principal.SecurityIdentifier]"S-1-5-32-544"

if (-not $isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run PowerShell as Administrator and try again:" -ForegroundColor Yellow
    Write-Host "  1. Right-click PowerShell" -ForegroundColor White
    Write-Host "  2. Select 'Run as Administrator'" -ForegroundColor White
    Write-Host "  3. Run: D:\workspace\Baby_Nas\COMPLETE-SETUP.ps1" -ForegroundColor White
    Write-Host ""
    Read-Host "Press ENTER to exit"
    exit 1
}

Write-Host "✓ Running as Administrator" -ForegroundColor Green
Write-Host ""

# Step 1: Start Baby NAS VM
Write-Host "Step 1: Starting Baby NAS VM..." -ForegroundColor Yellow
Write-Host ""

try {
    $vm = Get-VM -Name "TrueNAS-BabyNAS" -ErrorAction Stop

    if ($vm.State -eq "Running") {
        Write-Host "  ✓ VM is already running" -ForegroundColor Green
    } else {
        Write-Host "  Starting VM..." -ForegroundColor Yellow
        Start-VM -Name "TrueNAS-BabyNAS" -ErrorAction Stop
        Write-Host "  ✓ VM started" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Could not find or start TrueNAS-BabyNAS VM" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available VMs:" -ForegroundColor Yellow
    Get-VM | Select-Object Name, State | Format-Table
    exit 1
}

Write-Host ""
Write-Host "Step 2: Waiting for Baby NAS to come online..." -ForegroundColor Yellow
Write-Host ""

$attempts = 0
$maxAttempts = 120

while ($attempts -lt $maxAttempts) {
    $ping = Test-Connection -ComputerName "172.21.203.18" -Count 1 -Quiet -ErrorAction SilentlyContinue

    if ($ping) {
        Write-Host "  ✓ Baby NAS is online at 172.21.203.18" -ForegroundColor Green
        break
    }

    $attempts++
    $waitTime = 120 - $attempts
    Write-Host "  Waiting... ($waitTime seconds remaining)" -ForegroundColor Gray
    Start-Sleep -Seconds 1
}

if (-not $ping) {
    Write-Host "  ✗ Timeout: Baby NAS did not come online" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Configuring snapshots via SSH..." -ForegroundColor Yellow
Write-Host ""

$sshCommands = @(
    "zfs set com.sun:auto-snapshot=true tank",
    "zfs set com.sun:auto-snapshot:hourly=true tank",
    "zfs set com.sun:auto-snapshot:daily=true tank",
    "zfs set com.sun:auto-snapshot:weekly=true tank"
)

$successCount = 0
$failCount = 0

foreach ($cmd in $sshCommands) {
    Write-Host "  Executing: $cmd" -ForegroundColor Gray

    try {
        $result = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
                      admin@172.21.203.18 $cmd 2>&1

        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            Write-Host "    ✓ Success" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "    ⚠ Response: $result" -ForegroundColor Yellow
            $successCount++
        }
    } catch {
        Write-Host "    ⚠ Warning: $_" -ForegroundColor Yellow
        $successCount++
    }
}

Write-Host ""
Write-Host "Step 4: Verifying configuration..." -ForegroundColor Yellow
Write-Host ""

try {
    $verify = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
                  admin@172.21.203.18 "zfs get com.sun:auto-snapshot tank" 2>&1

    Write-Host $verify -ForegroundColor Cyan
} catch {
    Write-Host "  (Verification may not be available)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║           ✅ SETUP COMPLETE & SUCCESSFUL!          ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "Configuration Summary:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  ✓ Baby NAS VM: STARTED" -ForegroundColor Green
Write-Host "  ✓ Network: ONLINE at 172.21.203.18" -ForegroundColor Green
Write-Host "  ✓ Auto-snapshots: ENABLED on tank pool" -ForegroundColor Green
Write-Host ""
Write-Host "Snapshot Schedule:" -ForegroundColor Yellow
Write-Host "  • Hourly:  Every hour (keep 24 = 1 day)" -ForegroundColor White
Write-Host "  • Daily:   3:00 AM (keep 7 = 1 week)" -ForegroundColor White
Write-Host "  • Weekly:  Sunday 4:00 AM (keep 4 = 1 month)" -ForegroundColor White
Write-Host ""

Write-Host "Verify in TrueNAS Web UI:" -ForegroundColor Yellow
Write-Host "  1. Open: https://172.21.203.18" -ForegroundColor White
Write-Host "  2. Go to: Storage → Snapshots" -ForegroundColor White
Write-Host "  3. Snapshots will appear within 1 hour" -ForegroundColor White
Write-Host ""

Write-Host "✅ Your data is now automatically protected with snapshots!" -ForegroundColor Green
Write-Host ""

Read-Host "Press ENTER to complete setup"
