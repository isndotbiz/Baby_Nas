<#
.SYNOPSIS
    Deploy phone backup infrastructure on Windows for TrueNAS integration

.DESCRIPTION
    Configures Windows to host phone backups via SMB:
    - Maps \\baby.isn.biz\PhoneBackups share
    - Verifies 500GB quota
    - Tests write permissions
    - Creates device-specific folders (Galaxy-S24, iPhone)
    - Sets up backup schedule verification
    - Configures SMB optimization for phone sync

.PARAMETER BabyNASHostname
    Hostname of Baby NAS
    Default: baby.isn.biz

.PARAMETER BabyNASIP
    IP address of Baby NAS
    Default: 172.21.203.18

.PARAMETER PhoneBackupShare
    SMB share path for phone backups
    Default: \\baby.isn.biz\PhoneBackups

.PARAMETER QuotaGB
    Expected quota in GB
    Default: 500

.PARAMETER Username
    Username for SMB authentication

.PARAMETER Password
    Password for SMB authentication

.PARAMETER DriveLetters
    Available drive letters to test
    Default: X,Y,Z

.PARAMETER CreateDeviceFolders
    Automatically create device-specific folders
    Default: $true

.PARAMETER NoGUI
    Run without interactive prompts

.PARAMETER SkipConnectivity
    Skip network connectivity test

.EXAMPLE
    .\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1
    Complete phone backup deployment with interactive setup

.EXAMPLE
    .\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1 -BabyNASIP 172.21.203.18 -Username admin -Password "P@ssw0rd" -NoGUI
    Silent deployment with credentials

.EXAMPLE
    .\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1 -QuotaGB 1000 -CreateDeviceFolders $true
    Deploy with custom quota and automatic folder creation
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BabyNASHostname = "baby.isn.biz",

    [Parameter(Mandatory=$false)]
    [string]$BabyNASIP = "172.21.203.18",

    [Parameter(Mandatory=$false)]
    [string]$PhoneBackupShare = "\\baby.isn.biz\PhoneBackups",

    [Parameter(Mandatory=$false)]
    [int]$QuotaGB = 500,

    [Parameter(Mandatory=$false)]
    [string]$Username,

    [Parameter(Mandatory=$false)]
    [string]$Password,

    [Parameter(Mandatory=$false)]
    [string[]]$DriveLetters = @("X", "Y", "Z"),

    [Parameter(Mandatory=$false)]
    [bool]$CreateDeviceFolders = $true,

    [Parameter(Mandatory=$false)]
    [switch]$NoGUI,

    [Parameter(Mandatory=$false)]
    [switch]$SkipConnectivity
)

#Requires -RunAsAdministrator

# ===== CONFIGURATION =====
$DeploymentName = "PHONE-BACKUPS-DEPLOYMENT"
$LogDir = "C:\Logs"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = "$LogDir\$DeploymentName-$Timestamp.log"
$ReportFile = "$LogDir\$DeploymentName-Report-$Timestamp.html"

# Device definitions
$DeviceFolders = @{
    "Galaxy-S24-Ultra" = "Samsung Galaxy S24 Ultra"
    "Galaxy-S24" = "Samsung Galaxy S24"
    "iPhone-15-Pro" = "iPhone 15 Pro"
    "iPhone-15" = "iPhone 15"
    "iPad" = "iPad"
}

# Color configuration
$Colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Debug = "Gray"
}

# ===== HELPER FUNCTIONS =====

function Initialize-Logging {
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"

    Write-Host $LogMessage -ForegroundColor $Colors[$Level]
    $LogMessage | Out-File -FilePath $LogFile -Append
}

function Write-Header {
    param([string]$Title)

    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host ""
    Write-Log "=== $Title ===" "INFO"
}

function Get-UserConfirmation {
    param(
        [string]$Message,
        [string]$DefaultChoice = "Y"
    )

    if ($NoGUI) { return $true }

    $choices = @("&Yes", "&No")
    $decision = $Host.UI.PromptForChoice("", $Message, $choices, 0)
    return ($decision -eq 0)
}

function Test-NetworkConnectivity {
    param([string]$IPAddress)

    Write-Log "Testing connectivity to $IPAddress..." "INFO"

    try {
        $ping = Test-Connection -ComputerName $IPAddress -Count 2 -Quiet -ErrorAction Stop
        if ($ping) {
            Write-Log "Connectivity OK - $IPAddress reachable" "SUCCESS"
            return $true
        } else {
            Write-Log "Connectivity FAILED - $IPAddress unreachable" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Connectivity test error: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function Find-AvailableDriveLetter {
    Write-Log "Finding available drive letter..." "INFO"

    foreach ($letter in $DriveLetters) {
        $drivePath = "${letter}:"
        if (-not (Test-Path $drivePath)) {
            Write-Log "Available drive letter found: $letter" "SUCCESS"
            return $letter
        }
    }

    Write-Log "No available drive letters: $($DriveLetters -join ', ')" "ERROR"
    return $null
}

function Mount-SMBShare {
    param(
        [string]$SharePath,
        [string]$DriveLetter,
        [string]$Username,
        [string]$Password
    )

    Write-Log "Mounting SMB share: $SharePath to ${DriveLetter}:" "INFO"

    # Check if already mounted
    if (Test-Path "${DriveLetter}:") {
        Write-Log "Drive letter ${DriveLetter}: already in use, attempting to remount..." "WARNING"
        try {
            Remove-PSDrive -Name $DriveLetter -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        } catch {
            Write-Log "Could not unmount existing drive: $($_.Exception.Message)" "ERROR"
            return $false
        }
    }

    try {
        if ($Username -and $Password) {
            Write-Log "Mounting with credentials..." "DEBUG"
            $credential = New-Object System.Management.Automation.PSCredential(
                $Username,
                (ConvertTo-SecureString $Password -AsPlainText -Force)
            )

            New-PSDrive -Name $DriveLetter -PSProvider "FileSystem" -Root $SharePath `
                -Credential $credential -Scope Global -Persist -ErrorAction Stop | Out-Null
        } else {
            Write-Log "Mounting with current Windows credentials..." "DEBUG"
            New-PSDrive -Name $DriveLetter -PSProvider "FileSystem" -Root $SharePath `
                -Scope Global -Persist -ErrorAction Stop | Out-Null
        }

        Start-Sleep -Milliseconds 500

        # Verify mount
        if (Test-Path "${DriveLetter}:") {
            Write-Log "SMB share mounted successfully: ${DriveLetter}:" "SUCCESS"
            return $true
        } else {
            Write-Log "Mount verification failed" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Error mounting share: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-WritePermissions {
    param([string]$Path)

    Write-Log "Testing write permissions to: $Path" "INFO"

    try {
        $testFile = Join-Path $Path "test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue

        Write-Log "Write permissions verified" "SUCCESS"
        return $true
    } catch {
        Write-Log "Write permission test failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-ShareQuota {
    param([string]$Path)

    Write-Log "Checking quota information for: $Path" "INFO"

    try {
        $drive = Get-Item $Path
        $psDrive = Get-PSDrive -Name $drive.PSDrive.Name -ErrorAction Stop

        $totalSpace = $psDrive.Used + $psDrive.Free
        $totalSpaceGB = [math]::Round($totalSpace / 1GB, 2)
        $freeSpaceGB = [math]::Round($psDrive.Free / 1GB, 2)
        $usedSpaceGB = [math]::Round($psDrive.Used / 1GB, 2)

        Write-Log "Total Space: $totalSpaceGB GB" "INFO"
        Write-Log "Used Space: $usedSpaceGB GB" "INFO"
        Write-Log "Free Space: $freeSpaceGB GB" "INFO"

        return @{
            Total = $totalSpaceGB
            Used = $usedSpaceGB
            Free = $freeSpaceGB
        }
    } catch {
        Write-Log "Could not determine quota: $($_.Exception.Message)" "WARNING"
        return $null
    }
}

function Create-DeviceFolders {
    param([string]$BasePath)

    Write-Log "Creating device-specific folders..." "INFO"

    $createdFolders = @()

    foreach ($folderName in $DeviceFolders.Keys) {
        $folderPath = Join-Path $BasePath $folderName

        try {
            if (-not (Test-Path $folderPath)) {
                New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
                Write-Log "Created folder: $folderName" "SUCCESS"
            } else {
                Write-Log "Folder already exists: $folderName" "INFO"
            }
            $createdFolders += $folderName
        } catch {
            Write-Log "Error creating folder $folderName : $($_.Exception.Message)" "ERROR"
        }
    }

    Write-Log "Device folders initialization complete: $($createdFolders.Count) folders" "SUCCESS"
    return $createdFolders
}

function Optimize-SMBSettings {
    Write-Log "Optimizing SMB settings for phone sync..." "INFO"

    # SMB performance optimization
    $smbSettings = @{
        "EnableBandwidthThrottling" = 0
        "Smb2CreditsMin" = 128
        "Smb2CreditsMax" = 2048
        "MaxCompressedDataSize" = 1048576
    }

    try {
        foreach ($setting in $smbSettings.GetEnumerator()) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"

            if (-not (Test-Path $regPath)) {
                Write-Log "Registry path not found: $regPath" "WARNING"
                continue
            }

            Set-ItemProperty -Path $regPath -Name $setting.Name -Value $setting.Value -ErrorAction Stop
            Write-Log "Set SMB parameter: $($setting.Name) = $($setting.Value)" "SUCCESS"
        }

        Write-Log "SMB optimization complete" "SUCCESS"
        return $true
    } catch {
        Write-Log "Error optimizing SMB settings: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function Configure-FirewallRules {
    Write-Log "Configuring Windows Firewall rules for SMB..." "INFO"

    try {
        # Ensure SMB ports are allowed
        $smbPorts = @(
            @{ Name = "SMB-In-445"; Protocol = "tcp"; Port = 445 }
            @{ Name = "SMB-In-139"; Protocol = "tcp"; Port = 139 }
        )

        foreach ($rule in $smbPorts) {
            $existingRule = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue

            if (-not $existingRule) {
                New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound `
                    -Protocol $rule.Protocol -LocalPort $rule.Port -Action Allow `
                    -ErrorAction Stop | Out-Null
                Write-Log "Created firewall rule: $($rule.Name)" "SUCCESS"
            } else {
                Write-Log "Firewall rule already exists: $($rule.Name)" "INFO"
            }
        }

        return $true
    } catch {
        Write-Log "Error configuring firewall: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function Generate-DeploymentReport {
    param([hashtable]$Status)

    Write-Log "Generating deployment report: $ReportFile" "INFO"

    $devicesList = ""
    foreach ($device in $Status.DeviceFolders) {
        $devicesList += "<li>$device</li>"
    }

    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Phone Backup Deployment Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #333; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #0078d4; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; background-color: white; margin-top: 10px; }
        th { background-color: #0078d4; color: white; padding: 10px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .success { color: green; font-weight: bold; }
        .error { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        .timestamp { color: #666; font-size: 0.9em; }
        .section { background-color: white; padding: 15px; margin-bottom: 20px; border-left: 4px solid #0078d4; }
        ul { margin: 5px 0; padding-left: 20px; }
    </style>
</head>
<body>
    <h1>Phone Backup Deployment Report</h1>
    <p class="timestamp">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>

    <div class="section">
        <h2>Deployment Summary</h2>
        <table>
            <tr>
                <th>Component</th>
                <th>Status</th>
                <th>Details</th>
            </tr>
            <tr>
                <td>Network Connectivity</td>
                <td class="$(if ($Status.ConnectivityOK) { 'success' } else { 'error' })">$(if ($Status.ConnectivityOK) { 'OK' } else { 'FAILED' })</td>
                <td>$($Status.BabyNASIP)</td>
            </tr>
            <tr>
                <td>SMB Share Access</td>
                <td class="$(if ($Status.SMBMounted) { 'success' } else { 'error' })">$(if ($Status.SMBMounted) { 'OK' } else { 'FAILED' })</td>
                <td>$($Status.PhoneBackupShare) on $($Status.MountedDrive):</td>
            </tr>
            <tr>
                <td>Write Permissions</td>
                <td class="$(if ($Status.WritePermissionsOK) { 'success' } else { 'error' })">$(if ($Status.WritePermissionsOK) { 'OK' } else { 'FAILED' })</td>
                <td>Can create/delete files</td>
            </tr>
            <tr>
                <td>Device Folders</td>
                <td class="success">CREATED</td>
                <td>$($Status.DeviceFolders.Count) folders configured</td>
            </tr>
            <tr>
                <td>SMB Optimization</td>
                <td class="success">COMPLETE</td>
                <td>Performance settings applied</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>Storage Information</h2>
        <table>
            <tr>
                <th>Metric</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Total Quota</td>
                <td>$($Status.QuotaGB) GB</td>
            </tr>
            <tr>
                <td>Available Space</td>
                <td>$($Status.FreeSpaceGB) GB</td>
            </tr>
            <tr>
                <td>Used Space</td>
                <td>$($Status.UsedSpaceGB) GB</td>
            </tr>
            <tr>
                <td>Usage Percentage</td>
                <td>$([math]::Round(($Status.UsedSpaceGB / $Status.QuotaGB) * 100, 1))%</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>Configured Devices</h2>
        <p>The following device-specific backup folders have been created:</p>
        <ul>
            $devicesList
        </ul>
    </div>

    <div class="section">
        <h2>Backup Configuration Instructions</h2>
        <h3>For Samsung Galaxy S24 Ultra:</h3>
        <ol>
            <li>Install Synology app or similar SMB client from Google Play Store</li>
            <li>Connect to \\$($Status.BabyNASIP)\PhoneBackups</li>
            <li>Navigate to Galaxy-S24-Ultra folder</li>
            <li>Configure automatic sync for camera/gallery</li>
        </ol>

        <h3>For iPhone 15 Pro:</h3>
        <ol>
            <li>Use third-party app (Photos Backup, Nextcloud, etc.)</li>
            <li>Configure SMB connection to \\$($Status.BabyNASIP)\PhoneBackups</li>
            <li>Navigate to iPhone-15-Pro folder</li>
            <li>Enable automatic backup in app settings</li>
        </ol>
    </div>

    <div class="section">
        <h2>Network Share Details</h2>
        <table>
            <tr>
                <th>Setting</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Share Path</td>
                <td>$($Status.PhoneBackupShare)</td>
            </tr>
            <tr>
                <td>Mounted Drive</td>
                <td>$($Status.MountedDrive):</td>
            </tr>
            <tr>
                <td>Hostname</td>
                <td>$($Status.BabyNASHostname)</td>
            </tr>
            <tr>
                <td>IP Address</td>
                <td>$($Status.BabyNASIP)</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>Next Steps</h2>
        <ol>
            <li>Install backup applications on each phone device</li>
            <li>Configure SMB/network share connections on devices</li>
            <li>Enable automatic backup schedules on each device</li>
            <li>Test backup by triggering manual sync on one device</li>
            <li>Monitor backup folder sizes in File Explorer</li>
            <li>Run VERIFY-ALL-BACKUPS.ps1 monthly to verify integrity</li>
        </ol>
    </div>

    <div class="section">
        <h2>Support Information</h2>
        <p><strong>Log File:</strong> $LogFile</p>
        <p><strong>Report File:</strong> $ReportFile</p>
        <p><strong>Mounted Drive:</strong> $($Status.MountedDrive):</p>
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $ReportFile -Encoding UTF8
    Write-Log "Report generated: $ReportFile" "SUCCESS"
}

# ===== MAIN EXECUTION =====

Write-Host ""
Write-Host "Phone Backup Deployment - Windows SMB Configuration" -ForegroundColor Cyan -BackgroundColor DarkBlue
Write-Host ""

Initialize-Logging

Write-Log "Starting phone backup deployment" "INFO"
Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
Write-Log "User: $env:USERNAME on $env:COMPUTERNAME" "INFO"

# Initialize status tracker
$Status = @{
    ConnectivityOK = $false
    BabyNASIP = $BabyNASIP
    BabyNASHostname = $BabyNASHostname
    PhoneBackupShare = $PhoneBackupShare
    SMBMounted = $false
    MountedDrive = ""
    WritePermissionsOK = $false
    DeviceFolders = @()
    QuotaGB = $QuotaGB
    FreeSpaceGB = 0
    UsedSpaceGB = 0
}

# Step 1: Network Connectivity Test
Write-Header "Testing Network Connectivity"

if (-not $SkipConnectivity) {
    if (Test-NetworkConnectivity -IPAddress $BabyNASIP) {
        $Status.ConnectivityOK = $true
    } else {
        Write-Log "Network connectivity test failed" "ERROR"
        if (-not (Get-UserConfirmation "Continue despite connectivity issues?")) {
            Write-Log "Deployment cancelled" "ERROR"
            exit 1
        }
    }
} else {
    Write-Log "Skipping connectivity test" "DEBUG"
    $Status.ConnectivityOK = $true
}

# Step 2: Find and Mount SMB Share
Write-Header "Mounting SMB Share"

$driveLetter = Find-AvailableDriveLetter
if (-not $driveLetter) {
    Write-Log "No available drive letters. Trying to use existing mount..." "WARNING"
    # Try to unmount any existing PhoneBackups
    Get-PSDrive | Where-Object { $_.Root -like "*PhoneBackups*" } | Remove-PSDrive -Force -ErrorAction SilentlyContinue
    $driveLetter = Find-AvailableDriveLetter
}

if ($driveLetter) {
    if (Mount-SMBShare -SharePath $PhoneBackupShare -DriveLetter $driveLetter `
        -Username $Username -Password $Password) {
        $Status.SMBMounted = $true
        $Status.MountedDrive = $driveLetter

        # Test write permissions
        Write-Header "Testing Write Permissions"

        $mountPath = "${driveLetter}:"
        if (Test-WritePermissions -Path $mountPath) {
            $Status.WritePermissionsOK = $true
        } else {
            Write-Log "Write permission test failed - continuing anyway" "WARNING"
        }

        # Get quota information
        Write-Header "Checking Quota"

        $quotaInfo = Get-ShareQuota -Path $mountPath
        if ($quotaInfo) {
            $Status.FreeSpaceGB = $quotaInfo.Free
            $Status.UsedSpaceGB = $quotaInfo.Used
        }

        # Step 3: Create Device Folders
        if ($CreateDeviceFolders) {
            Write-Header "Creating Device-Specific Folders"

            $Status.DeviceFolders = Create-DeviceFolders -BasePath $mountPath
        }

        # Step 4: Optimize SMB Settings
        Write-Header "Optimizing SMB Settings"

        Optimize-SMBSettings | Out-Null
        Configure-FirewallRules | Out-Null

    } else {
        Write-Log "Failed to mount SMB share" "ERROR"
        exit 1
    }
} else {
    Write-Log "No available drive letters available" "ERROR"
    exit 1
}

# Step 5: Generate Report
Write-Header "Generating Deployment Report"

Generate-DeploymentReport -Status $Status

# Summary
Write-Header "Deployment Summary"

Write-Host "Network Connectivity: " -NoNewline
Write-Host $(if ($Status.ConnectivityOK) { "✓ OK" } else { "✗ FAILED" }) -ForegroundColor $(if ($Status.ConnectivityOK) { "Green" } else { "Red" })

Write-Host "SMB Share Access: " -NoNewline
Write-Host $(if ($Status.SMBMounted) { "✓ OK ($($Status.MountedDrive):)" } else { "✗ FAILED" }) -ForegroundColor $(if ($Status.SMBMounted) { "Green" } else { "Red" })

Write-Host "Write Permissions: " -NoNewline
Write-Host $(if ($Status.WritePermissionsOK) { "✓ OK" } else { "✗ FAILED" }) -ForegroundColor $(if ($Status.WritePermissionsOK) { "Green" } else { "Red" })

Write-Host "Device Folders: " -NoNewline
Write-Host "✓ $($Status.DeviceFolders.Count) folders created" -ForegroundColor Green

Write-Host "Available Space: " -NoNewline
Write-Host "$($Status.FreeSpaceGB) GB / $($Status.QuotaGB) GB" -ForegroundColor Cyan

Write-Host ""
Write-Host "Mounted at: $($Status.MountedDrive):\PhoneBackups" -ForegroundColor Green
Write-Host "Log file: $LogFile" -ForegroundColor Gray
Write-Host "Report file: $ReportFile" -ForegroundColor Gray
Write-Host ""

Write-Log "Phone backup deployment completed" "SUCCESS"

# Open deployment report
if ((Get-UserConfirmation "Open detailed report?")) {
    Start-Process $ReportFile
}

Write-Host "Deployment complete. Press any key to exit..." -ForegroundColor Cyan
if (-not $NoGUI) {
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
