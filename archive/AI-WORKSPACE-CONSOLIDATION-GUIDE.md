# AI/ML Workspace Consolidation Guide

## Overview

This guide consolidates your scattered AI/ML folders into a single, organized workspace location while preserving your Flux models and deleting old/duplicate SDXL and Stable Diffusion models.

### Current State

**Source Folders:**
- `C:\Users\jdmal\ComfyUI` - ComfyUI automation (your primary workspace)
- `D:\Optimum` - SDXL models (~182GB)
- `D:\Projects` - Stable Diffusion models (~48GB)
- `D:\ai-workspace` - Additional ComfyUI (if exists, ~39GB)

**Total:** ~307GB across 4 locations

### Goal

**Target:** `D:\workspace\ComfyUI` (single consolidated location)
- Keep Flux models (your current preference)
- Delete old SDXL models (fluxedUpFluxNSFW, iniverseMix, etc.)
- Delete old Stable Diffusion models
- Delete temporary/partial files
- **Expected Result:** ~100-150GB consolidated workspace + ~150+ GB freed space

---

## Quick Start (3 Steps)

### Step 1: Preview (See What Will Happen)
```powershell
cd D:\workspace\Baby_Nas
.\consolidate-ai-workspace.ps1 -Preview
```

Shows:
- Flux models to keep
- Old models to delete
- Temp files to clean
- Target consolidation structure

### Step 2: Execute Consolidation
```powershell
.\consolidate-ai-workspace.ps1 -Execute
```

This will:
1. Create consolidated directory structure in `D:\workspace\ComfyUI`
2. Copy Flux models from ComfyUI
3. Copy ComfyUI dependencies (custom_nodes, web, etc.)
4. Scan and list other models found in SDXL/SD folders

**Time:** 10-30 minutes (network I/O)

### Step 3: Cleanup Old Files
```powershell
.\cleanup-old-models.ps1 -Execute
```

This will:
1. Delete old SDXL models (fluxedUpFluxNSFW, etc.)
2. Delete old Stable Diffusion models
3. Delete temporary/partial files (.crdownload, .part0-9)
4. Delete compiled Python cache (__pycache__)

**Result:** Frees ~150+ GB on D: drive

---

## Detailed Process

### Phase 1: Analysis (Already Complete)
✓ Ran `find-large-files.ps1`
✓ Identified 263 files across all locations
✓ Categorized by size and type
✓ Located all AI/ML models

**Key Findings:**
- **249 GB of .safetensors files** (78 files total)
  - 22.17 GB: fluxedUpFluxNSFW (old SDXL - DELETE)
  - 11.09 GB: flux1-dev-kontext_fp8_scaled (Flux - KEEP)
  - 11.08 GB: flux1-dev-fp8 (Flux - KEEP)
  - Other old SDXL/SD models - DELETE

- **66.67 GB of .mp4 files** (44 phone videos)
  - Keep or delete based on need

- **18.85 GB of .iso files** (Veeam, TrueNAS)
  - Safe to delete (can re-download)

- **5.6 GB of .crdownload files** (incomplete downloads)
  - DELETE

- **5.6 GB of .part0-9 files** (extraction temp files)
  - DELETE

### Phase 2: Consolidation

**What Gets Copied:**

```
D:\workspace\ComfyUI\                          ← New consolidated location
├── models\
│   ├── checkpoints\                            ← Flux models here
│   │   ├── flux1-dev-kontext_fp8_scaled.safetensors
│   │   ├── flux1-dev-fp8.safetensors
│   │   └── flux1-schnell-fp8.safetensors (if exists)
│   ├── loras\                                  ← LoRA files
│   ├── controlnet\                             ← ControlNet models
│   ├── upscalers\                              ← Upscaler models
│   └── embeddings\                             ← Text embeddings
├── custom_nodes\                               ← ComfyUI extensions
├── web\                                        ← ComfyUI web UI
├── input\                                      ← Input directory
└── output\                                     ← Output directory
```

**What Gets Deleted:**

From `D:\Optimum`:
- `fluxedUpFluxNSFW.safetensors` (22.17 GB)
- `iniverseMix.safetensors` (11.08 GB)
- Other old SDXL models
- `.crdownload` files
- `.part*` files

From `D:\Projects`:
- All old Stable Diffusion models
- `.crdownload` and `.part*` files

From `C:\Users\jdmal`:
- Temporary/incomplete files

### Phase 3: Verification

After consolidation, verify:

```powershell
# Check consolidated workspace size
(Get-ChildItem D:\workspace\ComfyUI -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB

# Should show ~100-150 GB depending on which models you keep

# Verify Flux models are present
Get-ChildItem D:\workspace\ComfyUI\models\checkpoints -Filter "flux*"

# Should list flux1-dev-*.safetensors files
```

### Phase 4: Testing

Test your consolidated ComfyUI setup:

1. **Update ComfyUI to use new location**
   - Update any shortcut/batch files to point to `D:\workspace\ComfyUI`

2. **Test Flux model loading**
   - Start ComfyUI
   - Load a Flux node
   - Verify it finds the models

3. **Test other dependencies**
   - Verify custom nodes load
   - Check LoRA loading
   - Test upscaler functionality

4. **Clean up source folders once verified**
   - Once ComfyUI works with consolidated setup:
     ```powershell
     Remove-Item D:\Optimum -Recurse -Force
     Remove-Item D:\Projects -Recurse -Force
     Remove-Item "D:\ai-workspace" -Recurse -Force
     ```

---

## Space Savings

### Before Consolidation
```
D:\Optimum        182 GB
D:\Projects        48 GB
D:\~               38 GB
C:\Users\jdmal\ComfyUI  (~50 GB estimated)
─────────────────────────
Total:            318 GB
```

### After Consolidation
```
D:\workspace\ComfyUI  100-150 GB (consolidated, Flux only)
─────────────────────────
Freed:            168-218 GB on D: drive
```

**Note:** Additional space freed by deleting ISOs, videos, temp files, etc.

---

## Decision Matrix

### Which Models to Keep

| Model | Size | Status | Action |
|-------|------|--------|--------|
| flux1-dev-kontext_fp8_scaled.safetensors | 11.09 GB | Current | **KEEP** |
| flux1-dev-fp8.safetensors | 11.08 GB | Current | **KEEP** |
| flux1-schnell-fp8.safetensors | ~3.5 GB | Current (if present) | **KEEP** |
| fluxedUpFluxNSFW.safetensors | 22.17 GB | Old SDXL | **DELETE** |
| iniverseMix.safetensors | 11.08 GB | Old SDXL | **DELETE** |
| Other SDXL models | Various | Deprecated | **DELETE** |
| Stable Diffusion models | Various | Deprecated | **DELETE** |

### Which Temp/Partial Files to Delete

| File Type | Pattern | Action | Space |
|-----------|---------|--------|-------|
| Incomplete downloads | *.crdownload | **DELETE** | ~2.8 GB |
| Extraction temps | *.part0-9 | **DELETE** | ~5.6 GB |
| Python cache | __pycache__/* | **DELETE** | ~200 MB |
| Old ISOs | *.iso | Optional | 18.85 GB |
| Phone videos | *.mp4 | Optional | 66.67 GB |

---

## Scripts Reference

### consolidate-ai-workspace.ps1

**Dry Run (Preview):**
```powershell
.\consolidate-ai-workspace.ps1 -Preview
```
Shows consolidation decisions without making changes.

**Execute:**
```powershell
.\consolidate-ai-workspace.ps1 -Execute
```
Performs consolidation:
- Creates D:\workspace\ComfyUI structure
- Copies Flux models
- Copies ComfyUI dependencies
- Lists old models found

### cleanup-old-models.ps1

**Preview:**
```powershell
.\cleanup-old-models.ps1 -Preview
```
Shows what will be deleted and space freed.

**Execute:**
```powershell
.\cleanup-old-models.ps1 -Execute
```
Deletes:
- Old SDXL models (fluxedUpFluxNSFW, iniverseMix)
- Old Stable Diffusion models
- Temporary/partial files
- Compiled Python cache

**Report:**
Shows count and size of deleted items.

---

## Step-by-Step Execution

### Step 1: Preview Consolidation
```powershell
cd D:\workspace\Baby_Nas
.\consolidate-ai-workspace.ps1 -Preview

# Review output:
# - Verifies source locations exist
# - Shows what will be copied (Flux models, dependencies)
# - Shows target structure
```

**Expected Output:**
```
Source Locations:
  ✓ ComfyUI (from User Home)
    Path: C:\Users\jdmal\ComfyUI
    Size: 50.5 GB

  ✓ Optimum (SDXL Models)
    Path: D:\Optimum
    Size: 182.3 GB

  ✓ Projects (Stable Diffusion)
    Path: D:\Projects
    Size: 48.2 GB

Key decisions to make:
1. FLUX MODELS TO KEEP:
   - flux1-dev-kontext_fp8_scaled.safetensors (11.09 GB)
   - flux1-dev-fp8.safetensors (11.08 GB)
   - flux1-schnell-fp8.safetensors (if present)

2. OLD SDXL MODELS TO DELETE:
   - fluxedUpFluxNSFW.safetensors (22.17 GB)
   - iniverseMix.safetensors (11.08 GB)
   - Other old SDXL .safetensors files
```

### Step 2: Execute Consolidation
```powershell
.\consolidate-ai-workspace.ps1 -Execute

# Will:
# 1. Create D:\workspace\ComfyUI directory structure
# 2. Copy Flux models from ComfyUI\models\checkpoints
# 3. Copy ComfyUI dependencies (custom_nodes, web, etc.)
# 4. Scan and list old SDXL/SD models (for manual review)
```

**Expected Time:** 10-30 minutes

**What To Watch For:**
- Progress messages showing folder creation
- Copy operations for Flux models
- File counts for old models found

### Step 3: Verify Consolidation Worked
```powershell
# Check if D:\workspace\ComfyUI was created
Get-ChildItem D:\workspace\ComfyUI

# Should show:
#   Directory: D:\workspace\ComfyUI
#
#   Mode   Name
#   ----   ----
#   d----  models
#   d----  custom_nodes
#   d----  web
#   d----  input
#   d----  output

# Check Flux models are present
Get-ChildItem D:\workspace\ComfyUI\models\checkpoints -Filter "flux*"

# Should show flux model files
```

### Step 4: Preview Cleanup
```powershell
.\cleanup-old-models.ps1 -Preview

# Shows:
# - Old SDXL models that will be deleted
# - Old SD models that will be deleted
# - Temp/partial files that will be deleted
# - Total space to be freed
```

**Example Output:**
```
Cleanup Analysis:

Old SDXL Models
  Location: D:\Optimum
  Old Models:
    ✓ fluxedUpFluxNSFW.safetensors (22.17 GB) - Old SDXL model - SAFE TO DELETE
    ✓ iniverseMix.safetensors (11.08 GB) - Old SDXL model - SAFE TO DELETE
  Temp/Partial Files:
    ✓ Found 5 *.crdownload files (2.8 GB) - Incomplete downloads
    ✓ Found 12 *.part* files (5.6 GB) - Partial extraction files

Total Space to Free: 41.61 GB from 17 files
```

### Step 5: Execute Cleanup
```powershell
.\cleanup-old-models.ps1 -Execute

# Will delete:
# - Old models (fluxedUpFluxNSFW, iniverseMix, others)
# - Temp files (.crdownload, .part0-9)
# - Compiled Python cache
#
# Shows progress and final freed space
```

**Expected Time:** 5-15 minutes

**Final Report:**
```
=== Cleanup Summary ===
  Files deleted: 47
  Failed deletions: 0
  Space freed: 41.61 GB

D: Drive free space: 150.5 GB
```

### Step 6: Update ComfyUI Configuration

Update any ComfyUI startup scripts/shortcuts to use new location:

```powershell
# Old (if pointing to C:\Users\jdmal\ComfyUI)
# New
cd D:\workspace\ComfyUI
python main.py
```

### Step 7: Optional - Delete Source Folders

Once you've tested the consolidated workspace and verified everything works:

```powershell
# Only after successful testing!

# Delete Optimum (SDXL models already consolidated)
Remove-Item D:\Optimum -Recurse -Force

# Delete Projects (SD models already consolidated)
Remove-Item D:\Projects -Recurse -Force

# Delete ai-workspace if it exists
Remove-Item "D:\ai-workspace" -Recurse -Force

# Delete old home backup (already archived to Baby NAS if needed)
Remove-Item "D:\~" -Recurse -Force
```

**Result:** Frees additional ~268 GB (total freed: 150-200+ GB)

---

## Troubleshooting

### "Cannot find Flux models"
- Verify `C:\Users\jdmal\ComfyUI` exists
- Check if models are in `models\checkpoints\` subdirectory
- May need to manually copy if structure is different

### "Consolidation didn't copy all files"
- Script only copies Flux models and essential directories
- Other models are listed for manual review
- Manually copy any models you want to keep

### "ComfyUI doesn't find models after consolidation"
- Update paths in ComfyUI config to point to `D:\workspace\ComfyUI`
- Verify `models\checkpoints\` has the model files
- Restart ComfyUI

### "Can't delete D:\Optimum - files in use"
- Close all ComfyUI instances
- Close any file explorers viewing the folders
- Verify no other applications have files open
- Try again

### "Low disk space during consolidation"
- Consolidation copies files first, then deletes
- Need temporary space for copies
- If running low, delete temp files first
- Run cleanup script first: `.\cleanup-old-models.ps1 -Execute`

---

## Success Checklist

- [ ] Ran consolidation preview and reviewed output
- [ ] Executed consolidation script
- [ ] Verified D:\workspace\ComfyUI created
- [ ] Verified Flux models copied to models\checkpoints\
- [ ] Tested ComfyUI with consolidated models
- [ ] Ran cleanup preview
- [ ] Executed cleanup script
- [ ] Verified old models deleted from source folders
- [ ] Checked D: drive has 150+ GB free space
- [ ] Updated ComfyUI shortcuts/configs to new location
- [ ] Deleted source folders (D:\Optimum, D:\Projects, etc.)
- [ ] Freed 150-200+ GB of space

---

## Reference

**Key Commands:**
```powershell
# Full consolidation workflow
.\consolidate-ai-workspace.ps1 -Preview      # Preview
.\consolidate-ai-workspace.ps1 -Execute      # Execute

# Full cleanup workflow
.\cleanup-old-models.ps1 -Preview            # Preview
.\cleanup-old-models.ps1 -Execute            # Execute

# Check space
Get-PSDrive D  # D: drive free space
Get-ChildItem D:\workspace\ComfyUI -Recurse | Measure-Object -Property Length -Sum

# List models
Get-ChildItem D:\workspace\ComfyUI\models\checkpoints -Filter "*.safetensors"
```

---

**Status:** Production Ready
**Version:** 1.0
**Last Updated:** 2025-12-18
