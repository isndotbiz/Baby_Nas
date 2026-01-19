<#
.SYNOPSIS
Archive old data from D: drive to Baby NAS with integrity verification

.DESCRIPTION
Copies 307GB of archived folders to Baby NAS, creates organized structure,
verifies integrity, and optionally cleans up source after confirmation.

Folders to archive:
  - D:\Optimum\ (182GB) - Old development environment
  - D:\~\ (38GB) - Old home directory backup
  - D:\Projects\ (48GB) - Old project archives
  - D:\ai-workspace\ (39GB) - Old AI workspace archive

Target on Baby NAS:
  - \\172.21.203.18\backups\archive\2025-12\ (organized by date)

.PARAMETER DryRun
  Show what would be copied without actually copying (default: true for safety)

.PARAMETER Execute
  Actually perform the copy operation

.PARAMETER SkipIntegrityCheck
  Skip verification after copy (not recommended)

.PARAMETER AutoCleanup
  Automatically delete source folders after successful verification

.EXAMPLE
  # Dry run - see what will be copied
  .\archive-old-data.ps1

  # Actually perform the archive
  .\archive-old-data.ps1 -Execute

  # Archive and auto-clean source folders
  .\archive-old-data.ps1 -Execute -AutoCleanup

.NOTES
  Requires: Network access to 172.21.203.18, SMB credentials
  Backups SMB share must exist on Baby NAS
  Source folders must be accessible on D: drive
#>

# Load environment variables from .env file
. "$PSScriptRoot\Load-EnvFile.ps1"

param(
    [switch]$DryRun = $true,
    [switch]$Execute,
    [switch]$SkipIntegrityCheck = $false,
    [switch]$AutoCleanup = $false,
    [string]$NasIP = (Get-EnvVariable "TRUENAS_IP" -Default "172.21.203.18"),
    [string]$NasShare = "backups",
    [string]$ArchiveDate = (Get-Date -Format "yyyy-MM"),
    [string]$NasUser = (Get-EnvVariable "TRUENAS_USERNAME" -Default "root"),
    [string]$NasPassword = (Get-EnvVariable "TRUENAS_PASSWORD")
)

# Override DryRun if Execute is specified
if ($Execute) {
    $DryRun = $false
}

$ErrorActionPreference = "Continue"

# Logging setup
$logDir = "C:\Logs"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $logDir "archive-old-data-$timestamp.log"

New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"

    Write-Host $logMessage -ForegroundColor $(switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "DEBUG" { "Gray" }
        default { "White" }
    })

    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Test-NasConnectivity {
    Write-Log "Testing connectivity to Baby NAS at $NasIP..." "INFO"

    if (Test-Connection -ComputerName $NasIP -Count 1 -Quiet) {
        Write-Log "✓ Baby NAS is reachable" "SUCCESS"
        return $true
    } else {
        Write-Log "✗ Cannot reach Baby NAS at $NasIP" "ERROR"
        return $false
    }
}

function Mount-NasShare {
    $smb = "\\$NasIP\$NasShare"

    Write-Log "Attempting to mount SMB share: $smb" "INFO"

    try {
        $credential = New-Object System.Management.Automation.PSCredential(
            $NasUser,
            (ConvertTo-SecureString $NasPassword -AsPlainText -Force)
        )

        New-PSDrive -Name "NasArchive" -PSProvider FileSystem -Root $smb -Credential $credential -Force -ErrorAction Stop | Out-Null
        Write-Log "✓ SMB share mounted as NasArchive:" "SUCCESS"
        return "NasArchive:"
    } catch {
        Write-Log "✗ Failed to mount SMB share: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Get-FolderSize {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return 0
    }

    try {
        $size = (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        return $size
    } catch {
        return 0
    }
}

function Format-Bytes {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } else {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Baby NAS Archive - Old Data Migration                ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Define folders to archive
$foldersToArchive = @(
    @{
        SourcePath = "D:\Optimum"
        TargetName = "optimum"
        Description = "Old development environment"
    },
    @{
        SourcePath = "D:\~"
        TargetName = "home-backup"
        Description = "Old home directory backup"
    },
    @{
        SourcePath = "D:\Projects"
        TargetName = "projects"
        Description = "Old project archives"
    },
    @{
        SourcePath = "D:\ai-workspace"
        TargetName = "ai-workspace-old"
        Description = "Old AI workspace archive"
    }
)

Write-Log "Archive operation started (DryRun: $DryRun)" "INFO"
Write-Log "Archive date: $ArchiveDate" "INFO"
Write-Host ""

# STEP 1: Analyze folders
Write-Host "=== STEP 1: Analyzing Folders to Archive ===" -ForegroundColor Cyan
Write-Host ""

$totalSize = 0
$folderStats = @()

foreach ($folder in $foldersToArchive) {
    $size = Get-FolderSize $folder.SourcePath
    $sizeFormatted = Format-Bytes $size
    $totalSize += $size

    $folderStats += [PSCustomObject]@{
        Folder      = Split-Path $folder.SourcePath -Leaf
        Path        = $folder.SourcePath
        Size        = $size
        SizeDisplay = $sizeFormatted
        Target      = $folder.TargetName
        Exists      = (Test-Path $folder.SourcePath)
    }

    $status = if (Test-Path $folder.SourcePath) { "✓ EXISTS" } else { "✗ MISSING" }
    Write-Log "$status $($folder.SourcePath) - $sizeFormatted ($($folder.Description))" "INFO"
}

$totalFormatted = Format-Bytes $totalSize

Write-Host ""
Write-Host "Summary of Folders to Archive:" -ForegroundColor Yellow
$folderStats | Format-Table -AutoSize
Write-Host ""
Write-Host "Total data to archive: $totalFormatted" -ForegroundColor Yellow
Write-Host ""

# STEP 2: Check connectivity
Write-Host "=== STEP 2: Verifying Baby NAS Connectivity ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-NasConnectivity)) {
    Write-Log "Cannot proceed without NAS connectivity" "ERROR"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure Baby NAS is running: Get-VM -Name TrueNAS-BabyNAS" -ForegroundColor White
    Write-Host "  2. Check ping: ping 172.21.203.18" -ForegroundColor White
    Write-Host "  3. Verify SMB is running: ssh admin@172.21.203.18 'svcs -a | grep smb'" -ForegroundColor White
    exit 1
}

# STEP 3: Mount NAS share
Write-Host ""
Write-Host "=== STEP 3: Mounting NAS Share ===" -ForegroundColor Cyan
Write-Host ""

$nasPath = Mount-NasShare
if (-not $nasPath) {
    Write-Log "Failed to mount NAS share" "ERROR"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check credentials are correct" -ForegroundColor White
    Write-Host "  2. Verify backups share exists on NAS" -ForegroundColor White
    Write-Host "  3. Check firewall allows SMB (port 445)" -ForegroundColor White
    exit 1
}

# STEP 4: Create archive directory structure
Write-Host ""
Write-Host "=== STEP 4: Setting Up Archive Directory Structure ===" -ForegroundColor Cyan
Write-Host ""

$archiveRoot = "$nasPath\archive\$ArchiveDate"

Write-Log "Archive root: $archiveRoot" "DEBUG"

if ($DryRun) {
    Write-Host "(DRY RUN - Not creating directories)" -ForegroundColor Yellow
    Write-Host "Would create: $archiveRoot" -ForegroundColor Gray
} else {
    try {
        New-Item -ItemType Directory -Path $archiveRoot -Force -ErrorAction Stop | Out-Null
        Write-Log "✓ Created archive directory structure" "SUCCESS"
        Write-Host "✓ Archive directory: $archiveRoot" -ForegroundColor Green
    } catch {
        Write-Log "✗ Failed to create archive directory: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# STEP 5: Copy folders
Write-Host ""
Write-Host "=== STEP 5: Copying Folders ===" -ForegroundColor Cyan
Write-Host ""

$copyResults = @()

foreach ($folder in $foldersToArchive) {
    if (-not (Test-Path $folder.SourcePath)) {
        Write-Log "⚠ Skipping $($folder.SourcePath) - not found" "WARNING"
        continue
    }

    $targetPath = "$archiveRoot\$($folder.TargetName)"
    $size = Get-FolderSize $folder.SourcePath
    $sizeFormatted = Format-Bytes $size

    Write-Host ""
    Write-Host "Copying: $($folder.SourcePath)" -ForegroundColor Cyan
    Write-Host "Target:  $targetPath" -ForegroundColor Cyan
    Write-Host "Size:    $sizeFormatted" -ForegroundColor Gray
    Write-Host ""

    if ($DryRun) {
        Write-Host "(DRY RUN - Would copy $sizeFormatted)" -ForegroundColor Yellow
        $copyResults += [PSCustomObject]@{
            Folder   = Split-Path $folder.SourcePath -Leaf
            Status   = "DRY RUN"
            Size     = $size
            CopyTime = "N/A"
            Success  = $null
        }
    } else {
        $startTime = Get-Date

        try {
            # Use robocopy for efficient transfer with verification
            Write-Log "Starting copy: $($folder.SourcePath) → $targetPath" "INFO"

            $robocopyArgs = @(
                $folder.SourcePath,
                $targetPath,
                "/E",                  # Copy all subdirectories including empty ones
                "/Z",                  # Restart mode (in case of interruption)
                "/V",                  # Verbose
                "/TS",                 # Include source file timestamps
                "/XJ",                 # Exclude junction points
                "/R:3",                # Retry 3 times on failed files
                "/W:10"                # Wait 10 seconds between retries
            )

            & robocopy.exe @robocopyArgs | Tee-Object -FilePath $logFile -Append | Out-Null

            $endTime = Get-Date
            $duration = $endTime - $startTime

            Write-Log "✓ Copy completed: $($folder.SourcePath) in $($duration.TotalMinutes) minutes" "SUCCESS"

            $copyResults += [PSCustomObject]@{
                Folder   = Split-Path $folder.SourcePath -Leaf
                Status   = "COPIED"
                Size     = $size
                CopyTime = "{0:N2} minutes" -f $duration.TotalMinutes
                Success  = $true
            }

            Write-Host "✓ Completed in $([Math]::Round($duration.TotalMinutes, 2)) minutes" -ForegroundColor Green
        } catch {
            Write-Log "✗ Copy failed: $($_.Exception.Message)" "ERROR"

            $copyResults += [PSCustomObject]@{
                Folder   = Split-Path $folder.SourcePath -Leaf
                Status   = "FAILED"
                Size     = $size
                CopyTime = "N/A"
                Success  = $false
            }

            Write-Host "✗ Copy failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# STEP 6: Verify integrity
Write-Host ""
Write-Host "=== STEP 6: Verifying Archive Integrity ===" -ForegroundColor Cyan
Write-Host ""

if ($SkipIntegrityCheck -or $DryRun) {
    Write-Host "(Skipping integrity verification)" -ForegroundColor Yellow
} else {
    Write-Log "Starting integrity verification" "INFO"

    $verifyResults = @()

    foreach ($result in $copyResults | Where-Object { $_.Success -eq $true }) {
        $sourceFolder = $foldersToArchive | Where-Object { $result.Folder -like "*$($_.TargetName)*" }
        $targetPath = "$archiveRoot\$($sourceFolder.TargetName)"

        Write-Host ""
        Write-Host "Verifying: $($result.Folder)" -ForegroundColor Cyan

        # Count files and get total size from both locations
        $sourceCount = (Get-ChildItem -Path $sourceFolder.SourcePath -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
        $targetCount = (Get-ChildItem -Path $targetPath -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count

        $sourceSize = Get-FolderSize $sourceFolder.SourcePath
        $targetSize = Get-FolderSize $targetPath

        $sizeMatch = if ($sourceSize -eq $targetSize) { "✓ MATCH" } else { "✗ MISMATCH" }
        $countMatch = if ($sourceCount -eq $targetCount) { "✓ MATCH" } else { "✗ MISMATCH" }

        Write-Host "  Files:  $countMatch ($sourceCount → $targetCount)" -ForegroundColor $(if ($countMatch -like "✓*") { "Green" } else { "Red" })
        Write-Host "  Size:   $sizeMatch ($(Format-Bytes $sourceSize) → $(Format-Bytes $targetSize))" -ForegroundColor $(if ($sizeMatch -like "✓*") { "Green" } else { "Red" })

        $verifyResults += [PSCustomObject]@{
            Folder     = $result.Folder
            FileMatch  = $countMatch
            SizeMatch  = $sizeMatch
            Verified   = ($countMatch -like "✓*" -and $sizeMatch -like "✓*")
        }

        Write-Log "Verification: $($result.Folder) - Files: $countMatch, Size: $sizeMatch" "INFO"
    }

    Write-Host ""
    Write-Host "Verification Summary:" -ForegroundColor Yellow
    $verifyResults | Format-Table -AutoSize

    $failedVerifications = @($verifyResults | Where-Object { $_.Verified -eq $false })
    if ($failedVerifications.Count -gt 0) {
        Write-Log "⚠ $($failedVerifications.Count) folder(s) failed verification" "WARNING"
        Write-Host ""
        Write-Host "⚠ Some folders failed verification!" -ForegroundColor Yellow
        Write-Host "Do NOT delete source folders until this is resolved." -ForegroundColor Yellow
        $AutoCleanup = $false
    } else {
        Write-Log "✓ All folders verified successfully" "SUCCESS"
        Write-Host ""
        Write-Host "✓ All folders verified successfully!" -ForegroundColor Green
    }
}

# STEP 7: Cleanup source (optional)
Write-Host ""
Write-Host "=== STEP 7: Cleanup Source Folders ===" -ForegroundColor Cyan
Write-Host ""

if ($AutoCleanup) {
    Write-Host "Auto-cleanup enabled. Preparing to remove source folders..." -ForegroundColor Yellow
    Write-Host ""

    foreach ($folder in $foldersToArchive) {
        if (-not (Test-Path $folder.SourcePath)) {
            continue
        }

        Write-Host "Delete source folder: $($folder.SourcePath)?" -ForegroundColor Yellow
        $confirm = Read-Host "  Type 'DELETE' to confirm"

        if ($confirm -eq "DELETE") {
            try {
                Remove-Item -Path $folder.SourcePath -Recurse -Force -ErrorAction Stop
                Write-Log "✓ Deleted: $($folder.SourcePath)" "SUCCESS"
                Write-Host "✓ Deleted" -ForegroundColor Green
            } catch {
                Write-Log "✗ Failed to delete $($folder.SourcePath): $($_.Exception.Message)" "ERROR"
                Write-Host "✗ Failed to delete" -ForegroundColor Red
            }
        } else {
            Write-Host "⊘ Skipped" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "⊘ Cleanup disabled" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Source folders preserved (manual cleanup available):" -ForegroundColor Gray
    foreach ($folder in $foldersToArchive) {
        if (Test-Path $folder.SourcePath) {
            Write-Host "  - $($folder.SourcePath)" -ForegroundColor Gray
        }
    }
}

# STEP 8: Create archive manifest
Write-Host ""
Write-Host "=== STEP 8: Creating Archive Manifest ===" -ForegroundColor Cyan
Write-Host ""

$manifest = @{
    ArchiveDate      = $ArchiveDate
    CreatedBy        = $env:USERNAME
    CreatedAt        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    NasIP            = $NasIP
    ArchivePath      = $archiveRoot
    TotalDataSize    = Format-Bytes $totalSize
    FoldersArchived  = $copyResults.Count
    VerificationDate = if (-not $SkipIntegrityCheck -and -not $DryRun) { Get-Date -Format "yyyy-MM-dd HH:mm:ss" } else { "N/A" }
    Folders          = @($copyResults)
}

$manifestJson = $manifest | ConvertTo-Json
$manifestFile = "$archiveRoot\manifest.json"

if (-not $DryRun) {
    try {
        $manifestJson | Out-File -FilePath $manifestFile -Encoding UTF8 -ErrorAction Stop
        Write-Log "✓ Manifest created: $manifestFile" "SUCCESS"
        Write-Host "✓ Archive manifest: $manifestFile" -ForegroundColor Green
    } catch {
        Write-Log "✗ Failed to create manifest: $($_.Exception.Message)" "WARNING"
    }
}

# SUMMARY
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║           Archive Operation Complete                 ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Total data: $totalFormatted" -ForegroundColor White
Write-Host "  Folders: $($foldersToArchive.Count)" -ForegroundColor White
Write-Host "  Archive root: $archiveRoot" -ForegroundColor White
Write-Host "  Log file: $logFile" -ForegroundColor White
Write-Host ""

if ($DryRun) {
    Write-Host "Mode: DRY RUN (no changes made)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To perform actual archive:" -ForegroundColor Cyan
    Write-Host "  .\archive-old-data.ps1 -Execute" -ForegroundColor White
    Write-Host ""
    Write-Host "To perform archive with auto-cleanup:" -ForegroundColor Cyan
    Write-Host "  .\archive-old-data.ps1 -Execute -AutoCleanup" -ForegroundColor White
} else {
    Write-Host "Mode: EXECUTION" -ForegroundColor Green
}

Write-Host ""
Write-Log "Archive operation completed" "INFO"
