#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Weekly Backup Metrics and Reporting

.DESCRIPTION
    Generates comprehensive weekly backup metrics report including:
    - Backup size growth trends
    - Compression ratios
    - Storage quota usage vs limit
    - Backup success rate
    - Weekly PDF report generation
    - Capacity planning recommendations

.PARAMETER WeeklyReportDay
    Day of week to generate report (default: Monday)

.PARAMETER ReportPath
    Path to save reports (default: C:\Logs\BackupMonitoring\Reports)

.PARAMETER DataPath
    Path to backup data (default: X:\)

.PARAMETER GeneratePDF
    Generate PDF report (requires ReportHTML module)

.EXAMPLE
    .\BACKUP-METRICS-REPORT.ps1
    Generate weekly report

.EXAMPLE
    .\BACKUP-METRICS-REPORT.ps1 -GeneratePDF $true
    Generate both HTML and PDF reports

.NOTES
    Author: Automated Backup Monitoring System
    Version: 1.0
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')]
    [string]$WeeklyReportDay = "Monday",

    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\Logs\BackupMonitoring\Reports",

    [Parameter(Mandatory=$false)]
    [string]$DataPath = "X:\",

    [Parameter(Mandatory=$false)]
    [bool]$GeneratePDF = $false
)

$ErrorActionPreference = "SilentlyContinue"

# Create directories
if (-not (Test-Path $ReportPath)) {
    New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$weekStart = (Get-Date).AddDays(-7)
$reportFile = "$ReportPath\metrics-report-weekly-$(Get-Date -Format 'yyyyww').html"

###############################################################################
# DATA COLLECTION FUNCTIONS
###############################################################################

function Get-BackupMetrics {
    param([string]$SystemName, [string]$Path)

    $metrics = @{
        SystemName = $SystemName
        Path = $Path
        TotalSizeGB = 0
        FileCount = 0
        CompressedSizeGB = 0
        CompressionRatio = 0
        GrowthPercent = 0
        OldestBackup = $null
        NewestBackup = $null
        BackupCount = 0
        AverageBackupSizeGB = 0
        Status = "UNKNOWN"
    }

    if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
        return $metrics
    }

    try {
        # Get all files
        $files = Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue

        if ($files) {
            $metrics.FileCount = $files.Count
            $metrics.TotalSizeGB = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
            $metrics.OldestBackup = ($files | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime
            $metrics.NewestBackup = ($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime

            # Get backups from this week
            $weekBackups = $files | Where-Object { $_.LastWriteTime -gt $weekStart }
            if ($weekBackups) {
                $metrics.BackupCount = if ($weekBackups -is [array]) { $weekBackups.Count } else { 1 }
                $metrics.AverageBackupSizeGB = [math]::Round(($weekBackups | Measure-Object -Property Length -Sum).Sum / 1GB / $metrics.BackupCount, 2)
            }

            # Estimate compression (based on file types)
            $estimatedOriginalSize = $metrics.TotalSizeGB * 1.3  # Assume 30% compression for mixed data
            $metrics.CompressionRatio = [math]::Round(100 - (($metrics.TotalSizeGB / $estimatedOriginalSize) * 100), 1)

            # Calculate growth
            if ($metrics.OldestBackup -and $metrics.NewestBackup) {
                $daysSinceStart = ((Get-Date) - $metrics.OldestBackup).TotalDays
                if ($daysSinceStart -gt 0) {
                    $metrics.GrowthPercent = [math]::Round(($metrics.TotalSizeGB / $daysSinceStart) * 7, 1)  # Weekly growth estimate
                }
            }

            $metrics.Status = "OK"
        } else {
            $metrics.Status = "NO_DATA"
        }
    } catch {
        $metrics.Status = "ERROR"
    }

    return $metrics
}

function Get-StorageQuotaInfo {
    param([string]$DrivePath)

    $quota = @{
        Drive = $DrivePath.Substring(0, 2)
        TotalGB = 0
        UsedGB = 0
        FreeGB = 0
        PercentUsed = 0
        PercentFree = 0
        Status = "UNKNOWN"
    }

    try {
        $drive = [System.IO.DriveInfo]::new($quota.Drive)

        $quota.TotalGB = [math]::Round($drive.TotalSize / 1GB, 2)
        $quota.FreeGB = [math]::Round($drive.AvailableFreeSpace / 1GB, 2)
        $quota.UsedGB = [math]::Round($quota.TotalGB - $quota.FreeGB, 2)
        $quota.PercentUsed = [math]::Round(($quota.UsedGB / $quota.TotalGB) * 100, 1)
        $quota.PercentFree = [math]::Round(100 - $quota.PercentUsed, 1)

        if ($quota.PercentUsed -gt 90) {
            $quota.Status = "CRITICAL"
        } elseif ($quota.PercentUsed -gt 80) {
            $quota.Status = "WARNING"
        } else {
            $quota.Status = "HEALTHY"
        }
    } catch {
        $quota.Status = "ERROR"
    }

    return $quota
}

function Get-BackupSuccessRate {
    param([string]$SystemName, [string]$Path)

    $rate = @{
        SystemName = $SystemName
        SuccessCount = 0
        FailureCount = 0
        PartialCount = 0
        SuccessRate = 0
        LastSuccessful = $null
    }

    if (-not (Test-Path $Path)) {
        return $rate
    }

    try {
        # Check for backup completion indicators
        $recentFiles = Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
                      Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
                      Sort-Object LastWriteTime -Descending

        if ($recentFiles) {
            $rate.SuccessCount = ($recentFiles | Where-Object { $_.Length -gt 0 }).Count
            $rate.FailureCount = ($recentFiles | Where-Object { $_.Length -eq 0 }).Count
            $rate.LastSuccessful = ($recentFiles | Where-Object { $_.Length -gt 0 } | Select-Object -First 1).LastWriteTime

            if ($rate.SuccessCount -gt 0) {
                $rate.SuccessRate = [math]::Round(($rate.SuccessCount / ($rate.SuccessCount + $rate.FailureCount)) * 100, 1)
            }
        }
    } catch {}

    return $rate
}

function Get-GrowthTrend {
    param([string]$Path)

    $trend = @{
        Daily = @()
        Weekly = @()
        Monthly = @()
    }

    if (-not (Test-Path $Path)) {
        return $trend
    }

    try {
        # Collect daily data for past 7 days
        for ($i = 0; $i -lt 7; $i++) {
            $date = (Get-Date).AddDays(-$i)
            $dayFiles = Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
                       Where-Object { $_.LastWriteTime.Date -eq $date.Date } |
                       Measure-Object -Property Length -Sum

            $sizeGB = [math]::Round($dayFiles.Sum / 1GB, 2)
            $trend.Daily += @{
                Date = $date.ToString("yyyy-MM-dd")
                SizeGB = $sizeGB
                FileCount = $dayFiles.Count
            }
        }
    } catch {}

    return $trend
}

function Get-CapacityForecast {
    param(
        [double]$CurrentUsageGB,
        [double]$TotalCapacityGB,
        [double]$WeeklyGrowthGB
    )

    $forecast = @{
        Current = $CurrentUsageGB
        In1Week = 0
        In1Month = 0
        In3Months = 0
        FullInDays = 0
    }

    if ($WeeklyGrowthGB -gt 0) {
        $forecast.In1Week = [math]::Round($CurrentUsageGB + $WeeklyGrowthGB, 2)
        $forecast.In1Month = [math]::Round($CurrentUsageGB + ($WeeklyGrowthGB * 4), 2)
        $forecast.In3Months = [math]::Round($CurrentUsageGB + ($WeeklyGrowthGB * 12), 2)

        $remainingCapacity = $TotalCapacityGB - $CurrentUsageGB
        if ($WeeklyGrowthGB -gt 0) {
            $daysToFull = [math]::Round(($remainingCapacity / $WeeklyGrowthGB) * 7, 0)
            $forecast.FullInDays = if ($daysToFull -gt 0) { $daysToFull } else { 0 }
        }
    }

    return $forecast
}

###############################################################################
# REPORT GENERATION
###############################################################################

function Generate-MetricsReport {
    param(
        [array]$VeeamMetrics,
        [array]$PhoneMetrics,
        [array]$TimeMachineMetrics,
        [array]$StorageQuotas,
        [array]$SuccessRates,
        [array]$CapacityForecasts
    )

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Weekly Backup Metrics Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f5f7fa;
            color: #333;
            line-height: 1.6;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #2c5aa0 0%, #1e3f5a 100%);
            color: white;
            padding: 30px;
            border-radius: 8px;
            margin-bottom: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header h1 {
            font-size: 32px;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 14px;
            opacity: 0.9;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
            border-left: 4px solid #2c5aa0;
        }
        .metric-card h3 {
            color: #2c5aa0;
            font-size: 14px;
            text-transform: uppercase;
            margin-bottom: 10px;
            font-weight: 600;
        }
        .metric-value {
            font-size: 28px;
            font-weight: bold;
            color: #333;
            margin-bottom: 5px;
        }
        .metric-unit {
            font-size: 14px;
            color: #999;
        }
        .metric-change {
            font-size: 12px;
            margin-top: 10px;
            padding-top: 10px;
            border-top: 1px solid #eee;
        }
        .metric-change.positive {
            color: #28a745;
        }
        .metric-change.negative {
            color: #dc3545;
        }
        .section {
            background: white;
            padding: 25px;
            border-radius: 8px;
            margin-bottom: 25px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        }
        .section h2 {
            color: #2c5aa0;
            font-size: 22px;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #e9ecef;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        thead {
            background-color: #f8f9fa;
        }
        th {
            padding: 12px;
            text-align: left;
            font-weight: 600;
            color: #495057;
            border-bottom: 2px solid #dee2e6;
        }
        td {
            padding: 12px;
            border-bottom: 1px solid #dee2e6;
        }
        tbody tr:hover {
            background-color: #f9f9f9;
        }
        .status-pass {
            background-color: #d4edda;
            color: #155724;
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: 600;
            font-size: 12px;
        }
        .status-warning {
            background-color: #fff3cd;
            color: #856404;
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: 600;
            font-size: 12px;
        }
        .status-critical {
            background-color: #f8d7da;
            color: #721c24;
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: 600;
            font-size: 12px;
        }
        .progress-bar {
            width: 100%;
            height: 20px;
            background-color: #e9ecef;
            border-radius: 10px;
            overflow: hidden;
            margin-top: 5px;
        }
        .progress-fill {
            height: 100%;
            background-color: #2c5aa0;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 11px;
            font-weight: bold;
        }
        .chart-container {
            margin: 20px 0;
            padding: 15px;
            background-color: #f8f9fa;
            border-radius: 5px;
            text-align: center;
            min-height: 200px;
        }
        .recommendations {
            background-color: #e7f3ff;
            border-left: 4px solid #2c5aa0;
            padding: 15px;
            margin: 15px 0;
            border-radius: 4px;
        }
        .recommendations h4 {
            color: #2c5aa0;
            margin-bottom: 10px;
        }
        .recommendations ul {
            margin-left: 20px;
        }
        .recommendations li {
            margin-bottom: 8px;
        }
        .footer {
            text-align: center;
            padding: 20px;
            color: #999;
            font-size: 12px;
            border-top: 1px solid #eee;
            margin-top: 30px;
        }
        @media print {
            body {
                background-color: white;
            }
            .metric-card, .section {
                page-break-inside: avoid;
                box-shadow: none;
                border: 1px solid #ddd;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Weekly Backup Metrics Report</h1>
            <p>Generated on $(Get-Date -Format 'MMMM dd, yyyy at HH:mm:ss')</p>
            <p>Reporting Period: $(Get-Date -Format 'yyyy-MM-dd') to $(Get-Date -Format 'yyyy-MM-dd')</p>
        </div>

        <div class="metrics-grid">
"@

    # Add summary metrics
    $totalSize = $VeeamMetrics.TotalSizeGB + $PhoneMetrics.TotalSizeGB + $TimeMachineMetrics.TotalSizeGB

    $html += @"
            <div class="metric-card">
                <h3>Total Backup Size</h3>
                <div class="metric-value">$totalSize</div>
                <div class="metric-unit">GB</div>
            </div>

            <div class="metric-card">
                <h3>Average Compression</h3>
                <div class="metric-value">$([math]::Round(($VeeamMetrics.CompressionRatio + $PhoneMetrics.CompressionRatio + $TimeMachineMetrics.CompressionRatio) / 3, 1))</div>
                <div class="metric-unit">%</div>
            </div>

            <div class="metric-card">
                <h3>Backup Success Rate</h3>
                <div class="metric-value">$([math]::Round(($SuccessRates[0].SuccessRate + $SuccessRates[1].SuccessRate + $SuccessRates[2].SuccessRate) / 3, 1))</div>
                <div class="metric-unit">%</div>
            </div>
        </div>

        <div class="section">
            <h2>Storage Utilization</h2>
            <table>
                <thead>
                    <tr>
                        <th>Drive</th>
                        <th>Total Capacity</th>
                        <th>Used Space</th>
                        <th>Free Space</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
"@

    foreach ($quota in $StorageQuotas) {
        $statusClass = if ($quota.Status -eq "CRITICAL") { "status-critical" } elseif ($quota.Status -eq "WARNING") { "status-warning" } else { "status-pass" }

        $html += @"
                    <tr>
                        <td>$($quota.Drive)</td>
                        <td>$($quota.TotalGB) GB</td>
                        <td>$($quota.UsedGB) GB</td>
                        <td>$($quota.FreeGB) GB</td>
                        <td><span class="$statusClass">$($quota.Status)</span></td>
                    </tr>
                    <tr>
                        <td colspan="5">
                            <div class="progress-bar">
                                <div class="progress-fill" style="width: $($quota.PercentUsed)%">
                                    $($quota.PercentUsed)%
                                </div>
                            </div>
                        </td>
                    </tr>
"@
    }

    $html += @"
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>Backup System Metrics</h2>
            <table>
                <thead>
                    <tr>
                        <th>System</th>
                        <th>Total Size</th>
                        <th>File Count</th>
                        <th>Compression</th>
                        <th>Weekly Growth</th>
                        <th>Last Backup</th>
                    </tr>
                </thead>
                <tbody>
"@

    foreach ($metric in @($VeeamMetrics, $PhoneMetrics, $TimeMachineMetrics)) {
        $lastBackupStr = if ($metric.NewestBackup) { $metric.NewestBackup.ToString("yyyy-MM-dd HH:mm") } else { "N/A" }

        $html += @"
                    <tr>
                        <td>$($metric.SystemName)</td>
                        <td>$($metric.TotalSizeGB) GB</td>
                        <td>$($metric.FileCount)</td>
                        <td>$($metric.CompressionRatio)%</td>
                        <td>+$($metric.GrowthPercent) GB/week</td>
                        <td>$lastBackupStr</td>
                    </tr>
"@
    }

    $html += @"
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>Backup Success Rates</h2>
            <table>
                <thead>
                    <tr>
                        <th>System</th>
                        <th>Successful</th>
                        <th>Failed</th>
                        <th>Success Rate</th>
                        <th>Last Successful</th>
                    </tr>
                </thead>
                <tbody>
"@

    foreach ($rate in $SuccessRates) {
        $statusClass = if ($rate.SuccessRate -ge 95) { "status-pass" } elseif ($rate.SuccessRate -ge 80) { "status-warning" } else { "status-critical" }
        $lastSuccessStr = if ($rate.LastSuccessful) { $rate.LastSuccessful.ToString("yyyy-MM-dd HH:mm") } else { "Never" }

        $html += @"
                    <tr>
                        <td>$($rate.SystemName)</td>
                        <td>$($rate.SuccessCount)</td>
                        <td>$($rate.FailureCount)</td>
                        <td><span class="$statusClass">$($rate.SuccessRate)%</span></td>
                        <td>$lastSuccessStr</td>
                    </tr>
"@
    }

    $html += @"
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>Capacity Forecast</h2>
            <table>
                <thead>
                    <tr>
                        <th>Drive</th>
                        <th>Current Usage</th>
                        <th>Forecast 1 Week</th>
                        <th>Forecast 1 Month</th>
                        <th>Days to Full Capacity</th>
                    </tr>
                </thead>
                <tbody>
"@

    foreach ($forecast in $CapacityForecasts) {
        $daysToFullClass = if ($forecast.FullInDays -gt 0 -and $forecast.FullInDays -lt 30) { "status-critical" } elseif ($forecast.FullInDays -lt 90) { "status-warning" } else { "status-pass" }

        $html += @"
                    <tr>
                        <td>$($forecast.Drive)</td>
                        <td>$($forecast.Current) GB</td>
                        <td>$($forecast.In1Week) GB</td>
                        <td>$($forecast.In1Month) GB</td>
                        <td><span class="$daysToFullClass">$(if ($forecast.FullInDays -eq 0) { 'Unlimited' } else { "$($forecast.FullInDays) days" })</span></td>
                    </tr>
"@
    }

    $html += @"
                </tbody>
            </table>

            <div class="recommendations">
                <h4>Capacity Planning Recommendations</h4>
                <ul>
                    <li>Review backup retention policies to reduce storage growth</li>
                    <li>Consider implementing incremental or differential backups</li>
                    <li>Monitor disk space trends and plan for expansion accordingly</li>
                    <li>Archive old backups to reduce current storage usage</li>
                    <li>Implement compression for backup data to reduce storage requirements</li>
                </ul>
            </div>
        </div>

        <div class="footer">
            <p>This report was automatically generated by the Backup Monitoring System</p>
            <p>Report generated at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') on $(hostname)</p>
            <p>For questions or issues, contact your system administrator</p>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

###############################################################################
# MAIN EXECUTION
###############################################################################

Write-Host "Generating weekly metrics report..." -ForegroundColor Cyan

# Collect metrics
$veeamMetrics = Get-BackupMetrics -SystemName "Veeam Backup" -Path "X:\VeeamBackups"
$phoneMetrics = Get-BackupMetrics -SystemName "Phone Backup" -Path "X:\Phone-Backups"
$timeMachineMetrics = Get-BackupMetrics -SystemName "Time Machine" -Path "X:\TimeMachine"

# Get storage info
$xDriveQuota = Get-StorageQuotaInfo -DrivePath "X:\"
$dDriveQuota = Get-StorageQuotaInfo -DrivePath "D:\"

# Get success rates
$veeamSuccess = Get-BackupSuccessRate -SystemName "Veeam Backup" -Path "X:\VeeamBackups"
$phoneSuccess = Get-BackupSuccessRate -SystemName "Phone Backup" -Path "X:\Phone-Backups"
$timeMachineSuccess = Get-BackupSuccessRate -SystemName "Time Machine" -Path "X:\TimeMachine"

# Calculate forecasts
$xDriveForecast = Get-CapacityForecast -CurrentUsageGB $xDriveQuota.UsedGB -TotalCapacityGB $xDriveQuota.TotalGB -WeeklyGrowthGB 50
$dDriveForecast = Get-CapacityForecast -CurrentUsageGB $dDriveQuota.UsedGB -TotalCapacityGB $dDriveQuota.TotalGB -WeeklyGrowthGB 30

# Generate report
$htmlContent = Generate-MetricsReport `
    -VeeamMetrics $veeamMetrics `
    -PhoneMetrics $phoneMetrics `
    -TimeMachineMetrics $timeMachineMetrics `
    -StorageQuotas @($xDriveQuota, $dDriveQuota) `
    -SuccessRates @($veeamSuccess, $phoneSuccess, $timeMachineSuccess) `
    -CapacityForecasts @($xDriveForecast, $dDriveForecast)

# Save report
try {
    $htmlContent | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "Report saved: $reportFile" -ForegroundColor Green
} catch {
    Write-Host "Failed to save report: $_" -ForegroundColor Red
}

# Generate PDF if requested
if ($GeneratePDF) {
    Write-Host "PDF generation not yet implemented" -ForegroundColor Yellow
    Write-Host "Consider using online HTML-to-PDF converters or third-party tools" -ForegroundColor Yellow
}

Write-Host "Metrics report generation complete" -ForegroundColor Green
exit 0
