#Requires -RunAsAdministrator
###############################################################################
# Daily Health Check Script
# Purpose: Run comprehensive health checks and generate daily report
# Usage: .\daily-health-check.ps1 [-SendEmail] [-EmailTo <email>]
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$BabyNasIP = "",

    [Parameter(Mandatory=$false)]
    [string]$MainNasIP = "10.0.0.89",

    [Parameter(Mandatory=$false)]
    [switch]$SendEmail,

    [Parameter(Mandatory=$false)]
    [string]$EmailTo = "",

    [Parameter(Mandatory=$false)]
    [string]$SMTPServer = "smtp.gmail.com",

    [Parameter(Mandatory=$false)]
    [int]$SMTPPort = 587,

    [Parameter(Mandatory=$false)]
    [string]$EmailFrom = "",

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\daily-health-checks"
)

$ErrorActionPreference = "Continue"

###############################################################################
# CONFIGURATION
###############################################################################

# Health check thresholds
$thresholds = @{
    BackupAgeHours = 28          # Max hours since last backup
    DiskSpacePercent = 20         # Min free space percentage
    PoolCapacityPercent = 85      # Max pool capacity percentage
    SnapshotMinCount = 10         # Minimum snapshot count
    ReplicationMaxAgeHours = 26   # Max hours since last replication
}

###############################################################################
# FUNCTIONS
###############################################################################

function Write-HealthLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR','SECTION')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8

    # Write to console with color
    $color = switch ($Level) {
        'INFO'    { 'White' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        'SECTION' { 'Cyan' }
    }

    if ($Level -eq 'SECTION') {
        Write-Host ""
        Write-Host "═══ $Message ═══" -ForegroundColor $color
    } else {
        $symbol = switch ($Level) {
            'SUCCESS' { '✓' }
            'WARNING' { '⚠' }
            'ERROR'   { '✗' }
            default   { ' ' }
        }
        Write-Host "$symbol $Message" -ForegroundColor $color
    }
}

function Get-HealthStatus {
    param(
        [int]$ErrorCount,
        [int]$WarningCount
    )

    if ($ErrorCount -gt 0) { return "CRITICAL" }
    if ($WarningCount -gt 0) { return "WARNING" }
    return "HEALTHY"
}

function Test-BabyNasConnection {
    param([string]$IP)

    return Test-Connection -ComputerName $IP -Count 2 -Quiet -ErrorAction SilentlyContinue
}

function Get-VMStatus {
    try {
        $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1
        return $vm
    } catch {
        return $null
    }
}

function Get-PoolInfo {
    param(
        [string]$IP,
        [string]$PoolName
    )

    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        if (-not (Test-Path $sshKey)) {
            $sshKey = "$env:USERPROFILE\.ssh\truenas_admin_10_0_0_89"
        }

        if (Test-Path $sshKey) {
            $sshArgs = @("-i", $sshKey, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5", "root@$IP", "zpool status $PoolName")
            $output = & ssh @sshArgs 2>$null
            return $output
        }
    } catch {}

    return $null
}

function Get-SnapshotCount {
    param(
        [string]$IP,
        [string]$Dataset
    )

    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        if (Test-Path $sshKey) {
            $sshArgs = @("-i", $sshKey, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5", "root@$IP", "zfs list -t snapshot -r $Dataset | wc -l")
            $output = & ssh @sshArgs 2>$null
            return [int]($output -replace '[^\d]','')
        }
    } catch {}

    return 0
}

###############################################################################
# MAIN SCRIPT
###############################################################################

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                    Daily Health Check Report                             ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "Health Check Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Create log directory
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $LogPath "health-check-$timestamp.log"

Write-HealthLog "=== Daily Health Check Started ===" -Level SECTION

# Initialize counters
$checks = @{
    Total = 0
    Passed = 0
    Warnings = 0
    Errors = 0
}

$issues = @{
    Critical = @()
    Warnings = @()
}

###############################################################################
# AUTO-DETECT BABY NAS IP
###############################################################################

if ([string]::IsNullOrEmpty($BabyNasIP)) {
    Write-HealthLog "Auto-detecting Baby NAS IP..." -Level INFO

    $vm = Get-VMStatus
    if ($vm) {
        $vmNet = Get-VMNetworkAdapter -VM $vm
        if ($vmNet.IPAddresses) {
            $BabyNasIP = ($vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
        }
    }

    if ([string]::IsNullOrEmpty($BabyNasIP)) {
        Write-HealthLog "Baby NAS IP not detected - some checks will be skipped" -Level WARNING
        $checks.Warnings++
        $issues.Warnings += "Baby NAS IP not detected"
    } else {
        Write-HealthLog "Baby NAS IP: $BabyNasIP" -Level SUCCESS
    }
}

###############################################################################
# CHECK 1: HYPER-V VM STATUS
###############################################################################

Write-HealthLog "Hyper-V VM Status" -Level SECTION
$checks.Total++

$vm = Get-VMStatus

if ($vm) {
    if ($vm.State -eq "Running") {
        Write-HealthLog "VM '$($vm.Name)' is Running" -Level SUCCESS
        Write-HealthLog "Uptime: $($vm.Uptime.ToString('dd\.hh\:mm\:ss'))" -Level INFO
        Write-HealthLog "CPU: $($vm.CPUUsage)% | Memory: $([math]::Round($vm.MemoryAssigned/1GB, 2)) GB" -Level INFO
        $checks.Passed++

        # Check auto-start
        if ($vm.AutomaticStartAction -ne "Start") {
            Write-HealthLog "Auto-start not configured" -Level WARNING
            $checks.Warnings++
            $issues.Warnings += "VM auto-start not configured"
        }
    } else {
        Write-HealthLog "VM is not running (State: $($vm.State))" -Level ERROR
        $checks.Errors++
        $issues.Critical += "Baby NAS VM is not running"
    }
} else {
    Write-HealthLog "Baby NAS VM not found" -Level ERROR
    $checks.Errors++
    $issues.Critical += "Baby NAS VM not found in Hyper-V"
}

###############################################################################
# CHECK 2: NETWORK CONNECTIVITY
###############################################################################

Write-HealthLog "Network Connectivity" -Level SECTION
$checks.Total += 2

# Baby NAS
if (-not [string]::IsNullOrEmpty($BabyNasIP)) {
    if (Test-BabyNasConnection -IP $BabyNasIP) {
        Write-HealthLog "Baby NAS reachable at $BabyNasIP" -Level SUCCESS
        $checks.Passed++
    } else {
        Write-HealthLog "Baby NAS unreachable at $BabyNasIP" -Level ERROR
        $checks.Errors++
        $issues.Critical += "Baby NAS not responding to ping"
    }
}

# Main NAS
if (Test-Connection -ComputerName $MainNasIP -Count 2 -Quiet -ErrorAction SilentlyContinue) {
    Write-HealthLog "Main NAS reachable at $MainNasIP" -Level SUCCESS
    $checks.Passed++
} else {
    Write-HealthLog "Main NAS unreachable at $MainNasIP" -Level WARNING
    $checks.Warnings++
    $issues.Warnings += "Main NAS not responding (replication may fail)"
}

###############################################################################
# CHECK 3: POOL HEALTH
###############################################################################

Write-HealthLog "Storage Pool Health" -Level SECTION

# Baby NAS Pool
if (-not [string]::IsNullOrEmpty($BabyNasIP)) {
    $checks.Total++
    $poolStatus = Get-PoolInfo -IP $BabyNasIP -PoolName "tank"

    if ($poolStatus) {
        if ($poolStatus -match "state:\s+ONLINE") {
            Write-HealthLog "Baby NAS Pool 'tank': ONLINE" -Level SUCCESS
            $checks.Passed++

            # Check capacity
            if ($poolStatus -match 'cap\s+(\d+)%') {
                $capacity = [int]$Matches[1]
                if ($capacity -ge $thresholds.PoolCapacityPercent) {
                    Write-HealthLog "Pool capacity high: ${capacity}%" -Level WARNING
                    $checks.Warnings++
                    $issues.Warnings += "Baby NAS pool capacity at ${capacity}%"
                } else {
                    Write-HealthLog "Pool capacity: ${capacity}%" -Level SUCCESS
                }
            }
        } elseif ($poolStatus -match "state:\s+DEGRADED") {
            Write-HealthLog "Baby NAS Pool 'tank': DEGRADED" -Level ERROR
            $checks.Errors++
            $issues.Critical += "Baby NAS pool is degraded"
        } else {
            Write-HealthLog "Baby NAS Pool 'tank': UNKNOWN STATE" -Level ERROR
            $checks.Errors++
            $issues.Critical += "Baby NAS pool in unknown state"
        }
    } else {
        Write-HealthLog "Cannot query Baby NAS pool status" -Level WARNING
        $checks.Warnings++
    }
}

# Main NAS Pools
$checks.Total += 2
$mainPoolStatus = Get-PoolInfo -IP $MainNasIP -PoolName "tank"
if ($mainPoolStatus -and $mainPoolStatus -match "state:\s+ONLINE") {
    Write-HealthLog "Main NAS Pool 'tank': ONLINE" -Level SUCCESS
    $checks.Passed++
} else {
    Write-HealthLog "Main NAS Pool 'tank': Check manually" -Level WARNING
    $checks.Warnings++
}

$backupPoolStatus = Get-PoolInfo -IP $MainNasIP -PoolName "backup"
if ($backupPoolStatus -and $backupPoolStatus -match "state:\s+ONLINE") {
    Write-HealthLog "Main NAS Pool 'backup': ONLINE" -Level SUCCESS
    $checks.Passed++

    if ($backupPoolStatus -notmatch "mirror") {
        Write-HealthLog "⚠ Backup pool has NO REDUNDANCY" -Level WARNING
        $checks.Warnings++
        $issues.Warnings += "Main NAS backup pool needs mirror drive"
    }
} else {
    Write-HealthLog "Main NAS Pool 'backup': Check manually" -Level WARNING
    $checks.Warnings++
}

###############################################################################
# CHECK 4: BACKUP FRESHNESS
###############################################################################

Write-HealthLog "Backup Freshness" -Level SECTION
$checks.Total++

# Check for recent backups
$backupLocations = @(
    "X:\VeeamBackups",
    "C:\Backups",
    "\\$BabyNasIP\WindowsBackup"
)

$latestBackup = $null
$backupPath = $null

foreach ($location in $backupLocations) {
    if (Test-Path $location -ErrorAction SilentlyContinue) {
        $files = Get-ChildItem $location -Recurse -File -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1

        if ($files -and (-not $latestBackup -or $files.LastWriteTime -gt $latestBackup.LastWriteTime)) {
            $latestBackup = $files
            $backupPath = $location
        }
    }
}

if ($latestBackup) {
    $hoursSinceBackup = ((Get-Date) - $latestBackup.LastWriteTime).TotalHours

    if ($hoursSinceBackup -lt $thresholds.BackupAgeHours) {
        Write-HealthLog "Last backup: $([math]::Round($hoursSinceBackup, 1)) hours ago" -Level SUCCESS
        Write-HealthLog "Location: $backupPath" -Level INFO
        $checks.Passed++
    } else {
        Write-HealthLog "Last backup is old: $([math]::Round($hoursSinceBackup, 1)) hours ago" -Level ERROR
        $checks.Errors++
        $issues.Critical += "Last backup is $([math]::Round($hoursSinceBackup, 1)) hours old"
    }
} else {
    Write-HealthLog "No backups found" -Level ERROR
    $checks.Errors++
    $issues.Critical += "No backup files found"
}

###############################################################################
# CHECK 5: SNAPSHOT COUNT
###############################################################################

Write-HealthLog "Snapshot Availability" -Level SECTION
$checks.Total++

if (-not [string]::IsNullOrEmpty($BabyNasIP)) {
    $snapshotCount = Get-SnapshotCount -IP $BabyNasIP -Dataset "tank"

    if ($snapshotCount -ge $thresholds.SnapshotMinCount) {
        Write-HealthLog "Snapshots available: $snapshotCount" -Level SUCCESS
        $checks.Passed++
    } elseif ($snapshotCount -gt 0) {
        Write-HealthLog "Limited snapshots: $snapshotCount (minimum: $($thresholds.SnapshotMinCount))" -Level WARNING
        $checks.Warnings++
        $issues.Warnings += "Low snapshot count ($snapshotCount)"
    } else {
        Write-HealthLog "No snapshots found" -Level ERROR
        $checks.Errors++
        $issues.Critical += "No snapshots configured"
    }
}

###############################################################################
# CHECK 6: SMB SHARES
###############################################################################

Write-HealthLog "SMB Share Accessibility" -Level SECTION
$checks.Total++

if (-not [string]::IsNullOrEmpty($BabyNasIP)) {
    $shares = @(
        "\\$BabyNasIP\WindowsBackup",
        "\\$BabyNasIP\Veeam"
    )

    $accessibleShares = 0
    foreach ($share in $shares) {
        if (Test-Path $share -ErrorAction SilentlyContinue) {
            $accessibleShares++
        }
    }

    if ($accessibleShares -eq $shares.Count) {
        Write-HealthLog "All SMB shares accessible ($accessibleShares/$($shares.Count))" -Level SUCCESS
        $checks.Passed++
    } elseif ($accessibleShares -gt 0) {
        Write-HealthLog "Some SMB shares accessible ($accessibleShares/$($shares.Count))" -Level WARNING
        $checks.Warnings++
        $issues.Warnings += "Not all SMB shares accessible"
    } else {
        Write-HealthLog "No SMB shares accessible" -Level ERROR
        $checks.Errors++
        $issues.Critical += "SMB shares not accessible"
    }
}

###############################################################################
# CHECK 7: DISK SPACE
###############################################################################

Write-HealthLog "Local Disk Space" -Level SECTION

$volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveLetter -match '[C-Z]' }

foreach ($vol in $volumes) {
    $checks.Total++
    $percentFree = ($vol.SizeRemaining / $vol.Size) * 100
    $freeGB = [math]::Round($vol.SizeRemaining / 1GB, 2)
    $totalGB = [math]::Round($vol.Size / 1GB, 2)

    $driveName = "$($vol.DriveLetter): ($($vol.FileSystemLabel))"

    if ($percentFree -ge $thresholds.DiskSpacePercent) {
        Write-HealthLog "$driveName - ${freeGB} GB free (${percentFree:N1}%)" -Level SUCCESS
        $checks.Passed++
    } elseif ($percentFree -ge 10) {
        Write-HealthLog "$driveName - ${freeGB} GB free (${percentFree:N1}%)" -Level WARNING
        $checks.Warnings++
        $issues.Warnings += "$driveName low on space (${percentFree:N1}% free)"
    } else {
        Write-HealthLog "$driveName - ${freeGB} GB free (${percentFree:N1}%)" -Level ERROR
        $checks.Errors++
        $issues.Critical += "$driveName critically low on space (${percentFree:N1}% free)"
    }
}

###############################################################################
# CHECK 8: SCHEDULED TASKS
###############################################################################

Write-HealthLog "Scheduled Backup Tasks" -Level SECTION
$checks.Total++

$backupTasks = Get-ScheduledTask | Where-Object {
    $_.TaskName -like "*Backup*" -or
    $_.TaskName -like "*Baby*NAS*"
}

if ($backupTasks) {
    $enabledCount = ($backupTasks | Where-Object { $_.State -eq 'Ready' }).Count
    $disabledCount = ($backupTasks | Where-Object { $_.State -eq 'Disabled' }).Count
    $totalCount = $backupTasks.Count

    Write-HealthLog "Found $totalCount backup tasks: $enabledCount enabled, $disabledCount disabled" -Level INFO

    if ($disabledCount -eq 0) {
        Write-HealthLog "All backup tasks are enabled" -Level SUCCESS
        $checks.Passed++
    } else {
        Write-HealthLog "$disabledCount backup tasks are disabled" -Level WARNING
        $checks.Warnings++
        $issues.Warnings += "$disabledCount backup tasks disabled"
    }

    # Show task details
    foreach ($task in $backupTasks) {
        $lastRun = (Get-ScheduledTaskInfo -TaskName $task.TaskName -ErrorAction SilentlyContinue).LastRunTime
        $lastRunStr = if ($lastRun) { $lastRun.ToString('yyyy-MM-dd HH:mm') } else { "Never" }
        Write-HealthLog "  $($task.TaskName): $($task.State) (Last run: $lastRunStr)" -Level INFO
    }
} else {
    Write-HealthLog "No backup scheduled tasks found" -Level WARNING
    $checks.Warnings++
    $issues.Warnings += "No backup scheduled tasks configured"
}

###############################################################################
# CHECK 9: REPLICATION STATUS
###############################################################################

Write-HealthLog "Replication Status" -Level SECTION
$checks.Total++

if (-not [string]::IsNullOrEmpty($BabyNasIP)) {
    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        if (Test-Path $sshKey) {
            $sshArgs = @("-i", $sshKey, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5", "root@$BabyNasIP")

            # Check if replication script exists
            $replScript = & ssh @sshArgs "test -f /root/replicate-to-main.sh && echo 'exists'" 2>$null

            if ($replScript -match "exists") {
                # Check last replication
                $lastRepl = & ssh @sshArgs "tail -50 /var/log/replication.log 2>/dev/null | grep -E 'Time:|Complete'" 2>$null

                if ($lastRepl) {
                    if ($lastRepl -match "Complete") {
                        Write-HealthLog "Replication configured and running" -Level SUCCESS
                        $checks.Passed++

                        # Try to determine last run time
                        $timeMatch = $lastRepl | Select-String "Time:\s*(.+)" | Select-Object -Last 1
                        if ($timeMatch) {
                            Write-HealthLog "Last run: $($timeMatch.Matches.Groups[1].Value)" -Level INFO
                        }
                    } else {
                        Write-HealthLog "Replication may have failed - check logs" -Level WARNING
                        $checks.Warnings++
                        $issues.Warnings += "Replication status unclear"
                    }
                } else {
                    Write-HealthLog "No replication logs found (may not have run yet)" -Level WARNING
                    $checks.Warnings++
                    $issues.Warnings += "No replication history"
                }
            } else {
                Write-HealthLog "Replication not configured" -Level WARNING
                $checks.Warnings++
                $issues.Warnings += "Replication not set up"
            }
        }
    } catch {
        Write-HealthLog "Cannot check replication status" -Level WARNING
        $checks.Warnings++
    }
}

###############################################################################
# SUMMARY REPORT
###############################################################################

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$overallStatus = Get-HealthStatus -ErrorCount $checks.Errors -WarningCount $checks.Warnings
$statusColor = switch ($overallStatus) {
    'HEALTHY'  { 'Green' }
    'WARNING'  { 'Yellow' }
    'CRITICAL' { 'Red' }
}

Write-Host "OVERALL HEALTH STATUS: " -NoNewline
Write-Host "$overallStatus" -ForegroundColor $statusColor -BackgroundColor Black
Write-Host ""

Write-HealthLog "=== Health Check Summary ===" -Level SECTION
Write-HealthLog "Total Checks: $($checks.Total)" -Level INFO
Write-HealthLog "Passed: $($checks.Passed)" -Level SUCCESS
Write-HealthLog "Warnings: $($checks.Warnings)" -Level WARNING
Write-HealthLog "Errors: $($checks.Errors)" -Level ERROR

# Display issues
if ($issues.Critical.Count -gt 0) {
    Write-Host ""
    Write-Host "CRITICAL ISSUES:" -ForegroundColor Red
    foreach ($issue in $issues.Critical) {
        Write-Host "  ✗ $issue" -ForegroundColor Red
    }
}

if ($issues.Warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNINGS:" -ForegroundColor Yellow
    foreach ($warning in $issues.Warnings) {
        Write-Host "  ⚠ $warning" -ForegroundColor Yellow
    }
}

Write-HealthLog "" -Level INFO
Write-HealthLog "Report saved to: $logFile" -Level INFO

###############################################################################
# EMAIL NOTIFICATION
###############################################################################

if ($SendEmail -and -not [string]::IsNullOrEmpty($EmailTo)) {
    Write-Host ""
    Write-HealthLog "Preparing email notification..." -Level INFO

    $emailSubject = "Baby NAS Daily Health Check: $overallStatus"

    $emailBody = @"
Baby NAS Daily Health Check Report
===================================

Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Overall Status: $overallStatus

Summary:
--------
Total Checks: $($checks.Total)
Passed: $($checks.Passed)
Warnings: $($checks.Warnings)
Errors: $($checks.Errors)

$(if ($issues.Critical.Count -gt 0) {
"Critical Issues ($($issues.Critical.Count)):
" + ($issues.Critical | ForEach-Object { "- $_" }) -join "`n"
})

$(if ($issues.Warnings.Count -gt 0) {
"Warnings ($($issues.Warnings.Count)):
" + ($issues.Warnings | ForEach-Object { "- $_" }) -join "`n"
})

Configuration:
--------------
Baby NAS IP: $BabyNasIP
Main NAS IP: $MainNasIP

Log File: $logFile

--
This is an automated health check report.
For details, review the full log file on the server.
"@

    Write-HealthLog "Email notification not fully configured" -Level WARNING
    Write-HealthLog "To: $EmailTo" -Level INFO
    Write-HealthLog "Subject: $emailSubject" -Level INFO

    # TODO: Configure SMTP credentials
    <#
    try {
        $cred = Get-Credential -Message "Enter SMTP credentials for $EmailFrom"
        Send-MailMessage `
            -To $EmailTo `
            -From $EmailFrom `
            -Subject $emailSubject `
            -Body $emailBody `
            -SmtpServer $SMTPServer `
            -Port $SMTPPort `
            -UseSsl `
            -Credential $cred

        Write-HealthLog "Email sent successfully" -Level SUCCESS
    } catch {
        Write-HealthLog "Failed to send email: $($_.Exception.Message)" -Level ERROR
    }
    #>
}

###############################################################################
# CLEANUP OLD LOGS
###############################################################################

try {
    $oldLogs = Get-ChildItem $LogPath -Filter "health-check-*.log" |
               Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }

    if ($oldLogs) {
        $oldLogs | Remove-Item -Force
        Write-HealthLog "Cleaned up $($oldLogs.Count) old log files" -Level INFO
    }
} catch {
    Write-HealthLog "Could not clean up old logs" -Level WARNING
}

###############################################################################
# EXIT
###############################################################################

Write-Host ""
Write-Host "Health check completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Return exit code based on status
if ($overallStatus -eq "CRITICAL") {
    exit 1
} elseif ($overallStatus -eq "WARNING") {
    exit 2
} else {
    exit 0
}
