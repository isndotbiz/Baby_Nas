#Requires -RunAsAdministrator
###############################################################################
# Baby NAS Real-Time Health Monitoring Script
# Purpose: Monitor Baby NAS VM, pools, replication, and SMB shares
# Usage: .\monitor-baby-nas.ps1 [-BabyNasIP <ip>] [-MainNasIP <ip>] [-Continuous]
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$BabyNasIP = "",

    [Parameter(Mandatory=$false)]
    [string]$MainNasIP = "10.0.0.89",

    [Parameter(Mandatory=$false)]
    [switch]$Continuous,

    [Parameter(Mandatory=$false)]
    [int]$RefreshSeconds = 30
)

$ErrorActionPreference = "Continue"

# Color functions
function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('OK','WARNING','ERROR','INFO')]
        [string]$Status
    )

    $color = switch ($Status) {
        'OK'      { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        'INFO'    { 'Cyan' }
    }

    $symbol = switch ($Status) {
        'OK'      { '✓' }
        'WARNING' { '⚠' }
        'ERROR'   { '✗' }
        'INFO'    { 'ℹ' }
    }

    Write-Host "$symbol $Message" -ForegroundColor $color
}

function Get-PoolCapacity {
    param([string]$Output)

    if ($Output -match 'cap\s+(\d+)%') {
        return [int]$Matches[1]
    }
    return -1
}

function Get-PoolHealth {
    param([string]$Output)

    if ($Output -match 'state:\s+(\w+)') {
        return $Matches[1]
    }
    return "UNKNOWN"
}

# Auto-detect Baby NAS IP if not provided
if ([string]::IsNullOrEmpty($BabyNasIP)) {
    Write-Host "Detecting Baby NAS VM..." -ForegroundColor Cyan
    $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1

    if ($vm) {
        Write-Host "Found VM: $($vm.Name)" -ForegroundColor Green

        # Try to get IP from network adapter
        $vmNet = Get-VMNetworkAdapter -VM $vm
        if ($vmNet.IPAddresses) {
            $BabyNasIP = ($vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
        }
    }

    if ([string]::IsNullOrEmpty($BabyNasIP)) {
        Write-Host "Could not auto-detect Baby NAS IP. Please specify with -BabyNasIP parameter" -ForegroundColor Red
        exit 1
    }
}

do {
    Clear-Host

    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                    Baby NAS Health Monitor                               ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Monitoring Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "Baby NAS IP: $BabyNasIP" -ForegroundColor Gray
    Write-Host ""

    $overallHealth = "OK"
    $issues = @()

    ###########################################################################
    # 1. VM STATUS CHECK
    ###########################################################################
    Write-Host "═══ Hyper-V VM Status ═══" -ForegroundColor Cyan

    try {
        $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1

        if ($vm) {
            if ($vm.State -eq "Running") {
                Write-Status "VM '$($vm.Name)' is Running" -Status OK
                Write-Host "  Uptime: $($vm.Uptime.ToString('dd\.hh\:mm\:ss'))" -ForegroundColor Gray
                Write-Host "  CPU: $($vm.CPUUsage)% | Memory: $([math]::Round($vm.MemoryAssigned/1GB, 2)) GB assigned" -ForegroundColor Gray
            } elseif ($vm.State -eq "Off") {
                Write-Status "VM '$($vm.Name)' is STOPPED" -Status ERROR
                $overallHealth = "ERROR"
                $issues += "Baby NAS VM is not running"
            } else {
                Write-Status "VM '$($vm.Name)' in unexpected state: $($vm.State)" -Status WARNING
                $overallHealth = "WARNING"
                $issues += "VM in unexpected state: $($vm.State)"
            }

            # Check auto-start configuration
            if ($vm.AutomaticStartAction -eq "Start") {
                Write-Status "Auto-start: Enabled (Delay: $($vm.AutomaticStartDelay)s)" -Status OK
            } else {
                Write-Status "Auto-start: Not configured" -Status WARNING
                if ($overallHealth -ne "ERROR") { $overallHealth = "WARNING" }
                $issues += "VM auto-start not configured"
            }
        } else {
            Write-Status "Baby NAS VM not found" -Status ERROR
            $overallHealth = "ERROR"
            $issues += "Baby NAS VM not found"
        }
    } catch {
        Write-Status "Failed to query VM status: $($_.Exception.Message)" -Status ERROR
        $overallHealth = "ERROR"
        $issues += "Cannot query Hyper-V"
    }

    Write-Host ""

    ###########################################################################
    # 2. NETWORK CONNECTIVITY
    ###########################################################################
    Write-Host "═══ Network Connectivity ═══" -ForegroundColor Cyan

    # Baby NAS connectivity
    $babyNasPing = Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet -ErrorAction SilentlyContinue
    if ($babyNasPing) {
        Write-Status "Baby NAS reachable at $BabyNasIP" -Status OK
    } else {
        Write-Status "Baby NAS unreachable at $BabyNasIP" -Status ERROR
        $overallHealth = "ERROR"
        $issues += "Baby NAS not responding to ping"
    }

    # Main NAS connectivity
    $mainNasPing = Test-Connection -ComputerName $MainNasIP -Count 2 -Quiet -ErrorAction SilentlyContinue
    if ($mainNasPing) {
        Write-Status "Main NAS reachable at $MainNasIP" -Status OK
    } else {
        Write-Status "Main NAS unreachable at $MainNasIP" -Status WARNING
        if ($overallHealth -ne "ERROR") { $overallHealth = "WARNING" }
        $issues += "Main NAS not responding (replication target unavailable)"
    }

    Write-Host ""

    ###########################################################################
    # 3. POOL HEALTH - BABY NAS
    ###########################################################################
    Write-Host "═══ Baby NAS Pool Health ═══" -ForegroundColor Cyan

    if ($babyNasPing) {
        try {
            # Check if SSH key exists
            $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
            $sshArgs = @()
            if (Test-Path $sshKey) {
                $sshArgs += @("-i", $sshKey)
            }
            $sshArgs += @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5")

            # Try root user first, then truenas_admin
            $poolStatus = $null
            try {
                $poolStatus = & ssh @sshArgs "root@$BabyNasIP" "zpool status tank" 2>$null
            } catch {
                try {
                    $poolStatus = & ssh @sshArgs "truenas_admin@$BabyNasIP" "sudo zpool status tank" 2>$null
                } catch {
                    $poolStatus = $null
                }
            }

            if ($poolStatus) {
                $health = Get-PoolHealth -Output $poolStatus
                $capacity = Get-PoolCapacity -Output $poolStatus

                if ($health -eq "ONLINE") {
                    Write-Status "Pool 'tank': $health" -Status OK
                } elseif ($health -match "DEGRADED") {
                    Write-Status "Pool 'tank': $health (disk failure or maintenance)" -Status WARNING
                    if ($overallHealth -ne "ERROR") { $overallHealth = "WARNING" }
                    $issues += "Baby NAS pool degraded"
                } else {
                    Write-Status "Pool 'tank': $health" -Status ERROR
                    $overallHealth = "ERROR"
                    $issues += "Baby NAS pool in critical state"
                }

                if ($capacity -ge 0) {
                    $capacityStatus = if ($capacity -lt 80) { "OK" } elseif ($capacity -lt 90) { "WARNING" } else { "ERROR" }
                    Write-Status "Capacity: ${capacity}% used" -Status $capacityStatus

                    if ($capacity -ge 90) {
                        $overallHealth = "ERROR"
                        $issues += "Baby NAS pool capacity critical (${capacity}%)"
                    } elseif ($capacity -ge 80 -and $overallHealth -ne "ERROR") {
                        $overallHealth = "WARNING"
                        $issues += "Baby NAS pool capacity high (${capacity}%)"
                    }
                }

                # Show datasets
                try {
                    $datasets = & ssh @sshArgs "root@$BabyNasIP" "zfs list -o name,used,avail,refer tank/windows-backups tank/veeam" 2>$null
                    if ($datasets) {
                        Write-Host "  Datasets:" -ForegroundColor Gray
                        $datasets | Select-Object -Skip 1 | ForEach-Object {
                            Write-Host "    $_" -ForegroundColor DarkGray
                        }
                    }
                } catch {}

            } else {
                Write-Status "Cannot query pool status (SSH not configured)" -Status WARNING
                Write-Host "  Tip: Configure SSH keys with .\2-configure-baby-nas.ps1" -ForegroundColor DarkGray
            }
        } catch {
            Write-Status "Error querying pool: $($_.Exception.Message)" -Status ERROR
            $overallHealth = "ERROR"
            $issues += "Cannot query Baby NAS pool status"
        }
    } else {
        Write-Status "Skipping pool check (Baby NAS unreachable)" -Status ERROR
    }

    Write-Host ""

    ###########################################################################
    # 4. POOL HEALTH - MAIN NAS
    ###########################################################################
    Write-Host "═══ Main NAS Pool Health ═══" -ForegroundColor Cyan

    if ($mainNasPing) {
        try {
            $sshKey = "$env:USERPROFILE\.ssh\truenas_admin_10_0_0_89"
            $sshArgs = @()
            if (Test-Path $sshKey) {
                $sshArgs += @("-i", $sshKey)
            }
            $sshArgs += @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5")

            # Check tank pool
            try {
                $poolStatus = & ssh @sshArgs "root@$MainNasIP" "zpool status tank" 2>$null
                if ($poolStatus) {
                    $health = Get-PoolHealth -Output $poolStatus
                    $capacity = Get-PoolCapacity -Output $poolStatus

                    $statusType = if ($health -eq "ONLINE") { "OK" } elseif ($health -match "DEGRADED") { "WARNING" } else { "ERROR" }
                    Write-Status "Pool 'tank': $health ($capacity% used)" -Status $statusType
                }
            } catch {}

            # Check backup pool
            try {
                $backupPool = & ssh @sshArgs "root@$MainNasIP" "zpool status backup" 2>$null
                if ($backupPool) {
                    $health = Get-PoolHealth -Output $backupPool
                    $capacity = Get-PoolCapacity -Output $backupPool

                    $statusType = if ($health -eq "ONLINE") { "OK" } elseif ($health -match "DEGRADED") { "WARNING" } else { "ERROR" }
                    Write-Status "Pool 'backup': $health ($capacity% used)" -Status $statusType

                    # Warning about non-redundant backup pool
                    if ($backupPool -notmatch "mirror") {
                        Write-Status "⚠ Backup pool has NO REDUNDANCY - needs mirror drive!" -Status WARNING
                        if ($overallHealth -ne "ERROR") { $overallHealth = "WARNING" }
                    }
                }
            } catch {}

        } catch {
            Write-Status "Cannot query Main NAS pools (SSH not configured)" -Status WARNING
        }
    } else {
        Write-Status "Skipping pool check (Main NAS unreachable)" -Status WARNING
    }

    Write-Host ""

    ###########################################################################
    # 5. REPLICATION STATUS
    ###########################################################################
    Write-Host "═══ Replication Status ═══" -ForegroundColor Cyan

    if ($babyNasPing -and $mainNasPing) {
        try {
            $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
            if (Test-Path $sshKey) {
                $sshArgs = @("-i", $sshKey, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5")

                # Check for replication script
                $replScript = & ssh @sshArgs "root@$BabyNasIP" "test -f /root/replicate-to-main.sh && echo 'exists'" 2>$null

                if ($replScript -match "exists") {
                    Write-Status "Replication script configured" -Status OK

                    # Check last replication log
                    $lastRepl = & ssh @sshArgs "root@$BabyNasIP" "tail -20 /var/log/replication.log 2>/dev/null" 2>$null
                    if ($lastRepl) {
                        $lastTime = $lastRepl | Select-String "Time:" | Select-Object -Last 1
                        if ($lastTime) {
                            Write-Host "  Last replication: $($lastTime.Line -replace 'Time: ','')" -ForegroundColor Gray

                            if ($lastRepl -match "Replication Complete") {
                                Write-Status "Last replication: Successful" -Status OK
                            } else {
                                Write-Status "Last replication: Check logs for status" -Status WARNING
                            }
                        }
                    } else {
                        Write-Status "No replication log found (may not have run yet)" -Status INFO
                    }

                    # Check cron schedule
                    $cronJob = & ssh @sshArgs "root@$BabyNasIP" "crontab -l | grep replicate-to-main" 2>$null
                    if ($cronJob) {
                        Write-Host "  Scheduled: $($cronJob.Trim())" -ForegroundColor DarkGray
                    } else {
                        Write-Status "Replication not scheduled in cron" -Status WARNING
                        if ($overallHealth -ne "ERROR") { $overallHealth = "WARNING" }
                        $issues += "Automatic replication not scheduled"
                    }
                } else {
                    Write-Status "Replication script not found" -Status WARNING
                    Write-Host "  Tip: Run .\3-setup-replication.ps1 to configure" -ForegroundColor DarkGray
                    if ($overallHealth -ne "ERROR") { $overallHealth = "WARNING" }
                    $issues += "Replication not configured"
                }
            } else {
                Write-Status "Cannot check replication (SSH keys not configured)" -Status WARNING
            }
        } catch {
            Write-Status "Error checking replication: $($_.Exception.Message)" -Status ERROR
        }
    } else {
        Write-Status "Cannot check replication (network issues)" -Status ERROR
    }

    Write-Host ""

    ###########################################################################
    # 6. SMB SHARE ACCESSIBILITY
    ###########################################################################
    Write-Host "═══ SMB Share Accessibility ═══" -ForegroundColor Cyan

    if ($babyNasPing) {
        # Check common share paths
        $shares = @(
            @{Name="WindowsBackup"; Path="\\$BabyNasIP\WindowsBackup"},
            @{Name="Veeam"; Path="\\$BabyNasIP\Veeam"},
            @{Name="WindowsBackup (NetBIOS)"; Path="\\babynas\WindowsBackup"}
        )

        foreach ($share in $shares) {
            try {
                if (Test-Path $share.Path -ErrorAction SilentlyContinue) {
                    Write-Status "$($share.Name): Accessible" -Status OK

                    # Get space info
                    try {
                        $drive = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -eq $share.Path } | Select-Object -First 1
                        if (-not $drive) {
                            # Try to get space info directly
                            $item = Get-Item $share.Path -ErrorAction SilentlyContinue
                            if ($item) {
                                Write-Host "  Path available for backups" -ForegroundColor DarkGray
                            }
                        } else {
                            $usedGB = [math]::Round(($drive.Used / 1GB), 2)
                            $freeGB = [math]::Round(($drive.Free / 1GB), 2)
                            Write-Host "  Free: ${freeGB} GB | Used: ${usedGB} GB" -ForegroundColor DarkGray
                        }
                    } catch {}
                } else {
                    Write-Status "$($share.Name): Not accessible" -Status WARNING
                }
            } catch {
                Write-Status "$($share.Name): Error - $($_.Exception.Message)" -Status WARNING
            }
        }

        # Check mapped drives
        $mappedDrives = Get-PSDrive -PSProvider FileSystem | Where-Object {
            $_.DisplayRoot -and $_.DisplayRoot -match $BabyNasIP
        }

        if ($mappedDrives) {
            Write-Host ""
            Write-Host "  Mapped Network Drives:" -ForegroundColor Gray
            foreach ($drive in $mappedDrives) {
                $freeGB = [math]::Round(($drive.Free / 1GB), 2)
                $usedGB = [math]::Round(($drive.Used / 1GB), 2)
                Write-Host "    $($drive.Name): $($drive.DisplayRoot) (${freeGB} GB free)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Status "Cannot check shares (Baby NAS unreachable)" -Status ERROR
    }

    Write-Host ""

    ###########################################################################
    # OVERALL STATUS SUMMARY
    ###########################################################################
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

    $statusColor = switch ($overallHealth) {
        'OK'      { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
    }

    Write-Host ""
    Write-Host "OVERALL STATUS: " -NoNewline
    Write-Host "$overallHealth" -ForegroundColor $statusColor -BackgroundColor Black
    Write-Host ""

    if ($issues.Count -gt 0) {
        Write-Host "Issues Detected:" -ForegroundColor Yellow
        foreach ($issue in $issues) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    if ($Continuous) {
        Write-Host "Press Ctrl+C to stop monitoring. Refreshing in $RefreshSeconds seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds $RefreshSeconds
    }

} while ($Continuous)

Write-Host ""
Write-Host "Monitoring complete." -ForegroundColor Gray
Write-Host ""

# Return exit code based on health
if ($overallHealth -eq "ERROR") {
    exit 1
} elseif ($overallHealth -eq "WARNING") {
    exit 2
} else {
    exit 0
}
