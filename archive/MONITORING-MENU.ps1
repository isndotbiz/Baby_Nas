#Requires -RunAsAdministrator
###############################################################################
# Baby NAS Monitoring - Interactive Menu
# Purpose: Easy access to all monitoring features
# Usage: .\MONITORING-MENU.ps1
###############################################################################

$ErrorActionPreference = "Continue"

function Show-Menu {
    Clear-Host
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║              Baby NAS Monitoring System - Main Menu                      ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    Write-Host "  1. Start Monitoring Service" -ForegroundColor Green
    Write-Host "  2. Stop Monitoring Service" -ForegroundColor Red
    Write-Host "  3. Check Monitoring Status" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  4. Open Interactive Dashboard (TUI)" -ForegroundColor Cyan
    Write-Host "  5. Start Web Dashboard" -ForegroundColor Cyan
    Write-Host "  6. Open System Tray App" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  7. Run Health Check Now" -ForegroundColor Magenta
    Write-Host "  8. Send Test Alert" -ForegroundColor Magenta
    Write-Host "  9. View Today's Logs" -ForegroundColor Magenta
    Write-Host ""
    Write-Host " 10. Edit Configuration" -ForegroundColor Yellow
    Write-Host " 11. Install/Update Monitoring" -ForegroundColor Yellow
    Write-Host " 12. View Documentation" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  0. Exit" -ForegroundColor Gray
    Write-Host ""
}

function Wait-ForKey {
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Start-MonitoringService {
    Write-Host ""
    Write-Host "Starting monitoring service..." -ForegroundColor Cyan
    try {
        & "$PSScriptRoot\START-MONITORING.ps1"
        Write-Host ""
        Write-Host "Monitoring service started successfully!" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-ForKey
}

function Stop-MonitoringService {
    Write-Host ""
    Write-Host "Stopping monitoring service..." -ForegroundColor Cyan
    try {
        & "$PSScriptRoot\START-MONITORING.ps1" -StopMonitoring
        Write-Host ""
        Write-Host "Monitoring service stopped successfully!" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-ForKey
}

function Show-MonitoringStatus {
    Write-Host ""
    Write-Host "Checking monitoring status..." -ForegroundColor Cyan
    try {
        & "$PSScriptRoot\START-MONITORING.ps1" -Status
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-ForKey
}

function Open-InteractiveDashboard {
    Write-Host ""
    Write-Host "Opening interactive dashboard..." -ForegroundColor Cyan
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\dashboard.ps1`""
        Write-Host ""
        Write-Host "Dashboard opened in new window" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-ForKey
}

function Start-WebDashboard {
    Write-Host ""
    Write-Host "Starting web dashboard..." -ForegroundColor Cyan
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\START-MONITORING.ps1`" -WebDashboard" -Verb RunAs
        Write-Host ""
        Write-Host "Web dashboard starting..." -ForegroundColor Green
        Write-Host "Open http://localhost:8888 in your browser" -ForegroundColor Yellow
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-ForKey
}

function Open-TrayApp {
    Write-Host ""
    Write-Host "Opening system tray app..." -ForegroundColor Cyan
    try {
        Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSScriptRoot\tray-notification-app.ps1`""
        Write-Host ""
        Write-Host "Tray app started (check system tray)" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-ForKey
}

function Run-HealthCheck {
    Write-Host ""
    Write-Host "Running health check..." -ForegroundColor Cyan
    try {
        & "$PSScriptRoot\daily-health-check.ps1"
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-ForKey
}

function Send-TestAlert {
    Write-Host ""
    Write-Host "Send Test Alert" -ForegroundColor Cyan
    Write-Host "===============" -ForegroundColor Cyan
    Write-Host ""

    $severity = Read-Host "Enter severity (info/warning/critical)"
    if ($severity -notin @('info', 'warning', 'critical')) {
        $severity = 'warning'
    }

    $message = Read-Host "Enter alert message"
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = "Test alert from monitoring menu"
    }

    try {
        & "$PSScriptRoot\send-webhook-alert.ps1" -Severity $severity -Message $message -Details "Manual test from monitoring menu"
        Write-Host ""
        Write-Host "Test alert sent successfully!" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-ForKey
}

function View-Logs {
    Write-Host ""
    Write-Host "Opening today's log file..." -ForegroundColor Cyan

    $logPath = "C:\Logs\baby-nas-monitoring"
    $logFile = Join-Path $logPath "monitor-$(Get-Date -Format 'yyyyMMdd').log"

    if (Test-Path $logFile) {
        try {
            Start-Process notepad.exe -ArgumentList $logFile
            Write-Host ""
            Write-Host "Log file opened in Notepad" -ForegroundColor Green
        } catch {
            Write-Host ""
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host ""
        Write-Host "Log file not found: $logFile" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Available log files:" -ForegroundColor Cyan
        if (Test-Path $logPath) {
            Get-ChildItem $logPath -Filter "monitor-*.log" | ForEach-Object {
                Write-Host "  - $($_.Name)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  No logs found (monitoring may not have started yet)" -ForegroundColor Gray
        }
    }
    Wait-ForKey
}

function Edit-Configuration {
    Write-Host ""
    Write-Host "Opening configuration file..." -ForegroundColor Cyan

    $configPath = "$PSScriptRoot\monitoring-config.json"

    if (Test-Path $configPath) {
        try {
            Start-Process notepad.exe -ArgumentList $configPath
            Write-Host ""
            Write-Host "Configuration file opened in Notepad" -ForegroundColor Green
            Write-Host "After editing, restart monitoring service for changes to take effect" -ForegroundColor Yellow
        } catch {
            Write-Host ""
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host ""
        Write-Host "Configuration file not found: $configPath" -ForegroundColor Red
    }
    Wait-ForKey
}

function Run-Installation {
    Write-Host ""
    Write-Host "Running installation/update..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Installation options:" -ForegroundColor Yellow
    Write-Host "  1. Install all components" -ForegroundColor Gray
    Write-Host "  2. Install web dashboard only" -ForegroundColor Gray
    Write-Host "  3. Install tray app only" -ForegroundColor Gray
    Write-Host "  4. Configure scheduled tasks only" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "Enter choice (1-4)"

    $args = @()
    switch ($choice) {
        "1" { $args += "-InstallAll" }
        "2" { $args += "-InstallWebDashboard" }
        "3" { $args += "-InstallTrayApp" }
        "4" { $args += "-ConfigureScheduledTasks" }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
            Wait-ForKey
            return
        }
    }

    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\INSTALL-MONITORING.ps1`" $args" -Verb RunAs -Wait
        Write-Host ""
        Write-Host "Installation completed!" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Wait-ForKey
}

function View-Documentation {
    Write-Host ""
    Write-Host "Opening documentation..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Available documentation:" -ForegroundColor Yellow
    Write-Host "  1. Quick Start Guide" -ForegroundColor Gray
    Write-Host "  2. Full README" -ForegroundColor Gray
    Write-Host "  3. n8n Integration Guide" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "Enter choice (1-3)"

    $docPath = ""
    switch ($choice) {
        "1" { $docPath = "$PSScriptRoot\..\monitoring\QUICKSTART.md" }
        "2" { $docPath = "$PSScriptRoot\..\monitoring\README.md" }
        "3" { $docPath = "$PSScriptRoot\..\monitoring\n8n-workflow-example.json" }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
            Wait-ForKey
            return
        }
    }

    if (Test-Path $docPath) {
        try {
            Start-Process notepad.exe -ArgumentList $docPath
            Write-Host ""
            Write-Host "Documentation opened in Notepad" -ForegroundColor Green
        } catch {
            Write-Host ""
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host ""
        Write-Host "Documentation file not found: $docPath" -ForegroundColor Red
    }
    Wait-ForKey
}

# Main loop
while ($true) {
    Show-Menu

    $choice = Read-Host "Enter your choice"

    switch ($choice) {
        "1"  { Start-MonitoringService }
        "2"  { Stop-MonitoringService }
        "3"  { Show-MonitoringStatus }
        "4"  { Open-InteractiveDashboard }
        "5"  { Start-WebDashboard }
        "6"  { Open-TrayApp }
        "7"  { Run-HealthCheck }
        "8"  { Send-TestAlert }
        "9"  { View-Logs }
        "10" { Edit-Configuration }
        "11" { Run-Installation }
        "12" { View-Documentation }
        "0"  {
            Write-Host ""
            Write-Host "Exiting..." -ForegroundColor Gray
            exit 0
        }
        default {
            Write-Host ""
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Wait-ForKey
        }
    }
}
