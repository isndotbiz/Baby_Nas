#Requires -RunAsAdministrator
###############################################################################
# Baby NAS VM Creation Script
# Creates Hyper-V VM with disk passthrough for TrueNAS Baby NAS
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$VMName = "TrueNAS-BabyNAS",

    [Parameter(Mandatory=$false)]
    [string]$ISOPath = "",

    [Parameter(Mandatory=$false)]
    [int64]$MemoryGB = 16,

    [Parameter(Mandatory=$false)]
    [int]$CPUCount = 4,

    [Parameter(Mandatory=$false)]
    [int]$OSDiskSizeGB = 32,

    [Parameter(Mandatory=$false)]
    [string[]]$DataDiskNumbers = @(),  # e.g., @(1, 2, 3) for 3x 6TB

    [Parameter(Mandatory=$false)]
    [string[]]$CacheDiskNumbers = @()  # e.g., @(4, 5) for 2x 256GB SSDs
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                  Baby NAS Hyper-V VM Creation                           ║
║                                                                          ║
║  This script creates a TrueNAS SCALE VM with physical disk passthrough  ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""

###############################################################################
# Step 1: Check Prerequisites
###############################################################################
Write-Host "=== Checking Prerequisites ===" -ForegroundColor Green

# Check if Hyper-V is installed
$hyperv = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
if ($hyperv.State -ne "Enabled") {
    Write-Host "✗ Hyper-V is not enabled!" -ForegroundColor Red
    Write-Host "Enable it with:" -ForegroundColor Yellow
    Write-Host "  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" -ForegroundColor White
    exit 1
}
Write-Host "✓ Hyper-V is enabled" -ForegroundColor Green

# Check if VM already exists
if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    Write-Host "✗ VM '$VMName' already exists!" -ForegroundColor Red
    $overwrite = Read-Host "Delete existing VM and continue? (yes/no)"
    if ($overwrite -eq "yes") {
        if ((Get-VM -Name $VMName).State -eq "Running") {
            Stop-VM -Name $VMName -Force
        }
        Remove-VM -Name $VMName -Force
        Write-Host "✓ Existing VM removed" -ForegroundColor Green
    } else {
        exit 1
    }
}

###############################################################################
# Step 2: Get ISO Path
###############################################################################
if ([string]::IsNullOrEmpty($ISOPath)) {
    Write-Host ""
    Write-Host "Looking for TrueNAS ISO..." -ForegroundColor Yellow

    # Check common locations
    $commonPaths = @(
        "D:\ISOs\TrueNAS-SCALE*.iso",
        "C:\ISOs\TrueNAS-SCALE*.iso",
        "$env:USERPROFILE\Downloads\TrueNAS-SCALE*.iso"
    )

    foreach ($path in $commonPaths) {
        $found = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $ISOPath = $found.FullName
            break
        }
    }

    if ([string]::IsNullOrEmpty($ISOPath)) {
        Write-Host "✗ TrueNAS ISO not found!" -ForegroundColor Red
        Write-Host "Download from: https://www.truenas.com/download-truenas-scale/" -ForegroundColor Cyan
        $ISOPath = Read-Host "Enter full path to TrueNAS SCALE ISO"
    }
}

if (-not (Test-Path $ISOPath)) {
    Write-Host "✗ ISO not found: $ISOPath" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Using ISO: $ISOPath" -ForegroundColor Green

###############################################################################
# Step 3: Identify Disks for Passthrough
###############################################################################
Write-Host ""
Write-Host "=== Identifying Disks ===" -ForegroundColor Green

# Show all physical disks
Write-Host "`nAvailable Physical Disks:" -ForegroundColor Yellow
Get-Disk | Where-Object BusType -ne "USB" | Format-Table Number, FriendlyName, @{L='Size(GB)';E={[math]::Round($_.Size/1GB,2)}}, PartitionStyle, OperationalStatus

if ($DataDiskNumbers.Count -eq 0) {
    Write-Host "`nSelect disks for DATA (RAIDZ1 pool):" -ForegroundColor Cyan
    Write-Host "Enter disk numbers separated by commas (e.g., 1,2,3 for 3x 6TB disks)" -ForegroundColor White
    $input = Read-Host "Data disk numbers"
    $DataDiskNumbers = $input -split ',' | ForEach-Object { [int]$_.Trim() }
}

if ($CacheDiskNumbers.Count -eq 0) {
    Write-Host "`nSelect disks for CACHE (SLOG + L2ARC):" -ForegroundColor Cyan
    Write-Host "Enter disk numbers separated by commas (e.g., 4,5 for 2x 256GB SSDs)" -ForegroundColor White
    $input = Read-Host "Cache disk numbers"
    $CacheDiskNumbers = $input -split ',' | ForEach-Object { [int]$_.Trim() }
}

Write-Host "`nSelected Configuration:" -ForegroundColor Yellow
Write-Host "  Data Disks (RAIDZ1): $($DataDiskNumbers -join ', ')" -ForegroundColor White
Write-Host "  Cache Disks (SLOG/L2ARC): $($CacheDiskNumbers -join ', ')" -ForegroundColor White

$confirm = Read-Host "`nContinue with this configuration? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Aborted by user" -ForegroundColor Yellow
    exit 0
}

###############################################################################
# Step 4: Take Disks Offline
###############################################################################
Write-Host ""
Write-Host "=== Taking Disks Offline ===" -ForegroundColor Green

$AllDisks = $DataDiskNumbers + $CacheDiskNumbers

foreach ($diskNum in $AllDisks) {
    $disk = Get-Disk -Number $diskNum

    Write-Host "Processing Disk $diskNum ($($disk.FriendlyName))..." -ForegroundColor Cyan

    # Warn if disk has partitions
    if ($disk.PartitionStyle -ne "RAW") {
        Write-Host "  WARNING: Disk has partitions! Data will be lost." -ForegroundColor Red
        $confirmWipe = Read-Host "  Continue and wipe disk $diskNum? (yes/no)"
        if ($confirmWipe -ne "yes") {
            Write-Host "Skipping disk $diskNum" -ForegroundColor Yellow
            continue
        }
    }

    # Set offline
    if ($disk.OperationalStatus -eq "Online") {
        Set-Disk -Number $diskNum -IsOffline $true
        Write-Host "  ✓ Disk $diskNum set offline" -ForegroundColor Green
    } else {
        Write-Host "  • Disk $diskNum already offline" -ForegroundColor Gray
    }
}

###############################################################################
# Step 5: Create VM
###############################################################################
Write-Host ""
Write-Host "=== Creating Hyper-V VM ===" -ForegroundColor Green

# Get default VM path
$vmPath = (Get-VMHost).VirtualMachinePath

Write-Host "Creating VM: $VMName" -ForegroundColor Cyan
Write-Host "  Location: $vmPath" -ForegroundColor White
Write-Host "  Memory: ${MemoryGB}GB" -ForegroundColor White
Write-Host "  CPUs: $CPUCount" -ForegroundColor White
Write-Host "  OS Disk: ${OSDiskSizeGB}GB" -ForegroundColor White

# Create VM
New-VM -Name $VMName `
    -MemoryStartupBytes ($MemoryGB * 1GB) `
    -Generation 2 `
    -NewVHDPath "$vmPath\$VMName\Virtual Hard Disks\os.vhdx" `
    -NewVHDSizeBytes ($OSDiskSizeGB * 1GB) `
    -SwitchName (Get-VMSwitch | Select-Object -First 1).Name

Write-Host "✓ VM created" -ForegroundColor Green

# Configure VM
Write-Host "Configuring VM settings..." -ForegroundColor Cyan

Set-VM -Name $VMName -ProcessorCount $CPUCount
Set-VM -Name $VMName -StaticMemory
Set-VM -Name $VMName -MemoryStartupBytes ($MemoryGB * 1GB)
Set-VM -Name $VMName -CheckpointType Disabled

# Enable nested virtualization (optional, useful for containers)
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true

Write-Host "✓ VM configured" -ForegroundColor Green

###############################################################################
# Step 6: Add Physical Disks to VM
###############################################################################
Write-Host ""
Write-Host "=== Attaching Physical Disks to VM ===" -ForegroundColor Green

foreach ($diskNum in $AllDisks) {
    $disk = Get-Disk -Number $diskNum
    $diskPath = "\\.\PhysicalDrive$diskNum"

    Write-Host "Attaching Disk $diskNum ($($disk.FriendlyName))..." -ForegroundColor Cyan

    try {
        Add-VMHardDiskDrive -VMName $VMName `
            -ControllerType SCSI `
            -ControllerNumber 0 `
            -DiskNumber $diskNum

        Write-Host "  ✓ Disk $diskNum attached" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to attach disk $diskNum : $_" -ForegroundColor Red
    }
}

###############################################################################
# Step 7: Attach ISO
###############################################################################
Write-Host ""
Write-Host "=== Attaching Installation ISO ===" -ForegroundColor Green

Add-VMDvdDrive -VMName $VMName -Path $ISOPath
Write-Host "✓ ISO attached: $ISOPath" -ForegroundColor Green

# Set boot order (DVD first)
$dvd = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd
Write-Host "✓ Boot order set to DVD first" -ForegroundColor Green

###############################################################################
# Step 8: Configure Networking
###############################################################################
Write-Host ""
Write-Host "=== Configuring Network ===" -ForegroundColor Green

# Get VM network adapter
$netAdapter = Get-VMNetworkAdapter -VMName $VMName

# Enable MAC spoofing (required for some configurations)
Set-VMNetworkAdapter -VMName $VMName -MacAddressSpoofing On
Write-Host "✓ MAC spoofing enabled" -ForegroundColor Green

###############################################################################
# Summary
###############################################################################
Write-Host ""
Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                  VM Creation Complete!                                   ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host ""
Write-Host "VM Configuration Summary:" -ForegroundColor Yellow
Write-Host "  Name: $VMName" -ForegroundColor White
Write-Host "  Memory: ${MemoryGB}GB" -ForegroundColor White
Write-Host "  CPUs: $CPUCount" -ForegroundColor White
Write-Host "  OS Disk: ${OSDiskSizeGB}GB VHDX" -ForegroundColor White
Write-Host "  Data Disks: $($DataDiskNumbers.Count) disks for RAIDZ1" -ForegroundColor White
Write-Host "  Cache Disks: $($CacheDiskNumbers.Count) SSDs for SLOG/L2ARC" -ForegroundColor White
Write-Host "  Boot ISO: $ISOPath" -ForegroundColor White
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Start VM: Start-VM -Name '$VMName'" -ForegroundColor Cyan
Write-Host "  2. Connect to console: vmconnect.exe localhost '$VMName'" -ForegroundColor Cyan
Write-Host "  3. Install TrueNAS SCALE (select 32GB OS disk)" -ForegroundColor Cyan
Write-Host "  4. Set root password: uppercut%`$##" -ForegroundColor Cyan
Write-Host "  5. Note the IP address shown after reboot" -ForegroundColor Cyan
Write-Host ""

$startNow = Read-Host "Start VM now? (yes/no)"
if ($startNow -eq "yes") {
    Start-VM -Name $VMName
    Write-Host "✓ VM started" -ForegroundColor Green

    Start-Sleep -Seconds 2

    $connectNow = Read-Host "Open VM console? (yes/no)"
    if ($connectNow -eq "yes") {
        vmconnect.exe localhost $VMName
    }
}

Write-Host ""
Write-Host "✓ Setup complete! VM is ready for TrueNAS installation." -ForegroundColor Green
Write-Host ""
