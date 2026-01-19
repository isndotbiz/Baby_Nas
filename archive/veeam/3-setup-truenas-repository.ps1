#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automated TrueNAS Veeam repository setup script

.DESCRIPTION
    Creates and configures Veeam backup repository on TrueNAS via API or SSH.
    Features:
    - Dataset creation with optimal properties for Veeam
    - SMB share configuration with proper permissions
    - Performance tuning for backup workloads
    - Compression and deduplication settings
    - Integration with existing TrueNAS infrastructure

.PARAMETER TrueNasIP
    IP address or hostname of TrueNAS server
    Default: 172.21.203.18

.PARAMETER TrueNasApiKey
    API key for TrueNAS authentication
    If not provided, will prompt or use SSH

.PARAMETER DatasetName
    Name for the Veeam backup dataset
    Default: veeam-backups

.PARAMETER PoolName
    ZFS pool to create dataset in
    Default: tank

.PARAMETER ShareName
    SMB share name
    Default: Veeam

.PARAMETER DatasetQuota
    Quota size for dataset (e.g., "500G", "1T")
    Default: None (unlimited)

.PARAMETER EnableCompression
    Enable ZFS compression
    Default: $true (lz4)

.PARAMETER EnableDedup
    Enable ZFS deduplication (NOT recommended for Veeam)
    Default: $false

.PARAMETER RecordSize
    ZFS recordsize (128k recommended for Veeam)
    Default: "128K"

.PARAMETER SmbUsername
    Username for SMB share access
    Default: veeam-user

.PARAMETER SmbPassword
    SecureString password for SMB user

.EXAMPLE
    .\3-setup-truenas-repository.ps1
    Interactive setup with defaults

.EXAMPLE
    .\3-setup-truenas-repository.ps1 -TrueNasIP "172.21.203.18" -DatasetQuota "1T"
    Setup with 1TB quota

.EXAMPLE
    .\3-setup-truenas-repository.ps1 -TrueNasApiKey "1-abc123..." -RecordSize "1M"
    Setup using API key with custom recordsize

.NOTES
    Author: Automated Veeam Deployment System
    Version: 1.0
    Requires: TrueNAS Scale or Core with API enabled
    Requires: PowerShell 5.1+ or PowerShell Core
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TrueNasIP = "172.21.203.18",

    [Parameter(Mandatory=$false)]
    [string]$TrueNasApiKey,

    [Parameter(Mandatory=$false)]
    [string]$DatasetName = "veeam-backups",

    [Parameter(Mandatory=$false)]
    [string]$PoolName = "tank",

    [Parameter(Mandatory=$false)]
    [string]$ShareName = "Veeam",

    [Parameter(Mandatory=$false)]
    [string]$DatasetQuota,

    [Parameter(Mandatory=$false)]
    [bool]$EnableCompression = $true,

    [Parameter(Mandatory=$false)]
    [bool]$EnableDedup = $false,

    [Parameter(Mandatory=$false)]
    [ValidateSet("128K", "256K", "512K", "1M")]
    [string]$RecordSize = "128K",

    [Parameter(Mandatory=$false)]
    [string]$SmbUsername = "veeam-user",

    [Parameter(Mandatory=$false)]
    [SecureString]$SmbPassword
)

# Configuration
$logDir = "C:\Logs\Veeam"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\truenas-repo-setup-$timestamp.log"
$configFile = "$logDir\truenas-repo-config.json"

# TrueNAS API configuration
$apiBase = "https://$TrueNasIP/api/v2.0"
$sshPort = 22

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

function Test-TrueNasConnectivity {
    param([string]$IP)

    Write-Log "Testing connectivity to TrueNAS: $IP" "INFO"

    # Test ping
    if (Test-Connection -ComputerName $IP -Count 2 -Quiet) {
        Write-Log "TrueNAS is reachable via ping" "SUCCESS"
    } else {
        Write-Log "WARNING: Cannot ping TrueNAS (may be normal if ICMP blocked)" "WARNING"
    }

    # Test SSH port
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($IP, $sshPort)
        $tcpClient.Close()
        Write-Log "SSH port ($sshPort) is open" "SUCCESS"
    } catch {
        Write-Log "WARNING: Cannot connect to SSH port $sshPort" "WARNING"
    }

    # Test API port (443)
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($IP, 443)
        $tcpClient.Close()
        Write-Log "HTTPS/API port (443) is open" "SUCCESS"
        return $true
    } catch {
        Write-Log "ERROR: Cannot connect to TrueNAS API port (443)" "ERROR"
        return $false
    }
}

function Test-TrueNasAPI {
    param([string]$ApiKey)

    Write-Log "Testing TrueNAS API connection..." "INFO"

    if (-not $ApiKey) {
        Write-Log "No API key provided, skipping API test" "WARNING"
        return $false
    }

    try {
        # Ignore SSL certificate errors for self-signed certs
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $response = Invoke-RestMethod -Uri "$apiBase/system/info" `
                -Method Get `
                -Headers @{ Authorization = "Bearer $ApiKey" } `
                -SkipCertificateCheck -ErrorAction Stop
        } else {
            # PowerShell 5.1 - ignore SSL
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            $response = Invoke-RestMethod -Uri "$apiBase/system/info" `
                -Method Get `
                -Headers @{ Authorization = "Bearer $ApiKey" } `
                -ErrorAction Stop
        }

        Write-Log "API connection successful" "SUCCESS"
        Write-Log "TrueNAS Version: $($response.version)" "INFO"
        Write-Log "Hostname: $($response.hostname)" "INFO"

        return $true

    } catch {
        Write-Log "ERROR: API connection failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-TrueNasApiKey {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " TRUENAS API KEY REQUIRED" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To create an API key in TrueNAS:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Open TrueNAS web interface: https://$TrueNasIP" -ForegroundColor White
    Write-Host "2. Log in with admin credentials" -ForegroundColor White
    Write-Host "3. Navigate to: Settings > API Keys" -ForegroundColor White
    Write-Host "4. Click 'Add' to create new API key" -ForegroundColor White
    Write-Host "5. Name: 'Veeam Automation'" -ForegroundColor White
    Write-Host "6. Copy the generated API key (starts with '1-')" -ForegroundColor White
    Write-Host ""
    Write-Host "Enter API key (or press Enter to use SSH instead): " -NoNewline -ForegroundColor Yellow

    $apiKey = Read-Host

    if ($apiKey) {
        Write-Log "API key provided by user" "INFO"
        return $apiKey
    } else {
        Write-Log "No API key provided, will use SSH method" "INFO"
        return $null
    }
}

function New-TrueNasDatasetSSH {
    param(
        [string]$IP,
        [string]$Pool,
        [string]$Dataset,
        [string]$RecordSize,
        [bool]$Compression,
        [bool]$Dedup,
        [string]$Quota
    )

    Write-Log "Creating dataset via SSH: $Pool/$Dataset" "INFO"

    # Build ZFS create command
    $datasetPath = "$Pool/$Dataset"
    $zfsCmd = "zfs create"

    # Set recordsize
    $zfsCmd += " -o recordsize=$RecordSize"

    # Set compression
    if ($Compression) {
        $zfsCmd += " -o compression=lz4"
    } else {
        $zfsCmd += " -o compression=off"
    }

    # Set deduplication
    if ($Dedup) {
        $zfsCmd += " -o dedup=on"
        Write-Log "WARNING: Deduplication enabled - not recommended for Veeam backups" "WARNING"
    } else {
        $zfsCmd += " -o dedup=off"
    }

    # Set atime off for performance
    $zfsCmd += " -o atime=off"

    # Set sync for better performance
    $zfsCmd += " -o sync=standard"

    # Add quota if specified
    if ($Quota) {
        $zfsCmd += " -o quota=$Quota"
    }

    # Add dataset path
    $zfsCmd += " $datasetPath"

    Write-Log "ZFS command: $zfsCmd" "INFO"

    # Show manual SSH instructions
    Show-SSHInstructions -Command $zfsCmd -Description "Create ZFS dataset"

    return $datasetPath
}

function New-TrueNasDatasetAPI {
    param(
        [string]$ApiKey,
        [string]$Pool,
        [string]$Dataset,
        [string]$RecordSize,
        [bool]$Compression,
        [bool]$Dedup,
        [string]$Quota
    )

    Write-Log "Creating dataset via API: $Pool/$Dataset" "INFO"

    try {
        $datasetPath = "$Pool/$Dataset"

        # Build dataset properties
        $properties = @{
            name = $datasetPath
            type = "FILESYSTEM"
            recordsize = $RecordSize
            atime = "OFF"
            sync = "STANDARD"
        }

        if ($Compression) {
            $properties.compression = "LZ4"
        } else {
            $properties.compression = "OFF"
        }

        if ($Dedup) {
            $properties.dedup = "ON"
            Write-Log "WARNING: Deduplication enabled - not recommended for Veeam" "WARNING"
        } else {
            $properties.dedup = "OFF"
        }

        if ($Quota) {
            $properties.quota = $Quota
        }

        $body = $properties | ConvertTo-Json

        Write-Log "API request body: $body" "INFO"

        # Create dataset
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $response = Invoke-RestMethod -Uri "$apiBase/pool/dataset" `
                -Method Post `
                -Headers @{ Authorization = "Bearer $ApiKey"; "Content-Type" = "application/json" } `
                -Body $body `
                -SkipCertificateCheck -ErrorAction Stop
        } else {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            $response = Invoke-RestMethod -Uri "$apiBase/pool/dataset" `
                -Method Post `
                -Headers @{ Authorization = "Bearer $ApiKey"; "Content-Type" = "application/json" } `
                -Body $body `
                -ErrorAction Stop
        }

        Write-Log "Dataset created successfully via API" "SUCCESS"
        Write-Log "Dataset path: $datasetPath" "INFO"

        return $datasetPath

    } catch {
        Write-Log "ERROR creating dataset via API: $($_.Exception.Message)" "ERROR"

        # Fall back to SSH instructions
        Write-Log "Falling back to SSH method..." "WARNING"
        return New-TrueNasDatasetSSH -IP $TrueNasIP -Pool $Pool -Dataset $Dataset -RecordSize $RecordSize -Compression $Compression -Dedup $Dedup -Quota $Quota
    }
}

function New-TrueNasSMBShareSSH {
    param(
        [string]$ShareName,
        [string]$DatasetPath,
        [string]$Username
    )

    Write-Log "Creating SMB share via SSH: $ShareName" "INFO"

    # Commands to create SMB share
    $commands = @"
# Create SMB share for Veeam backups

# 1. Enable SMB service (if not already)
midclt call smb.update '{"enable": true}'

# 2. Create SMB share
midclt call sharing.smb.create '{
  "name": "$ShareName",
  "path": "/mnt/$DatasetPath",
  "comment": "Veeam Backup Repository",
  "enabled": true,
  "guestok": false,
  "purpose": "NO_PRESET",
  "recyclebin": false,
  "abe": false,
  "hostsallow": [],
  "hostsdeny": []
}'

# 3. Set permissions on dataset
chmod 770 /mnt/$DatasetPath
chown $Username:$Username /mnt/$DatasetPath

# 4. Restart SMB service
midclt call service.restart smb

echo "SMB share created: $ShareName"
echo "Path: /mnt/$DatasetPath"
echo "Access: \\\\$TrueNasIP\\$ShareName"
"@

    Show-SSHInstructions -Command $commands -Description "Create SMB share"

    return "\\$TrueNasIP\$ShareName"
}

function New-TrueNasSMBShareAPI {
    param(
        [string]$ApiKey,
        [string]$ShareName,
        [string]$DatasetPath,
        [string]$Username
    )

    Write-Log "Creating SMB share via API: $ShareName" "INFO"

    try {
        # Build SMB share configuration
        $shareConfig = @{
            name = $ShareName
            path = "/mnt/$DatasetPath"
            comment = "Veeam Backup Repository - Automated Setup"
            enabled = $true
            guestok = $false
            purpose = "NO_PRESET"
            recyclebin = $false
            abe = $false
        }

        $body = $shareConfig | ConvertTo-Json

        Write-Log "Creating SMB share..." "INFO"

        # Create SMB share
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $response = Invoke-RestMethod -Uri "$apiBase/sharing/smb" `
                -Method Post `
                -Headers @{ Authorization = "Bearer $ApiKey"; "Content-Type" = "application/json" } `
                -Body $body `
                -SkipCertificateCheck -ErrorAction Stop
        } else {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            $response = Invoke-RestMethod -Uri "$apiBase/sharing/smb" `
                -Method Post `
                -Headers @{ Authorization = "Bearer $ApiKey"; "Content-Type" = "application/json" } `
                -Body $body `
                -ErrorAction Stop
        }

        Write-Log "SMB share created successfully" "SUCCESS"

        # Enable SMB service if not already enabled
        Write-Log "Ensuring SMB service is enabled..." "INFO"

        $smbConfig = @{ enable = $true } | ConvertTo-Json

        if ($PSVersionTable.PSVersion.Major -ge 6) {
            Invoke-RestMethod -Uri "$apiBase/smb" `
                -Method Put `
                -Headers @{ Authorization = "Bearer $ApiKey"; "Content-Type" = "application/json" } `
                -Body $smbConfig `
                -SkipCertificateCheck -ErrorAction SilentlyContinue | Out-Null
        } else {
            Invoke-RestMethod -Uri "$apiBase/smb" `
                -Method Put `
                -Headers @{ Authorization = "Bearer $ApiKey"; "Content-Type" = "application/json" } `
                -Body $smbConfig `
                -ErrorAction SilentlyContinue | Out-Null
        }

        $uncPath = "\\$TrueNasIP\$ShareName"
        Write-Log "SMB share accessible at: $uncPath" "SUCCESS"

        return $uncPath

    } catch {
        Write-Log "ERROR creating SMB share via API: $($_.Exception.Message)" "ERROR"
        Write-Log "Falling back to SSH method..." "WARNING"

        return New-TrueNasSMBShareSSH -ShareName $ShareName -DatasetPath $DatasetPath -Username $Username
    }
}

function Show-SSHInstructions {
    param(
        [string]$Command,
        [string]$Description
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host " SSH MANUAL CONFIGURATION REQUIRED" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Task: $Description" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Connect to TrueNAS via SSH:" -ForegroundColor Cyan
    Write-Host "   ssh root@$TrueNasIP" -ForegroundColor Green
    Write-Host ""
    Write-Host "2. Run the following commands:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host $Command -ForegroundColor Green
    Write-Host ""
    Write-Host "3. Press Enter here when complete..." -ForegroundColor Yellow

    Read-Host

    Write-Log "User indicated manual SSH configuration completed" "INFO"
}

function New-TrueNasSMBUser {
    param(
        [string]$Username,
        [SecureString]$Password
    )

    Write-Log "Creating TrueNAS user for SMB access: $Username" "INFO"

    if (-not $Password) {
        Write-Host ""
        Write-Host "Enter password for SMB user '$Username': " -NoNewline -ForegroundColor Yellow
        $Password = Read-Host -AsSecureString
        Write-Host ""
    }

    # Convert SecureString to plain text for display
    $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    )

    $commands = @"
# Create user for Veeam SMB access

# 1. Create user
midclt call user.create '{
  "username": "$Username",
  "full_name": "Veeam Backup User",
  "password": "$passwordPlain",
  "group_create": true,
  "home": "/nonexistent",
  "shell": "/usr/bin/nologin",
  "smb": true
}'

# 2. Verify user creation
id $Username

echo "User created: $Username"
"@

    Show-SSHInstructions -Command $commands -Description "Create SMB user"

    # Store credentials securely
    $credConfig = @{
        Username = $Username
        CreatedDate = (Get-Date).ToString()
        SharePath = "\\$TrueNasIP\$ShareName"
    }

    $credConfig | ConvertTo-Json | Out-File -FilePath "$logDir\truenas-smb-credentials.json"
    Write-Log "Credentials info saved to: $logDir\truenas-smb-credentials.json" "INFO"

    return $Username
}

function Test-TrueNasSMBShare {
    param(
        [string]$UncPath,
        [string]$Username,
        [SecureString]$Password
    )

    Write-Log "Testing SMB share access: $UncPath" "INFO"

    try {
        # Try to access share
        if (Test-Path $UncPath) {
            Write-Log "SMB share is accessible without authentication" "SUCCESS"
            return $true
        }

        # Try with credentials
        if ($Username -and $Password) {
            $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            )

            $netUseResult = net use $UncPath $passwordPlain /user:$Username 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Log "SMB share accessible with credentials" "SUCCESS"

                # Test write access
                $testFile = Join-Path $UncPath "veeam-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
                "test" | Out-File -FilePath $testFile
                Remove-Item -Path $testFile -Force

                Write-Log "Write access confirmed" "SUCCESS"
                return $true
            } else {
                Write-Log "ERROR: Cannot access SMB share with credentials" "ERROR"
                Write-Log "Output: $netUseResult" "ERROR"
                return $false
            }
        }

    } catch {
        Write-Log "ERROR testing SMB share: $($_.Exception.Message)" "ERROR"
        return $false
    }

    return $false
}

function Save-Configuration {
    param(
        [hashtable]$Config
    )

    Write-Log "Saving configuration to: $configFile" "INFO"

    try {
        $Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configFile -Force
        Write-Log "Configuration saved successfully" "SUCCESS"

        # Make configuration readable
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host " CONFIGURATION SUMMARY" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "TrueNAS Server:    $($Config.TrueNasIP)" -ForegroundColor White
        Write-Host "Dataset:           $($Config.DatasetPath)" -ForegroundColor White
        Write-Host "SMB Share:         $($Config.ShareName)" -ForegroundColor White
        Write-Host "UNC Path:          $($Config.UncPath)" -ForegroundColor Green
        Write-Host "SMB Username:      $($Config.SmbUsername)" -ForegroundColor White
        Write-Host "Record Size:       $($Config.RecordSize)" -ForegroundColor White
        Write-Host "Compression:       $($Config.Compression)" -ForegroundColor White
        Write-Host "Deduplication:     $($Config.Deduplication)" -ForegroundColor White
        if ($Config.Quota) {
            Write-Host "Quota:             $($Config.Quota)" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "Config saved to: $configFile" -ForegroundColor Cyan
        Write-Host ""

    } catch {
        Write-Log "WARNING: Could not save configuration: $($_.Exception.Message)" "WARNING"
    }
}

function Show-NextSteps {
    param([hashtable]$Config)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " REPOSITORY SETUP COMPLETE" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "VEEAM BACKUP DESTINATION:" -ForegroundColor Cyan
    Write-Host "  $($Config.UncPath)" -ForegroundColor Green
    Write-Host ""

    Write-Host "SMB CREDENTIALS:" -ForegroundColor Cyan
    Write-Host "  Username: $($Config.SmbUsername)" -ForegroundColor White
    Write-Host "  Password: [Set during user creation]" -ForegroundColor White
    Write-Host ""

    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Test SMB share access from Windows:" -ForegroundColor Yellow
    Write-Host "   net use $($Config.UncPath) /user:$($Config.SmbUsername) PASSWORD" -ForegroundColor Green
    Write-Host "   dir $($Config.UncPath)" -ForegroundColor Green
    Write-Host ""

    Write-Host "2. Configure Veeam backup job:" -ForegroundColor Yellow
    Write-Host "   .\2-configure-backup-jobs.ps1 -BackupDestination `"$($Config.UncPath)`"" -ForegroundColor Green
    Write-Host ""

    Write-Host "3. Verify TrueNAS dataset:" -ForegroundColor Yellow
    Write-Host "   - Check dataset properties: zfs get all $($Config.DatasetPath)" -ForegroundColor White
    Write-Host "   - Monitor space usage: zfs list $($Config.DatasetPath)" -ForegroundColor White
    Write-Host ""

    Write-Host "4. Setup replication coordination:" -ForegroundColor Yellow
    Write-Host "   .\6-integration-replication.ps1" -ForegroundColor Green
    Write-Host ""

    Write-Host "PERFORMANCE TIPS:" -ForegroundColor Cyan
    Write-Host "  - Dataset uses $($Config.RecordSize) recordsize (optimal for Veeam)" -ForegroundColor White
    Write-Host "  - Compression: $($Config.Compression) (reduces storage usage)" -ForegroundColor White
    Write-Host "  - Deduplication: $($Config.Deduplication) (off recommended for Veeam)" -ForegroundColor White
    Write-Host ""
}

# ===== MAIN EXECUTION =====

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " TRUENAS VEEAM REPOSITORY SETUP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== TrueNAS Veeam Repository Setup Started ===" "INFO"
Write-Log "TrueNAS IP: $TrueNasIP" "INFO"
Write-Log "Dataset: $PoolName/$DatasetName" "INFO"
Write-Log "Share Name: $ShareName" "INFO"

# Step 1: Test TrueNAS connectivity
Write-Log "" "INFO"
Write-Log "Step 1: Test TrueNAS Connectivity" "INFO"

if (-not (Test-TrueNasConnectivity -IP $TrueNasIP)) {
    Write-Host ""
    Write-Host "ERROR: Cannot connect to TrueNAS at $TrueNasIP" -ForegroundColor Red
    Write-Host "Please verify TrueNAS is running and network is accessible" -ForegroundColor Yellow
    Write-Host ""
    Write-Log "Cannot connect to TrueNAS, exiting" "ERROR"
    exit 1
}

# Step 2: Test API or get API key
Write-Log "" "INFO"
Write-Log "Step 2: API Authentication" "INFO"

$useAPI = $false

if ($TrueNasApiKey) {
    $useAPI = Test-TrueNasAPI -ApiKey $TrueNasApiKey
} else {
    $TrueNasApiKey = Get-TrueNasApiKey

    if ($TrueNasApiKey) {
        $useAPI = Test-TrueNasAPI -ApiKey $TrueNasApiKey
    }
}

if (-not $useAPI) {
    Write-Log "Will use SSH method for configuration" "INFO"
}

# Step 3: Create dataset
Write-Log "" "INFO"
Write-Log "Step 3: Create ZFS Dataset" "INFO"

$datasetPath = $null

if ($useAPI) {
    $datasetPath = New-TrueNasDatasetAPI `
        -ApiKey $TrueNasApiKey `
        -Pool $PoolName `
        -Dataset $DatasetName `
        -RecordSize $RecordSize `
        -Compression $EnableCompression `
        -Dedup $EnableDedup `
        -Quota $DatasetQuota
} else {
    $datasetPath = New-TrueNasDatasetSSH `
        -IP $TrueNasIP `
        -Pool $PoolName `
        -Dataset $DatasetName `
        -RecordSize $RecordSize `
        -Compression $EnableCompression `
        -Dedup $EnableDedup `
        -Quota $DatasetQuota
}

if (-not $datasetPath) {
    Write-Log "ERROR: Failed to create dataset" "ERROR"
    exit 1
}

# Step 4: Create SMB user
Write-Log "" "INFO"
Write-Log "Step 4: Create SMB User" "INFO"

$smbUser = New-TrueNasSMBUser -Username $SmbUsername -Password $SmbPassword

# Step 5: Create SMB share
Write-Log "" "INFO"
Write-Log "Step 5: Create SMB Share" "INFO"

$uncPath = $null

if ($useAPI) {
    $uncPath = New-TrueNasSMBShareAPI `
        -ApiKey $TrueNasApiKey `
        -ShareName $ShareName `
        -DatasetPath $datasetPath `
        -Username $smbUser
} else {
    $uncPath = New-TrueNasSMBShareSSH `
        -ShareName $ShareName `
        -DatasetPath $datasetPath `
        -Username $smbUser
}

if (-not $uncPath) {
    Write-Log "ERROR: Failed to create SMB share" "ERROR"
    exit 1
}

# Step 6: Test SMB share
Write-Log "" "INFO"
Write-Log "Step 6: Test SMB Share Access" "INFO"

Write-Host ""
Write-Host "Testing SMB share access..." -ForegroundColor Cyan
Write-Host "This may prompt for credentials if needed" -ForegroundColor Yellow
Write-Host ""

$shareAccessible = Test-TrueNasSMBShare -UncPath $uncPath -Username $smbUser -Password $SmbPassword

if ($shareAccessible) {
    Write-Log "SMB share is accessible and writable" "SUCCESS"
} else {
    Write-Log "WARNING: Could not verify SMB share access automatically" "WARNING"
    Write-Log "You may need to test manually" "WARNING"
}

# Step 7: Save configuration
Write-Log "" "INFO"
Write-Log "Step 7: Save Configuration" "INFO"

$config = @{
    TrueNasIP = $TrueNasIP
    DatasetPath = $datasetPath
    ShareName = $ShareName
    UncPath = $uncPath
    SmbUsername = $smbUser
    RecordSize = $RecordSize
    Compression = if ($EnableCompression) { "LZ4" } else { "OFF" }
    Deduplication = if ($EnableDedup) { "ON" } else { "OFF" }
    Quota = $DatasetQuota
    CreatedDate = (Get-Date).ToString()
}

Save-Configuration -Config $config

# Step 8: Show next steps
Show-NextSteps -Config $config

Write-Log "=== TrueNAS Repository Setup Completed ===" "SUCCESS"
Write-Log "Log file: $logFile" "INFO"

exit 0
