# Baby NAS Archive & Snapshots Guide

Complete guide for archiving 307GB of old data from D: drive to Baby NAS and setting up automated snapshots.

## Overview

### Archive Project
- **Source**: 307GB of old data on D: drive
- **Target**: Baby NAS (172.21.203.18) with RAIDZ1 pool
- **Strategy**: Safe copy with verification before deletion
- **Retention**: Long-term archival with snapshots

### Folders to Archive
| Folder | Size | Purpose |
|--------|------|---------|
| `D:\Optimum\` | 182GB | Old development environment |
| `D:\~\` | 38GB | Old home directory backup |
| `D:\Projects\` | 48GB | Old project archives |
| `D:\ai-workspace\` | 39GB | Old AI workspace archive |

### Target Structure
```
NAS Archive Layout:
\\172.21.203.18\backups\archive\2025-12\
├── optimum/              (182GB)
├── home-backup/          (38GB)
├── projects/             (48GB)
├── ai-workspace-old/     (39GB)
└── manifest.json         (metadata)
```

---

## Quick Start

### Step 1: Dry Run (See What Will Happen)
```powershell
cd D:\workspace\Baby_Nas
.\archive-old-data.ps1
```

Shows:
- What folders will be copied
- Total data size (307GB)
- Archive directory structure
- Timeline estimate

**Output**: No data is changed (dry run mode)

### Step 2: Actually Perform Archive
```powershell
.\archive-old-data.ps1 -Execute
```

Process:
1. Copies all folders to `\\172.21.203.18\backups\archive\2025-12\`
2. Verifies file counts and sizes match
3. Creates manifest.json with metadata
4. **Preserves source folders** (you manually delete after confirmation)

**Expected time**: 2-4 hours for 307GB over network

### Step 3: Verify & Cleanup
```powershell
.\archive-old-data.ps1 -Execute -AutoCleanup
```

Process:
1. Performs archive (same as Step 2)
2. Verifies integrity
3. **Asks for confirmation before deleting each folder**
4. Safely removes source folders one by one

**Safety**: Each folder deletion requires manual confirmation

---

## Detailed Archive Workflow

### Phase 1: Pre-Archive Checklist

```powershell
# Check Baby NAS is online
Test-Connection 172.21.203.18

# Check SMB share is accessible
net use W: \\172.21.203.18\backups /user:admin "uppercut%`$##"

# Check available space on Baby NAS
(Get-Item W:).FreeSpace / 1GB  # Should show ~6-7 TB free
```

### Phase 2: Dry Run Analysis

```powershell
# See what will be archived (no changes)
.\archive-old-data.ps1

# Review the output:
# - Folder sizes
# - Archive path
# - Timeline estimate
# - Any missing folders
```

### Phase 3: Execute Archive

```powershell
# Start actual copy
.\archive-old-data.ps1 -Execute

# Script will:
# 1. Show connectivity status
# 2. Mount SMB share
# 3. Create directory structure
# 4. Copy each folder (with progress)
# 5. Verify integrity
# 6. Create manifest.json
# 7. Preserve source (for manual review)
```

**Monitor Progress:**
- Watch console output for copy progress
- Each folder shows transfer time
- Verification shows file/size match

### Phase 4: Verification

After archive completes:

```powershell
# Check archive exists on NAS
net use
# Should show mounted share

# Verify archive structure
Get-ChildItem \\172.21.203.18\backups\archive\2025-12\
# Should list: optimum/, home-backup/, projects/, ai-workspace-old/, manifest.json

# Check manifest
type \\172.21.203.18\backups\archive\2025-12\manifest.json
# Shows archive metadata, sizes, verification dates
```

### Phase 5: Cleanup Source (Manual)

**AFTER you're confident archive is good:**

```powershell
# Option 1: Manual deletion
Remove-Item -Path "D:\Optimum" -Recurse -Force
Remove-Item -Path "D:\~" -Recurse -Force
Remove-Item -Path "D:\Projects" -Recurse -Force
Remove-Item -Path "D:\ai-workspace" -Recurse -Force

# Option 2: Using the script with auto-cleanup
.\archive-old-data.ps1 -Execute -AutoCleanup
# Script asks for confirmation for each folder
```

**Reclaimed space**: ~307GB on D: drive

---

## Setting Up Snapshots

### Why Snapshots?

Snapshots protect archived data:
- **Hourly**: Recover from accidental deletion same day
- **Daily**: Weekly recovery points
- **Weekly**: Monthly archives
- **No storage cost**: ZFS snapshots use only changed data

### Configure Snapshots

```powershell
# Setup snapshot schedule
.\setup-snapshots.ps1

# This creates:
# - Hourly snapshots (keep 24)
# - Daily snapshots at 3:00 AM (keep 7)
# - Weekly snapshots Sunday 4:00 AM (keep 4)
```

### View Snapshots

```powershell
# List all current snapshots
.\setup-snapshots.ps1 -Schedule View

# Or via Python tool
python truenas-snapshot-manager.py list tank
```

### Snapshot Examples

After setup, you'll see snapshots like:
```
tank@hourly-2025-12-18-00
tank@hourly-2025-12-18-01
...
tank@daily-2025-12-18
tank@daily-2025-12-17
...
tank@weekly-2025-12-14 (Sunday)
tank@weekly-2025-12-07 (Sunday)
```

---

## Monitoring & Troubleshooting

### Check Archive Status

```powershell
# View archive location
\\172.21.203.18\backups\archive\2025-12\

# Check Baby NAS pool capacity
ssh admin@172.21.203.18 "zfs list -H tank | awk '{print \"Used: \" \$2 \", Avail: \" \$3}'"

# Result: Used: 307.5GB, Avail: 6.2TB (example)
```

### Verify Integrity

```powershell
# Compare source vs archived
$source = (Get-ChildItem D:\Optimum -Recurse | Measure-Object -Property Length -Sum).Sum
$archive = (Get-ChildItem \\172.21.203.18\backups\archive\2025-12\optimum -Recurse | Measure-Object -Property Length -Sum).Sum

if ($source -eq $archive) {
    Write-Host "✓ Sizes match" -ForegroundColor Green
} else {
    Write-Host "✗ MISMATCH - Investigate!" -ForegroundColor Red
}
```

### Troubleshooting

#### "Cannot reach Baby NAS"
```powershell
# Check if VM is running
Get-VM -Name TrueNAS-BabyNAS | Select-Object State

# Start if needed
Start-VM -Name TrueNAS-BabyNAS
```

#### "SMB share not accessible"
```powershell
# Verify credentials
net use \\172.21.203.18\backups /user:admin "uppercut%`$##" /delete
net use \\172.21.203.18\backups /user:admin "uppercut%`$##"

# Check SMB service on NAS
ssh admin@172.21.203.18 "svcs -a | grep smb"
```

#### "Archive is too slow"
```powershell
# Check network speed
iperf3 -c 172.21.203.18  # Requires iperf3 server on NAS

# Typical speeds over gigabit:
# - Expected: 100-125 MB/sec
# - 307GB would take ~45-50 minutes
```

#### "Verification failed"
```powershell
# Re-run the problematic folder
.\archive-old-data.ps1 -Execute

# Or manually verify
Get-ChildItem D:\Optimum -Recurse | Measure-Object -Property Length -Sum
Get-ChildItem \\172.21.203.18\backups\archive\2025-12\optimum -Recurse | Measure-Object -Property Length -Sum

# Sizes should match exactly
```

---

## Schedule Integration

### Automate Archive + Snapshots

Create Windows Task Scheduler job to run after backup:

```powershell
# Create task to run archive after nightly backup
$action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-ExecutionPolicy Bypass -File D:\workspace\Baby_Nas\archive-old-data.ps1 -Execute"
$trigger = New-ScheduledTaskTrigger -At 23:00 -Daily  # 11:00 PM daily
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Description "Daily archive to Baby NAS"
Register-ScheduledTask -TaskName "Archive to Baby NAS" -InputObject $task -Force
```

---

## Advanced Operations

### Restore from Archive

```powershell
# Copy archived folder back to D: drive
Copy-Item -Path "\\172.21.203.18\backups\archive\2025-12\optimum" -Destination "D:\Optimum-restored" -Recurse

# Or using robocopy
robocopy "\\172.21.203.18\backups\archive\2025-12\optimum" "D:\Optimum-restored" /E /Z
```

### Restore from Snapshot

```powershell
# SSH into Baby NAS
ssh admin@172.21.203.18

# List snapshots
zfs list -t snapshot

# Rollback to specific snapshot (DESTRUCTIVE!)
zfs rollback tank@daily-2025-12-17

# Or mount snapshot read-only
zfs clone tank@daily-2025-12-17 tank/restore-point
```

### Archive to Main NAS

```powershell
# Setup replication to Main NAS (10.0.0.89)
# This creates automatic backups of your archives

python truenas-replication-manager.py create \
  --source tank/archive \
  --target backup/archive \
  --schedule daily \
  --time "02:30"
```

---

## Reference

### Archive Script Options

```powershell
# Dry run (default - no changes)
.\archive-old-data.ps1

# Execute archive
.\archive-old-data.ps1 -Execute

# Execute with auto-cleanup
.\archive-old-data.ps1 -Execute -AutoCleanup

# Custom archive date
.\archive-old-data.ps1 -Execute -ArchiveDate "2025-12-old"

# Skip verification (not recommended)
.\archive-old-data.ps1 -Execute -SkipIntegrityCheck
```

### Snapshot Script Options

```powershell
# Setup snapshots
.\setup-snapshots.ps1 -Schedule Setup

# View snapshots
.\setup-snapshots.ps1 -Schedule View

# Remove snapshots
.\setup-snapshots.ps1 -Schedule Delete
```

### Manual Commands

```powershell
# View logs
Get-Content C:\Logs\archive-old-data-*.log -Tail 100

# Check free space on D:
(Get-Item D:\).FreeSpace / 1GB

# Check Baby NAS pool capacity
ssh admin@172.21.203.18 "zpool list tank"

# Monitor archive in progress
Get-Process robocopy  # Check if copy is running
```

---

## Timeline & Expectations

| Task | Time | Notes |
|------|------|-------|
| Dry run analysis | 5 min | No data copied |
| Archive 307GB | 45-120 min | Depends on network speed |
| Verification | 10-20 min | File/size checks |
| Manual cleanup | 5 min | Delete source folders |
| **Total** | **1-2.5 hours** | One-time operation |

---

## Success Checklist

- [ ] Ran dry run and reviewed output
- [ ] Baby NAS has 307GB+ free space
- [ ] Network connectivity verified
- [ ] Archive copied successfully
- [ ] Verification passed (all sizes match)
- [ ] Manifest.json created
- [ ] Source folders deleted (after confirmation)
- [ ] ~307GB reclaimed on D: drive
- [ ] Snapshots configured on Baby NAS
- [ ] First snapshot created and verified

---

## Support & Documentation

**Related guides:**
- `README-HEADLESS-STARTUP.md` - VM startup
- `BACKUP-DEPLOYMENT-GUIDE.md` - Backup configuration
- `MONITORING_AND_AUTOMATION_README.md` - Monitoring

**Python tools:**
```bash
python truenas-snapshot-manager.py --help
python truenas-manager.py --help
```

**SSH access:**
```bash
ssh admin@172.21.203.18
```

---

**Archive Date**: 2025-12-18
**Status**: Production Ready
**Version**: 1.0
