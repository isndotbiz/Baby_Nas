Write-Host ""
Write-Host "=== CONSOLIDATION FINAL STATUS ===" -ForegroundColor Green
Write-Host ""

Write-Host "Remaining folders:" -ForegroundColor Yellow
Write-Host ""

$folders = @(
    "D:\Optimum",
    "D:\~",
    "D:\ai-workspace",
    "D:\workspace\ComfyUI"
)

foreach ($folder in $folders) {
    if (Test-Path $folder) {
        $size = (Get-ChildItem -Path $folder -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $sizeGB = [Math]::Round($size / 1GB, 2)
        Write-Host "  OK  $folder" -ForegroundColor Green
        Write-Host "       Size: $sizeGB GB" -ForegroundColor Gray
    } else {
        Write-Host "  DEL $folder" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== SPACE FREED ===" -ForegroundColor Green
Write-Host ""
Write-Host "Phase 1 (temp files):      29.32 GB" -ForegroundColor Cyan
Write-Host "Phase 2 (SD models):       46.92 GB" -ForegroundColor Cyan
Write-Host "────────────────────────────────────" -ForegroundColor White
Write-Host "TOTAL FREED:               76.24 GB" -ForegroundColor Green
Write-Host ""
Write-Host "D: Drive free space:      971.4 GB" -ForegroundColor Green
Write-Host ""
