#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Archive folders from D:\workspace\BABY_NAS\ to BabyNAS SMB share

.DESCRIPTION
    Copies project folders to BabyNAS using SMB/CIFS protocol
    Creates timestamped archives with progress reporting

.EXAMPLE
    .\archive-to-babynas.ps1
#>

# Configuration
$SMB_HOST = "baby.isndotbiz.com"
$SMB_SHARE = "backups"
$SMB_USER = "jdmal"
$SOURCE_PATH = "D:\workspace\BABY_NAS"
$ARCHIVE_TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HHmmss"

# Colors
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host ">>> $Text" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "[INFO] $Text" -ForegroundColor Cyan
}

function Write-Error {
    param([string]$Text)
    Write-Host "[ERROR] $Text" -ForegroundColor Red
}

Write-Header "ARCHIVE TO BABYNAS"
Write-Info "Archiving folders from D:\workspace\BABY_NAS\ to BabyNAS SMB share"
Write-Host ""

# Step 1: List folders to archive
Write-Header "STEP 1: FOLDERS TO ARCHIVE"
Write-Step "Scanning D:\workspace\BABY_NAS\ for folders..."

$folders = @(
    "Library",
    "llama-cpp-langfuse-proxy",
    "firecrawl-mdjsonl",
    "._backup_20251231_150401"
)

# Also check for cleanup_archive folders
$cleanupFolders = Get-ChildItem -Path $SOURCE_PATH -Directory -Filter "cleanup_archive_20251230_*" -ErrorAction SilentlyContinue
if ($cleanupFolders) {
    $folders += @($cleanupFolders | Select-Object -ExpandProperty Name)
}

Write-Success "Found folders to archive:"
foreach ($folder in $folders) {
    $folderPath = Join-Path $SOURCE_PATH $folder
    if (Test-Path $folderPath) {
        $size = (Get-ChildItem $folderPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
        Write-Host "  ✓ $folder ($('{0:F2}' -f $size) GB)"
    } else {
        Write-Host "  ✗ $folder (NOT FOUND)"
    }
}
Write-Host ""

# Step 2: Test SMB connection
Write-Header "STEP 2: TEST SMB CONNECTION"
Write-Step "Testing connection to \\$SMB_HOST\$SMB_SHARE..."

$UNC_PATH = "\\$SMB_HOST\$SMB_SHARE"
$testPath = Test-Path $UNC_PATH -ErrorAction SilentlyContinue

if ($testPath) {
    Write-Success "SMB share accessible: $UNC_PATH"
} else {
    Write-Info "SMB share not yet accessible. Will attempt to map drive..."
    Write-Step "Prompting for password to map SMB drive..."

    $cred = Get-Credential -UserName $SMB_USER -Message "Enter password for $SMB_USER on $SMB_HOST"

    try {
        New-PSDrive -Name "BabyNAS" -PSProvider FileSystem -Root $UNC_PATH -Credential $cred -Persist -ErrorAction Stop | Out-Null
        Write-Success "Successfully mapped SMB share as BabyNAS:"
        $testPath = Test-Path "BabyNAS:\" -ErrorAction SilentlyContinue
        if ($testPath) {
            Write-Success "Drive mapping verified"
        }
    } catch {
        Write-Error "Failed to map SMB drive: $_"
        exit 1
    }
}
Write-Host ""

# Step 3: Create archive directory
Write-Header "STEP 3: CREATE ARCHIVE DIRECTORY"
$ARCHIVE_DIR = Join-Path $UNC_PATH "ARCHIVE_$ARCHIVE_TIMESTAMP"
Write-Step "Creating archive directory: ARCHIVE_$ARCHIVE_TIMESTAMP..."

try {
    New-Item -ItemType Directory -Path $ARCHIVE_DIR -Force -ErrorAction Stop | Out-Null
    Write-Success "Archive directory created: $ARCHIVE_DIR"
} catch {
    Write-Error "Failed to create archive directory: $_"
    exit 1
}
Write-Host ""

# Step 4: Archive folders
Write-Header "STEP 4: ARCHIVING FOLDERS"
$successCount = 0
$failureCount = 0

foreach ($folder in $folders) {
    $folderPath = Join-Path $SOURCE_PATH $folder

    if (-not (Test-Path $folderPath)) {
        Write-Info "Skipping (not found): $folder"
        $failureCount++
        continue
    }

    Write-Step "Archiving: $folder..."

    try {
        # Get folder size
        $size = (Get-ChildItem $folderPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
        Write-Info "  Size: $('{0:F2}' -f $size) GB"

        # Copy with progress
        $destPath = Join-Path $ARCHIVE_DIR $folder
        Copy-Item -Path $folderPath -Destination $destPath -Recurse -Force -ErrorAction Stop

        Write-Success "  Completed: $folder"
        $successCount++
    } catch {
        Write-Error "  Failed to archive $folder : $_"
        $failureCount++
    }

    Write-Host ""
}

# Step 5: Verify archive
Write-Header "STEP 5: VERIFY ARCHIVE"
Write-Step "Verifying archived folders..."

$archivedItems = Get-ChildItem -Path $ARCHIVE_DIR -ErrorAction SilentlyContinue
$totalSize = (Get-ChildItem $ARCHIVE_DIR -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB

Write-Success "Archive Contents:"
Write-Host "  Location: $ARCHIVE_DIR"
Write-Host "  Items: $($archivedItems.Count)"
Write-Host "  Total Size: $('{0:F2}' -f $totalSize) GB"
Write-Host ""

foreach ($item in $archivedItems) {
    Write-Host "  ✓ $($item.Name)"
}
Write-Host ""

# Step 6: Summary
Write-Header "ARCHIVE COMPLETE"
Write-Success "Successfully archived $successCount folders"
if ($failureCount -gt 0) {
    Write-Error "Failed to archive $failureCount folders"
}

Write-Host ""
Write-Info "Archive Details:"
Write-Host "  Source: $SOURCE_PATH"
Write-Host "  Destination: $UNC_PATH"
Write-Host "  Archive Dir: ARCHIVE_$ARCHIVE_TIMESTAMP"
Write-Host "  Total Size: $('{0:F2}' -f $totalSize) GB"
Write-Host "  Created: $(Get-Date)"
Write-Host ""

Write-Header "NEXT STEPS"
Write-Info "1. Verify archive on BabyNAS:"
Write-Host "   \\$SMB_HOST\$SMB_SHARE\ARCHIVE_$ARCHIVE_TIMESTAMP"
Write-Host ""
Write-Info "2. Check BabyNAS backup snapshots:"
Write-Host "   Web UI: http://192.168.215.2"
Write-Host ""
Write-Info "3. Monitor replication to Main NAS:"
Write-Host "   python vaultwarden-credential-manager.py get 'ZFS-Replication'"
Write-Host ""

Write-Host "Archive operation finished at $(Get-Date)" -ForegroundColor Green
