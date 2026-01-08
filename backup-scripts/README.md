# Baby NAS Restic Backup Scripts

Automated snapshot backups of D:\workspace\baby_nas using Restic with 30-minute intervals.

**Security:** All passwords stored in 1Password CLI (no hardcoded secrets)

## Quick Start

### 1. Install Restic

```powershell
# Download from https://github.com/restic/restic/releases
# Extract restic.exe to C:\Tools\restic\
# Add to PATH or use full path
```

### 2. Initialize Repository

```powershell
# Set password (use a strong password!)
$env:RESTIC_PASSWORD = "YourSecurePassword123!"

# Create backup location
New-Item -ItemType Directory -Path "D:\backups\baby_nas_restic" -Force

# Initialize repository
restic init --repo D:\backups\baby_nas_restic
```

### 3. Store Password in 1Password (REQUIRED)

Password is already stored in 1Password:
- **Item:** BabyNAS Restic Backup
- **Vault:** TrueNAS Infrastructure
- **Password:** `BabyNAS-Restic-2026-SecureBackup!`

To verify:
```powershell
op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
```

See [1PASSWORD-SETUP.md](1PASSWORD-SETUP.md) for full details.

### 4. Run First Backup

```powershell
# Test backup manually
.\backup-baby-nas.ps1

# Check logs
Get-Content .\logs\backup_*.log | Select-Object -Last 50
```

### 5. Schedule Automated Backups

```powershell
# Run as Administrator
.\create-backup-task.ps1
```

## Scripts

| Script | Purpose |
|--------|---------|
| `backup-baby-nas.ps1` | Main backup script with retention policy |
| `backup-wrapper.ps1` | Wrapper that retrieves password from 1Password |
| `restore-baby-nas.ps1` | Restore snapshots with safety checks |
| `verify-backup-health.ps1` | Check integrity and show stats |
| `create-backup-task.ps1` | Create scheduled task (30-min intervals) |
| `get-restic-password.ps1` | Helper to retrieve password from 1Password |
| `1PASSWORD-SETUP.md` | 1Password integration documentation |

## Common Operations

### List Snapshots

```powershell
# Password retrieved automatically from 1Password
$env:RESTIC_PASSWORD = & op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
restic snapshots --repo D:\backups\baby_nas_restic --tag automated
```

### Restore Latest Snapshot

```powershell
.\restore-baby-nas.ps1
# Files restored to D:\workspace\baby_nas_RESTORE
```

### Restore Specific Snapshot

```powershell
.\restore-baby-nas.ps1 -SnapshotId a1b2c3d4
```

### Full Rollback (DANGEROUS)

```powershell
.\restore-baby-nas.ps1 -OverwriteSource
# Type 'YES' to confirm
```

### Check Backup Health

```powershell
.\verify-backup-health.ps1
```

### Monitor Scheduled Task

```powershell
# View task info
Get-ScheduledTask -TaskName "BabyNAS-Restic-Backup" | Get-ScheduledTaskInfo

# View recent logs
Get-ChildItem .\logs\backup_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Start task manually (test)
Start-ScheduledTask -TaskName "BabyNAS-Restic-Backup"
```

## Retention Policy

Default settings keep:
- Hourly: 24 (last 24 hours)
- Daily: 7 (last 7 days)
- Weekly: 4 (last 4 weeks)
- Monthly: 6 (last 6 months)

Edit `backup-baby-nas.ps1` to adjust:

```powershell
.\backup-baby-nas.ps1 -RetentionHours 48 -RetentionDays 14
```

## Storage Requirements

- First backup: ~100% of source size
- Incremental snapshots: ~1-5% each (with deduplication)
- Budget 3x source size for safety

Example: 50GB source = 150GB backup storage

## Troubleshooting

### Password Not Found

All scripts now retrieve passwords from 1Password automatically.

If you need to manually retrieve:
```powershell
$env:RESTIC_PASSWORD = & op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
```

See [1PASSWORD-SETUP.md](1PASSWORD-SETUP.md) for troubleshooting.

### Backup Fails

```powershell
# Check detailed log
Get-Content .\logs\backup_*.log | Select-Object -Last 100

# Verify repository
restic check --repo D:\backups\baby_nas_restic
```

### Disk Space Issues

```powershell
# Check repository size
restic stats --repo D:\backups\baby_nas_restic --mode restore-size

# Manually prune old snapshots
restic forget --repo D:\backups\baby_nas_restic --keep-hourly 12 --prune
```

## Security Notes

- **All passwords stored in 1Password** (no hardcoded secrets in scripts)
- 1Password CLI retrieves passwords securely at runtime
- Restic repositories are encrypted at rest (AES-256)
- Backup scripts automatically retrieve password from 1Password
- No passwords stored in environment variables or files
- See [1PASSWORD-SETUP.md](1PASSWORD-SETUP.md) for security details
