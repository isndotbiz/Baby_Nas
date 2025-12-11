#Requires -RunAsAdministrator
###############################################################################
# Open TrueNAS VM Console
###############################################################################

$VMName = "TrueNAS-BabyNAS"

Write-Host "=== Opening TrueNAS VM Console ===" -ForegroundColor Cyan
Write-Host ""

# Check VM state
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Host "✗ VM not found: $VMName" -ForegroundColor Red
    exit 1
}

Write-Host "VM: $VMName" -ForegroundColor White
Write-Host "State: $($vm.State)" -ForegroundColor $(if ($vm.State -eq "Running") { "Green" } else { "Yellow" })
Write-Host "Uptime: $($vm.Uptime)" -ForegroundColor Gray
Write-Host ""

if ($vm.State -ne "Running") {
    Write-Host "⚠ VM is not running" -ForegroundColor Yellow
    $start = Read-Host "Start VM now? (yes/no)"

    if ($start -eq "yes") {
        Write-Host "Starting VM..." -ForegroundColor Cyan
        Start-VM -Name $VMName
        Write-Host "Waiting for VM to start..." -ForegroundColor Cyan
        Start-Sleep -Seconds 5
        Write-Host "✓ VM started" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "Please start the VM first: Start-VM -Name '$VMName'" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Opening VM console..." -ForegroundColor Cyan
Write-Host ""

# Open console
vmconnect.exe localhost $VMName

Write-Host ""
Write-Host "=== Console opened ===" -ForegroundColor Green
Write-Host ""
Write-Host "What to look for:" -ForegroundColor Yellow
Write-Host "  • TrueNAS boot menu (select Install/Upgrade)" -ForegroundColor White
Write-Host "  • Login prompt (TrueNAS is installed)" -ForegroundColor White
Write-Host "  • IP address displayed on screen" -ForegroundColor White
Write-Host "  • Any error messages" -ForegroundColor White
Write-Host ""
Write-Host "Default credentials:" -ForegroundColor Yellow
Write-Host "  Username: root" -ForegroundColor White
Write-Host "  Password: uppercut%`$##" -ForegroundColor White
Write-Host ""
