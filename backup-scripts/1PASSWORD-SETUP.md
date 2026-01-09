# 1Password CLI Integration - Workspace Backup

## Overview

All Restic backup passwords are stored in **1Password** instead of hardcoded in scripts.

## 1Password Item Details

**New Item (for workspace backup):**
- **Item Name:** Workspace Restic Backup
- **Vault:** TrueNAS Infrastructure
- **Category:** Password
- **Tags:** backup, restic, workspace
- **Password:** (generate a strong password)

**Note:** You need to create this item in 1Password before the backup will work.

## How It Works

All backup scripts retrieve the Restic password from 1Password using the CLI:

```powershell
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" `
    --vault "TrueNAS Infrastructure" `
    --fields password `
    --reveal
```

## Scripts Using 1Password

The following scripts use 1Password for password retrieval:

1. **backup-wrapper.ps1** - Main scheduled task wrapper
2. **backup-workspace.ps1** - Main backup script
3. **restore-workspace.ps1** - Restore utility
4. **verify-backup-health.ps1** - Health check script
5. **get-restic-password.ps1** - Helper script

## Prerequisites

### 1Password CLI Installed
```powershell
# Check installation
op --version
# Should show: 2.31.1 or later
```

### Signed In to 1Password
```powershell
# Check sign-in status
op account list
# Should show your 1Password account
```

## Creating the 1Password Item

### Option 1: Via 1Password Desktop App
1. Open 1Password
2. Select "TrueNAS Infrastructure" vault
3. Create new Password item
4. Name: "Workspace Restic Backup"
5. Generate a strong password (24+ characters)
6. Add tags: backup, restic, workspace

### Option 2: Via 1Password CLI
```powershell
# Generate a secure password and create item
op item create --category=password --title="Workspace Restic Backup" --vault="TrueNAS Infrastructure" --generate-password=24,letters,digits,symbols
```

## Manual Password Retrieval

### Get Password
```powershell
op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
```

### Get Full Item Details
```powershell
op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure"
```

### Update Password (If Needed)
```powershell
op item edit "Workspace Restic Backup" --vault "TrueNAS Infrastructure" password="NewPassword"
```

## Benefits of 1Password Integration

1. **No Hardcoded Secrets** - Passwords are never stored in script files
2. **Centralized Management** - All passwords managed in 1Password
3. **Audit Trail** - 1Password tracks all password access
4. **Easy Rotation** - Update password in one place, all scripts use new password
5. **Secure Storage** - 1Password encryption > local environment variables

## Testing 1Password Integration

### Test Password Retrieval
```powershell
op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
```

### Test Backup
```powershell
cd D:\workspace\Baby_Nas\backup-scripts
.\backup-wrapper.ps1
```

### Test Restore
```powershell
.\restore-workspace.ps1 -DryRun
```

### Test Health Check
```powershell
.\verify-backup-health.ps1
```

All scripts should:
1. Retrieve password from 1Password
2. Run successfully without errors
3. NOT prompt for password

## Scheduled Task Integration

The scheduled task **Workspace-Restic-Backup** uses `backup-wrapper.ps1` which:
1. Sets Restic in PATH
2. Retrieves password from 1Password
3. Calls main backup script
4. Returns exit code

## Troubleshooting

### Error: "1Password CLI returned error code"

**Cause:** Not signed in to 1Password

**Fix:**
```powershell
# Sign in to 1Password
op signin
```

### Error: "item not found"

**Cause:** The 1Password item doesn't exist yet

**Fix:** Create the item (see "Creating the 1Password Item" above)

### Error: "restic.exe not found in PATH"

**Cause:** Restic not in system PATH

**Fix:** Script now adds `C:\Tools\restic` to PATH automatically

### Error: "vault query must be provided"

**Cause:** Missing vault parameter

**Fix:** Always specify `--vault "TrueNAS Infrastructure"`

### Test 1Password Access
```powershell
# This should return the password
op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
```

## Security Notes

- 1Password session stays active based on your 1Password settings
- Running as SYSTEM account requires 1Password CLI accessible to SYSTEM
- Consider using 1Password Service Account for automation (if needed)
- Never commit the password to git
- Scripts automatically handle password retrieval errors

## Emergency Password Access

If 1Password is unavailable, you can temporarily set the password:

```powershell
# Temporary - for emergency use only
# Get password from 1Password desktop app first
$env:RESTIC_PASSWORD = "your-password-here"
restic snapshots --repo D:\backups\workspace_restic
```

## Files Using 1Password

```
backup-scripts/
    backup-wrapper.ps1           Retrieves from 1Password
    backup-workspace.ps1         Main backup (uses env var from wrapper)
    restore-workspace.ps1        Retrieves from 1Password
    verify-backup-health.ps1     Retrieves from 1Password
    get-restic-password.ps1      Helper script for password retrieval
    1PASSWORD-SETUP.md           This file
```

## Secure Password Handling

**Before (Insecure):**
```powershell
$env:RESTIC_PASSWORD = "hardcoded-password-here"
```

**After (Secure):**
```powershell
$env:RESTIC_PASSWORD = & op item get "Workspace Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
```

## Migration from BabyNAS Backup

The old 1Password item "BabyNAS Restic Backup" is preserved for the old repository.

| Old | New |
|-----|-----|
| BabyNAS Restic Backup | Workspace Restic Backup |
| D:\backups\baby_nas_restic | D:\backups\workspace_restic |

You can keep both items if you need to access old backups.

---

**1Password Integration Updated:** 2026-01-08
**1Password CLI Version:** 2.31.1
**Backup Scope:** D:\workspace (full workspace)
