param(
    [switch]$Execute = $false,
    [switch]$Preview = $false
)

Write-Host ""
Write-Host "=== AI/ML Old Model & Temp File Cleanup ===" -ForegroundColor Cyan
Write-Host ""

# Define cleanup rules
$cleanupRules = @(
    @{
        Path = "D:\Optimum"
        Description = "Old SDXL Models"
        Models = @(
            "fluxedUpFluxNSFW.safetensors",
            "iniverseMix.safetensors",
            "iniverseMixSFWNSFW*.safetensors"
        )
        Patterns = @(
            "*.crdownload",
            "*.part*"
        )
    },
    @{
        Path = "D:\Projects"
        Description = "Old Stable Diffusion Models"
        Models = @()
        Patterns = @(
            "*.crdownload",
            "*.part*"
        )
    }
)

Write-Host "Cleanup Analysis:" -ForegroundColor Yellow
Write-Host ""

$totalSpaceToFree = 0
$filesToDelete = @()
$itemCount = 0

foreach ($rule in $cleanupRules) {
    if (!(Test-Path $rule.Path)) {
        Write-Host "SKIPPED: $($rule.Path) - Not found" -ForegroundColor Red
        continue
    }

    Write-Host "$($rule.Description)" -ForegroundColor Yellow
    Write-Host "  Location: $($rule.Path)" -ForegroundColor Gray

    # Check for old models
    if ($rule.Models.Count -gt 0) {
        Write-Host "  Old Models to Delete:" -ForegroundColor Gray

        foreach ($modelPattern in $rule.Models) {
            $foundModels = Get-ChildItem -Path $rule.Path -Recurse -Filter $modelPattern -ErrorAction SilentlyContinue

            foreach ($modelFile in $foundModels) {
                if ($modelFile.PSIsContainer) {
                    continue
                }

                $sizeGB = [Math]::Round($modelFile.Length / 1GB, 2)
                Write-Host "    WILL DELETE: $($modelFile.Name) size=$sizeGB GB" -ForegroundColor Red
                $totalSpaceToFree += $modelFile.Length
                $itemCount++

                $filesToDelete += @{
                    Path = $modelFile.FullName
                    Size = $modelFile.Length
                    Type = "Model"
                }
            }
        }
    }

    # Check for temp/partial files
    Write-Host "  Temp/Partial Files to Delete:" -ForegroundColor Gray

    foreach ($pattern in $rule.Patterns) {
        $tempFiles = Get-ChildItem -Path $rule.Path -Recurse -Filter $pattern -ErrorAction SilentlyContinue

        if ($tempFiles) {
            $tempSize = 0
            foreach ($tempFile in $tempFiles) {
                if (-not $tempFile.PSIsContainer) {
                    $tempSize += $tempFile.Length
                }
            }

            $tempGB = [Math]::Round($tempSize / 1GB, 2)
            Write-Host "    WILL DELETE: $($tempFiles.Count) $pattern files size=$tempGB GB" -ForegroundColor Red
            $totalSpaceToFree += $tempSize
            $itemCount += $tempFiles.Count

            foreach ($tempFile in $tempFiles) {
                $filesToDelete += @{
                    Path = $tempFile.FullName
                    Size = $tempFile.Length
                    Type = "Temp"
                }
            }
        }
    }

    Write-Host ""
}

$totalGB = [Math]::Round($totalSpaceToFree / 1GB, 2)
Write-Host "Total to Delete: $itemCount items, $totalGB GB" -ForegroundColor Cyan
Write-Host ""

if ($Preview) {
    Write-Host "=== Preview Mode ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Sample of files to be deleted:" -ForegroundColor Gray

    $sampleCount = 0
    foreach ($file in $filesToDelete) {
        if ($sampleCount -ge 20) {
            break
        }
        $fileGB = [Math]::Round($file.Size / 1GB, 3)
        Write-Host "  $($file.Path)" -ForegroundColor Gray
        $sampleCount++
    }

    if ($filesToDelete.Count -gt 20) {
        Write-Host "  ... and $($filesToDelete.Count - 20) more items" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "To execute cleanup:" -ForegroundColor Cyan
    Write-Host "  .\cleanup-old-models.ps1 -Execute" -ForegroundColor White
    Write-Host ""
    exit 0
}

if ($Execute) {
    Write-Host "=== EXECUTING CLEANUP ===" -ForegroundColor Red
    Write-Host ""

    $deleted = 0
    $failed = 0
    $deletedSize = 0

    foreach ($file in $filesToDelete) {
        try {
            if (Test-Path $file.Path) {
                $fileName = [System.IO.Path]::GetFileName($file.Path)
                Write-Host "  Deleting: $fileName" -ForegroundColor Yellow
                Remove-Item -Path $file.Path -Force -ErrorAction Stop

                $deleted++
                $deletedSize += $file.Size
            }
        } catch {
            Write-Host "    FAILED: $_" -ForegroundColor Red
            $failed++
        }
    }

    Write-Host ""
    Write-Host "=== Cleanup Summary ===" -ForegroundColor Cyan
    Write-Host "  Items deleted: $deleted" -ForegroundColor Green
    Write-Host "  Failed deletions: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })

    $deletedGB = [Math]::Round($deletedSize / 1GB, 2)
    Write-Host "  Space freed: $deletedGB GB" -ForegroundColor Green
    Write-Host ""

    # Show remaining space on D: drive
    try {
        $driveInfo = Get-PSDrive D
        if ($driveInfo) {
            $freeGB = [Math]::Round($driveInfo.Free / 1GB, 2)
            Write-Host "D: Drive free space: $freeGB GB" -ForegroundColor Green
        }
    } catch {
        Write-Host "Could not retrieve D: drive info" -ForegroundColor Gray
    }

    Write-Host ""

} else {
    Write-Host "DRY RUN MODE - No files will be deleted" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To preview cleanup:" -ForegroundColor Cyan
    Write-Host "  .\cleanup-old-models.ps1 -Preview" -ForegroundColor White
    Write-Host ""
    Write-Host "To execute cleanup:" -ForegroundColor Cyan
    Write-Host "  .\cleanup-old-models.ps1 -Execute" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
