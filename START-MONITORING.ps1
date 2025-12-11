#Requires -RunAsAdministrator
###############################################################################
# Baby NAS Continuous Monitoring Script
# Purpose: Start background monitoring daemon with alerting and logging
# Usage: .\START-MONITORING.ps1 [-ConfigPath <path>] [-WebDashboard] [-NoNotifications]
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "$PSScriptRoot\monitoring-config.json",

    [Parameter(Mandatory=$false)]
    [switch]$WebDashboard,

    [Parameter(Mandatory=$false)]
    [switch]$NoNotifications,

    [Parameter(Mandatory=$false)]
    [switch]$StopMonitoring,

    [Parameter(Mandatory=$false)]
    [switch]$Status
)

$ErrorActionPreference = "Stop"

###############################################################################
# CONSTANTS
###############################################################################

$MONITORING_JOB_NAME = "BabyNAS-Monitor"
$WEB_JOB_NAME = "BabyNAS-WebDashboard"
$MUTEX_NAME = "Global\BabyNASMonitoring"
$PID_FILE = "$env:TEMP\babynas-monitor.pid"

###############################################################################
# FUNCTIONS
###############################################################################

function Write-MonitorLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO'    { 'Cyan' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
    }

    $symbol = switch ($Level) {
        'SUCCESS' { '[+]' }
        'WARNING' { '[!]' }
        'ERROR'   { '[X]' }
        'INFO'    { '[i]' }
    }

    Write-Host "$symbol $Message" -ForegroundColor $color
}

function Load-Config {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-MonitorLog "Config file not found: $Path" -Level ERROR
        Write-MonitorLog "Creating default config..." -Level INFO

        # Create default config
        $defaultConfig = @{
            monitoring = @{
                enabled = $true
                refreshIntervalSeconds = 30
            }
            babyNAS = @{
                ip = ""
                autoDetectIP = $true
            }
            mainNAS = @{
                ip = "10.0.0.89"
            }
            thresholds = @{
                pool = @{
                    capacityWarning = 80
                    capacityCritical = 90
                }
            }
        }

        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $Path
    }

    try {
        $config = Get-Content $Path -Raw | ConvertFrom-Json
        return $config
    } catch {
        Write-MonitorLog "Failed to parse config: $($_.Exception.Message)" -Level ERROR
        exit 1
    }
}

function Get-MonitoringStatus {
    $jobs = Get-Job | Where-Object { $_.Name -eq $MONITORING_JOB_NAME }
    $webJobs = Get-Job | Where-Object { $_.Name -eq $WEB_JOB_NAME }

    $status = @{
        MonitoringRunning = $false
        WebDashboardRunning = $false
        Jobs = @()
    }

    if ($jobs) {
        $status.MonitoringRunning = ($jobs | Where-Object { $_.State -eq 'Running' }).Count -gt 0
        $status.Jobs += $jobs
    }

    if ($webJobs) {
        $status.WebDashboardRunning = ($webJobs | Where-Object { $_.State -eq 'Running' }).Count -gt 0
        $status.Jobs += $webJobs
    }

    return $status
}

function Stop-MonitoringService {
    Write-MonitorLog "Stopping monitoring services..." -Level INFO

    # Stop background jobs
    $jobs = Get-Job | Where-Object {
        $_.Name -eq $MONITORING_JOB_NAME -or $_.Name -eq $WEB_JOB_NAME
    }

    if ($jobs) {
        $jobs | Stop-Job -ErrorAction SilentlyContinue
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        Write-MonitorLog "Stopped $($jobs.Count) monitoring job(s)" -Level SUCCESS
    } else {
        Write-MonitorLog "No monitoring jobs running" -Level INFO
    }

    # Remove PID file
    if (Test-Path $PID_FILE) {
        Remove-Item $PID_FILE -Force
    }

    Write-MonitorLog "Monitoring stopped" -Level SUCCESS
}

function Show-MonitoringStatus {
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                   Baby NAS Monitoring Status                             ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    $status = Get-MonitoringStatus

    Write-Host "Monitoring Service: " -NoNewline
    if ($status.MonitoringRunning) {
        Write-Host "RUNNING" -ForegroundColor Green
    } else {
        Write-Host "STOPPED" -ForegroundColor Red
    }

    Write-Host "Web Dashboard:      " -NoNewline
    if ($status.WebDashboardRunning) {
        Write-Host "RUNNING" -ForegroundColor Green
    } else {
        Write-Host "STOPPED" -ForegroundColor Gray
    }

    if ($status.Jobs.Count -gt 0) {
        Write-Host "`nActive Jobs:" -ForegroundColor Cyan
        foreach ($job in $status.Jobs) {
            $runtime = ""
            if ($job.PSBeginTime) {
                $elapsed = (Get-Date) - $job.PSBeginTime
                $runtime = " (Running: $($elapsed.Hours)h $($elapsed.Minutes)m)"
            }
            Write-Host "  - $($job.Name): $($job.State)$runtime" -ForegroundColor Gray
        }
    }

    Write-Host ""
}

###############################################################################
# MAIN EXECUTION
###############################################################################

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║              Baby NAS Monitoring Service Manager                         ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Handle status check
if ($Status) {
    Show-MonitoringStatus
    exit 0
}

# Handle stop command
if ($StopMonitoring) {
    Stop-MonitoringService
    exit 0
}

# Check if already running
$currentStatus = Get-MonitoringStatus
if ($currentStatus.MonitoringRunning) {
    Write-MonitorLog "Monitoring is already running!" -Level WARNING
    Write-MonitorLog "Use -StopMonitoring to stop, or -Status to check status" -Level INFO
    exit 1
}

# Load configuration
Write-MonitorLog "Loading configuration from: $ConfigPath" -Level INFO
$config = Load-Config -Path $ConfigPath

if (-not $config.monitoring.enabled) {
    Write-MonitorLog "Monitoring is disabled in config" -Level WARNING
    exit 1
}

# Determine paths
$monitorScript = "$PSScriptRoot\monitor-baby-nas.ps1"
$webDashboardDir = "$PSScriptRoot\..\monitoring\web"

if (-not (Test-Path $monitorScript)) {
    Write-MonitorLog "Monitor script not found: $monitorScript" -Level ERROR
    Write-MonitorLog "Please ensure monitor-baby-nas.ps1 exists" -Level ERROR
    exit 1
}

# Create log directory
$logPath = $config.logging.path -replace '%USERPROFILE%', $env:USERPROFILE
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    Write-MonitorLog "Created log directory: $logPath" -Level SUCCESS
}

###############################################################################
# START MONITORING JOB
###############################################################################

Write-MonitorLog "Starting monitoring service..." -Level INFO

$monitorJob = Start-Job -Name $MONITORING_JOB_NAME -ScriptBlock {
    param($MonitorScript, $Config, $LogPath, $NoNotifications)

    $ErrorActionPreference = "Continue"

    # Monitoring loop
    $alertCooldown = @{}
    $lastAlertTime = Get-Date

    while ($true) {
        try {
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $logFile = Join-Path $LogPath "monitor-$(Get-Date -Format 'yyyyMMdd').log"

            # Run monitor script and capture output
            $output = & $MonitorScript -BabyNasIP $Config.babyNAS.ip -MainNasIP $Config.mainNAS.ip 2>&1
            $exitCode = $LASTEXITCODE

            # Log output
            "$timestamp - Exit Code: $exitCode" | Out-File -FilePath $logFile -Append
            $output | Out-File -FilePath $logFile -Append

            # Check for issues and send alerts
            if ($exitCode -eq 1 -and -not $NoNotifications) {
                # Critical error
                $alertKey = "CRITICAL-$(Get-Date -Format 'yyyyMMddHH')"
                if (-not $alertCooldown.ContainsKey($alertKey)) {
                    # Send Windows notification
                    Add-Type -AssemblyName System.Windows.Forms
                    $notification = New-Object System.Windows.Forms.NotifyIcon
                    $notification.Icon = [System.Drawing.SystemIcons]::Error
                    $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Error
                    $notification.BalloonTipTitle = "Baby NAS: CRITICAL"
                    $notification.BalloonTipText = "Critical monitoring errors detected. Check dashboard for details."
                    $notification.Visible = $true
                    $notification.ShowBalloonTip(5000)

                    $alertCooldown[$alertKey] = $true
                    Start-Sleep -Seconds 5
                    $notification.Dispose()
                }
            } elseif ($exitCode -eq 2 -and -not $NoNotifications) {
                # Warning
                $alertKey = "WARNING-$(Get-Date -Format 'yyyyMMddHH')"
                if (-not $alertCooldown.ContainsKey($alertKey)) {
                    Add-Type -AssemblyName System.Windows.Forms
                    $notification = New-Object System.Windows.Forms.NotifyIcon
                    $notification.Icon = [System.Drawing.SystemIcons]::Warning
                    $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
                    $notification.BalloonTipTitle = "Baby NAS: Warning"
                    $notification.BalloonTipText = "Monitoring warnings detected. Check dashboard for details."
                    $notification.Visible = $true
                    $notification.ShowBalloonTip(5000)

                    $alertCooldown[$alertKey] = $true
                    Start-Sleep -Seconds 5
                    $notification.Dispose()
                }
            }

            # Clean up old cooldown entries (older than 1 hour)
            $alertCooldown = @{}

        } catch {
            "$timestamp - ERROR: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append
        }

        Start-Sleep -Seconds $Config.monitoring.refreshIntervalSeconds
    }
} -ArgumentList $monitorScript, $config, $logPath, $NoNotifications.IsPresent

Write-MonitorLog "Monitoring service started (Job ID: $($monitorJob.Id))" -Level SUCCESS
Write-MonitorLog "Refresh interval: $($config.monitoring.refreshIntervalSeconds) seconds" -Level INFO
Write-MonitorLog "Logs: $logPath" -Level INFO

# Save PID
$monitorJob.Id | Out-File -FilePath $PID_FILE -Force

###############################################################################
# START WEB DASHBOARD (Optional)
###############################################################################

if ($WebDashboard -and (Test-Path $webDashboardDir)) {
    Write-MonitorLog "Starting web dashboard..." -Level INFO

    $webJob = Start-Job -Name $WEB_JOB_NAME -ScriptBlock {
        param($DashboardDir, $Port)

        $ErrorActionPreference = "Continue"

        # Simple HTTP server using .NET
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:$Port/")
        $listener.Start()

        Write-Host "Web dashboard listening on http://localhost:$Port/"

        while ($listener.IsListening) {
            try {
                $context = $listener.GetContext()
                $request = $context.Request
                $response = $context.Response

                # Serve files
                $requestPath = $request.Url.LocalPath
                if ($requestPath -eq "/" -or $requestPath -eq "") {
                    $requestPath = "/index.html"
                }

                $filePath = Join-Path $DashboardDir $requestPath.TrimStart('/')

                if (Test-Path $filePath) {
                    $content = Get-Content $filePath -Raw -Encoding UTF8
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)

                    # Set content type
                    if ($filePath -like "*.html") {
                        $response.ContentType = "text/html"
                    } elseif ($filePath -like "*.js") {
                        $response.ContentType = "application/javascript"
                    } elseif ($filePath -like "*.css") {
                        $response.ContentType = "text/css"
                    } elseif ($filePath -like "*.json") {
                        $response.ContentType = "application/json"
                    }

                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                } else {
                    $response.StatusCode = 404
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes("404 - Not Found")
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }

                $response.Close()
            } catch {
                Write-Host "Error: $($_.Exception.Message)"
            }
        }
    } -ArgumentList $webDashboardDir, $config.dashboard.web.port

    Write-MonitorLog "Web dashboard started on http://localhost:$($config.dashboard.web.port)" -Level SUCCESS
    Write-MonitorLog "Open your browser to view the dashboard" -Level INFO
} elseif ($WebDashboard) {
    Write-MonitorLog "Web dashboard directory not found: $webDashboardDir" -Level WARNING
}

###############################################################################
# SUMMARY
###############################################################################

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-MonitorLog "Monitoring services started successfully!" -Level SUCCESS
Write-Host ""
Write-Host "Commands:" -ForegroundColor Cyan
Write-Host "  Check status:  .\START-MONITORING.ps1 -Status" -ForegroundColor Gray
Write-Host "  Stop services: .\START-MONITORING.ps1 -StopMonitoring" -ForegroundColor Gray
Write-Host "  View logs:     Get-Content '$logPath\monitor-$(Get-Date -Format 'yyyyMMdd').log' -Wait -Tail 50" -ForegroundColor Gray
Write-Host ""
Write-Host "Dashboard:" -ForegroundColor Cyan
Write-Host "  Interactive:   .\dashboard.ps1" -ForegroundColor Gray
if ($WebDashboard) {
    Write-Host "  Web:           http://localhost:$($config.dashboard.web.port)" -ForegroundColor Gray
}
Write-Host ""

# Keep script running to show initial status
Write-Host "Press Ctrl+C to return to prompt (monitoring will continue in background)" -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 3

# Show initial job status
Show-MonitoringStatus

Write-Host "Monitoring is running in the background." -ForegroundColor Green
Write-Host ""
