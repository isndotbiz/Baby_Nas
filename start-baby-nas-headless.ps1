<#
.SYNOPSIS
Starts the Baby NAS Hyper-V VM in headless mode (no console window).

.DESCRIPTION
Ensures the TrueNAS-BabyNAS VM is running in the background without displaying
a console window. Can be run manually or scheduled as a Windows Task Scheduler job.

Features:
- Checks current VM state
- Starts VM if not running
- Waits for network connectivity (IP assignment)
- Logs all activity
- Returns exit code for automation

.PARAMETER Wait
Wait for the VM to be fully booted and reachable on network (default: 60 seconds).

.PARAMETER NoLog
Skip logging to file (logs go to console only).

.PARAMETER VMName
Name of the VM to start (default: TrueNAS-BabyNAS).

.PARAMETER MaxWaitSeconds
Maximum seconds to wait for VM to be network-reachable (default: 120).

.EXAMPLE
# Start VM and wait for network
.\start-baby-nas-headless.ps1

# Start VM without waiting
.\start-baby-nas-headless.ps1 -NoWait

# Schedule as Windows Task
# See "Setup Task Scheduler" section below

.NOTES
Requires: Administrator privileges
Prerequisites: Hyper-V feature enabled
Log location: C:\Logs\start-baby-nas-headless-*.log
#>

param(
    [switch]$Wait = $true,
    [switch]$NoWait,
    [switch]$NoLog,
    [string]$VMName = "TrueNAS-BabyNAS",
    [int]$MaxWaitSeconds = 120,
    [string]$ExpectedIP = "172.21.203.18"
)

# Override Wait if NoWait is specified
if ($NoWait) {
    $Wait = $false
}

# Setup logging
$logDir = "C:\Logs"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $logDir "start-baby-nas-headless-$timestamp.log"

if (-not $NoLog) {
    New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"

    Write-Host $logMessage -ForegroundColor $(switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "Gray" }
    })

    if (-not $NoLog) {
        Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
    }
}

function Check-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-VMStatus {
    param([string]$Name)

    try {
        $vm = Get-VM -Name $Name -ErrorAction Stop
        return @{
            Name   = $vm.Name
            State  = $vm.State
            Status = $vm.Status
            Uptime = $vm.Uptime
            Found  = $true
        }
    } catch {
        return @{
            Name  = $Name
            Found = $false
            Error = $_.Exception.Message
        }
    }
}

function Start-TargetVM {
    param([string]$Name)

    try {
        Write-Log "Starting VM: $Name" INFO
        Start-VM -Name $Name -ErrorAction Stop
        Write-Log "VM start command issued successfully" SUCCESS
        return $true
    } catch {
        Write-Log "Failed to start VM: $($_.Exception.Message)" ERROR
        return $false
    }
}

function Wait-ForNetworkConnectivity {
    param(
        [string]$IP,
        [int]$MaxSeconds
    )

    Write-Log "Waiting for network connectivity to $IP (max $MaxSeconds seconds)..." INFO

    $startTime = Get-Date
    $connected = $false

    while ((Get-Date) - $startTime -lt [timespan]::FromSeconds($MaxSeconds)) {
        try {
            $ping = Test-Connection -ComputerName $IP -Count 1 -Quiet -ErrorAction SilentlyContinue

            if ($ping) {
                Write-Log "✓ Network connectivity confirmed to $IP" SUCCESS
                $connected = $true
                break
            }
        } catch {
            # Silently continue
        }

        Start-Sleep -Seconds 3
        $elapsed = [math]::Floor(((Get-Date) - $startTime).TotalSeconds)
        Write-Host "  ... waiting ($elapsed/$MaxSeconds seconds)" -ForegroundColor Gray -NoNewline
        Write-Host "`r" -NoNewline
    }

    if (-not $connected) {
        Write-Log "⚠ Timeout waiting for network connectivity to $IP" WARNING
    }

    return $connected
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Log "Baby NAS Headless Startup Script" INFO
Write-Log "VM Name: $VMName" INFO
Write-Log "Admin Rights: $(Check-AdminRights)" INFO
Write-Log "" INFO

# Check admin rights
if (-not (Check-AdminRights)) {
    Write-Log "❌ This script requires Administrator privileges" ERROR
    Write-Log "Please run PowerShell as Administrator and try again" ERROR
    exit 1
}

# Check VM exists
$vmStatus = Get-VMStatus -Name $VMName
if (-not $vmStatus.Found) {
    Write-Log "❌ VM not found: $VMName" ERROR
    Write-Log "Error: $($vmStatus.Error)" ERROR
    exit 2
}

Write-Log "✓ VM found: $VMName" SUCCESS

# Check current state
Write-Log "Current VM State: $($vmStatus.State)" INFO

if ($vmStatus.State -eq "Running") {
    Write-Log "✓ VM is already running (uptime: $($vmStatus.Uptime))" SUCCESS

    # Even if running, test connectivity
    if ($Wait) {
        $connected = Wait-ForNetworkConnectivity -IP $ExpectedIP -MaxSeconds 30
        if ($connected) {
            Write-Log "✓ VM is online and accessible" SUCCESS
            exit 0
        }
    }
    exit 0
}

# VM is not running, start it
Write-Log "VM is not running (state: $($vmStatus.State))" WARNING

if (Start-TargetVM -Name $VMName) {
    Write-Log "Waiting for VM to initialize..." INFO
    Start-Sleep -Seconds 10

    if ($Wait) {
        Write-Log "Waiting for network connectivity..." INFO
        $connected = Wait-ForNetworkConnectivity -IP $ExpectedIP -MaxSeconds $MaxWaitSeconds

        if ($connected) {
            Write-Log "✓ Baby NAS is ready!" SUCCESS
            exit 0
        } else {
            Write-Log "⚠ VM started but network connectivity not confirmed yet" WARNING
            Write-Log "The VM may still be booting. Check status with: .\open-vm-console.ps1" WARNING
            exit 0
        }
    }

    Write-Log "✓ Baby NAS started successfully (headless mode)" SUCCESS
    exit 0
} else {
    Write-Log "❌ Failed to start the VM" ERROR
    exit 3
}
