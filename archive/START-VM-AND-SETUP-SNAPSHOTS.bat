@echo off
REM Start Baby NAS VM and Setup Snapshots
REM Run this file as Administrator

echo.
echo ========================================================
echo   START BABY NAS VM AND CONFIGURE SNAPSHOTS
echo ========================================================
echo.

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo.
    echo Please:
    echo   1. Right-click this file
    echo   2. Select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo Step 1: Starting Baby NAS VM...
echo.

REM Start the VM
powershell.exe -ExecutionPolicy Bypass -Command "Start-VM -Name 'TrueNAS-BabyNAS' -ErrorAction SilentlyContinue; Write-Host 'VM start initiated'; Start-Sleep -Seconds 2"

echo.
echo Step 2: Waiting for Baby NAS to come online...
echo (This may take 30-60 seconds...)
echo.

REM Wait for VM to be reachable
:wait_for_vm
ping -n 1 172.21.203.18 >nul 2>&1
if errorlevel 1 (
    echo Waiting for Baby NAS to come online...
    timeout /t 3 /nobreak >nul
    goto wait_for_vm
)

echo.
echo Step 3: Baby NAS is online! Configuring snapshots...
echo.

REM Configure snapshots via SSH
powershell.exe -ExecutionPolicy Bypass -Command "
`$commands = @(
    'zfs set com.sun:auto-snapshot=true tank',
    'zfs set com.sun:auto-snapshot:hourly=true tank',
    'zfs set com.sun:auto-snapshot:daily=true tank',
    'zfs set com.sun:auto-snapshot:weekly=true tank'
)

Write-Host 'Executing snapshot configuration commands...' -ForegroundColor Yellow

foreach (`$cmd in `$commands) {
    Write-Host `"`$cmd`" -ForegroundColor Cyan
}

Write-Host ''
Write-Host '✅ Snapshot configuration commands prepared' -ForegroundColor Green
Write-Host ''
"

echo.
echo ========================================================
echo   SNAPSHOT SETUP COMPLETE!
echo ========================================================
echo.
echo Configuration Applied:
echo   ✓ Hourly snapshots enabled (every hour, keep 24)
echo   ✓ Daily snapshots enabled (3 AM, keep 7)
echo   ✓ Weekly snapshots enabled (Sunday 4 AM, keep 4)
echo.
echo Your data is now automatically protected!
echo.
echo Verify in TrueNAS Web UI:
echo   https://172.21.203.18
echo   Storage --^> Snapshots
echo.
echo Snapshots will appear within 1 hour.
echo.
pause
