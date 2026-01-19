#Requires -RunAsAdministrator
###############################################################################
# Baby NAS System Tray Notification App
# Purpose: Windows system tray app for monitoring alerts
# Usage: .\tray-notification-app.ps1 [-ConfigPath <path>]
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "$PSScriptRoot\monitoring-config.json"
)

$ErrorActionPreference = "Stop"

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

###############################################################################
# CONFIGURATION
###############################################################################

# Load config
if (Test-Path $ConfigPath) {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} else {
    Write-Host "Config file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$logPath = $config.logging.path -replace '%USERPROFILE%', $env:USERPROFILE
$refreshInterval = $config.monitoring.refreshIntervalSeconds * 1000  # Convert to ms

###############################################################################
# TRAY ICON SETUP
###############################################################################

# Create notification icon
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon

# Create icon (use system icons)
$iconLibrary = [System.Drawing.SystemIcons]
$notifyIcon.Icon = $iconLibrary::Application

# Set initial tooltip
$notifyIcon.Text = "Baby NAS Monitor - Initializing..."
$notifyIcon.Visible = $true

###############################################################################
# CONTEXT MENU
###############################################################################

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Menu items
$menuItemDashboard = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemDashboard.Text = "Open Dashboard"
$menuItemDashboard.Add_Click({
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\dashboard.ps1`""
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to open dashboard: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$menuItemWebDashboard = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemWebDashboard.Text = "Open Web Dashboard"
$menuItemWebDashboard.Add_Click({
    try {
        $port = 8888
        if ($config.dashboard.web.port) {
            $port = $config.dashboard.web.port
        }
        Start-Process "http://localhost:$port"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to open web dashboard: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$menuItemRefresh = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemRefresh.Text = "Refresh Now"
$menuItemRefresh.Add_Click({
    Update-Status
})

$menuItemSeparator1 = New-Object System.Windows.Forms.ToolStripSeparator

$menuItemViewLogs = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemViewLogs.Text = "View Logs"
$menuItemViewLogs.Add_Click({
    try {
        $logFile = Join-Path $logPath "monitor-$(Get-Date -Format 'yyyyMMdd').log"
        if (Test-Path $logFile) {
            Start-Process notepad.exe -ArgumentList $logFile
        } else {
            [System.Windows.Forms.MessageBox]::Show("Log file not found: $logFile", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to open log: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$menuItemStatus = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemStatus.Text = "Monitoring Status"
$menuItemStatus.Add_Click({
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\START-MONITORING.ps1`" -Status"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to check status: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$menuItemSeparator2 = New-Object System.Windows.Forms.ToolStripSeparator

$menuItemStartMonitoring = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemStartMonitoring.Text = "Start Monitoring"
$menuItemStartMonitoring.Add_Click({
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\START-MONITORING.ps1`"" -Verb RunAs
        [System.Windows.Forms.MessageBox]::Show("Monitoring service started", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to start monitoring: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$menuItemStopMonitoring = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemStopMonitoring.Text = "Stop Monitoring"
$menuItemStopMonitoring.Add_Click({
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\START-MONITORING.ps1`" -StopMonitoring" -Verb RunAs
        [System.Windows.Forms.MessageBox]::Show("Monitoring service stopped", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to stop monitoring: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$menuItemSeparator3 = New-Object System.Windows.Forms.ToolStripSeparator

$menuItemExit = New-Object System.Windows.Forms.ToolStripMenuItem
$menuItemExit.Text = "Exit"
$menuItemExit.Add_Click({
    $notifyIcon.Visible = $false
    $timer.Stop()
    [System.Windows.Forms.Application]::Exit()
})

# Add items to context menu
$contextMenu.Items.AddRange(@(
    $menuItemDashboard,
    $menuItemWebDashboard,
    $menuItemRefresh,
    $menuItemSeparator1,
    $menuItemViewLogs,
    $menuItemStatus,
    $menuItemSeparator2,
    $menuItemStartMonitoring,
    $menuItemStopMonitoring,
    $menuItemSeparator3,
    $menuItemExit
))

$notifyIcon.ContextMenuStrip = $contextMenu

###############################################################################
# STATUS UPDATE FUNCTION
###############################################################################

function Update-Status {
    try {
        # Run quick health check
        $monitorScript = "$PSScriptRoot\monitor-baby-nas.ps1"

        if (-not (Test-Path $monitorScript)) {
            $notifyIcon.Icon = $iconLibrary::Warning
            $notifyIcon.Text = "Baby NAS Monitor - Script not found"
            return
        }

        # Get Baby NAS IP
        $babyNasIP = ""
        if ($config.babyNAS.ip -and $config.babyNAS.ip -ne "") {
            $babyNasIP = $config.babyNAS.ip
        } else {
            # Try to detect
            $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1
            if ($vm) {
                $vmNet = Get-VMNetworkAdapter -VM $vm
                if ($vmNet.IPAddresses) {
                    $babyNasIP = ($vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
                }
            }
        }

        # Quick network check
        $isOnline = $false
        if ($babyNasIP) {
            $isOnline = Test-Connection -ComputerName $babyNasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
        }

        # Check VM state
        $vmState = "Unknown"
        $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1
        if ($vm) {
            $vmState = $vm.State
        }

        # Update icon and tooltip based on status
        if ($vmState -eq "Running" -and $isOnline) {
            $notifyIcon.Icon = $iconLibrary::Shield
            $notifyIcon.Text = "Baby NAS Monitor - Healthy`nVM: Running | Network: Online"
        } elseif ($vmState -eq "Running") {
            $notifyIcon.Icon = $iconLibrary::Warning
            $notifyIcon.Text = "Baby NAS Monitor - Warning`nVM: Running | Network: Offline"
        } else {
            $notifyIcon.Icon = $iconLibrary::Error
            $notifyIcon.Text = "Baby NAS Monitor - Error`nVM: $vmState"
        }

        # Check for recent errors in logs
        $logFile = Join-Path $logPath "monitor-$(Get-Date -Format 'yyyyMMdd').log"
        if (Test-Path $logFile) {
            $recentLogs = Get-Content $logFile -Tail 10 -ErrorAction SilentlyContinue
            if ($recentLogs -match "Exit Code: [12]") {
                # Found warnings or errors
                $lastError = $recentLogs | Select-String "Exit Code:" | Select-Object -Last 1

                if ($lastError -match "Exit Code: 2") {
                    $notifyIcon.Icon = $iconLibrary::Warning
                } elseif ($lastError -match "Exit Code: 1") {
                    $notifyIcon.Icon = $iconLibrary::Error
                }
            }
        }

    } catch {
        $notifyIcon.Icon = $iconLibrary::Error
        $notifyIcon.Text = "Baby NAS Monitor - Error checking status"
    }
}

###############################################################################
# TIMER FOR AUTO-REFRESH
###############################################################################

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $refreshInterval
$timer.Add_Tick({
    Update-Status
})
$timer.Start()

###############################################################################
# DOUBLE-CLICK EVENT
###############################################################################

$notifyIcon.Add_DoubleClick({
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\dashboard.ps1`""
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to open dashboard: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

###############################################################################
# INITIAL UPDATE AND START
###############################################################################

Update-Status

# Show startup notification
$notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
$notifyIcon.BalloonTipTitle = "Baby NAS Monitor Started"
$notifyIcon.BalloonTipText = "Monitoring your Baby NAS system. Double-click to open dashboard."
$notifyIcon.ShowBalloonTip(3000)

###############################################################################
# APPLICATION CONTEXT
###############################################################################

$appContext = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($appContext)

# Cleanup on exit
$notifyIcon.Visible = $false
$notifyIcon.Dispose()
