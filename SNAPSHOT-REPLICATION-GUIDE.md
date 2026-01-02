# Automatic Snapshots & ZFS Replication Setup Guide

Complete guide for setting up automatic ZFS snapshots on BabyNAS and replicating to Main NAS (10.0.0.89).

---

## 📋 Overview

This setup provides:

✅ **Automatic Snapshots** on BabyNAS
- Hourly snapshots (24 hour retention)
- Daily snapshots (7 day retention)
- Weekly snapshots (4 week retention)

✅ **Automatic Replication** to Main NAS
- Push replication from BabyNAS → Main NAS
- Incremental snapshots (fast, bandwidth efficient)
- Scheduled sync (hourly, daily, or custom)

✅ **Data Protection**
- Point-in-time recovery up to 1 month
- 3 geographic locations (if Main NAS in different building)
- Automatic snapshot rotation

---

## 🚀 Step 1: Configure Automatic Snapshots (BabyNAS)

### Run the Snapshot Configuration Script

```powershell
cd D:\workspace\Baby_Nas
.\configure-zfs-snapshots.ps1
```

**What this does:**
1. ✓ Connects to BabyNAS via SSH
2. ✓ Configures ZFS snapshot properties
3. ✓ Prepares datasets for replication
4. ✓ Provides TrueNAS Web UI instructions

### Complete Configuration via TrueNAS Web UI

After running the script, finish setup in TrueNAS:

1. **Open TrueNAS Web UI:** https://172.21.203.18
2. **Go to:** System → Tasks → Periodic Snapshot Tasks
3. **Create 3 Tasks:**

#### Task 1: Hourly Snapshots
```
Description: Hourly BabyNAS Snapshots
Datasets:
  ✓ tank/backups
  ✓ tank/veeam
  ✓ tank/wsl-backups
  ✓ tank/media
Schedule: Every hour
Snapshot Naming: auto-{pool}-{dataset}-hourly-{year}{month}{day}-{hour}00
Keep for: 24 (snapshots)
Recursive: ✓ Yes
```

#### Task 2: Daily Snapshots
```
Description: Daily BabyNAS Snapshots
Datasets:
  ✓ tank/backups
  ✓ tank/veeam
  ✓ tank/wsl-backups
  ✓ tank/media
Schedule: Every day at 02:00 AM
Snapshot Naming: auto-{pool}-{dataset}-daily-{year}{month}{day}
Keep for: 7 (snapshots)
Recursive: ✓ Yes
```

#### Task 3: Weekly Snapshots
```
Description: Weekly BabyNAS Snapshots
Datasets:
  ✓ tank/backups
  ✓ tank/veeam
  ✓ tank/wsl-backups
  ✓ tank/media
Schedule: Every Sunday at 03:00 AM
Snapshot Naming: auto-{pool}-{dataset}-weekly-{year}-w{week}
Keep for: 4 (snapshots)
Recursive: ✓ Yes
```

### Verify Snapshots Are Created

After 1 hour, verify snapshots exist:

```powershell
# SSH into BabyNAS and check
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.21.203.18 "zfs list -t snapshot -r tank | head -20"
```

Expected output:
```
NAME                                          USED  AVAIL     REFER  MOUNTPOINT
tank/backups@auto-tank-backups-hourly-...    100M      -      50G   -
tank/veeam@auto-tank-veeam-hourly-...       200M      -     100G   -
tank/wsl-backups@auto-tank-wsl-hourly-...    50M      -      25G   -
tank/media@auto-tank-media-hourly-...       500M      -     250G   -
```

---

## 🔗 Step 2: Gather Information from Main NAS (10.0.0.89)

### Run the Replication Information Script

```powershell
.\setup-zfs-replication.ps1
```

**This script will show you:**
- Exactly what information is needed
- Where to find it on Main NAS
- Step-by-step instructions for each item

### Manual Information Gathering

If you prefer to gather manually, see: `REPLICATION-SETUP-INFO.md`

**Key information to collect:**

| Item | Location | Example |
|------|----------|---------|
| Available Space | Storage → Pools → Tank | 11.5 TB |
| Target Dataset | Storage → Pools | tank/rag-system |
| Replication User | System → Users | baby-nas |
| SSH Key Status | System → Users → baby-nas | Added ✓ |
| Encryption | Storage → Pools → rag-system | OFF |
| Compression | Storage → Pools → rag-system | lz4 |

### Create Replication User on Main NAS

1. **Open Main NAS Web UI:** https://10.0.0.89
2. **Go to:** System → Users → Add User
3. **Fill in:**
   ```
   Username: baby-nas
   Full Name: BabyNAS Replication User
   Disable Password Login: ✓ Checked
   ```
4. **Save**

### Add SSH Public Key to Replication User

1. **Get public key from BabyNAS:**
   ```powershell
   ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.21.203.18 "cat ~/.ssh/id_ed25519.pub"
   ```

2. **On Main NAS Web UI:**
   - Go to: System → Users → baby-nas → Edit
   - Find: SSH Public Key field
   - Paste the entire key (starts with `ssh-ed25519`)
   - Click: Save

3. **Verify SSH works:**
   ```powershell
   ssh -i "$env:USERPROFILE\.ssh\id_ed25519" baby-nas@10.0.0.89 "zfs list"
   ```
   Should show list of datasets on Main NAS

---

## 📝 Step 3: Update .env.local with Replication Settings

The `.env.local` file has been pre-populated with replication settings. Update the values based on information from Main NAS:

### Current .env.local Settings

```env
# Main NAS Target
MAIN_NAS_HOST=10.0.0.89
MAIN_NAS_HOSTNAME=baremetal.isn.biz
MAIN_NAS_USER=root

# Replication SSH User (from Main NAS)
REPLICATION_SSH_USER=baby-nas
REPLICATION_SSH_KEY=D:\workspace\Baby_Nas\keys\baby-nas_rag-system

# Target Dataset (on Main NAS)
REPLICATION_TARGET_DATASET=tank/rag-system
REPLICATION_TARGET_MOUNTPOINT=/mnt/tank/rag-system

# Replication Schedule
REPLICATION_SCHEDULE=hourly         # Options: hourly, daily, weekly, custom
REPLICATION_KEEP_HOURLY=24          # Keep 24 hourly snapshots
REPLICATION_KEEP_DAILY=7            # Keep 7 daily snapshots
REPLICATION_KEEP_WEEKLY=4           # Keep 4 weekly snapshots

# Replication Options
REPLICATION_COMPRESSION=lz4         # Must match or be compatible
REPLICATION_DEDUP=off               # Deduplication (usually off)
REPLICATION_ENCRYPTION=off          # Should match target dataset
REPLICATION_BANDWIDTH_LIMIT=0       # 0 = unlimited
```

### Update Instructions

1. **Edit .env.local:**
   ```powershell
   notepad D:\workspace\Baby_Nas\.env.local
   ```

2. **Update these values from Main NAS info:**
   - `MAIN_NAS_HOST` - Should be 10.0.0.89
   - `REPLICATION_SSH_USER` - Username created above (baby-nas)
   - `REPLICATION_TARGET_DATASET` - Target dataset path (tank/rag-system)
   - `REPLICATION_SCHEDULE` - Choose: hourly, daily, or weekly
   - `REPLICATION_KEEP_*` - Match Main NAS capacity
   - `REPLICATION_COMPRESSION` - Match Main NAS pool setting

3. **Save the file**

---

## 🔌 Step 4: Set Up Replication Tasks

### Option A: Manual Replication (One-Time)

For initial full sync, run manually first:

```powershell
# Send current snapshots from BabyNAS to Main NAS
ssh root@172.21.203.18 `
  "zfs send -R tank/backups@latest | ssh baby-nas@10.0.0.89 zfs recv -F tank/rag-system/backups"
```

### Option B: TrueNAS Built-in Replication (Recommended)

1. **On BabyNAS, go to:** Tasks → Replication Tasks → Add
2. **Fill in:**
   ```
   Name: BabyNAS to Main NAS Replication
   Source: Tank/backups (and other datasets)
   Destination: ssh://baby-nas@10.0.0.89/tank/rag-system
   Direction: Push (BabyNAS → Main NAS)
   Schedule: Hourly / Daily / Custom
   Enabled: ✓ Yes
   ```
3. **Save**

### Option C: Automated Script Replication

Create a PowerShell scheduled task:

```powershell
# Create scheduled replication task
$taskName = "BabyNAS ZFS Replication"
$taskPath = "\BabyNAS\"
$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\OpenSSH\ssh.exe" `
  -Argument '-i "$env:USERPROFILE\.ssh\id_ed25519" root@172.21.203.18 "zfs send -R tank/backups | ssh baby-nas@10.0.0.89 zfs recv -F tank/rag-system"'
$trigger = New-ScheduledTaskTrigger -Once -At "02:00 AM" -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -TaskPath $taskPath
```

---

## ✅ Step 5: Verify Replication Works

### Test the Replication Connection

```powershell
# From BabyNAS, test SSH to Main NAS
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.21.203.18 `
  "zfs send -n tank/backups@latest | ssh baby-nas@10.0.0.89 zfs recv -n -F tank/rag-system"
```

Should complete without errors.

### Monitor First Replication

1. **Check BabyNAS snapshots:**
   ```powershell
   ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.21.203.18 "zfs list -t snapshot -r tank | head -10"
   ```

2. **Check Main NAS received data:**
   ```powershell
   ssh -i "$env:USERPROFILE\.ssh\id_ed25519" baby-nas@10.0.0.89 "zfs list -r tank/rag-system"
   ```

3. **Watch replication status on TrueNAS:**
   - Go to: Tasks → Replication Tasks
   - Watch status column for recent activity
   - Should show: "Transfer in progress..." or "Completed successfully"

### Expected First Replication Time

```
Dataset Size    →    Replication Time
500 GB          →    30-45 minutes
1-2 TB          →    1-2 hours
4-5 TB (all)    →    2-4 hours
```

Time depends on:
- Network speed (gigabit = faster)
- Data size
- Compression enabled
- Other network traffic

---

## 📊 Monitoring Replication Status

### Check Replication History

```powershell
# On BabyNAS
ssh root@172.21.203.18 "zfs list -r tank"

# On Main NAS
ssh baby-nas@10.0.0.89 "zfs list -r tank/rag-system"
```

### View TrueNAS Replication Status

1. **BabyNAS Web UI:** https://172.21.203.18
   - Tasks → Replication Tasks
   - Shows: Last run time, next run, status

2. **Main NAS Web UI:** https://10.0.0.89
   - Storage → Pools → rag-system
   - Shows: Used space, snapshots, last modified

### Set Up Monitoring Alerts

In `.env` or TrueNAS:
```
Alert if replication fails
Alert if snapshots not created
Alert if storage gets low
Alert if replication takes longer than expected
```

---

## 🔄 Replication Bandwidth & Performance

### Estimate Bandwidth Usage

```
Per Hourly Replication:
  • Small changes: 100 MB - 500 MB
  • Large changes: 500 MB - 2 GB

Per Daily Replication:
  • Typical: 5-20 GB
  • Heavy backups: 20-50 GB

Monthly Bandwidth:
  • Typical: 5-10 TB
  • Heavy backups: 10-20 TB
```

### Optimize Bandwidth

**If bandwidth is limited:**

1. **Reduce snapshot frequency:**
   ```
   Change from: Hourly → Daily → Weekly
   Reduces bandwidth by: 80-90%
   ```

2. **Limit bandwidth in script:**
   ```env
   REPLICATION_BANDWIDTH_LIMIT=100  # Limit to 100 Mbps
   ```

3. **Schedule during off-peak hours:**
   ```
   Replication at: 2:00 AM - 6:00 AM
   Backup jobs at: 7:00 PM - 2:00 AM
   ```

---

## 🔐 Security Best Practices

### SSH Key Protection
- ✅ SSH public key in authorized_keys
- ✅ SSH private key in secure location (password protected if possible)
- ✅ Permissions: `chmod 600 ~/.ssh/id_ed25519`

### Firewall Rules
- ✅ Allow SSH (port 22) between BabyNAS and Main NAS
- ✅ Restrict to known IP addresses if possible
- ✅ Use VPN if systems are geographically separated

### Data Integrity
- ✅ ZFS checksums validate all data
- ✅ Snapshots are read-only (cannot be modified)
- ✅ Replication preserves checksums

### Credential Management
- ✅ Never commit .env files to git
- ✅ Store SSH keys securely
- ✅ Rotate credentials periodically
- ✅ Restrict replication user permissions (not root if possible)

---

## 🆘 Troubleshooting

### Problem: Replication Fails to Start

**Symptoms:**
- Replication task shows "Waiting..."
- Never actually runs

**Solutions:**
1. Check SSH connectivity:
   ```powershell
   ssh -i "$env:USERPROFILE\.ssh\id_ed25519" baby-nas@10.0.0.89 "zfs list"
   ```

2. Verify SSH key is added to user:
   ```powershell
   ssh -i "$env:USERPROFILE\.ssh\id_ed25519" baby-nas@10.0.0.89 "cat ~/.ssh/authorized_keys"
   ```

3. Check TrueNAS logs:
   - Go to: System → Logs → Services
   - Look for replication errors

### Problem: Replication Is Very Slow

**Symptoms:**
- Replication takes hours for small changes
- High CPU or network usage

**Solutions:**
1. Check network bandwidth:
   ```powershell
   # Speed test between systems
   iperf3 between BabyNAS and Main NAS
   ```

2. Reduce frequency:
   - Change from hourly to daily
   - Run during off-peak hours

3. Monitor CPU:
   - Check if compression is CPU-bound
   - Consider: LZ4 (fast) vs other compression

### Problem: "Permission Denied" Errors

**Symptoms:**
```
error: permission denied
cannot create dataset: /tank/rag-system/backups
```

**Solutions:**
1. Check replication user permissions:
   ```powershell
   ssh baby-nas@10.0.0.89 "zfs allow -u baby-nas tank/rag-system"
   ```

2. Grant necessary permissions:
   ```bash
   # On Main NAS
   zfs allow -u baby-nas create,receive,rollback,destroy,mount \
     tank/rag-system
   ```

3. Use root user instead:
   - Edit replication task
   - Change user from baby-nas to root

### Problem: Snapshots Using Too Much Space

**Symptoms:**
- Pool capacity warning
- Snapshots taking 20%+ of pool space

**Solutions:**
1. Reduce snapshot retention:
   ```env
   REPLICATION_KEEP_HOURLY=12  # Down from 24
   REPLICATION_KEEP_DAILY=3    # Down from 7
   ```

2. Enable compression if not already:
   ```
   On TrueNAS: Storage → Pools → tank → Edit
   Set: Compression = LZ4
   ```

3. Delete old snapshots:
   ```bash
   zfs destroy -r tank/backups@old-snapshot
   ```

---

## 📈 Performance Expectations

### Replication Completion Times

| Dataset | Size | Network | Time |
|---------|------|---------|------|
| tank/backups | 500 GB | Gigabit | 30-45 min |
| tank/veeam | 1.5 TB | Gigabit | 1-2 hours |
| tank/wsl | 100 GB | Gigabit | 10-15 min |
| tank/media | 2 TB | Gigabit | 1-2 hours |
| **Total** | **4-5 TB** | **Gigabit** | **2-4 hours** |

### Incremental Replication Times

```
Typical hourly replication: 5-15 minutes
Daily replication: 30-60 minutes
Weekly replication: 1-3 hours
```

---

## 📚 Next Steps

1. ✅ Run `configure-zfs-snapshots.ps1`
2. ✅ Complete TrueNAS snapshot task setup
3. ✅ Run `setup-zfs-replication.ps1`
4. ✅ Gather information from Main NAS
5. ✅ Update .env.local with replication settings
6. ✅ Create replication tasks (TrueNAS or manual)
7. ✅ Test first replication
8. ✅ Monitor for 24-48 hours
9. ✅ Set up monitoring alerts

---

## 📞 Support Resources

- TrueNAS Replication Docs: https://www.truenas.com/docs/scale/
- ZFS Snapshots: https://openzfs.github.io/
- SSH Troubleshooting: man ssh-keygen
- See: `REPLICATION-SETUP-INFO.md` for detailed information gathering

---

**Created:** 2025-01-01
**Version:** 1.0
**Last Updated:** 2025-01-01
