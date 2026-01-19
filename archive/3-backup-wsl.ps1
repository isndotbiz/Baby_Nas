# Script 3: WSL Backup Automation
# Purpose: Backup all WSL distributions
# Run as: Administrator
# Usage: .\3-backup-wsl.ps1 -BackupPath "X:\WSLBackups"

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "X:\WSLBackups",

    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 7
)

# Create log directory
$logDir = "C:\Logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\wsl-backup-$timestamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console with color
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage -ForegroundColor White }
    }

    # Write to log file
    $logMessage | Out-File -FilePath $logFile -Append
}

Write-Log "=== WSL Backup Script Started ===" "INFO"

# Create backup directory if not exists
if (-not (Test-Path $BackupPath)) {
    Write-Log "Creating backup directory: $BackupPath" "INFO"
    New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
}

# Check if WSL is installed
$wslCheck = wsl --list --quiet 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log "WSL is not installed or not running" "ERROR"
    exit 1
}

# Get list of WSL distributions
Write-Log "Detecting WSL distributions..." "INFO"
$distributions = wsl --list --quiet | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }

if ($distributions.Count -eq 0) {
    Write-Log "No WSL distributions found" "WARNING"
    exit 0
}

Write-Log "Found $($distributions.Count) distribution(s): $($distributions -join ', ')" "INFO"

# Backup each distribution
$successCount = 0
$failCount = 0

foreach ($distro in $distributions) {
    $distroName = $distro.Trim()
    $backupFile = Join-Path $BackupPath "$distroName-$timestamp.tar"

    Write-Log "Backing up: $distroName" "INFO"
    Write-Log "  Target: $backupFile" "INFO"

    try {
        # Export WSL distribution
        $exportStart = Get-Date
        wsl --export $distroName $backupFile 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            $exportEnd = Get-Date
            $duration = ($exportEnd - $exportStart).TotalMinutes

            # Get file size
            $fileInfo = Get-Item $backupFile
            $sizeGB = [math]::Round($fileInfo.Length / 1GB, 2)

            Write-Log "  SUCCESS: Backup completed in $([math]::Round($duration, 1)) minutes" "SUCCESS"
            Write-Log "  Size: $sizeGB GB" "INFO"

            $successCount++
        } else {
            Write-Log "  FAILED: Export command returned error code $LASTEXITCODE" "ERROR"
            $failCount++
        }
    } catch {
        Write-Log "  FAILED: $($_.Exception.Message)" "ERROR"
        $failCount++
    }
}

# Cleanup old backups
Write-Log "Cleaning up old backups (keeping last $RetentionDays days)..." "INFO"

try {
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $oldBackups = Get-ChildItem $BackupPath -Filter "*.tar" |
        Where-Object { $_.CreationTime -lt $cutoffDate }

    if ($oldBackups) {
        foreach ($backup in $oldBackups) {
            Write-Log "  Deleting: $($backup.Name) (age: $((Get-Date) - $backup.CreationTime).Days days)" "INFO"
            Remove-Item $backup.FullName -Force
        }
        Write-Log "  Cleaned up $($oldBackups.Count) old backup(s)" "SUCCESS"
    } else {
        Write-Log "  No old backups to clean up" "INFO"
    }
} catch {
    Write-Log "  Cleanup failed: $($_.Exception.Message)" "WARNING"
}

# Calculate total backup size
$totalSize = (Get-ChildItem $BackupPath -Filter "*.tar" |
    Measure-Object -Property Length -Sum).Sum / 1GB

Write-Log "=== Backup Summary ===" "INFO"
Write-Log "Successful: $successCount" "SUCCESS"
Write-Log "Failed: $failCount" $(if ($failCount -gt 0) { "ERROR" } else { "INFO" })
Write-Log "Total backup size: $([math]::Round($totalSize, 2)) GB" "INFO"
Write-Log "Log file: $logFile" "INFO"
Write-Log "=== WSL Backup Script Completed ===" "INFO"

# Exit with appropriate code
if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}
