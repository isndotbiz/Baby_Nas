# create-sync-task.ps1
# Create scheduled task for automated workspace sync to Baby NAS
# Run this script as Administrator

[CmdletBinding()]
param(
    [int]$IntervalMinutes = 60,    # Sync every hour by default
    [switch]$Mirror,                # Use mirror mode (deletes extras on destination)
    [switch]$Uninstall              # Remove the scheduled task
)

$taskName = "BabyNAS-Workspace-Sync"
$scriptPath = "D:\workspace\Baby_Nas\backup-scripts\sync-wrapper.ps1"
$workingDir = "D:\workspace\Baby_Nas\backup-scripts"

# Check for admin rights
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

if ($Uninstall) {
    Write-Host "Removing scheduled task '$taskName'..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Task removed successfully." -ForegroundColor Green
    exit 0
}

# Verify script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: Sync script not found at: $scriptPath" -ForegroundColor Red
    exit 1
}

# Remove existing task if present
Write-Host "Checking for existing task..." -ForegroundColor Cyan
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Build PowerShell arguments
$psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
if ($Mirror) {
    $psArgs += " -Mirror -Force"
}

# Create action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument $psArgs `
    -WorkingDirectory $workingDir

# Create trigger - runs every N minutes
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(5) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -MultipleInstances IgnoreNew

# Run as current user (needed for network drive access and 1Password CLI)
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType S4U `
    -RunLevel Highest

# Register the task
Write-Host "Creating scheduled task '$taskName'..." -ForegroundColor Cyan
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Sync D:\workspace to Baby NAS every $IntervalMinutes minutes. $(if($Mirror){'Mirror mode - deletes extras on NAS.'}else{'Copy mode - preserves NAS extras.'})"

# Verify creation
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host ""
    Write-Host "SUCCESS: Scheduled task created!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  Name:     $taskName"
    Write-Host "  Interval: Every $IntervalMinutes minutes"
    Write-Host "  Mode:     $(if($Mirror){'MIRROR (syncs deletions)'}else{'COPY (preserves destination)'})"
    Write-Host "  Script:   $scriptPath"
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Cyan
    Write-Host "  Run now:     Start-ScheduledTask -TaskName '$taskName'"
    Write-Host "  Check status: Get-ScheduledTaskInfo -TaskName '$taskName'"
    Write-Host "  Remove:      .\create-sync-task.ps1 -Uninstall"
    Write-Host ""
} else {
    Write-Host "ERROR: Task creation failed!" -ForegroundColor Red
    exit 1
}
