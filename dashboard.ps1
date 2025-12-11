#Requires -RunAsAdministrator
###############################################################################
# Baby NAS Interactive Dashboard (TUI)
# Purpose: Real-time terminal dashboard with metrics and graphs
# Usage: .\dashboard.ps1 [-ConfigPath <path>] [-RefreshSeconds <int>]
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "$PSScriptRoot\monitoring-config.json",

    [Parameter(Mandatory=$false)]
    [int]$RefreshSeconds = 5,

    [Parameter(Mandatory=$false)]
    [switch]$Compact
)

$ErrorActionPreference = "Continue"

###############################################################################
# CONFIGURATION
###############################################################################

# Load config
if (Test-Path $ConfigPath) {
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    } catch {
        Write-Host "Failed to load config, using defaults" -ForegroundColor Yellow
        $config = $null
    }
}

# History tracking for graphs
$historySize = 60
$history = @{
    CPUUsage = New-Object System.Collections.Queue
    MemoryUsage = New-Object System.Collections.Queue
    PoolCapacity = New-Object System.Collections.Queue
    NetworkLatency = New-Object System.Collections.Queue
    Timestamp = New-Object System.Collections.Queue
}

###############################################################################
# HELPER FUNCTIONS
###############################################################################

function Get-ColorForValue {
    param(
        [int]$Value,
        [int]$WarnThreshold = 80,
        [int]$CritThreshold = 90
    )

    if ($Value -ge $CritThreshold) { return 'Red' }
    if ($Value -ge $WarnThreshold) { return 'Yellow' }
    return 'Green'
}

function Draw-ProgressBar {
    param(
        [int]$Value,
        [int]$Max = 100,
        [int]$Width = 40,
        [int]$WarnThreshold = 80,
        [int]$CritThreshold = 90
    )

    $percent = [math]::Min(100, [math]::Round(($Value / $Max) * 100))
    $filled = [math]::Round(($percent / 100) * $Width)
    $empty = $Width - $filled

    $color = Get-ColorForValue -Value $percent -WarnThreshold $WarnThreshold -CritThreshold $CritThreshold

    $bar = ('[' + ('█' * $filled) + ('░' * $empty) + ']')
    Write-Host "$bar " -NoNewline -ForegroundColor $color
    Write-Host "$percent%" -ForegroundColor $color
}

function Draw-SparkLine {
    param(
        [System.Collections.Queue]$Data,
        [int]$Width = 50,
        [int]$Height = 8
    )

    if ($Data.Count -eq 0) {
        return " " * $Width
    }

    $values = @($Data.ToArray())
    $max = ($values | Measure-Object -Maximum).Maximum
    $min = ($values | Measure-Object -Minimum).Minimum

    if ($max -eq $min) {
        $max = $min + 1
    }

    $chars = @(' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█')
    $range = $max - $min

    $output = ""
    foreach ($val in $values | Select-Object -Last $Width) {
        $normalized = ($val - $min) / $range
        $index = [math]::Floor($normalized * ($chars.Count - 1))
        $output += $chars[$index]
    }

    return $output
}

function Get-BabyNasIP {
    if ($config -and $config.babyNAS.ip -and $config.babyNAS.ip -ne "") {
        return $config.babyNAS.ip
    }

    # Try to detect from Hyper-V
    try {
        $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1
        if ($vm) {
            $vmNet = Get-VMNetworkAdapter -VM $vm
            if ($vmNet.IPAddresses) {
                $ip = ($vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
                if ($ip) { return $ip }
            }
        }
    } catch {}

    return ""
}

function Get-MainNasIP {
    if ($config -and $config.mainNAS.ip) {
        return $config.mainNAS.ip
    }
    return "10.0.0.89"
}

function Get-VMMetrics {
    try {
        $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1
        if ($vm) {
            return @{
                State = $vm.State
                CPUUsage = $vm.CPUUsage
                MemoryAssigned = $vm.MemoryAssigned
                MemoryDemand = $vm.MemoryDemand
                Uptime = $vm.Uptime
                Status = $vm.Status
            }
        }
    } catch {}
    return $null
}

function Get-PoolMetrics {
    param([string]$IP)

    if ([string]::IsNullOrEmpty($IP)) { return $null }

    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        if (-not (Test-Path $sshKey)) {
            $sshKey = "$env:USERPROFILE\.ssh\truenas_admin_10_0_0_89"
        }

        if (Test-Path $sshKey) {
            $sshArgs = @("-i", $sshKey, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=3", "root@$IP")
            $output = & ssh @sshArgs "zpool list -H -o name,size,alloc,free,cap,health tank" 2>$null

            if ($output) {
                $parts = $output -split '\s+'
                return @{
                    Name = $parts[0]
                    Size = $parts[1]
                    Allocated = $parts[2]
                    Free = $parts[3]
                    Capacity = [int]($parts[4] -replace '%', '')
                    Health = $parts[5]
                }
            }
        }
    } catch {}
    return $null
}

function Get-NetworkLatency {
    param([string]$IP)

    if ([string]::IsNullOrEmpty($IP)) { return -1 }

    try {
        $ping = Test-Connection -ComputerName $IP -Count 1 -ErrorAction SilentlyContinue
        if ($ping) {
            return $ping.ResponseTime
        }
    } catch {}
    return -1
}

function Get-ReplicationStatus {
    param([string]$IP)

    if ([string]::IsNullOrEmpty($IP)) { return $null }

    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        if (Test-Path $sshKey) {
            $sshArgs = @("-i", $sshKey, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=3", "root@$IP")
            $lastRepl = & ssh @sshArgs "tail -5 /var/log/replication.log 2>/dev/null | grep -E 'Complete|Failed'" 2>$null

            if ($lastRepl) {
                if ($lastRepl -match "Complete") {
                    return @{ Status = "Success"; LastRun = "Recently" }
                } else {
                    return @{ Status = "Failed"; LastRun = "Check Logs" }
                }
            }
        }
    } catch {}
    return @{ Status = "Unknown"; LastRun = "N/A" }
}

function Get-DiskTemperatures {
    param([string]$IP)

    if ([string]::IsNullOrEmpty($IP)) { return @() }

    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        if (Test-Path $sshKey) {
            $sshArgs = @("-i", $sshKey, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=3", "root@$IP")
            $output = & ssh @sshArgs "for disk in \$(zpool status tank | grep '/dev/' | awk '{print \$1}'); do smartctl -A \$disk 2>/dev/null | grep -i temperature | head -1; done" 2>$null

            $temps = @()
            if ($output) {
                foreach ($line in $output) {
                    if ($line -match '(\d+)\s+\(') {
                        $temps += [int]$Matches[1]
                    } elseif ($line -match '\s+(\d+)\s+\d+\s+\d+\s+') {
                        $temps += [int]$Matches[1]
                    }
                }
            }
            return $temps
        }
    } catch {}
    return @()
}

###############################################################################
# MAIN DASHBOARD LOOP
###############################################################################

$babyNasIP = Get-BabyNasIP
$mainNasIP = Get-MainNasIP

Write-Host "Starting dashboard..." -ForegroundColor Cyan
Write-Host "Baby NAS IP: $babyNasIP" -ForegroundColor Gray
Write-Host "Press Ctrl+C to exit" -ForegroundColor Gray
Start-Sleep -Seconds 2

while ($true) {
    try {
        Clear-Host

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

        # Collect metrics
        $vmMetrics = Get-VMMetrics
        $poolMetrics = Get-PoolMetrics -IP $babyNasIP
        $latency = Get-NetworkLatency -IP $babyNasIP
        $replStatus = Get-ReplicationStatus -IP $babyNasIP
        $diskTemps = Get-DiskTemperatures -IP $babyNasIP

        # Update history
        if ($vmMetrics) {
            if ($history.CPUUsage.Count -ge $historySize) { $history.CPUUsage.Dequeue() | Out-Null }
            $history.CPUUsage.Enqueue($vmMetrics.CPUUsage)

            $memPercent = [math]::Round(($vmMetrics.MemoryDemand / $vmMetrics.MemoryAssigned) * 100)
            if ($history.MemoryUsage.Count -ge $historySize) { $history.MemoryUsage.Dequeue() | Out-Null }
            $history.MemoryUsage.Enqueue($memPercent)
        }

        if ($poolMetrics) {
            if ($history.PoolCapacity.Count -ge $historySize) { $history.PoolCapacity.Dequeue() | Out-Null }
            $history.PoolCapacity.Enqueue($poolMetrics.Capacity)
        }

        if ($latency -gt 0) {
            if ($history.NetworkLatency.Count -ge $historySize) { $history.NetworkLatency.Dequeue() | Out-Null }
            $history.NetworkLatency.Enqueue($latency)
        }

        if ($history.Timestamp.Count -ge $historySize) { $history.Timestamp.Dequeue() | Out-Null }
        $history.Timestamp.Enqueue($timestamp)

        ###############################################################################
        # RENDER DASHBOARD
        ###############################################################################

        Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                                                                                  ║
║                              Baby NAS Monitoring Dashboard                                       ║
║                                                                                                  ║
╚══════════════════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

        Write-Host ""
        Write-Host "  Last Update: $timestamp" -ForegroundColor Gray
        Write-Host "  Refresh: ${RefreshSeconds}s" -ForegroundColor Gray
        Write-Host ""

        # VM STATUS
        Write-Host "┌─ Virtual Machine ─────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
        if ($vmMetrics) {
            $stateColor = if ($vmMetrics.State -eq "Running") { "Green" } else { "Red" }
            Write-Host "  State:    " -NoNewline
            Write-Host $vmMetrics.State -ForegroundColor $stateColor
            Write-Host "  Uptime:   $($vmMetrics.Uptime.Days)d $($vmMetrics.Uptime.Hours)h $($vmMetrics.Uptime.Minutes)m" -ForegroundColor Gray

            Write-Host ""
            Write-Host "  CPU Usage:    " -NoNewline
            Draw-ProgressBar -Value $vmMetrics.CPUUsage -Max 100 -Width 40

            $memPercent = [math]::Round(($vmMetrics.MemoryDemand / $vmMetrics.MemoryAssigned) * 100)
            $memGB = [math]::Round($vmMetrics.MemoryDemand / 1GB, 2)
            $memTotalGB = [math]::Round($vmMetrics.MemoryAssigned / 1GB, 2)
            Write-Host "  Memory:       " -NoNewline
            Draw-ProgressBar -Value $memPercent -Max 100 -Width 40
            Write-Host "                $memGB GB / $memTotalGB GB" -ForegroundColor Gray

            if (-not $Compact -and $history.CPUUsage.Count -gt 1) {
                Write-Host ""
                Write-Host "  CPU History:  " -NoNewline -ForegroundColor DarkGray
                Write-Host (Draw-SparkLine -Data $history.CPUUsage -Width 60) -ForegroundColor Cyan
                Write-Host "  Mem History:  " -NoNewline -ForegroundColor DarkGray
                Write-Host (Draw-SparkLine -Data $history.MemoryUsage -Width 60) -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Status: VM not found or not accessible" -ForegroundColor Red
        }
        Write-Host "└───────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
        Write-Host ""

        # NETWORK STATUS
        Write-Host "┌─ Network ─────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
        Write-Host "  Baby NAS ($babyNasIP):  " -NoNewline
        if ($latency -gt 0) {
            $pingColor = if ($latency -lt 5) { "Green" } elseif ($latency -lt 20) { "Yellow" } else { "Red" }
            Write-Host "Online" -NoNewline -ForegroundColor Green
            Write-Host " (${latency}ms)" -ForegroundColor $pingColor
        } else {
            Write-Host "Offline" -ForegroundColor Red
        }

        $mainLatency = Get-NetworkLatency -IP $mainNasIP
        Write-Host "  Main NAS ($mainNasIP): " -NoNewline
        if ($mainLatency -gt 0) {
            $pingColor = if ($mainLatency -lt 5) { "Green" } elseif ($mainLatency -lt 20) { "Yellow" } else { "Red" }
            Write-Host "Online" -NoNewline -ForegroundColor Green
            Write-Host " (${mainLatency}ms)" -ForegroundColor $pingColor
        } else {
            Write-Host "Offline" -ForegroundColor Red
        }

        if (-not $Compact -and $history.NetworkLatency.Count -gt 1) {
            Write-Host ""
            Write-Host "  Latency:      " -NoNewline -ForegroundColor DarkGray
            Write-Host (Draw-SparkLine -Data $history.NetworkLatency -Width 60) -ForegroundColor Green
        }
        Write-Host "└───────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
        Write-Host ""

        # STORAGE STATUS
        Write-Host "┌─ Storage Pool ────────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
        if ($poolMetrics) {
            $healthColor = if ($poolMetrics.Health -eq "ONLINE") { "Green" } else { "Red" }
            Write-Host "  Pool:     tank" -ForegroundColor Gray
            Write-Host "  Health:   " -NoNewline
            Write-Host $poolMetrics.Health -ForegroundColor $healthColor
            Write-Host "  Size:     $($poolMetrics.Size)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  Capacity:     " -NoNewline
            Draw-ProgressBar -Value $poolMetrics.Capacity -Max 100 -Width 40
            Write-Host "                $($poolMetrics.Allocated) used / $($poolMetrics.Free) free" -ForegroundColor Gray

            if (-not $Compact -and $history.PoolCapacity.Count -gt 1) {
                Write-Host ""
                Write-Host "  Cap History:  " -NoNewline -ForegroundColor DarkGray
                Write-Host (Draw-SparkLine -Data $history.PoolCapacity -Width 60) -ForegroundColor Magenta
            }
        } else {
            Write-Host "  Status: Unable to query pool status" -ForegroundColor Red
        }
        Write-Host "└───────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
        Write-Host ""

        # DISK TEMPERATURES
        if ($diskTemps.Count -gt 0) {
            Write-Host "┌─ Disk Temperatures ───────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
            for ($i = 0; $i -lt $diskTemps.Count; $i++) {
                $temp = $diskTemps[$i]
                $tempColor = Get-ColorForValue -Value $temp -WarnThreshold 45 -CritThreshold 55
                Write-Host "  Disk $($i+1):    " -NoNewline
                Write-Host "${temp}°C" -ForegroundColor $tempColor
            }
            Write-Host "└───────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
            Write-Host ""
        }

        # REPLICATION STATUS
        Write-Host "┌─ Replication ─────────────────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
        if ($replStatus) {
            $replColor = if ($replStatus.Status -eq "Success") { "Green" } elseif ($replStatus.Status -eq "Failed") { "Red" } else { "Yellow" }
            Write-Host "  Status:   " -NoNewline
            Write-Host $replStatus.Status -ForegroundColor $replColor
            Write-Host "  Last Run: $($replStatus.LastRun)" -ForegroundColor Gray
        } else {
            Write-Host "  Status: Unable to check replication" -ForegroundColor Yellow
        }
        Write-Host "└───────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan
        Write-Host ""

        # ALERTS SUMMARY
        $alertCount = 0
        $alerts = @()

        if ($vmMetrics -and $vmMetrics.State -ne "Running") {
            $alertCount++
            $alerts += "VM not running"
        }
        if ($vmMetrics -and $vmMetrics.CPUUsage -gt 90) {
            $alertCount++
            $alerts += "High CPU usage"
        }
        if ($poolMetrics -and $poolMetrics.Capacity -gt 85) {
            $alertCount++
            $alerts += "Pool capacity high"
        }
        if ($poolMetrics -and $poolMetrics.Health -ne "ONLINE") {
            $alertCount++
            $alerts += "Pool health degraded"
        }
        if ($latency -lt 0) {
            $alertCount++
            $alerts += "Baby NAS offline"
        }
        if ($diskTemps.Count -gt 0 -and ($diskTemps | Where-Object { $_ -gt 50 }).Count -gt 0) {
            $alertCount++
            $alerts += "High disk temperature"
        }

        if ($alertCount -gt 0) {
            Write-Host "┌─ Active Alerts ───────────────────────────────────────────────────────────────────────┐" -ForegroundColor Red
            foreach ($alert in $alerts) {
                Write-Host "  ⚠ $alert" -ForegroundColor Red
            }
            Write-Host "└───────────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Red
            Write-Host ""
        }

        # FOOTER
        Write-Host "Press Ctrl+C to exit | Refreshing in ${RefreshSeconds}s..." -ForegroundColor DarkGray

    } catch {
        Write-Host "Error updating dashboard: $($_.Exception.Message)" -ForegroundColor Red
    }

    Start-Sleep -Seconds $RefreshSeconds
}
