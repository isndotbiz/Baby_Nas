# Fix Windows SMB Client and Map Baby NAS Drives
# Must run as Administrator

Write-Host "=== Baby NAS Drive Mapping Fix ===" -ForegroundColor Cyan
Write-Host ""

# Enable insecure guest auth (required for some NAS systems)
Write-Host "Enabling insecure guest authentication..." -ForegroundColor Yellow
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f

# Restart workstation service
Write-Host "Restarting workstation service..." -ForegroundColor Yellow
net stop workstation /y
Start-Sleep -Seconds 2
net start workstation
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Mapping drives..." -ForegroundColor Yellow

net use W: \\10.0.0.88\workspace /user:smbuser SmbPass2024! /persistent:yes
net use M: \\10.0.0.88\models /user:smbuser SmbPass2024! /persistent:yes
net use S: \\10.0.0.88\staging /user:smbuser SmbPass2024! /persistent:yes
net use B: \\10.0.0.88\backups /user:smbuser SmbPass2024! /persistent:yes

Write-Host ""
Write-Host "=== Current Mappings ===" -ForegroundColor Cyan
net use

Write-Host ""
Write-Host "Done! Press any key to close..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
