# Workspace Sync to Baby NAS

Automated synchronization of `D:\workspace` to Baby NAS using robocopy.

## Overview

| Setting | Value |
|---------|-------|
| Source | `D:\workspace` |
| Destination | `W:\` (`\\10.0.0.88\workspace`) |
| Baby NAS IP | 10.0.0.88 |
| SMB User | smbuser (password in 1Password) |
| Default Interval | Every 60 minutes |
| Mode | Copy (preserves destination extras) |

## Quick Start

### Manual Sync (On-Demand)

```powershell
# Navigate to scripts directory
cd D:\workspace\Baby_Nas\backup-scripts

# Run sync (preview first)
.\sync-now.ps1 -DryRun

# Run actual sync
.\sync-now.ps1

# Mirror sync (deletes extras on NAS - use carefully!)
.\sync-now.ps1 -Mirror
```

### Enable Automated Sync

Run as Administrator:

```powershell
# Create hourly sync task (default - copy mode)
.\create-sync-task.ps1

# Create sync task with custom interval (every 30 minutes)
.\create-sync-task.ps1 -IntervalMinutes 30

# Create mirror sync task (syncs deletions)
.\create-sync-task.ps1 -Mirror

# Remove scheduled task
.\create-sync-task.ps1 -Uninstall
```

## Scripts

| Script | Purpose |
|--------|---------|
| `sync-workspace-to-nas.ps1` | Main sync script with full options |
| `sync-wrapper.ps1` | Wrapper for scheduled tasks (handles credentials) |
| `sync-now.ps1` | Quick on-demand sync helper |
| `create-sync-task.ps1` | Creates/removes Windows scheduled task |

## Excluded Directories

The following directories are excluded from sync to save space and time:

- `node_modules` - NPM dependencies (reinstall with `npm install`)
- `.git` - Git repositories (large, use git push instead)
- `__pycache__` - Python bytecode cache
- `.venv` / `venv` - Python virtual environments
- `.next` - Next.js build output
- `dist` / `build` - Build artifacts
- `.cache` - Various caches

## Excluded Files

- `*.pyc`, `*.pyo` - Python compiled files
- `*.tmp`, `*.log`, `*.bak` - Temporary files
- `Thumbs.db`, `desktop.ini`, `.DS_Store` - System files

## Sync Modes

### Copy Mode (Default - Safe)

```powershell
.\sync-now.ps1
```

- Copies new and updated files to NAS
- Does NOT delete files on NAS that are missing from source
- Safe for cases where you have extra files on NAS

### Mirror Mode (Full Sync)

```powershell
.\sync-now.ps1 -Mirror
```

- Creates exact mirror of source on destination
- DELETES files on NAS that don't exist in source
- Use when you want destination to exactly match source

## Logs

Sync logs are stored in `D:\workspace\Baby_Nas\backup-scripts\logs\`:

- `sync_YYYY-MM-DD_HH-mm-ss.log` - Detailed robocopy output
- `sync_wrapper_YYYY-MM-DD_HH-mm-ss.log` - Wrapper/credential logs

Logs older than 30 days are automatically deleted.

## Troubleshooting

### W: Drive Not Accessible

1. Check if Baby NAS is online:
   ```powershell
   Test-Connection 10.0.0.88
   ```

2. Manually map the drive:
   ```powershell
   net use W: \\10.0.0.88\workspace /user:smbuser
   ```

3. Check SMB credentials in 1Password: "Baby NAS - SMB User"

### Sync Fails with Errors

Check the log files in `logs\` directory. Common issues:

- **Exit code 8+**: Some files failed to copy (permissions, in use)
- **Exit code 16**: Serious error (network, authentication)

### Scheduled Task Not Running

1. Check task status:
   ```powershell
   Get-ScheduledTaskInfo -TaskName "BabyNAS-Workspace-Sync"
   ```

2. Run manually to test:
   ```powershell
   Start-ScheduledTask -TaskName "BabyNAS-Workspace-Sync"
   ```

3. Check Task Scheduler for error details (taskschd.msc)

## Robocopy Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No files copied (already in sync) |
| 1 | Files copied successfully |
| 2 | Extra files in destination |
| 3 | Files copied + extras in destination |
| 4 | Mismatched files/directories |
| 8+ | Some errors occurred |
| 16+ | Serious/fatal error |

## Integration with Backup System

This sync complements (does not replace) the Restic backup system:

- **Restic**: Point-in-time snapshots with deduplication and retention
- **Robocopy sync**: Live mirror for quick access from other machines

Both can run independently on their own schedules.
