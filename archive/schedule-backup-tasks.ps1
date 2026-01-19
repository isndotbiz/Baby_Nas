#Requires -RunAsAdministrator
###############################################################################
# Schedule Backup Tasks Script
# Purpose: Create Windows scheduled tasks for automated backups and monitoring
# Usage: .\schedule-backup-tasks.ps1
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [switch]$RemoveExisting,

    [Parameter(Mandatory=$false)]
    [string]$BabyNasIP = "",

    [Parameter(Mandatory=$false)]
    [string]$EmailTo = "",

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

###############################################################################
# CONFIGURATION
###############################################################################

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptRoot)) {
    $scriptRoot = "D:\workspace\True_Nas\windows-scripts"
}

# Task definitions
$tasks = @(
    @{
        Name = "BabyNAS-DailyWorkspaceBackup"
        Description = "Daily backup of D:\workspace to Baby NAS"
        Script = Join-Path $scriptRoot "backup-workspace.ps1"
        Schedule = @{
            Time = "00:30"  # 12:30 AM
            Days = @("Daily")
        }
        Arguments = ""
        Priority = "High"
    },
    @{
        Name = "BabyNAS-DailyHealthCheck"
        Description = "Daily health check of Baby NAS infrastructure"
        Script = Join-Path $scriptRoot "daily-health-check.ps1"
        Schedule = @{
            Time = "08:00"  # 8:00 AM
            Days = @("Daily")
        }
        Arguments = ""
        Priority = "Normal"
    },
    @{
        Name = "BabyNAS-WeeklyRecoveryTest"
        Description = "Weekly recovery test to verify backup integrity"
        Script = Join-Path $scriptRoot "test-recovery.ps1"
        Schedule = @{
            Time = "06:00"  # 6:00 AM
            Days = @("Sunday")
        }
        Arguments = "-CleanupAfterTest"
        Priority = "Normal"
    },
    @{
        Name = "BabyNAS-HourlyMonitor"
        Description = "Hourly quick health monitoring"
        Script = Join-Path $scriptRoot "monitor-baby-nas.ps1"
        Schedule = @{
            Time = "00:00"  # Every hour
            Days = @("Hourly")
        }
        Arguments = ""
        Priority = "Low"
        Enabled = $false  # Disabled by default - enable manually if needed
    }
)

###############################################################################
# FUNCTIONS
###############################################################################

function Write-TaskLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $color = switch ($Level) {
        'INFO'    { 'White' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
    }

    $symbol = switch ($Level) {
        'SUCCESS' { '✓' }
        'WARNING' { '⚠' }
        'ERROR'   { '✗' }
        'INFO'    { 'ℹ' }
    }

    Write-Host "$symbol $Message" -ForegroundColor $color
}

function Test-ScriptExists {
    param([string]$Path)

    if (Test-Path $Path) {
        return $true
    } else {
        Write-TaskLog "Script not found: $Path" -Level ERROR
        return $false
    }
}

function Remove-ExistingTask {
    param([string]$TaskName)

    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($existing) {
        if ($WhatIf) {
            Write-TaskLog "[WHATIF] Would remove existing task: $TaskName" -Level WARNING
        } else {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-TaskLog "Removed existing task: $TaskName" -Level INFO
        }
        return $true
    }
    return $false
}

function New-BackupScheduledTask {
    param(
        [hashtable]$TaskConfig
    )

    Write-Host ""
    Write-TaskLog "Creating task: $($TaskConfig.Name)" -Level INFO
    Write-TaskLog "Description: $($TaskConfig.Description)" -Level INFO

    # Verify script exists
    if (-not (Test-ScriptExists -Path $TaskConfig.Script)) {
        Write-TaskLog "Skipping task creation - script not found" -Level ERROR
        return $false
    }

    # Remove existing task if requested
    if ($RemoveExisting) {
        Remove-ExistingTask -TaskName $TaskConfig.Name
    } else {
        $existing = Get-ScheduledTask -TaskName $TaskConfig.Name -ErrorAction SilentlyContinue
        if ($existing) {
            Write-TaskLog "Task already exists. Use -RemoveExisting to recreate" -Level WARNING
            return $false
        }
    }

    if ($WhatIf) {
        Write-TaskLog "[WHATIF] Would create scheduled task" -Level WARNING
        Write-TaskLog "  Script: $($TaskConfig.Script)" -Level INFO
        Write-TaskLog "  Schedule: $($TaskConfig.Schedule.Days -join ', ') at $($TaskConfig.Schedule.Time)" -Level INFO
        return $true
    }

    # Create action
    $actionArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$($TaskConfig.Script)`" $($TaskConfig.Arguments)"
    $action = New-ScheduledTaskAction `
        -Execute "PowerShell.exe" `
        -Argument $actionArgs

    # Create trigger based on schedule type
    $trigger = $null
    if ($TaskConfig.Schedule.Days -contains "Hourly") {
        # Hourly task
        $trigger = New-ScheduledTaskTrigger -Once -At $TaskConfig.Schedule.Time -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration ([TimeSpan]::MaxValue)
    } elseif ($TaskConfig.Schedule.Days -contains "Daily") {
        # Daily task
        $trigger = New-ScheduledTaskTrigger -Daily -At $TaskConfig.Schedule.Time
    } else {
        # Weekly task
        $daysOfWeek = $TaskConfig.Schedule.Days -join ','
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek -At $TaskConfig.Schedule.Time
    }

    # Create principal (run as SYSTEM with highest privileges)
    $principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -Priority $TaskConfig.Priority

    # Register task
    try {
        Register-ScheduledTask `
            -TaskName $TaskConfig.Name `
            -Description $TaskConfig.Description `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings | Out-Null

        # Disable if specified
        if ($TaskConfig.Enabled -eq $false) {
            Disable-ScheduledTask -TaskName $TaskConfig.Name | Out-Null
            Write-TaskLog "Task created (DISABLED - enable manually if needed)" -Level SUCCESS
        } else {
            Write-TaskLog "Task created successfully" -Level SUCCESS
        }

        return $true
    } catch {
        Write-TaskLog "Failed to create task: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

###############################################################################
# MAIN SCRIPT
###############################################################################

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                Schedule Baby NAS Backup Tasks                            ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "Script Location: $scriptRoot" -ForegroundColor Gray
Write-Host ""

if ($WhatIf) {
    Write-Host "═══ WHATIF MODE - No changes will be made ═══" -ForegroundColor Yellow
    Write-Host ""
}

###############################################################################
# Pre-flight Checks
###############################################################################

Write-TaskLog "=== Pre-flight Checks ===" -Level INFO
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-TaskLog "This script must be run as Administrator" -Level ERROR
    exit 1
}

Write-TaskLog "Running as Administrator" -Level SUCCESS

# Check if Task Scheduler service is running
$taskScheduler = Get-Service -Name "Schedule" -ErrorAction SilentlyContinue

if ($taskScheduler -and $taskScheduler.Status -eq "Running") {
    Write-TaskLog "Task Scheduler service is running" -Level SUCCESS
} else {
    Write-TaskLog "Task Scheduler service is not running" -Level ERROR
    exit 1
}

# Verify script files exist
Write-Host ""
Write-TaskLog "Verifying script files..." -Level INFO

$allScriptsExist = $true
foreach ($task in $tasks) {
    if (Test-Path $task.Script) {
        Write-TaskLog "Found: $(Split-Path $task.Script -Leaf)" -Level SUCCESS
    } else {
        Write-TaskLog "Missing: $(Split-Path $task.Script -Leaf)" -Level ERROR
        $allScriptsExist = $false
    }
}

if (-not $allScriptsExist) {
    Write-Host ""
    Write-TaskLog "Some script files are missing. Cannot continue." -Level ERROR
    exit 1
}

# Add email parameter if provided
if (-not [string]::IsNullOrEmpty($EmailTo)) {
    Write-Host ""
    Write-TaskLog "Email notifications will be configured for: $EmailTo" -Level INFO

    $tasks | Where-Object { $_.Name -like "*HealthCheck*" -or $_.Name -like "*RecoveryTest*" } | ForEach-Object {
        $_.Arguments += " -SendEmail -EmailTo `"$EmailTo`""
    }
}

# Add Baby NAS IP if provided
if (-not [string]::IsNullOrEmpty($BabyNasIP)) {
    Write-Host ""
    Write-TaskLog "Baby NAS IP will be configured as: $BabyNasIP" -Level INFO

    $tasks | ForEach-Object {
        if ($_.Arguments) {
            $_.Arguments += " -BabyNasIP `"$BabyNasIP`""
        } else {
            $_.Arguments = "-BabyNasIP `"$BabyNasIP`""
        }
    }
}

###############################################################################
# Create Scheduled Tasks
###############################################################################

Write-Host ""
Write-TaskLog "=== Creating Scheduled Tasks ===" -Level INFO

$successCount = 0
$failCount = 0

foreach ($task in $tasks) {
    $result = New-BackupScheduledTask -TaskConfig $task

    if ($result) {
        $successCount++
    } else {
        $failCount++
    }
}

###############################################################################
# Create Log Directories
###############################################################################

Write-Host ""
Write-TaskLog "=== Creating Log Directories ===" -Level INFO

$logDirs = @(
    "C:\Logs\workspace-backup",
    "C:\Logs\daily-health-checks",
    "C:\Logs\recovery-tests"
)

foreach ($dir in $logDirs) {
    if (-not (Test-Path $dir)) {
        if ($WhatIf) {
            Write-TaskLog "[WHATIF] Would create: $dir" -Level WARNING
        } else {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-TaskLog "Created: $dir" -Level SUCCESS
        }
    } else {
        Write-TaskLog "Exists: $dir" -Level INFO
    }
}

###############################################################################
# Summary
###############################################################################

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-TaskLog "=== Task Scheduling Summary ===" -Level INFO
Write-Host ""

if ($WhatIf) {
    Write-TaskLog "WHATIF MODE - No actual changes were made" -Level WARNING
} else {
    Write-TaskLog "Successfully created: $successCount tasks" -Level SUCCESS
    if ($failCount -gt 0) {
        Write-TaskLog "Failed to create: $failCount tasks" -Level ERROR
    }
}

Write-Host ""
Write-Host "Scheduled Tasks:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

foreach ($task in $tasks) {
    $scheduleStr = if ($task.Schedule.Days -contains "Hourly") {
        "Every hour starting at $($task.Schedule.Time)"
    } elseif ($task.Schedule.Days -contains "Daily") {
        "Daily at $($task.Schedule.Time)"
    } else {
        "$($task.Schedule.Days -join ', ') at $($task.Schedule.Time)"
    }

    $statusStr = if ($task.Enabled -eq $false) { " (DISABLED)" } else { "" }

    Write-Host ""
    Write-Host "Task: " -NoNewline -ForegroundColor White
    Write-Host "$($task.Name)$statusStr" -ForegroundColor Cyan
    Write-Host "  Schedule: $scheduleStr" -ForegroundColor Gray
    Write-Host "  Script: $(Split-Path $task.Script -Leaf)" -ForegroundColor Gray

    if (-not $WhatIf) {
        $existingTask = Get-ScheduledTask -TaskName $task.Name -ErrorAction SilentlyContinue
        if ($existingTask) {
            $info = Get-ScheduledTaskInfo -TaskName $task.Name -ErrorAction SilentlyContinue
            if ($info) {
                $lastRun = if ($info.LastRunTime) { $info.LastRunTime.ToString('yyyy-MM-dd HH:mm') } else { "Never" }
                $nextRun = if ($info.NextRunTime) { $info.NextRunTime.ToString('yyyy-MM-dd HH:mm') } else { "Not scheduled" }
                Write-Host "  Last run: $lastRun" -ForegroundColor DarkGray
                Write-Host "  Next run: $nextRun" -ForegroundColor DarkGray
            }
        }
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

###############################################################################
# Next Steps
###############################################################################

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. View all scheduled tasks:" -ForegroundColor White
Write-Host "   Get-ScheduledTask | Where-Object { `$_.TaskName -like 'BabyNAS-*' }" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Manually run a task to test:" -ForegroundColor White
Write-Host "   Start-ScheduledTask -TaskName 'BabyNAS-DailyHealthCheck'" -ForegroundColor Gray
Write-Host ""

Write-Host "3. View task history:" -ForegroundColor White
Write-Host "   Get-ScheduledTaskInfo -TaskName 'BabyNAS-DailyHealthCheck'" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Enable the hourly monitor (if needed):" -ForegroundColor White
Write-Host "   Enable-ScheduledTask -TaskName 'BabyNAS-HourlyMonitor'" -ForegroundColor Gray
Write-Host ""

Write-Host "5. Disable a task:" -ForegroundColor White
Write-Host "   Disable-ScheduledTask -TaskName 'BabyNAS-WeeklyRecoveryTest'" -ForegroundColor Gray
Write-Host ""

Write-Host "6. Remove all tasks:" -ForegroundColor White
Write-Host "   Get-ScheduledTask | Where-Object { `$_.TaskName -like 'BabyNAS-*' } | Unregister-ScheduledTask -Confirm:`$false" -ForegroundColor Gray
Write-Host ""

###############################################################################
# Configuration Tips
###############################################################################

Write-Host ""
Write-Host "Configuration Tips:" -ForegroundColor Cyan
Write-Host ""

Write-Host "• Configure email notifications:" -ForegroundColor Yellow
Write-Host "  Edit daily-health-check.ps1 and configure SMTP settings" -ForegroundColor Gray
Write-Host ""

Write-Host "• Adjust backup schedule:" -ForegroundColor Yellow
Write-Host "  Use Task Scheduler UI or modify this script and re-run with -RemoveExisting" -ForegroundColor Gray
Write-Host ""

Write-Host "• Monitor task execution:" -ForegroundColor Yellow
Write-Host "  Check logs in C:\Logs\" -ForegroundColor Gray
Write-Host ""

Write-Host "• Baby NAS IP auto-detection:" -ForegroundColor Yellow
Write-Host "  Scripts will auto-detect Baby NAS VM IP if not specified" -ForegroundColor Gray
Write-Host ""

###############################################################################
# Manual Test Command
###############################################################################

if (-not $WhatIf) {
    Write-Host ""
    Write-Host "Test Tasks Now:" -ForegroundColor Cyan
    Write-Host ""

    $response = Read-Host "Would you like to test the Daily Health Check task now? (y/N)"

    if ($response -match '^[Yy]') {
        Write-Host ""
        Write-TaskLog "Running Daily Health Check task..." -Level INFO
        try {
            Start-ScheduledTask -TaskName "BabyNAS-DailyHealthCheck" -ErrorAction Stop
            Write-TaskLog "Task started successfully" -Level SUCCESS
            Write-Host ""
            Write-Host "Task is running in the background. Check the log in C:\Logs\daily-health-checks\" -ForegroundColor Gray

            Start-Sleep -Seconds 3

            $info = Get-ScheduledTaskInfo -TaskName "BabyNAS-DailyHealthCheck" -ErrorAction SilentlyContinue
            if ($info) {
                Write-Host "Last Run Time: $($info.LastRunTime)" -ForegroundColor Gray
                Write-Host "Last Task Result: $($info.LastTaskResult)" -ForegroundColor Gray
            }
        } catch {
            Write-TaskLog "Failed to start task: $($_.Exception.Message)" -Level ERROR
        }
    }
}

###############################################################################
# Exit
###############################################################################

Write-Host ""
Write-Host "Task scheduling completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

if ($WhatIf) {
    exit 0
} elseif ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}
