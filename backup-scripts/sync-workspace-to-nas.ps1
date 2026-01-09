# sync-workspace-to-nas.ps1
# Synchronize D:\workspace to Baby NAS W: drive using robocopy
# Supports both mirror mode (delete extras on destination) and copy mode (preserve destination extras)

[CmdletBinding()]
param(
    [string]$SourcePath = "D:\workspace",
    [string]$DestPath = "W:\",
    [string]$NasShare = "\\10.0.0.88\workspace",
    [string]$LogPath = "D:\workspace\Baby_Nas\backup-scripts\logs",
    [switch]$Mirror,           # Use /MIR (delete files not in source) - CAREFUL!
    [switch]$DryRun,           # Show what would be copied without copying
    [switch]$Force,            # Skip confirmation prompts
    [int]$RetryCount = 3,      # Number of retries for failed copies
    [int]$RetryWait = 10       # Seconds between retries
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $LogPath "sync_$timestamp.log"

# Create log directory if missing
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] [$Level] $Message"
    Write-Host $entry -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }
        "WARN"  { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    })
    Add-Content -Path $logFile -Value $entry
}

function Test-NetworkDrive {
    param([string]$DriveLetter, [string]$Share)

    # Check if drive is mapped
    $drive = Get-PSDrive -Name $DriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
    if ($drive) {
        # Test if actually accessible
        if (Test-Path "$DriveLetter\") {
            return $true
        }
    }

    # Try to map the drive
    Write-Log "Drive $DriveLetter not accessible, attempting to map $Share..."
    try {
        # Check if share is reachable
        $sharePath = $Share
        if (Test-Path $sharePath) {
            # Map the drive using net use (more reliable for SMB)
            net use $DriveLetter $Share /persistent:no 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            if (Test-Path "$DriveLetter\") {
                Write-Log "Successfully mapped $DriveLetter to $Share" -Level "SUCCESS"
                return $true
            }
        }
    } catch {
        Write-Log "Failed to map drive: $($_.Exception.Message)" -Level "WARN"
    }

    return $false
}

try {
    Write-Log "=== Workspace Sync Started ==="
    Write-Log "Source: $SourcePath"
    Write-Log "Destination: $DestPath"
    Write-Log "Mode: $(if($Mirror){'MIRROR (deletes extras)'}else{'COPY (preserves destination)'})"
    if ($DryRun) { Write-Log "DRY RUN - No files will be modified" -Level "WARN" }

    # Preflight: Check source
    Write-Log "Preflight: Checking source path..."
    if (-not (Test-Path $SourcePath)) {
        throw "Source path does not exist: $SourcePath"
    }

    # Preflight: Check/map destination
    Write-Log "Preflight: Checking destination accessibility..."
    $driveLetter = $DestPath.Substring(0, 2)  # e.g., "W:"

    if (-not (Test-NetworkDrive -DriveLetter $driveLetter -Share $NasShare)) {
        # Try direct UNC path as fallback
        Write-Log "Trying direct UNC path..." -Level "WARN"
        if (Test-Path $NasShare) {
            $DestPath = $NasShare
            Write-Log "Using UNC path: $DestPath"
        } else {
            throw "Cannot access destination. NAS may be offline or share unavailable."
        }
    }

    # Build robocopy arguments as a single string (avoids quoting issues with Start-Process)
    $excludeDirs = @(
        "node_modules", ".git", "__pycache__", ".venv", "venv",
        ".next", "dist", "build", ".cache", "*.egg-info",
        ".idea", ".vs", "obj", "bin", "target", ".gradle"
    )
    $excludeFiles = @(
        "*.pyc", "*.pyo", "*.tmp", "*.log", "*.bak",
        "Thumbs.db", "desktop.ini", ".DS_Store"
    )

    $xdArgs = ($excludeDirs | ForEach-Object { "/XD `"$_`"" }) -join " "
    $xfArgs = ($excludeFiles | ForEach-Object { "/XF `"$_`"" }) -join " "

    # Confirm mirror mode if requested (before we start)
    if ($Mirror -and -not $Force -and -not $DryRun) {
        Write-Log "WARNING: Mirror mode will DELETE files on destination not in source!" -Level "WARN"
        $confirm = Read-Host "Continue? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Log "Sync cancelled by user" -Level "WARN"
            exit 0
        }
    }

    # Calculate source size (approximate)
    Write-Log "Calculating source size (excluding filtered directories)..."
    $sourceSize = (Get-ChildItem -Path $SourcePath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\(node_modules|\.git|__pycache__|\.venv|venv|\.next|dist|build|\.cache)\\'
        } |
        Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Log ("Source size (filtered): {0:N2} GB" -f $sourceSize)

    # Run robocopy
    Write-Log "Starting robocopy sync..."
    Write-Log "robocopy $SourcePath -> $DestPath (excludes: $($excludeDirs.Count) dirs, $($excludeFiles.Count) file patterns)"

    $startTime = Get-Date
    $exitCode = 0
    try {
        # Build arguments as an array for proper handling
        $roboArgs = @(
            $SourcePath,
            $DestPath,
            "/E", "/Z", "/R:$RetryCount", "/W:$RetryWait", "/MT:8",
            "/NP", "/NDL", "/TEE", "/LOG+:$logFile"
        )

        # Add exclusions
        foreach ($dir in $excludeDirs) {
            $roboArgs += "/XD"
            $roboArgs += $dir
        }
        foreach ($file in $excludeFiles) {
            $roboArgs += "/XF"
            $roboArgs += $file
        }

        # Add mirror or dry run flags
        if ($Mirror) {
            $roboArgs = $roboArgs | Where-Object { $_ -ne "/E" }
            $roboArgs += "/MIR"
            $roboArgs += "/XO"
        }
        if ($DryRun) {
            $roboArgs += "/L"
        }

        # Execute robocopy
        & robocopy @roboArgs
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = 16
    }
    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Interpret robocopy exit codes
    # 0 = No files copied (already in sync)
    # 1 = Files copied successfully
    # 2 = Extra files/dirs in destination (with /MIR would be deleted)
    # 3 = 1+2
    # 4 = Mismatched files/dirs
    # 8 = Some files could not be copied (errors)
    # 16 = Serious error

    switch ($exitCode) {
        0 { Write-Log "No changes - already in sync" -Level "SUCCESS" }
        1 { Write-Log "Files copied successfully" -Level "SUCCESS" }
        2 { Write-Log "Extra files in destination (not deleted without /MIR)" -Level "SUCCESS" }
        3 { Write-Log "Files copied, extras in destination" -Level "SUCCESS" }
        4 { Write-Log "Some mismatched files or directories" -Level "WARN" }
        5 { Write-Log "Files copied, some mismatches" -Level "WARN" }
        6 { Write-Log "Extras and mismatches found" -Level "WARN" }
        7 { Write-Log "Files copied, extras and mismatches" -Level "WARN" }
        { $_ -ge 8 } {
            Write-Log "Errors occurred during copy (exit code: $exitCode)" -Level "ERROR"
            if ($exitCode -ge 16) {
                throw "Serious error during robocopy (exit code: $exitCode)"
            }
        }
        default { Write-Log "Robocopy exit code: $exitCode" }
    }

    Write-Log ("Sync completed in {0:N1} minutes" -f $duration.TotalMinutes)

    # Get destination stats if accessible
    if (Test-Path $DestPath) {
        $destSize = (Get-ChildItem -Path $DestPath -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum / 1GB
        Write-Log ("Destination size: {0:N2} GB" -f $destSize)
    }

    Write-Log "=== Workspace Sync Completed ==="

} catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
} finally {
    # Clean up old sync logs (keep 30 days)
    Get-ChildItem $LogPath -Filter "sync_*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
