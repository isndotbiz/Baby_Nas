# Reduce BabyNAS VM RAM to 8192 MB
# This script modifies the Hyper-V virtual machine memory allocation

param(
    [string]$VmName = "Baby-NAS",
    [long]$NewMemoryMB = 8192,
    [switch]$Force = $false
)

Write-Host "=== BabyNAS VM RAM Reduction ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')

if (-not $isAdmin) {
    Write-Host "Error: This script requires administrator privileges" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again" -ForegroundColor Red
    exit 1
}

Write-Host "1. Finding VM: $VmName..." -ForegroundColor Yellow
$vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Host "   ✗ VM not found" -ForegroundColor Red
    Write-Host "   Available VMs:" -ForegroundColor Yellow
    Get-VM | Select-Object Name, @{N="RAM (MB)";E={$_.MemoryAssigned/1MB}} | Format-Table
    exit 1
}

Write-Host "   ✓ Found: $($vm.Name)" -ForegroundColor Green
Write-Host "   Current State: $($vm.State)" -ForegroundColor Gray

# Check if VM is running
Write-Host ""
Write-Host "2. Checking VM state..." -ForegroundColor Yellow

if ($vm.State -eq "Running") {
    Write-Host "   VM is currently RUNNING" -ForegroundColor Yellow
    Write-Host "   Must shut down VM before reducing RAM" -ForegroundColor Yellow
    Write-Host ""

    if (-not $Force) {
        $response = Read-Host "   Shut down VM? (yes/no)"
        if ($response -ne "yes") {
            Write-Host "   Cancelled" -ForegroundColor Gray
            exit 0
        }
    }

    Write-Host "   Shutting down VM..." -ForegroundColor Yellow
    Stop-VM -VM $vm -Force
    Start-Sleep -Seconds 5
    Write-Host "   ✓ VM shut down" -ForegroundColor Green
} else {
    Write-Host "   VM is STOPPED - Can proceed" -ForegroundColor Green
}

# Get current RAM
Write-Host ""
Write-Host "3. Current VM Configuration..." -ForegroundColor Yellow
$currentMemoryMB = $vm.MemoryAssigned / 1MB
Write-Host "   Current RAM: $([int]$currentMemoryMB) MB" -ForegroundColor Gray
Write-Host "   New RAM: $NewMemoryMB MB" -ForegroundColor Gray
Write-Host "   Reduction: $([int]($currentMemoryMB - $NewMemoryMB)) MB" -ForegroundColor Gray

Write-Host ""
Write-Host "4. Applying new memory setting..." -ForegroundColor Yellow

try {
    $vm | Set-VMMemory -StartupBytes ($NewMemoryMB * 1MB) -ErrorAction Stop
    Write-Host "   ✓ Memory configuration updated" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to update memory" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify the change
$vmUpdated = Get-VM -Name $VmName
$newMemoryMB = $vmUpdated.MemoryAssigned / 1MB

Write-Host ""
Write-Host "5. Verification..." -ForegroundColor Yellow
Write-Host "   New RAM setting: $([int]$newMemoryMB) MB" -ForegroundColor Green

Write-Host ""
Write-Host "✓ Complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the new memory allocation: $([int]$newMemoryMB) MB"
Write-Host "2. Start the VM when ready"
Write-Host ""
Write-Host "To start the VM:"
Write-Host "  Start-VM -Name '$VmName'"
Write-Host ""
Write-Host "To verify RAM after startup:"
Write-Host "  Get-VM -Name '$VmName' | Select-Object Name, @{N='RAM (MB)';E={[int]($_.MemoryAssigned/1MB)}}"
