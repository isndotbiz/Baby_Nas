# Baby NAS - Storage Only VM

Minimal TrueNAS SCALE VM for workspace sync, model archive, and staging.

## VM Configuration

| Setting | Value |
|---------|-------|
| **Name** | BabyNAS |
| **Path** | D:\VM\BabyNAS |
| **vCPUs** | 2 (threads) |
| **RAM** | 8GB (static) |
| **Network** | Virtual Switch (10.0.0.x) |
| **Hostname** | baby.isn.biz |

## Storage (Option B)

- **Boot**: 32GB VHDX (virtual disk on D:\VM\BabyNAS)
- **Pool**: 3x 6TB HDD (RAIDZ1, ~12TB usable)
- **Special vdev**: 2x 256GB SSD **mirrored** (metadata + small files)

Single SSD failure = pool stays online (mirror protects)

## Network Drives

| Drive | Share | Purpose |
|-------|-------|---------|
| W: | \\baby.isn.biz\workspace | Workspace sync |
| M: | \\baby.isn.biz\models | AI model archive |
| S: | \\baby.isn.biz\staging | Downloads, temp |
| B: | \\baby.isn.biz\backups | General backups |

## Architecture

```
Windows Host (NVMe)     →  Active models, GPU inference (24GB)
Baby NAS (HDD+SSD)      →  Storage: workspace, archive, staging
Main NAS (10.0.0.89)    →  Services, long-term, replication target
```

## Services (4 only)

- SSH, SMB, SMART, (optional NFS)
- NO Docker, NO apps, NO automation overhead

## Project Files

```
D:\workspace\Baby_Nas\
├── Create-BabyNAS-VM.ps1   # VM creation script
├── .env.example            # Credential template
├── .gitignore
├── CLAUDE.md
└── archive/                # Old scripts (reference)
```

## Quick Start

```powershell
# 1. Download TrueNAS SCALE ISO to D:\ISOs\
# 2. Run VM creation script (as admin)
.\Create-BabyNAS-VM.ps1

# 3. Passthrough disks, install TrueNAS, configure
```
