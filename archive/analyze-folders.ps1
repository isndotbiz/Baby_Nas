# Analyze folders to decide what to archive/delete

Write-Host ""
Write-Host "=== Folder Analysis for Archive Decision ===" -ForegroundColor Cyan
Write-Host ""

$folders = @(
    @{ Path = "D:\Optimum"; Name = "Optimum" },
    @{ Path = "D:\~"; Name = "Home Backup" },
    @{ Path = "D:\Projects"; Name = "Projects" },
    @{ Path = "D:\ai-workspace"; Name = "AI Workspace" }
)

foreach ($folder in $folders) {
    if (Test-Path $folder.Path) {
        Write-Host "📁 $($folder.Name)" -ForegroundColor Yellow
        Write-Host "   Path: $($folder.Path)" -ForegroundColor Gray

        try {
            $size = (Get-ChildItem -Path $folder.Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $sizeGB = [Math]::Round($size / 1GB, 2)
            Write-Host "   Size: $sizeGB GB" -ForegroundColor White
        } catch {
            Write-Host "   Size: (error reading)" -ForegroundColor Red
        }

        Write-Host "   Top-level contents:" -ForegroundColor Gray
        try {
            Get-ChildItem -Path $folder.Path -Force -ErrorAction SilentlyContinue | Select-Object -First 15 | ForEach-Object {
                $type = if ($_.PSIsContainer) { "📁" } else { "📄" }
                $size = if ($_.PSIsContainer) { "" } else { " ($([Math]::Round($_.Length / 1MB, 1))MB)" }
                Write-Host "      $type $($_.Name)$size" -ForegroundColor Gray
            }
        } catch {
            Write-Host "      (error listing)" -ForegroundColor Red
        }

        Write-Host ""
    } else {
        Write-Host "✗ NOT FOUND: $($folder.Path)" -ForegroundColor Red
        Write-Host ""
    }
}

Write-Host "=== Analysis Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Questions to ask for each folder:" -ForegroundColor Yellow
Write-Host "  1. Do I actively use this?" -ForegroundColor White
Write-Host "  2. Is there critical data that needs backup?" -ForegroundColor White
Write-Host "  3. Can it be safely deleted?" -ForegroundColor White
Write-Host "  4. Do I ever need to restore from it?" -ForegroundColor White
Write-Host ""
Write-Host "If answers are mostly NO → DELETE IT" -ForegroundColor Green
Write-Host "If answers are mostly YES → ARCHIVE IT" -ForegroundColor Green
Write-Host ""
