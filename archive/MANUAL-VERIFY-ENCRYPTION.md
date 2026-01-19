# Manual Encryption Verification

Run these commands on your Windows machine to verify encryption is working.

## Quick Check (2 minutes)

### 1. SSH into BabyNAS as root
```powershell
ssh root@192.168.215.2
# Password: 74108520
```

### 2. List encrypted datasets
```bash
zfs list | grep encrypted
```

You should see:
```
tank/backups_encrypted
tank/veeam_encrypted
tank/wsl-backups_encrypted
tank/media_encrypted
tank/phone_encrypted
tank/home_encrypted
```

If you see these 6 datasets, encryption **worked** ✅

---

## Detailed Verification (5 minutes)

### Check Encryption is Enabled

```bash
zfs list -o name,encryption,encrypted,recordsize,compression | grep _encrypted
```

Expected output:
```
NAME                           ENCRYPTION  ENCRYPTED  RECORDSIZE  COMPRESSION
tank/backups_encrypted         on          yes        1M          lz4
tank/veeam_encrypted           on          yes        1M          lz4
tank/wsl-backups_encrypted     on          yes        1M          lz4
tank/media_encrypted           on          yes        1M          lz4
tank/phone_encrypted           on          yes        128K        lz4
tank/home_encrypted            on          yes        128K        lz4
```

**All should show:**
- ✅ `encryption=on`
- ✅ `encrypted=yes`
- ✅ `compression=lz4`
- ✅ `atime=off` (if you check separately)

### Check jdmal Permissions

```bash
zfs allow | grep jdmal
```

You should see jdmal has permissions like:
```
create,receive,rollback,destroy,mount,unmount,snapshot,hold,release,send,compression
```

### Check Mount Point Ownership

```bash
ls -la /mnt/tank/ | grep _encrypted
```

Should show jdmal ownership:
```
drwxr-xr-x  2 jdmal jdmal  6 Jan  2 10:45 backups_encrypted
drwxr-xr-x  2 jdmal jdmal  6 Jan  2 10:45 veeam_encrypted
... etc
```

### Test jdmal Access

```bash
ssh jdmal@192.168.215.2
```

Then:
```bash
cd /mnt/tank/backups_encrypted
ls -la
```

If you can list files, jdmal has access ✅

---

## What Success Looks Like

✅ All 6 encrypted datasets exist
✅ All show `encryption=on` and `encrypted=yes`
✅ All have `compression=lz4`
✅ jdmal has permissions granted
✅ Mount points owned by jdmal
✅ jdmal can SSH and access datasets

---

## If Verification Fails

### Missing encrypted datasets?

```bash
# Check what datasets exist
zfs list

# If only unencrypted datasets (tank/backups, tank/veeam, etc.) exist:
# Run the encryption setup script:
# .\\RUN-ENCRYPTION-SETUP-NOW.ps1
```

### Encryption shows as "off" or "no"?

```bash
# Check encryption properties
zfs get encryption tank/backups_encrypted
zfs get encrypted tank/backups_encrypted

# If encryption is off, datasets were not created with encryption
# Delete and recreate with encryption enabled, or run setup script again
```

### jdmal has no permissions?

```bash
# Grant permissions manually
zfs allow -u jdmal create,receive,rollback,destroy,mount,unmount,snapshot,hold,release,send,compression tank/backups_encrypted
# Repeat for other _encrypted datasets
```

### jdmal can't access files?

```bash
# Check mount point ownership
ls -ld /mnt/tank/backups_encrypted

# If owned by root, change to jdmal:
chown jdmal:jdmal /mnt/tank/backups_encrypted
```

---

## Complete Verification Script

Copy and paste this entire block into SSH to run all checks at once:

```bash
#!/bin/bash

echo "====== ENCRYPTION VERIFICATION REPORT ======"
echo ""

echo "[1] Encrypted Datasets:"
zfs list -o name,encryption,encrypted,recordsize,compression | grep _encrypted
echo ""

echo "[2] jdmal User:"
id jdmal
echo ""

echo "[3] jdmal Permissions:"
zfs allow | grep -A 20 tank/backups_encrypted | head -5
echo ""

echo "[4] Mount Point Ownership:"
ls -ld /mnt/tank/backups_encrypted
echo ""

echo "[5] jdmal Can Access:"
su - jdmal -c "ls -la /mnt/tank/backups_encrypted | head -5"
echo ""

echo "====== END REPORT ======"
```

---

## Expected Results

| Check | Status | Command |
|-------|--------|---------|
| 6 encrypted datasets exist | ✅ | `zfs list \| grep encrypted` |
| Encryption = ON | ✅ | `zfs get encryption tank/backups_encrypted` |
| Encrypted = YES | ✅ | `zfs get encrypted tank/backups_encrypted` |
| Compression = LZ4 | ✅ | `zfs get compression tank/backups_encrypted` |
| jdmal user exists | ✅ | `id jdmal` |
| jdmal has permissions | ✅ | `zfs allow \| grep jdmal` |
| Mount point owned by jdmal | ✅ | `ls -ld /mnt/tank/backups_encrypted` |
| jdmal can access | ✅ | `su - jdmal -c "ls /mnt/tank/backups_encrypted"` |

---

## Summary

If all checks pass, your encryption is **completely verified** ✅

Your backup infrastructure is now:
- ✅ Encrypted (AES-256-GCM)
- ✅ Owned by jdmal
- ✅ Ready for replication
- ✅ Ready for internet access (Tailscale VPN)

---

## Next Steps

Once verified:

1. **Update snapshot tasks** in TrueNAS Web UI
   - Data Protection → Snapshots
   - Change dataset to `tank/backups_encrypted` (etc.)

2. **Update replication tasks** in TrueNAS Web UI
   - Data Protection → Replication
   - Change source to `tank/backups_encrypted` (etc.)

3. **Set up Tailscale VPN** for remote access
   - `.\SETUP-TAILSCALE-QUICK.ps1`

4. **Test remote access**
   - From any device with Tailscale
   - `https://100.64.x.x` (TrueNAS UI)
   - `\\100.64.x.x\backups_encrypted` (SMB)
   - `ssh jdmal@100.64.x.x` (SSH)

---

## Command Reference

All verification commands on one page:

```bash
# As root
ssh root@192.168.215.2

# List encrypted datasets
zfs list | grep _encrypted

# Check encryption properties
zfs list -o name,encryption,encrypted,recordsize,compression | grep _encrypted

# Check jdmal permissions
zfs allow | grep jdmal

# Check mount ownership
ls -ld /mnt/tank/backups_encrypted

# Test jdmal access
su - jdmal -c "ls /mnt/tank/backups_encrypted"

# Or SSH as jdmal
ssh jdmal@192.168.215.2
cd /mnt/tank/backups_encrypted
ls -la
```

Done! Your encryption is now verified. 🔐✅
