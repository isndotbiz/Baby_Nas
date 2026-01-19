# ZFS Replication Setup - Information Gathering Guide

## Overview

This document explains how to gather the information needed to set up automatic replication from BabyNAS (172.21.203.18) to Main NAS (10.0.0.89).

---

## 📋 Checklist of Information Needed

Before setting up automated replication, collect the following from your Main NAS (10.0.0.89):

### From Main NAS System

- [ ] **Main NAS Hostname/IP**
  - Value: `10.0.0.89`
  - Description: Static IP address of bare metal TrueNAS

- [ ] **Main NAS Root Password** (for setup only)
  - Description: Temporary access for initial configuration
  - IMPORTANT: Only used for setup, not stored in .env

- [ ] **Replication User Account Name**
  - Value: `baby-nas` (default, can be different)
  - Description: SSH user that will perform replication
  - Permission: Must have ZFS dataset permissions

- [ ] **Replication User SSH Public Key**
  - Description: Public key from BabyNAS authorized_keys
  - Format: Starts with `ssh-ed25519` or `ssh-rsa`
  - Source: From BabyNAS `~/.ssh/id_ed25519.pub`

### From Main NAS Storage

- [ ] **Available Pool Space**
  - Command: `zpool list` on Main NAS
  - Example Output:
    ```
    NAME    SIZE  ALLOC   FREE  CAP
    tank     16T   4.5T  11.5T  28%
    ```
  - Need: At least 6-8 TB free (for full sync)

- [ ] **Target Dataset Path**
  - Value: `tank/rag-system` (recommended)
  - Description: Where to receive replicated snapshots
  - Status: Should already exist or will be created

- [ ] **Target Dataset Mount Point**
  - Description: Where dataset is mounted on filesystem
  - Example: `/mnt/tank/rag-system`
  - Purpose: Verify space is accessible

### From Main NAS Configuration

- [ ] **ZFS Encryption Status**
  - Command: `zfs get encryption tank/rag-system`
  - Value: `encryption=off` (preferred) or `encryption=on`
  - If encrypted: Need passphrase or key

- [ ] **Pool Compression Status**
  - Command: `zfs get compression tank`
  - Recommended: `compression=lz4`
  - Affects: Storage efficiency and replication speed

- [ ] **Existing Snapshots Policy**
  - Command: `zfs list -t snapshot tank | head`
  - Description: See if snapshots already exist
  - Important: For incremental replication start point

### Network & Security

- [ ] **SSH Access Between Systems**
  - Test: `ssh -i ~/.ssh/id_ed25519 root@10.0.0.89 "zfs list"`
  - Should return: List of datasets on Main NAS
  - If fails: SSH keys not set up yet

- [ ] **Firewall Ports**
  - Port 22: SSH must be open between systems
  - Port 443: HTTPS for TrueNAS Web UI
  - Test: `Test-NetConnection -ComputerName 10.0.0.89 -Port 22`

---

## 🔧 Step-by-Step Information Collection

### Part 1: Access Main NAS Web UI

**URL:** `https://10.0.0.89`

**Login:** Use your TrueNAS credentials

### Part 2: Check Available Storage

1. Go to: **Storage → Pools → Tank**
2. Note the following:
   ```
   Pool Name: tank
   Total Size: [X] TB
   Used: [Y] TB
   Available: [Z] TB
   ```
3. Verify you have at least 6-8 TB available
4. If not enough, you may need to expand the pool

### Part 3: Check Existing Datasets

1. Go to: **Storage → Pools → Tank**
2. Expand the "tank" dataset
3. Look for existing datasets:
   - `tank/backups`
   - `tank/veeam`
   - `tank/wsl-backups`
   - `tank/media`
4. Note their sizes and compression settings

### Part 4: Create or Verify Target Dataset

1. If `tank/rag-system` doesn't exist:
   - Go to: **Storage → Pools → Tank**
   - Click: **Add Dataset**
   - Settings:
     ```
     Name: rag-system
     Compression: LZ4
     Deduplication: OFF
     Sync: Standard
     ```
   - Click: **Save**

2. If it already exists:
   - Note its current size
   - Note any existing snapshots
   - Verify compression setting

### Part 5: Create Replication User

1. Go to: **System → Users**
2. Click: **Add User**
3. Fill in:
   ```
   Username: baby-nas
   Full Name: BabyNAS Replication User
   Email: (leave blank)
   Password: (leave blank - use SSH key instead)
   Disable Password Login: ✓ (checked)
   ```
4. Click: **Add Group** and select/create appropriate group
5. Click: **Save**

### Part 6: Add SSH Public Key

1. From BabyNAS, get the public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
   This gives you something like:
   ```
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxx root@baby-nas
   ```

2. Back in Main NAS Web UI:
   - Go to: **System → Users → baby-nas**
   - Click: **Edit**
   - Scroll to: **SSH Public Key**
   - Paste the entire public key
   - Click: **Save**

### Part 7: Verify SSH Access

From PowerShell on Windows (or SSH on Linux):

```powershell
# Test SSH connection
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" baby-nas@10.0.0.89 "zfs list"

# Should show: List of datasets on Main NAS
```

If successful, you'll see:
```
NAME                    USED  AVAIL     REFER  MOUNTPOINT
tank                   5.2T  10.8T     104K   /mnt/tank
tank/rag-system        100G  10.8T      50G   /mnt/tank/rag-system
...
```

---

## 📝 Information Template

Print this and fill in the information from your Main NAS:

```
═══════════════════════════════════════════════════════════════════════
MAIN NAS (10.0.0.89) REPLICATION INFORMATION
═══════════════════════════════════════════════════════════════════════

SYSTEM INFORMATION:
  Main NAS IP:                    10.0.0.89
  Main NAS Hostname:              ________________
  TrueNAS Version:                ________________

STORAGE INFORMATION:
  Pool Name:                      tank
  Total Pool Size:                ________________ TB
  Used Space:                     ________________ TB
  Available Space:                ________________ TB
  Compression Method:             ________________ (should be: lz4)

TARGET DATASET:
  Dataset Name:                   tank/rag-system
  Dataset Mount Point:            /mnt/tank/rag-system
  Existing Data Size:             ________________ GB
  Encryption Enabled:             YES / NO (circle one)
  If Encrypted, Passphrase:       ________________

REPLICATION USER:
  Username:                       baby-nas
  User UID:                       ________________
  Primary Group:                  ________________
  SSH Public Key Added:           YES / NO (circle one)

SSH VERIFICATION:
  SSH Key Format:                 ________________ (ed25519 or rsa)
  SSH Key Fingerprint:            ________________
  SSH Connection Test:            SUCCESS / FAILED

NETWORK:
  Port 22 Open (SSH):             YES / NO
  Port 443 Open (HTTPS):          YES / NO
  VPN Access Required:            YES / NO
  Bandwidth Limit (if any):       ________________ Mbps

REPLICATION PREFERENCES:
  Preferred Schedule:             HOURLY / DAILY / WEEKLY / CUSTOM
  Backup Window (if restricted):  ________________
  Retention Policy:               ________________
  Notification Email:             ________________

═══════════════════════════════════════════════════════════════════════
```

---

## 🔐 Security Notes

### What NOT to Share
- ❌ Main NAS root password (only needed during setup)
- ❌ SSH private keys (ever)
- ❌ Dataset encryption passphrases (store separately)

### What IS Safe to Share
- ✅ System information (IP, hostname, version)
- ✅ Dataset names and paths
- ✅ Storage capacity numbers
- ✅ Network configuration
- ✅ Replication user name
- ✅ Snapshot policies

### SSH Key Best Practices
- Keep private keys secure: `~/.ssh/id_ed25519` (permission 600)
- Public keys are safe to share: `~/.ssh/id_ed25519.pub`
- Use separate keys for each purpose
- Ed25519 is more secure than RSA
- Never share or paste private keys

---

## 📊 Example Information (Filled In)

```
═══════════════════════════════════════════════════════════════════════
MAIN NAS (10.0.0.89) REPLICATION INFORMATION
═══════════════════════════════════════════════════════════════════════

SYSTEM INFORMATION:
  Main NAS IP:                    10.0.0.89
  Main NAS Hostname:              baremetal.isn.biz
  TrueNAS Version:                TrueNAS SCALE 24.04.1

STORAGE INFORMATION:
  Pool Name:                      tank
  Total Pool Size:                16 TB
  Used Space:                     4.5 TB
  Available Space:                11.5 TB
  Compression Method:             lz4

TARGET DATASET:
  Dataset Name:                   tank/rag-system
  Dataset Mount Point:            /mnt/tank/rag-system
  Existing Data Size:             0 GB
  Encryption Enabled:             NO
  If Encrypted, Passphrase:       N/A

REPLICATION USER:
  Username:                       baby-nas
  User UID:                       1003
  Primary Group:                  baby-nas
  SSH Public Key Added:           YES

SSH VERIFICATION:
  SSH Key Format:                 ed25519
  SSH Key Fingerprint:            SHA256:xxxxxxxxxxxxx
  SSH Connection Test:            SUCCESS

NETWORK:
  Port 22 Open (SSH):             YES
  Port 443 Open (HTTPS):          YES
  VPN Access Required:            NO
  Bandwidth Limit (if any):       None (unlimited)

REPLICATION PREFERENCES:
  Preferred Schedule:             HOURLY
  Backup Window (if restricted):  2:00 AM - 4:00 AM
  Retention Policy:               Keep 24 hourly, 7 daily, 4 weekly
  Notification Email:             admin@example.com

═══════════════════════════════════════════════════════════════════════
```

---

## 🚀 Next Steps

Once you have gathered all this information:

1. **Save this information securely**
   - Keep it in a safe location
   - Do not share passwords via email/chat

2. **Provide to replication setup script**
   - Use the information in `configure-zfs-replication-task.ps1`
   - Script will validate all credentials

3. **Create replication tasks**
   - Automated sync setup
   - Schedule optimization
   - Monitoring configuration

4. **Verify replication works**
   - Check first sync completes successfully
   - Monitor ongoing sync status
   - Verify snapshot retention

---

## 📞 Troubleshooting

### SSH Connection Fails
**Problem:** `Permission denied (publickey)`
**Solution:**
1. Verify SSH key is added to Main NAS user
2. Check public key has no extra whitespace
3. Test with: `ssh -vvv baby-nas@10.0.0.89`

### Insufficient Space
**Problem:** Not enough space on Main NAS
**Solution:**
1. Check actual data size: `zfs list -r tank`
2. Expand pool or delete old snapshots
3. Start with smaller datasets to replicate

### Encryption Error
**Problem:** `Cannot decrypt dataset`
**Solution:**
1. If dataset is encrypted, need passphrase or key
2. Or: Create new unencrypted dataset for replication
3. Contact Main NAS administrator for encryption keys

### Network Connectivity
**Problem:** `Cannot reach 10.0.0.89`
**Solution:**
1. Check firewall rules on Main NAS
2. Verify SSH port 22 is open
3. Check if VPN connection is needed
4. Test from command line: `ssh baby-nas@10.0.0.89`

---

## 📚 Additional Resources

- TrueNAS Documentation: https://www.truenas.com/docs/
- ZFS Best Practices: https://openzfs.github.io/
- SSH Key Management: https://man.openbsd.org/ssh-keygen
- Replication Troubleshooting: See `CONFIGURATION_GUIDE.md`

---

**Created:** 2025-01-01
**Version:** 1.0
