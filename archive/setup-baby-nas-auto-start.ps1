<#
.SYNOPSIS
Configures Windows Task Scheduler to auto-start Baby NAS VM on system boot.

.DESCRIPTION
Creates a scheduled task that automatically starts the TrueNAS-BabyNAS VM
whenever Windows boots up. The VM runs headless in the background.

Options:
- Auto-start on system boot (recommended)
- Manual start command
- View/remove existing task

.PARAMETER Action
Action to perform: Setup, Remove, or View (default: Setup).

.PARAMETER AtStartup
Trigger task at system startup (default: true).

.PARAMETER AtLogon
Trigger task when user logs on (alternative to AtStartup).

.PARAMETER Disable
Create task but leave it disabled (for manual testing).

.EXAMPLE
# Setup auto-start on system boot
.\setup-baby-nas-auto-start.ps1

# View current task configuration
.\setup-baby-nas-auto-start.ps1 -Action View

# Remove the scheduled task
.\setup-baby-nas-auto-start.ps1 -Action Remove

# Create task but disable it initially
.\setup-baby-nas-auto-start.ps1 -Disable

.NOTES
Requires: Administrator privileges
Task name: "Start Baby NAS VM (Headless)"
Log location: C:\Logs\
#>

param(
    [ValidateSet("Setup", "Remove", "View")]
    [string]$Action = "Setup",
    [switch]$AtStartup = $true,
    [switch]$AtLogon,
    [switch]$Disable
)

# Task configuration
$TaskName = "Start Baby NAS VM (Headless)"
$TaskDescription = "Automatically starts the TrueNAS-BabyNAS Hyper-V VM in headless mode"
$ScriptPath = Join-Path $PSScriptRoot "start-baby-nas-headless.ps1"
$LogDir = "C:\Logs"

function Check-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "Gray" }
    }

    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Setup-ScheduledTask {
    Write-Status "Setting up scheduled task: $TaskName" INFO
    Write-Status ""

    # Check script exists
    if (-not (Test-Path $ScriptPath)) {
        Write-Status "Error: Script not found at $ScriptPath" ERROR
        return $false
    }

    Write-Status "Script path: $ScriptPath" INFO

    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Status "Task already exists. Updating..." WARNING
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }

    try {
        # Create task action
        $action = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -NoWait"

        # Determine trigger
        if ($AtLogon) {
            Write-Status "Trigger: On user logon" INFO
            $trigger = New-ScheduledTaskTrigger -AtLogOn
        } else {
            Write-Status "Trigger: At system startup" INFO
            $trigger = New-ScheduledTaskTrigger -AtStartup
        }

        # Create task settings
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -MultipleInstances IgnoreNew `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable

        # Register task
        $taskPrincipal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -RunLevel Highest

        $task = New-ScheduledTask `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $taskPrincipal `
            -Description $TaskDescription

        Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

        Write-Status "✓ Task created successfully" SUCCESS

        # Disable if requested
        if ($Disable) {
            Disable-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue | Out-Null
            Write-Status "⚠ Task created but disabled (enable when ready)" WARNING
        } else {
            Write-Status "✓ Task is enabled and will run at next startup" SUCCESS
        }

        Write-Status ""
        Write-Status "Configuration:" INFO
        Write-Status "  Task Name: $TaskName" INFO
        Write-Status "  Script: $ScriptPath" INFO
        Write-Status "  Run As: SYSTEM (highest privileges)" INFO
        Write-Status "  Status: $(if ($Disable) { 'DISABLED' } else { 'ENABLED' })" INFO
        Write-Status ""
        Write-Status "The Baby NAS VM will now start automatically on system boot!" SUCCESS

        return $true
    } catch {
        Write-Status "Error creating task: $($_.Exception.Message)" ERROR
        return $false
    }
}

function View-ScheduledTask {
    Write-Status "Looking for scheduled task: $TaskName" INFO
    Write-Status ""

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if (-not $task) {
        Write-Status "✗ Task not found" WARNING
        Write-Status "Use: .\setup-baby-nas-auto-start.ps1 -Action Setup" INFO
        return
    }

    Write-Status "✓ Task found!" SUCCESS
    Write-Status ""

    $task | Select-Object TaskName, State, Description | Format-List | Out-Host

    Write-Status "Task Actions:" INFO
    $task.Actions | ForEach-Object {
        Write-Status "  Type: $($_.CimClass.CimClassName)" INFO
        Write-Status "  Execute: $($_.Execute)" INFO
        if ($_.Arguments) {
            Write-Status "  Arguments: $($_.Arguments)" INFO
        }
    }

    Write-Status ""
    Write-Status "Triggers:" INFO
    $task.Triggers | ForEach-Object {
        Write-Status "  Type: $($_.CimClass.CimClassName)" INFO
        if ($_.StartBoundary) {
            Write-Status "  Starts: $($_.StartBoundary)" INFO
        }
    }

    Write-Status ""
    Write-Status "Last Run:" INFO
    $lastRun = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($lastRun) {
        Write-Status "  Last Run Time: $($lastRun.LastRunTime)" INFO
        Write-Status "  Last Run Result: $($lastRun.LastTaskResult)" INFO
        Write-Status "  Next Run Time: $($lastRun.NextRunTime)" INFO
    }

    Write-Status ""
    Write-Status "Available Commands:" INFO
    Write-Status "  Enable task: Enable-ScheduledTask -TaskName `"$TaskName`"" INFO
    Write-Status "  Disable task: Disable-ScheduledTask -TaskName `"$TaskName`"" INFO
    Write-Status "  View logs: Get-EventLog -LogName System -Source TaskScheduler" INFO
}

function Remove-ScheduledTask {
    Write-Status "Removing scheduled task: $TaskName" INFO
    Write-Status ""

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if (-not $task) {
        Write-Status "✗ Task not found" WARNING
        return
    }

    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop | Out-Null
        Write-Status "✓ Task removed successfully" SUCCESS
        Write-Status ""
        Write-Status "The Baby NAS VM will no longer auto-start." WARNING
        Write-Status "To restore: .\setup-baby-nas-auto-start.ps1 -Action Setup" INFO
    } catch {
        Write-Status "Error removing task: $($_.Exception.Message)" ERROR
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-Host "Baby NAS Auto-Start Task Scheduler Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check admin rights
if (-not (Check-AdminRights)) {
    Write-Status "Error: This script requires Administrator privileges" ERROR
    Write-Status "Please run PowerShell as Administrator and try again" ERROR
    exit 1
}

# Verify script directory
New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction SilentlyContinue | Out-Null

# Execute requested action
switch ($Action) {
    "Setup" { Setup-ScheduledTask | Out-Null }
    "View" { View-ScheduledTask }
    "Remove" { Remove-ScheduledTask }
}

Write-Status ""
