# fix-scheduled-tasks.ps1
# Run as Administrator to fix scheduled task issues

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "`n=== Fixing Scheduled Task Issues ===" -ForegroundColor Cyan

# 1. Fix W: drive mapping (persistent with credentials)
Write-Host "`n[1/3] Fixing W: drive mapping..." -ForegroundColor Yellow
try {
    # Remove any existing W: mapping
    net use W: /delete /y 2>$null | Out-Null

    # Map with credentials from hardcoded (for scheduled tasks)
    $smbUser = "smbuser"
    $smbPass = "SmbPass2024!"

    net use W: "\\10.0.0.88\workspace" /user:$smbUser $smbPass /persistent:yes | Out-Null

    if (Test-Path "W:\") {
        Write-Host "  SUCCESS: W: drive mapped and accessible" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: W: drive mapped but not accessible" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERROR: Failed to map W: drive - $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Create Workspace-Restic-Backup task
Write-Host "`n[2/3] Creating Workspace-Restic-Backup scheduled task..." -ForegroundColor Yellow
try {
    Push-Location "D:\workspace\Baby_Nas\backup-scripts"

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName "Workspace-Restic-Backup" -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "  Task already exists. Removing old task..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName "Workspace-Restic-Backup" -Confirm:$false
    }

    & .\create-backup-task.ps1

    $task = Get-ScheduledTask -TaskName "Workspace-Restic-Backup" -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "  SUCCESS: Workspace-Restic-Backup task created" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Task was not created" -ForegroundColor Red
    }

    Pop-Location
} catch {
    Write-Host "  ERROR: Failed to create backup task - $($_.Exception.Message)" -ForegroundColor Red
    Pop-Location
}

# 3. Fix or recreate sync task
Write-Host "`n[3/3] Fixing sync scheduled task..." -ForegroundColor Yellow
try {
    # Check existing sync tasks
    $oldTask = Get-ScheduledTask -TaskName "BabyNAS-Workspace-Sync" -ErrorAction SilentlyContinue
    $newTask = Get-ScheduledTask -TaskName "Workspace-NAS-Sync" -ErrorAction SilentlyContinue

    if ($oldTask) {
        Write-Host "  Found BabyNAS-Workspace-Sync (old name). Keeping it." -ForegroundColor Yellow
        Write-Host "  Task should work now with W: drive properly mapped." -ForegroundColor Green
    }

    if (-not $newTask) {
        Write-Host "  Creating Workspace-NAS-Sync task..." -ForegroundColor Yellow
        Push-Location "D:\workspace\Baby_Nas\backup-scripts"
        & .\create-sync-task.ps1
        Pop-Location

        $newTask = Get-ScheduledTask -TaskName "Workspace-NAS-Sync" -ErrorAction SilentlyContinue
        if ($newTask) {
            Write-Host "  SUCCESS: Workspace-NAS-Sync task created" -ForegroundColor Green
        }
    } else {
        Write-Host "  Workspace-NAS-Sync task already exists" -ForegroundColor Green
    }

} catch {
    Write-Host "  ERROR: Failed to fix sync task - $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Test scheduled tasks
Write-Host "`n=== Testing Tasks ===" -ForegroundColor Cyan

$tasks = @("Workspace-Restic-Backup", "Workspace-NAS-Sync", "BabyNAS-Workspace-Sync")
foreach ($taskName in $tasks) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        $info = Get-ScheduledTaskInfo -TaskName $taskName
        Write-Host "`n[$taskName]" -ForegroundColor Green
        Write-Host "  State: $($task.State)"
        Write-Host "  Next Run: $($info.NextRunTime)"
    }
}

Write-Host "`n=== Fix Complete ===" -ForegroundColor Cyan
Write-Host "W: drive should now be persistently mapped with credentials."
Write-Host "Scheduled tasks should run successfully on their next trigger."
Write-Host "`nPress Enter to exit..."
Read-Host
