#Requires -RunAsAdministrator
###############################################################################
# Automated Workspace Backup Script
# Purpose: Backup D:\workspace to Baby NAS using Robocopy
# Usage: .\backup-workspace.ps1 [-Destination <path>] [-WhatIf]
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$Source = "D:\workspace",

    [Parameter(Mandatory=$false)]
    [string]$Destination = "",

    [Parameter(Mandatory=$false)]
    [string]$BabyNasIP = "",

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,

    [Parameter(Mandatory=$false)]
    [switch]$SendEmail,

    [Parameter(Mandatory=$false)]
    [string]$EmailTo = "",

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\workspace-backup"
)

$ErrorActionPreference = "Continue"

###############################################################################
# CONFIGURATION
###############################################################################

# Exclude patterns for Robocopy
$ExcludeDirs = @(
    "node_modules",
    ".git",
    ".vscode",
    "bin",
    "obj",
    ".vs",
    "dist",
    "build",
    "out",
    ".next",
    ".nuxt",
    "target",
    "venv",
    "__pycache__",
    ".pytest_cache",
    "coverage",
    ".idea",
    "logs",
    "temp",
    "tmp",
    ".cache"
)

$ExcludeFiles = @(
    "*.tmp",
    "*.temp",
    "*.log",
    "*.cache",
    "Thumbs.db",
    ".DS_Store",
    "desktop.ini",
    "*.pyc",
    "*.pyo",
    "package-lock.json",
    "yarn.lock"
)

# Robocopy options
# /MIR = Mirror (delete files in dest not in source)
# /R:3 = Retry 3 times on failed copies
# /W:5 = Wait 5 seconds between retries
# /MT:8 = Multi-threaded (8 threads)
# /NP = No progress percentage (cleaner logs)
# /NFL = No file list (reduces log size)
# /NDL = No directory list
# /XJ = Exclude junction points
# /XJD = Exclude junction points for directories
# /XJF = Exclude junction points for files
$RobocopyOptions = @(
    "/MIR",
    "/R:3",
    "/W:5",
    "/MT:8",
    "/NP",
    "/XJ",
    "/XJD",
    "/XJF",
    "/DCOPY:DAT",
    "/COPY:DAT",
    "/FFT",
    "/DST",
    "/V",
    "/TS",
    "/FP"
)

###############################################################################
# FUNCTIONS
###############################################################################

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8

    # Write to console with color
    $color = switch ($Level) {
        'INFO'    { 'White' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
    }

    Write-Host $logMessage -ForegroundColor $color
}

function Get-DirectorySize {
    param([string]$Path)

    try {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round($size / 1GB, 2)
    } catch {
        return 0
    }
}

function Send-EmailNotification {
    param(
        [string]$Subject,
        [string]$Body,
        [string]$To
    )

    if ([string]::IsNullOrEmpty($To)) {
        return
    }

    Write-Log "Email notification feature not configured. Set up SMTP settings to enable." -Level WARNING
    Write-Log "Would send email to: $To" -Level INFO
    Write-Log "Subject: $Subject" -Level INFO

    # TODO: Configure SMTP settings
    <#
    try {
        Send-MailMessage `
            -To $To `
            -Subject $Subject `
            -Body $Body `
            -SmtpServer "smtp.example.com" `
            -From "backups@example.com" `
            -Port 587 `
            -UseSsl `
            -Credential (Get-Credential)
    } catch {
        Write-Log "Failed to send email: $($_.Exception.Message)" -Level ERROR
    }
    #>
}

###############################################################################
# MAIN SCRIPT
###############################################################################

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                    Workspace Backup to Baby NAS                          ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "Backup Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Create log directory
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $LogPath "backup-$timestamp.log"

Write-Log "=== Workspace Backup Started ===" -Level INFO
Write-Log "Source: $Source" -Level INFO

###############################################################################
# Validate Source
###############################################################################

if (-not (Test-Path $Source)) {
    Write-Log "Source path does not exist: $Source" -Level ERROR
    exit 1
}

$sourceSize = Get-DirectorySize -Path $Source
Write-Log "Source size: $sourceSize GB" -Level INFO

###############################################################################
# Determine Destination
###############################################################################

if ([string]::IsNullOrEmpty($Destination)) {
    # Auto-detect Baby NAS share
    Write-Log "Auto-detecting Baby NAS destination..." -Level INFO

    # Try common mapped drives first
    $mappedDrives = Get-PSDrive -PSProvider FileSystem | Where-Object {
        $_.DisplayRoot -and (
            $_.DisplayRoot -match "WindowsBackup" -or
            $_.DisplayRoot -match "windows-backup"
        )
    }

    if ($mappedDrives) {
        $drive = $mappedDrives | Select-Object -First 1
        $Destination = Join-Path "$($drive.Name):" "d-workspace"
        Write-Log "Found mapped drive: $Destination" -Level SUCCESS
    }
    # Try UNC paths
    elseif ([string]::IsNullOrEmpty($BabyNasIP)) {
        # Try to detect Baby NAS IP
        $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1
        if ($vm) {
            $vmNet = Get-VMNetworkAdapter -VM $vm
            if ($vmNet.IPAddresses) {
                $BabyNasIP = ($vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
            }
        }

        if ([string]::IsNullOrEmpty($BabyNasIP)) {
            Write-Log "Could not auto-detect Baby NAS. Please specify -Destination or -BabyNasIP" -Level ERROR
            exit 1
        }

        $Destination = "\\$BabyNasIP\WindowsBackup\d-workspace"
        Write-Log "Using UNC path: $Destination" -Level INFO
    } else {
        $Destination = "\\$BabyNasIP\WindowsBackup\d-workspace"
        Write-Log "Using UNC path: $Destination" -Level INFO
    }
}

Write-Log "Destination: $Destination" -Level INFO

###############################################################################
# Validate Destination
###############################################################################

# Create destination if it doesn't exist
if (-not (Test-Path $Destination)) {
    Write-Log "Creating destination directory: $Destination" -Level INFO
    try {
        New-Item -Path $Destination -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Log "Destination created successfully" -Level SUCCESS
    } catch {
        Write-Log "Failed to create destination: $($_.Exception.Message)" -Level ERROR
        exit 1
    }
}

# Test write access
$testFile = Join-Path $Destination ".backup-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
try {
    "test" | Out-File -FilePath $testFile -ErrorAction Stop
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    Write-Log "Destination is writable" -Level SUCCESS
} catch {
    Write-Log "Destination is not writable: $($_.Exception.Message)" -Level ERROR
    exit 1
}

###############################################################################
# Pre-Backup Checks
###############################################################################

Write-Log "" -Level INFO
Write-Log "=== Pre-Backup Checks ===" -Level INFO

# Check destination space
try {
    $destDrive = Get-PSDrive -PSProvider FileSystem | Where-Object {
        $_.DisplayRoot -and $Destination.StartsWith($_.Name + ":")
    } | Select-Object -First 1

    if ($destDrive) {
        $freeSpaceGB = [math]::Round($destDrive.Free / 1GB, 2)
        Write-Log "Destination free space: $freeSpaceGB GB" -Level INFO

        if ($freeSpaceGB -lt ($sourceSize * 1.2)) {
            Write-Log "WARNING: Destination may not have enough space (need ~$($sourceSize * 1.2) GB)" -Level WARNING
        } else {
            Write-Log "Sufficient space available" -Level SUCCESS
        }
    }
} catch {
    Write-Log "Could not check destination space: $($_.Exception.Message)" -Level WARNING
}

# Check for running processes that might lock files
$lockedProcesses = @(
    "devenv",      # Visual Studio
    "code",        # VS Code
    "python",
    "node",
    "npm",
    "git"
)

$runningLocked = Get-Process | Where-Object {
    $lockedProcesses -contains $_.ProcessName
}

if ($runningLocked) {
    Write-Log "WARNING: The following processes are running and may lock files:" -Level WARNING
    $runningLocked | Select-Object ProcessName, Id | ForEach-Object {
        Write-Log "  - $($_.ProcessName) (PID: $($_.Id))" -Level WARNING
    }
    Write-Log "Consider closing these applications for a complete backup" -Level WARNING
    Write-Host ""
}

###############################################################################
# Build Robocopy Command
###############################################################################

if ($WhatIf) {
    Write-Log "=== RUNNING IN WHATIF MODE ===" -Level WARNING
    Write-Log "No files will be modified" -Level WARNING
    Write-Host ""
    $RobocopyOptions += "/L"  # List only mode
}

# Build exclude parameters
$excludeDirParams = $ExcludeDirs | ForEach-Object { "/XD", $_ }
$excludeFileParams = $ExcludeFiles | ForEach-Object { "/XF", $_ }

# Build full command
$robocopyArgs = @($Source, $Destination) + $RobocopyOptions + $excludeDirParams + $excludeFileParams + @("/LOG+:$logFile")

Write-Log "" -Level INFO
Write-Log "=== Starting Robocopy ===" -Level INFO
Write-Log "Command: robocopy $($robocopyArgs -join ' ')" -Level INFO
Write-Host ""

###############################################################################
# Execute Backup
###############################################################################

$startTime = Get-Date

try {
    # Execute Robocopy
    $result = & robocopy $robocopyArgs

    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Robocopy exit codes:
    # 0 = No files copied (no change)
    # 1 = Files copied successfully
    # 2 = Extra files/dirs detected (expected with /MIR)
    # 3 = 1 + 2 (files copied and extra files detected)
    # 4+ = Errors occurred

    $exitCode = $LASTEXITCODE

    Write-Host ""
    Write-Log "=== Robocopy Completed ===" -Level INFO
    Write-Log "Exit Code: $exitCode" -Level INFO
    Write-Log "Duration: $($duration.ToString('hh\:mm\:ss'))" -Level INFO

    # Interpret exit code
    if ($exitCode -eq 0) {
        Write-Log "No changes detected - backup is already current" -Level SUCCESS
        $status = "SUCCESS"
        $statusDetail = "No changes (already synchronized)"
    } elseif ($exitCode -le 3) {
        Write-Log "Backup completed successfully" -Level SUCCESS
        $status = "SUCCESS"
        $statusDetail = if ($exitCode -eq 1) { "Files copied" }
                       elseif ($exitCode -eq 2) { "Extra files cleaned up" }
                       else { "Files copied and cleaned up" }
    } elseif ($exitCode -le 7) {
        Write-Log "Backup completed with warnings (some files may have been skipped)" -Level WARNING
        $status = "WARNING"
        $statusDetail = "Completed with warnings - check log for details"
    } else {
        Write-Log "Backup failed with errors (exit code: $exitCode)" -Level ERROR
        $status = "ERROR"
        $statusDetail = "Failed with errors - check log for details"
    }

} catch {
    Write-Log "Backup failed with exception: $($_.Exception.Message)" -Level ERROR
    $status = "ERROR"
    $statusDetail = $_.Exception.Message
    $exitCode = 99
}

###############################################################################
# Post-Backup Summary
###############################################################################

Write-Host ""
Write-Log "=== Backup Summary ===" -Level INFO

# Try to parse Robocopy log for statistics
try {
    $logContent = Get-Content $logFile -Tail 50 -ErrorAction SilentlyContinue
    $stats = $logContent | Select-String -Pattern "Files\s*:\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)"

    if ($stats) {
        Write-Log "Statistics from Robocopy:" -Level INFO
        # Parse the statistics line
        $logContent | Select-String -Pattern "(Total|Dirs|Files)\s*:" | ForEach-Object {
            Write-Log "  $($_.Line.Trim())" -Level INFO
        }
    }
} catch {
    Write-Log "Could not parse backup statistics" -Level WARNING
}

# Check destination size after backup
$destSize = Get-DirectorySize -Path $Destination
Write-Log "Destination size after backup: $destSize GB" -Level INFO

Write-Host ""
Write-Log "Status: $status - $statusDetail" -Level $(if ($status -eq "SUCCESS") { "SUCCESS" } elseif ($status -eq "WARNING") { "WARNING" } else { "ERROR" })
Write-Log "Log file: $logFile" -Level INFO

###############################################################################
# Create Backup Marker File
###############################################################################

if ($status -ne "ERROR") {
    $markerFile = Join-Path $Destination ".last-backup-info.txt"
    $markerContent = @"
Last Backup: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Status: $status
Duration: $($duration.ToString('hh\:mm\:ss'))
Source: $Source
Source Size: $sourceSize GB
Destination Size: $destSize GB
Log File: $logFile
Exit Code: $exitCode
"@
    $markerContent | Out-File -FilePath $markerFile -Encoding UTF8 -Force
}

###############################################################################
# Send Email Notification (if configured)
###############################################################################

if ($SendEmail -and -not [string]::IsNullOrEmpty($EmailTo)) {
    $emailSubject = "Workspace Backup: $status"
    $emailBody = @"
Workspace Backup Report
=======================

Status: $status
Details: $statusDetail
Duration: $($duration.ToString('hh\:mm\:ss'))

Source: $Source
Destination: $Destination

Source Size: $sourceSize GB
Destination Size: $destSize GB

Robocopy Exit Code: $exitCode

Log File: $logFile

Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

    Send-EmailNotification -Subject $emailSubject -Body $emailBody -To $EmailTo
}

###############################################################################
# Cleanup Old Logs
###############################################################################

try {
    $oldLogs = Get-ChildItem $LogPath -Filter "backup-*.log" |
               Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }

    if ($oldLogs) {
        Write-Log "Cleaning up $($oldLogs.Count) old log files (>30 days)" -Level INFO
        $oldLogs | Remove-Item -Force
    }
} catch {
    Write-Log "Could not clean up old logs: $($_.Exception.Message)" -Level WARNING
}

###############################################################################
# Exit
###############################################################################

Write-Host ""
Write-Host "Backup completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Return exit code
if ($status -eq "ERROR") {
    exit 1
} elseif ($status -eq "WARNING") {
    exit 2
} else {
    exit 0
}
