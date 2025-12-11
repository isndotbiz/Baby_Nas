# Script 2: Initialize Single Drive for Backup
# Purpose: Initialize one 6TB drive as NTFS backup target
# Run as: Administrator
# Usage: .\2-initialize-single-drive.ps1 -DiskNumber 2

param(
    [Parameter(Mandatory=$true)]
    [int]$DiskNumber,

    [Parameter(Mandatory=$false)]
    [string]$VolumeLabel = "BackupDrive",

    [Parameter(Mandatory=$false)]
    [switch]$Confirm
)

Write-Host "`n=== Initialize Backup Drive ===" -ForegroundColor Cyan

# Verify disk exists
$disk = Get-Disk -Number $DiskNumber -ErrorAction SilentlyContinue

if (-not $disk) {
    Write-Host "ERROR: Disk $DiskNumber not found!" -ForegroundColor Red
    Write-Host "Run .\1-identify-drives.ps1 to see available disks"
    exit 1
}

# Display disk info
Write-Host "`nTarget Disk Information:" -ForegroundColor Yellow
$disk | Select-Object Number, FriendlyName,
    @{N='Size(TB)';E={[math]::Round($_.Size/1TB,2)}},
    PartitionStyle,
    @{N='Health';E={$_.HealthStatus}} | Format-Table -AutoSize

# Confirmation
if (-not $Confirm) {
    Write-Host "`nWARNING: This will erase all data on Disk $DiskNumber!" -ForegroundColor Red
    Write-Host "Disk: $($disk.FriendlyName) ($([math]::Round($disk.Size/1TB,2)) TB)" -ForegroundColor Yellow

    $response = Read-Host "`nAre you sure you want to continue? (Type 'YES' to confirm)"

    if ($response -ne 'YES') {
        Write-Host "`nOperation cancelled by user." -ForegroundColor Yellow
        exit 0
    }
}

try {
    # Clear disk (remove all partitions)
    Write-Host "`nStep 1: Clearing disk..." -ForegroundColor Cyan
    Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false
    Write-Host "  Disk cleared successfully" -ForegroundColor Green

    Start-Sleep -Seconds 2

    # Initialize as GPT
    Write-Host "`nStep 2: Initializing as GPT..." -ForegroundColor Cyan
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -PassThru | Out-Null
    Write-Host "  Disk initialized as GPT" -ForegroundColor Green

    Start-Sleep -Seconds 2

    # Create partition
    Write-Host "`nStep 3: Creating partition..." -ForegroundColor Cyan
    $partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter
    $driveLetter = $partition.DriveLetter
    Write-Host "  Partition created with drive letter: $driveLetter`:" -ForegroundColor Green

    Start-Sleep -Seconds 2

    # Format as NTFS
    Write-Host "`nStep 4: Formatting as NTFS (this may take several minutes)..." -ForegroundColor Cyan
    Format-Volume -DriveLetter $driveLetter `
        -FileSystem NTFS `
        -NewFileSystemLabel $VolumeLabel `
        -AllocationUnitSize 65536 `
        -Confirm:$false | Out-Null
    Write-Host "  Volume formatted successfully" -ForegroundColor Green

    # Create backup directories
    Write-Host "`nStep 5: Creating backup directories..." -ForegroundColor Cyan
    $backupRoot = "$driveLetter`:"
    $directories = @(
        "$backupRoot\VeeamBackups",
        "$backupRoot\WSLBackups",
        "$backupRoot\ManualBackups"
    )

    foreach ($dir in $directories) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Host "  Created: $dir" -ForegroundColor Green
    }

    # Success summary
    Write-Host "`n=== Initialization Complete ===" -ForegroundColor Green
    Write-Host "Drive Letter: $driveLetter`:" -ForegroundColor Cyan
    Write-Host "Volume Label: $VolumeLabel" -ForegroundColor Cyan
    Write-Host "File System: NTFS (64KB allocation)" -ForegroundColor Cyan
    Write-Host "Total Size: $([math]::Round((Get-Volume -DriveLetter $driveLetter).Size/1TB,2)) TB" -ForegroundColor Cyan
    Write-Host "Available: $([math]::Round((Get-Volume -DriveLetter $driveLetter).SizeRemaining/1TB,2)) TB" -ForegroundColor Cyan

    # Next steps
    Write-Host "`n=== Next Steps ===" -ForegroundColor Yellow
    Write-Host "1. Download and install Veeam Agent for Windows FREE"
    Write-Host "   URL: https://www.veeam.com/windows-endpoint-server-backup-free.html"
    Write-Host "`n2. Configure Veeam backup job:"
    Write-Host "   - Backup destination: $driveLetter`:\VeeamBackups"
    Write-Host "   - Select drives to backup: C:, D:, E:, F:"
    Write-Host "   - Schedule: Daily at 2:00 AM"
    Write-Host "   - Retention: 14 days"
    Write-Host "`n3. Run first backup manually to verify"
    Write-Host "`n4. Optional: Add mirror drive later with:"
    Write-Host "   .\3-add-mirror-drive.ps1 -SourceDisk $DiskNumber -MirrorDisk X"

} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Initialization failed. Please check disk status and try again." -ForegroundColor Red
    exit 1
}

Write-Host "`n"
