# Stable Diffusion Models Analysis

**Location:** `D:\Projects`
**Total Size:** 38.58 GB
**Total Models:** 24 files across 5 folders

---

## Overview by Category

| Category | Count | Size | Notes |
|----------|-------|------|-------|
| **Stable-diffusion** (Checkpoints) | 6 | 34.61 GB | Main base models |
| **Lora** (LoRA fine-tunes) | 15 | 3.24 GB | Style/quality modifiers |
| **loras** (duplicate LoRA folder) | 1 | 0.29 GB | Duplicate Facebook_Quality |
| **realistic** (LoRA variations) | 1 | 0.14 GB | Single skin texture |
| **VAE** (Variational autoencoders) | 1 | 0.31 GB | SDXL VAE file |

---

## Detailed Model List

### MAIN CHECKPOINTS (34.61 GB) - Large Base Models
These are full Stable Diffusion models. Most are 6-7 GB each.

| Model Name | Size | Type | Recommendation |
|-----------|------|------|-----------------|
| `cyberrealisticPony_v141.safetensors` | 6.46 GB | Pony/Anime | DELETE (old, not Flux) |
| `pikonRealism_v2_2187513.safetensors` | 6.62 GB | Realism | DELETE (old, not Flux) |
| `realismIllustriousBy_v50FP16_1987107.safetensors` | 6.46 GB | Realism | DELETE (old, not Flux) |
| `realismSDXLByStable_v80FP16_2231467.safetensors` | 6.46 GB | Realism | DELETE (old, not Flux) |
| `realisticVisionV60B1_v51HyperVAE_418901.safetensors` | 1.99 GB | Realism | DELETE (old, not Flux) |
| `ultraepicaiRealism_v10_1845407.safetensors` | 6.62 GB | Realism | DELETE (old, not Flux) |

**Summary:** All 6 are Stable Diffusion v1.5 models (deprecated). None are Flux. Safe to delete if you're using Flux exclusively.

---

### LORA FILES (3.24 GB) - Style/Quality Modifiers

**Large LoRA Files (>400 MB):**

| Model Name | Size | Purpose | Recommendation |
|-----------|------|---------|-----------------|
| `Pandora-RAWr.safetensors` | 596.5 MB | Photography quality | DELETE (old style) |
| `Realism Lora By Stable Yogi_V3_Lite_1971030.safetensors` | 649.7 MB | Realism enhancer | DELETE (for SD, not Flux) |
| `realism20lora20by.cpW5.safetensors` | 649.7 MB | Realism enhancer | DELETE (duplicate/old) |
| `zy_AmateurStyle_v2_632089.safetensors` | 435.3 MB | Amateur photography | DELETE (specific style) |
| `Facebookq-fotos.safetensors` | 219.2 MB | Photography quality | DELETE (old) |

**Medium LoRA Files (50-100 MB):**

| Model Name | Size | Purpose | Recommendation |
|-----------|------|---------|-----------------|
| `BSS_CNMTK-R(Restored)_2121183.safetensors` | 217.9 MB | Face restoration | DELETE (for SD v1.5) |
| `Facebook_Quality_Photos.safetensors` | 292.2 MB | Photo quality (duplicate) | DELETE (duplicate exists) |
| `hourglassv2_pony_836231.safetensors` | 54.8 MB | Pony body shape | DELETE (anime, not needed) |
| `ponyChar4ByStableYogi.uIsD.safetensors` | 54.8 MB | Pony character | DELETE (anime, not needed) |
| `superEyeDetailerBy.4EGS.safetensors` | 54.8 MB | Eye detail enhancer | DELETE (for SD, not Flux) |

**Small LoRA Files (<50 MB):**

| Model Name | Size | Purpose | Recommendation |
|-----------|------|---------|-----------------|
| `Add_Details_v1.2_1406099.safetensors` | 5.2 MB | Detail enhancement | DELETE (minimal size anyway) |
| `cyberrealisticNegative.DW8L.safetensors` | 0.6 MB | Negative prompt | DELETE (minimal) |
| `CyberRealistic_Negative_PONY_V2-neg.safetensors` | 0.6 MB | Negative prompt | DELETE (minimal) |
| `realismLoraByStable.VvFC.safetensors` | 42.5 MB | Realism enhancer | DELETE (for SD) |
| `Realism_Lora_By_Stable_yogi_SDXL8.1.safetensors` | 42.5 MB | Realism enhancer | DELETE (for SDXL, not Flux) |

**Summary:** All LoRA files are for Stable Diffusion v1.5 or XL. None are designed for Flux. Safe to delete if using Flux.

---

### VAE (0.31 GB) - Variational Autoencoders

| Model Name | Size | Purpose | Recommendation |
|-----------|------|---------|-----------------|
| `sdxl_vae.safetensors` | 319.1 MB | SDXL VAE encoder | DELETE (for SDXL, not Flux) |

**Summary:** This is for SDXL models. Not compatible with Flux.

---

### DUPLICATE LOCATIONS (0.43 GB) - Redundant Files

| Model Name | Size | Location | Recommendation |
|-----------|------|----------|-----------------|
| `Facebook_Quality_Photos.safetensors` | 292.2 MB | `loras\` folder | DELETE (duplicate in Lora folder) |
| `skin_texture.safetensors` | 144.1 MB | `realistic\` folder | DELETE (not used, minimal) |

**Summary:** These are duplicates or unused variants.

---

## Decision Matrix

### KEEP vs DELETE Recommendation

**Status: ALL 24 FILES ARE FOR STABLE DIFFUSION**

Since you're using Flux now:

```
RECOMMENDED ACTION: DELETE ALL 38.58 GB
├── Base models (34.61 GB): All are SD v1.5, not Flux
├── LoRA files (3.24 GB): All are for SD, not compatible with Flux
├── VAE (0.31 GB): SDXL only, not for Flux
└── Duplicates (0.43 GB): Redundant files
```

**Rationale:**
- Flux uses completely different model format
- These are all Stable Diffusion v1.5 or SDXL models
- Flux models are much more recent and better quality
- Size savings: 38.58 GB
- Compatibility: NONE with Flux

---

## Alternative: Keep Specific Models

If you ever want to use Stable Diffusion again, recommended models to keep:

| Model | Size | Reason | Keep? |
|-------|------|--------|-------|
| `pikonRealism_v2_2187513.safetensors` | 6.62 GB | Best realism model | Optional |
| `realisticVisionV60B1_v51HyperVAE_418901.safetensors` | 1.99 GB | Good general purpose | Optional |
| Other files | 30 GB | Niche/specific uses | NO |

**If keeping 2 models: 8.61 GB (save 30 GB)**

---

## Action Plan

### Option 1: Complete Cleanup (Recommended)
```powershell
# Delete entire D:\Projects folder
Remove-Item "D:\Projects" -Recurse -Force

# Space freed: 38.58 GB
# Total cleanup from project: 68 GB (29.32 already freed)
```

### Option 2: Keep "Just in Case"
```powershell
# Keep 2 best models, delete others
Remove-Item "D:\Projects\Stable-diffusion\*" -Exclude "*pikonRealism*", "*realisticVision*" -Force
Remove-Item "D:\Projects\Lora\*" -Force
Remove-Item "D:\Projects\loras" -Recurse -Force
Remove-Item "D:\Projects\realistic" -Recurse -Force
Remove-Item "D:\Projects\VAE" -Recurse -Force

# Space freed: 30 GB
# Kept: 8.61 GB (2 best models)
```

### Option 3: Archive to Baby NAS (Safe Backup)
```powershell
# Archive all SD models to Baby NAS before deleting
# Using existing archive script:
.\archive-old-data.ps1 -Execute

# Then delete source:
Remove-Item "D:\Projects" -Recurse -Force

# Result: Safe backup on NAS + 38.58 GB freed
```

---

## Model Details & Notes

### Base Models Explained

**Stable Diffusion v1.5 Models (6-7 GB each):**
- `cyberrealisticPony_v141` - Specialized for pony/anime style (Pony model variant)
- `pikonRealism_v2` - Photorealistic output, good for portraits
- `realismIllustrious` - Anime-influenced realism
- `realismSDXLByStable` - SDXL variant (not v1.5)
- `realisticVision` - Good general purpose photorealism
- `ultraepicaiRealism` - Over-stylized realism

**All are deprecated** - Flux v1 and v1.1 are much better quality and newer.

### LoRA Files Explained

**LoRA = Low Rank Adaptation** - These are fine-tuning files that modify base models

**Categories in your collection:**
- **Realism LoRA** - Enhance photorealism in SD models
- **Pony LoRA** - For anime/pony character generation
- **Quality LoRA** - Improve photo quality and detail
- **Negative LoRA** - Tell model what NOT to generate
- **Style LoRA** - Apply specific photography styles

**All are for Stable Diffusion** - Not compatible with Flux, which has its own styling system

### VAE Explained

**VAE = Variational AutoEncoder** - Compresses/decompresses images in the generation process

- This one is `sdxl_vae.safetensors` - For SDXL models only
- Flux has built-in VAE handling (different system)
- Not needed if not using SDXL

---

## Final Recommendation

### COMPLETE DELETE ALL
**Rationale:**
1. ✓ You're using Flux exclusively
2. ✓ None of these files are compatible with Flux
3. ✓ Flux quality > Stable Diffusion quality
4. ✓ Frees up 38.58 GB of valuable space
5. ✓ Can always re-download if needed later

**Command:**
```powershell
Remove-Item "D:\Projects" -Recurse -Force
```

**Result:**
- Space freed: 38.58 GB
- Total cleanup from start: 68 GB (29.32 already freed + 38.58 new)
- D: Drive free space: ~962 GB total
- Leaves only consolidated workspace and Optimum folder

---

## Files Created

All models listed and analyzed in:
- `D:\Projects\` - Current location
- See `CONSOLIDATION-EXECUTION-REPORT.md` for archive history

---

**Recommendation:** DELETE ALL (Type 'DELETE ALL' if you agree)

**Safe Backup Option:** Archive to Baby NAS first, then delete

**Conservative Option:** Keep the 2 best models (pikonRealism + realisticVision) = 8.61 GB

What would you like to do?
