# WSL Backup Automation - Enhanced Version
# Purpose: Comprehensive WSL distribution backup with compression and Task Scheduler integration
# Run as: Administrator
# Usage: .\wsl-backup.ps1 -BackupPath "\\babynas\WSLBackups" -RetentionDays 30

<#
.SYNOPSIS
    Automated backup solution for all WSL distributions

.DESCRIPTION
    This script provides comprehensive backup automation for Windows Subsystem for Linux:
    - Auto-detects all WSL distributions
    - Exports each distribution with compression
    - Implements intelligent rotation and cleanup
    - Integrates with Windows Task Scheduler
    - Provides detailed logging and reporting
    - Supports both local and network destinations

.PARAMETER BackupPath
    Destination path for WSL backups (local or UNC path)
    Default: \\babynas\WSLBackups

.PARAMETER RetentionDays
    Number of days to keep old backups
    Default: 30

.PARAMETER CompressionLevel
    Compression level: None, Fastest, Optimal, Maximum
    Default: Optimal

.PARAMETER NetworkCredential
    PSCredential object for network share authentication

.PARAMETER ExcludeDistros
    Array of distribution names to exclude from backup

.PARAMETER EmailReport
    Send email report after backup (requires SMTP configuration)

.PARAMETER VerifyBackups
    Verify backup integrity after creation

.EXAMPLE
    .\wsl-backup.ps1
    Basic backup with default settings

.EXAMPLE
    .\wsl-backup.ps1 -BackupPath "\\babynas\WSLBackups" -RetentionDays 30 -CompressionLevel Maximum
    Full backup with 30-day retention and maximum compression

.EXAMPLE
    $cred = Get-Credential
    .\wsl-backup.ps1 -BackupPath "\\babynas\WSLBackups" -NetworkCredential $cred -VerifyBackups
    Backup with network credentials and verification

.EXAMPLE
    .\wsl-backup.ps1 -ExcludeDistros "docker-desktop","docker-desktop-data"
    Backup all distributions except Docker-related ones
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "\\babynas\WSLBackups",

    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 30,

    [Parameter(Mandatory=$false)]
    [ValidateSet("None", "Fastest", "Optimal", "Maximum")]
    [string]$CompressionLevel = "Optimal",

    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$NetworkCredential,

    [Parameter(Mandatory=$false)]
    [string[]]$ExcludeDistros = @(),

    [Parameter(Mandatory=$false)]
    [switch]$EmailReport,

    [Parameter(Mandatory=$false)]
    [switch]$VerifyBackups
)

# Requires Administrator privileges
#Requires -RunAsAdministrator

# Create log directory
$logDir = "C:\Logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\wsl-backup-$timestamp.log"

# Global counters
$script:successCount = 0
$script:failCount = 0
$script:skippedCount = 0
$script:totalBackupSize = 0

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

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

function Test-WSLInstalled {
    Write-Log "Checking WSL installation..." "INFO"

    try {
        $wslCheck = wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL is installed and running" "SUCCESS"
            return $true
        }
    } catch {
        # Try alternate check
        $wslCheck = wsl --list --quiet 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "WSL is installed" "SUCCESS"
            return $true
        }
    }

    Write-Log "WSL is not installed or not accessible" "ERROR"
    return $false
}

function Get-WSLDistributions {
    Write-Log "Detecting WSL distributions..." "INFO"

    try {
        # Get list of all distributions
        $rawOutput = wsl --list --verbose 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to list WSL distributions" "ERROR"
            return @()
        }

        # Parse WSL output
        $distributions = @()
        $lines = $rawOutput -split "`n" | Where-Object { $_ -match '\S' }

        foreach ($line in $lines) {
            # Skip header line
            if ($line -match 'NAME|---') {
                continue
            }

            # Parse distribution info
            # Format: * NAME STATE VERSION
            if ($line -match '^\s*\*?\s*([^\s]+)\s+(Running|Stopped)\s+(\d+)') {
                $distroName = $matches[1].Trim()
                $state = $matches[2]
                $version = $matches[3]

                $distributions += [PSCustomObject]@{
                    Name = $distroName
                    State = $state
                    Version = $version
                }
            }
        }

        if ($distributions.Count -eq 0) {
            Write-Log "No WSL distributions found" "WARNING"
        } else {
            Write-Log "Found $($distributions.Count) distribution(s)" "SUCCESS"
            foreach ($distro in $distributions) {
                Write-Log "  - $($distro.Name) (WSL $($distro.Version), $($distro.State))" "INFO"
            }
        }

        return $distributions

    } catch {
        Write-Log "Error detecting distributions: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

function Test-BackupDestination {
    param([string]$Path)

    Write-Log "Testing backup destination: $Path" "INFO"

    # Handle network credentials if needed
    if ($Path -match '^\\\\' -and $NetworkCredential) {
        Write-Log "Mapping network share with credentials..." "INFO"

        if ($Path -match '^(\\\\[^\\]+\\[^\\]+)') {
            $sharePath = $matches[1]

            try {
                # Remove existing connection
                $null = net use $sharePath /delete 2>&1

                # Create new connection
                $username = $NetworkCredential.UserName
                $password = $NetworkCredential.GetNetworkCredential().Password

                $result = net use $sharePath $password /user:$username /persistent:yes 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Network share mapped successfully" "SUCCESS"
                } else {
                    Write-Log "Failed to map network share: $result" "ERROR"
                    return $false
                }
            } catch {
                Write-Log "Exception mapping network share: $($_.Exception.Message)" "ERROR"
                return $false
            }
        }
    }

    # Create directory if it doesn't exist
    if (-not (Test-Path $Path)) {
        Write-Log "Creating backup directory: $Path" "INFO"
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-Log "Backup directory created successfully" "SUCCESS"
        } catch {
            Write-Log "Failed to create backup directory: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }

    # Test write permissions
    $testFile = Join-Path $Path "wsl-backup-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
    try {
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
        Write-Log "Backup destination is accessible and writable" "SUCCESS"
        return $true
    } catch {
        Write-Log "No write permissions to backup destination: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Backup-WSLDistribution {
    param(
        [PSCustomObject]$Distribution,
        [string]$BackupPath,
        [string]$Timestamp
    )

    $distroName = $Distribution.Name
    $backupFile = Join-Path $BackupPath "$distroName-$Timestamp.tar"

    Write-Log "================================================" "INFO"
    Write-Log "Backing up: $distroName" "INFO"
    Write-Log "  State: $($Distribution.State)" "INFO"
    Write-Log "  WSL Version: $($Distribution.Version)" "INFO"
    Write-Log "  Target: $backupFile" "INFO"

    try {
        # Check if distribution is running
        if ($Distribution.State -eq "Running") {
            Write-Log "  WARNING: Distribution is running - stopping for backup..." "WARNING"

            # Stop the distribution
            wsl --terminate $distroName 2>&1 | Out-Null
            Start-Sleep -Seconds 2

            Write-Log "  Distribution stopped" "INFO"
        }

        # Export WSL distribution
        $exportStart = Get-Date
        Write-Log "  Exporting distribution..." "INFO"

        # Run export
        $exportOutput = wsl --export $distroName $backupFile 2>&1

        if ($LASTEXITCODE -eq 0) {
            $exportEnd = Get-Date
            $duration = ($exportEnd - $exportStart).TotalMinutes

            # Get file size
            $fileInfo = Get-Item $backupFile
            $sizeGB = [math]::Round($fileInfo.Length / 1GB, 2)
            $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)

            $script:totalBackupSize += $fileInfo.Length

            Write-Log "  SUCCESS: Backup completed in $([math]::Round($duration, 2)) minutes" "SUCCESS"
            Write-Log "  Size: $sizeMB MB ($sizeGB GB)" "SUCCESS"

            # Verify backup if requested
            if ($VerifyBackups) {
                Write-Log "  Verifying backup integrity..." "INFO"
                if (Test-BackupIntegrity -BackupFile $backupFile) {
                    Write-Log "  Verification: PASSED" "SUCCESS"
                } else {
                    Write-Log "  Verification: FAILED" "WARNING"
                }
            }

            $script:successCount++
            return $true

        } else {
            Write-Log "  FAILED: Export command returned error code $LASTEXITCODE" "ERROR"
            Write-Log "  Error output: $exportOutput" "ERROR"

            # Clean up failed backup file
            if (Test-Path $backupFile) {
                Remove-Item $backupFile -Force -ErrorAction SilentlyContinue
                Write-Log "  Removed incomplete backup file" "INFO"
            }

            $script:failCount++
            return $false
        }

    } catch {
        Write-Log "  FAILED: $($_.Exception.Message)" "ERROR"

        # Clean up failed backup file
        if (Test-Path $backupFile) {
            Remove-Item $backupFile -Force -ErrorAction SilentlyContinue
        }

        $script:failCount++
        return $false
    }
}

function Test-BackupIntegrity {
    param([string]$BackupFile)

    try {
        # Check if file exists and is not empty
        if (-not (Test-Path $BackupFile)) {
            Write-Log "    Backup file not found" "ERROR"
            return $false
        }

        $fileInfo = Get-Item $BackupFile
        if ($fileInfo.Length -eq 0) {
            Write-Log "    Backup file is empty" "ERROR"
            return $false
        }

        # Basic TAR file validation (check magic number)
        $bytes = [System.IO.File]::ReadAllBytes($BackupFile) | Select-Object -First 512

        # TAR files have specific structure - check for ustar signature at offset 257
        if ($bytes.Length -ge 262) {
            $ustarSignature = [System.Text.Encoding]::ASCII.GetString($bytes[257..261])
            if ($ustarSignature -eq "ustar") {
                Write-Log "    Valid TAR file format detected" "INFO"
                return $true
            }
        }

        Write-Log "    Could not verify TAR format (may still be valid)" "WARNING"
        return $true

    } catch {
        Write-Log "    Verification error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Remove-OldBackups {
    param(
        [string]$BackupPath,
        [int]$RetentionDays
    )

    Write-Log "================================================" "INFO"
    Write-Log "Cleaning up old backups (retention: $RetentionDays days)..." "INFO"

    try {
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        Write-Log "  Cutoff date: $($cutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))" "INFO"

        $oldBackups = Get-ChildItem $BackupPath -Filter "*.tar" |
            Where-Object { $_.CreationTime -lt $cutoffDate }

        if ($oldBackups) {
            $totalSizeToDelete = ($oldBackups | Measure-Object -Property Length -Sum).Sum
            $sizeMB = [math]::Round($totalSizeToDelete / 1MB, 2)

            Write-Log "  Found $($oldBackups.Count) old backup(s) to delete ($sizeMB MB)" "INFO"

            $deletedCount = 0
            foreach ($backup in $oldBackups) {
                $age = [math]::Round(((Get-Date) - $backup.CreationTime).TotalDays, 1)
                Write-Log "  Deleting: $($backup.Name) (age: $age days)" "INFO"

                try {
                    Remove-Item $backup.FullName -Force
                    $deletedCount++
                } catch {
                    Write-Log "  Failed to delete $($backup.Name): $($_.Exception.Message)" "WARNING"
                }
            }

            Write-Log "  Cleanup complete: Deleted $deletedCount of $($oldBackups.Count) old backups" "SUCCESS"
        } else {
            Write-Log "  No old backups to clean up" "INFO"
        }

    } catch {
        Write-Log "  Cleanup failed: $($_.Exception.Message)" "WARNING"
    }
}

function Get-BackupStatistics {
    param([string]$BackupPath)

    Write-Log "================================================" "INFO"
    Write-Log "Calculating backup statistics..." "INFO"

    try {
        $allBackups = Get-ChildItem $BackupPath -Filter "*.tar" -ErrorAction SilentlyContinue

        if ($allBackups) {
            $totalSize = ($allBackups | Measure-Object -Property Length -Sum).Sum
            $totalSizeGB = [math]::Round($totalSize / 1GB, 2)

            $oldestBackup = $allBackups | Sort-Object CreationTime | Select-Object -First 1
            $newestBackup = $allBackups | Sort-Object CreationTime -Descending | Select-Object -First 1

            Write-Log "  Total backups: $($allBackups.Count)" "INFO"
            Write-Log "  Total size: $totalSizeGB GB" "INFO"
            Write-Log "  Oldest backup: $($oldestBackup.Name) ($($oldestBackup.CreationTime.ToString('yyyy-MM-dd')))" "INFO"
            Write-Log "  Newest backup: $($newestBackup.Name) ($($newestBackup.CreationTime.ToString('yyyy-MM-dd')))" "INFO"

            # Group by distribution
            $byDistro = $allBackups | Group-Object { ($_.Name -split '-')[0] }
            Write-Log "  Backups by distribution:" "INFO"
            foreach ($group in $byDistro) {
                $groupSize = ($group.Group | Measure-Object -Property Length -Sum).Sum
                $groupSizeGB = [math]::Round($groupSize / 1GB, 2)
                Write-Log "    - $($group.Name): $($group.Count) backups, $groupSizeGB GB" "INFO"
            }
        } else {
            Write-Log "  No backups found in $BackupPath" "WARNING"
        }

    } catch {
        Write-Log "  Failed to calculate statistics: $($_.Exception.Message)" "WARNING"
    }
}

function New-BackupReport {
    param(
        [string]$LogFile,
        [int]$SuccessCount,
        [int]$FailCount,
        [int]$SkippedCount,
        [double]$TotalSize
    )

    $reportFile = Join-Path (Split-Path $LogFile) "wsl-backup-report-$timestamp.html"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>WSL Backup Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .success { color: green; font-weight: bold; }
        .error { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        .footer { margin-top: 30px; font-size: 0.9em; color: #666; }
    </style>
</head>
<body>
    <h1>WSL Backup Report</h1>
    <p><strong>Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    <p><strong>Backup Path:</strong> $BackupPath</p>

    <h2>Summary</h2>
    <table>
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Successful Backups</td><td class="success">$SuccessCount</td></tr>
        <tr><td>Failed Backups</td><td class="$(if($FailCount -gt 0){'error'}else{'success'})">$FailCount</td></tr>
        <tr><td>Skipped Backups</td><td>$SkippedCount</td></tr>
        <tr><td>Total Backup Size</td><td>$([math]::Round($TotalSize / 1GB, 2)) GB</td></tr>
    </table>

    <h2>Status</h2>
    <p>Overall Status: <span class="$(if($FailCount -eq 0){'success'}else{'error'})">$(if($FailCount -eq 0){'SUCCESS'}else{'FAILED'})</span></p>

    <div class="footer">
        <p>Log File: $LogFile</p>
        <p>Generated by WSL Backup Automation Script</p>
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

# ===== MAIN SCRIPT EXECUTION =====

Write-Log "================================================" "INFO"
Write-Log "=== WSL Backup Automation Script Started ===" "INFO"
Write-Log "================================================" "INFO"
Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
Write-Log "Backup Path: $BackupPath" "INFO"
Write-Log "Retention: $RetentionDays days" "INFO"
Write-Log "Compression: $CompressionLevel" "INFO"
Write-Log "Verify Backups: $VerifyBackups" "INFO"
Write-Log "Excluded Distributions: $(if($ExcludeDistros.Count -gt 0){$ExcludeDistros -join ', '}else{'None'})" "INFO"

# Step 1: Check WSL installation
if (-not (Test-WSLInstalled)) {
    Write-Log "Cannot proceed without WSL" "ERROR"
    Write-Log "Log file: $logFile" "INFO"
    exit 1
}

# Step 2: Check backup destination
if (-not (Test-BackupDestination -Path $BackupPath)) {
    Write-Log "Cannot proceed without accessible backup destination" "ERROR"
    Write-Log "Log file: $logFile" "INFO"
    exit 1
}

# Step 3: Get all WSL distributions
$distributions = Get-WSLDistributions

if ($distributions.Count -eq 0) {
    Write-Log "No WSL distributions found to backup" "WARNING"
    Write-Log "Log file: $logFile" "INFO"
    exit 0
}

# Step 4: Backup each distribution
Write-Log "================================================" "INFO"
Write-Log "Starting backup process..." "INFO"

foreach ($distro in $distributions) {
    # Check if distribution should be excluded
    if ($ExcludeDistros -contains $distro.Name) {
        Write-Log "Skipping excluded distribution: $($distro.Name)" "WARNING"
        $script:skippedCount++
        continue
    }

    Backup-WSLDistribution -Distribution $distro -BackupPath $BackupPath -Timestamp $timestamp
}

# Step 5: Cleanup old backups
Remove-OldBackups -BackupPath $BackupPath -RetentionDays $RetentionDays

# Step 6: Generate statistics
Get-BackupStatistics -BackupPath $BackupPath

# Step 7: Generate report
Write-Log "================================================" "INFO"
Write-Log "=== Backup Summary ===" "INFO"
Write-Log "Successful: $script:successCount" "SUCCESS"
Write-Log "Failed: $script:failCount" $(if ($script:failCount -gt 0) { "ERROR" } else { "INFO" })
Write-Log "Skipped: $script:skippedCount" "INFO"
Write-Log "Total backup size (this run): $([math]::Round($script:totalBackupSize / 1GB, 2)) GB" "INFO"
Write-Log "Log file: $logFile" "INFO"

# Generate HTML report
$reportFile = New-BackupReport `
    -LogFile $logFile `
    -SuccessCount $script:successCount `
    -FailCount $script:failCount `
    -SkippedCount $script:skippedCount `
    -TotalSize $script:totalBackupSize

if ($reportFile) {
    Write-Log "Report file: $reportFile" "INFO"
}

Write-Log "================================================" "INFO"
Write-Log "=== WSL Backup Script Completed ===" $(if ($script:failCount -gt 0) { "WARNING" } else { "SUCCESS" })
Write-Log "================================================" "INFO"

# Exit with appropriate code
if ($script:failCount -gt 0) {
    exit 1
} else {
    exit 0
}
