# Find large files for AI/ML consolidation

Write-Host ""
Write-Host "=== Finding Large Files (>100MB) ===" -ForegroundColor Cyan
Write-Host ""

$folders = @(
    'D:\Optimum',
    'D:\~',
    'D:\Projects',
    'C:\Users\jdmal'
)

$allLargeFiles = @()

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Write-Host "Scanning: $folder" -ForegroundColor Yellow

        try {
            $files = Get-ChildItem -Path $folder -Recurse -ErrorAction SilentlyContinue |
                Where-Object { -not $_.PSIsContainer -and $_.Length -gt 100MB }

            if ($files) {
                foreach ($file in $files) {
                    $sizeGB = [Math]::Round($file.Length / 1GB, 2)
                    $sizeMB = [Math]::Round($file.Length / 1MB, 1)

                    $display = if ($sizeGB -ge 1) { "$sizeGB GB" } else { "$sizeMB MB" }

                    $allLargeFiles += [PSCustomObject]@{
                        FullPath = $file.FullName
                        Name = $file.Name
                        SizeBytes = $file.Length
                        SizeGB = $sizeGB
                        SizeMB = $sizeMB
                        DisplaySize = $display
                        Type = $file.Extension
                        SourceFolder = $folder
                    }
                }
            }
        } catch {
            Write-Host "  Error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  NOT FOUND: $folder" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Large Files Found ===" -ForegroundColor Green
Write-Host ""

if ($allLargeFiles.Count -gt 0) {
    $sorted = $allLargeFiles | Sort-Object -Property SizeBytes -Descending
    $byType = $sorted | Group-Object -Property Type

    Write-Host "Total large files: $($sorted.Count)" -ForegroundColor Yellow
    Write-Host ""

    foreach ($typeGroup in $byType) {
        $totalSize = ($typeGroup.Group | Measure-Object -Property SizeBytes -Sum).Sum
        $totalGB = [Math]::Round($totalSize / 1GB, 2)
        Write-Host "$($typeGroup.Name) files ($($typeGroup.Count) files, $totalGB GB):" -ForegroundColor Cyan

        foreach ($file in $typeGroup.Group | Select-Object -First 20) {
            $relPath = $file.FullPath -replace [regex]::Escape($file.SourceFolder), ''
            Write-Host "  $($file.DisplaySize) - $relPath" -ForegroundColor White
        }
        Write-Host ""
    }

    Write-Host "=== All Large Files (Sorted by Size) ===" -ForegroundColor Green
    Write-Host ""

    $count = 0
    foreach ($file in $sorted) {
        $count++
        $relPath = $file.FullPath -replace [regex]::Escape($file.SourceFolder), ''
        Write-Host "$count. $($file.DisplaySize) | $($file.Type) | $relPath" -ForegroundColor Gray
    }

    $csvPath = "C:\Logs\large-files-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').csv"
    $sorted | Export-Csv -Path $csvPath -NoTypeInformation

    Write-Host ""
    Write-Host "CSV exported to: $csvPath" -ForegroundColor Green
    Write-Host ""

} else {
    Write-Host "No files > 100MB found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "AI/ML Folders Found:" -ForegroundColor Yellow
Write-Host "  D:\Optimum (SDXL models)" -ForegroundColor White
Write-Host "  D:\Projects (Stable Diffusion)" -ForegroundColor White
Write-Host "  C:\Users\jdmal (ComfyUI automation)" -ForegroundColor White
Write-Host ""
