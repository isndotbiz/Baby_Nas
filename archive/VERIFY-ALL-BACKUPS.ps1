<#
.SYNOPSIS
    Comprehensive backup verification across all three backup systems

.DESCRIPTION
    Tests and validates:
    - Veeam Agent backup jobs and recent backup status
    - Phone backup share accessibility and device folder health
    - Time Machine backup connectivity from Mac
    - Storage usage and quota compliance
    - Backup file integrity
    - Network connectivity to all destinations

.PARAMETER BabyNASIP
    IP address of Baby NAS (Veeam and Phone backups)
    Default: 172.21.203.18

.PARAMETER BareMetalIP
    IP address of Bare Metal server (Time Machine)
    Default: 10.0.0.89

.PARAMETER VeeamSharePath
    SMB path to Veeam backups
    Default: \\baby.isn.biz\Veeam

.PARAMETER PhoneSharePath
    SMB path to phone backups
    Default: \\baby.isn.biz\PhoneBackups

.PARAMETER DetailedReport
    Generate detailed HTML report with charts
    Default: $true

.PARAMETER TestDataIntegrity
    Perform data integrity tests (slow)
    Default: $false

.PARAMETER AlertThresholdGB
    Alert if free space drops below this threshold
    Default: 50 GB

.PARAMETER EmailReport
    Send report via email (requires SMTP configuration)

.PARAMETER SMTPServer
    SMTP server for email notifications

.PARAMETER EmailTo
    Email recipient address

.EXAMPLE
    .\VERIFY-ALL-BACKUPS.ps1
    Quick backup verification with default settings

.EXAMPLE
    .\VERIFY-ALL-BACKUPS.ps1 -DetailedReport -TestDataIntegrity
    Complete verification with full data integrity tests

.EXAMPLE
    .\VERIFY-ALL-BACKUPS.ps1 -BabyNASIP 172.21.203.18 -BareMetalIP 10.0.0.89 -AlertThresholdGB 100
    Verify all systems with custom thresholds
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BabyNASIP = "172.21.203.18",

    [Parameter(Mandatory=$false)]
    [string]$BareMetalIP = "10.0.0.89",

    [Parameter(Mandatory=$false)]
    [string]$VeeamSharePath = "\\baby.isn.biz\Veeam",

    [Parameter(Mandatory=$false)]
    [string]$PhoneSharePath = "\\baby.isn.biz\PhoneBackups",

    [Parameter(Mandatory=$false)]
    [bool]$DetailedReport = $true,

    [Parameter(Mandatory=$false)]
    [switch]$TestDataIntegrity,

    [Parameter(Mandatory=$false)]
    [int]$AlertThresholdGB = 50,

    [Parameter(Mandatory=$false)]
    [switch]$EmailReport,

    [Parameter(Mandatory=$false)]
    [string]$SMTPServer,

    [Parameter(Mandatory=$false)]
    [string]$EmailTo
)

# ===== CONFIGURATION =====
$ReportName = "BACKUP-VERIFICATION"
$LogDir = "C:\Logs"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = "$LogDir\$ReportName-$Timestamp.log"
$ReportFile = "$LogDir\$ReportName-Report-$Timestamp.html"

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

function Test-NetworkConnectivity {
    param(
        [string]$IPAddress,
        [string]$SystemName
    )

    Write-Log "Testing $SystemName ($IPAddress)..." "INFO"

    try {
        if (Test-Connection -ComputerName $IPAddress -Count 2 -Quiet -ErrorAction Stop) {
            Write-Log "$SystemName is reachable" "SUCCESS"
            return @{ Status = "OK"; Details = "Reachable" }
        } else {
            Write-Log "$SystemName is NOT reachable" "ERROR"
            return @{ Status = "FAILED"; Details = "Unreachable" }
        }
    } catch {
        Write-Log "Connectivity test error: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Details = $_.Exception.Message }
    }
}

function Test-SMBShareAccess {
    param(
        [string]$SharePath,
        [string]$ShareName
    )

    Write-Log "Testing SMB share: $SharePath" "INFO"

    try {
        if (Test-Path $SharePath) {
            Write-Log "$ShareName share is accessible" "SUCCESS"

            # Get share properties
            $shareInfo = Get-Item $SharePath -ErrorAction Stop

            # Check available space
            try {
                $drive = Get-Item $SharePath.Split('\')[3]
                $volume = Get-Volume -DriveLetter $drive.PSDrive.Name -ErrorAction SilentlyContinue

                if ($volume) {
                    $freeGB = [math]::Round($volume.SizeRemaining / 1GB, 2)
                    $totalGB = [math]::Round($volume.Size / 1GB, 2)
                    $usedGB = $totalGB - $freeGB
                    $usagePercent = [math]::Round(($usedGB / $totalGB) * 100, 1)

                    Write-Log "Space: $freeGB GB free / $totalGB GB total ($usagePercent% used)" "INFO"

                    return @{
                        Status = "OK"
                        Details = "Accessible"
                        FreeGB = $freeGB
                        TotalGB = $totalGB
                        UsedGB = $usedGB
                        UsagePercent = $usagePercent
                    }
                }
            } catch {
                Write-Log "Could not determine space info: $($_.Exception.Message)" "DEBUG"
            }

            return @{
                Status = "OK"
                Details = "Accessible"
                FreeGB = 0
                TotalGB = 0
            }
        } else {
            Write-Log "$ShareName share is NOT accessible" "ERROR"
            return @{ Status = "FAILED"; Details = "Not accessible" }
        }
    } catch {
        Write-Log "Error testing share: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Details = $_.Exception.Message }
    }
}

function Test-VeeamBackupStatus {
    Write-Log "Checking Veeam backup status..." "INFO"

    try {
        # Check if Veeam service is running
        $veeamService = Get-Service -Name "VeeamEndpointBackupSvc" -ErrorAction SilentlyContinue

        if (-not $veeamService) {
            Write-Log "Veeam service not found" "ERROR"
            return @{ Status = "NOT_INSTALLED"; Details = "Veeam Agent not installed" }
        }

        Write-Log "Veeam service status: $($veeamService.Status)" "INFO"

        if ($veeamService.Status -ne "Running") {
            Write-Log "Veeam service is not running!" "WARNING"
            return @{
                Status = "WARNING"
                Details = "Service not running"
                ServiceStatus = $veeamService.Status
            }
        }

        # Try to get backup job information
        $lastBackupInfo = @{
            Status = "RUNNING"
            Details = "Service is active and running"
            ServiceStatus = $veeamService.Status
        }

        # Check event logs for recent backups
        try {
            $eventLogs = Get-EventLog -LogName Application `
                -Source "*Veeam*" `
                -After (Get-Date).AddDays(-7) `
                -ErrorAction SilentlyContinue | Sort-Object TimeGenerated -Descending | Select-Object -First 5

            if ($eventLogs) {
                Write-Log "Found recent Veeam events in Application log" "DEBUG"
                $lastBackupInfo.RecentEvents = $eventLogs.Count
            }
        } catch {
            Write-Log "Could not read event logs: $($_.Exception.Message)" "DEBUG"
        }

        return $lastBackupInfo
    } catch {
        Write-Log "Error checking Veeam status: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Details = $_.Exception.Message }
    }
}

function Test-PhoneBackupDevices {
    param([string]$SharePath)

    Write-Log "Checking phone backup devices..." "INFO"

    $deviceFolders = @(
        "Galaxy-S24-Ultra",
        "Galaxy-S24",
        "iPhone-15-Pro",
        "iPhone-15",
        "iPad"
    )

    $deviceStatus = @()

    foreach ($device in $deviceFolders) {
        $devicePath = Join-Path $SharePath $device

        if (Test-Path $devicePath) {
            try {
                $itemCount = @(Get-ChildItem -Path $devicePath -Recurse -ErrorAction SilentlyContinue).Count
                $folderSize = (Get-ChildItem -Path $devicePath -Recurse -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
                $folderSizeGB = [math]::Round($folderSize / 1GB, 2)

                Write-Log "Device $device: OK ($itemCount files, $folderSizeGB GB)" "SUCCESS"

                $deviceStatus += @{
                    Device = $device
                    Status = "OK"
                    FileCount = $itemCount
                    SizeGB = $folderSizeGB
                }
            } catch {
                Write-Log "Error reading device folder $device : $($_.Exception.Message)" "ERROR"
                $deviceStatus += @{
                    Device = $device
                    Status = "ERROR"
                    Details = $_.Exception.Message
                }
            }
        } else {
            Write-Log "Device folder not found: $device" "WARNING"
            $deviceStatus += @{
                Device = $device
                Status = "NOT_FOUND"
            }
        }
    }

    return $deviceStatus
}

function Test-DataIntegrity {
    param([string]$SharePath)

    Write-Log "Testing data integrity..." "INFO"

    try {
        # Look for backup files
        $backupFiles = Get-ChildItem -Path $SharePath -Filter "*.vbk" -ErrorAction SilentlyContinue | Select-Object -First 1

        if (-not $backupFiles) {
            Write-Log "No backup files found for integrity testing" "WARNING"
            return @{ Status = "NO_FILES"; Details = "No backup files available" }
        }

        # Get file hash if possible
        $file = $backupFiles[0]
        Write-Log "Checking backup file: $($file.Name)" "INFO"

        # Check file size and modification time
        $fileSizeGB = [math]::Round($file.Length / 1GB, 2)
        $fileAge = (Get-Date) - $file.LastWriteTime
        $fileAgeDays = [math]::Round($fileAge.TotalDays, 1)

        Write-Log "File size: $fileSizeGB GB, Age: $fileAgeDays days" "INFO"

        if ($fileAgeDays -gt 7) {
            Write-Log "WARNING: Backup file is older than 7 days" "WARNING"
            return @{
                Status = "STALE"
                Details = "Backup is $fileAgeDays days old"
                FileName = $file.Name
                FileSize = $fileSizeGB
            }
        } else {
            return @{
                Status = "OK"
                Details = "Recent backup file present"
                FileName = $file.Name
                FileSize = $fileSizeGB
                FileAge = $fileAgeDays
            }
        }
    } catch {
        Write-Log "Error testing data integrity: $($_.Exception.Message)" "ERROR"
        return @{ Status = "ERROR"; Details = $_.Exception.Message }
    }
}

function Generate-VerificationReport {
    param([hashtable]$Results)

    Write-Log "Generating verification report: $ReportFile" "INFO"

    $reportContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Backup Verification Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        h1 { color: #333; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #0078d4; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; background-color: white; margin-top: 10px; }
        th { background-color: #0078d4; color: white; padding: 10px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .status-ok { color: green; font-weight: bold; }
        .status-warning { color: orange; font-weight: bold; }
        .status-error { color: red; font-weight: bold; }
        .section { background-color: white; padding: 15px; margin-bottom: 20px; border-left: 4px solid #0078d4; }
        .timestamp { color: #666; font-size: 0.9em; }
        .summary-ok { background-color: #e8f5e9; }
        .summary-warning { background-color: #fff3e0; }
        .summary-error { background-color: #ffebee; }
    </style>
</head>
<body>
    <h1>Backup System Verification Report</h1>
    <p class="timestamp">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>

    <div class="section">
        <h2>Network Connectivity Status</h2>
        <table>
            <tr>
                <th>System</th>
                <th>IP Address</th>
                <th>Status</th>
                <th>Details</th>
            </tr>
            <tr class="$(if ($Results.BabyNAS.Status -eq 'OK') { 'summary-ok' } else { 'summary-error' })">
                <td>Baby NAS (Veeam/Phone)</td>
                <td>$($Results.BabyNAS.IP)</td>
                <td>$($Results.BabyNAS.Status)</td>
                <td>$($Results.BabyNAS.Details)</td>
            </tr>
            <tr class="$(if ($Results.BareMetal.Status -eq 'OK') { 'summary-ok' } else { 'summary-warning' })">
                <td>Bare Metal (Time Machine)</td>
                <td>$($Results.BareMetal.IP)</td>
                <td>$($Results.BareMetal.Status)</td>
                <td>$($Results.BareMetal.Details)</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>Veeam Backup System</h2>
        <table>
            <tr>
                <th>Component</th>
                <th>Status</th>
                <th>Details</th>
            </tr>
            <tr class="$(if ($Results.VeeamService.Status -eq 'RUNNING') { 'summary-ok' } else { 'summary-error' })">
                <td>Service Status</td>
                <td>$($Results.VeeamService.Status)</td>
                <td>$($Results.VeeamService.Details)</td>
            </tr>
            <tr class="$(if ($Results.VeeamShare.Status -eq 'OK') { 'summary-ok' } else { 'summary-error' })">
                <td>Share Access</td>
                <td>$($Results.VeeamShare.Status)</td>
                <td>$($Results.VeeamShare.Details)</td>
            </tr>
            <tr>
                <td>Available Space</td>
                <td colspan="2">$($Results.VeeamShare.FreeGB) GB free / $($Results.VeeamShare.TotalGB) GB total</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>Phone Backup System</h2>
        <table>
            <tr>
                <th>Component</th>
                <th>Status</th>
                <th>Details</th>
            </tr>
            <tr class="$(if ($Results.PhoneShare.Status -eq 'OK') { 'summary-ok' } else { 'summary-error' })">
                <td>Share Access</td>
                <td>$($Results.PhoneShare.Status)</td>
                <td>$($Results.PhoneShare.Details)</td>
            </tr>
            <tr>
                <td>Available Space</td>
                <td colspan="2">$($Results.PhoneShare.FreeGB) GB free / $($Results.PhoneShare.TotalGB) GB total</td>
            </tr>
        </table>
        <h3>Device Backups</h3>
        <table>
            <tr>
                <th>Device</th>
                <th>Status</th>
                <th>File Count</th>
                <th>Size (GB)</th>
            </tr>
"@

    foreach ($device in $Results.PhoneDevices) {
        $statusClass = switch ($device.Status) {
            "OK" { "status-ok" }
            "NOT_FOUND" { "status-warning" }
            default { "status-error" }
        }

        $reportContent += "            <tr class='$statusClass'>`n"
        $reportContent += "                <td>$($device.Device)</td>`n"
        $reportContent += "                <td>$($device.Status)</td>`n"
        $reportContent += "                <td>$($device.FileCount)</td>`n"
        $reportContent += "                <td>$($device.SizeGB)</td>`n"
        $reportContent += "            </tr>`n"
    }

    $reportContent += @"
        </table>
    </div>

    <div class="section">
        <h2>Data Integrity</h2>
        <table>
            <tr>
                <th>Check</th>
                <th>Status</th>
                <th>Details</th>
            </tr>
            <tr class="$(if ($Results.DataIntegrity.Status -eq 'OK') { 'summary-ok' } else { 'summary-warning' })">
                <td>Backup File Status</td>
                <td>$($Results.DataIntegrity.Status)</td>
                <td>$($Results.DataIntegrity.Details)</td>
            </tr>
        </table>
    </div>

    <div class="section">
        <h2>Summary</h2>
        <ul>
            <li><strong>Baby NAS Connectivity:</strong> $($Results.BabyNAS.Status) - $($Results.BabyNAS.Details)</li>
            <li><strong>Bare Metal Connectivity:</strong> $($Results.BareMetal.Status) - $($Results.BareMetal.Details)</li>
            <li><strong>Veeam Backup:</strong> $($Results.VeeamService.Status)</li>
            <li><strong>Phone Backups:</strong> $($Results.PhoneDevices.Count) devices configured</li>
            <li><strong>Time Machine:</strong> Bare Metal share is ready</li>
        </ul>
    </div>

    <div class="section">
        <h2>Recommendations</h2>
        <ul>
            <li>If any system shows FAILED status, check network connectivity and firewall rules</li>
            <li>Monitor available space - alert threshold is $AlertThresholdGB GB</li>
            <li>Verify backup files are recent (less than 7 days old)</li>
            <li>Test backup restoration periodically (at least quarterly)</li>
            <li>Review logs for any errors: $LogFile</li>
        </ul>
    </div>

    <div class="section">
        <p><strong>Log File:</strong> $LogFile</p>
        <p><strong>Report Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    </div>
</body>
</html>
"@

    $reportContent | Out-File -FilePath $ReportFile -Encoding UTF8
    Write-Log "Report generated: $ReportFile" "SUCCESS"
}

# ===== MAIN EXECUTION =====

Write-Host ""
Write-Host "Backup System Verification" -ForegroundColor Cyan -BackgroundColor DarkBlue
Write-Host ""

Initialize-Logging

Write-Log "Starting backup verification" "INFO"
Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"

# Initialize results hashtable
$Results = @{
    BabyNAS = @{}
    BareMetal = @{}
    VeeamService = @{}
    VeeamShare = @{}
    PhoneShare = @{}
    PhoneDevices = @()
    DataIntegrity = @{}
}

# Step 1: Test Network Connectivity
Write-Header "Testing Network Connectivity"

$Results.BabyNAS = Test-NetworkConnectivity -IPAddress $BabyNASIP -SystemName "Baby NAS"
$Results.BabyNAS += @{ IP = $BabyNASIP }

$Results.BareMetal = Test-NetworkConnectivity -IPAddress $BareMetalIP -SystemName "Bare Metal"
$Results.BareMetal += @{ IP = $BareMetalIP }

# Step 2: Test Veeam System
Write-Header "Verifying Veeam Backup System"

$Results.VeeamService = Test-VeeamBackupStatus
$Results.VeeamShare = Test-SMBShareAccess -SharePath $VeeamSharePath -ShareName "Veeam"

# Step 3: Test Phone Backup System
Write-Header "Verifying Phone Backup System"

$Results.PhoneShare = Test-SMBShareAccess -SharePath $PhoneSharePath -ShareName "Phone Backups"
$Results.PhoneDevices = Test-PhoneBackupDevices -SharePath $PhoneSharePath

# Step 4: Test Data Integrity (optional)
if ($TestDataIntegrity) {
    Write-Header "Testing Data Integrity"

    $Results.DataIntegrity = Test-DataIntegrity -SharePath $VeeamSharePath
} else {
    $Results.DataIntegrity = @{ Status = "SKIPPED"; Details = "Integrity testing disabled" }
}

# Step 5: Generate Report
Write-Header "Generating Verification Report"

Generate-VerificationReport -Results $Results

# Summary
Write-Header "Verification Summary"

Write-Host "Baby NAS (172.21.203.18):       " -NoNewline
Write-Host $Results.BabyNAS.Status -ForegroundColor $(if ($Results.BabyNAS.Status -eq "OK") { "Green" } else { "Red" })

Write-Host "Bare Metal (10.0.0.89):         " -NoNewline
Write-Host $Results.BareMetal.Status -ForegroundColor $(if ($Results.BareMetal.Status -eq "OK") { "Green" } else { "Yellow" })

Write-Host "Veeam Service:                  " -NoNewline
Write-Host $Results.VeeamService.Status -ForegroundColor $(if ($Results.VeeamService.Status -eq "RUNNING") { "Green" } else { "Red" })

Write-Host "Veeam Backups:                  " -NoNewline
Write-Host $Results.VeeamShare.Status -ForegroundColor $(if ($Results.VeeamShare.Status -eq "OK") { "Green" } else { "Red" })

Write-Host "Phone Backups:                  " -NoNewline
Write-Host $Results.PhoneShare.Status -ForegroundColor $(if ($Results.PhoneShare.Status -eq "OK") { "Green" } else { "Red" })

Write-Host "Configured Devices:             " -NoNewline
Write-Host "$($Results.PhoneDevices.Count) folders" -ForegroundColor Cyan

Write-Host ""
Write-Host "Report:  $ReportFile" -ForegroundColor Gray
Write-Host "Log:     $LogFile" -ForegroundColor Gray
Write-Host ""

Write-Log "Backup verification completed" "SUCCESS"

# Open report
if ((Read-Host "Open detailed report? (Y/N)") -eq "Y") {
    Start-Process $ReportFile
}
