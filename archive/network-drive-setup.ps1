# Network Drive Mapping Automation
# Purpose: Map Baby NAS SMB shares to Windows drive letters with secure credential storage
# Run as: Administrator (for persistent mappings)
# Usage: .\network-drive-setup.ps1 -NASServer "babynas" -Username "admin"

<#
.SYNOPSIS
    Automated network drive mapping for Baby NAS SMB shares

.DESCRIPTION
    This script automates the mapping of network drives to Baby NAS SMB shares:
    - Maps W: to \\babynas\WindowsBackup
    - Maps V: to \\babynas\Veeam
    - Maps L: to \\babynas\WSLBackups (optional)
    - Stores credentials securely using Windows Credential Manager
    - Verifies connectivity before mapping
    - Sets persistence for automatic reconnection
    - Tests read/write access after mapping

.PARAMETER NASServer
    Name or IP address of the NAS server
    Default: babynas (10.0.0.89)

.PARAMETER Username
    Username for SMB authentication
    Default: Current Windows username

.PARAMETER Password
    Password for SMB authentication (as SecureString)
    If not provided, will prompt securely

.PARAMETER WindowsBackupDrive
    Drive letter for Windows Backup share
    Default: W:

.PARAMETER VeeamDrive
    Drive letter for Veeam share
    Default: V:

.PARAMETER WSLBackupDrive
    Drive letter for WSL Backup share
    Default: L:

.PARAMETER SkipWSLBackup
    Don't map WSL Backup share

.PARAMETER ForceRemap
    Force remapping even if drives already exist

.PARAMETER TestOnly
    Only test connectivity, don't create mappings

.EXAMPLE
    .\network-drive-setup.ps1
    Interactive setup with prompts

.EXAMPLE
    .\network-drive-setup.ps1 -NASServer "babynas" -Username "admin"
    Setup with specific server and username

.EXAMPLE
    .\network-drive-setup.ps1 -NASServer "10.0.0.89" -ForceRemap
    Force remap all drives using IP address

.EXAMPLE
    .\network-drive-setup.ps1 -TestOnly
    Test connectivity without creating mappings
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$NASServer = "babynas",

    [Parameter(Mandatory=$false)]
    [string]$Username = $env:USERNAME,

    [Parameter(Mandatory=$false)]
    [SecureString]$Password,

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^[A-Z]:$')]
    [string]$WindowsBackupDrive = "W:",

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^[A-Z]:$')]
    [string]$VeeamDrive = "V:",

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^[A-Z]:$')]
    [string]$WSLBackupDrive = "L:",

    [Parameter(Mandatory=$false)]
    [switch]$SkipWSLBackup,

    [Parameter(Mandatory=$false)]
    [switch]$ForceRemap,

    [Parameter(Mandatory=$false)]
    [switch]$TestOnly
)

# Create log directory
$logDir = "C:\Logs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\network-drive-setup-$timestamp.log"

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

function Test-NASConnectivity {
    param([string]$Server)

    Write-Log "Testing connectivity to NAS server: $Server" "INFO"

    # Try to resolve hostname
    try {
        $resolved = [System.Net.Dns]::GetHostEntry($Server)
        Write-Log "  Hostname resolved: $($resolved.AddressList[0].IPAddressToString)" "SUCCESS"
    } catch {
        Write-Log "  Cannot resolve hostname: $Server" "WARNING"
        Write-Log "  Will attempt direct connection anyway..." "INFO"
    }

    # Test ping
    Write-Log "  Testing ICMP ping..." "INFO"
    if (Test-Connection -ComputerName $Server -Count 2 -Quiet) {
        Write-Log "  Ping successful" "SUCCESS"
    } else {
        Write-Log "  Ping failed (may be normal if ICMP is blocked)" "WARNING"
    }

    # Test SMB port (445)
    Write-Log "  Testing SMB port (445)..." "INFO"
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connection = $tcpClient.BeginConnect($Server, 445, $null, $null)
        $wait = $connection.AsyncWaitHandle.WaitOne(3000, $false)

        if ($wait) {
            $tcpClient.EndConnect($connection)
            $tcpClient.Close()
            Write-Log "  SMB port 445 is open" "SUCCESS"
            return $true
        } else {
            $tcpClient.Close()
            Write-Log "  SMB port 445 is not accessible" "ERROR"
            return $false
        }
    } catch {
        Write-Log "  Cannot connect to SMB port: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-SecureCredential {
    param(
        [string]$Server,
        [string]$Username,
        [SecureString]$Password
    )

    Write-Log "Preparing credentials..." "INFO"

    # If password not provided, check Credential Manager first
    if (-not $Password) {
        Write-Log "  Checking Windows Credential Manager..." "INFO"

        try {
            # Try to get stored credential
            $targetName = "MicrosoftAccount:target=termsrv/$Server"
            $storedCred = cmdkey /list:$targetName 2>&1

            if ($storedCred -match $Server) {
                Write-Log "  Found stored credentials for $Server" "SUCCESS"
                Write-Host ""
                Write-Host "Use stored credentials? (Y/N): " -NoNewline -ForegroundColor Yellow
                $useStored = Read-Host

                if ($useStored -eq 'Y' -or $useStored -eq 'y') {
                    Write-Log "  Using stored credentials" "INFO"
                    return $null # Will use stored creds with net use
                }
            }
        } catch {
            Write-Log "  No stored credentials found" "INFO"
        }

        # Prompt for password
        Write-Host ""
        Write-Host "Enter password for $Username@$Server" -ForegroundColor Yellow
        $Password = Read-Host -AsSecureString "Password"
    }

    # Create PSCredential object
    $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)

    return $credential
}

function Save-CredentialToManager {
    param(
        [string]$Server,
        [string]$Username,
        [string]$Password
    )

    Write-Log "Saving credentials to Windows Credential Manager..." "INFO"

    try {
        # Use cmdkey to store credential
        $targetName = "$Server"
        $result = cmdkey /add:$targetName /user:$Username /pass:$Password 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "  Credentials saved successfully" "SUCCESS"
            return $true
        } else {
            Write-Log "  Failed to save credentials: $result" "WARNING"
            return $false
        }
    } catch {
        Write-Log "  Error saving credentials: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function Test-DriveLetterAvailable {
    param([string]$DriveLetter)

    $drive = $DriveLetter.TrimEnd(':')
    $existing = Get-PSDrive -Name $drive -ErrorAction SilentlyContinue

    if ($existing) {
        Write-Log "  Drive $DriveLetter is already in use" "WARNING"
        Write-Log "  Current mapping: $($existing.DisplayRoot)" "INFO"
        return $false
    } else {
        Write-Log "  Drive $DriveLetter is available" "SUCCESS"
        return $true
    }
}

function Remove-ExistingDriveMapping {
    param([string]$DriveLetter)

    $drive = $DriveLetter.TrimEnd(':')

    Write-Log "  Removing existing mapping for $DriveLetter..." "INFO"

    try {
        # Try PowerShell method
        Remove-PSDrive -Name $drive -Force -ErrorAction SilentlyContinue

        # Try net use method
        $result = net use "$DriveLetter" /delete /yes 2>&1

        Write-Log "  Existing mapping removed" "SUCCESS"
        Start-Sleep -Seconds 1
        return $true

    } catch {
        Write-Log "  Error removing mapping: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function New-NetworkDriveMapping {
    param(
        [string]$DriveLetter,
        [string]$UNCPath,
        [string]$Username,
        [string]$Password,
        [bool]$Persistent = $true
    )

    Write-Log "Mapping $DriveLetter to $UNCPath..." "INFO"

    try {
        # Check if drive letter is already mapped
        if (-not (Test-DriveLetterAvailable -DriveLetter $DriveLetter)) {
            if ($ForceRemap) {
                Remove-ExistingDriveMapping -DriveLetter $DriveLetter
            } else {
                Write-Log "  Drive already mapped. Use -ForceRemap to override" "WARNING"
                return $false
            }
        }

        # Build net use command
        $netUseCmd = "net use $DriveLetter $UNCPath"

        if ($Password) {
            $netUseCmd += " $Password /user:$Username"
        }

        if ($Persistent) {
            $netUseCmd += " /persistent:yes"
        }

        # Execute mapping
        Write-Log "  Executing network drive mapping..." "INFO"
        $result = Invoke-Expression "$netUseCmd 2>&1"

        if ($LASTEXITCODE -eq 0) {
            Write-Log "  Drive mapped successfully" "SUCCESS"

            # Verify mapping
            Start-Sleep -Seconds 1
            if (Test-Path $DriveLetter) {
                Write-Log "  Verified: Drive is accessible" "SUCCESS"
                return $true
            } else {
                Write-Log "  WARNING: Drive mapped but not accessible" "WARNING"
                return $false
            }
        } else {
            Write-Log "  Mapping failed: $result" "ERROR"
            return $false
        }

    } catch {
        Write-Log "  Error mapping drive: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-DriveAccess {
    param(
        [string]$DriveLetter,
        [string]$Description
    )

    Write-Log "Testing access to $Description ($DriveLetter)..." "INFO"

    $drive = $DriveLetter.TrimEnd(':') + ":"

    # Test read access
    try {
        $items = Get-ChildItem $drive -ErrorAction Stop | Select-Object -First 5
        Write-Log "  Read access: OK" "SUCCESS"

        # Test write access
        $testFile = Join-Path $drive "access-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
        try {
            "test" | Out-File -FilePath $testFile -ErrorAction Stop
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            Write-Log "  Write access: OK" "SUCCESS"
            return $true
        } catch {
            Write-Log "  Write access: FAILED - $($_.Exception.Message)" "WARNING"
            return $false
        }

    } catch {
        Write-Log "  Read access: FAILED - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Show-MappedDrives {
    Write-Log "Current network drive mappings:" "INFO"

    try {
        $mappings = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -match '^\\\\' }

        if ($mappings) {
            foreach ($mapping in $mappings) {
                Write-Log "  $($mapping.Name): $($mapping.DisplayRoot)" "INFO"
            }
        } else {
            Write-Log "  No network drives currently mapped" "INFO"
        }
    } catch {
        Write-Log "  Error listing mapped drives: $($_.Exception.Message)" "WARNING"
    }
}

# ===== MAIN SCRIPT EXECUTION =====

Write-Log "================================================" "INFO"
Write-Log "=== Network Drive Setup Script Started ===" "INFO"
Write-Log "================================================" "INFO"
Write-Log "NAS Server: $NASServer" "INFO"
Write-Log "Username: $Username" "INFO"
Write-Log "Windows Backup Drive: $WindowsBackupDrive" "INFO"
Write-Log "Veeam Drive: $VeeamDrive" "INFO"
Write-Log "WSL Backup Drive: $(if($SkipWSLBackup){'Skipped'}else{$WSLBackupDrive})" "INFO"
Write-Log "Test Only Mode: $TestOnly" "INFO"

# Step 1: Show current mappings
Write-Log "" "INFO"
Write-Log "=== Current Drive Mappings ===" "INFO"
Show-MappedDrives

# Step 2: Test NAS connectivity
Write-Log "" "INFO"
Write-Log "=== Testing NAS Connectivity ===" "INFO"

if (-not (Test-NASConnectivity -Server $NASServer)) {
    Write-Log "Cannot connect to NAS server: $NASServer" "ERROR"
    Write-Log "" "INFO"
    Write-Log "TROUBLESHOOTING STEPS:" "INFO"
    Write-Log "1. Verify NAS server is powered on" "INFO"
    Write-Log "2. Check network connectivity (cable/WiFi)" "INFO"
    Write-Log "3. Try using IP address instead: 10.0.0.89" "INFO"
    Write-Log "4. Verify SMB services are running on NAS" "INFO"
    Write-Log "5. Check Windows Firewall settings" "INFO"
    Write-Log "" "INFO"
    Write-Log "Log file: $logFile" "INFO"
    exit 1
}

if ($TestOnly) {
    Write-Log "" "INFO"
    Write-Log "Test Only mode - connectivity verified, exiting" "SUCCESS"
    Write-Log "Log file: $logFile" "INFO"
    exit 0
}

# Step 3: Get credentials
Write-Log "" "INFO"
Write-Log "=== Credential Configuration ===" "INFO"

$credential = Get-SecureCredential -Server $NASServer -Username $Username -Password $Password

$plainPassword = $null
if ($credential) {
    $plainPassword = $credential.GetNetworkCredential().Password
}

# Step 4: Map drives
Write-Log "" "INFO"
Write-Log "=== Creating Drive Mappings ===" "INFO"

$mappedDrives = @()

# Map Windows Backup share
Write-Log "" "INFO"
Write-Log "--- Windows Backup Share ---" "INFO"
$windowsBackupUNC = "\\$NASServer\WindowsBackup"
if (New-NetworkDriveMapping -DriveLetter $WindowsBackupDrive -UNCPath $windowsBackupUNC -Username $Username -Password $plainPassword) {
    if (Test-DriveAccess -DriveLetter $WindowsBackupDrive -Description "Windows Backup") {
        $mappedDrives += @{Drive=$WindowsBackupDrive; Path=$windowsBackupUNC; Status="OK"}
    } else {
        $mappedDrives += @{Drive=$WindowsBackupDrive; Path=$windowsBackupUNC; Status="Mapped but access issues"}
    }
} else {
    $mappedDrives += @{Drive=$WindowsBackupDrive; Path=$windowsBackupUNC; Status="Failed"}
}

# Map Veeam share
Write-Log "" "INFO"
Write-Log "--- Veeam Backup Share ---" "INFO"
$veeamUNC = "\\$NASServer\Veeam"
if (New-NetworkDriveMapping -DriveLetter $VeeamDrive -UNCPath $veeamUNC -Username $Username -Password $plainPassword) {
    if (Test-DriveAccess -DriveLetter $VeeamDrive -Description "Veeam Backup") {
        $mappedDrives += @{Drive=$VeeamDrive; Path=$veeamUNC; Status="OK"}
    } else {
        $mappedDrives += @{Drive=$VeeamDrive; Path=$veeamUNC; Status="Mapped but access issues"}
    }
} else {
    $mappedDrives += @{Drive=$VeeamDrive; Path=$veeamUNC; Status="Failed"}
}

# Map WSL Backup share (optional)
if (-not $SkipWSLBackup) {
    Write-Log "" "INFO"
    Write-Log "--- WSL Backup Share ---" "INFO"
    $wslBackupUNC = "\\$NASServer\WSLBackups"
    if (New-NetworkDriveMapping -DriveLetter $WSLBackupDrive -UNCPath $wslBackupUNC -Username $Username -Password $plainPassword) {
        if (Test-DriveAccess -DriveLetter $WSLBackupDrive -Description "WSL Backup") {
            $mappedDrives += @{Drive=$WSLBackupDrive; Path=$wslBackupUNC; Status="OK"}
        } else {
            $mappedDrives += @{Drive=$WSLBackupDrive; Path=$wslBackupUNC; Status="Mapped but access issues"}
        }
    } else {
        $mappedDrives += @{Drive=$WSLBackupDrive; Path=$wslBackupUNC; Status="Failed"}
    }
}

# Step 5: Save credentials to Credential Manager
if ($plainPassword -and $credential) {
    Write-Log "" "INFO"
    Write-Log "=== Saving Credentials ===" "INFO"
    Save-CredentialToManager -Server $NASServer -Username $Username -Password $plainPassword
}

# Step 6: Summary
Write-Log "" "INFO"
Write-Log "================================================" "INFO"
Write-Log "=== Setup Summary ===" "INFO"
Write-Log "================================================" "INFO"

$successCount = ($mappedDrives | Where-Object { $_.Status -eq "OK" }).Count
$failCount = ($mappedDrives | Where-Object { $_.Status -eq "Failed" }).Count

foreach ($drive in $mappedDrives) {
    $statusColor = switch ($drive.Status) {
        "OK" { "SUCCESS" }
        "Failed" { "ERROR" }
        default { "WARNING" }
    }
    Write-Log "$($drive.Drive) -> $($drive.Path): $($drive.Status)" $statusColor
}

Write-Log "" "INFO"
Write-Log "Successful mappings: $successCount" $(if($successCount -gt 0){"SUCCESS"}else{"INFO"})
Write-Log "Failed mappings: $failCount" $(if($failCount -gt 0){"ERROR"}else{"INFO"})

# Show final mapped drives
Write-Log "" "INFO"
Write-Log "=== Final Drive Mappings ===" "INFO"
Show-MappedDrives

Write-Log "" "INFO"
Write-Log "NEXT STEPS:" "INFO"
Write-Log "1. Verify drives appear in Windows Explorer" "INFO"
Write-Log "2. Configure Veeam to use $VeeamDrive for backups" "INFO"
Write-Log "3. Update backup scripts to use mapped drives" "INFO"
Write-Log "4. Test backup operations" "INFO"
Write-Log "" "INFO"
Write-Log "Log file: $logFile" "INFO"
Write-Log "================================================" "INFO"
Write-Log "=== Network Drive Setup Script Completed ===" $(if($failCount -eq 0){"SUCCESS"}else{"WARNING"})
Write-Log "================================================" "INFO"

# Exit with appropriate code
if ($failCount -gt 0) {
    exit 1
} else {
    exit 0
}
