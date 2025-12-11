# Setup TrueNAS VM in Hyper-V with Disk Passthrough
# Run as Administrator

param(
    [string]$VMName = "TrueNAS-Storage",
    [string]$ISOPath = "D:\ISOs\TrueNAS-SCALE-latest.iso",  # Update this path
    [int]$VMMemoryGB = 16,
    [int]$VMProcessors = 4
)

Write-Host "=== TrueNAS Hyper-V Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Must run as Administrator" -ForegroundColor Red
    exit 1
}

# Step 1: Identify disks
Write-Host "Step 1: Identifying disks..." -ForegroundColor Yellow
Write-Host ""

$hdds = Get-PhysicalDisk | Where-Object {
    $_.Size -gt 5TB -and $_.Size -lt 7TB -and $_.BusType -eq 'SATA'
} | Sort-Object DeviceId

$ssds = Get-PhysicalDisk | Where-Object {
    $_.MediaType -eq 'SSD' -and $_.Size -gt 200GB -and $_.Size -lt 300GB
} | Sort-Object DeviceId

Write-Host "Found HDDs for RAIDZ1:" -ForegroundColor Green
$hdds | Format-Table DeviceId, FriendlyName, Size, OperationalStatus -AutoSize

Write-Host "Found SSDs for SLOG/L2ARC:" -ForegroundColor Green
$ssds | Format-Table DeviceId, FriendlyName, Size, OperationalStatus -AutoSize

if ($hdds.Count -lt 3) {
    Write-Host "ERROR: Need 3 HDDs, found $($hdds.Count)" -ForegroundColor Red
    exit 1
}

if ($ssds.Count -lt 2) {
    Write-Host "WARNING: Need 2 SSDs for SLOG+L2ARC, found $($ssds.Count)" -ForegroundColor Yellow
    Write-Host "Will proceed with available SSDs" -ForegroundColor Yellow
}

# Step 2: Map disk numbers BEFORE taking disks offline
Write-Host ""
Write-Host "Step 2: Mapping disk numbers..." -ForegroundColor Yellow

$hddDiskNumbers = @()
foreach ($disk in $hdds) {
    # Use DeviceId from PhysicalDisk which matches Disk Number
    $diskNum = $disk.DeviceId
    if ($null -ne $diskNum) {
        $hddDiskNumbers += $diskNum
        Write-Host "  HDD: $($disk.FriendlyName) = Disk $diskNum" -ForegroundColor White
    } else {
        Write-Host "  WARNING: Could not get disk number for $($disk.FriendlyName)" -ForegroundColor Yellow
    }
}

$ssdDiskNumbers = @()
foreach ($disk in $ssds) {
    # Use DeviceId from PhysicalDisk which matches Disk Number
    $diskNum = $disk.DeviceId
    if ($null -ne $diskNum) {
        $ssdDiskNumbers += $diskNum
        Write-Host "  SSD: $($disk.FriendlyName) = Disk $diskNum" -ForegroundColor White
    } else {
        Write-Host "  WARNING: Could not get disk number for $($disk.FriendlyName)" -ForegroundColor Yellow
    }
}

# Step 3: Take disks offline for passthrough
Write-Host ""
Write-Host "Step 3: Taking disks offline for passthrough..." -ForegroundColor Yellow

foreach ($diskNum in $hddDiskNumbers) {
    Write-Host "  Taking HDD Disk $diskNum offline" -ForegroundColor White
    Set-Disk -Number $diskNum -IsOffline $true
}

foreach ($diskNum in $ssdDiskNumbers) {
    Write-Host "  Taking SSD Disk $diskNum offline" -ForegroundColor White
    Set-Disk -Number $diskNum -IsOffline $true
}

Write-Host "Disks taken offline!" -ForegroundColor Green

# Step 4: Create VM
Write-Host ""
Write-Host "Step 4: Creating Hyper-V VM..." -ForegroundColor Yellow

# Check if VM already exists
$existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if ($existingVM) {
    Write-Host "ERROR: VM '$VMName' already exists" -ForegroundColor Red
    $overwrite = Read-Host "Remove existing VM? (yes/no)"
    if ($overwrite -eq "yes") {
        Stop-VM -Name $VMName -Force -ErrorAction SilentlyContinue
        Remove-VM -Name $VMName -Force
        Write-Host "Removed existing VM" -ForegroundColor Yellow
    } else {
        exit 1
    }
}

# Create VM
$vmPath = "C:\Hyper-V\$VMName"

# Remove old VM path if exists
if (Test-Path $vmPath) {
    Write-Host "  Removing old VM files..." -ForegroundColor Yellow
    Remove-Item -Path $vmPath -Recurse -Force
}

New-VM -Name $VMName `
    -MemoryStartupBytes ($VMMemoryGB * 1GB) `
    -Generation 2 `
    -NewVHDPath "$vmPath\$VMName-OS.vhdx" `
    -NewVHDSizeBytes 32GB `
    -SwitchName (Get-VMSwitch | Select-Object -First 1).Name

# Configure VM
Set-VM -Name $VMName -ProcessorCount $VMProcessors -AutomaticStartAction Nothing
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false

# Disable Secure Boot (TrueNAS doesn't support it)
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

Write-Host "VM created!" -ForegroundColor Green

# Step 5: Attach ISO
Write-Host ""
Write-Host "Step 5: Attaching TrueNAS ISO..." -ForegroundColor Yellow

if (Test-Path $ISOPath) {
    Add-VMDvdDrive -VMName $VMName -Path $ISOPath
    Write-Host "ISO attached: $ISOPath" -ForegroundColor Green
} else {
    Write-Host "WARNING: ISO not found at $ISOPath" -ForegroundColor Yellow
    Write-Host "You'll need to attach the TrueNAS ISO manually before starting the VM" -ForegroundColor Yellow
    Write-Host "Download from: https://www.truenas.com/download-truenas-scale/" -ForegroundColor Cyan
}

# Step 6: Attach physical disks
Write-Host ""
Write-Host "Step 6: Attaching physical disks to VM..." -ForegroundColor Yellow

foreach ($diskNum in $hddDiskNumbers) {
    Write-Host "  Attaching HDD Disk $diskNum" -ForegroundColor White
    Add-VMHardDiskDrive -VMName $VMName -DiskNumber $diskNum -ControllerType SCSI
}

foreach ($diskNum in $ssdDiskNumbers) {
    Write-Host "  Attaching SSD Disk $diskNum" -ForegroundColor White
    Add-VMHardDiskDrive -VMName $VMName -DiskNumber $diskNum -ControllerType SCSI
}

Write-Host "Physical disks attached!" -ForegroundColor Green

# Step 7: Summary and next steps
Write-Host ""
Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "VM Configuration:" -ForegroundColor Cyan
Write-Host "  Name: $VMName" -ForegroundColor White
Write-Host "  Memory: $VMMemoryGB GB" -ForegroundColor White
Write-Host "  CPUs: $VMProcessors" -ForegroundColor White
Write-Host "  OS Disk: 32GB VHDX" -ForegroundColor White
Write-Host ""
Write-Host "Attached Physical Disks:" -ForegroundColor Cyan
Write-Host "  HDDs: $($hdds.Count)x 6TB (for RAIDZ1 pool)" -ForegroundColor White
Write-Host "  SSDs: $($ssds.Count)x 256GB (for SLOG/L2ARC)" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Start the VM: Start-VM -Name '$VMName'" -ForegroundColor White
Write-Host "  2. Connect to console: vmconnect.exe localhost '$VMName'" -ForegroundColor White
Write-Host "  3. Install TrueNAS SCALE" -ForegroundColor White
Write-Host "  4. After install, create ZFS pool:" -ForegroundColor White
Write-Host "     - Pool: RAIDZ1 with 3x 6TB HDDs" -ForegroundColor White
Write-Host "     - SLOG: 1x 256GB SSD (optional)" -ForegroundColor White
Write-Host "     - L2ARC: 1x 256GB SSD (optional)" -ForegroundColor White
Write-Host "  5. Set up SMB shares to access from Windows" -ForegroundColor White
Write-Host ""
Write-Host "To start VM now, run:" -ForegroundColor Cyan
Write-Host "  Start-VM -Name '$VMName'" -ForegroundColor White
Write-Host "  vmconnect.exe localhost '$VMName'" -ForegroundColor White
Write-Host ""

# Save configuration
$configFile = "D:\workspace\True_Nas\TRUENAS_VM_CONFIG.txt"
@"
TrueNAS Hyper-V VM Configuration
Created: $(Get-Date)
VM Name: $VMName
Memory: $VMMemoryGB GB
CPUs: $VMProcessors

Disks Attached:
HDDs (RAIDZ1):
$($hdds | ForEach-Object { "  - $($_.FriendlyName) - $([math]::Round($_.Size/1TB, 2)) TB" } | Out-String)
SSDs (SLOG/L2ARC):
$($ssds | ForEach-Object { "  - $($_.FriendlyName) - $([math]::Round($_.Size/1GB, 2)) GB" } | Out-String)

ZFS Configuration Recommendations:
- Create RAIDZ1 pool with 3x 6TB HDDs (~12TB usable)
- Add 1x 256GB SSD as SLOG (ZIL) for sync write acceleration
- Add 1x 256GB SSD as L2ARC for read caching
- Enable compression (lz4 or zstd)
- Consider setting recordsize based on workload

Network Setup:
- Configure static IP in TrueNAS
- Enable SMB service for Windows file sharing
- Map network drive in Windows to access storage

"@ | Out-File -FilePath $configFile -Encoding UTF8

Write-Host "Configuration saved to: $configFile" -ForegroundColor Green
