# restore-workspace.ps1
# Restore from Restic snapshot with safety checks

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SnapshotId = "latest",

    [string]$RepoPath = "D:\backups\workspace_restic",
    [string]$RestorePath = "D:\workspace_RESTORE",
    [switch]$OverwriteSource,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Ensure Restic is in PATH for this session
$env:Path = "C:\Tools\restic;$env:Path"

function Write-ColorLog {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

try {
    Write-ColorLog "=== Workspace Restic Restore Utility ===" -Color Cyan

    # Retrieve password from 1Password
    Write-ColorLog "`nRetrieving password from 1Password..." -Color Yellow
    try {
        $env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
        if ([string]::IsNullOrEmpty($env:RESTIC_PASSWORD)) {
            throw "Failed to retrieve password from 1Password"
        }
    } catch {
        Write-ColorLog "ERROR: Could not retrieve password from 1Password: $_" -Color Red
        exit 1
    }

    # List available snapshots
    Write-ColorLog "`nAvailable snapshots:" -Color Yellow
    & restic snapshots --repo $RepoPath --tag automated

    if ($SnapshotId -eq "latest") {
        Write-ColorLog "`nRestoring LATEST snapshot..." -Color Green
    } else {
        Write-ColorLog "`nRestoring snapshot: $SnapshotId" -Color Green
    }

    # Safety check
    if ($OverwriteSource) {
        Write-ColorLog "`nWARNING: You are about to overwrite D:\workspace!" -Color Red
        Write-ColorLog "This will replace ALL files in your workspace with the backup version." -Color Red
        $confirm = Read-Host "Type 'YES I UNDERSTAND' to confirm"
        if ($confirm -ne "YES I UNDERSTAND") {
            Write-ColorLog "Restore cancelled." -Color Yellow
            exit 0
        }
        $RestorePath = "D:\workspace"
    } else {
        Write-ColorLog "`nRestoring to safe location: $RestorePath" -Color Green
        Write-ColorLog "Review files there before manually moving to source." -Color Yellow
    }

    # Create restore directory
    if (-not (Test-Path $RestorePath)) {
        New-Item -ItemType Directory -Path $RestorePath -Force | Out-Null
    }

    # Perform restore
    $restoreArgs = @(
        "restore",
        $SnapshotId,
        "--repo", $RepoPath,
        "--target", $RestorePath
    )

    if ($DryRun) {
        Write-ColorLog "`nDRY RUN - No files will be restored" -Color Yellow
        $restoreArgs += "--dry-run"
    }

    Write-ColorLog "`nRestoring files..." -Color Cyan
    & restic @restoreArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Restore failed with exit code $LASTEXITCODE"
    }

    Write-ColorLog "`n=== Restore Completed ===" -Color Green
    Write-ColorLog "Files restored to: $RestorePath" -Color Cyan

    if (-not $OverwriteSource) {
        Write-ColorLog "`nNote: Files are in a safe location. Review and copy needed files manually." -Color Yellow
    }

} catch {
    Write-ColorLog "ERROR: $($_.Exception.Message)" -Color Red
    exit 1
}
