#Requires -RunAsAdministrator
###############################################################################
# EMERGENCY FIX - Disable Secure Boot on Baby NAS VM
# This fixes the "unsigned image hash not allowed" boot error
###############################################################################

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║                                                          ║" -ForegroundColor Red
Write-Host "║          FIXING SECURE BOOT ISSUE                        ║" -ForegroundColor Red
Write-Host "║                                                          ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

$VMName = "TrueNAS-BabyNAS"

# Step 1: Stop VM
Write-Host "[1/4] Stopping VM..." -ForegroundColor Cyan
try {
    Stop-VM -Name $VMName -Force -ErrorAction Stop
    Write-Host "      ✓ VM stopped" -ForegroundColor Green
} catch {
    Write-Host "      • VM was already stopped" -ForegroundColor Gray
}
Start-Sleep -Seconds 2

# Step 2: Disable Secure Boot (THE FIX!)
Write-Host "[2/4] Disabling Secure Boot..." -ForegroundColor Cyan
try {
    Set-VMFirmware -VMName $VMName -EnableSecureBoot Off -ErrorAction Stop
    Write-Host "      ✓ Secure Boot DISABLED (this was the problem!)" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to disable Secure Boot: $_" -ForegroundColor Red
    exit 1
}
Start-Sleep -Seconds 1

# Step 3: Verify the fix
Write-Host "[3/4] Verifying configuration..." -ForegroundColor Cyan
$firmware = Get-VMFirmware -VMName $VMName
Write-Host "      • Secure Boot: $($firmware.SecureBoot)" -ForegroundColor White
Write-Host "      • Boot Order: $($firmware.BootOrder[0].Device)" -ForegroundColor White

if ($firmware.SecureBoot -eq "Off") {
    Write-Host "      ✓ Configuration verified!" -ForegroundColor Green
} else {
    Write-Host "      ⚠ Warning: Secure Boot still enabled" -ForegroundColor Yellow
}

# Step 4: Start VM
Write-Host "[4/4] Starting VM..." -ForegroundColor Cyan
try {
    Start-VM -Name $VMName -ErrorAction Stop
    Write-Host "      ✓ VM started" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Failed to start VM: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Waiting for VM to boot..." -ForegroundColor Yellow
Start-Sleep -Seconds 8

# Check VM state
$vm = Get-VM -Name $VMName
Write-Host "VM State: $($vm.State)" -ForegroundColor White

# Open console
Write-Host ""
Write-Host "Opening VM console..." -ForegroundColor Cyan
Start-Process "vmconnect.exe" -ArgumentList "localhost", $VMName

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                          ║" -ForegroundColor Green
Write-Host "║                    FIX APPLIED!                          ║" -ForegroundColor Green
Write-Host "║                                                          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "What you should see now in the VM console:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. TrueNAS logo/boot screen (with ASCII art)" -ForegroundColor White
Write-Host "  2. Boot menu with 'Install/Upgrade' option" -ForegroundColor White
Write-Host "  3. TrueNAS installer starting" -ForegroundColor White
Write-Host ""
Write-Host "If you still see the boot error:" -ForegroundColor Yellow
Write-Host "  - Wait 30 seconds for the VM to fully boot" -ForegroundColor White
Write-Host "  - If still showing error, press Ctrl+Alt+Del in VM console" -ForegroundColor White
Write-Host "  - Or run this script again" -ForegroundColor White
Write-Host ""
Write-Host "Once you see the TrueNAS boot menu:" -ForegroundColor Green
Write-Host "  1. Select: Install/Upgrade (press Enter)" -ForegroundColor White
Write-Host "  2. Choose: 32GB OS disk (smallest disk)" -ForegroundColor White
Write-Host "  3. Set password: uppercut%`$##" -ForegroundColor White
Write-Host "  4. Wait: 5-10 minutes" -ForegroundColor White
Write-Host "  5. Reboot when prompted" -ForegroundColor White
Write-Host "  6. Note the IP address shown after reboot" -ForegroundColor White
Write-Host ""
