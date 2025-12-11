#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Daily Comprehensive Health Check for All Backup Systems

.DESCRIPTION
    Runs every morning (default 6:00 AM) to:
    - Check all three backup systems (Veeam, Phone, Time Machine)
    - Verify SMB connectivity
    - Verify network paths are accessible
    - Generate daily report with pass/fail status
    - Send report via email or save locally

.PARAMETER CheckTime
    Time to run daily check (default: 06:00)

.PARAMETER EmailReport
    Send report via email (true/false)

.PARAMETER SaveLocally
    Save report to local file (default: true)

.PARAMETER ReportPath
    Path to save reports (default: C:\Logs\BackupMonitoring\Reports)

.PARAMETER ConfigPath
    Path to alerting configuration (default: C:\BackupMonitoring\Config\alerting-config.json)

.EXAMPLE
    .\HEALTH-CHECK-DAILY.ps1
    Run daily health check with defaults

.EXAMPLE
    .\HEALTH-CHECK-DAILY.ps1 -EmailReport $true
    Run and email report

.NOTES
    Author: Automated Backup Monitoring System
    Version: 1.0
    Schedule with: schtasks /create /tn "Daily Backup Health Check" /tr "powershell -ExecutionPolicy Bypass -File C:\path\to\HEALTH-CHECK-DAILY.ps1" /sc daily /st 06:00
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$CheckTime = "06:00",

    [Parameter(Mandatory=$false)]
    [bool]$EmailReport = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SaveLocally = $true,

    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\Logs\BackupMonitoring\Reports",

    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "C:\BackupMonitoring\Config\alerting-config.json"
)

$ErrorActionPreference = "SilentlyContinue"

# Create directories
if (-not (Test-Path $ReportPath)) {
    New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFile = "$ReportPath\health-check-$timestamp.html"
$statusLogFile = "$ReportPath\health-check-$timestamp.log"

# Load configuration if available
$config = $null
if (Test-Path $ConfigPath) {
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    } catch {}
}

###############################################################################
# HELPER FUNCTIONS
###############################################################################

function Write-StatusLog {
    param([string]$Message, [string]$Level = "INFO")
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $statusLogFile -Value $logMessage
}

function Test-BackupPath {
    param(
        [string]$Path,
        [string]$SystemName
    )

    $result = @{
        Name = $SystemName
        Path = $Path
        Accessible = $false
        LastBackup = $null
        HoursSince = 0
        SizeGB = 0
        Status = "UNKNOWN"
        Details = ""
    }

    if (Test-Path $Path -ErrorAction SilentlyContinue) {
        $result.Accessible = $true

        try {
            $files = Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending |
                     Select-Object -First 1

            if ($files) {
                $result.LastBackup = $files.LastWriteTime
                $result.HoursSince = [math]::Round(((Get-Date) - $files.LastWriteTime).TotalHours, 1)

                # Calculate size
                $totalSize = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum).Sum
                $result.SizeGB = [math]::Round($totalSize / 1GB, 2)

                # Determine status based on age
                $maxHours = switch ($SystemName) {
                    "Veeam Backup" { 28 }
                    "Phone Backup" { 24 }
                    "Time Machine" { 24 }
                    default { 48 }
                }

                if ($result.HoursSince -le $maxHours) {
                    $result.Status = "PASS"
                    $result.Details = "Last backup $([math]::Round($result.HoursSince, 1)) hours ago"
                } else {
                    $result.Status = "FAIL"
                    $result.Details = "Last backup $([math]::Round($result.HoursSince, 1)) hours ago (exceeds $maxHours hour limit)"
                }
            } else {
                $result.Status = "FAIL"
                $result.Details = "No backup files found in path"
            }
        } catch {
            $result.Status = "ERROR"
            $result.Details = "Error accessing path: $_"
        }
    } else {
        $result.Status = "FAIL"
        $result.Details = "Path not accessible"
    }

    return $result
}

function Test-SMBConnectivity {
    param([string]$SMBPath)

    $result = @{
        Path = $SMBPath
        Accessible = $false
        Status = "FAIL"
    }

    try {
        if (Test-Path $SMBPath -ErrorAction Stop) {
            $result.Accessible = $true
            $result.Status = "PASS"
        }
    } catch {
        $result.Status = "FAIL"
    }

    return $result
}

function Test-NetworkPath {
    param([string]$Path, [string]$Name)

    $result = @{
        Name = $Name
        Path = $Path
        Accessible = $false
        Status = "UNKNOWN"
    }

    try {
        if (Test-Path $Path -ErrorAction SilentlyContinue) {
            $result.Accessible = $true
            $result.Status = "PASS"
        } else {
            $result.Status = "FAIL"
        }
    } catch {
        $result.Status = "FAIL"
    }

    return $result
}

###############################################################################
# HEALTH CHECKS
###############################################################################

Write-StatusLog "Daily health check started" "START"

$healthChecks = @()
$passCount = 0
$failCount = 0
$errorCount = 0

# Check 1: Veeam Backup
Write-StatusLog "Checking Veeam backup..." "INFO"
$veeamPaths = @("X:\VeeamBackups", "D:\VeeamBackups", "\\10.0.0.89\Veeam")
$veeamResult = $null

foreach ($path in $veeamPaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $veeamResult = Test-BackupPath -Path $path -SystemName "Veeam Backup"
        break
    }
}

if ($veeamResult -eq $null) {
    $veeamResult = @{
        Name = "Veeam Backup"
        Path = $veeamPaths -join " / "
        Accessible = $false
        Status = "FAIL"
        Details = "No Veeam backup paths accessible"
    }
}

$healthChecks += $veeamResult
if ($veeamResult.Status -eq "PASS") { $passCount++ } else { $failCount++ }
Write-StatusLog "Veeam Backup: $($veeamResult.Status) - $($veeamResult.Details)" "INFO"

# Check 2: Phone Backup
Write-StatusLog "Checking phone backup..." "INFO"
$phonePaths = @("X:\Phone-Backups", "D:\Phone-Backups", "\\10.0.0.89\Phone-Backups")
$phoneResult = $null

foreach ($path in $phonePaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $phoneResult = Test-BackupPath -Path $path -SystemName "Phone Backup"
        break
    }
}

if ($phoneResult -eq $null) {
    $phoneResult = @{
        Name = "Phone Backup"
        Path = $phonePaths -join " / "
        Accessible = $false
        Status = "FAIL"
        Details = "No phone backup paths accessible"
    }
}

$healthChecks += $phoneResult
if ($phoneResult.Status -eq "PASS") { $passCount++ } else { $failCount++ }
Write-StatusLog "Phone Backup: $($phoneResult.Status) - $($phoneResult.Details)" "INFO"

# Check 3: Time Machine
Write-StatusLog "Checking Time Machine backup..." "INFO"
$timeMachinePaths = @("X:\TimeMachine", "D:\TimeMachine", "\\10.0.0.89\TimeMachine")
$timeMachineResult = $null

foreach ($path in $timeMachinePaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $timeMachineResult = Test-BackupPath -Path $path -SystemName "Time Machine"
        break
    }
}

if ($timeMachineResult -eq $null) {
    $timeMachineResult = @{
        Name = "Time Machine"
        Path = $timeMachinePaths -join " / "
        Accessible = $false
        Status = "FAIL"
        Details = "No Time Machine backup paths accessible"
    }
}

$healthChecks += $timeMachineResult
if ($timeMachineResult.Status -eq "PASS") { $passCount++ } else { $failCount++ }
Write-StatusLog "Time Machine: $($timeMachineResult.Status) - $($timeMachineResult.Details)" "INFO"

# Check 4: SMB Connectivity
Write-StatusLog "Checking SMB connectivity..." "INFO"
$smbPaths = @(
    @{ Path = "\\10.0.0.89\Veeam"; Name = "TrueNAS - Veeam Share" },
    @{ Path = "\\10.0.0.89\Phone-Backups"; Name = "TrueNAS - Phone Backups" },
    @{ Path = "\\10.0.0.89\TimeMachine"; Name = "TrueNAS - Time Machine" }
)

$smbResults = @()
foreach ($smb in $smbPaths) {
    $smbResult = Test-NetworkPath -Path $smb.Path -Name $smb.Name
    $smbResults += $smbResult

    if ($smbResult.Status -eq "PASS") { $passCount++ } else { $failCount++ }
    Write-StatusLog "SMB: $($smb.Name) - $($smbResult.Status)" "INFO"
}

# Check 5: Network Connectivity
Write-StatusLog "Checking network connectivity..." "INFO"
$nasIPs = @(
    @{ IP = "10.0.0.89"; Name = "TrueNAS Main" },
    @{ IP = "10.0.0.90"; Name = "Baby NAS" }
)

$networkResults = @()
foreach ($nas in $nasIPs) {
    $connected = Test-Connection -ComputerName $nas.IP -Count 1 -Quiet -ErrorAction SilentlyContinue

    $result = @{
        Name = $nas.Name
        IP = $nas.IP
        Status = if ($connected) { "PASS" } else { "FAIL" }
    }

    $networkResults += $result
    if ($result.Status -eq "PASS") { $passCount++ } else { $failCount++ }
    Write-StatusLog "Network: $($nas.Name) - $($result.Status)" "INFO"
}

# Check 6: Local Disk Space
Write-StatusLog "Checking local disk space..." "INFO"
$diskResults = @()
$volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveLetter -match '[A-Z]' }

foreach ($vol in $volumes) {
    $percentFree = if ($vol.Size -gt 0) { ($vol.SizeRemaining / $vol.Size) * 100 } else { 0 }
    $freeGB = [math]::Round($vol.SizeRemaining / 1GB, 2)

    $diskResult = @{
        Drive = "$($vol.DriveLetter):"
        PercentFree = [math]::Round($percentFree, 1)
        FreeGB = $freeGB
        Status = if ($percentFree -gt 10) { "PASS" } else { "FAIL" }
    }

    $diskResults += $diskResult
    if ($diskResult.Status -eq "PASS") { $passCount++ } else { $failCount++ }
    Write-StatusLog "Disk $($vol.DriveLetter): $($diskResult.Status) - $($diskResult.FreeGB) GB free" "INFO"
}

# Overall status
$overallStatus = if ($failCount -gt 0) { "FAIL" } elseif ($passCount -gt 0) { "PASS" } else { "UNKNOWN" }

###############################################################################
# GENERATE HTML REPORT
###############################################################################

$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Daily Backup Health Check Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background-color: #2c5aa0;
            color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .status {
            font-size: 24px;
            font-weight: bold;
            margin-top: 10px;
        }
        .status.pass { color: #28a745; }
        .status.fail { color: #dc3545; }
        .status.warning { color: #ffc107; }
        .section {
            background-color: white;
            padding: 15px;
            margin-bottom: 15px;
            border-radius: 5px;
            border-left: 5px solid #2c5aa0;
        }
        .section h2 {
            margin-top: 0;
            color: #2c5aa0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        th {
            background-color: #f8f9fa;
            padding: 10px;
            text-align: left;
            border-bottom: 2px solid #dee2e6;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #dee2e6;
        }
        tr:hover {
            background-color: #f9f9f9;
        }
        .pass {
            color: #28a745;
            font-weight: bold;
        }
        .fail {
            color: #dc3545;
            font-weight: bold;
        }
        .warning {
            color: #ffc107;
            font-weight: bold;
        }
        .details {
            font-size: 12px;
            color: #666;
            margin-top: 5px;
        }
        .summary {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 15px;
            margin-bottom: 20px;
        }
        .summary-box {
            background-color: white;
            padding: 15px;
            border-radius: 5px;
            text-align: center;
            border-left: 5px solid #2c5aa0;
        }
        .summary-box h3 {
            margin: 0 0 10px 0;
            color: #666;
        }
        .summary-box .number {
            font-size: 32px;
            font-weight: bold;
            color: #2c5aa0;
        }
        .footer {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            font-size: 12px;
            color: #666;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Daily Backup Health Check Report</h1>
        <div class="status $(if ($overallStatus -eq 'PASS') { 'pass' } else { 'fail' })">
            Overall Status: $overallStatus
        </div>
        <p>Report Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    </div>

    <div class="summary">
        <div class="summary-box">
            <h3>Passed Checks</h3>
            <div class="number pass">$passCount</div>
        </div>
        <div class="summary-box">
            <h3>Failed Checks</h3>
            <div class="number fail">$failCount</div>
        </div>
        <div class="summary-box">
            <h3>Total Checks</h3>
            <div class="number">$($passCount + $failCount)</div>
        </div>
    </div>

    <div class="section">
        <h2>Backup Systems Status</h2>
        <table>
            <thead>
                <tr>
                    <th>System</th>
                    <th>Status</th>
                    <th>Last Backup</th>
                    <th>Size (GB)</th>
                    <th>Details</th>
                </tr>
            </thead>
            <tbody>
"@

foreach ($check in $healthChecks) {
    $statusClass = if ($check.Status -eq "PASS") { "pass" } else { "fail" }
    $lastBackupStr = if ($check.LastBackup) { $check.LastBackup.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }

    $htmlReport += @"
                <tr>
                    <td>$($check.Name)</td>
                    <td><span class="$statusClass">$($check.Status)</span></td>
                    <td>$lastBackupStr</td>
                    <td>$($check.SizeGB)</td>
                    <td>$($check.Details)</td>
                </tr>
"@
}

$htmlReport += @"
            </tbody>
        </table>
    </div>

    <div class="section">
        <h2>Network Connectivity</h2>
        <table>
            <thead>
                <tr>
                    <th>System</th>
                    <th>IP Address</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
"@

foreach ($net in $networkResults) {
    $statusClass = if ($net.Status -eq "PASS") { "pass" } else { "fail" }

    $htmlReport += @"
                <tr>
                    <td>$($net.Name)</td>
                    <td>$($net.IP)</td>
                    <td><span class="$statusClass">$($net.Status)</span></td>
                </tr>
"@
}

$htmlReport += @"
            </tbody>
        </table>
    </div>

    <div class="section">
        <h2>SMB Share Accessibility</h2>
        <table>
            <thead>
                <tr>
                    <th>Share Name</th>
                    <th>Path</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
"@

foreach ($smb in $smbResults) {
    $statusClass = if ($smb.Status -eq "PASS") { "pass" } else { "fail" }

    $htmlReport += @"
                <tr>
                    <td>$($smb.Name)</td>
                    <td>$($smb.Path)</td>
                    <td><span class="$statusClass">$($smb.Status)</span></td>
                </tr>
"@
}

$htmlReport += @"
            </tbody>
        </table>
    </div>

    <div class="section">
        <h2>Local Disk Space</h2>
        <table>
            <thead>
                <tr>
                    <th>Drive</th>
                    <th>Free Space (GB)</th>
                    <th>Free (%)</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
"@

foreach ($disk in $diskResults) {
    $statusClass = if ($disk.Status -eq "PASS") { "pass" } else { "fail" }

    $htmlReport += @"
                <tr>
                    <td>$($disk.Drive)</td>
                    <td>$($disk.FreeGB)</td>
                    <td>$($disk.PercentFree)</td>
                    <td><span class="$statusClass">$($disk.Status)</span></td>
                </tr>
"@
}

$htmlReport += @"
            </tbody>
        </table>
    </div>

    <div class="footer">
        <p>Report generated on $env:COMPUTERNAME at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Log file: $statusLogFile</p>
        <p>This is an automated health check report. Review for anomalies and take appropriate action.</p>
    </div>
</body>
</html>
"@

###############################################################################
# SAVE AND SEND REPORT
###############################################################################

if ($SaveLocally) {
    try {
        $htmlReport | Out-File -FilePath $reportFile -Encoding UTF8
        Write-StatusLog "Report saved to: $reportFile" "INFO"
    } catch {
        Write-StatusLog "Failed to save report: $_" "ERROR"
    }
}

if ($EmailReport -and $config -and $config.alerts.email.enabled) {
    Write-StatusLog "Sending email report..." "INFO"

    try {
        $emailSubject = "Daily Backup Health Check - $overallStatus"
        $emailBody = $htmlReport

        # Get email configuration
        $smtpServer = $config.alerts.email.smtpServer
        $smtpPort = $config.alerts.email.smtpPort
        $emailFrom = $config.alerts.email.fromAddress
        $emailTo = $config.alerts.email.recipients -join ','

        # Send email (requires SMTP credentials to be configured)
        # This is a placeholder - actual implementation would need credential handling
        Write-StatusLog "Email sending not fully configured (requires SMTP credentials)" "WARNING"

    } catch {
        Write-StatusLog "Failed to send email: $_" "ERROR"
    }
}

###############################################################################
# CLEANUP
###############################################################################

Write-StatusLog "Daily health check completed with status: $overallStatus" "END"

# Cleanup old reports (keep last 30 days)
try {
    Get-ChildItem $ReportPath -Filter "health-check-*.html" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}

Write-Host "Health check complete: $overallStatus"
Write-Host "Report: $reportFile"
Write-Host "Log: $statusLogFile"

exit $(if ($overallStatus -eq "PASS") { 0 } else { 1 })
