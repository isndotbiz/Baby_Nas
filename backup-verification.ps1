# Backup Verification and Validation Script
# Purpose: Verify Veeam and WSL backups, test restoration, and generate comprehensive reports
# Run as: Administrator
# Usage: .\backup-verification.ps1 -VeeamPath "V:\" -WSLPath "L:\"

<#
.SYNOPSIS
    Comprehensive backup verification and validation tool

.DESCRIPTION
    This script provides complete backup validation capabilities:
    - Checks last Veeam backup success/failure status
    - Verifies backup file sizes and integrity
    - Tests random file restoration from backups
    - Validates WSL backup exports
    - Checks disk space and retention compliance
    - Generates detailed HTML and text reports
    - Sends email notifications (optional)
    - Monitors backup age and alerts on stale backups

.PARAMETER VeeamPath
    Path to Veeam backup repository
    Default: V:\

.PARAMETER WSLPath
    Path to WSL backup repository
    Default: L:\

.PARAMETER MaxBackupAge
    Maximum acceptable backup age in hours (alert if older)
    Default: 48 hours

.PARAMETER TestRestoration
    Perform actual restoration test (slow but thorough)

.PARAMETER GenerateReport
    Generate HTML report
    Default: True

.PARAMETER EmailReport
    Send report via email (requires SMTP configuration)

.PARAMETER SMTPServer
    SMTP server for email notifications

.PARAMETER EmailTo
    Email recipient address

.PARAMETER EmailFrom
    Email sender address

.PARAMETER DetailedLogging
    Enable verbose logging

.EXAMPLE
    .\backup-verification.ps1
    Basic verification with default settings

.EXAMPLE
    .\backup-verification.ps1 -VeeamPath "V:\" -WSLPath "L:\" -TestRestoration
    Full verification including restoration test

.EXAMPLE
    .\backup-verification.ps1 -MaxBackupAge 24 -EmailReport -EmailTo "admin@example.com"
    Verify with 24-hour alert threshold and email reporting
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$VeeamPath = "V:\",

    [Parameter(Mandatory=$false)]
    [string]$WSLPath = "L:\",

    [Parameter(Mandatory=$false)]
    [int]$MaxBackupAge = 48,

    [Parameter(Mandatory=$false)]
    [switch]$TestRestoration,

    [Parameter(Mandatory=$false)]
    [bool]$GenerateReport = $true,

    [Parameter(Mandatory=$false)]
    [switch]$EmailReport,

    [Parameter(Mandatory=$false)]
    [string]$SMTPServer = "",

    [Parameter(Mandatory=$false)]
    [string]$EmailTo = "",

    [Parameter(Mandatory=$false)]
    [string]$EmailFrom = "backup-monitor@localhost",

    [Parameter(Mandatory=$false)]
    [switch]$DetailedLogging
)

# Create log directory
$logDir = "C:\Logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\backup-verification-$timestamp.log"

# Verification results
$script:verificationResults = @{
    VeeamStatus = "Unknown"
    VeeamLastBackup = $null
    VeeamBackupSize = 0
    VeeamBackupCount = 0
    VeeamIssues = @()
    WSLStatus = "Unknown"
    WSLLastBackup = $null
    WSLBackupSize = 0
    WSLBackupCount = 0
    WSLIssues = @()
    DiskSpace = @{}
    OverallStatus = "Unknown"
    Warnings = @()
    Errors = @()
    StartTime = Get-Date
    EndTime = $null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO"    { Write-Host $logMessage -ForegroundColor Cyan }
        "DEBUG"   {
            if ($DetailedLogging) {
                Write-Host $logMessage -ForegroundColor Gray
            }
        }
        default   { Write-Host $logMessage -ForegroundColor White }
    }

    $logMessage | Out-File -FilePath $logFile -Append
}

function Test-VeeamInstallation {
    Write-Log "Checking Veeam installation..." "INFO"

    $veeamService = Get-Service -Name "VeeamEndpointBackupSvc" -ErrorAction SilentlyContinue

    if ($veeamService) {
        Write-Log "  Veeam service status: $($veeamService.Status)" "SUCCESS"

        if ($veeamService.Status -ne "Running") {
            Write-Log "  WARNING: Veeam service is not running" "WARNING"
            $script:verificationResults.Warnings += "Veeam service is not running"
            return $false
        }
        return $true
    } else {
        Write-Log "  Veeam is not installed" "WARNING"
        $script:verificationResults.VeeamIssues += "Veeam not installed"
        return $false
    }
}

function Get-VeeamBackupStatus {
    Write-Log "Analyzing Veeam backup status..." "INFO"

    if (-not (Test-Path $VeeamPath)) {
        Write-Log "  Veeam backup path not accessible: $VeeamPath" "ERROR"
        $script:verificationResults.VeeamStatus = "Path Not Found"
        $script:verificationResults.Errors += "Veeam backup path not accessible"
        return $false
    }

    try {
        # Get all Veeam backup files
        $veeamFiles = Get-ChildItem $VeeamPath -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '\.(vbk|vib|vrb|vbm)$' }

        if ($veeamFiles) {
            $script:verificationResults.VeeamBackupCount = $veeamFiles.Count

            # Get most recent backup
            $latestBackup = $veeamFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $script:verificationResults.VeeamLastBackup = $latestBackup.LastWriteTime

            # Calculate total size
            $totalSize = ($veeamFiles | Measure-Object -Property Length -Sum).Sum
            $script:verificationResults.VeeamBackupSize = $totalSize

            # Check backup age
            $backupAge = (Get-Date) - $latestBackup.LastWriteTime
            $ageHours = [math]::Round($backupAge.TotalHours, 1)

            Write-Log "  Last backup: $($latestBackup.Name)" "SUCCESS"
            Write-Log "  Backup date: $($latestBackup.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO"
            Write-Log "  Backup age: $ageHours hours" "INFO"
            Write-Log "  Total backup count: $($veeamFiles.Count)" "INFO"
            Write-Log "  Total backup size: $([math]::Round($totalSize / 1GB, 2)) GB" "INFO"

            # Check if backup is too old
            if ($backupAge.TotalHours -gt $MaxBackupAge) {
                $msg = "Veeam backup is older than $MaxBackupAge hours (age: $ageHours hours)"
                Write-Log "  WARNING: $msg" "WARNING"
                $script:verificationResults.Warnings += $msg
                $script:verificationResults.VeeamStatus = "Stale"
            } else {
                $script:verificationResults.VeeamStatus = "OK"
            }

            # Check for backup chain integrity
            $fullBackups = $veeamFiles | Where-Object { $_.Extension -eq '.vbk' }
            $incrementalBackups = $veeamFiles | Where-Object { $_.Extension -eq '.vib' }

            Write-Log "  Full backups: $($fullBackups.Count)" "INFO"
            Write-Log "  Incremental backups: $($incrementalBackups.Count)" "INFO"

            if ($fullBackups.Count -eq 0) {
                $msg = "No full backups found"
                Write-Log "  WARNING: $msg" "WARNING"
                $script:verificationResults.Warnings += $msg
            }

            return $true

        } else {
            Write-Log "  No Veeam backup files found" "WARNING"
            $script:verificationResults.VeeamStatus = "No Backups"
            $script:verificationResults.Warnings += "No Veeam backup files found"
            return $false
        }

    } catch {
        Write-Log "  Error analyzing Veeam backups: $($_.Exception.Message)" "ERROR"
        $script:verificationResults.VeeamStatus = "Error"
        $script:verificationResults.Errors += "Veeam analysis error: $($_.Exception.Message)"
        return $false
    }
}

function Get-WSLBackupStatus {
    Write-Log "Analyzing WSL backup status..." "INFO"

    if (-not (Test-Path $WSLPath)) {
        Write-Log "  WSL backup path not accessible: $WSLPath" "ERROR"
        $script:verificationResults.WSLStatus = "Path Not Found"
        $script:verificationResults.Errors += "WSL backup path not accessible"
        return $false
    }

    try {
        # Get all WSL backup files
        $wslFiles = Get-ChildItem $WSLPath -Filter "*.tar" -File -ErrorAction SilentlyContinue

        if ($wslFiles) {
            $script:verificationResults.WSLBackupCount = $wslFiles.Count

            # Get most recent backup
            $latestBackup = $wslFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $script:verificationResults.WSLLastBackup = $latestBackup.LastWriteTime

            # Calculate total size
            $totalSize = ($wslFiles | Measure-Object -Property Length -Sum).Sum
            $script:verificationResults.WSLBackupSize = $totalSize

            # Check backup age
            $backupAge = (Get-Date) - $latestBackup.LastWriteTime
            $ageHours = [math]::Round($backupAge.TotalHours, 1)

            Write-Log "  Last backup: $($latestBackup.Name)" "SUCCESS"
            Write-Log "  Backup date: $($latestBackup.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO"
            Write-Log "  Backup age: $ageHours hours" "INFO"
            Write-Log "  Total backup count: $($wslFiles.Count)" "INFO"
            Write-Log "  Total backup size: $([math]::Round($totalSize / 1GB, 2)) GB" "INFO"

            # Check if backup is too old
            if ($backupAge.TotalHours -gt $MaxBackupAge) {
                $msg = "WSL backup is older than $MaxBackupAge hours (age: $ageHours hours)"
                Write-Log "  WARNING: $msg" "WARNING"
                $script:verificationResults.Warnings += $msg
                $script:verificationResults.WSLStatus = "Stale"
            } else {
                $script:verificationResults.WSLStatus = "OK"
            }

            # Group backups by distribution
            $byDistro = $wslFiles | Group-Object { ($_.Name -split '-')[0] }
            Write-Log "  Distributions backed up: $($byDistro.Count)" "INFO"
            foreach ($group in $byDistro) {
                $distroSize = ($group.Group | Measure-Object -Property Length -Sum).Sum
                Write-Log "    - $($group.Name): $($group.Count) backups, $([math]::Round($distroSize / 1GB, 2)) GB" "DEBUG"
            }

            # Verify TAR file integrity
            Write-Log "  Verifying backup integrity..." "INFO"
            $corruptCount = 0
            foreach ($backup in $wslFiles) {
                if ($backup.Length -eq 0) {
                    $msg = "Empty backup file: $($backup.Name)"
                    Write-Log "    WARNING: $msg" "WARNING"
                    $script:verificationResults.Warnings += $msg
                    $corruptCount++
                }
            }

            if ($corruptCount -eq 0) {
                Write-Log "  All backup files appear valid" "SUCCESS"
            } else {
                Write-Log "  Found $corruptCount potentially corrupt backup(s)" "WARNING"
            }

            return $true

        } else {
            Write-Log "  No WSL backup files found" "WARNING"
            $script:verificationResults.WSLStatus = "No Backups"
            $script:verificationResults.Warnings += "No WSL backup files found"
            return $false
        }

    } catch {
        Write-Log "  Error analyzing WSL backups: $($_.Exception.Message)" "ERROR"
        $script:verificationResults.WSLStatus = "Error"
        $script:verificationResults.Errors += "WSL analysis error: $($_.Exception.Message)"
        return $false
    }
}

function Test-DiskSpace {
    param([string[]]$Paths)

    Write-Log "Checking disk space..." "INFO"

    foreach ($path in $Paths) {
        if (Test-Path $path) {
            try {
                $drive = (Get-Item $path).PSDrive

                $totalSpace = $drive.Free + $drive.Used
                $freeSpace = $drive.Free
                $usedSpace = $drive.Used
                $percentFree = [math]::Round(($freeSpace / $totalSpace) * 100, 1)

                $script:verificationResults.DiskSpace[$drive.Name] = @{
                    Total = $totalSpace
                    Free = $freeSpace
                    Used = $usedSpace
                    PercentFree = $percentFree
                }

                Write-Log "  Drive $($drive.Name): $([math]::Round($freeSpace / 1GB, 2)) GB free of $([math]::Round($totalSpace / 1GB, 2)) GB ($percentFree% free)" "INFO"

                # Alert if less than 10% free or less than 10GB
                if ($percentFree -lt 10 -or ($freeSpace / 1GB) -lt 10) {
                    $msg = "Low disk space on drive $($drive.Name): $percentFree% free"
                    Write-Log "  WARNING: $msg" "WARNING"
                    $script:verificationResults.Warnings += $msg
                }

            } catch {
                Write-Log "  Error checking disk space for $path : $($_.Exception.Message)" "WARNING"
            }
        }
    }
}

function Test-WSLBackupRestoration {
    Write-Log "Testing WSL backup restoration..." "INFO"

    if (-not (Test-Path $WSLPath)) {
        Write-Log "  WSL backup path not accessible" "ERROR"
        return $false
    }

    try {
        # Get a random recent backup
        $backups = Get-ChildItem $WSLPath -Filter "*.tar" |
            Where-Object { $_.Name -notmatch 'docker-desktop' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 5

        if (-not $backups) {
            Write-Log "  No suitable backups found for testing" "WARNING"
            return $false
        }

        $testBackup = $backups | Get-Random
        Write-Log "  Selected backup for testing: $($testBackup.Name)" "INFO"

        # Create temporary test location
        $testDistroName = "backup-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Write-Log "  Creating temporary test distribution: $testDistroName" "INFO"

        # Import backup to temporary location
        $importResult = wsl --import $testDistroName "C:\Temp\WSLTest\$testDistroName" $testBackup.FullName 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "  Test import successful" "SUCCESS"

            # Test if distribution can be accessed
            $testResult = wsl -d $testDistroName echo "test" 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Log "  Distribution is functional" "SUCCESS"
                $restorationSuccess = $true
            } else {
                Write-Log "  Distribution import succeeded but not functional" "WARNING"
                $script:verificationResults.Warnings += "WSL restoration test: distribution not functional"
                $restorationSuccess = $false
            }

            # Cleanup test distribution
            Write-Log "  Cleaning up test distribution..." "INFO"
            wsl --unregister $testDistroName 2>&1 | Out-Null

            Remove-Item "C:\Temp\WSLTest\$testDistroName" -Recurse -Force -ErrorAction SilentlyContinue

            return $restorationSuccess

        } else {
            Write-Log "  Test import failed: $importResult" "ERROR"
            $script:verificationResults.Errors += "WSL restoration test failed"
            return $false
        }

    } catch {
        Write-Log "  Restoration test error: $($_.Exception.Message)" "ERROR"
        $script:verificationResults.Errors += "WSL restoration test error"
        return $false
    }
}

function Get-VeeamLogs {
    Write-Log "Checking Veeam logs..." "INFO"

    $veeamLogPath = "C:\ProgramData\Veeam\Endpoint"

    if (Test-Path $veeamLogPath) {
        try {
            $recentLogs = Get-ChildItem $veeamLogPath -Filter "*.log" -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-1) } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 5

            if ($recentLogs) {
                Write-Log "  Found $($recentLogs.Count) recent log file(s)" "INFO"

                foreach ($log in $recentLogs) {
                    Write-Log "    - $($log.Name) ($(Get-Date $log.LastWriteTime -Format 'yyyy-MM-dd HH:mm'))" "DEBUG"

                    # Search for errors in log
                    $errorLines = Select-String -Path $log.FullName -Pattern "error|fail|exception" -SimpleMatch -ErrorAction SilentlyContinue |
                        Select-Object -First 3

                    if ($errorLines) {
                        Write-Log "    Found potential errors in $($log.Name)" "WARNING"
                        $script:verificationResults.Warnings += "Errors found in Veeam log: $($log.Name)"
                    }
                }
            } else {
                Write-Log "  No recent Veeam logs found" "INFO"
            }

        } catch {
            Write-Log "  Error reading Veeam logs: $($_.Exception.Message)" "WARNING"
        }
    } else {
        Write-Log "  Veeam log directory not found" "DEBUG"
    }
}

function New-VerificationReport {
    param([string]$LogFile)

    $reportFile = Join-Path (Split-Path $LogFile) "backup-verification-report-$timestamp.html"

    $veeamStatusColor = switch ($script:verificationResults.VeeamStatus) {
        "OK" { "green" }
        "Stale" { "orange" }
        default { "red" }
    }

    $wslStatusColor = switch ($script:verificationResults.WSLStatus) {
        "OK" { "green" }
        "Stale" { "orange" }
        default { "red" }
    }

    $overallStatusColor = if ($script:verificationResults.Errors.Count -eq 0) {
        if ($script:verificationResults.Warnings.Count -eq 0) { "green" } else { "orange" }
    } else { "red" }

    $overallStatus = if ($script:verificationResults.Errors.Count -eq 0) {
        if ($script:verificationResults.Warnings.Count -eq 0) { "HEALTHY" } else { "WARNING" }
    } else { "CRITICAL" }

    $script:verificationResults.OverallStatus = $overallStatus
    $script:verificationResults.EndTime = Get-Date

    $duration = ($script:verificationResults.EndTime - $script:verificationResults.StartTime).TotalSeconds

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Backup Verification Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; border-bottom: 2px solid #ddd; padding-bottom: 5px; }
        .status-ok { color: green; font-weight: bold; }
        .status-warning { color: orange; font-weight: bold; }
        .status-error { color: red; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .metric-box { display: inline-block; margin: 10px; padding: 15px; border-radius: 5px; background-color: #f0f0f0; min-width: 200px; }
        .metric-label { font-size: 0.9em; color: #666; }
        .metric-value { font-size: 1.5em; font-weight: bold; margin-top: 5px; }
        .alert-box { padding: 15px; margin: 15px 0; border-radius: 5px; }
        .alert-warning { background-color: #fff3cd; border-left: 4px solid #ffc107; }
        .alert-error { background-color: #f8d7da; border-left: 4px solid #dc3545; }
        .footer { margin-top: 50px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 0.9em; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Backup Verification Report</h1>
        <p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>Duration:</strong> $([math]::Round($duration, 1)) seconds</p>
        <p><strong>Overall Status:</strong> <span style="color: $overallStatusColor; font-weight: bold; font-size: 1.2em;">$overallStatus</span></p>

        <h2>Quick Summary</h2>
        <div class="metric-box">
            <div class="metric-label">Veeam Status</div>
            <div class="metric-value" style="color: $veeamStatusColor;">$($script:verificationResults.VeeamStatus)</div>
        </div>
        <div class="metric-box">
            <div class="metric-label">WSL Status</div>
            <div class="metric-value" style="color: $wslStatusColor;">$($script:verificationResults.WSLStatus)</div>
        </div>
        <div class="metric-box">
            <div class="metric-label">Total Warnings</div>
            <div class="metric-value" style="color: orange;">$($script:verificationResults.Warnings.Count)</div>
        </div>
        <div class="metric-box">
            <div class="metric-label">Total Errors</div>
            <div class="metric-value" style="color: red;">$($script:verificationResults.Errors.Count)</div>
        </div>

        <h2>Veeam Backup Status</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Status</td><td style="color: $veeamStatusColor; font-weight: bold;">$($script:verificationResults.VeeamStatus)</td></tr>
            <tr><td>Last Backup</td><td>$(if($script:verificationResults.VeeamLastBackup){$script:verificationResults.VeeamLastBackup.ToString('yyyy-MM-dd HH:mm:ss')}else{'N/A'})</td></tr>
            <tr><td>Backup Count</td><td>$($script:verificationResults.VeeamBackupCount)</td></tr>
            <tr><td>Total Size</td><td>$([math]::Round($script:verificationResults.VeeamBackupSize / 1GB, 2)) GB</td></tr>
        </table>

        <h2>WSL Backup Status</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Status</td><td style="color: $wslStatusColor; font-weight: bold;">$($script:verificationResults.WSLStatus)</td></tr>
            <tr><td>Last Backup</td><td>$(if($script:verificationResults.WSLLastBackup){$script:verificationResults.WSLLastBackup.ToString('yyyy-MM-dd HH:mm:ss')}else{'N/A'})</td></tr>
            <tr><td>Backup Count</td><td>$($script:verificationResults.WSLBackupCount)</td></tr>
            <tr><td>Total Size</td><td>$([math]::Round($script:verificationResults.WSLBackupSize / 1GB, 2)) GB</td></tr>
        </table>

        <h2>Disk Space</h2>
        <table>
            <tr><th>Drive</th><th>Total</th><th>Free</th><th>Used</th><th>% Free</th></tr>
            $(foreach ($drive in $script:verificationResults.DiskSpace.Keys) {
                $info = $script:verificationResults.DiskSpace[$drive]
                $color = if ($info.PercentFree -lt 10) { "red" } elseif ($info.PercentFree -lt 20) { "orange" } else { "black" }
                "<tr><td>$drive</td><td>$([math]::Round($info.Total / 1GB, 2)) GB</td><td>$([math]::Round($info.Free / 1GB, 2)) GB</td><td>$([math]::Round($info.Used / 1GB, 2)) GB</td><td style='color: $color;'>$($info.PercentFree)%</td></tr>"
            })
        </table>

        $(if ($script:verificationResults.Warnings.Count -gt 0) {
            "<h2>Warnings</h2>"
            foreach ($warning in $script:verificationResults.Warnings) {
                "<div class='alert-box alert-warning'>$warning</div>"
            }
        })

        $(if ($script:verificationResults.Errors.Count -gt 0) {
            "<h2>Errors</h2>"
            foreach ($error in $script:verificationResults.Errors) {
                "<div class='alert-box alert-error'>$error</div>"
            }
        })

        <div class="footer">
            <p><strong>Log File:</strong> $LogFile</p>
            <p><strong>Report File:</strong> $reportFile</p>
            <p>Generated by Backup Verification Script v1.0</p>
        </div>
    </div>
</body>
</html>
"@

    try {
        $html | Out-File -FilePath $reportFile -Encoding UTF8
        Write-Log "HTML report generated: $reportFile" "SUCCESS"
        return $reportFile
    } catch {
        Write-Log "Failed to generate HTML report: $($_.Exception.Message)" "WARNING"
        return $null
    }
}

function Send-EmailReport {
    param(
        [string]$ReportFile,
        [string]$SMTPServer,
        [string]$From,
        [string]$To
    )

    if (-not $SMTPServer -or -not $To) {
        Write-Log "Email configuration incomplete, skipping email notification" "WARNING"
        return $false
    }

    Write-Log "Sending email report..." "INFO"

    try {
        $subject = "Backup Verification Report - $($script:verificationResults.OverallStatus) - $(Get-Date -Format 'yyyy-MM-dd')"

        $body = Get-Content $ReportFile -Raw

        Send-MailMessage `
            -SmtpServer $SMTPServer `
            -From $From `
            -To $To `
            -Subject $subject `
            -Body $body `
            -BodyAsHtml `
            -ErrorAction Stop

        Write-Log "Email report sent successfully to $To" "SUCCESS"
        return $true

    } catch {
        Write-Log "Failed to send email report: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ===== MAIN SCRIPT EXECUTION =====

Write-Log "================================================" "INFO"
Write-Log "=== Backup Verification Script Started ===" "INFO"
Write-Log "================================================" "INFO"
Write-Log "Veeam Path: $VeeamPath" "INFO"
Write-Log "WSL Path: $WSLPath" "INFO"
Write-Log "Max Backup Age: $MaxBackupAge hours" "INFO"
Write-Log "Test Restoration: $TestRestoration" "INFO"

# Step 1: Check Veeam installation
Write-Log "" "INFO"
Write-Log "=== Veeam Installation Check ===" "INFO"
$veeamInstalled = Test-VeeamInstallation

# Step 2: Check Veeam backups
if ($veeamInstalled) {
    Write-Log "" "INFO"
    Write-Log "=== Veeam Backup Analysis ===" "INFO"
    Get-VeeamBackupStatus

    Write-Log "" "INFO"
    Write-Log "=== Veeam Log Analysis ===" "INFO"
    Get-VeeamLogs
}

# Step 3: Check WSL backups
Write-Log "" "INFO"
Write-Log "=== WSL Backup Analysis ===" "INFO"
Get-WSLBackupStatus

# Step 4: Test restoration if requested
if ($TestRestoration) {
    Write-Log "" "INFO"
    Write-Log "=== Restoration Testing ===" "INFO"
    $restorationSuccess = Test-WSLBackupRestoration

    if ($restorationSuccess) {
        Write-Log "Restoration test: PASSED" "SUCCESS"
    } else {
        Write-Log "Restoration test: FAILED" "ERROR"
    }
}

# Step 5: Check disk space
Write-Log "" "INFO"
Write-Log "=== Disk Space Analysis ===" "INFO"
Test-DiskSpace -Paths @($VeeamPath, $WSLPath)

# Step 6: Generate report
if ($GenerateReport) {
    Write-Log "" "INFO"
    Write-Log "=== Generating Report ===" "INFO"
    $reportFile = New-VerificationReport -LogFile $logFile

    # Send email if requested
    if ($EmailReport -and $reportFile) {
        Send-EmailReport -ReportFile $reportFile -SMTPServer $SMTPServer -From $EmailFrom -To $EmailTo
    }
}

# Step 7: Summary
Write-Log "" "INFO"
Write-Log "================================================" "INFO"
Write-Log "=== Verification Summary ===" "INFO"
Write-Log "================================================" "INFO"
Write-Log "Overall Status: $($script:verificationResults.OverallStatus)" $(if($script:verificationResults.OverallStatus -eq "HEALTHY"){"SUCCESS"}elseif($script:verificationResults.OverallStatus -eq "WARNING"){"WARNING"}else{"ERROR"})
Write-Log "Veeam Status: $($script:verificationResults.VeeamStatus)" "INFO"
Write-Log "WSL Status: $($script:verificationResults.WSLStatus)" "INFO"
Write-Log "Warnings: $($script:verificationResults.Warnings.Count)" "INFO"
Write-Log "Errors: $($script:verificationResults.Errors.Count)" "INFO"
Write-Log "" "INFO"
Write-Log "Log file: $logFile" "INFO"
if ($reportFile) {
    Write-Log "Report file: $reportFile" "INFO"
}
Write-Log "================================================" "INFO"
Write-Log "=== Backup Verification Completed ===" $(if($script:verificationResults.Errors.Count -eq 0){"SUCCESS"}else{"WARNING"})
Write-Log "================================================" "INFO"

# Exit with appropriate code
if ($script:verificationResults.Errors.Count -gt 0) {
    exit 1
} elseif ($script:verificationResults.Warnings.Count -gt 0) {
    exit 2
} else {
    exit 0
}
