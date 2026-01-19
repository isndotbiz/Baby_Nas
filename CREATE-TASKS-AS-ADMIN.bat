@echo off
echo Creating scheduled tasks...
echo.

cd /d D:\workspace\Baby_Nas\backup-scripts

echo [1/2] Creating Workspace-Restic-Backup task...
powershell.exe -ExecutionPolicy Bypass -File "create-backup-task.ps1"
echo.

echo [2/2] Creating Workspace-NAS-Sync task...
powershell.exe -ExecutionPolicy Bypass -File "create-sync-task.ps1"
echo.

echo Done!
echo.
pause
