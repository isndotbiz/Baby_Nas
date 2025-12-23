Write-Host ""
Write-Host "=== Starting Baby NAS VM ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking VM state..." -ForegroundColor Yellow
$vm = Get-VM -Name "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue

if ($vm) {
    if ($vm.State -eq "Running") {
        Write-Host "  Status: Already running" -ForegroundColor Green
    } else {
        Write-Host "  Status: Stopped, starting..." -ForegroundColor Yellow
        Start-VM -Name "TrueNAS-BabyNAS"
        Write-Host "  Status: VM started" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Waiting for network connectivity..." -ForegroundColor Yellow

    $attempts = 0
    $maxAttempts = 60

    while ($attempts -lt $maxAttempts) {
        $attempts++
        $ping = Test-Connection -ComputerName "172.21.203.18" -Count 1 -Quiet -ErrorAction SilentlyContinue

        if ($ping) {
            Write-Host "  OK - Baby NAS is online!" -ForegroundColor Green
            break
        }

        Write-Host "  Attempt $attempts/$maxAttempts - waiting..." -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }

    if ($ping) {
        Write-Host ""
        Write-Host "Baby NAS is ready at 172.21.203.18" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Timeout: Baby NAS did not respond" -ForegroundColor Red
    }
} else {
    Write-Host "VM not found: TrueNAS-BabyNAS" -ForegroundColor Red
}

Write-Host ""
