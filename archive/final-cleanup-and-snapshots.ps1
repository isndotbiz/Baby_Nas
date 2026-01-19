param(
    [switch]$DeleteFolders = $false,
    [switch]$SetupSnapshots = $false,
    [switch]$Both = $false
)

Write-Host ""
Write-Host "=== Final Cleanup & Snapshot Setup ===" -ForegroundColor Cyan
Write-Host ""

# Phase 1: Delete remaining folders
if ($DeleteFolders -or $Both) {
    Write-Host "=== PHASE 1: DELETE REMAINING FOLDERS ===" -ForegroundColor Red
    Write-Host ""

    $foldersToDelete = @("D:\Optimum", "D:\~")

    foreach ($folder in $foldersToDelete) {
        if (Test-Path $folder) {
            $size = (Get-ChildItem -Path $folder -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $sizeGB = [Math]::Round($size / 1GB, 2)

            Write-Host "Deleting: $folder" -ForegroundColor Yellow
            Write-Host "  Size: $sizeGB GB" -ForegroundColor Gray

            try {
                Remove-Item -Path $folder -Recurse -Force -ErrorAction Stop
                Write-Host "  Status: DELETED" -ForegroundColor Green
            } catch {
                Write-Host "  Status: FAILED - $_" -ForegroundColor Red
            }
        } else {
            Write-Host "Not found: $folder" -ForegroundColor Gray
        }

        Write-Host ""
    }

    # Show new drive space
    $drive = Get-PSDrive D
    $freeGB = [Math]::Round($drive.Free / 1GB, 2)
    Write-Host "D: Drive free space: $freeGB GB" -ForegroundColor Green
    Write-Host ""
}

# Phase 2: Setup snapshots
if ($SetupSnapshots -or $Both) {
    Write-Host "=== PHASE 2: SETUP AUTOMATED SNAPSHOTS ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Testing Baby NAS connectivity..." -ForegroundColor Yellow
    $ping = Test-Connection -ComputerName "172.21.203.18" -Count 1 -Quiet

    if ($ping) {
        Write-Host "  OK - Baby NAS is online" -ForegroundColor Green
        Write-Host ""

        Write-Host "Snapshot Configuration Plan:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Hourly Snapshots:" -ForegroundColor White
        Write-Host "    - Schedule: Every hour" -ForegroundColor Gray
        Write-Host "    - Retention: Keep 24 (1 day)" -ForegroundColor Gray
        Write-Host "    - Purpose: Quick recovery from recent changes" -ForegroundColor Gray
        Write-Host ""

        Write-Host "  Daily Snapshots:" -ForegroundColor White
        Write-Host "    - Schedule: 3:00 AM daily" -ForegroundColor Gray
        Write-Host "    - Retention: Keep 7 (1 week)" -ForegroundColor Gray
        Write-Host "    - Purpose: Recover from day-old issues" -ForegroundColor Gray
        Write-Host ""

        Write-Host "  Weekly Snapshots:" -ForegroundColor White
        Write-Host "    - Schedule: Sunday 4:00 AM" -ForegroundColor Gray
        Write-Host "    - Retention: Keep 4 (1 month)" -ForegroundColor Gray
        Write-Host "    - Purpose: Long-term recovery points" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Setting up snapshots via SSH..." -ForegroundColor Yellow
        Write-Host ""

        # SSH commands to setup snapshots
        $sshCommands = @(
            "# Create snapshot tasks",
            "zfs set com.sun:auto-snapshot=true tank",
            "zfs set com.sun:auto-snapshot:hourly=true tank",
            "zfs set com.sun:auto-snapshot:daily=true tank",
            "zfs set com.sun:auto-snapshot:weekly=true tank",
            ""
            "echo 'Snapshots configured'"
        )

        Write-Host "Commands to execute on Baby NAS:" -ForegroundColor Yellow
        Write-Host ""

        foreach ($cmd in $sshCommands) {
            if ($cmd -eq "") {
                Write-Host ""
            } else {
                Write-Host "  $cmd" -ForegroundColor Cyan
            }
        }

        Write-Host ""
        Write-Host "To manually setup snapshots:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. SSH into Baby NAS:" -ForegroundColor White
        Write-Host "     ssh admin@172.21.203.18" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  2. Enable auto-snapshots:" -ForegroundColor White
        Write-Host "     zfs set com.sun:auto-snapshot=true tank" -ForegroundColor Cyan
        Write-Host "     zfs set com.sun:auto-snapshot:hourly=true tank" -ForegroundColor Cyan
        Write-Host "     zfs set com.sun:auto-snapshot:daily=true tank" -ForegroundColor Cyan
        Write-Host "     zfs set com.sun:auto-snapshot:weekly=true tank" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  3. Verify via TrueNAS Web UI:" -ForegroundColor White
        Write-Host "     https://172.21.203.18" -ForegroundColor Cyan
        Write-Host "     → Storage → Snapshots" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "Snapshot Setup Status: READY FOR CONFIGURATION" -ForegroundColor Green
        Write-Host ""

    } else {
        Write-Host "  ERROR - Cannot reach Baby NAS at 172.21.203.18" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please start the VM first:" -ForegroundColor Yellow
        Write-Host "  Get-VM -Name TrueNAS-BabyNAS | Select State" -ForegroundColor Cyan
        Write-Host "  Start-VM -Name TrueNAS-BabyNAS" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Show usage if no flags
if (-not $DeleteFolders -and -not $SetupSnapshots -and -not $Both) {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Delete folders:" -ForegroundColor White
    Write-Host "    .\final-cleanup-and-snapshots.ps1 -DeleteFolders" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Setup snapshots:" -ForegroundColor White
    Write-Host "    .\final-cleanup-and-snapshots.ps1 -SetupSnapshots" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Do both:" -ForegroundColor White
    Write-Host "    .\final-cleanup-and-snapshots.ps1 -Both" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host ""
