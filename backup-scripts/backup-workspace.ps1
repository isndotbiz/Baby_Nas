# backup-workspace.ps1
# Safe snapshot backup of D:\workspace using Restic with preflight checks and logging

[CmdletBinding()]
param(
    [string]$SourcePath = "D:\workspace",
    [string]$RepoPath = "D:\backups\workspace_restic",
    [string]$LogPath = "D:\workspace\Baby_Nas\backup-scripts\logs",
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
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

try {
    Write-Log "=== Workspace Restic Backup Started ==="
    Write-Log "Source: $SourcePath"
    Write-Log "Repository: $RepoPath"

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
        $cred = Get-StoredCredential -Target "ResticWorkspace" -ErrorAction SilentlyContinue
        if ($cred) {
            $env:RESTIC_PASSWORD = $cred.GetNetworkCredential().Password
            Write-Log "Using password from Credential Manager"
        } else {
            throw "No password found. Set RESTIC_PASSWORD or store in Credential Manager."
        }
    }

    # Perform backup with comprehensive exclusions for a full workspace
    Write-Log "Creating snapshot of $SourcePath..."

    # Build exclusion list for development workspace
    $excludePatterns = @(
        # Version control (already versioned elsewhere)
        ".git",
        ".svn",
        ".hg",

        # Node.js / JavaScript
        "node_modules",
        ".npm",
        ".yarn",
        ".pnpm-store",
        "bower_components",

        # Python
        "__pycache__",
        "*.pyc",
        "*.pyo",
        "*.pyd",
        ".Python",
        ".venv",
        "venv",
        ".virtualenv",
        "virtualenv",
        "env",
        ".env.local",
        ".tox",
        ".pytest_cache",
        ".mypy_cache",
        "*.egg-info",
        ".eggs",

        # Rust
        "target",

        # Go
        "vendor",

        # .NET / C#
        "bin",
        "obj",
        "packages",
        ".nuget",

        # Java / Kotlin
        ".gradle",
        ".m2",
        "build",

        # IDE and editor files
        ".idea",
        ".vscode/settings.json",
        ".vs",
        "*.suo",
        "*.user",
        "*.userosscache",
        "*.sln.docstates",
        ".project",
        ".classpath",
        ".settings",

        # Temporary and cache files
        "*.tmp",
        "*.temp",
        "*.swp",
        "*.swo",
        "*~",
        ".cache",
        ".parcel-cache",
        ".next",
        ".nuxt",
        ".turbo",

        # Build outputs (generic)
        "dist",
        "out",
        "*.dll",
        "*.exe",
        "*.o",
        "*.so",
        "*.dylib",

        # Log files (we have our own logging)
        "*.log",
        "logs",
        "npm-debug.log*",
        "yarn-debug.log*",
        "yarn-error.log*",

        # OS generated files
        "Thumbs.db",
        "ehthumbs.db",
        "Desktop.ini",
        ".DS_Store",
        ".AppleDouble",
        ".LSOverride",

        # Large binary/media files that shouldn't be versioned
        "*.iso",
        "*.dmg",
        "*.pkg",
        "*.msi",
        "*.deb",
        "*.rpm",

        # Container and VM files
        "*.vhdx",
        "*.vmdk",
        "*.vdi",
        "*.ova",
        "*.ovf",

        # Model files (large AI models - archive separately)
        "*.gguf",
        "*.safetensors",
        "*.bin",
        "*.onnx",
        "*.pt",
        "*.pth",
        "*.ckpt",

        # Coverage and test outputs
        "coverage",
        ".coverage",
        "htmlcov",
        ".nyc_output",

        # Secrets and credentials (should be in 1Password, not backed up)
        ".env",
        "*.pem",
        "*.key",
        "credentials.json",
        "secrets.json"
    )

    $backupArgs = @(
        "backup",
        $SourcePath,
        "--repo", $RepoPath,
        "--tag", "automated",
        "--tag", "workspace",
        "--host", $env:COMPUTERNAME,
        "--ignore-inode",
        "--verbose"
    )

    # Add all exclusion patterns
    foreach ($pattern in $excludePatterns) {
        $backupArgs += "--exclude"
        $backupArgs += $pattern
    }

    # Run backup - capture stderr separately to avoid PowerShell treating warnings as errors
    $backupProcess = Start-Process -FilePath "restic" -ArgumentList $backupArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$LogPath\restic_stdout.tmp" -RedirectStandardError "$LogPath\restic_stderr.tmp"

    $stdoutContent = if (Test-Path "$LogPath\restic_stdout.tmp") { Get-Content "$LogPath\restic_stdout.tmp" -Raw } else { "" }
    $stderrContent = if (Test-Path "$LogPath\restic_stderr.tmp") { Get-Content "$LogPath\restic_stderr.tmp" -Raw } else { "" }

    # Clean up temp files
    Remove-Item "$LogPath\restic_stdout.tmp" -Force -ErrorAction SilentlyContinue
    Remove-Item "$LogPath\restic_stderr.tmp" -Force -ErrorAction SilentlyContinue

    # Log output
    if ($stdoutContent) { Write-Log "Backup stdout: $stdoutContent" }
    if ($stderrContent) { Write-Log "Backup stderr (may include warnings): $stderrContent" }

    if ($backupProcess.ExitCode -ne 0) {
        throw "Restic backup failed with exit code $($backupProcess.ExitCode)"
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

    # Run retention - capture stderr separately
    $forgetProcess = Start-Process -FilePath "restic" -ArgumentList $forgetArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$LogPath\restic_stdout.tmp" -RedirectStandardError "$LogPath\restic_stderr.tmp"

    $stdoutContent = if (Test-Path "$LogPath\restic_stdout.tmp") { Get-Content "$LogPath\restic_stdout.tmp" -Raw } else { "" }
    $stderrContent = if (Test-Path "$LogPath\restic_stderr.tmp") { Get-Content "$LogPath\restic_stderr.tmp" -Raw } else { "" }

    Remove-Item "$LogPath\restic_stdout.tmp" -Force -ErrorAction SilentlyContinue
    Remove-Item "$LogPath\restic_stderr.tmp" -Force -ErrorAction SilentlyContinue

    if ($stdoutContent) { Write-Log "Retention stdout: $stdoutContent" }
    if ($stderrContent) { Write-Log "Retention stderr: $stderrContent" }

    if ($forgetProcess.ExitCode -ne 0) {
        Write-Log "Warning: Retention policy failed with exit code $($forgetProcess.ExitCode)" -Level "WARN"
    } else {
        Write-Log "Retention policy applied successfully"
    }

    # Show repository stats
    Write-Log "Checking repository statistics..."
    $statsArgs = @("stats", "--repo", $RepoPath, "--mode", "restore-size")
    $statsProcess = Start-Process -FilePath "restic" -ArgumentList $statsArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$LogPath\restic_stdout.tmp" -RedirectStandardError "$LogPath\restic_stderr.tmp"

    $statsOutput = if (Test-Path "$LogPath\restic_stdout.tmp") { Get-Content "$LogPath\restic_stdout.tmp" -Raw } else { "" }
    Remove-Item "$LogPath\restic_stdout.tmp" -Force -ErrorAction SilentlyContinue
    Remove-Item "$LogPath\restic_stderr.tmp" -Force -ErrorAction SilentlyContinue

    Write-Log "Repository stats: $statsOutput"

    Write-Log "=== Workspace Backup Completed Successfully ==="

} catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
} finally {
    # Clean up old logs (keep 30 days)
    Write-Log "Cleaning old log files..."
    Get-ChildItem $LogPath -Filter "backup_*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
