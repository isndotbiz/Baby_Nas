# Workspace Restic Backup Setup - COMPLETE

## Setup Summary

Restic automated backup system is now configured to backup **all of D:\workspace**.

**1Password Integration:** All passwords stored securely in 1Password CLI (no hardcoded secrets)

**Status:** ACTIVE - Backups working!
**Repository:** D:\backups\workspace_restic
**Source:** D:\workspace (entire workspace directory)
**Current Snapshots:** 2
**Repository Size:** ~5 GB (after deduplication)

## Critical Information

### Repository Password

**Stored in 1Password:**
- **Item Name:** Workspace Restic Backup
- **Item ID:** ptsuruniijiwlu6ve6vpmgctba
- **Vault:** TrueNAS Infrastructure
- **Password:** (auto-generated, stored securely in 1Password)

**IMPORTANT:** Password is required to access backups!
- Without this password, backups are irrecoverably lost
- Password must be securely stored in 1Password (NOT hardcoded in scripts)
- All scripts automatically retrieve password from 1Password

## Setup Steps

### Step 1: Create 1Password Entry

```powershell
# Create a new password item in 1Password
# Item Name: "Workspace Restic Backup"
# Vault: "TrueNAS Infrastructure"
# Generate a strong password (24+ characters recommended)
```

Or via CLI:
```powershell
op item create --category=password --title="Workspace Restic Backup" --vault="TrueNAS Infrastructure" password="YOUR-SECURE-PASSWORD-HERE"
```

### Step 2: Initialize Repository

```powershell
# Create backup directory
New-Item -ItemType Directory -Path "D:\backups\workspace_restic" -Force

# Set password from 1Password
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal

# Initialize repository
restic init --repo D:\backups\workspace_restic
```

### Step 3: Test First Backup

```powershell
cd D:\workspace\Baby_Nas\backup-scripts
.\backup-wrapper.ps1
```

### Step 4: Create Scheduled Task

```powershell
# Run as Administrator
.\create-backup-task.ps1
```

## Excluded Patterns

The backup automatically excludes development artifacts:

| Category | Patterns |
|----------|----------|
| Version Control | `.git`, `.svn`, `.hg` |
| Node.js | `node_modules`, `.npm`, `.yarn`, `.pnpm-store` |
| Python | `__pycache__`, `.venv`, `venv`, `*.pyc`, `.tox` |
| Build Outputs | `bin`, `obj`, `dist`, `out`, `target`, `build` |
| IDE Files | `.idea`, `.vs`, `.vscode/settings.json` |
| Cache/Temp | `.cache`, `.next`, `.nuxt`, `*.tmp`, `*.log` |
| Large Binaries | `*.iso`, `*.vhdx`, `*.vmdk` |
| AI Models | `*.gguf`, `*.safetensors`, `*.pt`, `*.onnx` |
| Secrets | `.env`, `*.pem`, `*.key` |

See `backup-workspace.ps1` for the complete list.

## Installation Details

- **Restic Version:** 0.18.1
- **Installation Path:** C:\Tools\restic\restic.exe
- **Added to System PATH:** Yes
- **Repository Location:** D:\backups\workspace_restic

## Scheduled Task

- **Task Name:** Workspace-Restic-Backup
- **Schedule:** Every 30 minutes, indefinitely
- **Runs as:** SYSTEM account
- **Status:** Run create-backup-task.ps1 as Administrator to enable

## Retention Policy

Snapshots are automatically pruned according to this policy:
- **Hourly:** Keep last 24 (1 day)
- **Daily:** Keep last 7 (1 week)
- **Weekly:** Keep last 4 (4 weeks)
- **Monthly:** Keep last 6 (6 months)

## Common Operations

### List Snapshots
```powershell
cd D:\workspace\Baby_Nas\backup-scripts
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
restic snapshots --repo D:\backups\workspace_restic --tag automated
```

### Restore Latest Snapshot
```powershell
cd D:\workspace\Baby_Nas\backup-scripts
.\restore-workspace.ps1
# Files will be restored to D:\workspace_RESTORE
```

### Restore Specific Snapshot
```powershell
.\restore-workspace.ps1 -SnapshotId e1a0cbab
```

### Check Backup Health
```powershell
.\verify-backup-health.ps1
```

### Manual Backup (Test)
```powershell
Start-ScheduledTask -TaskName "Workspace-Restic-Backup"
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
Get-ScheduledTask -TaskName "Workspace-Restic-Backup" | Get-ScheduledTaskInfo
```

### Disable Backups (Temporary)
```powershell
Disable-ScheduledTask -TaskName "Workspace-Restic-Backup"
```

### Enable Backups
```powershell
Enable-ScheduledTask -TaskName "Workspace-Restic-Backup"
```

### Remove Task (Permanent)
```powershell
Unregister-ScheduledTask -TaskName "Workspace-Restic-Backup" -Confirm:$false
```

## Monitoring

### Check Disk Space
```powershell
# Check repository size
$repoSize = (Get-ChildItem D:\backups\workspace_restic -Recurse -File |
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

$successful = ($logs | Select-String "=== Workspace Backup Completed Successfully ===").Count
Write-Host "Successful backups (last 24h): $successful"
```

## Troubleshooting

### Backup Fails - Password Error
If you see "wrong password or no key found":
1. Verify 1Password CLI is signed in: `op account list`
2. Test password retrieval: `op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal`
3. Verify repository exists at D:\backups\workspace_restic

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

Based on typical workspace sizes (with exclusions applied):

| Workspace Size | First Backup | 1 Week | 1 Month |
|----------------|--------------|--------|---------|
| 10 GB | ~10 GB | ~15 GB | ~25 GB |
| 50 GB | ~50 GB | ~75 GB | ~125 GB |
| 100 GB | ~100 GB | ~150 GB | ~250 GB |

Note: Restic deduplication typically reduces storage by 50-80%.

## Files Created

```
D:\workspace\Baby_Nas\backup-scripts\
    backup-workspace.ps1          Main backup script (full workspace)
    backup-wrapper.ps1            Wrapper that retrieves password from 1Password
    restore-workspace.ps1         Restore utility (uses 1Password)
    verify-backup-health.ps1      Health check script (uses 1Password)
    create-backup-task.ps1        Task scheduler setup
    get-restic-password.ps1       Helper to retrieve password from 1Password
    README.md                     Usage documentation
    SETUP-COMPLETE.md             This file
    1PASSWORD-SETUP.md            1Password integration documentation
    logs\                         Backup logs (auto-cleaned after 30 days)

D:\backups\workspace_restic\      Restic repository (encrypted, initialized)
C:\Tools\restic\restic.exe        Restic binary

1Password:
  Item: Workspace Restic Backup   (created)
  Vault: TrueNAS Infrastructure
```

## Migration Notes

This setup replaces the previous BabyNAS-only backup:

| Old | New |
|-----|-----|
| D:\workspace\baby_nas | D:\workspace (entire workspace) |
| D:\backups\baby_nas_restic | D:\backups\workspace_restic |
| BabyNAS-Restic-Backup task | Workspace-Restic-Backup task |
| "BabyNAS Restic Backup" 1Password | "Workspace Restic Backup" 1Password |

The old repository is preserved at `D:\backups\baby_nas_restic` and can be removed after verifying the new backups work correctly.

## Security Notes

- **No Hardcoded Passwords** - All passwords stored in 1Password
- Repository is encrypted with AES-256
- Password required for all operations (backup, restore, check)
- Backups run as SYSTEM account (highest privileges)
- Scripts automatically retrieve password from 1Password at runtime
- 1Password provides audit trail of all password access
- Sensitive files (`.env`, credentials) excluded from backups

---

**Setup Date:** 2026-01-08
**Restic version:** 0.18.1
**System:** DESKTOP-RYZ3900 (Windows)
**Scope:** D:\workspace (full workspace)
**Backup Size:** ~19 GB (with exclusions, from ~234 GB workspace)
**Repository Size:** ~5 GB (after deduplication/compression)
