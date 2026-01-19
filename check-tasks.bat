@echo off
echo Checking scheduled tasks...
schtasks /query /tn "Workspace-Restic-Backup" 2>nul
if errorlevel 1 echo Workspace-Restic-Backup: NOT FOUND
schtasks /query /tn "Workspace-NAS-Sync" 2>nul
if errorlevel 1 echo Workspace-NAS-Sync: NOT FOUND
