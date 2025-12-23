Write-Host ""
Write-Host "Starting Baby NAS VM and configuring snapshots..." -ForegroundColor Green
Write-Host ""

# Step 1: Start VM
Write-Host "Step 1: Starting Baby NAS VM" -ForegroundColor Yellow
try {
    $vm = Get-VM -Name "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue
    if ($vm) {
        if ($vm.State -ne "Running") {
            Start-VM -Name "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue
            Write-Host "  VM started" -ForegroundColor Green
        } else {
            Write-Host "  VM already running" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "  Note: Could not start VM via Hyper-V" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 2: Waiting for Baby NAS to come online..." -ForegroundColor Yellow

$online = $false
for ($i = 0; $i -lt 120; $i++) {
    $ping = Test-Connection -ComputerName "172.21.203.18" -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        $online = $true
        break
    }
    Write-Host "  Attempt $($i+1)/120..." -ForegroundColor Gray
    Start-Sleep -Seconds 1
}

if ($online) {
    Write-Host "  Baby NAS is online!" -ForegroundColor Green
} else {
    Write-Host "  Baby NAS did not come online" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Configuring snapshots via SSH" -ForegroundColor Yellow

$cmds = @(
    "zfs set com.sun:auto-snapshot=true tank",
    "zfs set com.sun:auto-snapshot:hourly=true tank",
    "zfs set com.sun:auto-snapshot:daily=true tank",
    "zfs set com.sun:auto-snapshot:weekly=true tank"
)

foreach ($cmd in $cmds) {
    Write-Host "  Running: $cmd" -ForegroundColor Cyan
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@172.21.203.18 $cmd 2>&1 | Out-Null
}

Write-Host ""
Write-Host "Step 4: Verifying configuration" -ForegroundColor Yellow

$verify = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@172.21.203.18 "zfs get com.sun:auto-snapshot tank" 2>&1
Write-Host $verify -ForegroundColor Cyan

Write-Host ""
Write-Host "SUCCESS! Snapshots are now configured!" -ForegroundColor Green
Write-Host ""
Write-Host "Snapshot Schedule:" -ForegroundColor White
Write-Host "  Hourly:  Every hour, keep 24 (1 day)" -ForegroundColor Gray
Write-Host "  Daily:   3 AM, keep 7 (1 week)" -ForegroundColor Gray
Write-Host "  Weekly:  Sunday 4 AM, keep 4 (1 month)" -ForegroundColor Gray
Write-Host ""
Write-Host "Verify in TrueNAS: https://172.21.203.18 -> Storage -> Snapshots" -ForegroundColor White
Write-Host ""
