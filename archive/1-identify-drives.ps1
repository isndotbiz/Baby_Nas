# Script 1: Identify Available Drives
# Purpose: Identify 6TB drives available for backup pool
# Run as: Administrator

Write-Host "`n=== Physical Disk Inventory ===" -ForegroundColor Cyan
Write-Host "Scanning for available 6TB drives...`n"

# Get all physical disks
$disks = Get-PhysicalDisk | Select-Object DeviceID, FriendlyName,
    @{N='Size(TB)';E={[math]::Round($_.Size/1TB,2)}},
    MediaType,
    @{N='Health';E={$_.HealthStatus}},
    @{N='Usage';E={$_.Usage}}

# Display all disks
Write-Host "All Physical Disks:" -ForegroundColor Yellow
$disks | Format-Table -AutoSize

# Identify potential 6TB drives
$sixTBDisks = $disks | Where-Object { $_.'Size(TB)' -ge 5.5 -and $_.'Size(TB)' -le 6.5 }

if ($sixTBDisks) {
    Write-Host "`n=== Potential 6TB Drives Found ===" -ForegroundColor Green
    $sixTBDisks | Format-Table -AutoSize

    Write-Host "`nFound $($sixTBDisks.Count) drive(s) approximately 6TB in size" -ForegroundColor Green
} else {
    Write-Host "`nNo 6TB drives found!" -ForegroundColor Red
    Write-Host "Please ensure the 6TB drives are properly connected."
}

# Check for uninitialized disks
Write-Host "`n=== Uninitialized Disks ===" -ForegroundColor Cyan
$uninitDisks = Get-Disk | Where-Object {$_.PartitionStyle -eq 'RAW'} |
    Select-Object Number, FriendlyName,
    @{N='Size(TB)';E={[math]::Round($_.Size/1TB,2)}},
    PartitionStyle

if ($uninitDisks) {
    Write-Host "These disks are uninitialized and ready for use:" -ForegroundColor Yellow
    $uninitDisks | Format-Table -AutoSize
} else {
    Write-Host "No uninitialized disks found." -ForegroundColor Gray
}

# Check current disk partitions
Write-Host "`n=== Current Partition Layout ===" -ForegroundColor Cyan
Get-Partition | Select-Object DiskNumber, PartitionNumber, DriveLetter,
    @{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}},
    Type | Format-Table -AutoSize

# Export inventory to CSV
$exportPath = "D:\disk-inventory-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$disks | Export-Csv -Path $exportPath -NoTypeInformation
Write-Host "`nInventory exported to: $exportPath" -ForegroundColor Green

# Summary and recommendations
Write-Host "`n=== Recommendations ===" -ForegroundColor Cyan

if ($sixTBDisks.Count -ge 3) {
    Write-Host "You have $($sixTBDisks.Count) 6TB drives available." -ForegroundColor Green
    Write-Host "`nOption A (RECOMMENDED): Start with 1 drive for immediate protection"
    Write-Host "  - Fast setup (30 minutes)"
    Write-Host "  - Get backups running TODAY"
    Write-Host "  - Add mirror later for redundancy"
    Write-Host "`nOption B: Setup RAIDZ2 with all 3 drives"
    Write-Host "  - 10TB usable capacity"
    Write-Host "  - 1-drive fault tolerance"
    Write-Host "  - Takes 3-4 hours to setup"

} elseif ($sixTBDisks.Count -eq 2) {
    Write-Host "You have 2 6TB drives available." -ForegroundColor Yellow
    Write-Host "Recommendation: Setup mirrored pair (6TB usable, 1-drive fault tolerance)"

} elseif ($sixTBDisks.Count -eq 1) {
    Write-Host "You have 1 6TB drive available." -ForegroundColor Yellow
    Write-Host "Recommendation: Use single drive now, add mirror later"

} else {
    Write-Host "No suitable 6TB drives found!" -ForegroundColor Red
    Write-Host "Please check drive connections and run this script again."
}

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Note the disk numbers of your 6TB drives"
Write-Host "2. Choose backup method: Veeam (recommended) or OpenZFS"
Write-Host "3. Run initialization script: .\2-initialize-single-drive.ps1 -DiskNumber X"
Write-Host "   (Replace X with your chosen disk number)"

Write-Host "`n"
