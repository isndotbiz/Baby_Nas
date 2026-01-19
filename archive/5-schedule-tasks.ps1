# Script 5: Setup Automated Scheduled Tasks
# Purpose: Create all backup-related scheduled tasks
# Run as: Administrator
# Usage: .\5-schedule-tasks.ps1

Write-Host "`n=== Backup Automation Setup ===" -ForegroundColor Cyan
Write-Host "This script will create scheduled tasks for automated backups`n" -ForegroundColor Gray

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Task 1: WSL Weekly Backup
Write-Host "Creating task: WSL Weekly Backup..." -ForegroundColor Yellow

$wslScript = Join-Path $scriptPath "3-backup-wsl.ps1"

if (Test-Path $wslScript) {
    $trigger1 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "01:00AM"
    $action1 = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$wslScript`" -BackupPath `"X:\WSLBackups`""

    $settings1 = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -AllowStartIfOnBatteries:$false `
        -DontStopIfGoingOnBatteries:$false

    try {
        Register-ScheduledTask -TaskName "WSL-Weekly-Backup" `
            -Trigger $trigger1 `
            -Action $action1 `
            -Settings $settings1 `
            -RunLevel Highest `
            -Description "Weekly backup of all WSL distributions" `
            -Force | Out-Null

        Write-Host "  Created: WSL-Weekly-Backup (Sundays at 1:00 AM)" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to create WSL backup task: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  SKIPPED: Script not found: $wslScript" -ForegroundColor Gray
}

# Task 2: Daily Backup Health Check
Write-Host "`nCreating task: Daily Backup Health Check..." -ForegroundColor Yellow

$monitorScript = Join-Path $scriptPath "4-monitor-backups.ps1"

if (Test-Path $monitorScript) {
    $trigger2 = New-ScheduledTaskTrigger -Daily -At "08:00AM"
    $action2 = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$monitorScript`""

    $settings2 = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable

    try {
        Register-ScheduledTask -TaskName "Backup-Health-Check" `
            -Trigger $trigger2 `
            -Action $action2 `
            -Settings $settings2 `
            -RunLevel Highest `
            -Description "Daily backup health monitoring" `
            -Force | Out-Null

        Write-Host "  Created: Backup-Health-Check (Daily at 8:00 AM)" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to create health check task: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  SKIPPED: Script not found: $monitorScript" -ForegroundColor Gray
}

# Display created tasks
Write-Host "`n=== Scheduled Tasks Summary ===" -ForegroundColor Cyan

$tasks = Get-ScheduledTask | Where-Object {
    $_.TaskName -in @("WSL-Weekly-Backup", "Backup-Health-Check")
}

if ($tasks) {
    $tasks | Select-Object TaskName, State, @{N='NextRun';E={(Get-ScheduledTaskInfo $_).NextRunTime}} |
        Format-Table -AutoSize
} else {
    Write-Host "No tasks were created." -ForegroundColor Red
}

# Instructions
Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
Write-Host "1. Verify tasks were created successfully (see above)"
Write-Host "2. Test tasks manually:"
Write-Host "   Start-ScheduledTask -TaskName 'WSL-Weekly-Backup'"
Write-Host "   Start-ScheduledTask -TaskName 'Backup-Health-Check'"
Write-Host "3. Configure Veeam Agent backup schedule separately"
Write-Host "4. Monitor task history in Task Scheduler"

Write-Host "`n=== View Task Details ===" -ForegroundColor Yellow
Write-Host "To view task details, run:"
Write-Host "  Get-ScheduledTask -TaskName 'WSL-Weekly-Backup' | Get-ScheduledTaskInfo"
Write-Host "  Get-ScheduledTask -TaskName 'Backup-Health-Check' | Get-ScheduledTaskInfo"

Write-Host "`n=== Modify Tasks ===" -ForegroundColor Yellow
Write-Host "To modify schedule, use Task Scheduler GUI:"
Write-Host "  taskschd.msc"
Write-Host "Or use PowerShell Set-ScheduledTask cmdlet"

Write-Host "`n"
