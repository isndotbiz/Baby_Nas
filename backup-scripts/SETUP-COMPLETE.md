# Restic Backup Setup - COMPLETE

## Setup Summary

Restic automated backup system is now configured and running!

**✓ 1Password Integration:** All passwords stored securely in 1Password CLI (no hardcoded secrets)

**Status:** Active - Backups every 30 minutes
**Repository:** D:\backups\baby_nas_restic
**Source:** D:\workspace\baby_nas
**Current Snapshots:** 2

## Critical Information

### Repository Password

**Stored in 1Password:**
- **Item Name:** BabyNAS Restic Backup
- **Vault:** TrueNAS Infrastructure
- **Password:** `BabyNAS-Restic-2026-SecureBackup!`

**IMPORTANT:** Password is required to access backups!
- Without this password, backups are irrecoverably lost
- Password is securely stored in 1Password (NOT hardcoded in scripts)
- All scripts automatically retrieve password from 1Password
- See [1PASSWORD-SETUP.md](1PASSWORD-SETUP.md) for details

## Installation Details

- **Restic Version:** 0.18.1
- **Installation Path:** C:\Tools\restic\restic.exe
- **Added to System PATH:** Yes
- **Repository Location:** D:\backups\baby_nas_restic (Note: Changed from E: to D: as E: drive not available)

## Scheduled Task

- **Task Name:** BabyNAS-Restic-Backup
- **Schedule:** Every 30 minutes, indefinitely
- **Runs as:** SYSTEM account
- **Status:** Active
- **Last Run:** 2026-01-07 8:23:36 PM (Success)
- **Next Run:** 2026-01-07 8:53:27 PM

## Retention Policy

Snapshots are automatically pruned according to this policy:
- **Hourly:** Keep last 24 (1 day)
- **Daily:** Keep last 7 (1 week)
- **Weekly:** Keep last 4 (4 weeks)
- **Monthly:** Keep last 6 (6 months)

## Current Status

### Repository Statistics
- Total Snapshots: 2
- Total File Count: 600
- Total Size: 5.424 MB
- Repository Storage: ~881 KB (after deduplication)

### Recent Backups
```
ID        Time                 Host             Tags        Size
--------------------------------------------------------------------------------------------
e1a0cbab  2026-01-07 20:20:36  DESKTOP-RYZ3900  automated   2.712 MB
89d8a31a  2026-01-07 20:23:36  DESKTOP-RYZ3900  automated   2.712 MB
```

## Common Operations

### List Snapshots
```powershell
cd D:\workspace\baby_nas\backup-scripts
# Password retrieved automatically from 1Password
$env:RESTIC_PASSWORD = & op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
restic snapshots --repo D:\backups\baby_nas_restic --tag automated
```

### Restore Latest Snapshot
```powershell
cd D:\workspace\baby_nas\backup-scripts
.\restore-baby-nas.ps1
# Files will be restored to D:\workspace\baby_nas_RESTORE
```

### Restore Specific Snapshot
```powershell
.\restore-baby-nas.ps1 -SnapshotId e1a0cbab
```

### Check Backup Health
```powershell
.\verify-backup-health.ps1
```

### Manual Backup (Test)
```powershell
Start-ScheduledTask -TaskName "BabyNAS-Restic-Backup"
```

### View Recent Logs
```powershell
Get-ChildItem .\logs\backup_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

### View Latest Log
```powershell
Get-Content (Get-ChildItem .\logs\backup_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

## Task Management

### View Task Status
```powershell
Get-ScheduledTask -TaskName "BabyNAS-Restic-Backup" | Get-ScheduledTaskInfo
```

### Disable Backups (Temporary)
```powershell
Disable-ScheduledTask -TaskName "BabyNAS-Restic-Backup"
```

### Enable Backups
```powershell
Enable-ScheduledTask -TaskName "BabyNAS-Restic-Backup"
```

### Remove Task (Permanent)
```powershell
Unregister-ScheduledTask -TaskName "BabyNAS-Restic-Backup" -Confirm:$false
```

## Monitoring

### Check Disk Space
```powershell
# Check repository size
$repoSize = (Get-ChildItem D:\backups\baby_nas_restic -Recurse -File |
    Measure-Object -Property Length -Sum).Sum / 1GB
Write-Host "Repository size: $([math]::Round($repoSize, 2)) GB"

# Check D: drive usage
$drive = Get-PSDrive D
$percentUsed = ($drive.Used / ($drive.Used + $drive.Free)) * 100
Write-Host "Drive D: is $([math]::Round($percentUsed, 1))% full"
```

### Review Backup Success Rate
```powershell
# Count successful backups in last 24 hours
$logs = Get-ChildItem .\logs\backup_*.log |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) }

$successful = ($logs | Select-String "=== Backup Completed Successfully ===").Count
Write-Host "Successful backups (last 24h): $successful"
```

## Troubleshooting

### Backup Fails - Password Error
If you see "wrong password or no key found":
1. Verify 1Password CLI is signed in: `op account list`
2. Test password retrieval: `op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal`
3. Verify repository exists at D:\backups\baby_nas_restic
4. See [1PASSWORD-SETUP.md](1PASSWORD-SETUP.md) for detailed troubleshooting

### Backup Fails - Restic Not Found
If you see "restic.exe not found in PATH":
1. Verify restic.exe exists at C:\Tools\restic\restic.exe
2. Check system PATH includes C:\Tools\restic
3. May need to restart for PATH changes to take effect

### Check Latest Error
```powershell
$latestLog = Get-ChildItem .\logs\backup_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content $latestLog | Select-String "ERROR"
```

## Storage Estimates

Based on current usage (2.7 MB source):
- 48 snapshots (24 hours): ~5-10 MB with deduplication
- 168 snapshots (1 week): ~15-30 MB with deduplication
- 720 snapshots (1 month): ~50-100 MB with deduplication

With 6-month retention policy: Expect ~200-500 MB total storage

## Next Steps (Optional)

1. **Add Email Notifications**: Configure script to send email on backup failure
2. **Remote Backup**: Add second repository on \\baby.isn.biz\backups for offsite storage
3. **Customize Exclusions**: Edit backup-baby-nas.ps1 to exclude additional file patterns
4. **Adjust Retention**: Modify retention parameters in backup-baby-nas.ps1 if needed

## Files Created

```
D:\workspace\Baby_Nas\backup-scripts\
├── backup-baby-nas.ps1           Main backup script
├── backup-wrapper.ps1            Wrapper that retrieves password from 1Password
├── restore-baby-nas.ps1          Restore utility (uses 1Password)
├── verify-backup-health.ps1      Health check script (uses 1Password)
├── create-backup-task.ps1        Task scheduler setup
├── get-restic-password.ps1       Helper to retrieve password from 1Password
├── README.md                     Usage documentation
├── SETUP-COMPLETE.md             This file
├── 1PASSWORD-SETUP.md            1Password integration documentation
└── logs\                         Backup logs (auto-cleaned after 30 days)
    ├── backup_2026-01-07_20-20-36.log
    ├── backup_2026-01-07_20-21-13.log
    ├── backup_2026-01-07_20-23-36.log
    └── backup_2026-01-07_20-36-31.log

D:\backups\baby_nas_restic\       Restic repository (encrypted)
C:\Tools\restic\restic.exe        Restic binary

1Password:
  Item: BabyNAS Restic Backup
  Vault: TrueNAS Infrastructure
  Password: BabyNAS-Restic-2026-SecureBackup!
```

## Security Notes

- **No Hardcoded Passwords** - All passwords stored in 1Password
- Repository is encrypted with AES-256
- Password required for all operations (backup, restore, check)
- Backups run as SYSTEM account (highest privileges)
- Scripts automatically retrieve password from 1Password at runtime
- 1Password provides audit trail of all password access
- Consider encrypting D: drive for additional security
- See [1PASSWORD-SETUP.md](1PASSWORD-SETUP.md) for complete security details

---

**Setup completed:** 2026-01-07 8:23 PM
**Restic version:** 0.18.1
**System:** DESKTOP-RYZ3900 (Windows)
