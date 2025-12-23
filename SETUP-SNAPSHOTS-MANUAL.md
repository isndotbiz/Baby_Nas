# Setup Automated Snapshots on Baby NAS - Manual Guide

**Status:** Ready to configure
**Baby NAS IP:** 172.21.203.18
**Pool:** tank

---

## Quick Start (3 Steps)

### Step 1: Start Baby NAS VM (if not running)
```powershell
# In PowerShell with admin rights
Start-VM -Name "TrueNAS-BabyNAS"

# Verify it's online
ping 172.21.203.18
# Should respond with replies
```

### Step 2: SSH into Baby NAS
```bash
# In PowerShell or terminal
ssh admin@172.21.203.18

# If prompted for password, default is usually set during TrueNAS setup
```

### Step 3: Enable Auto-Snapshots
Once connected via SSH, run these commands:

```bash
# Enable snapshots on tank pool
zfs set com.sun:auto-snapshot=true tank

# Enable hourly snapshots (keep 24 = 1 day)
zfs set com.sun:auto-snapshot:hourly=true tank

# Enable daily snapshots (keep 7 = 1 week)
zfs set com.sun:auto-snapshot:daily=true tank

# Enable weekly snapshots (keep 4 = 1 month)
zfs set com.sun:auto-snapshot:weekly=true tank
```

---

## What Gets Created

### Hourly Snapshots
- **Schedule:** Every hour on the hour
- **Retention:** Keep 24 snapshots (1 day window)
- **Purpose:** Quick recovery from recent accidental changes
- **Example names:**
  ```
  tank@hourly-2025-12-18-00
  tank@hourly-2025-12-18-01
  tank@hourly-2025-12-18-02
  ...
  ```

### Daily Snapshots
- **Schedule:** 3:00 AM daily
- **Retention:** Keep 7 snapshots (1 week of daily backups)
- **Purpose:** Recover from issues discovered day-old
- **Example names:**
  ```
  tank@daily-2025-12-18
  tank@daily-2025-12-17
  tank@daily-2025-12-16
  ...
  ```

### Weekly Snapshots
- **Schedule:** Sunday at 4:00 AM
- **Retention:** Keep 4 snapshots (4 weeks = ~1 month)
- **Purpose:** Long-term recovery points, detect older issues
- **Example names:**
  ```
  tank@weekly-2025-12-14 (Sunday)
  tank@weekly-2025-12-07 (Sunday)
  tank@weekly-11-30 (Sunday)
  tank@weekly-11-23 (Sunday)
  ```

---

## Verify Snapshots Are Working

### Option 1: Via SSH
```bash
# List all snapshots
zfs list -t snapshot

# List snapshots for tank pool only
zfs list -t snapshot tank

# Watch snapshots being created (run hourly)
zfs list -t snapshot tank | head -20
```

### Option 2: Via TrueNAS Web UI
1. Open browser: `https://172.21.203.18`
2. Login with admin credentials
3. Navigate: **Storage** → **Snapshots**
4. Should show hourly, daily, and weekly snapshots
5. Filter by pool: `tank`

---

## Advanced Configuration

### Change Snapshot Retention

If you want to keep MORE snapshots (more storage cost) or FEWER:

```bash
# Change hourly retention (default: 24)
# Example: keep 48 hourly snapshots (2 days)
zfs set com.sun:auto-snapshot:hourly=48 tank

# Change daily retention (default: 7)
# Example: keep 14 daily snapshots (2 weeks)
zfs set com.sun:auto-snapshot:daily=14 tank

# Change weekly retention (default: 4)
# Example: keep 8 weekly snapshots (2 months)
zfs set com.sun:auto-snapshot:weekly=8 tank
```

### Disable Snapshots

If you need to turn off snapshots temporarily:

```bash
# Disable all snapshots
zfs set com.sun:auto-snapshot=false tank

# Re-enable all snapshots
zfs set com.sun:auto-snapshot=true tank

# Disable only hourly
zfs set com.sun:auto-snapshot:hourly=false tank
```

---

## Restore from Snapshots

### List Available Snapshots
```bash
# See all snapshots
zfs list -t snapshot tank

# See just recent daily snapshots
zfs list -t snapshot tank | grep daily | tail -10
```

### Restore to a Point in Time

**Warning:** This is destructive - rolls back ALL changes after the snapshot!

```bash
# Rollback to a specific daily snapshot
zfs rollback tank@daily-2025-12-17

# This will undo all changes made after 2025-12-17 3:00 AM
```

### Clone Snapshot (Safe Preview)

To safely view what's in a snapshot without rolling back:

```bash
# Create a clone of daily snapshot from Dec 17
zfs clone tank@daily-2025-12-17 tank/restore-point

# Mount it (might auto-mount)
zfs mount tank/restore-point

# Now available at: /tank/restore-point for browsing
# Can safely restore individual files from here

# When done, destroy the clone
zfs destroy tank/restore-point
```

---

## Troubleshooting

### Snapshots Not Being Created

Check if auto-snapshot service is enabled:

```bash
# Enable auto-snapshot daemon
svcadm enable svc:/system/filesystem/zfs/auto-snapshot:default

# Check if it's running
svcadm status svc:/system/filesystem/zfs/auto-snapshot:default
```

### Storage Growing Despite Snapshots

Remember: **ZFS snapshots only use storage for changed data**

- Small changes = small snapshot overhead
- Large changes = larger snapshot storage use
- Snapshot storage is freed when snapshot is deleted

Example:
- If 10 GB changes between snapshots
- Each new snapshot only takes ~10 GB more storage
- Not 10 GB × number of snapshots

### Can't Connect via SSH

```bash
# First verify VM is running
Get-VM -Name "TrueNAS-BabyNAS" | Select State

# Try SSH with verbose output
ssh -vvv admin@172.21.203.18

# If it hangs on connection, check firewall on Baby NAS
# Via TrueNAS Web UI → System → Advanced → SSH
# Should be enabled on port 22
```

---

## Monitoring Snapshots

### View Snapshot Storage Usage

```bash
# See how much space snapshots use
zfs get referenced,usedbysnapshots,compressratio tank

# Example output:
# NAME  PROPERTY             VALUE
# tank  referenced           189.5G
# tank  usedbysnapshots      2.3G        <-- Snapshot overhead
# tank  compressratio        1.45x
```

### Monitor Pool Capacity

```bash
# Check pool status
zpool status tank

# Check pool space usage
zpool list tank

# Example output:
# NAME    SIZE    ALLOC   FREE    CAP
# tank   17.4T   9.5G   8.6T    55%     <-- Safe range
```

---

## Best Practices

✅ **DO:**
- Keep hourly snapshots for quick recovery
- Keep daily snapshots for week-long safety window
- Keep weekly snapshots for monthly recovery points
- Monitor pool capacity (keep under 80%)
- Test restoration occasionally

❌ **DON'T:**
- Keep TOO MANY snapshots (wastes storage)
- Keep TOO FEW snapshots (not useful)
- Ignore pool capacity (can cause issues)
- Rely only on snapshots (use real backups too)

---

## Quick Commands Reference

```bash
# List all snapshots
zfs list -t snapshot

# Create manual snapshot (optional)
zfs snapshot tank@manual-2025-12-18

# Delete old snapshot manually
zfs destroy tank@hourly-2025-12-10-00

# Rollback to snapshot (DESTRUCTIVE!)
zfs rollback tank@daily-2025-12-17

# Clone snapshot (non-destructive)
zfs clone tank@daily-2025-12-17 tank/restore-point

# Check snapshot property
zfs get com.sun:auto-snapshot tank

# Enable all snapshots
zfs set com.sun:auto-snapshot=true tank

# Disable all snapshots
zfs set com.sun:auto-snapshot=false tank
```

---

## Summary

After running the three commands in Step 3:
- ✅ Hourly snapshots created every hour
- ✅ Daily snapshots created at 3:00 AM
- ✅ Weekly snapshots created Sunday at 4:00 AM
- ✅ Automatic cleanup maintains retention
- ✅ Full recovery capability for any point in time
- ✅ No additional configuration needed

**Your data is now protected with automated snapshots!**

---

**Created:** 2025-12-18
**Ready for:** Manual SSH setup to Baby NAS
**Estimated time:** 5 minutes to setup
