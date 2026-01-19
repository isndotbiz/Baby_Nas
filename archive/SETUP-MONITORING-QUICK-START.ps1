#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Quick Start Setup for Backup Monitoring Infrastructure

.DESCRIPTION
    One-click setup wizard that configures:
    - Directories and logs
    - Alerting configuration
    - Scheduled tasks
    - Initial dashboard test

.PARAMETER InteractiveSetup
    Run interactive setup (default: true)

.EXAMPLE
    .\SETUP-MONITORING-QUICK-START.ps1

.NOTES
    Author: Automated Backup Monitoring System
    Version: 1.0
#>

param(
    [Parameter(Mandatory=$false)]
    [bool]$InteractiveSetup = $true
)

$ErrorActionPreference = "Stop"

###############################################################################
# COLORS AND DISPLAY
###############################################################################

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                                ║" -ForegroundColor Cyan
    Write-Host "║     BACKUP MONITORING INFRASTRUCTURE - QUICK START SETUP        ║" -ForegroundColor Cyan
    Write-Host "║                                                                ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Step {
    param([int]$Number, [string]$Title)
    Write-Host ""
    Write-Host "STEP $Number - $Title" -ForegroundColor Yellow
    Write-Host "─" * 60 -ForegroundColor Yellow
}

function Show-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Show-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Show-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Show-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

###############################################################################
# SETUP FUNCTIONS
###############################################################################

function Create-Directories {
    Show-Step 1 "Creating Directory Structure"

    $directories = @(
        "C:\BackupMonitoring\Config",
        "C:\Logs\BackupMonitoring",
        "C:\Logs\BackupMonitoring\Reports",
        "C:\Logs\BackupMonitoring\Archive"
    )

    foreach ($dir in $directories) {
        try {
            if (-not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Show-Success "Created: $dir"
            } else {
                Show-Info "Already exists: $dir"
            }
        } catch {
            Show-Error "Failed to create $dir : $_"
            return $false
        }
    }

    return $true
}

function Copy-ConfigTemplate {
    Show-Step 2 "Setting Up Configuration Template"

    $templatePath = Join-Path (Split-Path $PSCommandPath) "ALERTING-CONFIG-TEMPLATE.json"
    $targetPath = "C:\BackupMonitoring\Config\alerting-config.json"

    if (-not (Test-Path $templatePath)) {
        Show-Warning "Template not found at $templatePath"
        Show-Info "Configuration will be created during alerting setup"
        return $true
    }

    if (-not (Test-Path $targetPath)) {
        try {
            Copy-Item -Path $templatePath -Destination $targetPath -Force
            Show-Success "Configuration template copied to $targetPath"
        } catch {
            Show-Error "Failed to copy template: $_"
            return $false
        }
    } else {
        Show-Info "Configuration already exists at $targetPath"
    }

    return $true
}

function Test-Prerequisites {
    Show-Step 3 "Checking Prerequisites"

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion.Major
    if ($psVersion -ge 5) {
        Show-Success "PowerShell 5.0+ installed"
    } else {
        Show-Error "PowerShell 5.0+ required (currently $psVersion)"
        return $false
    }

    # Check admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if ($isAdmin) {
        Show-Success "Running with administrator privileges"
    } else {
        Show-Error "Must run as administrator"
        return $false
    }

    # Check .NET Framework
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319") {
        Show-Success ".NET Framework installed"
    }

    # Check network connectivity
    if (Test-Connection 8.8.8.8 -Count 1 -Quiet) {
        Show-Success "Internet connectivity available"
    } else {
        Show-Warning "Internet connectivity not available (webhooks may not work)"
    }

    return $true
}

function Create-ScheduledTasks {
    Show-Step 4 "Creating Scheduled Tasks"

    $scriptPath = Split-Path $PSCommandPath -Parent

    # Daily Health Check Task
    try {
        $taskName = "Daily Backup Health Check"
        $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

        if ($taskExists) {
            Show-Warning "Task '$taskName' already exists, skipping..."
        } else {
            $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath\HEALTH-CHECK-DAILY.ps1`""

            $trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM

            $principal = New-ScheduledTaskPrincipal `
                -UserId "SYSTEM" `
                -LogonType ServiceAccount `
                -RunLevel Highest

            $settings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -RunOnlyIfNetworkAvailable

            Register-ScheduledTask `
                -TaskName $taskName `
                -Action $action `
                -Trigger $trigger `
                -Principal $principal `
                -Settings $settings `
                -Description "Daily backup system health check" `
                -Force | Out-Null

            Show-Success "Created scheduled task: $taskName (runs daily at 6:00 AM)"
        }
    } catch {
        Show-Error "Failed to create health check task: $_"
    }

    # Weekly Metrics Task
    try {
        $taskName = "Weekly Backup Metrics Report"
        $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

        if ($taskExists) {
            Show-Warning "Task '$taskName' already exists, skipping..."
        } else {
            $action = New-ScheduledTaskAction `
                -Execute "powershell.exe" `
                -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath\BACKUP-METRICS-REPORT.ps1`""

            $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 7:00AM

            $principal = New-ScheduledTaskPrincipal `
                -UserId "SYSTEM" `
                -LogonType ServiceAccount `
                -RunLevel Highest

            $settings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -RunOnlyIfNetworkAvailable

            Register-ScheduledTask `
                -TaskName $taskName `
                -Action $action `
                -Trigger $trigger `
                -Principal $principal `
                -Settings $settings `
                -Description "Weekly backup metrics and capacity planning report" `
                -Force | Out-Null

            Show-Success "Created scheduled task: $taskName (runs Mondays at 7:00 AM)"
        }
    } catch {
        Show-Error "Failed to create metrics task: $_"
    }

    return $true
}

function Configure-Alerting {
    Show-Step 5 "Configuring Alert Channels"

    $scriptPath = Split-Path $PSCommandPath -Parent
    $alertingSetupPath = Join-Path $scriptPath "BACKUP-ALERTING-SETUP.ps1"

    if (-not (Test-Path $alertingSetupPath)) {
        Show-Warning "Alerting setup script not found"
        return $true
    }

    Write-Host ""
    Write-Host "The alerting setup wizard will now start." -ForegroundColor Cyan
    Write-Host "This will configure email and webhook alerts." -ForegroundColor Cyan
    Write-Host ""

    $setupChoice = Read-Host "Configure alerting now? (y/n) [default: y]"

    if ($setupChoice -ne "n") {
        try {
            & $alertingSetupPath
            Show-Success "Alerting configuration complete"
        } catch {
            Show-Error "Alerting setup encountered an error: $_"
        }
    } else {
        Show-Info "Alerting setup skipped. You can run BACKUP-ALERTING-SETUP.ps1 later"
    }

    return $true
}

function Test-Monitoring {
    Show-Step 6 "Testing Monitoring Setup"

    $scriptPath = Split-Path $PSCommandPath -Parent
    $dashboardPath = Join-Path $scriptPath "BACKUP-MONITORING-DASHBOARD.ps1"

    if (-not (Test-Path $dashboardPath)) {
        Show-Warning "Dashboard script not found"
        return $true
    }

    Write-Host ""
    Write-Host "Ready to test the monitoring dashboard." -ForegroundColor Cyan
    Write-Host "The dashboard will run with a 5-minute refresh interval." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to exit the dashboard." -ForegroundColor Cyan
    Write-Host ""

    $testChoice = Read-Host "Start monitoring dashboard now? (y/n) [default: n]"

    if ($testChoice -eq "y") {
        Write-Host ""
        Write-Host "Starting dashboard in 3 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3

        try {
            & $dashboardPath -RefreshInterval 300
        } catch {
            Show-Error "Dashboard encountered an error: $_"
        }
    } else {
        Show-Info "Dashboard test skipped. Run BACKUP-MONITORING-DASHBOARD.ps1 to start"
    }

    return $true
}

function Show-Summary {
    Show-Step 7 "Setup Complete - Summary"

    Write-Host ""
    Write-Host "WHAT WAS INSTALLED:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  📁 Directories:" -ForegroundColor White
    Write-Host "     • C:\BackupMonitoring\Config" -ForegroundColor Gray
    Write-Host "     • C:\Logs\BackupMonitoring" -ForegroundColor Gray
    Write-Host "     • C:\Logs\BackupMonitoring\Reports" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  📋 Scheduled Tasks:" -ForegroundColor White
    Write-Host "     • Daily Backup Health Check (6:00 AM daily)" -ForegroundColor Gray
    Write-Host "     • Weekly Backup Metrics Report (7:00 AM Monday)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  📊 Configuration:" -ForegroundColor White
    Write-Host "     • C:\BackupMonitoring\Config\alerting-config.json" -ForegroundColor Gray
    Write-Host ""

    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. CONFIGURE ALERTS:" -ForegroundColor White
    Write-Host "     .\BACKUP-ALERTING-SETUP.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. START MONITORING DASHBOARD:" -ForegroundColor White
    Write-Host "     .\BACKUP-MONITORING-DASHBOARD.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. VIEW DOCUMENTATION:" -ForegroundColor White
    Write-Host "     .\MONITORING-SETUP-GUIDE.md" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. RUN HEALTH CHECK (manual):" -ForegroundColor White
    Write-Host "     .\HEALTH-CHECK-DAILY.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  5. GENERATE METRICS REPORT:" -ForegroundColor White
    Write-Host "     .\BACKUP-METRICS-REPORT.ps1" -ForegroundColor Gray
    Write-Host ""

    Write-Host "MONITORING LOCATIONS:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  • Dashboard Logs: C:\Logs\BackupMonitoring\dashboard-*.log" -ForegroundColor Gray
    Write-Host "  • Health Reports: C:\Logs\BackupMonitoring\Reports\health-check-*.html" -ForegroundColor Gray
    Write-Host "  • Metrics Reports: C:\Logs\BackupMonitoring\Reports\metrics-report-*.html" -ForegroundColor Gray
    Write-Host ""

    Write-Host "SCHEDULED TASKS:" -ForegroundColor Cyan
    Write-Host ""

    try {
        $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Backup*" }
        if ($tasks) {
            $tasks | Format-Table -Property TaskName, State, @{Name="NextRunTime"; Expression={(Get-ScheduledTaskInfo -TaskName $_.TaskName).NextRunTime}} -AutoSize
        }
    } catch {}

    Write-Host ""
}

###############################################################################
# MAIN EXECUTION
###############################################################################

Show-Header

Write-Host "This script will set up comprehensive backup monitoring for all three systems:" -ForegroundColor White
Write-Host "  • Veeam Backup (Windows)" -ForegroundColor Gray
Write-Host "  • Phone Backup (Android/iPhone)" -ForegroundColor Gray
Write-Host "  • Time Machine (macOS)" -ForegroundColor Gray
Write-Host ""

$startChoice = Read-Host "Continue with setup? (y/n) [default: y]"

if ($startChoice -eq "n") {
    Write-Host ""
    Write-Host "Setup cancelled." -ForegroundColor Yellow
    exit 0
}

# Execute setup steps
try {
    if (-not (Create-Directories)) { exit 1 }
    if (-not (Copy-ConfigTemplate)) { exit 1 }
    if (-not (Test-Prerequisites)) { exit 1 }
    if (-not (Create-ScheduledTasks)) { exit 1 }
    if (-not (Configure-Alerting)) { exit 1 }
    if (-not (Test-Monitoring)) { exit 0 }

    Show-Summary

    Write-Host "Setup wizard completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

} catch {
    Show-Error "Setup failed: $_"
    exit 1
}
