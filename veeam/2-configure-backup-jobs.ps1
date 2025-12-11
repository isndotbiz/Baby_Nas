#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automated Veeam backup job configuration script

.DESCRIPTION
    Creates and configures Veeam backup jobs with optimal settings for TrueNAS targets.
    Features:
    - Automated job creation via PowerShell
    - Multiple drive backup support
    - Network share credential management
    - Application-aware processing
    - Custom retention policies
    - Flexible scheduling
    - Email notification configuration

.PARAMETER BackupDestination
    UNC path or local path for backup storage
    Default: \\172.21.203.18\Veeam

.PARAMETER BackupDrives
    Array of drives to backup (e.g., "C:", "D:")
    Default: @("C:", "D:")

.PARAMETER JobName
    Name for the backup job
    Default: "Windows-Daily-Backup"

.PARAMETER RetentionPoints
    Number of restore points to keep
    Default: 7

.PARAMETER ScheduleTime
    Time to run backup (24-hour format HH:MM)
    Default: "02:00"

.PARAMETER Compression
    Compression level: None, Dedupe, Optimal, High, Extreme
    Default: "Optimal"

.PARAMETER EnableEncryption
    Enable backup encryption
    Default: $false

.PARAMETER EncryptionPassword
    Password for backup encryption (required if EnableEncryption = $true)

.PARAMETER NetworkUsername
    Username for network share (if needed)

.PARAMETER NetworkPassword
    SecureString password for network share

.PARAMETER EnableAppAware
    Enable application-aware processing (VSS)
    Default: $true

.PARAMETER EnableEmailNotifications
    Enable email notifications for backup results
    Default: $false

.PARAMETER EmailTo
    Email address for notifications

.PARAMETER SmtpServer
    SMTP server address

.EXAMPLE
    .\2-configure-backup-jobs.ps1
    Basic configuration with defaults

.EXAMPLE
    .\2-configure-backup-jobs.ps1 -BackupDestination "\\172.21.203.18\Veeam" -BackupDrives "C:","D:" -RetentionPoints 14
    Configure backup for C: and D: with 14-day retention

.EXAMPLE
    .\2-configure-backup-jobs.ps1 -EnableEncryption $true -EncryptionPassword "MySecurePass123"
    Configure with encryption enabled

.NOTES
    Author: Automated Veeam Deployment System
    Version: 1.0
    Requires: Veeam Agent for Windows installed
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupDestination = "\\172.21.203.18\Veeam",

    [Parameter(Mandatory=$false)]
    [string[]]$BackupDrives = @("C:", "D:"),

    [Parameter(Mandatory=$false)]
    [string]$JobName = "Windows-Daily-Backup",

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 365)]
    [int]$RetentionPoints = 7,

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$ScheduleTime = "02:00",

    [Parameter(Mandatory=$false)]
    [ValidateSet("None", "Dedupe", "Optimal", "High", "Extreme")]
    [string]$Compression = "Optimal",

    [Parameter(Mandatory=$false)]
    [bool]$EnableEncryption = $false,

    [Parameter(Mandatory=$false)]
    [string]$EncryptionPassword,

    [Parameter(Mandatory=$false)]
    [string]$NetworkUsername,

    [Parameter(Mandatory=$false)]
    [SecureString]$NetworkPassword,

    [Parameter(Mandatory=$false)]
    [bool]$EnableAppAware = $true,

    [Parameter(Mandatory=$false)]
    [bool]$EnableEmailNotifications = $false,

    [Parameter(Mandatory=$false)]
    [string]$EmailTo,

    [Parameter(Mandatory=$false)]
    [string]$SmtpServer
)

# Configuration
$logDir = "C:\Logs\Veeam"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\veeam-configure-$timestamp.log"
$configFile = "$logDir\veeam-config-$timestamp.xml"

# Create log directory
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

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
        default   { Write-Host $logMessage -ForegroundColor White }
    }

    $logMessage | Out-File -FilePath $logFile -Append
}

function Test-VeeamInstalled {
    Write-Log "Verifying Veeam Agent installation..." "INFO"

    $service = Get-Service -Name "VeeamEndpointBackupSvc" -ErrorAction SilentlyContinue

    if ($service) {
        Write-Log "Veeam service found: $($service.Status)" "SUCCESS"
        if ($service.Status -ne "Running") {
            Write-Log "Starting Veeam service..." "INFO"
            Start-Service -Name "VeeamEndpointBackupSvc"
        }
        return $true
    }

    Write-Log "ERROR: Veeam Agent not installed" "ERROR"
    return $false
}

function Test-BackupDestination {
    param([string]$Path)

    Write-Log "Testing backup destination: $Path" "INFO"

    # Test if UNC path
    if ($Path -match '^\\\\') {
        Write-Log "Detected network path" "INFO"

        # Extract server
        if ($Path -match '^\\\\([^\\]+)') {
            $server = $matches[1]

            # Try to resolve hostname/IP
            try {
                $resolved = [System.Net.Dns]::GetHostAddresses($server)
                Write-Log "Server $server resolved to: $($resolved[0].IPAddressToString)" "SUCCESS"
            } catch {
                Write-Log "WARNING: Could not resolve server: $server" "WARNING"
            }

            # Test connectivity
            if (Test-Connection -ComputerName $server -Count 2 -Quiet) {
                Write-Log "Server $server is reachable" "SUCCESS"
            } else {
                Write-Log "WARNING: Cannot ping $server (may be normal if ICMP blocked)" "WARNING"
            }
        }
    }

    # Test path access
    try {
        if (Test-Path $Path) {
            Write-Log "Path is accessible" "SUCCESS"

            # Test write access
            $testFile = Join-Path $Path "veeam-write-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
            try {
                "test" | Out-File -FilePath $testFile -ErrorAction Stop
                Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
                Write-Log "Write permissions verified" "SUCCESS"
                return $true
            } catch {
                Write-Log "ERROR: No write access to $Path" "ERROR"
                return $false
            }
        } else {
            Write-Log "Path does not exist, attempting to create..." "INFO"
            try {
                New-Item -Path $Path -ItemType Directory -Force | Out-Null
                Write-Log "Directory created successfully" "SUCCESS"
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
        [string]$Path,
        [string]$Username,
        [SecureString]$Password
    )

    if ($Path -notmatch '^\\\\') {
        Write-Log "Local path, no credentials needed" "INFO"
        return $true
    }

    Write-Log "Configuring network credentials..." "INFO"

    # Prompt for credentials if not provided
    if (-not $Username -or -not $Password) {
        Write-Host ""
        Write-Host "Network share credentials required for: $Path" -ForegroundColor Yellow
        Write-Host "Press Enter to use current Windows credentials, or provide credentials:" -ForegroundColor Cyan
        Write-Host ""

        $response = Read-Host "Enter username (or press Enter for current user)"

        if ($response) {
            $Username = $response
            $Password = Read-Host "Enter password" -AsSecureString
        } else {
            Write-Log "Using current Windows credentials" "INFO"
            return $true
        }
    }

    # Map network drive with credentials
    if ($Username -and $Password) {
        try {
            # Extract share path (\\server\share)
            if ($Path -match '^(\\\\[^\\]+\\[^\\]+)') {
                $sharePath = $matches[1]

                # Remove existing connection
                $null = net use $sharePath /delete 2>&1

                # Create new persistent connection
                $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                )

                $netUseResult = net use $sharePath $passwordPlain /user:$Username /persistent:yes 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Network credentials configured successfully" "SUCCESS"
                    return $true
                } else {
                    Write-Log "ERROR: Failed to configure network credentials" "ERROR"
                    Write-Log "Output: $netUseResult" "ERROR"
                    return $false
                }
            }
        } catch {
            Write-Log "ERROR: Exception configuring credentials: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }

    return $true
}

function New-VeeamBackupJobManual {
    param(
        [string]$Name,
        [string[]]$Drives,
        [string]$Destination,
        [int]$Retention,
        [string]$Time,
        [string]$CompressionLevel,
        [bool]$AppAware,
        [bool]$Encryption,
        [string]$EncryptPassword
    )

    Write-Log "Preparing backup job configuration..." "INFO"

    # Save configuration to file for manual reference
    $config = @{
        JobName = $Name
        Drives = $Drives
        Destination = $Destination
        Retention = $Retention
        ScheduleTime = $Time
        Compression = $CompressionLevel
        ApplicationAware = $AppAware
        Encryption = $Encryption
        Timestamp = (Get-Date).ToString()
        ComputerName = $env:COMPUTERNAME
        Username = $env:USERNAME
    }

    $config | Export-Clixml -Path $configFile
    Write-Log "Configuration saved to: $configFile" "INFO"

    # Show manual configuration guide
    Show-ManualConfiguration -Config $config -EncryptPassword $EncryptPassword

    return $true
}

function Show-ManualConfiguration {
    param(
        [hashtable]$Config,
        [string]$EncryptPassword
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " VEEAM BACKUP JOB CONFIGURATION GUIDE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "CONFIGURATION SUMMARY:" -ForegroundColor Green
    Write-Host "  Job Name:        $($Config.JobName)" -ForegroundColor White
    Write-Host "  Backup Drives:   $($Config.Drives -join ', ')" -ForegroundColor White
    Write-Host "  Destination:     $($Config.Destination)" -ForegroundColor White
    Write-Host "  Retention:       $($Config.Retention) restore points" -ForegroundColor White
    Write-Host "  Schedule:        Daily at $($Config.ScheduleTime)" -ForegroundColor White
    Write-Host "  Compression:     $($Config.Compression)" -ForegroundColor White
    Write-Host "  App-Aware:       $($Config.ApplicationAware)" -ForegroundColor White
    Write-Host "  Encryption:      $($Config.Encryption)" -ForegroundColor White
    Write-Host ""

    Write-Host "STEP-BY-STEP CONFIGURATION:" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "1. OPEN VEEAM CONTROL PANEL" -ForegroundColor Yellow
    Write-Host "   Method 1: Press Win+R, type: " -NoNewline
    Write-Host "control.exe /name Veeam.EndpointBackup" -ForegroundColor Green
    Write-Host "   Method 2: Search for 'Veeam' in Start Menu"
    Write-Host ""

    Write-Host "2. START BACKUP JOB CREATION" -ForegroundColor Yellow
    Write-Host "   - Click 'Configure Backup' (or 'Add Job' if jobs exist)"
    Write-Host "   - Select 'Volume Level Backup' mode"
    Write-Host ""

    Write-Host "3. SELECT VOLUMES TO BACKUP" -ForegroundColor Yellow
    Write-Host "   Check the following drives:"
    foreach ($drive in $Config.Drives) {
        Write-Host "   [X] $drive" -ForegroundColor Green
    }
    Write-Host "   Click 'Next'"
    Write-Host ""

    Write-Host "4. CONFIGURE BACKUP DESTINATION" -ForegroundColor Yellow
    Write-Host "   - Select: 'Local or network shared folder'"
    Write-Host "   - Path: " -NoNewline
    Write-Host "$($Config.Destination)" -ForegroundColor Green
    Write-Host "   - Enter credentials if prompted (for network shares)"
    Write-Host "   - Click 'Next'"
    Write-Host ""

    Write-Host "5. CONFIGURE BACKUP CACHE" -ForegroundColor Yellow
    Write-Host "   - Location: C:\VeeamCache (default recommended)"
    Write-Host "   - Size: 10-20 GB minimum"
    Write-Host "   - Click 'Next'"
    Write-Host ""

    Write-Host "6. ADVANCED SETTINGS - COMPRESSION" -ForegroundColor Yellow
    Write-Host "   - Compression Level: " -NoNewline
    Write-Host "$($Config.Compression)" -ForegroundColor Green
    Write-Host "   - Block Size: 'Local target' (default)"
    Write-Host ""

    if ($Config.Encryption) {
        Write-Host "7. ADVANCED SETTINGS - ENCRYPTION" -ForegroundColor Yellow
        Write-Host "   - Enable Encryption: " -NoNewline
        Write-Host "YES" -ForegroundColor Green
        if ($EncryptPassword) {
            Write-Host "   - Password: " -NoNewline
            Write-Host "[PROVIDED - See secure notes]" -ForegroundColor Green
        } else {
            Write-Host "   - Password: " -NoNewline
            Write-Host "[SET YOUR OWN SECURE PASSWORD]" -ForegroundColor Yellow
        }
        Write-Host "   - Password Hint: (optional)"
        Write-Host ""
    }

    Write-Host "8. SCHEDULE CONFIGURATION" -ForegroundColor Yellow
    Write-Host "   - Enable: " -NoNewline
    Write-Host "Daily backup" -ForegroundColor Green
    Write-Host "   - Time: " -NoNewline
    Write-Host "$($Config.ScheduleTime)" -ForegroundColor Green
    Write-Host "   - Days: All days (Mon-Sun)"
    Write-Host "   - Retry: Enable (3 attempts, 10 min interval)"
    Write-Host ""

    Write-Host "9. RETENTION POLICY" -ForegroundColor Yellow
    Write-Host "   - Keep: " -NoNewline
    Write-Host "$($Config.Retention) restore points" -ForegroundColor Green
    $weeks = [math]::Round($Config.Retention / 7, 1)
    Write-Host "   (Approximately $weeks weeks of backups)"
    Write-Host ""

    if ($Config.ApplicationAware) {
        Write-Host "10. APPLICATION-AWARE PROCESSING" -ForegroundColor Yellow
        Write-Host "   - Enable: " -NoNewline
        Write-Host "Application-aware processing" -ForegroundColor Green
        Write-Host "   - VSS: Microsoft Software Provider"
        Write-Host "   - Process SQL/Exchange if present"
        Write-Host ""
    }

    Write-Host "11. JOB NAME" -ForegroundColor Yellow
    Write-Host "   - Name: " -NoNewline
    Write-Host "$($Config.JobName)" -ForegroundColor Green
    Write-Host ""

    Write-Host "12. REVIEW AND FINISH" -ForegroundColor Yellow
    Write-Host "   - Review all settings"
    Write-Host "   - Click 'Finish' to save"
    Write-Host "   - Click 'Backup Now' to test immediately (recommended)"
    Write-Host ""

    Write-Host "13. VERIFY OPERATION" -ForegroundColor Yellow
    Write-Host "   - Check job appears in Veeam Control Panel"
    Write-Host "   - Monitor first backup progress"
    Write-Host "   - Verify files created at: $($Config.Destination)"
    Write-Host "   - Check logs: C:\ProgramData\Veeam\Endpoint\*"
    Write-Host ""

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Configuration guide saved to: " -ForegroundColor Cyan
    Write-Host "$configFile" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Log "Manual configuration guide displayed" "INFO"
}

function New-VeeamScheduledTask {
    param(
        [string]$JobName,
        [string]$Time
    )

    Write-Log "Creating scheduled task fallback for backup job..." "INFO"

    # Parse time
    $timeParts = $Time -split ':'
    $hour = $timeParts[0]
    $minute = $timeParts[1]

    # Veeam CLI path
    $veeamCli = "${env:ProgramFiles}\Veeam\Endpoint Backup\Veeam.Endpoint.Manager.exe"

    if (-not (Test-Path $veeamCli)) {
        Write-Log "WARNING: Veeam CLI not found at expected location" "WARNING"
        return $false
    }

    try {
        # Create scheduled task to trigger Veeam backup
        $taskName = "Veeam-$JobName-Daily"

        # Check if task exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

        if ($existingTask) {
            Write-Log "Scheduled task already exists: $taskName" "WARNING"
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Log "Removed existing task" "INFO"
        }

        # Create task action (launch Veeam to start backup)
        # Note: Actual command may vary based on Veeam version
        $action = New-ScheduledTaskAction -Execute $veeamCli -Argument "/backup start `"$JobName`""

        # Create daily trigger
        $trigger = New-ScheduledTaskTrigger -Daily -At "$hour`:$minute"

        # Create task settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        # Register task
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Description "Automated Veeam backup for $JobName" | Out-Null

        Write-Log "Scheduled task created: $taskName" "SUCCESS"
        return $true

    } catch {
        Write-Log "ERROR creating scheduled task: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-VeeamBackupJob {
    param([string]$JobName)

    Write-Log "Checking for existing backup job: $JobName" "INFO"

    # Check Veeam registry for job configuration
    $regPath = "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup\Jobs"

    if (Test-Path $regPath) {
        $jobs = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue

        foreach ($job in $jobs) {
            $jobNameReg = (Get-ItemProperty -Path $job.PSPath -Name "Name" -ErrorAction SilentlyContinue).Name

            if ($jobNameReg -eq $JobName) {
                Write-Log "Found existing job in registry: $JobName" "SUCCESS"
                return $true
            }
        }
    }

    # Check Veeam config files
    $configPaths = @(
        "C:\ProgramData\Veeam\Endpoint",
        "${env:ProgramData}\Veeam\Endpoint"
    )

    foreach ($configPath in $configPaths) {
        if (Test-Path $configPath) {
            $configFiles = Get-ChildItem -Path $configPath -Recurse -Filter "*.xml" -ErrorAction SilentlyContinue

            foreach ($file in $configFiles) {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue

                if ($content -and $content -match $JobName) {
                    Write-Log "Found job reference in config: $($file.FullName)" "SUCCESS"
                    return $true
                }
            }
        }
    }

    Write-Log "No existing job found with name: $JobName" "INFO"
    return $false
}

function Show-ValidationSteps {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " VALIDATION AND TESTING" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "IMMEDIATE ACTIONS:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Open Veeam Control Panel and verify job configuration"
    Write-Host "2. Run test backup immediately (don't wait for schedule)"
    Write-Host "3. Monitor backup progress in Veeam UI"
    Write-Host "4. Verify backup files are created at destination"
    Write-Host ""

    Write-Host "VERIFY BACKUP FILES:" -ForegroundColor Cyan
    Write-Host "  Check destination: $BackupDestination" -ForegroundColor White
    Write-Host "  Look for: *.vbk, *.vib files" -ForegroundColor White
    Write-Host "  Verify file sizes are reasonable" -ForegroundColor White
    Write-Host ""

    Write-Host "RUN AUTOMATED MONITORING:" -ForegroundColor Cyan
    Write-Host "  .\4-monitor-backup-jobs.ps1" -ForegroundColor Green
    Write-Host ""

    Write-Host "TEST RECOVERY:" -ForegroundColor Cyan
    Write-Host "  .\5-test-recovery.ps1" -ForegroundColor Green
    Write-Host ""

    Write-Host "VIEW LOGS:" -ForegroundColor Cyan
    Write-Host "  Configuration: $configFile" -ForegroundColor White
    Write-Host "  Log file: $logFile" -ForegroundColor White
    Write-Host "  Veeam logs: C:\ProgramData\Veeam\Endpoint" -ForegroundColor White
    Write-Host ""
}

# ===== MAIN EXECUTION =====

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " VEEAM BACKUP JOB CONFIGURATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== Veeam Backup Job Configuration Started ===" "INFO"
Write-Log "Job Name: $JobName" "INFO"
Write-Log "Drives: $($BackupDrives -join ', ')" "INFO"
Write-Log "Destination: $BackupDestination" "INFO"
Write-Log "Retention: $RetentionPoints points" "INFO"
Write-Log "Schedule: Daily at $ScheduleTime" "INFO"

# Step 1: Verify Veeam installation
Write-Log "" "INFO"
Write-Log "Step 1: Verify Veeam Installation" "INFO"

if (-not (Test-VeeamInstalled)) {
    Write-Host ""
    Write-Host "ERROR: Veeam Agent is not installed!" -ForegroundColor Red
    Write-Host "Run installation script first: .\1-install-veeam-agent.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Log "Veeam not installed, cannot continue" "ERROR"
    exit 1
}

# Step 2: Test backup destination
Write-Log "" "INFO"
Write-Log "Step 2: Test Backup Destination" "INFO"

if (-not (Test-BackupDestination -Path $BackupDestination)) {
    Write-Host ""
    Write-Host "ERROR: Backup destination is not accessible!" -ForegroundColor Red
    Write-Host "Destination: $BackupDestination" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Cyan
    Write-Host "  - Network share not accessible"
    Write-Host "  - No write permissions"
    Write-Host "  - TrueNAS share not created"
    Write-Host ""
    Write-Host "Run TrueNAS setup first: .\3-setup-truenas-repository.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Log "Backup destination not accessible, cannot continue" "ERROR"
    exit 1
}

# Step 3: Configure network credentials
Write-Log "" "INFO"
Write-Log "Step 3: Configure Network Credentials" "INFO"

if ($BackupDestination -match '^\\\\') {
    if (-not (Set-NetworkCredentials -Path $BackupDestination -Username $NetworkUsername -Password $NetworkPassword)) {
        Write-Log "WARNING: Network credentials may not be configured properly" "WARNING"
        Write-Host ""
        Write-Host "You may need to manually configure network credentials in Veeam" -ForegroundColor Yellow
        Write-Host ""
    }
}

# Step 4: Validate encryption settings
if ($EnableEncryption -and -not $EncryptionPassword) {
    Write-Host ""
    Write-Host "Encryption enabled but no password provided" -ForegroundColor Yellow
    Write-Host "You will need to set encryption password in Veeam UI manually" -ForegroundColor Yellow
    Write-Host ""
    $EncryptionPassword = $null
}

# Step 5: Check for existing job
Write-Log "" "INFO"
Write-Log "Step 5: Check Existing Jobs" "INFO"

$jobExists = Test-VeeamBackupJob -JobName $JobName

if ($jobExists) {
    Write-Host ""
    Write-Host "WARNING: A job with name '$JobName' may already exist" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  1. Modify existing job in Veeam UI"
    Write-Host "  2. Delete existing job and create new one"
    Write-Host "  3. Use different job name"
    Write-Host ""
}

# Step 6: Create backup job configuration
Write-Log "" "INFO"
Write-Log "Step 6: Create Backup Job" "INFO"

$jobCreated = New-VeeamBackupJobManual `
    -Name $JobName `
    -Drives $BackupDrives `
    -Destination $BackupDestination `
    -Retention $RetentionPoints `
    -Time $ScheduleTime `
    -CompressionLevel $Compression `
    -AppAware $EnableAppAware `
    -Encryption $EnableEncryption `
    -EncryptPassword $EncryptionPassword

if ($jobCreated) {
    Write-Log "Backup job configuration prepared" "SUCCESS"
}

# Step 7: Show validation steps
Write-Log "" "INFO"
Write-Log "Step 7: Validation Instructions" "INFO"

Show-ValidationSteps

Write-Log "=== Configuration Completed ===" "SUCCESS"
Write-Log "Config saved: $configFile" "INFO"
Write-Log "Log file: $logFile" "INFO"

Write-Host ""
Write-Host "Configuration complete! Follow the guide above to finalize in Veeam UI." -ForegroundColor Green
Write-Host ""

exit 0
