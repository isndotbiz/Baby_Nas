# BabyNAS ZFS Encryption Setup Guide

## Overview

This guide enables encryption on all 6 datasets on BabyNAS and grants the `jdmal` user full permissions to manage them.

**Status**: ✅ Ready to execute
**Action Required**: Run encryption setup script on your Windows machine
**Estimated Time**: 10-15 minutes

---

## What This Does

1. ✅ Creates 6 **encrypted datasets** with AES-256-GCM encryption:
   - `tank/backups_encrypted`
   - `tank/veeam_encrypted`
   - `tank/wsl-backups_encrypted`
   - `tank/media_encrypted`
   - `tank/phone_encrypted`
   - `tank/home_encrypted`

2. ✅ Sets optimal **ZFS properties**:
   - **Recordsize**: 1M for backups (sequential), 128K for general use
   - **Compression**: LZ4 (automatic, reduces storage by ~30-50%)
   - **atime**: OFF (improves performance)

3. ✅ Grants **jdmal user permissions**:
   - create, receive, rollback, destroy, mount, snapshot, hold, release

4. ✅ **Verifies encryption status** and permissions

---

## Quick Start (Recommended)

### Option 1: Automated PowerShell Script (Easiest)

Run this on your **Windows machine**:

```powershell
cd D:\workspace\Baby_Nas
.\setup-encryption-windows-local.ps1
```

The script will:
- Guide you through the setup
- Ask for confirmation before proceeding
- Execute all ZFS commands via SSH
- Display results in real-time
- Show next steps

---

### Option 2: Manual SSH Commands (Copy-Paste)

If you prefer manual execution:

```bash
ssh root@192.168.215.2
# Password: 74108520
```

Then copy-paste each section below:

#### Step 1: Create Encrypted Datasets

```bash
# Create all encrypted datasets with AES-256-GCM
# Passphrase: BabyNAS2026Secure (you'll be prompted for each)

echo "BabyNAS2026Secure" | zfs create -o encryption=on -o keyformat=passphrase tank/backups_encrypted
echo "BabyNAS2026Secure" | zfs create -o encryption=on -o keyformat=passphrase tank/veeam_encrypted
echo "BabyNAS2026Secure" | zfs create -o encryption=on -o keyformat=passphrase tank/wsl-backups_encrypted
echo "BabyNAS2026Secure" | zfs create -o encryption=on -o keyformat=passphrase tank/media_encrypted
echo "BabyNAS2026Secure" | zfs create -o encryption=on -o keyformat=passphrase tank/phone_encrypted
echo "BabyNAS2026Secure" | zfs create -o encryption=on -o keyformat=passphrase tank/home_encrypted
```

#### Step 2: Set ZFS Properties

```bash
# Backups (1M recordsize for sequential access)
zfs set recordsize=1M tank/backups_encrypted
zfs set compression=lz4 tank/backups_encrypted
zfs set atime=off tank/backups_encrypted

# Veeam (same as backups)
zfs set recordsize=1M tank/veeam_encrypted
zfs set compression=lz4 tank/veeam_encrypted
zfs set atime=off tank/veeam_encrypted

# WSL Backups (same as backups)
zfs set recordsize=1M tank/wsl-backups_encrypted
zfs set compression=lz4 tank/wsl-backups_encrypted
zfs set atime=off tank/wsl-backups_encrypted

# Media (same as backups)
zfs set recordsize=1M tank/media_encrypted
zfs set compression=lz4 tank/media_encrypted
zfs set atime=off tank/media_encrypted

# Phone (128K for mixed file sizes)
zfs set recordsize=128K tank/phone_encrypted
zfs set compression=lz4 tank/phone_encrypted
zfs set atime=off tank/phone_encrypted

# Home (128K for general use)
zfs set recordsize=128K tank/home_encrypted
zfs set compression=lz4 tank/home_encrypted
zfs set atime=off tank/home_encrypted
```

#### Step 3: Grant jdmal Permissions

```bash
# Grant full dataset management permissions to jdmal
zfs allow -u jdmal create,receive,rollback,destroy,mount,snapshot,hold,release tank/backups_encrypted
zfs allow -u jdmal create,receive,rollback,destroy,mount,snapshot,hold,release tank/veeam_encrypted
zfs allow -u jdmal create,receive,rollback,destroy,mount,snapshot,hold,release tank/wsl-backups_encrypted
zfs allow -u jdmal create,receive,rollback,destroy,mount,snapshot,hold,release tank/media_encrypted
zfs allow -u jdmal create,receive,rollback,destroy,mount,snapshot,hold,release tank/phone_encrypted
zfs allow -u jdmal create,receive,rollback,destroy,mount,snapshot,hold,release tank/home_encrypted
```

#### Step 4: Verify Encryption

```bash
# Check encryption status
zfs list -o name,encryption,encrypted,recordsize,compression | grep encrypted

# Check jdmal permissions
zfs allow | grep jdmal
```

---

## Encryption Passphrase

**Passphrase**: `BabyNAS2026Secure`

⚠️ **IMPORTANT**: Store this passphrase in a secure location (password manager, 1Password, Vaultwarden, etc.)

This passphrase is required if you ever need to:
- Mount the encrypted datasets on a different system
- Recover data from backup
- Migrate datasets

---

## Next Steps After Setup

### 1. Test jdmal Access (5 minutes)

```bash
ssh jdmal@192.168.215.2
zfs list -o name,encryption,encrypted

# You should see all encrypted datasets with "yes" in the "encrypted" column
```

### 2. Update Snapshot Tasks (10 minutes)

In TrueNAS Web UI:
1. Go to **Data Protection → Snapshots**
2. Edit each snapshot task
3. Change dataset from `tank/backups` to `tank/backups_encrypted` (etc.)

### 3. Update Replication Tasks (10 minutes)

In TrueNAS Web UI:
1. Go to **Data Protection → Replication**
2. Edit each replication task
3. Change source dataset from `tank/backups` to `tank/backups_encrypted` (etc.)

### 4. Create SMB Shares (Optional, 10 minutes)

If you want to access encrypted datasets via SMB:

1. Go to **Storage → Shares → Windows (SMB)**
2. Click **Add**
3. For each encrypted dataset:
   - **Name**: `backups_encrypted`, `veeam_encrypted`, etc.
   - **Path**: `/mnt/tank/backups_encrypted`, etc.
   - **User**: `jdmal`
   - **Share Mode**: "Visible to system"

### 5. Migrate Data (Optional, 30+ minutes)

If you had existing data in the old datasets:

**On Windows (PowerShell):**
```powershell
robocopy "\\192.168.215.2\backups" "\\192.168.215.2\backups_encrypted" /MIR /COPY:DAT /R:3 /W:10
```

**On Linux/Mac (SSH):**
```bash
rsync -av --delete /mnt/tank/backups/ /mnt/tank/backups_encrypted/
```

### 6. Delete Old Unencrypted Datasets (Optional, Optional)

⚠️ **ONLY after verifying all data has been migrated and new datasets are working:**

```bash
zfs destroy -r tank/backups
zfs destroy -r tank/veeam
zfs destroy -r tank/wsl-backups
zfs destroy -r tank/media
zfs destroy -r tank/phone
zfs destroy -r tank/home
```

---

## Troubleshooting

### SSH Connection Issues

**Error**: `ssh: connect to host 192.168.215.2 port 22: No route to host`

**Solution**:
1. Verify BabyNAS is running:
   ```powershell
   ping 192.168.215.2
   ```

2. Check if SSH is enabled on BabyNAS:
   - TrueNAS Web UI → System Settings → Services
   - Enable SSH if not already enabled

3. Verify SSH key is set up:
   ```powershell
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
   ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.215.2
   ```

### Password Prompt on Each Dataset

**Issue**: "Enter passphrase" prompt appears multiple times

**This is normal** - ZFS requires the passphrase for each new encrypted dataset creation.

**Solution**: The automated script handles this automatically. If using manual commands, use the echo piping method shown above.

### Permission Denied Errors

**Error**: `permission denied` when running zfs commands

**Solution**:
1. Ensure you're logged in as `root`:
   ```bash
   whoami  # Should show "root"
   ```

2. If using `jdmal` user, confirm permissions are granted:
   ```bash
   zfs allow | grep jdmal
   ```

---

## Files Created

| File | Purpose |
|------|---------|
| `setup-encryption-windows-local.ps1` | 🚀 **Run this** - Automated setup script |
| `enable-dataset-encryption-complete.ps1` | Backup automated script (cloud-based) |
| `setup-dataset-encryption-and-permissions.py` | Python API configuration (tested) |
| `setup-dataset-encryption-and-permissions.ps1` | PowerShell API configuration |
| `ENABLE-ENCRYPTION-AND-PERMISSIONS.txt` | Detailed manual guide |
| `SETUP-ENCRYPTION-SUMMARY.md` | **You are here** - Quick reference |

---

## Success Criteria

✅ **Setup is complete when:**

1. All 6 encrypted datasets created
2. ZFS properties set correctly (recordsize, compression, atime)
3. jdmal user has permissions on all datasets
4. `zfs list` shows all datasets with `encryption=on` and `encrypted=yes`

---

## Support

If you encounter any issues:

1. Check the troubleshooting section above
2. Review logs in TrueNAS Web UI (System → Logs)
3. Run `zfs list` to verify current state
4. Check SSH connectivity: `ping 192.168.215.2`

---

## Summary

| Component | Status | Details |
|-----------|--------|---------|
| **Encrypted Datasets** | 🟡 Pending | 6 datasets to be created |
| **ZFS Properties** | 🟡 Pending | recordsize, compression, atime |
| **jdmal Permissions** | 🟡 Pending | create, receive, rollback, destroy, mount, snapshot, hold, release |
| **Encryption Passphrase** | ✅ Ready | `BabyNAS2026Secure` |
| **Automated Script** | ✅ Ready | `setup-encryption-windows-local.ps1` |
| **Manual Commands** | ✅ Ready | Copy-paste commands provided above |

---

**Next Action**: Run `setup-encryption-windows-local.ps1` on your Windows machine to enable encryption automatically.
