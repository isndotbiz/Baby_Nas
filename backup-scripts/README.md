# Workspace Restic Backup Scripts

Automated snapshot backups of **D:\workspace** (entire workspace) using Restic with 30-minute intervals.

**Security:** All passwords stored in 1Password CLI (no hardcoded secrets)

## Backup Scope

| Source | Repository | Description |
|--------|------------|-------------|
| D:\workspace | D:\backups\workspace_restic | All workspace projects |

### Excluded Patterns

The backup automatically excludes:
- **Version Control:** `.git`, `.svn`, `.hg` (already versioned)
- **Node.js:** `node_modules`, `.npm`, `.yarn`, `.pnpm-store`
- **Python:** `__pycache__`, `.venv`, `venv`, `.tox`, `.pytest_cache`, `*.pyc`
- **Build Outputs:** `bin`, `obj`, `dist`, `out`, `target`, `build`
- **IDE Files:** `.idea`, `.vs`, `.vscode/settings.json`
- **Cache/Temp:** `.cache`, `.next`, `.nuxt`, `*.tmp`, `*.log`
- **Large Binaries:** `*.iso`, `*.vhdx`, `*.vmdk`
- **AI Models:** `*.gguf`, `*.safetensors`, `*.pt`, `*.onnx`
- **Secrets:** `.env`, `*.pem`, `*.key`

See `backup-workspace.ps1` for the complete exclusion list.

## Quick Start

### 1. Install Restic (if not already installed)

```powershell
# Download from https://github.com/restic/restic/releases
# Extract restic.exe to C:\Tools\restic\
# Add to PATH or use full path
```

### 2. Create 1Password Entry

Create a new item in 1Password:
- **Item Name:** Workspace Restic Backup
- **Vault:** TrueNAS Infrastructure
- **Password:** (generate a strong password)

### 3. Initialize Repository

```powershell
# Create backup location
New-Item -ItemType Directory -Path "D:\backups\workspace_restic" -Force

# Set password from 1Password
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal

# Initialize repository
restic init --repo D:\backups\workspace_restic
```

### 4. Run First Backup

```powershell
# Test backup manually
.\backup-wrapper.ps1

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
| `backup-workspace.ps1` | Main backup script with retention policy and exclusions |
| `backup-wrapper.ps1` | Wrapper that retrieves password from 1Password |
| `restore-workspace.ps1` | Restore snapshots with safety checks |
| `verify-backup-health.ps1` | Check integrity and show stats |
| `create-backup-task.ps1` | Create scheduled task (30-min intervals) |
| `get-restic-password.ps1` | Helper to retrieve password from 1Password |

## Common Operations

### List Snapshots

```powershell
# Password retrieved automatically from 1Password
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
restic snapshots --repo D:\backups\workspace_restic --tag automated
```

### Restore Latest Snapshot

```powershell
.\restore-workspace.ps1
# Files restored to D:\workspace_RESTORE
```

### Restore Specific Snapshot

```powershell
.\restore-workspace.ps1 -SnapshotId a1b2c3d4
```

### Restore Single File/Directory

```powershell
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal

# List files in a snapshot
restic ls latest --repo D:\backups\workspace_restic

# Restore specific path
restic restore latest --repo D:\backups\workspace_restic --target D:\restore_temp --include "D:\workspace\MyProject"
```

### Full Rollback (DANGEROUS)

```powershell
.\restore-workspace.ps1 -OverwriteSource
# Type 'YES I UNDERSTAND' to confirm
```

### Check Backup Health

```powershell
.\verify-backup-health.ps1
```

### Monitor Scheduled Task

```powershell
# View task info
Get-ScheduledTask -TaskName "Workspace-Restic-Backup" | Get-ScheduledTaskInfo

# View recent logs
Get-ChildItem .\logs\backup_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Start task manually (test)
Start-ScheduledTask -TaskName "Workspace-Restic-Backup"
```

## Retention Policy

Default settings keep:
- **Hourly:** 24 (last 24 hours)
- **Daily:** 7 (last 7 days)
- **Weekly:** 4 (last 4 weeks)
- **Monthly:** 6 (last 6 months)

Edit `backup-workspace.ps1` to adjust:

```powershell
.\backup-workspace.ps1 -RetentionHours 48 -RetentionDays 14
```

## Storage Requirements

Estimates based on typical workspace size:

| Workspace Size | First Backup | 1 Week | 1 Month |
|----------------|--------------|--------|---------|
| 10 GB | ~10 GB | ~15 GB | ~25 GB |
| 50 GB | ~50 GB | ~75 GB | ~125 GB |
| 100 GB | ~100 GB | ~150 GB | ~250 GB |

Note: Restic deduplication significantly reduces actual storage needed.

## Troubleshooting

### Password Not Found

All scripts now retrieve passwords from 1Password automatically.

If you need to manually retrieve:
```powershell
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
```

### 1Password CLI Not Signed In

```powershell
# Check status
op account list

# Sign in
op signin
```

### Backup Fails

```powershell
# Check detailed log
Get-Content .\logs\backup_*.log | Select-Object -Last 100

# Verify repository
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
restic check --repo D:\backups\workspace_restic
```

### Disk Space Issues

```powershell
# Check repository size
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
restic stats --repo D:\backups\workspace_restic --mode restore-size

# Manually prune old snapshots (more aggressive)
restic forget --repo D:\backups\workspace_restic --keep-hourly 12 --keep-daily 3 --prune
```

### Backup Taking Too Long

Consider adding more exclusions in `backup-workspace.ps1` or running less frequently.

## Security Notes

- **All passwords stored in 1Password** (no hardcoded secrets in scripts)
- 1Password CLI retrieves passwords securely at runtime
- Restic repositories are encrypted at rest (AES-256)
- Backup scripts automatically retrieve password from 1Password
- No passwords stored in environment variables or files
- Sensitive files (`.env`, `*.key`) are excluded from backups

## Migration from BabyNAS Backup

If you previously used the BabyNAS-only backup:

1. The old repository at `D:\backups\baby_nas_restic` is preserved
2. A new repository at `D:\backups\workspace_restic` is used
3. Old scheduled task `BabyNAS-Restic-Backup` is removed when running `create-backup-task.ps1`
4. New task `Workspace-Restic-Backup` covers all of D:\workspace

To remove old repository after verifying new backups work:
```powershell
Remove-Item -Recurse -Force D:\backups\baby_nas_restic
```
