Write-Host ""
Write-Host "=== DELETING ALL STABLE DIFFUSION MODELS ===" -ForegroundColor Red
Write-Host ""

$sdPath = "D:\Projects"

if (Test-Path $sdPath) {
    Write-Host "Source: $sdPath" -ForegroundColor Yellow

    # Get total size before deletion
    $totalSize = (Get-ChildItem -Path $sdPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $totalGB = [Math]::Round($totalSize / 1GB, 2)

    Write-Host "Total size to delete: $totalGB GB" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Deleting directory and all contents..." -ForegroundColor Yellow

    try {
        Remove-Item -Path $sdPath -Recurse -Force -ErrorAction Stop
        Write-Host ""
        Write-Host "SUCCESS!" -ForegroundColor Green
        Write-Host "Deleted: $sdPath" -ForegroundColor Green
        Write-Host "Space freed: $totalGB GB" -ForegroundColor Green
        Write-Host ""

        # Show new D: drive space
        $drive = Get-PSDrive D
        $freeGB = [Math]::Round($drive.Free / 1GB, 2)
        Write-Host "D: Drive free space: $freeGB GB" -ForegroundColor Green

    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Not found: $sdPath" -ForegroundColor Red
}

Write-Host ""
