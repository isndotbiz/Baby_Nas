# BabyNAS Deep Dive Implementation Plan

## Executive Summary

This document synthesizes the analysis from 4 specialized agents (Storage Architect, Security Officer, Network Engineer, Backup Specialist) into a unified, production-ready configuration for BabyNAS.

**Target System:**
- BabyNAS IP: 192.168.215.2
- Main NAS (Replication Target): 10.0.0.89
- Hardware: 3x 6TB HDDs + 2x SSDs (~256GB each)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BABYNAS ARCHITECTURE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  STORAGE LAYER                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ Pool: tank (RAIDZ1)                                                  │    │
│  │ ├── Data VDEVs: 3x 6TB HDD ─────────────────── ~12TB usable         │    │
│  │ ├── SLOG: 2x 16GB SSD (mirrored) ───────────── Sync write accel     │    │
│  │ ├── L2ARC: 2x ~240GB SSD (striped) ─────────── ~480GB read cache    │    │
│  │ └── Compression: LZ4 (all datasets)                                  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  DATASET LAYER                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ tank/backups     ─── 1MB records, encrypted, 4TB quota              │    │
│  │ tank/veeam       ─── 1MB records, encrypted, 4TB quota              │    │
│  │ tank/wsl-backups ─── 1MB records, encrypted, 500GB quota            │    │
│  │ tank/media       ─── 1MB records, optional encrypt, 2TB quota       │    │
│  │ tank/phone       ─── 128KB records, encrypted, 500GB quota          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  SECURITY LAYER                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ SSH: Key-only, root prohibit-password, MaxAuthTries=3               │    │
│  │ SMB: SMB2_10 minimum, signing mandatory, no guest                   │    │
│  │ Users: nas-admin (sudo), baby-nas (replication), smb-users          │    │
│  │ Encryption: AES-256-GCM on sensitive datasets                       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  REPLICATION LAYER                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ BabyNAS ──── SSH (baby-nas user) ────▶ Main NAS (10.0.0.89)        │    │
│  │ Schedule: Daily 02:30 AM                                             │    │
│  │ Method: Incremental ZFS send/receive with LZ4 compression           │    │
│  │ Target: tank/rag-system/*                                            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Storage Configuration

### 1.1 Pool Creation (RAIDZ1)

**Via TrueNAS Web UI:**
1. Navigate to: Storage → Create Pool
2. Pool Name: `tank`
3. Layout: RAIDZ1
4. Select all 3x 6TB HDDs
5. Click Create

**Via CLI (SSH as root):**
```bash
# IMPORTANT: Use disk-by-id paths for stability
zpool create -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -O dnodesize=auto \
  -O normalization=formD \
  -O aclinherit=passthrough \
  -O acltype=posixacl \
  tank raidz1 \
  /dev/disk/by-id/ata-YOUR_HDD1 \
  /dev/disk/by-id/ata-YOUR_HDD2 \
  /dev/disk/by-id/ata-YOUR_HDD3
```

### 1.2 SSD Configuration (SLOG + L2ARC)

**Partition SSDs (16GB SLOG + remainder L2ARC):**
```bash
# Partition SSD1
sgdisk -n 1:0:+16G -t 1:bf01 -c 1:"slog1" /dev/disk/by-id/ata-YOUR_SSD1
sgdisk -n 2:0:0 -t 2:bf01 -c 2:"l2arc1" /dev/disk/by-id/ata-YOUR_SSD1

# Partition SSD2
sgdisk -n 1:0:+16G -t 1:bf01 -c 1:"slog2" /dev/disk/by-id/ata-YOUR_SSD2
sgdisk -n 2:0:0 -t 2:bf01 -c 2:"l2arc2" /dev/disk/by-id/ata-YOUR_SSD2

# Add mirrored SLOG
zpool add tank log mirror \
  /dev/disk/by-id/ata-YOUR_SSD1-part1 \
  /dev/disk/by-id/ata-YOUR_SSD2-part1

# Add L2ARC (striped for capacity)
zpool add tank cache \
  /dev/disk/by-id/ata-YOUR_SSD1-part2 \
  /dev/disk/by-id/ata-YOUR_SSD2-part2
```

### 1.3 Dataset Creation

```bash
# Veeam repository - large sequential writes
zfs create -o recordsize=1M \
  -o compression=lz4 \
  -o atime=off \
  -o primarycache=metadata \
  -o encryption=aes-256-gcm \
  -o keylocation=prompt \
  -o keyformat=passphrase \
  -o quota=4T \
  tank/veeam

# Windows backups
zfs create -o recordsize=1M \
  -o compression=lz4 \
  -o atime=off \
  -o primarycache=metadata \
  -o encryption=aes-256-gcm \
  -o keylocation=prompt \
  -o keyformat=passphrase \
  -o quota=4T \
  tank/backups

# WSL exports
zfs create -o recordsize=1M \
  -o compression=lz4 \
  -o atime=off \
  -o encryption=aes-256-gcm \
  -o keylocation=prompt \
  -o keyformat=passphrase \
  -o quota=500G \
  tank/wsl-backups

# Phone backups (mixed file sizes)
zfs create -o recordsize=128K \
  -o compression=lz4 \
  -o atime=off \
  -o encryption=aes-256-gcm \
  -o keylocation=prompt \
  -o keyformat=passphrase \
  -o quota=500G \
  tank/phone

# Media (optional encryption)
zfs create -o recordsize=1M \
  -o compression=lz4 \
  -o atime=off \
  -o quota=2T \
  tank/media
```

### 1.4 ARC/Memory Tuning

```bash
# For 16GB VM RAM - set ARC max to 8GB
echo "options zfs zfs_arc_max=8589934592" >> /etc/modprobe.d/zfs.conf
echo "options zfs zfs_arc_min=4294967296" >> /etc/modprobe.d/zfs.conf

# L2ARC write speed optimization
echo "options zfs l2arc_write_max=104857600" >> /etc/modprobe.d/zfs.conf
echo "options zfs l2arc_write_boost=209715200" >> /etc/modprobe.d/zfs.conf

# Apply without reboot
echo 8589934592 > /sys/module/zfs/parameters/zfs_arc_max
echo 104857600 > /sys/module/zfs/parameters/l2arc_write_max
```

---

## Phase 2: Security Hardening

### 2.1 User Account Structure

**Create Administrative User (Web UI):**
- Path: Credentials → Local Users → Add
```
Username: nas-admin
Full Name: NAS Administrator
Primary Group: Create new (nas-admin)
Additional Groups: builtin_administrators
Shell: bash
SSH Public Key: [your Ed25519 key]
Sudo: Allowed with password
```

**Create Replication Service Account:**
```
Username: baby-nas
Full Name: BabyNAS Replication Service
Shell: /usr/sbin/nologin
Disable Password: Yes
SSH Public Key: [replication key - generate on BabyNAS]
Sudo: Not allowed
```

**Create SMB Groups:**
| Group | GID | Purpose |
|-------|-----|---------|
| smb-readonly | 1100 | Read-only share access |
| smb-readwrite | 1101 | Read-write share access |
| backup-operators | 1102 | Backup service accounts |

### 2.2 SSH Hardening

**Web UI Path:** System → Services → SSH → Configure

| Setting | Value |
|---------|-------|
| TCP Port | 22 |
| Login as Root with Password | No |
| Allow Password Authentication | No |
| Allow TCP Port Forwarding | No |

**sshd_config recommendations (reference):**
```
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowTcpForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

### 2.3 SMB Hardening

**Web UI Path:** Services → SMB → Configure

| Setting | Value |
|---------|-------|
| Server Minimum Protocol | SMB2_10 |
| Server Maximum Protocol | SMB3_11 |
| Enable SMB1 Support | No |

**Auxiliary Parameters (add to SMB config):**
```
server signing = mandatory
smb encrypt = desired
restrict anonymous = 2
socket options = TCP_NODELAY IPTOS_LOWDELAY
use sendfile = yes
aio read size = 16384
aio write size = 16384
write cache size = 524288
```

**Per-Share Settings:**
- Allow Guest Access: **Unchecked** (all shares)
- Access Based Share Enumeration: **Enabled**

### 2.4 Dataset Encryption Key Management

**CRITICAL: Document passphrases securely offline!**

| Dataset | Encryption | Key Type | Auto-Unlock |
|---------|------------|----------|-------------|
| tank/backups | AES-256-GCM | Passphrase | Manual |
| tank/veeam | AES-256-GCM | Passphrase | Manual |
| tank/wsl-backups | AES-256-GCM | Passphrase | Manual |
| tank/phone | AES-256-GCM | Passphrase | Manual |
| tank/media | Optional | N/A | N/A |

**Unlock datasets after reboot:**
- Web UI: Datasets → [locked dataset] → Unlock

---

## Phase 3: Network Optimization

### 3.1 Network Interface Configuration

**Web UI Path:** Network → Interfaces → Edit

| Setting | Value |
|---------|-------|
| DHCP | No (use static) |
| IP Address | 192.168.215.2 |
| Netmask | 255.255.255.0 |
| IPv4 Gateway | 192.168.215.1 |
| MTU | 1500 |

**DNS Configuration:**
- Nameserver 1: 8.8.8.8
- Nameserver 2: 8.8.4.4

### 3.2 SSH Optimization for Replication

**Fast cipher selection (~/.ssh/config on BabyNAS):**
```
Host 10.0.0.89
    HostName 10.0.0.89
    User baby-nas
    IdentityFile /root/.ssh/id_ed25519_replication
    Ciphers aes128-gcm@openssh.com,chacha20-poly1305@openssh.com
    Compression no
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### 3.3 Windows Client Optimization

Run on Windows clients:
```powershell
# Enable SMB features
Set-SmbClientConfiguration -EnableLargeMtu $true -Force
Set-SmbClientConfiguration -EnableMultiChannel $true -Force
Set-SmbClientConfiguration -EnableBandwidthThrottling $false -Force
Set-SmbClientConfiguration -ConnectionCountPerRssNetworkInterface 4 -Force
```

---

## Phase 4: Backup & Replication

### 4.1 Snapshot Schedule

| Dataset | Hourly (24) | Daily (7) | Weekly (4) | Monthly (12) |
|---------|-------------|-----------|------------|--------------|
| tank/backups | Yes | Yes | Yes | Yes |
| tank/veeam | No | Yes | Yes | Yes |
| tank/wsl-backups | No | Yes | Yes | No |
| tank/media | No | Yes | No | Yes |
| tank/phone | Yes | Yes | Yes | No |

**Web UI Path:** Data Protection → Periodic Snapshot Tasks → Add

**Naming Schema Examples:**
- Hourly: `hourly-%Y-%m-%d_%H-%M`
- Daily: `daily-%Y-%m-%d`
- Weekly: `weekly-%Y-%m-%d`
- Monthly: `monthly-%Y-%m`

### 4.2 Replication Configuration

**Step 1: Create SSH Key on BabyNAS**
```bash
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519_replication -N "" -C "baby-nas-replication"
cat /root/.ssh/id_ed25519_replication.pub
```

**Step 2: Configure Main NAS (10.0.0.89)**

Create baby-nas user and grant permissions:
```bash
# On Main NAS as root
zfs create -p tank/rag-system
zfs allow -u baby-nas create,receive,rollback,destroy,mount,snapshot,hold,release tank/rag-system

# Add SSH key to /home/baby-nas/.ssh/authorized_keys
```

**Step 3: Create Replication Tasks**

**Web UI Path:** Data Protection → Replication Tasks → Add

| Task | Source | Destination | Schedule |
|------|--------|-------------|----------|
| Replicate-Backups | tank/backups | tank/rag-system/backups | Daily 02:30 |
| Replicate-Veeam | tank/veeam | tank/rag-system/veeam | Daily 03:00 |
| Replicate-WSL | tank/wsl-backups | tank/rag-system/wsl-backups | Daily 03:30 |
| Replicate-Media | tank/media | tank/rag-system/media | Daily 04:00 |
| Replicate-Phone | tank/phone | tank/rag-system/phone | Daily 04:30 |

**Replication Options:**
- Stream Compression: LZ4
- Large Block Support: Yes
- Compressed Send: Yes
- Recursive: Yes

### 4.3 Monitoring Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Replication Lag | 26 hours | 48 hours |
| Snapshot Freshness | 26 hours | 48 hours |
| Pool Capacity | 80% | 90% |
| Disk Temperature | 50°C | 55°C |

---

## Phase 5: Implementation Checklist

### Day 1: Storage Setup
- [ ] Create RAIDZ1 pool with 3x 6TB HDDs
- [ ] Partition SSDs (16GB SLOG + L2ARC)
- [ ] Add mirrored SLOG to pool
- [ ] Add L2ARC to pool
- [ ] Create datasets with encryption
- [ ] Document encryption passphrases securely
- [ ] Configure ARC limits
- [ ] Verify: `zpool status tank`

### Day 2: Security Hardening
- [ ] Create nas-admin user
- [ ] Create baby-nas service account
- [ ] Create SMB groups
- [ ] Configure SSH (key-only, no root password)
- [ ] Configure SMB (minimum SMB2_10, signing mandatory)
- [ ] Disable guest access on all shares
- [ ] Verify: `testparm -s`

### Day 3: Network & Services
- [ ] Configure static IP (192.168.215.2)
- [ ] Set DNS servers
- [ ] Apply SMB auxiliary parameters
- [ ] Create SMB shares for each dataset
- [ ] Test SMB connectivity from Windows
- [ ] Verify: `smbclient -L //192.168.215.2`

### Day 4: Backup & Replication
- [ ] Create snapshot tasks for all datasets
- [ ] Generate SSH keypair for replication
- [ ] Configure baby-nas user on Main NAS
- [ ] Grant ZFS permissions on Main NAS
- [ ] Create replication tasks
- [ ] Run initial replication (manual test)
- [ ] Verify: `zfs list -t snapshot -r tank`

### Day 5: Monitoring & Testing
- [ ] Configure email alerts
- [ ] Configure webhook alerts (Discord/Slack)
- [ ] Test restore from local snapshot
- [ ] Test restore from remote replica
- [ ] Document recovery procedures
- [ ] Schedule quarterly DR drill

---

## Quick Reference Commands

### Pool Status
```bash
zpool status tank
zpool iostat -v tank 5
arc_summary
```

### Dataset Management
```bash
zfs list -r tank
zfs get encryption,keystatus -r tank
zfs list -t snapshot -r tank | tail -20
```

### Replication Status
```bash
# Check replication task status via API
midclt call replication.query | jq '.[] | {name, state}'
```

### Unlock Encrypted Datasets
```bash
# Via Web UI: Datasets → [dataset] → Unlock
# Via CLI:
zfs load-key tank/backups
zfs mount tank/backups
```

### Manual Snapshot
```bash
zfs snapshot tank/backups@manual-$(date +%Y%m%d-%H%M%S)
```

### Test Replication
```bash
zfs send -nv tank/backups@latest | head -5
```

---

## Recovery Quick Reference

### Restore Single File
```bash
cp /mnt/tank/backups/.zfs/snapshot/daily-2024-01-15/file.txt /mnt/tank/backups/
```

### Clone Snapshot for Large Restore
```bash
zfs clone tank/backups@daily-2024-01-15 tank/restore-temp
# Copy files, then:
zfs destroy tank/restore-temp
```

### Pull from Main NAS (Disaster Recovery)
```bash
ssh baby-nas@10.0.0.89 "zfs send -Rv tank/rag-system/backups@latest" | zfs receive -Fv tank/backups
```

---

## Document Information

- **Created:** 2026-01-01
- **System:** BabyNAS (TrueNAS SCALE)
- **IP:** 192.168.215.2
- **Replication Target:** Main NAS (10.0.0.89)
- **Analysis By:** 4 Specialized Agents (Storage, Security, Network, Backup)
