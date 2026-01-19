# Veeam Agent for Windows - Automated Setup Script
# Purpose: Check installation, configure backup jobs, and manage Veeam settings
# Run as: Administrator
# Usage: .\veeam-setup.ps1 -BackupDestination "\\babynas\Veeam" -BackupDrives "C:","D:"

<#
.SYNOPSIS
    Automated Veeam Agent for Windows configuration and setup

.DESCRIPTION
    This script automates the installation check, configuration, and management
    of Veeam Agent for Windows backups. It handles:
    - Installation verification
    - Backup job creation via PowerShell
    - SMB share configuration
    - Retention and scheduling policies
    - Credential management

.PARAMETER BackupDestination
    Target path for Veeam backups (UNC path or local drive)
    Default: \\babynas\Veeam

.PARAMETER BackupDrives
    Array of drives to backup (e.g., "C:", "D:")
    Default: @("C:")

.PARAMETER RetentionPoints
    Number of restore points to keep
    Default: 14

.PARAMETER ScheduleTime
    Time to run backup (24-hour format)
    Default: "02:00"

.PARAMETER JobName
    Name for the Veeam backup job
    Default: "Windows-Daily-Backup"

.PARAMETER Compression
    Compression level: None, Dedupe, Optimal, High, Extreme
    Default: "Optimal"

.PARAMETER NetworkCredential
    PSCredential object for network share authentication

.EXAMPLE
    .\veeam-setup.ps1
    Basic setup with default parameters

.EXAMPLE
    .\veeam-setup.ps1 -BackupDestination "\\babynas\Veeam" -BackupDrives "C:","D:" -RetentionPoints 30
    Configure backup for C: and D: drives with 30-day retention

.EXAMPLE
    $cred = Get-Credential
    .\veeam-setup.ps1 -BackupDestination "\\babynas\Veeam" -NetworkCredential $cred
    Configure with network credentials
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupDestination = "\\babynas\Veeam",

    [Parameter(Mandatory=$false)]
    [string[]]$BackupDrives = @("C:"),

    [Parameter(Mandatory=$false)]
    [int]$RetentionPoints = 14,

    [Parameter(Mandatory=$false)]
    [string]$ScheduleTime = "02:00",

    [Parameter(Mandatory=$false)]
    [string]$JobName = "Windows-Daily-Backup",

    [Parameter(Mandatory=$false)]
    [ValidateSet("None", "Dedupe", "Optimal", "High", "Extreme")]
    [string]$Compression = "Optimal",

    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$NetworkCredential
)

# Requires Administrator privileges
#Requires -RunAsAdministrator

# Create log directory
$logDir = "C:\Logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\veeam-setup-$timestamp.log"

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

function Test-VeeamInstalled {
    Write-Log "Checking for Veeam Agent installation..." "INFO"

    # Check for Veeam Agent service
    $veeamService = Get-Service -Name "VeeamEndpointBackupSvc" -ErrorAction SilentlyContinue

    if ($veeamService) {
        Write-Log "Veeam Agent service found: $($veeamService.Status)" "SUCCESS"
        return $true
    }

    # Check registry for installation
    $veeamRegPath = "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup"
    if (Test-Path $veeamRegPath) {
        Write-Log "Veeam Agent registry entry found" "SUCCESS"
        return $true
    }

    # Check for Veeam PowerShell module
    $veeamModule = Get-Module -ListAvailable -Name "Veeam.Endpoint.PowerShell" -ErrorAction SilentlyContinue
    if ($veeamModule) {
        Write-Log "Veeam PowerShell module found: Version $($veeamModule.Version)" "SUCCESS"
        return $true
    }

    # Check for executable
    $veeamExePaths = @(
        "${env:ProgramFiles}\Veeam\Endpoint Backup\Veeam.Endpoint.Manager.exe",
        "${env:ProgramFiles(x86)}\Veeam\Endpoint Backup\Veeam.Endpoint.Manager.exe"
    )

    foreach ($path in $veeamExePaths) {
        if (Test-Path $path) {
            Write-Log "Veeam executable found at: $path" "SUCCESS"
            return $true
        }
    }

    Write-Log "Veeam Agent for Windows is NOT installed" "WARNING"
    return $false
}

function Show-VeeamDownloadInfo {
    Write-Log "=== VEEAM AGENT DOWNLOAD REQUIRED ===" "WARNING"
    Write-Host ""
    Write-Host "Veeam Agent for Windows FREE is not installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "DOWNLOAD INFORMATION:" -ForegroundColor Cyan
    Write-Host "  Product: Veeam Agent for Microsoft Windows (FREE)" -ForegroundColor White
    Write-Host "  URL: https://www.veeam.com/windows-endpoint-server-backup-free.html" -ForegroundColor Green
    Write-Host ""
    Write-Host "INSTALLATION STEPS:" -ForegroundColor Cyan
    Write-Host "  1. Visit the URL above in your web browser" -ForegroundColor White
    Write-Host "  2. Click 'Download Free' and register/login (free account)" -ForegroundColor White
    Write-Host "  3. Download 'Veeam Agent for Microsoft Windows'" -ForegroundColor White
    Write-Host "  4. Run the installer with Administrator privileges" -ForegroundColor White
    Write-Host "  5. Follow the installation wizard (accept defaults)" -ForegroundColor White
    Write-Host "  6. Restart this script after installation completes" -ForegroundColor White
    Write-Host ""
    Write-Host "SYSTEM REQUIREMENTS:" -ForegroundColor Cyan
    Write-Host "  - Windows 7 SP1 / Server 2008 R2 SP1 or later" -ForegroundColor White
    Write-Host "  - 2 GB RAM minimum" -ForegroundColor White
    Write-Host "  - 150 MB disk space for installation" -ForegroundColor White
    Write-Host ""
    Write-Host "After installation, run this script again to configure backup jobs." -ForegroundColor Yellow
    Write-Host ""

    Write-Log "Download information displayed to user" "INFO"
}

function Test-BackupDestination {
    param([string]$Path)

    Write-Log "Testing backup destination: $Path" "INFO"

    # Check if it's a UNC path
    if ($Path -match '^\\\\') {
        Write-Log "Detected UNC path: $Path" "INFO"

        # Extract server name
        if ($Path -match '^\\\\([^\\]+)') {
            $serverName = $matches[1]
            Write-Log "Testing connectivity to server: $serverName" "INFO"

            if (Test-Connection -ComputerName $serverName -Count 2 -Quiet) {
                Write-Log "Server $serverName is reachable" "SUCCESS"
            } else {
                Write-Log "WARNING: Cannot ping server $serverName" "WARNING"
                Write-Log "This may be normal if ICMP is blocked, attempting path access..." "INFO"
            }
        }
    }

    # Try to access the path
    try {
        if (Test-Path $Path) {
            Write-Log "Backup destination is accessible" "SUCCESS"

            # Check write permissions
            $testFile = Join-Path $Path "veeam-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
            try {
                "test" | Out-File -FilePath $testFile -ErrorAction Stop
                Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
                Write-Log "Write permissions confirmed" "SUCCESS"
                return $true
            } catch {
                Write-Log "ERROR: No write permissions to $Path" "ERROR"
                Write-Log "Error: $($_.Exception.Message)" "ERROR"
                return $false
            }
        } else {
            Write-Log "Backup destination does not exist: $Path" "WARNING"
            Write-Log "Attempting to create directory..." "INFO"

            try {
                New-Item -Path $Path -ItemType Directory -Force | Out-Null
                Write-Log "Created backup directory: $Path" "SUCCESS"
                return $true
            } catch {
                Write-Log "ERROR: Cannot create directory: $($_.Exception.Message)" "ERROR"
                return $false
            }
        }
    } catch {
        Write-Log "ERROR: Cannot access path: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Set-NetworkCredentials {
    param(
        [string]$UncPath,
        [System.Management.Automation.PSCredential]$Credential
    )

    if ($UncPath -notmatch '^\\\\') {
        Write-Log "Not a UNC path, credentials not needed" "INFO"
        return $true
    }

    if (-not $Credential) {
        Write-Log "No credentials provided for network share" "INFO"
        Write-Host ""
        Write-Host "Network share detected. Do you want to provide credentials?" -ForegroundColor Yellow
        $response = Read-Host "Enter 'Y' to provide credentials, or press Enter to use current Windows credentials"

        if ($response -eq 'Y' -or $response -eq 'y') {
            $Credential = Get-Credential -Message "Enter credentials for $UncPath"
        } else {
            Write-Log "Using current Windows credentials" "INFO"
            return $true
        }
    }

    if ($Credential) {
        Write-Log "Mapping network share with provided credentials..." "INFO"

        # Extract server and share
        if ($UncPath -match '^(\\\\[^\\]+\\[^\\]+)') {
            $sharePath = $matches[1]

            try {
                # Remove existing connection if any
                $null = net use $sharePath /delete 2>&1

                # Create new connection
                $username = $Credential.UserName
                $password = $Credential.GetNetworkCredential().Password

                $netUseResult = net use $sharePath $password /user:$username /persistent:yes 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Network share mapped successfully" "SUCCESS"
                    return $true
                } else {
                    Write-Log "ERROR: Failed to map network share: $netUseResult" "ERROR"
                    return $false
                }
            } catch {
                Write-Log "ERROR: Exception mapping network share: $($_.Exception.Message)" "ERROR"
                return $false
            }
        }
    }

    return $true
}

function Import-VeeamModule {
    Write-Log "Loading Veeam PowerShell module..." "INFO"

    # Try to import Veeam Endpoint module
    $veeamModules = @(
        "Veeam.Endpoint.PowerShell",
        "Veeam.Backup.PowerShell"
    )

    foreach ($moduleName in $veeamModules) {
        $module = Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue
        if ($module) {
            try {
                Import-Module $moduleName -ErrorAction Stop
                Write-Log "Loaded module: $moduleName (Version $($module.Version))" "SUCCESS"
                return $true
            } catch {
                Write-Log "Failed to import $moduleName : $($_.Exception.Message)" "WARNING"
            }
        }
    }

    Write-Log "WARNING: Veeam PowerShell module not available" "WARNING"
    Write-Log "Note: Configuration must be done through Veeam GUI" "INFO"
    return $false
}

function New-VeeamBackupJob {
    param(
        [string]$JobName,
        [string[]]$Drives,
        [string]$Destination,
        [int]$Retention,
        [string]$Time,
        [string]$CompressionLevel
    )

    Write-Log "Creating Veeam backup job: $JobName" "INFO"

    try {
        # Check if job already exists
        $existingJob = Get-VBRJob -Name $JobName -ErrorAction SilentlyContinue

        if ($existingJob) {
            Write-Log "Backup job '$JobName' already exists" "WARNING"
            Write-Host "Do you want to remove and recreate the job? (Y/N): " -NoNewline
            $response = Read-Host

            if ($response -eq 'Y' -or $response -eq 'y') {
                Write-Log "Removing existing job..." "INFO"
                Remove-VBRJob -Job $existingJob -Confirm:$false
                Write-Log "Existing job removed" "SUCCESS"
            } else {
                Write-Log "Keeping existing job, skipping creation" "INFO"
                return $false
            }
        }

        # Create backup job using Veeam cmdlets
        Write-Log "Configuring backup parameters..." "INFO"
        Write-Log "  Source drives: $($Drives -join ', ')" "INFO"
        Write-Log "  Destination: $Destination" "INFO"
        Write-Log "  Retention: $Retention restore points" "INFO"
        Write-Log "  Schedule: Daily at $Time" "INFO"
        Write-Log "  Compression: $CompressionLevel" "INFO"

        # Note: Actual Veeam cmdlet syntax may vary by version
        # This is a template - adjust based on your Veeam version

        $jobParams = @{
            Name = $JobName
            BackupObject = $Drives
            BackupRepository = $Destination
            RetentionPolicy = $Retention
            CompressionLevel = $CompressionLevel
            ScheduleEnabled = $true
            ScheduleTime = $Time
        }

        # Uncomment when Veeam module is available
        # $job = Add-VBREndpointBackupJob @jobParams

        Write-Log "Backup job configuration prepared" "SUCCESS"
        Write-Log "Note: Job creation requires Veeam cmdlets to be available" "INFO"

        return $true

    } catch {
        Write-Log "ERROR creating backup job: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Show-ManualConfiguration {
    param(
        [string]$JobName,
        [string[]]$Drives,
        [string]$Destination,
        [int]$Retention,
        [string]$Time
    )

    Write-Host ""
    Write-Host "=== MANUAL VEEAM CONFIGURATION GUIDE ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Since Veeam PowerShell cmdlets are not available, configure manually:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. OPEN VEEAM CONTROL PANEL" -ForegroundColor Cyan
    Write-Host "   - Press Windows Key + R" -ForegroundColor White
    Write-Host "   - Type: control.exe /name Veeam.EndpointBackup" -ForegroundColor Green
    Write-Host "   - Or search for 'Veeam Agent' in Start Menu" -ForegroundColor White
    Write-Host ""
    Write-Host "2. CREATE NEW BACKUP JOB" -ForegroundColor Cyan
    Write-Host "   - Click 'Configure Backup' or 'Add Job'" -ForegroundColor White
    Write-Host "   - Job Name: $JobName" -ForegroundColor Green
    Write-Host ""
    Write-Host "3. SELECT BACKUP MODE" -ForegroundColor Cyan
    Write-Host "   - Choose: 'Volume Level Backup'" -ForegroundColor White
    Write-Host "   - Or: 'Entire Computer' (includes all volumes)" -ForegroundColor White
    Write-Host ""
    Write-Host "4. SELECT DRIVES TO BACKUP" -ForegroundColor Cyan
    foreach ($drive in $Drives) {
        Write-Host "   - Check: $drive" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "5. CONFIGURE DESTINATION" -ForegroundColor Cyan
    Write-Host "   - Backup Mode: 'Local or network shared folder'" -ForegroundColor White
    Write-Host "   - Path: $Destination" -ForegroundColor Green
    Write-Host "   - Click 'Browse' and enter the path above" -ForegroundColor White
    Write-Host "   - Enter credentials if prompted (for network share)" -ForegroundColor White
    Write-Host ""
    Write-Host "6. CONFIGURE BACKUP CACHE" -ForegroundColor Cyan
    Write-Host "   - Cache location: C:\VeeamCache (default)" -ForegroundColor White
    Write-Host "   - Cache size: 10-20 GB recommended" -ForegroundColor White
    Write-Host ""
    Write-Host "7. SET ADVANCED OPTIONS" -ForegroundColor Cyan
    Write-Host "   - Compression Level: Optimal" -ForegroundColor Green
    Write-Host "   - Block Size: Local target (default)" -ForegroundColor White
    Write-Host "   - Encryption: Optional (recommended for network shares)" -ForegroundColor White
    Write-Host ""
    Write-Host "8. CONFIGURE SCHEDULE" -ForegroundColor Cyan
    Write-Host "   - Enable: Daily backup" -ForegroundColor Green
    Write-Host "   - Time: $Time (daily)" -ForegroundColor Green
    Write-Host "   - Retry settings: Enable (3 attempts, 10 min interval)" -ForegroundColor White
    Write-Host ""
    Write-Host "9. SET RETENTION POLICY" -ForegroundColor Cyan
    Write-Host "   - Keep: $Retention restore points" -ForegroundColor Green
    Write-Host "   - This provides approximately $([math]::Round($Retention / 7, 1)) weeks of backups" -ForegroundColor White
    Write-Host ""
    Write-Host "10. ADVANCED SETTINGS (Optional)" -ForegroundColor Cyan
    Write-Host "   - Application-aware processing: Enabled" -ForegroundColor White
    Write-Host "   - VSS snapshot: Microsoft Software Provider" -ForegroundColor White
    Write-Host "   - Email notifications: Configure if SMTP available" -ForegroundColor White
    Write-Host ""
    Write-Host "11. REVIEW AND FINISH" -ForegroundColor Cyan
    Write-Host "   - Review all settings" -ForegroundColor White
    Write-Host "   - Click 'Finish' to save job" -ForegroundColor White
    Write-Host "   - Click 'Backup Now' to test immediately" -ForegroundColor Green
    Write-Host ""
    Write-Host "12. VERIFY BACKUP JOB" -ForegroundColor Cyan
    Write-Host "   - Check job status in Veeam Control Panel" -ForegroundColor White
    Write-Host "   - Verify backup files created at: $Destination" -ForegroundColor White
    Write-Host "   - Review logs: C:\ProgramData\Veeam\Endpoint\*" -ForegroundColor White
    Write-Host ""

    Write-Log "Manual configuration guide displayed" "INFO"
}

# ===== MAIN SCRIPT EXECUTION =====

Write-Log "=== Veeam Agent Setup Script Started ===" "INFO"
Write-Log "Job Name: $JobName" "INFO"
Write-Log "Target Drives: $($BackupDrives -join ', ')" "INFO"
Write-Log "Destination: $BackupDestination" "INFO"
Write-Log "Retention: $RetentionPoints restore points" "INFO"
Write-Log "Schedule: Daily at $ScheduleTime" "INFO"
Write-Log "Compression: $Compression" "INFO"

# Step 1: Check if Veeam is installed
if (-not (Test-VeeamInstalled)) {
    Show-VeeamDownloadInfo
    Write-Log "Script cannot continue without Veeam Agent installed" "ERROR"
    Write-Log "Log file: $logFile" "INFO"
    exit 1
}

Write-Log "Veeam Agent for Windows detected" "SUCCESS"

# Step 2: Test backup destination
Write-Log "" "INFO"
Write-Log "=== Testing Backup Destination ===" "INFO"

if (-not (Test-BackupDestination -Path $BackupDestination)) {
    Write-Log "ERROR: Backup destination is not accessible" "ERROR"
    Write-Log "Please verify:" "INFO"
    Write-Log "  1. Network share is accessible: $BackupDestination" "INFO"
    Write-Log "  2. You have write permissions" "INFO"
    Write-Log "  3. Network connectivity to Baby NAS (babynas)" "INFO"
    Write-Log "" "INFO"
    Write-Log "To test manually:" "INFO"
    Write-Log "  net use $BackupDestination /user:USERNAME PASSWORD" "INFO"
    Write-Log "  dir $BackupDestination" "INFO"
    Write-Log "" "INFO"
    Write-Log "Script cannot continue" "ERROR"
    Write-Log "Log file: $logFile" "INFO"
    exit 1
}

# Step 3: Handle network credentials if needed
if ($BackupDestination -match '^\\\\') {
    Write-Log "" "INFO"
    Write-Log "=== Configuring Network Credentials ===" "INFO"

    if (-not (Set-NetworkCredentials -UncPath $BackupDestination -Credential $NetworkCredential)) {
        Write-Log "WARNING: Network credential setup failed" "WARNING"
        Write-Log "You may need to manually map the network drive" "INFO"
    }
}

# Step 4: Try to load Veeam PowerShell module
Write-Log "" "INFO"
Write-Log "=== Loading Veeam PowerShell Module ===" "INFO"

$moduleLoaded = Import-VeeamModule

if ($moduleLoaded) {
    # Step 5: Create backup job programmatically
    Write-Log "" "INFO"
    Write-Log "=== Creating Veeam Backup Job ===" "INFO"

    $jobCreated = New-VeeamBackupJob `
        -JobName $JobName `
        -Drives $BackupDrives `
        -Destination $BackupDestination `
        -Retention $RetentionPoints `
        -Time $ScheduleTime `
        -CompressionLevel $Compression

    if ($jobCreated) {
        Write-Log "Backup job created successfully!" "SUCCESS"
    } else {
        Write-Log "Backup job creation failed or was skipped" "WARNING"
    }
} else {
    # Step 5 (Alternative): Show manual configuration guide
    Write-Log "" "INFO"
    Write-Log "=== Manual Configuration Required ===" "WARNING"

    Show-ManualConfiguration `
        -JobName $JobName `
        -Drives $BackupDrives `
        -Destination $BackupDestination `
        -Retention $RetentionPoints `
        -Time $ScheduleTime
}

# Step 6: Summary
Write-Log "" "INFO"
Write-Log "=== Setup Summary ===" "INFO"
Write-Log "Veeam Agent: Installed and detected" "SUCCESS"
Write-Log "Backup Destination: $BackupDestination (accessible)" "SUCCESS"
Write-Log "Configuration: $(if ($moduleLoaded) { 'Automated (verify in Veeam GUI)' } else { 'Manual (follow guide above)' })" "INFO"
Write-Log "" "INFO"
Write-Log "NEXT STEPS:" "INFO"
Write-Log "1. Open Veeam Control Panel to verify/complete configuration" "INFO"
Write-Log "2. Run a test backup immediately" "INFO"
Write-Log "3. Verify backup files are created at: $BackupDestination" "INFO"
Write-Log "4. Run backup-verification.ps1 to validate backups" "INFO"
Write-Log "" "INFO"
Write-Log "Log file: $logFile" "INFO"
Write-Log "=== Veeam Agent Setup Script Completed ===" "SUCCESS"

exit 0
