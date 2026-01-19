#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Comprehensive Backup Monitoring Dashboard
    Displays real-time status of all three backup systems (Veeam, Phone, Time Machine)

.DESCRIPTION
    Interactive dashboard that shows:
    - Veeam backup size and next run time
    - Phone backup last sync time and size
    - Time Machine last backup and size
    - Color-coded status (green/yellow/red)
    - Auto-refreshes every 5 minutes

.PARAMETER RefreshInterval
    Refresh interval in seconds (default: 300 = 5 minutes)

.PARAMETER TrueNASIP
    IP address of TrueNAS system (default: 10.0.0.89)

.PARAMETER BabyNASIP
    IP address of Baby NAS VM (auto-detected if not provided)

.EXAMPLE
    .\BACKUP-MONITORING-DASHBOARD.ps1
    Run dashboard with default 5-minute refresh

.EXAMPLE
    .\BACKUP-MONITORING-DASHBOARD.ps1 -RefreshInterval 60
    Refresh every 60 seconds

.NOTES
    Author: Automated Backup Monitoring System
    Version: 1.0
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$RefreshInterval = 300,

    [Parameter(Mandatory=$false)]
    [string]$TrueNASIP = "10.0.0.89",

    [Parameter(Mandatory=$false)]
    [string]$BabyNASIP = ""
)

$ErrorActionPreference = "SilentlyContinue"

# Configuration
$LogPath = "C:\Logs\BackupMonitoring"
$DashboardLogFile = "$LogPath\dashboard-$(Get-Date -Format 'yyyyMMdd').log"

# Create log directory
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Auto-detect Baby NAS IP if not provided
if ([string]::IsNullOrEmpty($BabyNASIP)) {
    try {
        $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS*" } | Select-Object -First 1
        if ($vm) {
            $vmNet = Get-VMNetworkAdapter -VM $vm
            if ($vmNet.IPAddresses) {
                $BabyNASIP = ($vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
            }
        }
    } catch {}
}

###############################################################################
# HELPER FUNCTIONS
###############################################################################

function Write-DashLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    $logMessage | Out-File -FilePath $DashboardLogFile -Append
}

function Get-ColorCode {
    param([string]$Status)

    switch ($Status) {
        "OK"       { return [ConsoleColor]::Green }
        "WARNING"  { return [ConsoleColor]::Yellow }
        "CRITICAL" { return [ConsoleColor]::Red }
        "UNKNOWN"  { return [ConsoleColor]::Gray }
        default    { return [ConsoleColor]::White }
    }
}

function Get-StatusSymbol {
    param([string]$Status)

    switch ($Status) {
        "OK"       { return "✓" }
        "WARNING"  { return "⚠" }
        "CRITICAL" { return "✗" }
        "UNKNOWN"  { return "?" }
        default    { return " " }
    }
}

function Get-VeeamBackupStatus {
    $status = @{
        Status = "UNKNOWN"
        LastBackupTime = $null
        SizeGB = 0
        NextRunTime = $null
        DaysOld = 0
    }

    # Check multiple possible backup locations
    $backupLocations = @(
        "X:\VeeamBackups",
        "\\$BabyNASIP\Veeam",
        "D:\VeeamBackups"
    )

    foreach ($location in $backupLocations) {
        if (Test-Path $location -ErrorAction SilentlyContinue) {
            try {
                $latestFile = Get-ChildItem $location -Recurse -File -ErrorAction SilentlyContinue |
                              Sort-Object LastWriteTime -Descending |
                              Select-Object -First 1

                if ($latestFile) {
                    $status.LastBackupTime = $latestFile.LastWriteTime
                    $status.DaysOld = [math]::Round(((Get-Date) - $latestFile.LastWriteTime).TotalHours / 24, 1)

                    # Calculate total backup size
                    $totalSize = (Get-ChildItem $location -Recurse -File -ErrorAction SilentlyContinue |
                                  Measure-Object -Property Length -Sum).Sum
                    $status.SizeGB = [math]::Round($totalSize / 1GB, 2)

                    # Determine status
                    if ($status.DaysOld -lt 1) {
                        $status.Status = "OK"
                    } elseif ($status.DaysOld -lt 2) {
                        $status.Status = "WARNING"
                    } else {
                        $status.Status = "CRITICAL"
                    }

                    break
                }
            } catch {}
        }
    }

    # Try to get next scheduled run time from Task Scheduler
    try {
        $veeamTask = Get-ScheduledTask -TaskName "*Veeam*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($veeamTask) {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $veeamTask.TaskName -ErrorAction SilentlyContinue
            if ($taskInfo.NextRunTime) {
                $status.NextRunTime = $taskInfo.NextRunTime
            }
        }
    } catch {}

    return $status
}

function Get-PhoneBackupStatus {
    $status = @{
        Status = "UNKNOWN"
        LastSyncTime = $null
        SizeGB = 0
        DeviceCount = 0
        LastBackupPath = $null
    }

    $phoneBackupLocations = @(
        "X:\Phone-Backups",
        "\\$BabyNASIP\Phone-Backups",
        "D:\Phone-Backups"
    )

    foreach ($location in $phoneBackupLocations) {
        if (Test-Path $location -ErrorAction SilentlyContinue) {
            try {
                $backupDirs = Get-ChildItem $location -Directory -ErrorAction SilentlyContinue
                $status.DeviceCount = $backupDirs.Count

                if ($backupDirs) {
                    # Get most recent backup
                    $latestBackup = $backupDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    $status.LastSyncTime = $latestBackup.LastWriteTime
                    $status.LastBackupPath = $latestBackup.FullName

                    $daysSinceSync = [math]::Round(((Get-Date) - $status.LastSyncTime).TotalHours / 24, 1)

                    # Calculate total size
                    $totalSize = (Get-ChildItem $location -Recurse -File -ErrorAction SilentlyContinue |
                                  Measure-Object -Property Length -Sum).Sum
                    $status.SizeGB = [math]::Round($totalSize / 1GB, 2)

                    # Determine status
                    if ($daysSinceSync -lt 1) {
                        $status.Status = "OK"
                    } elseif ($daysSinceSync -lt 7) {
                        $status.Status = "WARNING"
                    } else {
                        $status.Status = "CRITICAL"
                    }
                } else {
                    $status.Status = "WARNING"
                }

                break
            } catch {}
        }
    }

    if ($status.Status -eq "UNKNOWN") {
        $status.Status = "UNKNOWN"
    }

    return $status
}

function Get-TimeMachineStatus {
    $status = @{
        Status = "UNKNOWN"
        LastBackupTime = $null
        SizeGB = 0
        BackupVolume = $null
    }

    # Check for Time Machine backups on TrueNAS
    $timeMachineLocations = @(
        "\\$TrueNASIP\TimeMachine",
        "\\$BabyNASIP\TimeMachine",
        "X:\TimeMachine",
        "D:\TimeMachine"
    )

    foreach ($location in $timeMachineLocations) {
        if (Test-Path $location -ErrorAction SilentlyContinue) {
            try {
                $status.BackupVolume = $location

                # Look for .sparsebundle or backup bundle
                $bundles = Get-ChildItem $location -Filter "*.sparsebundle" -Directory -ErrorAction SilentlyContinue

                if ($bundles) {
                    # Get most recent bundle modification
                    $latestBundle = $bundles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    $status.LastBackupTime = $latestBundle.LastWriteTime

                    # Get bundle size
                    $bundleSize = (Get-ChildItem $latestBundle.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                   Measure-Object -Property Length -Sum).Sum
                    $status.SizeGB = [math]::Round($bundleSize / 1GB, 2)

                    $hoursSinceBkp = [math]::Round(((Get-Date) - $status.LastBackupTime).TotalHours, 1)

                    # Determine status (Time Machine typically runs every hour)
                    if ($hoursSinceBkp -lt 2) {
                        $status.Status = "OK"
                    } elseif ($hoursSinceBkp -lt 24) {
                        $status.Status = "WARNING"
                    } else {
                        $status.Status = "CRITICAL"
                    }
                } else {
                    $status.Status = "WARNING"
                }

                break
            } catch {}
        }
    }

    return $status
}

function Get-StorageQuotaStatus {
    $quotas = @()

    # Check Veeam backup storage
    $veeamPath = "X:\VeeamBackups"
    if (Test-Path $veeamPath) {
        try {
            $volInfo = [System.IO.DriveInfo]::new($veeamPath.Substring(0, 2))
            $usedGB = [math]::Round(($volInfo.TotalSize - $volInfo.AvailableFreeSpace) / 1GB, 2)
            $totalGB = [math]::Round($volInfo.TotalSize / 1GB, 2)
            $percentUsed = [math]::Round(($usedGB / $totalGB) * 100, 1)

            $status = if ($percentUsed -gt 90) { "CRITICAL" } elseif ($percentUsed -gt 80) { "WARNING" } else { "OK" }

            $quotas += [PSCustomObject]@{
                Name = "Veeam Backup Storage"
                UsedGB = $usedGB
                TotalGB = $totalGB
                PercentUsed = $percentUsed
                Status = $status
            }
        } catch {}
    }

    return $quotas
}

function Get-NetworkConnectivity {
    $connectivity = @{
        TrueNAS = $false
        BabyNAS = $false
    }

    if (Test-Connection -ComputerName $TrueNASIP -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        $connectivity.TrueNAS = $true
    }

    if (-not [string]::IsNullOrEmpty($BabyNASIP) -and (Test-Connection -ComputerName $BabyNASIP -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        $connectivity.BabyNAS = $true
    }

    return $connectivity
}

###############################################################################
# DISPLAY FUNCTIONS
###############################################################################

function Show-DashboardHeader {
    Clear-Host

    $border = "╔" + ("═" * 78) + "╗"
    $title = "║ BACKUP MONITORING DASHBOARD" + (" " * 50) + "║"
    $subtitle = "║ Veeam • Phone • Time Machine" + (" " * 49) + "║"
    $timestamp = "║ Last Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" + (" " * 23) + "║"
    $borderBottom = "╚" + ("═" * 78) + "╝"

    Write-Host $border -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host $subtitle -ForegroundColor Cyan
    Write-Host $timestamp -ForegroundColor Gray
    Write-Host $borderBottom -ForegroundColor Cyan
    Write-Host ""
}

function Show-BackupStatus {
    param(
        [string]$Name,
        [hashtable]$Status
    )

    $symbol = Get-StatusSymbol $Status.Status
    $color = Get-ColorCode $Status.Status

    Write-Host "┌─ $symbol " -NoNewline -ForegroundColor $color
    Write-Host $Name -NoNewline -ForegroundColor White -BackgroundColor $([int][ConsoleColor]::Black)
    Write-Host " " -NoNewline
    Write-Host "─" * (70 - $Name.Length) + "┐" -ForegroundColor $color

    # Status line
    Write-Host "│ Status: " -NoNewline -ForegroundColor Gray
    Write-Host $Status.Status -ForegroundColor $color -BackgroundColor Black -NoNewline
    Write-Host (" " * (66 - $Status.Status.Length)) + "│" -ForegroundColor Gray

    # Last activity
    if ($Status.LastBackupTime) {
        $lastBackupStr = $Status.LastBackupTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "│ Last: " -NoNewline -ForegroundColor Gray
        Write-Host $lastBackupStr -NoNewline -ForegroundColor White

        if ($Status.DaysOld -or $Status.DaysOld -eq 0) {
            Write-Host " ($($Status.DaysOld) days old)" -NoNewline -ForegroundColor Gray
        }

        Write-Host (" " * (70 - $lastBackupStr.Length - if ($Status.DaysOld) { $Status.DaysOld.ToString().Length + 12 } else { 0 })) + "│" -ForegroundColor Gray
    } elseif ($Status.LastSyncTime) {
        $lastSyncStr = $Status.LastSyncTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "│ Last Sync: " -NoNewline -ForegroundColor Gray
        Write-Host $lastSyncStr -NoNewline -ForegroundColor White
        Write-Host (" " * (70 - $lastSyncStr.Length - 11)) + "│" -ForegroundColor Gray
    }

    # Size
    if ($Status.SizeGB -gt 0) {
        $sizeStr = "$($Status.SizeGB) GB"
        Write-Host "│ Size: " -NoNewline -ForegroundColor Gray
        Write-Host $sizeStr -NoNewline -ForegroundColor Cyan
        Write-Host (" " * (70 - $sizeStr.Length - 6)) + "│" -ForegroundColor Gray
    }

    # Next run (if available)
    if ($Status.NextRunTime) {
        $nextStr = $Status.NextRunTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "│ Next Run: " -NoNewline -ForegroundColor Gray
        Write-Host $nextStr -NoNewline -ForegroundColor Cyan
        Write-Host (" " * (70 - $nextStr.Length - 10)) + "│" -ForegroundColor Gray
    }

    # Device count (for phone backups)
    if ($Status.DeviceCount -gt 0) {
        Write-Host "│ Devices: " -NoNewline -ForegroundColor Gray
        Write-Host "$($Status.DeviceCount)" -NoNewline -ForegroundColor Cyan
        Write-Host (" " * 60) + "│" -ForegroundColor Gray
    }

    Write-Host "└" + ("─" * 76) + "┘" -ForegroundColor $color
    Write-Host ""
}

function Show-StorageQuotas {
    param([array]$Quotas)

    if ($Quotas.Count -eq 0) {
        return
    }

    Write-Host "STORAGE QUOTAS" -ForegroundColor Cyan
    Write-Host "┌─────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Gray

    foreach ($quota in $Quotas) {
        $color = Get-ColorCode $quota.Status
        $symbol = Get-StatusSymbol $quota.Status

        $percentBar = [int]($quota.PercentUsed / 5)
        $filledBar = "█" * $percentBar + "░" * (20 - $percentBar)

        Write-Host "│ " -NoNewline -ForegroundColor Gray
        Write-Host "$symbol $($quota.Name)" -NoNewline -ForegroundColor White
        Write-Host (" " * (50 - $quota.Name.Length)) + "│" -ForegroundColor Gray

        Write-Host "│ " -NoNewline -ForegroundColor Gray
        Write-Host $filledBar -ForegroundColor $color -NoNewline
        Write-Host " " + $quota.PercentUsed + "%" -ForegroundColor $color -NoNewline
        Write-Host (" " * (70 - $filledBar.Length - $quota.PercentUsed.ToString().Length - 2)) + "│" -ForegroundColor Gray

        Write-Host "│ " -NoNewline -ForegroundColor Gray
        Write-Host "$($quota.UsedGB) GB / $($quota.TotalGB) GB" -ForegroundColor Gray -NoNewline
        Write-Host (" " * (70 - "$($quota.UsedGB) GB / $($quota.TotalGB) GB".Length - 2)) + "│" -ForegroundColor Gray
        Write-Host "│" -ForegroundColor Gray
    }

    Write-Host "└─────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Gray
    Write-Host ""
}

function Show-NetworkStatus {
    param([hashtable]$Connectivity)

    Write-Host "NETWORK CONNECTIVITY" -ForegroundColor Cyan
    Write-Host "┌─────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Gray

    # TrueNAS
    $trueNasStatus = if ($Connectivity.TrueNAS) { "✓ ONLINE" } else { "✗ OFFLINE" }
    $trueNasColor = if ($Connectivity.TrueNAS) { [ConsoleColor]::Green } else { [ConsoleColor]::Red }

    Write-Host "│ TrueNAS ($TrueNASIP): " -NoNewline -ForegroundColor Gray
    Write-Host $trueNasStatus -ForegroundColor $trueNasColor -NoNewline
    Write-Host (" " * (50 - $trueNasStatus.Length - $TrueNASIP.Length)) + "│" -ForegroundColor Gray

    # Baby NAS
    if (-not [string]::IsNullOrEmpty($BabyNASIP)) {
        $babyNasStatus = if ($Connectivity.BabyNAS) { "✓ ONLINE" } else { "✗ OFFLINE" }
        $babyNasColor = if ($Connectivity.BabyNAS) { [ConsoleColor]::Green } else { [ConsoleColor]::Red }

        Write-Host "│ Baby NAS ($BabyNASIP): " -NoNewline -ForegroundColor Gray
        Write-Host $babyNasStatus -ForegroundColor $babyNasColor -NoNewline
        Write-Host (" " * (50 - $babyNasStatus.Length - $BabyNASIP.Length)) + "│" -ForegroundColor Gray
    }

    Write-Host "└─────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Gray
    Write-Host ""
}

function Show-FooterInfo {
    Write-Host "Press Ctrl+C to exit | Next refresh in $RefreshInterval seconds" -ForegroundColor Gray
    Write-Host "Log file: $DashboardLogFile" -ForegroundColor Gray
}

###############################################################################
# MAIN DASHBOARD LOOP
###############################################################################

Write-DashLog "Dashboard started" "INFO"

do {
    Show-DashboardHeader

    # Get all status information
    Write-Host "Gathering backup status..." -ForegroundColor Yellow

    $veeamStatus = Get-VeeamBackupStatus
    $phoneStatus = Get-PhoneBackupStatus
    $timeMachineStatus = Get-TimeMachineStatus
    $storageQuotas = Get-StorageQuotaStatus
    $connectivity = Get-NetworkConnectivity

    # Show dashboard
    Show-BackupStatus -Name "Veeam Backup" -Status $veeamStatus
    Show-BackupStatus -Name "Phone Backup" -Status $phoneStatus
    Show-BackupStatus -Name "Time Machine" -Status $timeMachineStatus

    Show-StorageQuotas -Quotas $storageQuotas
    Show-NetworkStatus -Connectivity $connectivity

    Show-FooterInfo

    # Log summary
    Write-DashLog "Veeam: $($veeamStatus.Status) | Phone: $($phoneStatus.Status) | TimeMachine: $($timeMachineStatus.Status)" "INFO"

    # Wait for next refresh
    Start-Sleep -Seconds $RefreshInterval

} while ($true)
