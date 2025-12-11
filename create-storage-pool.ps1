# Create Windows Storage Spaces Pool with 3x 6TB HDDs + 2x 256GB SSD Cache
# Run as Administrator

Write-Host "=== Windows Storage Spaces Pool Creation ===" -ForegroundColor Cyan
Write-Host ""

# Identify drives
Write-Host "Scanning for available drives..." -ForegroundColor Yellow
$allDisks = Get-PhysicalDisk | Where-Object { $_.CanPool -eq $true }

# Find 3x 6TB HDDs (Disks 2, 3, 4)
$hdds = Get-PhysicalDisk | Where-Object {
    $_.Size -gt 5TB -and
    $_.Size -lt 7TB -and
    $_.CanPool -eq $true
}

# Find 2x 256GB SSDs (Disks 0, 1)
$ssds = Get-PhysicalDisk | Where-Object {
    $_.MediaType -eq 'SSD' -and
    $_.Size -gt 200GB -and
    $_.Size -lt 300GB -and
    $_.CanPool -eq $true
}

Write-Host "Found $($hdds.Count) 6TB HDDs:" -ForegroundColor Green
$hdds | Format-Table DeviceId, FriendlyName, Size, OperationalStatus -AutoSize

Write-Host "Found $($ssds.Count) 256GB SSDs:" -ForegroundColor Green
$ssds | Format-Table DeviceId, FriendlyName, Size, OperationalStatus -AutoSize

# Validation
if ($hdds.Count -lt 3) {
    Write-Host "ERROR: Need 3x 6TB drives, only found $($hdds.Count)" -ForegroundColor Red
    Write-Host "Available poolable disks:" -ForegroundColor Yellow
    $allDisks | Format-Table DeviceId, FriendlyName, Size, MediaType, CanPool -AutoSize
    exit 1
}

if ($ssds.Count -lt 2) {
    Write-Host "WARNING: Need 2x 256GB SSDs for cache, only found $($ssds.Count)" -ForegroundColor Yellow
    Write-Host "Will create pool without SSD cache tier" -ForegroundColor Yellow
    $useSSDCache = $false
} else {
    $useSSDCache = $true
}

# Confirm
Write-Host ""
Write-Host "Ready to create Storage Pool with:" -ForegroundColor Cyan
Write-Host "  Pool Name: BackupStoragePool" -ForegroundColor White
Write-Host "  HDDs: 3x 6TB (DeviceIds: $($hdds.DeviceId -join ', '))" -ForegroundColor White
if ($useSSDCache) {
    Write-Host "  SSDs: 2x 256GB (DeviceIds: $($ssds.DeviceId -join ', '))" -ForegroundColor White
}
Write-Host "  Resilience: Parity (1-disk fault tolerance)" -ForegroundColor White
Write-Host "  Usable: ~12TB" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Continue? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Cancelled by user" -ForegroundColor Yellow
    exit 0
}

try {
    # Step 1: Create Storage Pool
    Write-Host ""
    Write-Host "Step 1/5: Creating Storage Pool..." -ForegroundColor Cyan

    if ($useSSDCache) {
        # Create pool with both HDDs and SSDs
        $allPhysicalDisks = $hdds + $ssds
        $pool = New-StoragePool -FriendlyName "BackupStoragePool" `
            -StorageSubSystemFriendlyName "Windows Storage*" `
            -PhysicalDisks $allPhysicalDisks `
            -ResiliencySettingNameDefault "Parity" `
            -ProvisioningTypeDefault "Thin"
    } else {
        # Create pool with HDDs only
        $pool = New-StoragePool -FriendlyName "BackupStoragePool" `
            -StorageSubSystemFriendlyName "Windows Storage*" `
            -PhysicalDisks $hdds `
            -ResiliencySettingNameDefault "Parity" `
            -ProvisioningTypeDefault "Thin"
    }

    Write-Host "Storage Pool created successfully!" -ForegroundColor Green

    # Step 2: Set SSD media type for tiering (if using SSDs)
    if ($useSSDCache) {
        Write-Host ""
        Write-Host "Step 2/5: Configuring SSD tier..." -ForegroundColor Cyan

        # Set SSDs as SSD tier
        Set-PhysicalDisk -UniqueId $ssds[0].UniqueId -MediaType SSD -Usage AutoSelect
        Set-PhysicalDisk -UniqueId $ssds[1].UniqueId -MediaType SSD -Usage AutoSelect

        Write-Host "SSD tier configured!" -ForegroundColor Green
    } else {
        Write-Host "Step 2/5: Skipping SSD tier (no SSDs available)" -ForegroundColor Yellow
    }

    # Step 3: Create storage tiers
    if ($useSSDCache) {
        Write-Host ""
        Write-Host "Step 3/5: Creating storage tiers..." -ForegroundColor Cyan

        $ssdTier = New-StorageTier -StoragePoolFriendlyName "BackupStoragePool" `
            -FriendlyName "SSD_Tier" `
            -MediaType SSD

        $hddTier = New-StorageTier -StoragePoolFriendlyName "BackupStoragePool" `
            -FriendlyName "HDD_Tier" `
            -MediaType HDD

        Write-Host "Storage tiers created!" -ForegroundColor Green
    } else {
        Write-Host "Step 3/5: Skipping tiering (no SSDs)" -ForegroundColor Yellow
    }

    # Step 4: Create Virtual Disk
    Write-Host ""
    Write-Host "Step 4/5: Creating Virtual Disk..." -ForegroundColor Cyan

    if ($useSSDCache) {
        # Create tiered virtual disk: 256GB on SSD, rest on HDD
        $vdisk = New-VirtualDisk -StoragePoolFriendlyName "BackupStoragePool" `
            -FriendlyName "BackupVolume" `
            -StorageTiers $ssdTier, $hddTier `
            -StorageTierSizes 256GB, 11.5TB `
            -ResiliencySettingName "Parity" `
            -WriteCacheSize 1GB
    } else {
        # Create simple virtual disk with parity
        $vdisk = New-VirtualDisk -StoragePoolFriendlyName "BackupStoragePool" `
            -FriendlyName "BackupVolume" `
            -Size 11.5TB `
            -ResiliencySettingName "Parity" `
            -ProvisioningType Thin `
            -WriteCacheSize 1GB
    }

    Write-Host "Virtual Disk created!" -ForegroundColor Green

    # Step 5: Initialize, partition, and format
    Write-Host ""
    Write-Host "Step 5/5: Initializing and formatting..." -ForegroundColor Cyan

    # Get the disk
    $disk = Get-VirtualDisk -FriendlyName "BackupVolume" | Get-Disk

    # Initialize disk
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT -Confirm:$false

    # Create partition (use all available space)
    $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter

    # Format with ReFS (recommended for Storage Spaces)
    Format-Volume -DriveLetter $partition.DriveLetter `
        -FileSystem ReFS `
        -NewFileSystemLabel "BackupStorage" `
        -AllocationUnitSize 64KB `
        -Confirm:$false

    Write-Host "Volume formatted successfully!" -ForegroundColor Green

    # Create directory structure
    Write-Host ""
    Write-Host "Creating backup directories..." -ForegroundColor Cyan
    $driveLetter = $partition.DriveLetter
    New-Item -Path "${driveLetter}:\VeeamBackups" -ItemType Directory -Force | Out-Null
    New-Item -Path "${driveLetter}:\WSLBackups" -ItemType Directory -Force | Out-Null
    New-Item -Path "${driveLetter}:\ManualBackups" -ItemType Directory -Force | Out-Null
    New-Item -Path "${driveLetter}:\MediaArchive" -ItemType Directory -Force | Out-Null
    New-Item -Path "${driveLetter}:\ProjectBackups" -ItemType Directory -Force | Out-Null

    Write-Host "Directories created!" -ForegroundColor Green

    # Display results
    Write-Host ""
    Write-Host "=== STORAGE POOL CREATED SUCCESSFULLY ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pool Information:" -ForegroundColor Cyan
    Get-StoragePool -FriendlyName "BackupStoragePool" | Format-List FriendlyName, OperationalStatus, HealthStatus, Size, AllocatedSize

    Write-Host "Virtual Disk Information:" -ForegroundColor Cyan
    Get-VirtualDisk -FriendlyName "BackupVolume" | Format-List FriendlyName, OperationalStatus, HealthStatus, Size, ResiliencySettingName

    Write-Host "Volume Information:" -ForegroundColor Cyan
    Get-Volume -DriveLetter $driveLetter | Format-List DriveLetter, FileSystem, HealthStatus, SizeRemaining, Size

    Write-Host ""
    Write-Host "Drive Letter: $($driveLetter):" -ForegroundColor Yellow
    Write-Host "Total Size: $([math]::Round((Get-Volume -DriveLetter $driveLetter).Size / 1TB, 2)) TB" -ForegroundColor Yellow
    Write-Host "Available: $([math]::Round((Get-Volume -DriveLetter $driveLetter).SizeRemaining / 1TB, 2)) TB" -ForegroundColor Yellow

    if ($useSSDCache) {
        Write-Host ""
        Write-Host "SSD Cache Tier: 256GB (hot data cached on SSDs)" -ForegroundColor Yellow
        Write-Host "HDD Storage Tier: ~11.5TB (bulk storage on HDDs)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Backup directories created at:" -ForegroundColor Cyan
    Write-Host "  ${driveLetter}:\VeeamBackups" -ForegroundColor White
    Write-Host "  ${driveLetter}:\WSLBackups" -ForegroundColor White
    Write-Host "  ${driveLetter}:\ManualBackups" -ForegroundColor White
    Write-Host "  ${driveLetter}:\MediaArchive" -ForegroundColor White
    Write-Host "  ${driveLetter}:\ProjectBackups" -ForegroundColor White

    # Save configuration
    $configFile = "D:\workspace\True_Nas\STORAGE_POOL_CONFIG.txt"
    @"
Storage Pool Configuration
Created: $(Get-Date)
Pool Name: BackupStoragePool
Drive Letter: $($driveLetter):
Total Capacity: $([math]::Round((Get-Volume -DriveLetter $driveLetter).Size / 1TB, 2)) TB
File System: ReFS
Resilience: Parity (1-disk fault tolerance)
HDDs: $($hdds.Count) x 6TB
SSDs: $($ssds.Count) x 256GB (cache tier)
SSD Tier Size: 256GB
HDD Tier Size: 11.5TB
"@ | Out-File -FilePath $configFile -Encoding UTF8

    Write-Host ""
    Write-Host "Configuration saved to: $configFile" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "ERROR: $_" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
Write-Host "Your storage pool is ready to use!" -ForegroundColor Green
