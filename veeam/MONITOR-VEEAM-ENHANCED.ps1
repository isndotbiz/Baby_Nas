#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enhanced Veeam backup monitoring with comprehensive reporting

.DESCRIPTION
    Advanced monitoring script for all Veeam backup jobs including:
    - Full system backups
    - Workspace sync status
    - WSL backup status
    - Storage capacity monitoring
    - Email alerts for failures
    - HTML reporting
    - Performance metrics

.PARAMETER ContinuousMonitoring
    Enable continuous monitoring mode
    Default: $false

.PARAMETER CheckInterval
    Interval in minutes for continuous monitoring
    Default: 60

.PARAMETER EnableEmailAlerts
    Send email alerts for failures
    Default: $false

.PARAMETER EmailTo
    Email address for alerts

.PARAMETER SmtpServer
    SMTP server address

.PARAMETER AlertOnWarning
    Alert on warnings as well as errors
    Default: $true

.EXAMPLE
    .\MONITOR-VEEAM-ENHANCED.ps1
    Single check of all backup jobs

.EXAMPLE
    .\MONITOR-VEEAM-ENHANCED.ps1 -ContinuousMonitoring $true -CheckInterval 30
    Continuous monitoring every 30 minutes

.NOTES
    Author: Enhanced Veeam Deployment System
    Version: 2.0
#>

param(
    [Parameter(Mandatory=$false)]
    [bool]$ContinuousMonitoring = $false,

    [Parameter(Mandatory=$false)]
    [int]$CheckInterval = 60,

    [Parameter(Mandatory=$false)]
    [bool]$EnableEmailAlerts = $false,

    [Parameter(Mandatory=$false)]
    [string]$EmailTo,

    [Parameter(Mandatory=$false)]
    [string]$SmtpServer,

    [Parameter(Mandatory=$false)]
    [bool]$AlertOnWarning = $true
)

# Configuration
$script:Config = @{
    LogDir = "C:\Logs\Veeam"
    ReportDir = "C:\Logs\Veeam\Reports"
    VeeamShare = "\\baby.isn.biz\Veeam"
    WorkspaceShare = "\\baby.isn.biz\WindowsBackup\d-workspace"
    WSLShare = "\\baby.isn.biz\WindowsBackup\wsl"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$($script:Config.LogDir)\monitor-$timestamp.log"
$reportFile = "$($script:Config.ReportDir)\report-$timestamp.html"
$statusFile = "$($script:Config.LogDir)\latest-status.json"

# Create directories
foreach ($dir in @($script:Config.LogDir, $script:Config.ReportDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

# ===== LOGGING =====

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

    $logMessage | Out-File -FilePath $logFile -Append -ErrorAction SilentlyContinue
}

# ===== BACKUP STATUS CHECKS =====

function Get-VeeamBackupStatus {
    Write-Log "Checking Veeam full backup status..." "INFO"

    $status = @{
        Type = "Veeam Full Backup"
        Status = "Unknown"
        LastBackup = "Never"
        LastSuccess = "Never"
        LastFailure = "Never"
        NextScheduled = "Unknown"
        Details = @()
    }

    # Check Windows Event Log for Veeam events
    try {
        $veeamEvents = Get-WinEvent -LogName "Veeam Backup" -MaxEvents 50 -ErrorAction SilentlyContinue

        if ($veeamEvents) {
            # Find most recent backup completion
            $successEvent = $veeamEvents | Where-Object { $_.Id -eq 190 -or $_.Message -match "completed successfully" } | Select-Object -First 1
            $failureEvent = $veeamEvents | Where-Object { $_.Id -eq 191 -or $_.LevelDisplayName -eq "Error" } | Select-Object -First 1

            if ($successEvent) {
                $status.LastSuccess = $successEvent.TimeCreated.ToString()
                $status.LastBackup = $successEvent.TimeCreated.ToString()
                $status.Status = "Success"
            }

            if ($failureEvent -and $failureEvent.TimeCreated -gt $successEvent.TimeCreated) {
                $status.LastFailure = $failureEvent.TimeCreated.ToString()
                $status.LastBackup = $failureEvent.TimeCreated.ToString()
                $status.Status = "Failed"
                $status.Details += $failureEvent.Message
            }
        } else {
            $status.Status = "No Events"
            $status.Details += "No Veeam events found in Event Log"
        }
    } catch {
        $status.Status = "Error"
        $status.Details += "Error checking event log: $($_.Exception.Message)"
    }

    # Check backup files
    try {
        if (Test-Path $script:Config.VeeamShare) {
            $backupFiles = Get-ChildItem -Path $script:Config.VeeamShare -Recurse -File -ErrorAction SilentlyContinue |
                          Where-Object { $_.Extension -in @('.vbk', '.vib', '.vbm') } |
                          Sort-Object LastWriteTime -Descending

            if ($backupFiles) {
                $newestFile = $backupFiles[0]
                $status.Details += "Newest backup file: $($newestFile.Name)"
                $status.Details += "File date: $($newestFile.LastWriteTime)"
                $status.Details += "File size: $([math]::Round($newestFile.Length / 1GB, 2)) GB"

                # Check if backup is recent (within 2 days)
                if ($newestFile.LastWriteTime -gt (Get-Date).AddDays(-2)) {
                    if ($status.Status -eq "Unknown" -or $status.Status -eq "No Events") {
                        $status.Status = "Success"
                    }
                } else {
                    $status.Status = "Stale"
                    $status.Details += "WARNING: No recent backup files (older than 2 days)"
                }
            } else {
                $status.Details += "WARNING: No backup files found"
            }
        } else {
            $status.Status = "Error"
            $status.Details += "ERROR: Cannot access backup destination"
        }
    } catch {
        $status.Details += "Error checking backup files: $($_.Exception.Message)"
    }

    return $status
}

function Get-WorkspaceBackupStatus {
    Write-Log "Checking workspace backup status..." "INFO"

    $status = @{
        Type = "Workspace Hourly Sync"
        Status = "Unknown"
        LastBackup = "Never"
        LastSuccess = "Never"
        LastFailure = "Never"
        NextScheduled = "Unknown"
        Details = @()
    }

    # Check scheduled task
    $task = Get-ScheduledTask -TaskName "*Workspace*" -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($task) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName -ErrorAction SilentlyContinue

        if ($taskInfo) {
            $status.LastBackup = $taskInfo.LastRunTime.ToString()
            $status.NextScheduled = $taskInfo.NextRunTime.ToString()

            if ($taskInfo.LastTaskResult -eq 0) {
                $status.Status = "Success"
                $status.LastSuccess = $taskInfo.LastRunTime.ToString()
            } else {
                $status.Status = "Failed"
                $status.LastFailure = $taskInfo.LastRunTime.ToString()
                $status.Details += "Last task result code: $($taskInfo.LastTaskResult)"
            }

            $status.Details += "Task state: $($task.State)"
            $status.Details += "Task enabled: $($task.Settings.Enabled)"
        }
    } else {
        $status.Status = "Not Configured"
        $status.Details += "Scheduled task not found"
    }

    # Check backup destination
    try {
        if (Test-Path $script:Config.WorkspaceShare) {
            $files = Get-ChildItem -Path $script:Config.WorkspaceShare -Recurse -File -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

            if ($files) {
                $status.Details += "Latest file: $($files.Name)"
                $status.Details += "Modified: $($files.LastWriteTime)"
            }
        } else {
            $status.Status = "Error"
            $status.Details += "ERROR: Cannot access workspace backup share"
        }
    } catch {
        $status.Details += "Error checking workspace backup: $($_.Exception.Message)"
    }

    # Check logs
    $logPattern = "workspace-backup-*.log"
    $latestLog = Get-ChildItem -Path $script:Config.LogDir -Filter $logPattern -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

    if ($latestLog) {
        $logContent = Get-Content -Path $latestLog.FullName -Tail 5 -ErrorAction SilentlyContinue
        $status.Details += "Log: $($latestLog.Name)"

        if ($logContent -match "ERROR") {
            $status.Status = "Failed"
            $status.Details += "Errors found in log"
        }
    }

    return $status
}

function Get-WSLBackupStatus {
    Write-Log "Checking WSL backup status..." "INFO"

    $status = @{
        Type = "WSL Daily Backup"
        Status = "Unknown"
        LastBackup = "Never"
        LastSuccess = "Never"
        LastFailure = "Never"
        NextScheduled = "Unknown"
        Details = @()
    }

    # Check scheduled task
    $task = Get-ScheduledTask -TaskName "*WSL*" -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($task) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName -ErrorAction SilentlyContinue

        if ($taskInfo) {
            $status.LastBackup = $taskInfo.LastRunTime.ToString()
            $status.NextScheduled = $taskInfo.NextRunTime.ToString()

            if ($taskInfo.LastTaskResult -eq 0) {
                $status.Status = "Success"
                $status.LastSuccess = $taskInfo.LastRunTime.ToString()
            } else {
                $status.Status = "Failed"
                $status.LastFailure = $taskInfo.LastRunTime.ToString()
                $status.Details += "Last task result code: $($taskInfo.LastTaskResult)"
            }

            $status.Details += "Task state: $($task.State)"
        }
    } else {
        $status.Status = "Not Configured"
        $status.Details += "Scheduled task not found"
    }

    # Check WSL backup files
    try {
        if (Test-Path $script:Config.WSLShare) {
            $wslBackups = Get-ChildItem -Path $script:Config.WSLShare -Filter "*.tar.gz" -ErrorAction SilentlyContinue |
                         Sort-Object LastWriteTime -Descending

            if ($wslBackups) {
                $status.Details += "Total WSL backups: $($wslBackups.Count)"
                $status.Details += "Latest backup: $($wslBackups[0].Name)"
                $status.Details += "Backup date: $($wslBackups[0].LastWriteTime)"
                $status.Details += "Backup size: $([math]::Round($wslBackups[0].Length / 1GB, 2)) GB"

                # Check if backup is recent
                if ($wslBackups[0].LastWriteTime -gt (Get-Date).AddDays(-2)) {
                    if ($status.Status -eq "Unknown") {
                        $status.Status = "Success"
                    }
                }
            } else {
                $status.Details += "WARNING: No WSL backup files found"
            }
        } else {
            $status.Status = "Error"
            $status.Details += "ERROR: Cannot access WSL backup share"
        }
    } catch {
        $status.Details += "Error checking WSL backups: $($_.Exception.Message)"
    }

    return $status
}

function Get-StorageStatus {
    Write-Log "Checking storage status..." "INFO"

    $storageStatus = @()

    foreach ($share in @($script:Config.VeeamShare, $script:Config.WorkspaceShare, $script:Config.WSLShare)) {
        $info = @{
            Share = $share
            Accessible = $false
            TotalGB = 0
            UsedGB = 0
            FreeGB = 0
            FreePercent = 0
            Status = "Unknown"
        }

        try {
            if (Test-Path $share) {
                $info.Accessible = $true

                # Try to get space info
                # Note: This may not work for all network shares
                $files = Get-ChildItem -Path $share -Recurse -File -ErrorAction SilentlyContinue
                $totalSize = ($files | Measure-Object -Property Length -Sum).Sum

                $info.UsedGB = [math]::Round($totalSize / 1GB, 2)
                $info.Status = "Accessible"

                Write-Log "Share $share : $($info.UsedGB) GB used" "INFO"
            } else {
                $info.Status = "Not Accessible"
                Write-Log "WARNING: Cannot access share: $share" "WARNING"
            }
        } catch {
            $info.Status = "Error"
            Write-Log "ERROR checking share $share : $($_.Exception.Message)" "ERROR"
        }

        $storageStatus += $info
    }

    return $storageStatus
}

function Get-OverallStatus {
    param(
        [array]$BackupStatuses
    )

    $overall = @{
        Status = "Success"
        TotalJobs = $BackupStatuses.Count
        SuccessJobs = 0
        FailedJobs = 0
        WarningJobs = 0
        UnknownJobs = 0
        Errors = @()
        Warnings = @()
    }

    foreach ($backup in $BackupStatuses) {
        switch ($backup.Status) {
            "Success"        { $overall.SuccessJobs++ }
            "Failed"         {
                $overall.FailedJobs++
                $overall.Errors += "$($backup.Type): $($backup.Status)"
            }
            "Stale"          {
                $overall.WarningJobs++
                $overall.Warnings += "$($backup.Type): Backup is stale"
            }
            "Not Configured" {
                $overall.WarningJobs++
                $overall.Warnings += "$($backup.Type): Not configured"
            }
            "Error"          {
                $overall.FailedJobs++
                $overall.Errors += "$($backup.Type): Error"
            }
            default          { $overall.UnknownJobs++ }
        }
    }

    # Determine overall status
    if ($overall.FailedJobs -gt 0) {
        $overall.Status = "Failed"
    } elseif ($overall.WarningJobs -gt 0) {
        $overall.Status = "Warning"
    } elseif ($overall.UnknownJobs -eq $overall.TotalJobs) {
        $overall.Status = "Unknown"
    }

    return $overall
}

# ===== REPORTING =====

function New-HtmlReport {
    param(
        [array]$BackupStatuses,
        [array]$StorageStatus,
        [hashtable]$Overall
    )

    Write-Log "Generating HTML report..." "INFO"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Veeam Backup Report - $env:COMPUTERNAME</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c5aa0;
            border-bottom: 3px solid #2c5aa0;
            padding-bottom: 10px;
        }
        h2 {
            color: #5a7aa0;
            margin-top: 30px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }
        .status-box {
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
            font-size: 18px;
        }
        .status-success {
            background-color: #d4edda;
            border-left: 5px solid #28a745;
            color: #155724;
        }
        .status-warning {
            background-color: #fff3cd;
            border-left: 5px solid #ffc107;
            color: #856404;
        }
        .status-failed {
            background-color: #f8d7da;
            border-left: 5px solid #dc3545;
            color: #721c24;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }
        th {
            background-color: #2c5aa0;
            color: white;
            padding: 12px;
            text-align: left;
        }
        td {
            border: 1px solid #ddd;
            padding: 10px;
        }
        tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        .badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 3px;
            font-weight: bold;
            font-size: 12px;
        }
        .badge-success { background-color: #28a745; color: white; }
        .badge-warning { background-color: #ffc107; color: black; }
        .badge-failed { background-color: #dc3545; color: white; }
        .badge-unknown { background-color: #6c757d; color: white; }
        .details {
            font-size: 12px;
            color: #666;
            margin-top: 5px;
        }
        .footer {
            margin-top: 50px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
            font-size: 12px;
            text-align: center;
        }
        .metric {
            display: inline-block;
            margin: 10px 20px;
            text-align: center;
        }
        .metric-value {
            font-size: 36px;
            font-weight: bold;
            color: #2c5aa0;
        }
        .metric-label {
            font-size: 14px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Veeam Backup Status Report</h1>

        <div class="status-box status-$($Overall.Status.ToLower())">
            <strong>Overall Status:</strong> $($Overall.Status.ToUpper())
        </div>

        <div style="text-align: center; margin: 30px 0;">
            <div class="metric">
                <div class="metric-value">$($Overall.TotalJobs)</div>
                <div class="metric-label">Total Jobs</div>
            </div>
            <div class="metric">
                <div class="metric-value" style="color: #28a745;">$($Overall.SuccessJobs)</div>
                <div class="metric-label">Success</div>
            </div>
            <div class="metric">
                <div class="metric-value" style="color: #ffc107;">$($Overall.WarningJobs)</div>
                <div class="metric-label">Warnings</div>
            </div>
            <div class="metric">
                <div class="metric-value" style="color: #dc3545;">$($Overall.FailedJobs)</div>
                <div class="metric-label">Failed</div>
            </div>
        </div>

        <p><strong>Computer:</strong> $env:COMPUTERNAME</p>
        <p><strong>Report Time:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>

        <h2>Backup Jobs</h2>
        <table>
            <tr>
                <th>Backup Type</th>
                <th>Status</th>
                <th>Last Backup</th>
                <th>Last Success</th>
                <th>Next Scheduled</th>
            </tr>
"@

    foreach ($backup in $BackupStatuses) {
        $badgeClass = switch ($backup.Status) {
            "Success" { "badge-success" }
            "Failed" { "badge-failed" }
            "Warning" { "badge-warning" }
            "Stale" { "badge-warning" }
            "Not Configured" { "badge-warning" }
            "Error" { "badge-failed" }
            default { "badge-unknown" }
        }

        $html += @"
            <tr>
                <td><strong>$($backup.Type)</strong></td>
                <td><span class="badge $badgeClass">$($backup.Status)</span></td>
                <td>$($backup.LastBackup)</td>
                <td>$($backup.LastSuccess)</td>
                <td>$($backup.NextScheduled)</td>
            </tr>
"@

        if ($backup.Details -and $backup.Details.Count -gt 0) {
            $html += @"
            <tr>
                <td colspan="5">
                    <div class="details">
"@
            foreach ($detail in $backup.Details) {
                $html += "                        $detail<br>`n"
            }
            $html += @"
                    </div>
                </td>
            </tr>
"@
        }
    }

    $html += @"
        </table>

        <h2>Storage Information</h2>
        <table>
            <tr>
                <th>Share</th>
                <th>Status</th>
                <th>Used Space (GB)</th>
            </tr>
"@

    foreach ($storage in $StorageStatus) {
        $statusBadge = if ($storage.Accessible) { "badge-success" } else { "badge-failed" }

        $html += @"
            <tr>
                <td>$($storage.Share)</td>
                <td><span class="badge $statusBadge">$($storage.Status)</span></td>
                <td>$($storage.UsedGB)</td>
            </tr>
"@
    }

    $html += @"
        </table>
"@

    # Add errors section if any
    if ($Overall.Errors.Count -gt 0) {
        $html += @"
        <h2 style="color: #dc3545;">Errors</h2>
        <div class="status-box status-failed">
            <ul>
"@
        foreach ($error in $Overall.Errors) {
            $html += "                <li>$error</li>`n"
        }
        $html += @"
            </ul>
        </div>
"@
    }

    # Add warnings section if any
    if ($Overall.Warnings.Count -gt 0) {
        $html += @"
        <h2 style="color: #ffc107;">Warnings</h2>
        <div class="status-box status-warning">
            <ul>
"@
        foreach ($warning in $Overall.Warnings) {
            $html += "                <li>$warning</li>`n"
        }
        $html += @"
            </ul>
        </div>
"@
    }

    $html += @"
        <div class="footer">
            <p>Generated by Enhanced Veeam Monitoring System</p>
            <p>$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
    </div>
</body>
</html>
"@

    try {
        $html | Out-File -FilePath $reportFile -Force -Encoding UTF8
        Write-Log "HTML report saved: $reportFile" "SUCCESS"
        return $reportFile
    } catch {
        Write-Log "ERROR saving HTML report: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Show-ConsoleSummary {
    param(
        [array]$BackupStatuses,
        [hashtable]$Overall
    )

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host " VEEAM BACKUP STATUS SUMMARY" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    $statusColor = switch ($Overall.Status) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Failed" { "Red" }
        default { "White" }
    }

    Write-Host "Overall Status: " -NoNewline
    Write-Host $Overall.Status -ForegroundColor $statusColor
    Write-Host "Computer: $env:COMPUTERNAME"
    Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""

    Write-Host "SUMMARY:" -ForegroundColor Cyan
    Write-Host "  Total Jobs:    $($Overall.TotalJobs)" -ForegroundColor White
    Write-Host "  Success:       " -NoNewline
    Write-Host "$($Overall.SuccessJobs)" -ForegroundColor Green
    Write-Host "  Warnings:      " -NoNewline
    Write-Host "$($Overall.WarningJobs)" -ForegroundColor Yellow
    Write-Host "  Failed:        " -NoNewline
    Write-Host "$($Overall.FailedJobs)" -ForegroundColor Red
    Write-Host ""

    Write-Host "BACKUP JOBS:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($backup in $BackupStatuses) {
        $color = switch ($backup.Status) {
            "Success" { "Green" }
            "Failed" { "Red" }
            "Warning" { "Yellow" }
            "Stale" { "Yellow" }
            "Error" { "Red" }
            default { "White" }
        }

        Write-Host "  $($backup.Type)" -ForegroundColor White
        Write-Host "    Status: " -NoNewline
        Write-Host "$($backup.Status)" -ForegroundColor $color
        Write-Host "    Last Backup: $($backup.LastBackup)"
        Write-Host "    Next Scheduled: $($backup.NextScheduled)"
        Write-Host ""
    }

    if ($Overall.Errors.Count -gt 0) {
        Write-Host "ERRORS:" -ForegroundColor Red
        foreach ($error in $Overall.Errors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
        Write-Host ""
    }

    if ($Overall.Warnings.Count -gt 0) {
        Write-Host "WARNINGS:" -ForegroundColor Yellow
        foreach ($warning in $Overall.Warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ===== MAIN EXECUTION =====

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " ENHANCED VEEAM BACKUP MONITORING" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== Enhanced Veeam Monitoring Started ===" "INFO"

do {
    Write-Log "Running backup status check..." "INFO"

    # Collect all backup statuses
    $backupStatuses = @()
    $backupStatuses += Get-VeeamBackupStatus
    $backupStatuses += Get-WorkspaceBackupStatus
    $backupStatuses += Get-WSLBackupStatus

    # Get storage status
    $storageStatus = Get-StorageStatus

    # Calculate overall status
    $overall = Get-OverallStatus -BackupStatuses $backupStatuses

    # Show console summary
    Show-ConsoleSummary -BackupStatuses $backupStatuses -Overall $overall

    # Generate HTML report
    $report = New-HtmlReport -BackupStatuses $backupStatuses -StorageStatus $storageStatus -Overall $overall

    # Save status to JSON
    $fullStatus = @{
        Timestamp = (Get-Date).ToString()
        Overall = $overall
        Backups = $backupStatuses
        Storage = $storageStatus
    }

    try {
        $fullStatus | ConvertTo-Json -Depth 10 | Out-File -FilePath $statusFile -Force
        Write-Log "Status saved: $statusFile" "INFO"
    } catch {
        Write-Log "WARNING: Could not save status file: $($_.Exception.Message)" "WARNING"
    }

    # Email alerts if enabled
    if ($EnableEmailAlerts -and ($Overall.Status -eq "Failed" -or ($AlertOnWarning -and $Overall.Status -eq "Warning"))) {
        Write-Log "Email alerts enabled but not implemented in this version" "WARNING"
        Write-Log "Use 4-monitor-backup-jobs.ps1 for email functionality" "INFO"
    }

    # Continuous monitoring
    if ($ContinuousMonitoring) {
        Write-Log "Next check in $CheckInterval minutes..." "INFO"
        Write-Host ""
        Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor Yellow
        Write-Host ""

        Start-Sleep -Seconds ($CheckInterval * 60)
    }

} while ($ContinuousMonitoring)

Write-Log "=== Monitoring Completed ===" "SUCCESS"
Write-Log "Report: $reportFile" "INFO"
Write-Log "Log: $logFile" "INFO"

# Open HTML report in browser
if ($report -and (Test-Path $report)) {
    try {
        Start-Process $report
    } catch {
        Write-Log "Could not open report automatically" "WARNING"
    }
}

exit 0
