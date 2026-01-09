# create-backup-task.ps1
# Create scheduled task for automated workspace backups

$taskName = "Workspace-Restic-Backup"
$scriptPath = "D:\workspace\Baby_Nas\backup-scripts\backup-wrapper.ps1"
$workingDir = "D:\workspace\Baby_Nas\backup-scripts"

Write-Host "=== Creating Workspace Backup Scheduled Task ===" -ForegroundColor Cyan

# Check if old task exists and remove it
$oldTaskName = "BabyNAS-Restic-Backup"
if (Get-ScheduledTask -TaskName $oldTaskName -ErrorAction SilentlyContinue) {
    Write-Host "Removing old task: $oldTaskName" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $oldTaskName -Confirm:$false -ErrorAction SilentlyContinue
}

# Remove existing task if present
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Create new task
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
    -WorkingDirectory $workingDir

# Trigger: Every 30 minutes, indefinitely
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)

# Settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# Run as SYSTEM or current user with highest privileges
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register task
Register-ScheduledTask -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Automated Restic backup of D:\workspace every 30 minutes"

Write-Host "`nScheduled task '$taskName' created successfully" -ForegroundColor Green
Write-Host "Backups will run every 30 minutes starting now" -ForegroundColor Cyan
Write-Host "`nBackup scope: D:\workspace (entire workspace directory)" -ForegroundColor White
Write-Host "Repository: D:\backups\workspace_restic" -ForegroundColor White
