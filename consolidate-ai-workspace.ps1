param(
    [switch]$Execute = $false,
    [switch]$Preview = $false
)

Write-Host ""
Write-Host "=== AI/ML Workspace Consolidation ===" -ForegroundColor Cyan
Write-Host ""

# Define source and target locations
$sources = @(
    @{
        Path = "C:\Users\jdmal\ComfyUI"
        Name = "ComfyUI (from User Home)"
        Type = "ComfyUI"
    },
    @{
        Path = "D:\Optimum"
        Name = "Optimum (SDXL Models)"
        Type = "SDXL"
    },
    @{
        Path = "D:\Projects"
        Name = "Projects (Stable Diffusion)"
        Type = "StableDiffusion"
    },
    @{
        Path = "D:\ai-workspace"
        Name = "AI Workspace (if exists)"
        Type = "ComfyUI"
    }
)

$targetBase = "D:\workspace"
$consolidatedPath = "$targetBase\ComfyUI"
$modelsPath = "$consolidatedPath\models"
$checkpointsPath = "$modelsPath\checkpoints"
$lorasPath = "$modelsPath\loras"
$controlnetPath = "$modelsPath\controlnet"
$upscalersPath = "$modelsPath\upscalers"
$embedPath = "$modelsPath\embeddings"

Write-Host "Source Locations:" -ForegroundColor Yellow
foreach ($source in $sources) {
    if (Test-Path $source.Path) {
        $size = (Get-ChildItem -Path $source.Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $sizeGB = [Math]::Round($size / 1GB, 2)
        Write-Host "  OK $($source.Name)" -ForegroundColor Green
        Write-Host "    Path: $($source.Path)" -ForegroundColor Gray
        Write-Host "    Size: $sizeGB GB" -ForegroundColor Gray
    } else {
        Write-Host "  NOT FOUND $($source.Name)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Target Location:" -ForegroundColor Yellow
Write-Host "  $consolidatedPath" -ForegroundColor White
Write-Host ""

if ($Preview) {
    Write-Host "=== Preview Mode ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Key decisions to make:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. FLUX MODELS TO KEEP:" -ForegroundColor Yellow
    Write-Host "   flux1-dev-kontext_fp8_scaled.safetensors 11.09 GB" -ForegroundColor White
    Write-Host "   flux1-dev-fp8.safetensors 11.08 GB" -ForegroundColor White
    Write-Host "   flux1-schnell-fp8.safetensors if present" -ForegroundColor White
    Write-Host ""

    Write-Host "2. OLD SDXL MODELS TO DELETE:" -ForegroundColor Yellow
    Write-Host "   fluxedUpFluxNSFW.safetensors 22.17 GB" -ForegroundColor White
    Write-Host "   iniverseMix.safetensors 11.08 GB" -ForegroundColor White
    Write-Host "   Other old SDXL .safetensors files" -ForegroundColor White
    Write-Host ""

    Write-Host "3. TEMP/INCOMPLETE FILES TO DELETE:" -ForegroundColor Yellow
    Write-Host "   .crdownload files (partial downloads)" -ForegroundColor White
    Write-Host "   .part0-9 files (temp extraction)" -ForegroundColor White
    Write-Host "   __pycache__ directories (compiled Python)" -ForegroundColor White
    Write-Host ""

    Write-Host "4. OPTIONAL CLEANUP:" -ForegroundColor Yellow
    Write-Host "   Old ISOs - can re-download if needed" -ForegroundColor White
    Write-Host "   Phone videos if not needed" -ForegroundColor White
    Write-Host "   Android emulator snapshots" -ForegroundColor White
    Write-Host ""

    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review large files in C:\Logs\large-files-*.csv" -ForegroundColor White
    Write-Host "  2. Run with -Execute flag to perform consolidation" -ForegroundColor White
    Write-Host ""
    exit 0
}

Write-Host "=== Consolidation Plan ===" -ForegroundColor Cyan
Write-Host ""

# Create target structure if needed
$dirs = @($consolidatedPath, $modelsPath, $checkpointsPath, $lorasPath, $controlnetPath, $upscalersPath, $embedPath)

if ($Execute) {
    Write-Host "Creating target directory structure..." -ForegroundColor Yellow
    foreach ($dir in $dirs) {
        if (!(Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            Write-Host "  Created: $dir" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "=== Phase 1: Copy Flux Models ===" -ForegroundColor Yellow

    # Find and copy Flux models from ComfyUI
    $fluxSourcePath = "C:\Users\jdmal\ComfyUI\models\checkpoints"
    if (Test-Path $fluxSourcePath) {
        $fluxModels = Get-ChildItem -Path $fluxSourcePath -Filter "flux*" -ErrorAction SilentlyContinue

        foreach ($model in $fluxModels) {
            $modelSizeGB = [Math]::Round($model.Length / 1GB, 2)
            Write-Host "  Copying: $($model.Name) ($modelSizeGB GB)" -ForegroundColor Green
            Copy-Item -Path $model.FullName -Destination $checkpointsPath -Force
        }
    } else {
        Write-Host "  Source path not found: $fluxSourcePath" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "=== Phase 2: Copy ComfyUI Dependencies ===" -ForegroundColor Yellow

    # Copy essential ComfyUI files
    $comfyPath = "C:\Users\jdmal\ComfyUI"
    if (Test-Path $comfyPath) {
        Write-Host "  Analyzing ComfyUI structure..." -ForegroundColor Yellow

        $itemsToCopy = @(
            "custom_nodes",
            "web",
            "input",
            "output"
        )

        foreach ($item in $itemsToCopy) {
            $sourcePath = Join-Path $comfyPath $item
            $destPath = Join-Path $consolidatedPath $item

            if (Test-Path $sourcePath) {
                Write-Host "  Copying: $item" -ForegroundColor Green
                & robocopy.exe $sourcePath $destPath /E /Z /R:3 /W:10 /NP | Out-Null
            }
        }
    }

    Write-Host ""
    Write-Host "=== Phase 3: Scan Other Model Directories ===" -ForegroundColor Yellow

    # Scan D:\Optimum (SDXL models)
    $optimumModels = "D:\Optimum"
    if (Test-Path $optimumModels) {
        Write-Host "  Scanning D:\Optimum for .safetensors files..." -ForegroundColor Yellow

        $modelFiles = Get-ChildItem -Path $optimumModels -Recurse -Filter "*.safetensors" -ErrorAction SilentlyContinue

        $fluxCount = 0
        $oldModelCount = 0

        foreach ($modelFile in $modelFiles) {
            if ($modelFile.Name -like "*flux*") {
                $fluxCount++
            } else {
                $oldModelCount++
                $sizeGB = [Math]::Round($modelFile.Length / 1GB, 2)
                Write-Host "    Found old model: $($modelFile.Name) ($sizeGB GB)" -ForegroundColor Gray
            }
        }

        Write-Host "    Summary: $fluxCount Flux models, $oldModelCount old models found" -ForegroundColor White
    }

    # Scan D:\Projects (Stable Diffusion)
    $projectsModels = "D:\Projects"
    if (Test-Path $projectsModels) {
        Write-Host "  Scanning D:\Projects for .safetensors files..." -ForegroundColor Yellow

        $modelFiles = Get-ChildItem -Path $projectsModels -Recurse -Filter "*.safetensors" -ErrorAction SilentlyContinue

        if ($modelFiles) {
            $modelCount = $modelFiles.Count
            Write-Host "    Found $modelCount Stable Diffusion models (to be deleted)" -ForegroundColor Gray
        } else {
            Write-Host "    No .safetensors files found" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "=== Phase 4: Summary ===" -ForegroundColor Cyan

    if (Test-Path $consolidatedPath) {
        $consolidatedSize = (Get-ChildItem -Path $consolidatedPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $consolidatedGB = [Math]::Round($consolidatedSize / 1GB, 2)

        Write-Host "  Consolidated workspace size: $consolidatedGB GB" -ForegroundColor Green
        Write-Host "  Location: $consolidatedPath" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "=== Next Steps ===" -ForegroundColor Yellow
    Write-Host "  1. Verify consolidated workspace has all needed Flux models" -ForegroundColor White
    Write-Host "  2. Test ComfyUI with the consolidated models" -ForegroundColor White
    Write-Host "  3. Run cleanup script to delete old models:" -ForegroundColor White
    Write-Host "     .\cleanup-old-models.ps1 -Execute" -ForegroundColor Cyan
    Write-Host ""

} else {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To execute consolidation:" -ForegroundColor Cyan
    Write-Host "  .\consolidate-ai-workspace.ps1 -Execute" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
