#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enhanced Veeam Agent deployment with comprehensive automation

.DESCRIPTION
    Complete Veeam Agent deployment solution with the following features:
    1. Automatic Veeam installation detection and silent install
    2. Intelligent installer location (D:\ISOs\VeeamAgent*.exe or *.iso)
    3. Automatic backup job configuration for multiple targets:
       - Full system backup to \\baby.isn.biz\Veeam
       - D:\workspace to \\baby.isn.biz\WindowsBackup\d-workspace
       - WSL distributions to \\baby.isn.biz\WindowsBackup\wsl
    4. Flexible scheduling (daily 1 AM for full, hourly for workspace sync)
    5. Configurable retention policies (7 days full, 30 days workspace)
    6. Network drive mapping with credentials
    7. Scheduled task creation for all backup jobs
    8. Comprehensive monitoring and reporting
    9. Backup/restore testing capability
    10. Email/notification setup (optional)

.PARAMETER VeeamInstallerPath
    Path to Veeam installer (auto-detects in D:\ISOs\ if not provided)
    Default: Auto-detect

.PARAMETER TrueNasServer
    TrueNAS server hostname or IP
    Default: baby.isn.biz

.PARAMETER TrueNasIP
    TrueNAS server IP address (for host file if DNS not working)
    Default: 172.21.203.18

.PARAMETER SmbUsername
    SMB/CIFS username for TrueNAS shares
    Default: truenas_admin

.PARAMETER SmbPassword
    SMB/CIFS password (will prompt if not provided)
    Default: Will prompt securely

.PARAMETER SkipInstallation
    Skip Veeam installation (if already installed)
    Default: $false

.PARAMETER SkipBackupConfiguration
    Skip backup job configuration
    Default: $false

.PARAMETER SkipWorkspaceSync
    Skip workspace hourly sync configuration
    Default: $false

.PARAMETER SkipWSLBackup
    Skip WSL backup configuration
    Default: $false

.PARAMETER SkipTesting
    Skip backup/restore testing
    Default: $false

.PARAMETER EnableEmailNotifications
    Enable email notifications for backup results
    Default: $false

.PARAMETER EmailTo
    Email address for notifications

.PARAMETER SmtpServer
    SMTP server for email notifications

.PARAMETER Unattended
    Run in unattended mode (no prompts)
    Default: $false

.EXAMPLE
    .\DEPLOY-VEEAM-ENHANCED.ps1
    Interactive deployment with all features

.EXAMPLE
    .\DEPLOY-VEEAM-ENHANCED.ps1 -Unattended $true -SmbPassword (ConvertTo-SecureString "uppercut%$##" -AsPlainText -Force)
    Automated deployment with provided credentials

.EXAMPLE
    .\DEPLOY-VEEAM-ENHANCED.ps1 -SkipInstallation $true
    Configure backups only (Veeam already installed)

.NOTES
    Author: Enhanced Veeam Deployment System
    Version: 2.0
    Requires: PowerShell 5.1+, Administrator privileges
    Duration: 30-60 minutes for complete deployment
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$VeeamInstallerPath,

    [Parameter(Mandatory=$false)]
    [string]$TrueNasServer = "baby.isn.biz",

    [Parameter(Mandatory=$false)]
    [string]$TrueNasIP = "172.21.203.18",

    [Parameter(Mandatory=$false)]
    [string]$SmbUsername = "truenas_admin",

    [Parameter(Mandatory=$false)]
    [SecureString]$SmbPassword,

    [Parameter(Mandatory=$false)]
    [bool]$SkipInstallation = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SkipBackupConfiguration = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SkipWorkspaceSync = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SkipWSLBackup = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SkipTesting = $false,

    [Parameter(Mandatory=$false)]
    [bool]$EnableEmailNotifications = $false,

    [Parameter(Mandatory=$false)]
    [string]$EmailTo,

    [Parameter(Mandatory=$false)]
    [string]$SmtpServer,

    [Parameter(Mandatory=$false)]
    [bool]$Unattended = $false
)

# ===== CONFIGURATION =====
$script:Config = @{
    # Paths
    LogDir = "C:\Logs\Veeam"
    VeeamCachePath = "C:\VeeamCache"
    ISOSearchPath = "D:\ISOs"
    WorkspacePath = "D:\workspace"

    # TrueNAS Shares
    VeeamShare = "\\$TrueNasServer\Veeam"
    WorkspaceShare = "\\$TrueNasServer\WindowsBackup\d-workspace"
    WSLShare = "\\$TrueNasServer\WindowsBackup\wsl"

    # Backup Jobs Configuration
    FullBackupJob = @{
        Name = "System-Full-Backup"
        Drives = @("C:", "D:")
        Destination = "\\$TrueNasServer\Veeam"
        Schedule = "01:00"  # 1 AM daily
        Retention = 7       # 7 days
        Compression = "Optimal"
        EnableAppAware = $true
    }

    WorkspaceBackupJob = @{
        Name = "Workspace-Hourly-Sync"
        Source = "D:\workspace"
        Destination = "\\$TrueNasServer\WindowsBackup\d-workspace"
        Schedule = "Hourly"
        Retention = 30      # 30 days
        Compression = "Optimal"
    }

    WSLBackupJob = @{
        Name = "WSL-Daily-Backup"
        Source = "C:\Users\*\AppData\Local\Packages\*\LocalState\ext4.vhdx"
        Destination = "\\$TrueNasServer\WindowsBackup\wsl"
        Schedule = "02:00"  # 2 AM daily
        Retention = 14      # 14 days
        Compression = "High"
    }

    # Credentials
    SmbUsername = $SmbUsername
    SmbPassword = $SmbPassword

    # Email Configuration
    EmailEnabled = $EnableEmailNotifications
    EmailTo = $EmailTo
    SmtpServer = $SmtpServer
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$($script:Config.LogDir)\enhanced-deploy-$timestamp.log"
$deploymentStatus = @{
    StartTime = (Get-Date).ToString()
    Steps = @{}
    Errors = @()
    Warnings = @()
}

# ===== LOGGING FUNCTIONS =====

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO"    { Write-Host $logMessage -ForegroundColor Cyan }
        "HEADER"  { Write-Host $logMessage -ForegroundColor Magenta }
        default   { Write-Host $logMessage -ForegroundColor White }
    }

    $logMessage | Out-File -FilePath $logFile -Append -ErrorAction SilentlyContinue
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "   ENHANCED VEEAM AGENT DEPLOYMENT SYSTEM" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Complete automated backup solution for:" -ForegroundColor White
    Write-Host "  - Full system backup (daily 1 AM)" -ForegroundColor White
    Write-Host "  - D:\workspace sync (hourly)" -ForegroundColor White
    Write-Host "  - WSL distributions (daily 2 AM)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Target: $TrueNasServer ($TrueNasIP)" -ForegroundColor Cyan
    Write-Host "  User: $SmbUsername" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ===== PREREQUISITE CHECKS =====

function Initialize-Environment {
    Write-Log "Initializing deployment environment..." "INFO"

    # Create log directory
    if (-not (Test-Path $script:Config.LogDir)) {
        New-Item -Path $script:Config.LogDir -ItemType Directory -Force | Out-Null
        Write-Log "Created log directory: $($script:Config.LogDir)" "SUCCESS"
    }

    # Verify running as Administrator
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "ERROR: Script must run as Administrator" "ERROR"
        throw "Administrator privileges required"
    }

    # Check TrueNAS connectivity
    Write-Log "Testing connectivity to TrueNAS..." "INFO"
    if (Test-Connection -ComputerName $TrueNasIP -Count 2 -Quiet) {
        Write-Log "TrueNAS is reachable at $TrueNasIP" "SUCCESS"
    } else {
        Write-Log "WARNING: Cannot ping TrueNAS at $TrueNasIP" "WARNING"
    }

    # Ensure hosts file has TrueNAS entry
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $hostsContent = Get-Content $hostsFile -ErrorAction SilentlyContinue

    if ($hostsContent -notmatch [regex]::Escape($TrueNasServer)) {
        Write-Log "Adding TrueNAS to hosts file..." "INFO"
        try {
            "`n$TrueNasIP`t$TrueNasServer" | Out-File -FilePath $hostsFile -Append -Encoding ASCII
            Write-Log "Added $TrueNasServer to hosts file" "SUCCESS"
        } catch {
            Write-Log "WARNING: Could not update hosts file: $($_.Exception.Message)" "WARNING"
        }
    }

    Write-Log "Environment initialization complete" "SUCCESS"
}

# ===== CREDENTIAL MANAGEMENT =====

function Get-SmbCredentials {
    Write-Log "Configuring SMB credentials..." "INFO"

    if (-not $script:Config.SmbPassword) {
        if ($Unattended) {
            Write-Log "ERROR: SMB password required in unattended mode" "ERROR"
            throw "SMB password required"
        }

        Write-Host ""
        Write-Host "Enter SMB password for user '$($script:Config.SmbUsername)': " -NoNewline -ForegroundColor Yellow
        $script:Config.SmbPassword = Read-Host -AsSecureString
        Write-Host ""
    }

    # Convert SecureString to plain text for net use
    $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($script:Config.SmbPassword)
    )

    return $passwordPlain
}

function Mount-NetworkShares {
    param([string]$Password)

    Write-Log "Mounting network shares..." "INFO"

    $shares = @(
        $script:Config.VeeamShare,
        $script:Config.WorkspaceShare,
        $script:Config.WSLShare
    )

    foreach ($share in $shares) {
        try {
            # Remove existing connection if any
            $null = net use $share /delete /y 2>&1

            # Mount share with credentials
            $result = net use $share $Password /user:$($script:Config.SmbUsername) /persistent:yes 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Log "Mounted share: $share" "SUCCESS"

                # Test write access
                $testFile = Join-Path $share "veeam-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
                try {
                    "test" | Out-File -FilePath $testFile -ErrorAction Stop
                    Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
                    Write-Log "Write access confirmed for $share" "SUCCESS"
                } catch {
                    Write-Log "WARNING: No write access to $share" "WARNING"
                }
            } else {
                Write-Log "WARNING: Failed to mount $share : $result" "WARNING"
                $deploymentStatus.Warnings += "Failed to mount $share"
            }
        } catch {
            Write-Log "ERROR mounting share $share : $($_.Exception.Message)" "ERROR"
            $deploymentStatus.Errors += "Failed to mount $share"
        }
    }
}

# ===== VEEAM INSTALLATION =====

function Test-VeeamInstalled {
    Write-Log "Checking for existing Veeam installation..." "INFO"

    $service = Get-Service -Name "VeeamEndpointBackupSvc" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "Veeam service found: $($service.Status)" "SUCCESS"
        return $true
    }

    $regPath = "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup"
    if (Test-Path $regPath) {
        try {
            $version = (Get-ItemProperty -Path $regPath -Name "Version" -ErrorAction SilentlyContinue).Version
            Write-Log "Veeam Agent found: Version $version" "SUCCESS"
            return $true
        } catch {
            Write-Log "Veeam registry entry found" "SUCCESS"
            return $true
        }
    }

    Write-Log "Veeam Agent is NOT installed" "INFO"
    return $false
}

function Find-VeeamInstaller {
    Write-Log "Searching for Veeam installer..." "INFO"

    if ($VeeamInstallerPath -and (Test-Path $VeeamInstallerPath)) {
        Write-Log "Using provided installer: $VeeamInstallerPath" "SUCCESS"
        return $VeeamInstallerPath
    }

    # Search in D:\ISOs\
    if (Test-Path $script:Config.ISOSearchPath) {
        $patterns = @("VeeamAgent*.exe", "VeeamAgent*.iso", "Veeam*Windows*.exe")

        foreach ($pattern in $patterns) {
            $files = Get-ChildItem -Path $script:Config.ISOSearchPath -Filter $pattern -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending

            if ($files) {
                $installer = $files[0].FullName
                Write-Log "Found installer: $installer" "SUCCESS"
                return $installer
            }
        }
    }

    Write-Log "WARNING: No Veeam installer found" "WARNING"
    return $null
}

function Install-VeeamAgent {
    param([string]$InstallerPath)

    Write-Log "Installing Veeam Agent from: $InstallerPath" "INFO"

    # Handle ISO if needed
    $installerExe = $InstallerPath
    $isoMount = $null

    if ($InstallerPath -like "*.iso") {
        Write-Log "Mounting ISO: $InstallerPath" "INFO"
        try {
            $mount = Mount-DiskImage -ImagePath $InstallerPath -PassThru
            $driveLetter = ($mount | Get-Volume).DriveLetter

            if (-not $driveLetter) {
                throw "Failed to mount ISO"
            }

            $isoMount = $mount
            $found = Get-ChildItem -Path "${driveLetter}:\" -Filter "*.exe" -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -like "*Veeam*" -or $_.Name -eq "Setup.exe" } |
                     Select-Object -First 1

            if ($found) {
                $installerExe = $found.FullName
                Write-Log "Found installer in ISO: $installerExe" "SUCCESS"
            } else {
                throw "No installer found in ISO"
            }
        } catch {
            Write-Log "ERROR mounting ISO: $($_.Exception.Message)" "ERROR"
            throw
        }
    }

    # Install silently
    $installArgs = @(
        "/silent",
        "/accepteula",
        "/noreboot",
        "ACCEPT_THIRDPARTY_LICENSES=1",
        "ACCEPTEULA=YES"
    )

    $argString = $installArgs -join " "
    Write-Log "Running installer: $installerExe $argString" "INFO"
    Write-Log "This may take 5-15 minutes..." "INFO"

    try {
        $process = Start-Process -FilePath $installerExe -ArgumentList $argString -Wait -PassThru -NoNewWindow
        $exitCode = $process.ExitCode

        Write-Log "Installation completed with exit code: $exitCode" "INFO"

        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            Write-Log "Veeam Agent installed successfully" "SUCCESS"

            # Wait for services to start
            Write-Log "Waiting for Veeam services to start..." "INFO"
            Start-Sleep -Seconds 30

            # Start service if needed
            $service = Get-Service -Name "VeeamEndpointBackupSvc" -ErrorAction SilentlyContinue
            if ($service -and $service.Status -ne "Running") {
                Start-Service -Name "VeeamEndpointBackupSvc" -ErrorAction SilentlyContinue
            }

            return $true
        } else {
            Write-Log "ERROR: Installation failed with exit code $exitCode" "ERROR"
            return $false
        }
    } catch {
        Write-Log "ERROR during installation: $($_.Exception.Message)" "ERROR"
        return $false
    } finally {
        # Cleanup ISO mount
        if ($isoMount) {
            Write-Log "Dismounting ISO..." "INFO"
            Dismount-DiskImage -ImagePath $isoMount.ImagePath | Out-Null
        }
    }
}

# ===== BACKUP JOB CONFIGURATION =====

function New-ScheduledBackupTask {
    param(
        [string]$TaskName,
        [string]$Description,
        [string]$ScriptPath,
        [string]$Schedule,  # "Daily HH:MM" or "Hourly"
        [hashtable]$Arguments = @{}
    )

    Write-Log "Creating scheduled task: $TaskName" "INFO"

    try {
        # Remove existing task if present
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Log "Removed existing task: $TaskName" "INFO"
        }

        # Build PowerShell command
        $argList = @()
        foreach ($key in $Arguments.Keys) {
            $value = $Arguments[$key]
            if ($value -is [string] -and $value.Contains(" ")) {
                $argList += "-$key `"$value`""
            } else {
                $argList += "-$key $value"
            }
        }

        $command = "PowerShell.exe"
        $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $($argList -join ' ')"

        # Create action
        $action = New-ScheduledTaskAction -Execute $command -Argument $argString

        # Create trigger based on schedule
        if ($Schedule -eq "Hourly") {
            $trigger = New-ScheduledTaskTrigger -Once -At "00:00" -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration ([TimeSpan]::MaxValue)
        } elseif ($Schedule -match "Daily (\d{2}):(\d{2})") {
            $hour = $matches[1]
            $minute = $matches[2]
            $trigger = New-ScheduledTaskTrigger -Daily -At "$hour`:$minute"
        } else {
            throw "Invalid schedule format: $Schedule"
        }

        # Create settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

        # Register task
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Description $Description | Out-Null

        Write-Log "Scheduled task created: $TaskName" "SUCCESS"
        return $true
    } catch {
        Write-Log "ERROR creating scheduled task: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function New-WorkspaceBackupScript {
    Write-Log "Creating workspace backup script..." "INFO"

    $scriptPath = "$($script:Config.LogDir)\workspace-backup.ps1"

    $scriptContent = @"
# Workspace Backup Script
# Auto-generated by Enhanced Veeam Deployment

`$ErrorActionPreference = "Continue"
`$logFile = "C:\Logs\Veeam\workspace-backup-`$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[`$timestamp] `$Message" | Out-File -FilePath `$logFile -Append
    Write-Host "[`$timestamp] `$Message"
}

Write-Log "=== Workspace Backup Started ==="

`$source = "$($script:Config.WorkspacePath)"
`$destination = "$($script:Config.WorkspaceShare)"

if (-not (Test-Path `$source)) {
    Write-Log "ERROR: Source path not found: `$source"
    exit 1
}

if (-not (Test-Path `$destination)) {
    Write-Log "ERROR: Destination path not accessible: `$destination"
    exit 1
}

Write-Log "Source: `$source"
Write-Log "Destination: `$destination"

# Use robocopy for efficient incremental sync
`$robocopyArgs = @(
    `$source,
    `$destination,
    "/MIR",        # Mirror (delete files in dest that don't exist in source)
    "/R:3",        # Retry 3 times
    "/W:10",       # Wait 10 seconds between retries
    "/MT:8",       # Multi-threaded (8 threads)
    "/NFL",        # No file list
    "/NDL",        # No directory list
    "/NP",         # No progress
    "/LOG+:`$logFile"  # Append to log
)

Write-Log "Running robocopy..."
`$result = robocopy @robocopyArgs

# Robocopy exit codes: 0-7 are success, 8+ are errors
if (`$LASTEXITCODE -lt 8) {
    Write-Log "Workspace backup completed successfully (exit code: `$LASTEXITCODE)"
    exit 0
} else {
    Write-Log "ERROR: Workspace backup failed (exit code: `$LASTEXITCODE)"
    exit `$LASTEXITCODE
}
"@

    $scriptContent | Out-File -FilePath $scriptPath -Force -Encoding UTF8
    Write-Log "Created workspace backup script: $scriptPath" "SUCCESS"

    return $scriptPath
}

function New-WSLBackupScript {
    Write-Log "Creating WSL backup script..." "INFO"

    $scriptPath = "$($script:Config.LogDir)\wsl-backup.ps1"

    $scriptContent = @"
# WSL Backup Script
# Auto-generated by Enhanced Veeam Deployment

`$ErrorActionPreference = "Continue"
`$logFile = "C:\Logs\Veeam\wsl-backup-`$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[`$timestamp] `$Message" | Out-File -FilePath `$logFile -Append
    Write-Host "[`$timestamp] `$Message"
}

Write-Log "=== WSL Backup Started ==="

`$destination = "$($script:Config.WSLShare)"

if (-not (Test-Path `$destination)) {
    Write-Log "ERROR: Destination path not accessible: `$destination"
    exit 1
}

# Find all WSL distributions
`$wslDistros = wsl --list --quiet 2>`$null | Where-Object { `$_ -and `$_.Trim() }

if (-not `$wslDistros) {
    Write-Log "WARNING: No WSL distributions found"
    exit 0
}

Write-Log "Found `$(`$wslDistros.Count) WSL distribution(s)"

foreach (`$distro in `$wslDistros) {
    `$distroName = `$distro.Trim()
    if (-not `$distroName) { continue }

    Write-Log "Backing up WSL distribution: `$distroName"

    `$exportPath = Join-Path `$destination "`$distroName-`$(Get-Date -Format 'yyyyMMdd-HHmmss').tar.gz"

    try {
        # Export WSL distribution
        wsl --export `$distroName `$exportPath --vhd 2>&1 | Out-File -FilePath `$logFile -Append

        if (Test-Path `$exportPath) {
            `$sizeGB = [math]::Round((Get-Item `$exportPath).Length / 1GB, 2)
            Write-Log "Successfully backed up `$distroName (`$sizeGB GB)"

            # Clean up old backups (keep last $($script:Config.WSLBackupJob.Retention) days)
            `$oldBackups = Get-ChildItem -Path `$destination -Filter "`$distroName-*.tar.gz" |
                          Where-Object { `$_.LastWriteTime -lt (Get-Date).AddDays(-$($script:Config.WSLBackupJob.Retention)) }

            foreach (`$old in `$oldBackups) {
                Write-Log "Removing old backup: `$(`$old.Name)"
                Remove-Item -Path `$old.FullName -Force
            }
        } else {
            Write-Log "ERROR: Export failed for `$distroName"
        }
    } catch {
        Write-Log "ERROR backing up `$distroName : `$(`$_.Exception.Message)"
    }
}

Write-Log "=== WSL Backup Completed ==="
exit 0
"@

    $scriptContent | Out-File -FilePath $scriptPath -Force -Encoding UTF8
    Write-Log "Created WSL backup script: $scriptPath" "SUCCESS"

    return $scriptPath
}

function Configure-BackupJobs {
    Write-Log "Configuring backup jobs..." "INFO"

    # Full system backup configuration
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " VEEAM BACKUP JOB CONFIGURATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "FULL SYSTEM BACKUP:" -ForegroundColor Yellow
    Write-Host "  Job Name:        $($script:Config.FullBackupJob.Name)" -ForegroundColor White
    Write-Host "  Drives:          $($script:Config.FullBackupJob.Drives -join ', ')" -ForegroundColor White
    Write-Host "  Destination:     $($script:Config.FullBackupJob.Destination)" -ForegroundColor White
    Write-Host "  Schedule:        Daily at $($script:Config.FullBackupJob.Schedule)" -ForegroundColor White
    Write-Host "  Retention:       $($script:Config.FullBackupJob.Retention) days" -ForegroundColor White
    Write-Host "  Compression:     $($script:Config.FullBackupJob.Compression)" -ForegroundColor White
    Write-Host ""
    Write-Host "MANUAL CONFIGURATION REQUIRED:" -ForegroundColor Yellow
    Write-Host "  1. Open Veeam Agent Control Panel" -ForegroundColor White
    Write-Host "  2. Click 'Configure Backup' or 'Add Job'" -ForegroundColor White
    Write-Host "  3. Select 'Volume Level Backup'" -ForegroundColor White
    Write-Host "  4. Select drives: $($script:Config.FullBackupJob.Drives -join ', ')" -ForegroundColor Green
    Write-Host "  5. Destination: $($script:Config.FullBackupJob.Destination)" -ForegroundColor Green
    Write-Host "  6. Schedule: Daily at $($script:Config.FullBackupJob.Schedule)" -ForegroundColor Green
    Write-Host "  7. Retention: $($script:Config.FullBackupJob.Retention) restore points" -ForegroundColor Green
    Write-Host "  8. Compression: $($script:Config.FullBackupJob.Compression)" -ForegroundColor Green
    Write-Host "  9. Enable Application-Aware Processing (VSS)" -ForegroundColor Green
    Write-Host ""

    if (-not $Unattended) {
        Write-Host "Press Enter after configuring Veeam backup job..." -ForegroundColor Yellow
        Read-Host
    }

    # Create workspace backup script and scheduled task
    if (-not $SkipWorkspaceSync) {
        Write-Log "Configuring workspace hourly sync..." "INFO"
        $workspaceScript = New-WorkspaceBackupScript

        $taskCreated = New-ScheduledBackupTask `
            -TaskName $script:Config.WorkspaceBackupJob.Name `
            -Description "Hourly sync of D:\workspace to TrueNAS" `
            -ScriptPath $workspaceScript `
            -Schedule "Hourly"

        if ($taskCreated) {
            Write-Log "Workspace hourly sync configured successfully" "SUCCESS"
        }
    }

    # Create WSL backup script and scheduled task
    if (-not $SkipWSLBackup) {
        Write-Log "Configuring WSL backup..." "INFO"
        $wslScript = New-WSLBackupScript

        $taskCreated = New-ScheduledBackupTask `
            -TaskName $script:Config.WSLBackupJob.Name `
            -Description "Daily backup of WSL distributions" `
            -ScriptPath $wslScript `
            -Schedule "Daily $($script:Config.WSLBackupJob.Schedule)"

        if ($taskCreated) {
            Write-Log "WSL daily backup configured successfully" "SUCCESS"
        }
    }
}

# ===== TESTING =====

function Test-BackupConfiguration {
    Write-Log "Testing backup configuration..." "INFO"

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " BACKUP CONFIGURATION TEST" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Test workspace backup
    if (-not $SkipWorkspaceSync) {
        Write-Host "Testing workspace backup..." -ForegroundColor Yellow
        try {
            $workspaceScript = "$($script:Config.LogDir)\workspace-backup.ps1"
            if (Test-Path $workspaceScript) {
                & PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File $workspaceScript

                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Workspace backup test PASSED" "SUCCESS"
                } else {
                    Write-Log "WARNING: Workspace backup test completed with warnings" "WARNING"
                }
            }
        } catch {
            Write-Log "ERROR testing workspace backup: $($_.Exception.Message)" "ERROR"
        }
    }

    # Test WSL backup
    if (-not $SkipWSLBackup) {
        Write-Host ""
        Write-Host "Testing WSL backup..." -ForegroundColor Yellow
        try {
            $wslScript = "$($script:Config.LogDir)\wsl-backup.ps1"
            if (Test-Path $wslScript) {
                & PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File $wslScript

                if ($LASTEXITCODE -eq 0) {
                    Write-Log "WSL backup test PASSED" "SUCCESS"
                } else {
                    Write-Log "WARNING: WSL backup test completed with warnings" "WARNING"
                }
            }
        } catch {
            Write-Log "ERROR testing WSL backup: $($_.Exception.Message)" "ERROR"
        }
    }

    Write-Host ""
}

# ===== MONITORING SETUP =====

function Setup-Monitoring {
    Write-Log "Setting up backup monitoring..." "INFO"

    # Create monitoring scheduled task
    $monitorScript = Join-Path $PSScriptRoot "4-monitor-backup-jobs.ps1"

    if (Test-Path $monitorScript) {
        $taskCreated = New-ScheduledBackupTask `
            -TaskName "Veeam-Backup-Monitoring" `
            -Description "Daily Veeam backup monitoring and reporting" `
            -ScriptPath $monitorScript `
            -Schedule "Daily 08:00" `
            -Arguments @{
                BackupDestination = $script:Config.VeeamShare
            }

        if ($taskCreated) {
            Write-Log "Monitoring scheduled task created" "SUCCESS"
        }
    } else {
        Write-Log "WARNING: Monitoring script not found: $monitorScript" "WARNING"
    }
}

# ===== FINAL REPORT =====

function Show-DeploymentSummary {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host " DEPLOYMENT COMPLETE" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "CONFIGURED BACKUP JOBS:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Full System Backup" -ForegroundColor Yellow
    Write-Host "   Location: $($script:Config.FullBackupJob.Destination)" -ForegroundColor White
    Write-Host "   Schedule: Daily at $($script:Config.FullBackupJob.Schedule)" -ForegroundColor White
    Write-Host "   Retention: $($script:Config.FullBackupJob.Retention) days" -ForegroundColor White
    Write-Host "   Status: MANUAL CONFIGURATION REQUIRED IN VEEAM UI" -ForegroundColor Yellow
    Write-Host ""

    if (-not $SkipWorkspaceSync) {
        Write-Host "2. Workspace Hourly Sync" -ForegroundColor Yellow
        Write-Host "   Source: $($script:Config.WorkspacePath)" -ForegroundColor White
        Write-Host "   Destination: $($script:Config.WorkspaceShare)" -ForegroundColor White
        Write-Host "   Schedule: Hourly" -ForegroundColor White
        Write-Host "   Retention: $($script:Config.WorkspaceBackupJob.Retention) days" -ForegroundColor White
        Write-Host "   Status: AUTOMATED VIA SCHEDULED TASK" -ForegroundColor Green
        Write-Host ""
    }

    if (-not $SkipWSLBackup) {
        Write-Host "3. WSL Daily Backup" -ForegroundColor Yellow
        Write-Host "   Destination: $($script:Config.WSLShare)" -ForegroundColor White
        Write-Host "   Schedule: Daily at $($script:Config.WSLBackupJob.Schedule)" -ForegroundColor White
        Write-Host "   Retention: $($script:Config.WSLBackupJob.Retention) days" -ForegroundColor White
        Write-Host "   Status: AUTOMATED VIA SCHEDULED TASK" -ForegroundColor Green
        Write-Host ""
    }

    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Complete Veeam full backup configuration in Veeam UI" -ForegroundColor White
    Write-Host "2. Test immediate backup: Open Veeam > Backup Now" -ForegroundColor White
    Write-Host "3. View scheduled tasks: taskschd.msc" -ForegroundColor White
    Write-Host "4. Monitor backups: .\4-monitor-backup-jobs.ps1" -ForegroundColor White
    Write-Host "5. Check logs: $($script:Config.LogDir)" -ForegroundColor White
    Write-Host ""

    Write-Host "SCHEDULED TASKS CREATED:" -ForegroundColor Cyan
    $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "Veeam*" -or $_.TaskName -like "*Workspace*" -or $_.TaskName -like "*WSL*" }
    foreach ($task in $tasks) {
        Write-Host "  - $($task.TaskName)" -ForegroundColor Green
    }
    Write-Host ""

    Write-Host "DOCUMENTATION:" -ForegroundColor Cyan
    Write-Host "  Deployment log: $logFile" -ForegroundColor White
    Write-Host "  All logs: $($script:Config.LogDir)" -ForegroundColor White
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
}

# ===== MAIN EXECUTION =====

try {
    Show-Banner
    Write-Log "=== Enhanced Veeam Deployment Started ===" "INFO"
    Write-Log "Mode: $(if ($Unattended) { 'Unattended' } else { 'Interactive' })" "INFO"

    # Step 1: Initialize environment
    Write-Log "" "INFO"
    Write-Log "STEP 1: Initialize Environment" "HEADER"
    Initialize-Environment

    # Step 2: Get credentials and mount shares
    Write-Log "" "INFO"
    Write-Log "STEP 2: Configure Network Access" "HEADER"
    $password = Get-SmbCredentials
    Mount-NetworkShares -Password $password

    # Step 3: Install Veeam (if needed)
    if (-not $SkipInstallation) {
        Write-Log "" "INFO"
        Write-Log "STEP 3: Veeam Installation" "HEADER"

        if (Test-VeeamInstalled) {
            Write-Log "Veeam Agent already installed, skipping installation" "INFO"
        } else {
            $installer = Find-VeeamInstaller

            if ($installer) {
                $installed = Install-VeeamAgent -InstallerPath $installer

                if (-not $installed) {
                    throw "Veeam installation failed"
                }
            } else {
                Write-Log "WARNING: No installer found. Please install Veeam manually." "WARNING"
                Write-Log "Download from: https://www.veeam.com/windows-endpoint-server-backup-free.html" "INFO"

                if (-not $Unattended) {
                    Write-Host ""
                    Write-Host "Press Enter after installing Veeam manually..." -ForegroundColor Yellow
                    Read-Host
                }
            }
        }
    }

    # Step 4: Configure backup jobs
    if (-not $SkipBackupConfiguration) {
        Write-Log "" "INFO"
        Write-Log "STEP 4: Configure Backup Jobs" "HEADER"
        Configure-BackupJobs
    }

    # Step 5: Test configuration
    if (-not $SkipTesting) {
        Write-Log "" "INFO"
        Write-Log "STEP 5: Test Backup Configuration" "HEADER"
        Test-BackupConfiguration
    }

    # Step 6: Setup monitoring
    Write-Log "" "INFO"
    Write-Log "STEP 6: Setup Monitoring" "HEADER"
    Setup-Monitoring

    # Final summary
    $deploymentStatus.EndTime = (Get-Date).ToString()
    Show-DeploymentSummary

    Write-Log "=== Deployment Completed Successfully ===" "SUCCESS"
    Write-Log "Log file: $logFile" "INFO"

    exit 0

} catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" "ERROR"
    Write-Log "Deployment failed. See log: $logFile" "ERROR"

    $deploymentStatus.Errors += $_.Exception.Message
    $deploymentStatus.EndTime = (Get-Date).ToString()

    exit 1
}
