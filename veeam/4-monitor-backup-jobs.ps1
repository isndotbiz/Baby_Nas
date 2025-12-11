#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automated Veeam backup monitoring and reporting script

.DESCRIPTION
    Monitors Veeam backup jobs and provides comprehensive reporting.
    Features:
    - Backup job status checking
    - Failed backup detection and alerting
    - Performance metrics and statistics
    - Storage capacity monitoring
    - Email notifications (optional)
    - Automated health checks
    - Historical trend analysis

.PARAMETER CheckInterval
    Interval in minutes for continuous monitoring
    Default: 0 (single check, no loop)

.PARAMETER EnableEmailAlerts
    Send email alerts for failures
    Default: $false

.PARAMETER EmailTo
    Email address for alerts

.PARAMETER EmailFrom
    From email address

.PARAMETER SmtpServer
    SMTP server address

.PARAMETER SmtpPort
    SMTP server port
    Default: 587

.PARAMETER SmtpUsername
    SMTP authentication username

.PARAMETER SmtpPassword
    SMTP authentication password (SecureString)

.PARAMETER ReportPath
    Path to save monitoring reports
    Default: C:\Logs\Veeam\Reports

.PARAMETER AlertOnWarning
    Alert on warnings as well as errors
    Default: $false

.PARAMETER BackupDestination
    Backup destination path to monitor space
    Default: \\172.21.203.18\Veeam

.EXAMPLE
    .\4-monitor-backup-jobs.ps1
    Single backup status check

.EXAMPLE
    .\4-monitor-backup-jobs.ps1 -CheckInterval 60
    Continuous monitoring with 60-minute intervals

.EXAMPLE
    .\4-monitor-backup-jobs.ps1 -EnableEmailAlerts $true -EmailTo "admin@example.com" -SmtpServer "smtp.example.com"
    Monitor with email alerts enabled

.NOTES
    Author: Automated Veeam Deployment System
    Version: 1.0
    Requires: Veeam Agent for Windows installed
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$CheckInterval = 0,

    [Parameter(Mandatory=$false)]
    [bool]$EnableEmailAlerts = $false,

    [Parameter(Mandatory=$false)]
    [string]$EmailTo,

    [Parameter(Mandatory=$false)]
    [string]$EmailFrom,

    [Parameter(Mandatory=$false)]
    [string]$SmtpServer,

    [Parameter(Mandatory=$false)]
    [int]$SmtpPort = 587,

    [Parameter(Mandatory=$false)]
    [string]$SmtpUsername,

    [Parameter(Mandatory=$false)]
    [SecureString]$SmtpPassword,

    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\Logs\Veeam\Reports",

    [Parameter(Mandatory=$false)]
    [bool]$AlertOnWarning = $false,

    [Parameter(Mandatory=$false)]
    [string]$BackupDestination = "\\172.21.203.18\Veeam"
)

# Configuration
$logDir = "C:\Logs\Veeam"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\veeam-monitor-$timestamp.log"
$statusFile = "$logDir\veeam-status-latest.json"

# Veeam paths
$veeamDataPath = "$env:ProgramData\Veeam\Endpoint"
$veeamLogPath = "$veeamDataPath\Logs"

# Create directories
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $ReportPath)) {
    New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO"    { Write-Host $logMessage -ForegroundColor Cyan }
        default   { Write-Host $logMessage -ForegroundColor White }
    }

    $logMessage | Out-File -FilePath $logFile -Append
}

function Get-VeeamBackupJobs {
    Write-Log "Discovering Veeam backup jobs..." "INFO"

    $jobs = @()

    # Method 1: Check Windows Event Log
    try {
        $veeamEvents = Get-WinEvent -LogName "Veeam Backup" -MaxEvents 100 -ErrorAction SilentlyContinue |
                       Where-Object { $_.Id -in @(190, 191, 192) }  # Job start, success, failure IDs

        if ($veeamEvents) {
            Write-Log "Found $($veeamEvents.Count) Veeam events in Windows Event Log" "INFO"
        }
    } catch {
        Write-Log "No Veeam events found in Event Log" "INFO"
    }

    # Method 2: Check registry
    $regPath = "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup\Jobs"

    if (Test-Path $regPath) {
        $jobKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue

        foreach ($jobKey in $jobKeys) {
            try {
                $jobName = (Get-ItemProperty -Path $jobKey.PSPath -Name "Name" -ErrorAction SilentlyContinue).Name
                $jobEnabled = (Get-ItemProperty -Path $jobKey.PSPath -Name "Enabled" -ErrorAction SilentlyContinue).Enabled

                if ($jobName) {
                    $jobs += @{
                        Name = $jobName
                        Enabled = $jobEnabled
                        Source = "Registry"
                        Path = $jobKey.PSPath
                    }

                    Write-Log "Found job in registry: $jobName" "INFO"
                }
            } catch {
                Write-Log "Error reading job from registry: $($_.Exception.Message)" "WARNING"
            }
        }
    }

    # Method 3: Check config files
    if (Test-Path $veeamDataPath) {
        $configFiles = Get-ChildItem -Path $veeamDataPath -Recurse -Filter "*.xml" -ErrorAction SilentlyContinue

        foreach ($file in $configFiles) {
            try {
                [xml]$config = Get-Content -Path $file.FullName -ErrorAction Stop

                # Look for job configurations in XML
                if ($config.SelectNodes("//Job")) {
                    $jobNodes = $config.SelectNodes("//Job")

                    foreach ($node in $jobNodes) {
                        $jobName = $node.Name
                        if ($jobName) {
                            $jobs += @{
                                Name = $jobName
                                Source = "ConfigFile"
                                ConfigPath = $file.FullName
                            }

                            Write-Log "Found job in config: $jobName" "INFO"
                        }
                    }
                }
            } catch {
                # Not a valid XML or doesn't contain job info
            }
        }
    }

    Write-Log "Total jobs discovered: $($jobs.Count)" "INFO"
    return $jobs
}

function Get-VeeamBackupHistory {
    Write-Log "Retrieving backup history..." "INFO"

    $history = @()

    # Parse Veeam log files
    if (Test-Path $veeamLogPath) {
        $logFiles = Get-ChildItem -Path $veeamLogPath -Filter "*.log" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 10

        foreach ($logFile in $logFiles) {
            try {
                $logContent = Get-Content -Path $logFile.FullName -ErrorAction SilentlyContinue

                # Parse log for backup sessions
                foreach ($line in $logContent) {
                    # Look for backup start/end markers
                    if ($line -match "Backup session started" -or
                        $line -match "Backup completed" -or
                        $line -match "Backup failed") {

                        $history += @{
                            LogFile = $logFile.Name
                            Timestamp = $logFile.LastWriteTime
                            Entry = $line
                        }
                    }
                }
            } catch {
                Write-Log "Error parsing log file: $($logFile.Name)" "WARNING"
            }
        }
    }

    # Check Windows Event Log for backup events
    try {
        $backupEvents = Get-WinEvent -LogName "Veeam Backup" -MaxEvents 50 -ErrorAction SilentlyContinue

        foreach ($event in $backupEvents) {
            $history += @{
                Source = "EventLog"
                EventId = $event.Id
                Level = $event.LevelDisplayName
                Message = $event.Message
                TimeCreated = $event.TimeCreated
            }
        }
    } catch {
        Write-Log "No events found in Veeam Event Log" "INFO"
    }

    Write-Log "Retrieved $($history.Count) historical entries" "INFO"
    return $history
}

function Get-BackupStatus {
    Write-Log "Checking backup job status..." "INFO"

    $status = @{
        Timestamp = (Get-Date).ToString()
        ComputerName = $env:COMPUTERNAME
        Jobs = @()
        OverallStatus = "Unknown"
        Warnings = @()
        Errors = @()
    }

    # Get jobs
    $jobs = Get-VeeamBackupJobs

    if ($jobs.Count -eq 0) {
        Write-Log "WARNING: No backup jobs found" "WARNING"
        $status.Warnings += "No backup jobs configured"
        $status.OverallStatus = "Warning"
        return $status
    }

    # Get backup history
    $history = Get-VeeamBackupHistory

    # Analyze each job
    foreach ($job in $jobs) {
        $jobStatus = @{
            Name = $job.Name
            Enabled = $job.Enabled
            LastBackup = "Unknown"
            Status = "Unknown"
            Duration = "Unknown"
            Size = "Unknown"
        }

        # Find last backup for this job in history
        $relevantHistory = $history | Where-Object {
            $_.Entry -match $job.Name -or $_.Message -match $job.Name
        } | Sort-Object { if ($_.TimeCreated) { $_.TimeCreated } else { $_.Timestamp } } -Descending |
            Select-Object -First 1

        if ($relevantHistory) {
            $jobStatus.LastBackup = if ($relevantHistory.TimeCreated) {
                $relevantHistory.TimeCreated.ToString()
            } else {
                $relevantHistory.Timestamp.ToString()
            }

            # Determine status
            if ($relevantHistory.Entry -match "completed successfully" -or
                $relevantHistory.Level -eq "Information") {
                $jobStatus.Status = "Success"
            } elseif ($relevantHistory.Entry -match "failed" -or
                      $relevantHistory.Level -eq "Error") {
                $jobStatus.Status = "Failed"
                $status.Errors += "Job '$($job.Name)' failed"
            } elseif ($relevantHistory.Level -eq "Warning") {
                $jobStatus.Status = "Warning"
                $status.Warnings += "Job '$($job.Name)' has warnings"
            }
        } else {
            $jobStatus.Status = "No History"
            $status.Warnings += "Job '$($job.Name)' has no backup history"
        }

        $status.Jobs += $jobStatus
    }

    # Determine overall status
    if ($status.Errors.Count -gt 0) {
        $status.OverallStatus = "Failed"
    } elseif ($status.Warnings.Count -gt 0) {
        $status.OverallStatus = "Warning"
    } else {
        $status.OverallStatus = "Success"
    }

    Write-Log "Overall backup status: $($status.OverallStatus)" "INFO"
    return $status
}

function Get-BackupDestinationSpace {
    param([string]$Path)

    Write-Log "Checking backup destination space: $Path" "INFO"

    $spaceInfo = @{
        Path = $Path
        TotalSizeGB = 0
        FreeSizeGB = 0
        UsedSizeGB = 0
        FreePercent = 0
        Status = "Unknown"
    }

    try {
        if (Test-Path $Path) {
            # Get drive info
            if ($Path -match '^([A-Z]:)') {
                # Local drive
                $driveLetter = $matches[1]
                $drive = Get-PSDrive -Name $driveLetter.Trim(':')

                $spaceInfo.TotalSizeGB = [math]::Round($drive.Used + $drive.Free) / 1GB, 2)
                $spaceInfo.FreeSizeGB = [math]::Round($drive.Free / 1GB, 2)
                $spaceInfo.UsedSizeGB = [math]::Round($drive.Used / 1GB, 2)
                $spaceInfo.FreePercent = [math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 1)

            } elseif ($Path -match '^\\\\') {
                # Network path - try to get space info
                try {
                    # Get files in directory to check accessibility
                    $files = Get-ChildItem -Path $Path -ErrorAction Stop

                    # Try to get drive space (may not work for all network shares)
                    $drive = Get-PSDrive | Where-Object { $_.DisplayRoot -eq $Path } | Select-Object -First 1

                    if ($drive) {
                        $spaceInfo.FreeSizeGB = [math]::Round($drive.Free / 1GB, 2)
                        $spaceInfo.UsedSizeGB = [math]::Round($drive.Used / 1GB, 2)
                        $spaceInfo.TotalSizeGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
                        $spaceInfo.FreePercent = [math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 1)
                    }

                    $spaceInfo.Status = "Accessible"
                } catch {
                    Write-Log "WARNING: Cannot get detailed space info for network path" "WARNING"
                    $spaceInfo.Status = "Limited Info"
                }
            }

            # Determine status based on free space
            if ($spaceInfo.FreePercent -gt 0) {
                if ($spaceInfo.FreePercent -lt 10) {
                    $spaceInfo.Status = "Critical"
                    Write-Log "WARNING: Less than 10% free space on backup destination" "WARNING"
                } elseif ($spaceInfo.FreePercent -lt 20) {
                    $spaceInfo.Status = "Warning"
                    Write-Log "WARNING: Less than 20% free space on backup destination" "WARNING"
                } else {
                    $spaceInfo.Status = "Good"
                }
            }

            Write-Log "Backup destination space: $($spaceInfo.FreeSizeGB) GB free ($($spaceInfo.FreePercent)%)" "INFO"
        } else {
            Write-Log "ERROR: Backup destination not accessible: $Path" "ERROR"
            $spaceInfo.Status = "Inaccessible"
        }
    } catch {
        Write-Log "ERROR checking destination space: $($_.Exception.Message)" "ERROR"
        $spaceInfo.Status = "Error"
    }

    return $spaceInfo
}

function Get-BackupFileStats {
    param([string]$Path)

    Write-Log "Analyzing backup files..." "INFO"

    $stats = @{
        TotalFiles = 0
        TotalSizeGB = 0
        FileTypes = @{}
        OldestBackup = $null
        NewestBackup = $null
    }

    try {
        if (Test-Path $Path) {
            $backupFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue

            $stats.TotalFiles = $backupFiles.Count

            foreach ($file in $backupFiles) {
                $stats.TotalSizeGB += $file.Length

                $ext = $file.Extension.ToLower()
                if (-not $stats.FileTypes.ContainsKey($ext)) {
                    $stats.FileTypes[$ext] = @{
                        Count = 0
                        SizeGB = 0
                    }
                }

                $stats.FileTypes[$ext].Count++
                $stats.FileTypes[$ext].SizeGB += $file.Length
            }

            $stats.TotalSizeGB = [math]::Round($stats.TotalSizeGB / 1GB, 2)

            # Convert file type sizes to GB
            foreach ($ext in $stats.FileTypes.Keys) {
                $stats.FileTypes[$ext].SizeGB = [math]::Round($stats.FileTypes[$ext].SizeGB / 1GB, 2)
            }

            # Get oldest and newest
            if ($backupFiles.Count -gt 0) {
                $stats.OldestBackup = ($backupFiles | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime
                $stats.NewestBackup = ($backupFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
            }

            Write-Log "Backup files: $($stats.TotalFiles) files, $($stats.TotalSizeGB) GB total" "INFO"
        } else {
            Write-Log "WARNING: Cannot access backup path for file stats" "WARNING"
        }
    } catch {
        Write-Log "ERROR analyzing backup files: $($_.Exception.Message)" "ERROR"
    }

    return $stats
}

function Send-EmailAlert {
    param(
        [hashtable]$Status,
        [string]$To,
        [string]$From,
        [string]$SmtpServer,
        [int]$SmtpPort,
        [string]$Username,
        [SecureString]$Password
    )

    Write-Log "Sending email alert to: $To" "INFO"

    try {
        # Build email body
        $subject = "Veeam Backup Alert - $($Status.OverallStatus) - $env:COMPUTERNAME"

        $body = @"
<html>
<head>
<style>
    body { font-family: Arial, sans-serif; }
    h2 { color: #2c5aa0; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
    th { background-color: #2c5aa0; color: white; padding: 10px; text-align: left; }
    td { border: 1px solid #ddd; padding: 8px; }
    .success { color: green; font-weight: bold; }
    .warning { color: orange; font-weight: bold; }
    .error { color: red; font-weight: bold; }
</style>
</head>
<body>
<h2>Veeam Backup Status Report</h2>
<p><strong>Computer:</strong> $env:COMPUTERNAME</p>
<p><strong>Timestamp:</strong> $($Status.Timestamp)</p>
<p><strong>Overall Status:</strong> <span class="$($Status.OverallStatus.ToLower())">$($Status.OverallStatus)</span></p>

<h3>Backup Jobs</h3>
<table>
<tr>
    <th>Job Name</th>
    <th>Status</th>
    <th>Last Backup</th>
    <th>Enabled</th>
</tr>
"@

        foreach ($job in $Status.Jobs) {
            $statusClass = switch ($job.Status) {
                "Success" { "success" }
                "Failed" { "error" }
                "Warning" { "warning" }
                default { "" }
            }

            $body += @"
<tr>
    <td>$($job.Name)</td>
    <td><span class="$statusClass">$($job.Status)</span></td>
    <td>$($job.LastBackup)</td>
    <td>$($job.Enabled)</td>
</tr>
"@
        }

        $body += "</table>"

        # Add errors
        if ($Status.Errors.Count -gt 0) {
            $body += "<h3 class='error'>Errors</h3><ul>"
            foreach ($error in $Status.Errors) {
                $body += "<li>$error</li>"
            }
            $body += "</ul>"
        }

        # Add warnings
        if ($Status.Warnings.Count -gt 0) {
            $body += "<h3 class='warning'>Warnings</h3><ul>"
            foreach ($warning in $Status.Warnings) {
                $body += "<li>$warning</li>"
            }
            $body += "</ul>"
        }

        $body += @"
<p style="margin-top: 30px; color: #666; font-size: 12px;">
This alert was generated automatically by Veeam Monitoring System
</p>
</body>
</html>
"@

        # Send email
        $emailParams = @{
            To = $To
            From = $From
            Subject = $subject
            Body = $body
            BodyAsHtml = $true
            SmtpServer = $SmtpServer
            Port = $SmtpPort
            UseSsl = $true
        }

        if ($Username -and $Password) {
            $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
            $emailParams.Credential = $credential
        }

        Send-MailMessage @emailParams -ErrorAction Stop

        Write-Log "Email alert sent successfully" "SUCCESS"
        return $true

    } catch {
        Write-Log "ERROR sending email alert: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Save-StatusReport {
    param(
        [hashtable]$Status,
        [hashtable]$SpaceInfo,
        [hashtable]$FileStats,
        [string]$ReportPath
    )

    Write-Log "Saving status report..." "INFO"

    try {
        # Save JSON status
        $fullStatus = @{
            Status = $Status
            Space = $SpaceInfo
            Files = $FileStats
        }

        $fullStatus | ConvertTo-Json -Depth 10 | Out-File -FilePath $statusFile -Force

        # Save HTML report
        $reportHtml = "$ReportPath\veeam-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"

        $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
<title>Veeam Backup Report - $env:COMPUTERNAME</title>
<style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #2c5aa0; }
    h2 { color: #5a7aa0; margin-top: 30px; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
    th { background-color: #2c5aa0; color: white; padding: 10px; text-align: left; }
    td { border: 1px solid #ddd; padding: 8px; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    .success { color: green; font-weight: bold; }
    .warning { color: orange; font-weight: bold; }
    .error { color: red; font-weight: bold; }
    .metric { background-color: #f0f0f0; padding: 15px; margin: 10px 0; border-radius: 5px; }
    .metric-value { font-size: 24px; font-weight: bold; color: #2c5aa0; }
</style>
</head>
<body>
<h1>Veeam Backup Status Report</h1>
<div class="metric">
    <strong>Computer:</strong> $env:COMPUTERNAME<br>
    <strong>Report Time:</strong> $($Status.Timestamp)<br>
    <strong>Overall Status:</strong> <span class="$($Status.OverallStatus.ToLower())">$($Status.OverallStatus)</span>
</div>

<h2>Backup Jobs</h2>
<table>
<tr>
    <th>Job Name</th>
    <th>Status</th>
    <th>Enabled</th>
    <th>Last Backup</th>
</tr>
"@

        foreach ($job in $Status.Jobs) {
            $statusClass = switch ($job.Status) {
                "Success" { "success" }
                "Failed" { "error" }
                "Warning" { "warning" }
                default { "" }
            }

            $htmlContent += @"
<tr>
    <td>$($job.Name)</td>
    <td><span class="$statusClass">$($job.Status)</span></td>
    <td>$($job.Enabled)</td>
    <td>$($job.LastBackup)</td>
</tr>
"@
        }

        $htmlContent += "</table>"

        # Storage info
        $htmlContent += @"
<h2>Storage Information</h2>
<div class="metric">
    <strong>Backup Destination:</strong> $($SpaceInfo.Path)<br>
    <strong>Status:</strong> <span class="$($SpaceInfo.Status.ToLower())">$($SpaceInfo.Status)</span><br>
    <strong>Total Space:</strong> $($SpaceInfo.TotalSizeGB) GB<br>
    <strong>Used Space:</strong> $($SpaceInfo.UsedSizeGB) GB<br>
    <strong>Free Space:</strong> <span class="metric-value">$($SpaceInfo.FreeSizeGB) GB</span> ($($SpaceInfo.FreePercent)%)
</div>

<h2>Backup Files</h2>
<div class="metric">
    <strong>Total Files:</strong> $($FileStats.TotalFiles)<br>
    <strong>Total Size:</strong> $($FileStats.TotalSizeGB) GB<br>
    <strong>Oldest Backup:</strong> $($FileStats.OldestBackup)<br>
    <strong>Newest Backup:</strong> $($FileStats.NewestBackup)
</div>
"@

        # File types
        if ($FileStats.FileTypes.Count -gt 0) {
            $htmlContent += "<h3>File Types</h3><table><tr><th>Extension</th><th>Count</th><th>Size (GB)</th></tr>"

            foreach ($ext in $FileStats.FileTypes.Keys) {
                $htmlContent += "<tr><td>$ext</td><td>$($FileStats.FileTypes[$ext].Count)</td><td>$($FileStats.FileTypes[$ext].SizeGB)</td></tr>"
            }

            $htmlContent += "</table>"
        }

        $htmlContent += @"
<p style="margin-top: 50px; color: #666; font-size: 12px;">
Generated by Veeam Monitoring System - $(Get-Date)
</p>
</body>
</html>
"@

        $htmlContent | Out-File -FilePath $reportHtml -Force

        Write-Log "Report saved: $reportHtml" "SUCCESS"
        return $reportHtml

    } catch {
        Write-Log "ERROR saving report: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Show-StatusSummary {
    param(
        [hashtable]$Status,
        [hashtable]$SpaceInfo,
        [hashtable]$FileStats
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " VEEAM BACKUP STATUS SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Overall status
    $statusColor = switch ($Status.OverallStatus) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Failed" { "Red" }
        default { "White" }
    }

    Write-Host "Overall Status: " -NoNewline
    Write-Host "$($Status.OverallStatus)" -ForegroundColor $statusColor
    Write-Host "Computer: $env:COMPUTERNAME"
    Write-Host "Timestamp: $($Status.Timestamp)"
    Write-Host ""

    # Jobs
    Write-Host "BACKUP JOBS:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($job in $Status.Jobs) {
        $jobStatusColor = switch ($job.Status) {
            "Success" { "Green" }
            "Warning" { "Yellow" }
            "Failed" { "Red" }
            default { "White" }
        }

        Write-Host "  Job: $($job.Name)" -ForegroundColor White
        Write-Host "    Status: " -NoNewline
        Write-Host "$($job.Status)" -ForegroundColor $jobStatusColor
        Write-Host "    Last Backup: $($job.LastBackup)"
        Write-Host "    Enabled: $($job.Enabled)"
        Write-Host ""
    }

    # Storage
    Write-Host "STORAGE:" -ForegroundColor Cyan
    Write-Host "  Destination: $($SpaceInfo.Path)"
    Write-Host "  Free Space: $($SpaceInfo.FreeSizeGB) GB ($($SpaceInfo.FreePercent)%)"
    Write-Host "  Status: $($SpaceInfo.Status)"
    Write-Host ""

    # Files
    Write-Host "BACKUP FILES:" -ForegroundColor Cyan
    Write-Host "  Total Files: $($FileStats.TotalFiles)"
    Write-Host "  Total Size: $($FileStats.TotalSizeGB) GB"
    if ($FileStats.NewestBackup) {
        Write-Host "  Newest: $($FileStats.NewestBackup)"
    }
    if ($FileStats.OldestBackup) {
        Write-Host "  Oldest: $($FileStats.OldestBackup)"
    }
    Write-Host ""

    # Warnings and errors
    if ($Status.Warnings.Count -gt 0) {
        Write-Host "WARNINGS:" -ForegroundColor Yellow
        foreach ($warning in $Status.Warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    if ($Status.Errors.Count -gt 0) {
        Write-Host "ERRORS:" -ForegroundColor Red
        foreach ($error in $Status.Errors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
        Write-Host ""
    }

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

# ===== MAIN EXECUTION =====

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " VEEAM BACKUP MONITORING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== Veeam Backup Monitoring Started ===" "INFO"

# Main monitoring loop
do {
    $loopTimestamp = Get-Date

    Write-Log "Running backup status check..." "INFO"

    # Get backup status
    $status = Get-BackupStatus

    # Get storage info
    $spaceInfo = Get-BackupDestinationSpace -Path $BackupDestination

    # Get file statistics
    $fileStats = Get-BackupFileStats -Path $BackupDestination

    # Show summary
    Show-StatusSummary -Status $status -SpaceInfo $spaceInfo -FileStats $fileStats

    # Save report
    $reportPath = Save-StatusReport -Status $status -SpaceInfo $spaceInfo -FileStats $fileStats -ReportPath $ReportPath

    if ($reportPath) {
        Write-Log "Report saved: $reportPath" "SUCCESS"
    }

    # Send email alerts if enabled
    if ($EnableEmailAlerts) {
        $shouldAlert = $false

        if ($status.OverallStatus -eq "Failed") {
            $shouldAlert = $true
        } elseif ($AlertOnWarning -and $status.OverallStatus -eq "Warning") {
            $shouldAlert = $true
        }

        if ($shouldAlert) {
            Write-Log "Sending email alert..." "INFO"

            $emailSent = Send-EmailAlert `
                -Status $status `
                -To $EmailTo `
                -From $EmailFrom `
                -SmtpServer $SmtpServer `
                -SmtpPort $SmtpPort `
                -Username $SmtpUsername `
                -Password $SmtpPassword

            if ($emailSent) {
                Write-Log "Email alert sent successfully" "SUCCESS"
            }
        }
    }

    # Continuous monitoring
    if ($CheckInterval -gt 0) {
        Write-Log "Next check in $CheckInterval minutes..." "INFO"
        Write-Host ""
        Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor Yellow
        Write-Host ""

        Start-Sleep -Seconds ($CheckInterval * 60)
    }

} while ($CheckInterval -gt 0)

Write-Log "=== Monitoring Completed ===" "SUCCESS"
Write-Log "Log file: $logFile" "INFO"

exit 0
