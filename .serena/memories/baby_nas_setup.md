# Baby NAS - Storage Only VM

## Current Status: ✅ OPERATIONAL (Updated 2026-01-09)

## Philosophy
**Storage-only VM** - Minimal services, no Docker/apps overhead.
Focus: Workspace sync, model archive, staging, and backups.

## VM Configuration
- **Name**: BabyNAS
- **Host**: DESKTOP-RYZ3900 (Hyper-V)
- **Path**: D:\VM\BabyNAS
- **vCPUs**: 2 (threads)
- **RAM**: 8GB (static)
- **Boot Disk**: 32GB VHDX (virtual disk)

## Network
- **IP Address**: 10.0.0.88
- **Hostname**: baby.isn.biz
- **NetBIOS Name**: truenas
- **Workgroup**: WORKGROUP
- **Subnet**: 10.0.0.x/24 (Virtual Switch)
- **Main NAS**: 10.0.0.89 (replication target)

## Storage Pool
- **Pool Name**: tank
- **Status**: ONLINE
- **Type**: RAIDZ1 + mirrored special vdev
- **Data**: 3x 6TB HDD (Toshiba HDWE160, RAIDZ1)
- **Special vdev**: 2x 256GB SSD (Samsung 850, mirrored for metadata + small files)
- **Total**: ~18TB raw, ~10.8TB usable after RAIDZ1 parity

## Network Shares (SMB)
All shares accessible via \\10.0.0.88\ or \\baby.isn.biz\

| Drive | Share | Path | Purpose |
|-------|-------|------|---------|
| W: | workspace | /mnt/tank/workspace | Workspace sync |
| M: | models | /mnt/tank/models | AI model archive |
| S: | staging | /mnt/tank/staging | Downloads/temp |
| B: | backups | /mnt/tank/backups | General backups |

## Access & Credentials
**All credentials stored in 1Password vault "TrueNAS Infrastructure"**

### Admin Access
- Web UI: http://10.0.0.88
- User: truenas_admin
- Password: [1Password: "Baby NAS - TrueNAS Admin"]
- API Key: [1Password: "Baby NAS - TrueNAS Admin"]

### SSH Access
- Command: `ssh babynas`
- Host alias configured in ~/.ssh/config
- User: truenas_admin
- Key: ~/.ssh/babynas (Ed25519, passwordless)

### SMB Access
- User: smbuser
- Password: [1Password: "Baby NAS - SMB User"]
- Used for mapping network drives W:, M:, S:, B:

## Services (5 ONLY)
- **SSH** (port 22) ✅
- **SMB** (port 445) ✅
- **SMART** monitoring ✅
- **Tailscale** (remote access VPN) ✅
- **NFS** (optional)

**NO Docker, NO apps, NO automation overhead** (Tailscale runs as native systemd service)

## Remote Access (Tailscale) (NEW 2026-01-17)

### Installation
- **Method**: Native static binary installation (bypassed apt restrictions)
- **Service**: systemd service at /etc/systemd/system/tailscaled.service
- **Binaries**: /usr/bin/tailscale, /usr/sbin/tailscaled
- **State Directory**: /var/lib/tailscale
- **Version**: Tailscale 1.78.3

### Network Configuration
- **Tailscale IP**: 100.95.3.18
- **Subnet Routing**: Enabled for 10.0.0.0/24
- **IP Forwarding**: Enabled (persistent via /etc/sysctl.d/99-tailscale.conf)
- **DNS**: accept-dns=false (use local DNS)

### Connected Devices
| Device | Tailscale IP | Platform | Purpose |
|--------|--------------|----------|---------|
| baby | 100.95.3.18 | Linux | Baby NAS (this device) |
| desktop-ryz3900 | 100.79.49.12 | Windows | Windows desktop |
| jonathans-macbook-pro | 100.97.3.123 | macOS | MacBook Pro |
| samsung-sm-s928u | 100.103.5.63 | Android | Phone |
| truenas-docker | 100.78.159.106 | Linux | Main NAS Docker |

### Features Enabled
✅ **Remote Access**: Access Baby NAS from anywhere in the world
✅ **Subnet Routing**: Access entire home network (10.0.0.0/24) through Baby NAS
✅ **Encrypted VPN**: All traffic encrypted via WireGuard
✅ **No Port Forwarding**: No firewall changes or public exposure required

### Access from Remote Devices

**MacBook (via Tailscale):**
```bash
# SSH
ssh truenas_admin@100.95.3.18

# SMB shares
mount_smbfs //smbuser@100.95.3.18/workspace ~/NAS/workspace

# Or via Finder: smb://100.95.3.18/workspace
```

**Windows (via Tailscale):**
```powershell
# Map drives
net use W: \\100.95.3.18\workspace /user:smbuser

# SSH
ssh truenas_admin@100.95.3.18
```

**Via Subnet Routing:**
Once connected to Tailscale, remote devices can access the entire home network:
- Baby NAS via local IP: 10.0.0.88
- Windows Desktop: 10.0.0.100
- Main NAS: 10.0.0.89
- Router: 10.0.0.1

### Management Commands
```bash
# Check status
ssh babynas "tailscale status"

# Get Tailscale IP
ssh babynas "tailscale ip -4"

# Restart Tailscale
ssh babynas "systemctl restart tailscaled"

# Check service status
ssh babynas "systemctl status tailscaled"
```

### Documentation
See `D:\workspace\Baby_Nas\MACBOOK-SETUP.md` for detailed MacBook connection instructions.

## Backup & Version Control System (NEW 2026-01-09)

### 1. Local Restic Backup (D:\workspace)
- **Source**: D:\workspace (entire workspace, ~231 GB)
- **Repository**: D:\backups\workspace_restic (~5 GB deduplicated)
- **Schedule**: Every 30 minutes (requires Admin to enable task)
- **Task Name**: Workspace-Restic-Backup
- **1Password Item**: "Workspace Restic Backup" in TrueNAS Infrastructure vault
- **Excludes**: node_modules, .git, __pycache__, .venv, build artifacts, large binaries

### 2. Network Sync to Baby NAS
- **Source**: D:\workspace → **Destination**: W:\ (\\10.0.0.88\workspace)
- **Method**: Robocopy with smart exclusions
- **Schedule**: Every 60 minutes (requires Admin to enable task)
- **Task Name**: Workspace-NAS-Sync
- **Scripts**: sync-workspace-to-nas.ps1, sync-now.ps1

### 3. ZFS Snapshots on Baby NAS
Configured via TrueNAS SCALE API (midclt):

| Dataset | Schedule | Retention |
|---------|----------|-----------|
| tank/workspace | Hourly | 24 hours |
| tank/workspace | Daily | 7 days |
| tank/models | Hourly | 24 hours |
| tank/models | Daily | 7 days |
| tank/staging | Hourly | 24 hours |
| tank/staging | Daily | 7 days |
| tank/backups | Hourly | 24 hours |
| tank/backups | Daily | 7 days |

Check snapshots: `ssh babynas "midclt call pool.snapshottask.query"`

### 4. ZFS Replication to Main NAS
- **Source**: Baby NAS (10.0.0.88)
- **Target**: Main NAS (10.0.0.89) at tank/babynas/*
- **Schedule**: Daily at 2:30 AM
- **Datasets**: tank/workspace, tank/models, tank/staging, tank/backups
- **Status**: Configured and initial replication completed

Check replication: `ssh babynas "midclt call replication.query"`

## Project Structure
Location: D:\workspace\Baby_Nas\

### Essential Scripts
```
D:\workspace\Baby_Nas\
├── Create-BabyNAS-VM.ps1           # VM creation script
├── map-drives.bat                   # Quick map network drives
├── fix-and-map-drives.ps1          # Fix Windows SMB + map drives
├── map-baby-nas-drives.ps1         # Advanced mapping
├── restart-babynas-vm.ps1          # Restart VM with checks
├── Check-Snapshots.ps1             # Check ZFS snapshot status
├── ZFS-REPLICATION-SETUP.md        # Replication documentation
├── MACBOOK-SETUP.md                # MacBook remote access guide
├── install-tailscale.sh            # Tailscale installation script
├── docs/
│   └── ZFS-SNAPSHOTS.md            # Snapshot documentation
└── backup-scripts/
    ├── backup-workspace.ps1        # Restic backup (full workspace)
    ├── backup-wrapper.ps1          # Wrapper for scheduled task
    ├── restore-workspace.ps1       # Restore utility
    ├── verify-backup-health.ps1    # Health check
    ├── create-backup-task.ps1      # Create Restic scheduled task
    ├── get-restic-password.ps1     # 1Password helper
    ├── sync-workspace-to-nas.ps1   # Robocopy sync to NAS
    ├── sync-now.ps1                # Quick sync helper
    ├── sync-wrapper.ps1            # Wrapper for scheduled task
    ├── create-sync-task.ps1        # Create sync scheduled task
    ├── README.md                   # Backup documentation
    ├── SETUP-COMPLETE.md           # Setup summary
    ├── SYNC-SETUP.md               # Sync documentation
    ├── 1PASSWORD-SETUP.md          # 1Password integration docs
    └── logs/                       # Backup and sync logs
```

## Common Operations

### Enable Scheduled Tasks (Run as Administrator)
```powershell
cd D:\workspace\Baby_Nas\backup-scripts
.\create-backup-task.ps1    # Restic every 30 min
.\create-sync-task.ps1      # Sync every 60 min
```

### Manual Backup/Sync
```powershell
cd D:\workspace\Baby_Nas\backup-scripts
.\backup-wrapper.ps1        # Run Restic backup now
.\sync-now.ps1              # Run sync to NAS now
.\sync-now.ps1 -DryRun      # Preview sync changes
```

### Check Backup Status
```powershell
# Restic snapshots
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
restic snapshots --repo D:\backups\workspace_restic

# NAS sync logs
Get-Content (Get-ChildItem D:\workspace\Baby_Nas\backup-scripts\logs\sync_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
```

### Check ZFS Status
```bash
# Pool status
ssh babynas "zpool status tank"

# Snapshot tasks
ssh babynas "midclt call pool.snapshottask.query"

# List snapshots
ssh babynas "zfs list -t snapshot -r tank"

# Replication status
ssh babynas "midclt call replication.query"
```

### Map Network Drives
```powershell
.\map-drives.bat                    # Quick mapping
.\fix-and-map-drives.ps1            # Fix SMB issues first (Admin)
```

## Architecture
```
D:\workspace (NVMe)
    ↓ Restic backup (every 30 min)
D:\backups\workspace_restic (local versioning)

D:\workspace (NVMe)
    ↓ Robocopy sync (hourly)
Baby NAS W:\ (\\10.0.0.88\workspace)
    ↓ ZFS snapshots (hourly + daily)
    ↓ ZFS replication (daily)
Main NAS (10.0.0.89) tank/babynas/*
```

## Protection Layers
| Layer | What | Where | Schedule |
|-------|------|-------|----------|
| Restic | Local versioning | D:\backups\workspace_restic | Every 30 min |
| NAS Sync | Network copy | Baby NAS W: drive | Hourly |
| ZFS Snapshots | Point-in-time | Baby NAS tank pool | Hourly + Daily |
| ZFS Replication | Disaster recovery | Main NAS | Daily 2:30 AM |

**3-2-1 Backup Strategy Achieved** ✅

## 1Password Items
| Item Name | Vault | Purpose |
|-----------|-------|---------|
| Baby NAS - TrueNAS Admin | TrueNAS Infrastructure | Web UI / API access |
| Baby NAS - SMB User | TrueNAS Infrastructure | SMB share access |
| Workspace Restic Backup | TrueNAS Infrastructure | Restic repository password |
| BabyNAS Restic Backup | TrueNAS Infrastructure | Old Baby_Nas-only backup (legacy) |

## Last Updated
2026-01-17 - Added Tailscale for remote access with subnet routing (previous: 2026-01-09 - workspace backup system)
