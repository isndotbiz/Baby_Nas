# backup-baby-nas.ps1
# Safe snapshot backup using Restic with preflight checks and logging

[CmdletBinding()]
param(
    [string]$SourcePath = "D:\workspace\baby_nas",
    [string]$RepoPath = "D:\backups\baby_nas_restic",
    [string]$LogPath = "D:\workspace\baby_nas\backup-scripts\logs",
    [int]$RetentionHours = 24,
    [int]$RetentionDays = 7,
    [int]$RetentionWeeks = 4,
    [int]$RetentionMonths = 6
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $LogPath "backup_$timestamp.log"

# Create log directory if missing
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

try {
    Write-Log "=== Restic Backup Started ==="

    # Preflight checks
    Write-Log "Preflight: Checking source path..."
    if (-not (Test-Path $SourcePath)) {
        throw "Source path does not exist: $SourcePath"
    }

    Write-Log "Preflight: Checking restic executable..."
    $resticPath = Get-Command restic.exe -ErrorAction SilentlyContinue
    if (-not $resticPath) {
        throw "restic.exe not found in PATH. Install from https://restic.net"
    }

    Write-Log "Preflight: Checking repository..."
    if (-not (Test-Path $RepoPath)) {
        throw "Repository not initialized: $RepoPath. Run 'restic init' first."
    }

    # Load password from credential manager or environment
    Write-Log "Loading repository password..."
    if ($env:RESTIC_PASSWORD) {
        Write-Log "Using password from RESTIC_PASSWORD environment variable"
    } else {
        # Try to load from Windows Credential Manager
        $cred = Get-StoredCredential -Target "ResticBabyNAS" -ErrorAction SilentlyContinue
        if ($cred) {
            $env:RESTIC_PASSWORD = $cred.GetNetworkCredential().Password
            Write-Log "Using password from Credential Manager"
        } else {
            throw "No password found. Set RESTIC_PASSWORD or store in Credential Manager."
        }
    }

    # Perform backup
    Write-Log "Creating snapshot of $SourcePath..."
    $backupArgs = @(
        "backup",
        $SourcePath,
        "--repo", $RepoPath,
        "--tag", "automated",
        "--host", $env:COMPUTERNAME,
        "--exclude", "*.tmp",
        "--exclude", "*.log",
        "--exclude", ".git",
        "--exclude", "node_modules",
        "--exclude", "__pycache__",
        "--verbose"
    )

    $output = & restic @backupArgs 2>&1
    Write-Log "Backup output: $output"

    if ($LASTEXITCODE -ne 0) {
        throw "Restic backup failed with exit code $LASTEXITCODE"
    }

    Write-Log "Snapshot created successfully"

    # Apply retention policy
    Write-Log "Applying retention policy..."
    $forgetArgs = @(
        "forget",
        "--repo", $RepoPath,
        "--keep-hourly", $RetentionHours,
        "--keep-daily", $RetentionDays,
        "--keep-weekly", $RetentionWeeks,
        "--keep-monthly", $RetentionMonths,
        "--tag", "automated",
        "--prune",
        "--verbose"
    )

    $output = & restic @forgetArgs 2>&1
    Write-Log "Retention output: $output"

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Warning: Retention policy failed with exit code $LASTEXITCODE" -Level "WARN"
    } else {
        Write-Log "Retention policy applied successfully"
    }

    # Show repository stats
    Write-Log "Checking repository statistics..."
    $statsOutput = & restic stats --repo $RepoPath --mode restore-size 2>&1
    Write-Log "Repository stats: $statsOutput"

    Write-Log "=== Backup Completed Successfully ==="

} catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
} finally {
    # Clean up old logs (keep 30 days)
    Write-Log "Cleaning old log files..."
    Get-ChildItem $LogPath -Filter "backup_*.log" |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        Remove-Item -Force
}
