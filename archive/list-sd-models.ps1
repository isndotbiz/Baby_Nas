Write-Host ""
Write-Host "=== Scanning Stable Diffusion Models ===" -ForegroundColor Cyan
Write-Host ""

$sdPath = "D:\Projects"

if (Test-Path $sdPath) {
    Write-Host "Location: D:\Projects" -ForegroundColor Yellow
    Write-Host ""

    # Get all .safetensors files
    $models = Get-ChildItem -Path $sdPath -Recurse -Filter "*.safetensors" -ErrorAction SilentlyContinue

    if ($models) {
        Write-Host "Total models found: $($models.Count)" -ForegroundColor Green
        Write-Host ""

        # Group by directory
        $byFolder = $models | Group-Object { (Get-Item $_.Directory).Name }

        foreach ($group in $byFolder) {
            Write-Host "Folder: $($group.Name)" -ForegroundColor Yellow
            Write-Host ""

            $totalSize = 0
            foreach ($model in $group.Group) {
                $sizeGB = [Math]::Round($model.Length / 1GB, 2)
                $sizeMB = [Math]::Round($model.Length / 1MB, 1)
                $display = if ($sizeGB -ge 1) { "$sizeGB GB" } else { "$sizeMB MB" }

                Write-Host "  $($model.Name)" -ForegroundColor White
                Write-Host "    Size: $display" -ForegroundColor Gray

                $totalSize += $model.Length
            }

            $totalGB = [Math]::Round($totalSize / 1GB, 2)
            Write-Host "  Subtotal: $totalGB GB" -ForegroundColor Cyan
            Write-Host ""
        }

        # Grand total
        $grandTotal = ($models | Measure-Object -Property Length -Sum).Sum
        $grandGB = [Math]::Round($grandTotal / 1GB, 2)

        Write-Host "=== GRAND TOTAL ===" -ForegroundColor Green
        Write-Host "Total size of all SD models: $grandGB GB" -ForegroundColor Green
        Write-Host ""

    } else {
        Write-Host "No .safetensors files found" -ForegroundColor Red
    }
} else {
    Write-Host "D:\Projects not found" -ForegroundColor Red
}

Write-Host ""
