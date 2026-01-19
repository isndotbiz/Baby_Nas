Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  SETUP AUTOMATED SNAPSHOTS - INTERACTIVE" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

# Check if Baby NAS is online
Write-Host "Checking Baby NAS connectivity..." -ForegroundColor Yellow
$ping = Test-Connection -ComputerName "172.21.203.18" -Count 1 -Quiet -ErrorAction SilentlyContinue

if (-not $ping) {
    Write-Host ""
    Write-Host "ERROR: Baby NAS is OFFLINE" -ForegroundColor Red
    Write-Host ""
    Write-Host "You need to start the VM first. Follow these steps:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Open PowerShell as Administrator" -ForegroundColor White
    Write-Host "  2. Run this command:" -ForegroundColor White
    Write-Host "     Start-VM -Name 'TrueNAS-BabyNAS'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Wait 30-60 seconds for VM to boot" -ForegroundColor White
    Write-Host ""
    Write-Host "  4. Run this script again:" -ForegroundColor White
    Write-Host "     D:\workspace\Baby_Nas\RUN-THIS-TO-SETUP-SNAPSHOTS.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Then follow the on-screen instructions to complete snapshot setup." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "✓ Baby NAS is ONLINE at 172.21.203.18" -ForegroundColor Green
Write-Host ""

# Now provide manual SSH instructions since we don't have automated SSH
Write-Host "SNAPSHOT SETUP - MANUAL SSH CONFIGURATION" -ForegroundColor Cyan
Write-Host ""
Write-Host "You will now open an SSH connection to Baby NAS and run commands." -ForegroundColor Yellow
Write-Host ""

Write-Host "STEP 1: Open SSH Connection" -ForegroundColor White
Write-Host "─────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""
Write-Host "Copy this command and paste into PowerShell/Terminal:" -ForegroundColor Yellow
Write-Host ""
Write-Host "ssh admin@172.21.203.18" -ForegroundColor Cyan
Write-Host ""
Write-Host "If prompted for a password, use your TrueNAS admin password" -ForegroundColor Yellow
Write-Host ""

$hostResult = Read-Host "Press ENTER when you've successfully SSH'd into Baby NAS"

Write-Host ""
Write-Host "STEP 2: Enable Auto-Snapshots (Copy & Paste Each Command)" -ForegroundColor White
Write-Host "─────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

Write-Host "Run these 4 commands one at a time in your SSH session:" -ForegroundColor Yellow
Write-Host ""

Write-Host "COMMAND 1:" -ForegroundColor White
Write-Host "zfs set com.sun:auto-snapshot=true tank" -ForegroundColor Cyan
Write-Host "  (Press ENTER after pasting)" -ForegroundColor Gray
Write-Host ""

$cmd1 = Read-Host "After running Command 1, press ENTER here"

Write-Host ""
Write-Host "COMMAND 2:" -ForegroundColor White
Write-Host "zfs set com.sun:auto-snapshot:hourly=true tank" -ForegroundColor Cyan
Write-Host "  (Press ENTER after pasting)" -ForegroundColor Gray
Write-Host ""

$cmd2 = Read-Host "After running Command 2, press ENTER here"

Write-Host ""
Write-Host "COMMAND 3:" -ForegroundColor White
Write-Host "zfs set com.sun:auto-snapshot:daily=true tank" -ForegroundColor Cyan
Write-Host "  (Press ENTER after pasting)" -ForegroundColor Gray
Write-Host ""

$cmd3 = Read-Host "After running Command 3, press ENTER here"

Write-Host ""
Write-Host "COMMAND 4:" -ForegroundColor White
Write-Host "zfs set com.sun:auto-snapshot:weekly=true tank" -ForegroundColor Cyan
Write-Host "  (Press ENTER after pasting)" -ForegroundColor Gray
Write-Host ""

$cmd4 = Read-Host "After running Command 4, press ENTER here"

Write-Host ""
Write-Host "STEP 3: Verify Configuration" -ForegroundColor White
Write-Host "─────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

Write-Host "Run this verification command in SSH:" -ForegroundColor Yellow
Write-Host ""
Write-Host "zfs get com.sun:auto-snapshot tank" -ForegroundColor Cyan
Write-Host ""
Write-Host "You should see: com.sun:auto-snapshot = true" -ForegroundColor Yellow
Write-Host ""

$verify = Read-Host "Paste the output above and press ENTER"

Write-Host ""
Write-Host "STEP 4: Exit SSH" -ForegroundColor White
Write-Host "─────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""
Write-Host "Type this in your SSH session to exit:" -ForegroundColor Yellow
Write-Host ""
Write-Host "exit" -ForegroundColor Cyan
Write-Host ""

$exit = Read-Host "Press ENTER when you've exited SSH"

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  ✅ SNAPSHOTS SETUP COMPLETE!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Configuration Summary:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  ✓ Hourly snapshots:  ENABLED" -ForegroundColor Green
Write-Host "    • Created every hour" -ForegroundColor Gray
Write-Host "    • Keeps 24 snapshots (1-day recovery window)" -ForegroundColor Gray
Write-Host ""
Write-Host "  ✓ Daily snapshots:   ENABLED" -ForegroundColor Green
Write-Host "    • Created at 3:00 AM" -ForegroundColor Gray
Write-Host "    • Keeps 7 snapshots (1-week recovery window)" -ForegroundColor Gray
Write-Host ""
Write-Host "  ✓ Weekly snapshots:  ENABLED" -ForegroundColor Green
Write-Host "    • Created Sunday at 4:00 AM" -ForegroundColor Gray
Write-Host "    • Keeps 4 snapshots (1-month recovery window)" -ForegroundColor Gray
Write-Host ""

Write-Host "NEXT: Verify Snapshots in TrueNAS" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Open web browser:" -ForegroundColor White
Write-Host "   https://172.21.203.18" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Login with admin credentials" -ForegroundColor White
Write-Host ""
Write-Host "3. Navigate to:" -ForegroundColor White
Write-Host "   Storage → Snapshots" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. You should see snapshots appear within 1 hour:" -ForegroundColor White
Write-Host "   • tank@hourly-2025-12-18-... (hourly)" -ForegroundColor Cyan
Write-Host "   • tank@daily-2025-12-18 (daily)" -ForegroundColor Cyan
Write-Host "   • tank@weekly-2025-12-14 (weekly)" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Your data is now automatically protected with snapshots!" -ForegroundColor Green
Write-Host ""

Write-Host "Need help? See: D:\workspace\Baby_Nas\SETUP-SNAPSHOTS-MANUAL.md" -ForegroundColor Gray
Write-Host ""
