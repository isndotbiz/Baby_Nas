<#
.SYNOPSIS
    Creates a minimal Baby NAS VM for storage only.

.DESCRIPTION
    Creates a Hyper-V VM running TrueNAS SCALE optimized for:
    - Workspace sync
    - Model archive storage
    - Download staging
    - Minimal resource usage (2 vCPU, 8GB RAM)

.NOTES
    Storage Layout (Option B):
    - Boot: 32GB VHDX (virtual disk)
    - Pool: 3x 6TB HDD (RAIDZ1) + 2x 256GB SSD (mirrored special vdev)

    The mirrored special vdev stores metadata + small files on SSD
    for fast directory operations. Mirror protects against single SSD failure.

    Network: 10.0.0.x subnet (same as Main NAS)
    Hostname: baby.isn.biz
#>

#Requires -RunAsAdministrator

param(
    [string]$VMName = "BabyNAS",
    [string]$VMPath = "D:\VM\BabyNAS",
    [string]$ISOPath = "D:\ISOs\TrueNAS-SCALE-25.04.2.6.iso",
    [int]$MemoryGB = 8,
    [int]$CPUCount = 2,
    [int]$BootDiskGB = 32,
    [string]$SwitchName = "Virtual Switch"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Baby NAS VM Creation (Storage Only)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# STEP 1: Validate Prerequisites
# ============================================================================

Write-Host "STEP 1: Checking prerequisites..." -ForegroundColor Yellow

# Check Hyper-V
if (-not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State -eq 'Enabled') {
    Write-Error "Hyper-V is not enabled. Please enable it first."
    exit 1
}

# Check ISO exists
if (-not (Test-Path $ISOPath)) {
    Write-Host ""
    Write-Host "TrueNAS SCALE ISO not found at: $ISOPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Download from: https://www.truenas.com/download-truenas-scale/" -ForegroundColor Yellow
    Write-Host "Save as: $ISOPath" -ForegroundColor Yellow
    Write-Host ""

    $download = Read-Host "Open download page in browser? (Y/N)"
    if ($download -eq 'Y') {
        Start-Process "https://www.truenas.com/download-truenas-scale/"
    }
    exit 1
}

# Check switch exists
$switch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (-not $switch) {
    Write-Host "Available switches:" -ForegroundColor Yellow
    Get-VMSwitch | Select-Object Name, SwitchType | Format-Table
    Write-Error "Virtual switch '$SwitchName' not found."
    exit 1
}

# Check if VM already exists
if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
    Write-Error "VM '$VMName' already exists. Remove it first or choose a different name."
    exit 1
}

Write-Host "  ISO: $ISOPath" -ForegroundColor Green
Write-Host "  Switch: $SwitchName" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 2: Create VM Directory
# ============================================================================

Write-Host "STEP 2: Creating VM directory..." -ForegroundColor Yellow

if (-not (Test-Path $VMPath)) {
    New-Item -Path $VMPath -ItemType Directory -Force | Out-Null
}
Write-Host "  Path: $VMPath" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 3: Create Virtual Machine
# ============================================================================

Write-Host "STEP 3: Creating virtual machine..." -ForegroundColor Yellow

$vm = New-VM -Name $VMName `
    -Path $VMPath `
    -Generation 2 `
    -MemoryStartupBytes ($MemoryGB * 1GB) `
    -SwitchName $SwitchName `
    -NewVHDPath "$VMPath\boot.vhdx" `
    -NewVHDSizeBytes ($BootDiskGB * 1GB)

Write-Host "  VM Created: $VMName" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 4: Configure VM Settings
# ============================================================================

Write-Host "STEP 4: Configuring VM settings..." -ForegroundColor Yellow

# CPU
Set-VMProcessor -VMName $VMName -Count $CPUCount
Write-Host "  CPU: $CPUCount vCPUs" -ForegroundColor Green

# Memory (static for ZFS ARC predictability)
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false
Write-Host "  RAM: ${MemoryGB}GB (static)" -ForegroundColor Green

# Disable Secure Boot (required for TrueNAS)
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
Write-Host "  Secure Boot: Disabled" -ForegroundColor Green

# Attach ISO
Add-VMDvdDrive -VMName $VMName -Path $ISOPath
Write-Host "  ISO: Attached" -ForegroundColor Green

# Set boot order (DVD first for install)
$dvd = Get-VMDvdDrive -VMName $VMName
$hdd = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $dvd, $hdd
Write-Host "  Boot Order: DVD, HDD" -ForegroundColor Green

# Enable guest services
Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
Write-Host "  Guest Services: Enabled" -ForegroundColor Green

# Auto start
Set-VM -VMName $VMName -AutomaticStartAction Start -AutomaticStartDelay 30
Set-VM -VMName $VMName -AutomaticStopAction ShutDown
Write-Host "  Auto Start: Enabled (30s delay)" -ForegroundColor Green

Write-Host ""

# ============================================================================
# STEP 5: Display Physical Disk Info (for passthrough)
# ============================================================================

Write-Host "STEP 5: Available physical disks for passthrough..." -ForegroundColor Yellow
Write-Host ""

# Get physical disks
$disks = Get-Disk | Where-Object { $_.BusType -ne 'File Backed Virtual' } |
    Select-Object Number, FriendlyName, Size, PartitionStyle, OperationalStatus

if ($disks) {
    $disks | Format-Table -AutoSize

    Write-Host "To passthrough disks, take them offline in Disk Management first," -ForegroundColor Yellow
    Write-Host "then run:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # For each disk (replace X with disk number):" -ForegroundColor Cyan
    Write-Host '  $disk = Get-Disk -Number X' -ForegroundColor Cyan
    Write-Host '  Set-Disk -Number X -IsOffline $true' -ForegroundColor Cyan
    Write-Host '  Add-VMHardDiskDrive -VMName "BabyNAS" -DiskNumber X' -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "  No additional physical disks found." -ForegroundColor Yellow
    Write-Host "  Add your 3x 6TB HDDs and 2x 256GB SSDs, then passthrough." -ForegroundColor Yellow
}

Write-Host ""

# ============================================================================
# STEP 6: Summary
# ============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  VM Created Successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor White
Write-Host "  Name:      $VMName"
Write-Host "  Path:      $VMPath"
Write-Host "  vCPUs:     $CPUCount"
Write-Host "  RAM:       ${MemoryGB}GB"
Write-Host "  Boot Disk: ${BootDiskGB}GB VHDX"
Write-Host "  Network:   $SwitchName (10.0.0.x)"
Write-Host ""
Write-Host "Storage Layout (Option B):" -ForegroundColor Yellow
Write-Host "  Boot:    32GB VHDX (this VM)"
Write-Host "  Pool:    3x 6TB HDD (RAIDZ1 - data)"
Write-Host "  Special: 2x 256GB SSD (mirror - metadata)"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Passthrough your 3x 6TB HDDs + 2x 256GB SSDs"
Write-Host "  2. Start VM: Start-VM -Name $VMName"
Write-Host "  3. Connect: vmconnect localhost $VMName"
Write-Host "  4. Install TrueNAS SCALE (to the 32GB VHDX)"
Write-Host "  5. Configure static IP (e.g., 10.0.0.88)"
Write-Host "  6. Create ZFS pool with special vdev (see below)"
Write-Host "  7. Create datasets and SMB shares"
Write-Host ""
Write-Host "ZFS Pool Creation (in TrueNAS CLI or Web UI):" -ForegroundColor Yellow
Write-Host "  # CLI method:" -ForegroundColor Cyan
Write-Host "  zpool create tank raidz1 /dev/sda /dev/sdb /dev/sdc \\" -ForegroundColor Cyan
Write-Host "    special mirror /dev/sdd /dev/sde" -ForegroundColor Cyan
Write-Host ""
Write-Host "  # Or via Web UI:" -ForegroundColor Cyan
Write-Host "  Storage > Create Pool > Add RAIDZ1 (3x HDD)" -ForegroundColor Cyan
Write-Host "  Then: Add Vdev > Metadata > Mirror (2x SSD)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Planned Network Drives:" -ForegroundColor Yellow
Write-Host "  W: \\baby.isn.biz\workspace   - Workspace sync"
Write-Host "  M: \\baby.isn.biz\models      - AI model archive"
Write-Host "  S: \\baby.isn.biz\staging     - Downloads/temp"
Write-Host "  B: \\baby.isn.biz\backups     - General backups"
Write-Host ""

# Offer to start VM
$start = Read-Host "Start VM now? (Y/N)"
if ($start -eq 'Y') {
    Start-VM -Name $VMName
    Write-Host "VM starting..." -ForegroundColor Green
    Start-Sleep -Seconds 3
    vmconnect localhost $VMName
}
