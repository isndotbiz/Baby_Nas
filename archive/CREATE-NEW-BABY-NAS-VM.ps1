#Requires -RunAsAdministrator
###############################################################################
# Create New Baby NAS VM - With Proper External Network
# Run this as Administrator in PowerShell
###############################################################################

$ErrorActionPreference = "Stop"
$VMName = "TrueNAS-BabyNAS-V2"
$ISOPath = "D:\ISOs\TrueNAS-SCALE-25.04.2.6.iso"
$MemoryGB = 16
$CPUCount = 4
$OSDiskSizeGB = 32
$StaticIP = "10.0.0.88"
$Gateway = "10.0.0.1"
$SubnetMask = "255.255.255.0"

Write-Host @"
==============================================================================
                    Baby NAS VM Creation - Fresh Start
==============================================================================
"@ -ForegroundColor Cyan

###############################################################################
# Step 1: Remove Old VM if exists
###############################################################################
Write-Host "`n=== Step 1: Cleaning Up Old VM ===" -ForegroundColor Yellow

$oldVMs = @("TrueNAS-BabyNAS", "TrueNAS-BabyNAS-V2", "BabyNAS")
foreach ($oldVM in $oldVMs) {
    if (Get-VM -Name $oldVM -ErrorAction SilentlyContinue) {
        Write-Host "Found old VM: $oldVM - Removing..." -ForegroundColor Red
        if ((Get-VM -Name $oldVM).State -eq "Running") {
            Stop-VM -Name $oldVM -Force -TurnOff
        }
        Remove-VM -Name $oldVM -Force
        Write-Host "  Removed $oldVM" -ForegroundColor Green
    }
}

# Clean up old VHDX files
$vmPath = (Get-VMHost).VirtualMachinePath
foreach ($oldVM in $oldVMs) {
    $oldVHDX = "$vmPath\$oldVM"
    if (Test-Path $oldVHDX) {
        Remove-Item -Path $oldVHDX -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleaned up: $oldVHDX" -ForegroundColor Green
    }
}

###############################################################################
# Step 2: Create or Verify External Virtual Switch
###############################################################################
Write-Host "`n=== Step 2: Setting Up External Network Switch ===" -ForegroundColor Yellow

$externalSwitchName = "External-BabyNAS"
$existingExternalSwitch = Get-VMSwitch | Where-Object { $_.SwitchType -eq "External" } | Select-Object -First 1

if ($existingExternalSwitch) {
    Write-Host "Found existing External switch: $($existingExternalSwitch.Name)" -ForegroundColor Green
    $switchToUse = $existingExternalSwitch.Name
} else {
    Write-Host "No External switch found. Creating one..." -ForegroundColor Yellow

    # Find physical network adapter (not virtual)
    $physicalAdapters = Get-NetAdapter -Physical | Where-Object {
        $_.Status -eq "Up" -and
        $_.InterfaceDescription -notlike "*Virtual*" -and
        $_.InterfaceDescription -notlike "*Hyper-V*"
    }

    Write-Host "`nAvailable Physical Network Adapters:" -ForegroundColor Cyan
    $physicalAdapters | Format-Table Name, InterfaceDescription, Status, LinkSpeed

    if ($physicalAdapters.Count -eq 0) {
        Write-Host "ERROR: No physical network adapters found!" -ForegroundColor Red
        exit 1
    }

    $selectedAdapter = $physicalAdapters | Select-Object -First 1
    Write-Host "Using adapter: $($selectedAdapter.Name) ($($selectedAdapter.InterfaceDescription))" -ForegroundColor Cyan

    # Create External switch
    New-VMSwitch -Name $externalSwitchName `
        -NetAdapterName $selectedAdapter.Name `
        -AllowManagementOS $true `
        -Notes "External switch for Baby NAS - connected to physical network"

    Write-Host "Created External switch: $externalSwitchName" -ForegroundColor Green
    $switchToUse = $externalSwitchName
}

Write-Host "Will use switch: $switchToUse" -ForegroundColor Green

###############################################################################
# Step 3: Check ISO
###############################################################################
Write-Host "`n=== Step 3: Checking TrueNAS ISO ===" -ForegroundColor Yellow

if (-not (Test-Path $ISOPath)) {
    Write-Host "ISO not found at: $ISOPath" -ForegroundColor Red
    $altISO = Get-ChildItem -Path "D:\ISOs\TrueNAS*.iso" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($altISO) {
        $ISOPath = $altISO.FullName
        Write-Host "Found alternative: $ISOPath" -ForegroundColor Yellow
    } else {
        Write-Host "No TrueNAS ISO found! Download from https://www.truenas.com/download-truenas-scale/" -ForegroundColor Red
        exit 1
    }
}
Write-Host "Using ISO: $ISOPath" -ForegroundColor Green

###############################################################################
# Step 4: List Available Disks for Passthrough
###############################################################################
Write-Host "`n=== Step 4: Available Disks for Passthrough ===" -ForegroundColor Yellow

$disks = Get-Disk | Where-Object { $_.BusType -ne "USB" }
$disks | Format-Table Number, FriendlyName, @{L='Size(GB)';E={[math]::Round($_.Size/1GB,0)}}, PartitionStyle, OperationalStatus -AutoSize

Write-Host @"

Disk Selection Guide:
  - OS Drive (usually Disk 0): DO NOT SELECT - Windows is here!
  - Data Disks: Select your 6TB drives for RAIDZ1 (e.g., 1,2,3)
  - Cache Disks: Select SSDs for SLOG/L2ARC (e.g., 4,5)

"@ -ForegroundColor Cyan

$dataInput = Read-Host "Enter DATA disk numbers (comma-separated, e.g., 1,2,3) or ENTER to skip passthrough"
$cacheInput = Read-Host "Enter CACHE disk numbers (comma-separated, e.g., 4,5) or ENTER to skip"

$DataDiskNumbers = @()
$CacheDiskNumbers = @()

if ($dataInput -ne "") {
    $DataDiskNumbers = $dataInput -split ',' | ForEach-Object { [int]$_.Trim() }
}
if ($cacheInput -ne "") {
    $CacheDiskNumbers = $cacheInput -split ',' | ForEach-Object { [int]$_.Trim() }
}

$AllDisks = $DataDiskNumbers + $CacheDiskNumbers

###############################################################################
# Step 5: Take Disks Offline (if any selected)
###############################################################################
if ($AllDisks.Count -gt 0) {
    Write-Host "`n=== Step 5: Taking Disks Offline ===" -ForegroundColor Yellow

    foreach ($diskNum in $AllDisks) {
        $disk = Get-Disk -Number $diskNum
        Write-Host "Processing Disk $diskNum ($($disk.FriendlyName))..." -ForegroundColor Cyan

        if ($disk.OperationalStatus -eq "Online") {
            Set-Disk -Number $diskNum -IsOffline $true
            Write-Host "  Set offline" -ForegroundColor Green
        } else {
            Write-Host "  Already offline" -ForegroundColor Gray
        }
    }
}

###############################################################################
# Step 6: Create VM
###############################################################################
Write-Host "`n=== Step 6: Creating Hyper-V VM ===" -ForegroundColor Yellow

$vmStoragePath = "$vmPath\$VMName"

New-VM -Name $VMName `
    -MemoryStartupBytes ($MemoryGB * 1GB) `
    -Generation 2 `
    -NewVHDPath "$vmStoragePath\Virtual Hard Disks\os.vhdx" `
    -NewVHDSizeBytes ($OSDiskSizeGB * 1GB) `
    -SwitchName $switchToUse

Write-Host "VM created with External switch: $switchToUse" -ForegroundColor Green

# Configure VM settings
Set-VM -Name $VMName -ProcessorCount $CPUCount
Set-VM -Name $VMName -StaticMemory
Set-VM -Name $VMName -CheckpointType Disabled
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true

# Enable MAC spoofing for network flexibility
Set-VMNetworkAdapter -VMName $VMName -MacAddressSpoofing On

Write-Host "VM configured: ${MemoryGB}GB RAM, $CPUCount CPUs" -ForegroundColor Green

###############################################################################
# Step 7: Attach Physical Disks (if any)
###############################################################################
if ($AllDisks.Count -gt 0) {
    Write-Host "`n=== Step 7: Attaching Physical Disks ===" -ForegroundColor Yellow

    foreach ($diskNum in $AllDisks) {
        try {
            Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -DiskNumber $diskNum
            Write-Host "  Attached Disk $diskNum" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to attach Disk $diskNum: $_" -ForegroundColor Red
        }
    }
}

###############################################################################
# Step 8: Attach ISO and Set Boot Order
###############################################################################
Write-Host "`n=== Step 8: Attaching Installation ISO ===" -ForegroundColor Yellow

Add-VMDvdDrive -VMName $VMName -Path $ISOPath
$dvd = Get-VMDvdDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd

Write-Host "ISO attached, boot order set" -ForegroundColor Green

###############################################################################
# Summary
###############################################################################
Write-Host @"

==============================================================================
                         VM CREATION COMPLETE!
==============================================================================

VM Configuration:
  Name:           $VMName
  Memory:         ${MemoryGB}GB
  CPUs:           $CPUCount
  OS Disk:        ${OSDiskSizeGB}GB
  Network:        $switchToUse (EXTERNAL - connected to physical network!)
  Data Disks:     $($DataDiskNumbers.Count) attached
  Cache Disks:    $($CacheDiskNumbers.Count) attached

Target Network Configuration for TrueNAS:
  IP Address:     $StaticIP
  Subnet Mask:    $SubnetMask
  Gateway:        $Gateway

Next Steps:
  1. Start the VM and install TrueNAS SCALE
  2. During install, select the 32GB OS disk
  3. Set root password
  4. After reboot, TrueNAS will get IP via DHCP from your router
  5. Or set static IP $StaticIP in TrueNAS Web UI

==============================================================================
"@ -ForegroundColor Green

$startNow = Read-Host "Start VM now? (yes/no)"
if ($startNow -eq "yes") {
    Start-VM -Name $VMName
    Write-Host "VM started!" -ForegroundColor Green

    Start-Sleep -Seconds 3

    $openConsole = Read-Host "Open VM console? (yes/no)"
    if ($openConsole -eq "yes") {
        vmconnect.exe localhost $VMName
    }
}

Write-Host "`nDone! Your new Baby NAS VM is ready." -ForegroundColor Cyan
