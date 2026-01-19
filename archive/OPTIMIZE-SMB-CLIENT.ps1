#Requires -RunAsAdministrator
###############################################################################
# SMB Client Optimization for Baby NAS
# Optimizes Windows SMB client settings for maximum backup performance
###############################################################################

param(
    [switch]$TestOnly,
    [switch]$Verbose
)

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "      SMB Client Optimization for Baby NAS                     " -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

$logFile = "C:\Logs\smb-optimization-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
if (-not (Test-Path "C:\Logs")) {
    New-Item -ItemType Directory -Path "C:\Logs" -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        default   { Write-Host $logMessage -ForegroundColor White }
    }

    $logMessage | Out-File -FilePath $logFile -Append
}

###############################################################################
# Step 1: Get Current SMB Configuration
###############################################################################
Write-Host "[1/5] Current SMB Client Configuration" -ForegroundColor Cyan
Write-Host "---------------------------------------" -ForegroundColor Gray

$currentConfig = Get-SmbClientConfiguration

$settings = @(
    @{Name="EnableLargeMtu"; Current=$currentConfig.EnableLargeMtu; Optimal=$true; Description="Large MTU Support"},
    @{Name="EnableMultiChannel"; Current=$currentConfig.EnableMultiChannel; Optimal=$true; Description="SMB Multichannel"},
    @{Name="EnableBandwidthThrottling"; Current=$currentConfig.EnableBandwidthThrottling; Optimal=$false; Description="Bandwidth Throttling"},
    @{Name="ConnectionCountPerRssNetworkInterface"; Current=$currentConfig.ConnectionCountPerRssNetworkInterface; Optimal=4; Description="Connections per NIC"},
    @{Name="DirectoryCacheLifetime"; Current=$currentConfig.DirectoryCacheLifetime; Optimal=10; Description="Directory Cache (sec)"},
    @{Name="FileInfoCacheLifetime"; Current=$currentConfig.FileInfoCacheLifetime; Optimal=10; Description="File Info Cache (sec)"},
    @{Name="FileNotFoundCacheLifetime"; Current=$currentConfig.FileNotFoundCacheLifetime; Optimal=5; Description="File Not Found Cache"}
)

foreach ($setting in $settings) {
    $status = if ($setting.Current -eq $setting.Optimal) { "[OK]" } else { "[CHANGE]" }
    $color = if ($setting.Current -eq $setting.Optimal) { "Green" } else { "Yellow" }
    Write-Host ("  {0,-8} {1,-40} Current: {2,-10} Optimal: {3}" -f $status, $setting.Description, $setting.Current, $setting.Optimal) -ForegroundColor $color
}

if ($TestOnly) {
    Write-Host ""
    Write-Host "Test mode - no changes applied." -ForegroundColor Yellow
    Write-Host "Run without -TestOnly to apply optimizations." -ForegroundColor Yellow
    exit 0
}

###############################################################################
# Step 2: Apply SMB Optimizations
###############################################################################
Write-Host ""
Write-Host "[2/5] Applying SMB Client Optimizations" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    # Enable Large MTU
    Set-SmbClientConfiguration -EnableLargeMtu $true -Force
    Write-Log "Enabled Large MTU support" "SUCCESS"

    # Enable Multichannel
    Set-SmbClientConfiguration -EnableMultiChannel $true -Force
    Write-Log "Enabled SMB Multichannel" "SUCCESS"

    # Disable Bandwidth Throttling
    Set-SmbClientConfiguration -EnableBandwidthThrottling $false -Force
    Write-Log "Disabled bandwidth throttling" "SUCCESS"

    # Increase Connections per NIC
    Set-SmbClientConfiguration -ConnectionCountPerRssNetworkInterface 4 -Force
    Write-Log "Increased connections per NIC to 4" "SUCCESS"

    # Optimize Cache Lifetimes
    Set-SmbClientConfiguration -DirectoryCacheLifetime 10 -Force
    Set-SmbClientConfiguration -FileInfoCacheLifetime 10 -Force
    Set-SmbClientConfiguration -FileNotFoundCacheLifetime 5 -Force
    Write-Log "Optimized cache lifetimes" "SUCCESS"

} catch {
    Write-Log "Error applying settings: $($_.Exception.Message)" "ERROR"
}

###############################################################################
# Step 3: Network Adapter Optimization
###############################################################################
Write-Host ""
Write-Host "[3/5] Network Adapter Optimization" -ForegroundColor Cyan
Write-Host "-----------------------------------" -ForegroundColor Gray

$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Hyper-V|Virtual' }

foreach ($adapter in $adapters) {
    Write-Log "Processing adapter: $($adapter.Name)" "INFO"

    try {
        # Enable RSS if available
        $rss = Get-NetAdapterRss -Name $adapter.Name -ErrorAction SilentlyContinue
        if ($rss -and -not $rss.Enabled) {
            Enable-NetAdapterRss -Name $adapter.Name -ErrorAction SilentlyContinue
            Write-Log "  Enabled RSS on $($adapter.Name)" "SUCCESS"
        }

        # Enable Large Send Offload
        $lso = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*LsoV2IPv4" -ErrorAction SilentlyContinue
        if ($lso) {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*LsoV2IPv4" -RegistryValue 1 -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*LsoV2IPv6" -RegistryValue 1 -ErrorAction SilentlyContinue
            Write-Log "  Enabled Large Send Offload on $($adapter.Name)" "SUCCESS"
        }

    } catch {
        Write-Log "  Warning: Could not optimize $($adapter.Name): $($_.Exception.Message)" "WARNING"
    }
}

###############################################################################
# Step 4: Test Connectivity
###############################################################################
Write-Host ""
Write-Host "[4/5] Testing Connectivity" -ForegroundColor Cyan
Write-Host "--------------------------" -ForegroundColor Gray

# Load config if available
$configPath = "$PSScriptRoot\monitoring-config.json"
$babyNasIP = "172.21.203.18"
$mainNasIP = "10.0.0.89"

if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $babyNasIP = $config.babyNAS.ip
        $mainNasIP = $config.mainNAS.ip
    } catch {
        Write-Log "Could not load config, using defaults" "WARNING"
    }
}

$targets = @(
    @{Name="Baby NAS"; IP=$babyNasIP; Port=445},
    @{Name="Main NAS"; IP=$mainNasIP; Port=445}
)

foreach ($target in $targets) {
    Write-Host ""
    Write-Host "Testing $($target.Name) ($($target.IP)):" -ForegroundColor White

    # Ping test
    $ping = Test-Connection -ComputerName $target.IP -Count 5 -ErrorAction SilentlyContinue
    if ($ping) {
        $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
        Write-Log "  Ping: $([math]::Round($avgLatency, 2)) ms average" "SUCCESS"
    } else {
        Write-Log "  Ping: Failed (host unreachable)" "ERROR"
        continue
    }

    # SMB port test
    $smbTest = Test-NetConnection -ComputerName $target.IP -Port 445 -WarningAction SilentlyContinue
    if ($smbTest.TcpTestSucceeded) {
        Write-Log "  SMB Port 445: Open" "SUCCESS"
    } else {
        Write-Log "  SMB Port 445: Closed" "ERROR"
    }

    # SSH port test
    $sshTest = Test-NetConnection -ComputerName $target.IP -Port 22 -WarningAction SilentlyContinue
    if ($sshTest.TcpTestSucceeded) {
        Write-Log "  SSH Port 22: Open" "SUCCESS"
    } else {
        Write-Log "  SSH Port 22: Closed or filtered" "WARNING"
    }
}

###############################################################################
# Step 5: SMB Connection Test
###############################################################################
Write-Host ""
Write-Host "[5/5] SMB Connection Details" -ForegroundColor Cyan
Write-Host "----------------------------" -ForegroundColor Gray

$smbConnections = Get-SmbConnection -ErrorAction SilentlyContinue

if ($smbConnections) {
    Write-Host ""
    Write-Host "Active SMB Connections:" -ForegroundColor White
    $smbConnections | Format-Table ServerName, ShareName, Dialect, NumOpens -AutoSize

    # Check for optimal SMB version
    $dialects = $smbConnections | Select-Object -ExpandProperty Dialect -Unique
    foreach ($dialect in $dialects) {
        if ($dialect -match "3\." -or $dialect -eq "3.0" -or $dialect -eq "3.02" -or $dialect -eq "3.1.1") {
            Write-Log "SMB version $dialect in use (optimal)" "SUCCESS"
        } else {
            Write-Log "SMB version $dialect in use (consider upgrade)" "WARNING"
        }
    }
} else {
    Write-Log "No active SMB connections found" "INFO"
    Write-Host ""
    Write-Host "To test SMB connection, run:" -ForegroundColor Yellow
    Write-Host "  net use \\$babyNasIP\WindowsBackup /user:root" -ForegroundColor Gray
}

###############################################################################
# Summary
###############################################################################
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "      SMB Client Optimization Complete!                        " -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Optimizations Applied:" -ForegroundColor White
Write-Host "  - Large MTU: Enabled" -ForegroundColor Gray
Write-Host "  - Multichannel: Enabled" -ForegroundColor Gray
Write-Host "  - Bandwidth Throttling: Disabled" -ForegroundColor Gray
Write-Host "  - Connections per NIC: 4" -ForegroundColor Gray
Write-Host "  - Cache Lifetimes: Optimized for backups" -ForegroundColor Gray
Write-Host ""

Write-Host "Performance Tips:" -ForegroundColor Yellow
Write-Host "  1. Use mapped drives for backups (consistent connection)" -ForegroundColor Gray
Write-Host "  2. Avoid antivirus scanning of backup targets" -ForegroundColor Gray
Write-Host "  3. Schedule large backups during off-peak hours" -ForegroundColor Gray
Write-Host "  4. Monitor with: Get-SmbConnection | Format-Table" -ForegroundColor Gray
Write-Host ""

Write-Host "Log file: $logFile" -ForegroundColor Cyan
Write-Host ""
