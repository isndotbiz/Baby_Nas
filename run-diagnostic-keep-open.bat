@echo off
REM Run Baby NAS diagnostic as Administrator and keep window open
echo Running Baby NAS Diagnostic...
echo This will open a new admin PowerShell window.
echo.
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -NoProfile -Command &{cd D:\workspace\Baby_Nas; .\diagnose-vm-simple.ps1 | Tee-Object -FilePath diagnostic-output.txt; pause}' -WindowStyle Normal"
echo.
echo Diagnostic completed. Output saved to:
echo D:\workspace\Baby_Nas\diagnostic-output.txt
echo.
pause
