param(
    [switch]$Execute = $false,
    [switch]$Preview = $false
)

Write-Host ""
Write-Host "=== Archive Remaining Folders to Baby NAS ===" -ForegroundColor Cyan
Write-Host ""

# Folders to archive
$foldersToArchive = @(
    @{
        SourcePath = "D:\Optimum"
        ArchiveName = "optimum"
        Description = "SDXL Models and Dependencies"
    },
    @{
        SourcePath = "D:\~"
        ArchiveName = "home-backup"
        Description = "Home Directory Backup"
    }
)

Write-Host "Folders to Archive:" -ForegroundColor Yellow
Write-Host ""

$totalSize = 0
foreach ($folder in $foldersToArchive) {
    if (Test-Path $folder.SourcePath) {
        $size = (Get-ChildItem -Path $folder.SourcePath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $sizeGB = [Math]::Round($size / 1GB, 2)
        $totalSize += $size

        Write-Host "  $($folder.ArchiveName)" -ForegroundColor Green
        Write-Host "    Path: $($folder.SourcePath)" -ForegroundColor Gray
        Write-Host "    Description: $($folder.Description)" -ForegroundColor Gray
        Write-Host "    Size: $sizeGB GB" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "  NOT FOUND: $($folder.SourcePath)" -ForegroundColor Red
        Write-Host ""
    }
}

$totalGB = [Math]::Round($totalSize / 1GB, 2)
Write-Host "Total size to archive: $totalGB GB" -ForegroundColor Cyan
Write-Host ""

# Archive location
$archiveDate = Get-Date -Format "yyyy-MM"
$nasPath = "\\172.21.203.18\backups\archive\$archiveDate"
$logFile = "C:\Logs\archive-remaining-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

if ($Preview) {
    Write-Host "=== Preview Mode ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Archive Location: $nasPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Process:" -ForegroundColor Yellow
    Write-Host "  1. Check Baby NAS connectivity" -ForegroundColor White
    Write-Host "  2. Verify target archive directory exists or create" -ForegroundColor White
    Write-Host "  3. Copy each folder using robocopy" -ForegroundColor White
    Write-Host "  4. Verify file counts and sizes match" -ForegroundColor White
    Write-Host "  5. Create manifest.json with archive metadata" -ForegroundColor White
    Write-Host "  6. Log results" -ForegroundColor White
    Write-Host ""
    Write-Host "Estimated time: 1-3 hours (network dependent)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To execute:" -ForegroundColor Yellow
    Write-Host "  .\archive-remaining-folders.ps1 -Execute" -ForegroundColor White
    Write-Host ""
    exit 0
}

if ($Execute) {
    Write-Host "=== EXECUTING ARCHIVE ===" -ForegroundColor Red
    Write-Host ""

    # Test connectivity
    Write-Host "Testing Baby NAS connectivity..." -ForegroundColor Yellow
    $ping = Test-Connection -ComputerName "172.21.203.18" -Count 1 -Quiet

    if (-not $ping) {
        Write-Host "ERROR: Cannot reach Baby NAS at 172.21.203.18" -ForegroundColor Red
        Write-Host "Please verify:" -ForegroundColor Yellow
        Write-Host "  1. VM is running: Get-VM -Name TrueNAS-BabyNAS | Select State" -ForegroundColor White
        Write-Host "  2. Network connectivity: ping 172.21.203.18" -ForegroundColor White
        exit 1
    }

    Write-Host "  OK - Baby NAS is reachable" -ForegroundColor Green
    Write-Host ""

    # Create log file
    New-Item -Path "C:\Logs" -ItemType Directory -Force | Out-Null
    Add-Content -Path $logFile -Value "Archive started: $(Get-Date)"
    Add-Content -Path $logFile -Value "Archive location: $nasPath"
    Add-Content -Path $logFile -Value ""

    # Create archive directory
    Write-Host "Creating archive directory structure..." -ForegroundColor Yellow

    try {
        # Mount SMB share
        $nasShare = "\\172.21.203.18\backups"
        $credential = New-Object System.Management.Automation.PSCredential("admin", (ConvertTo-SecureString "uppercut%`$##" -AsPlainText -Force))

        # Try to mount
        try {
            New-PSDrive -Name NasArchive -PSProvider FileSystem -Root $nasShare -Credential $credential -ErrorAction Stop | Out-Null
            Write-Host "  Connected to SMB share" -ForegroundColor Green
        } catch {
            Write-Host "  Warning: Could not mount share, attempting direct path" -ForegroundColor Yellow
        }

        # Create archive base path if needed
        if (!(Test-Path $nasPath)) {
            New-Item -Path $nasPath -ItemType Directory -Force | Out-Null
            Write-Host "  Created: $nasPath" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
        Add-Content -Path $logFile -Value "ERROR: $_"
        exit 1
    }

    Write-Host ""

    # Archive each folder
    $archiveResults = @()

    foreach ($folder in $foldersToArchive) {
        if (!(Test-Path $folder.SourcePath)) {
            continue
        }

        Write-Host "=== Archiving: $($folder.ArchiveName) ===" -ForegroundColor Yellow
        Write-Host "Source: $($folder.SourcePath)" -ForegroundColor Gray

        $targetPath = Join-Path $nasPath $folder.ArchiveName
        $startTime = Get-Date

        try {
            # Create target directory
            New-Item -Path $targetPath -ItemType Directory -Force | Out-Null

            # Copy using robocopy
            Write-Host "Copying files..." -ForegroundColor Yellow
            & robocopy.exe $folder.SourcePath $targetPath /E /Z /V /TS /R:3 /W:10 /NP 2>&1 | Tee-Object -FilePath $logFile -Append | Out-Null

            # Verify
            Write-Host "Verifying archive..." -ForegroundColor Yellow

            $sourceFiles = (Get-ChildItem -Path $folder.SourcePath -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
            $targetFiles = (Get-ChildItem -Path $targetPath -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count

            $sourceSize = (Get-ChildItem -Path $folder.SourcePath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $targetSize = (Get-ChildItem -Path $targetPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum

            $sourceGB = [Math]::Round($sourceSize / 1GB, 2)
            $targetGB = [Math]::Round($targetSize / 1GB, 2)

            Write-Host "  Source: $sourceFiles files, $sourceGB GB" -ForegroundColor Gray
            Write-Host "  Target: $targetFiles files, $targetGB GB" -ForegroundColor Gray

            $endTime = Get-Date
            $duration = $endTime - $startTime

            if ($sourceGB -eq $targetGB) {
                Write-Host "  Status: VERIFIED ✓" -ForegroundColor Green

                $archiveResults += @{
                    Name = $folder.ArchiveName
                    SourcePath = $folder.SourcePath
                    TargetPath = $targetPath
                    SizeGB = $sourceGB
                    FileCount = $sourceFiles
                    Duration = $duration
                    Status = "Success"
                }
            } else {
                Write-Host "  Status: MISMATCH - Manual verification needed" -ForegroundColor Red

                $archiveResults += @{
                    Name = $folder.ArchiveName
                    SourcePath = $folder.SourcePath
                    TargetPath = $targetPath
                    SizeGB = $sourceGB
                    FileCount = $sourceFiles
                    Duration = $duration
                    Status = "Verification Failed"
                }
            }

            Write-Host ""

        } catch {
            Write-Host "  ERROR: $_" -ForegroundColor Red
            Add-Content -Path $logFile -Value "ERROR archiving $($folder.ArchiveName): $_"
        }
    }

    # Create manifest
    Write-Host "Creating manifest.json..." -ForegroundColor Yellow

    $manifest = @{
        archiveDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        location = $nasPath
        totalFolders = $archiveResults.Count
        folders = @()
    }

    foreach ($result in $archiveResults) {
        $manifest.folders += @{
            name = $result.Name
            sourcePath = $result.SourcePath
            targetPath = $result.TargetPath
            sizeGB = $result.SizeGB
            fileCount = $result.FileCount
            duration = "$($result.Duration.Hours)h $($result.Duration.Minutes)m"
            status = $result.Status
        }
    }

    $manifestPath = Join-Path $nasPath "manifest.json"
    $manifest | ConvertTo-Json | Set-Content -Path $manifestPath

    Write-Host "  Created: $manifestPath" -ForegroundColor Green
    Write-Host ""

    # Summary
    Write-Host "=== Archive Summary ===" -ForegroundColor Green
    Write-Host ""

    $totalArchived = 0
    foreach ($result in $archiveResults) {
        Write-Host "$($result.Name): $($result.SizeGB) GB - $($result.Status)" -ForegroundColor $(if ($result.Status -eq "Success") { "Green" } else { "Yellow" })
        if ($result.Status -eq "Success") {
            $totalArchived += $result.SizeGB
        }
    }

    Write-Host ""
    Write-Host "Total archived: $totalArchived GB" -ForegroundColor Green
    Write-Host "Archive location: $nasPath" -ForegroundColor Cyan
    Write-Host "Log file: $logFile" -ForegroundColor Gray
    Write-Host ""

    Write-Host "=== Next Steps ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Verify archives on Baby NAS:" -ForegroundColor White
    Write-Host "   Get-ChildItem $nasPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Once verified, delete source folders:" -ForegroundColor White
    Write-Host "   Remove-Item 'D:\Optimum' -Recurse -Force" -ForegroundColor Cyan
    Write-Host "   Remove-Item 'D:\~' -Recurse -Force" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "3. Expected space freed:" -ForegroundColor White
    Write-Host "   189.52 GB (Optimum + Home backup)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "4. Setup snapshots:" -ForegroundColor White
    Write-Host "   .\setup-snapshots.ps1" -ForegroundColor Cyan
    Write-Host ""

} else {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To preview archive:" -ForegroundColor Cyan
    Write-Host "  .\archive-remaining-folders.ps1 -Preview" -ForegroundColor White
    Write-Host ""
    Write-Host "To execute archive:" -ForegroundColor Cyan
    Write-Host "  .\archive-remaining-folders.ps1 -Execute" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
