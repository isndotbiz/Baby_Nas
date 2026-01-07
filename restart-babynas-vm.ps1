# Restart Baby NAS VM
# Run as Administrator

Write-Host "=== Restarting Baby NAS VM ===" -ForegroundColor Cyan
Write-Host ""

$vmName = "BabyNAS"

# Check VM status
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Host "ERROR: VM '$vmName' not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available VMs:" -ForegroundColor Yellow
    Get-VM | Select-Object Name, State | Format-Table
    pause
    exit 1
}

Write-Host "Current Status:" -ForegroundColor Yellow
Write-Host "  Name: $($vm.Name)"
Write-Host "  State: $($vm.State)"
Write-Host "  Uptime: $($vm.Uptime)"
Write-Host ""

# Restart VM
Write-Host "Restarting VM..." -ForegroundColor Yellow
Restart-VM -Name $vmName -Force -Confirm:$false

Write-Host "Waiting for VM to restart..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Wait for VM to be running
$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    $vm = Get-VM -Name $vmName
    if ($vm.State -eq "Running") {
        Write-Host "VM is running!" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
    Write-Host "  Waiting... ($elapsed seconds)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Waiting for TrueNAS to boot (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "Testing connectivity to 10.0.0.88..." -ForegroundColor Yellow
Test-Connection -ComputerName 10.0.0.88 -Count 2

Write-Host ""
Write-Host "Baby NAS VM restart complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to close..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
