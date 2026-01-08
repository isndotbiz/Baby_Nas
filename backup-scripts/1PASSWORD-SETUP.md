# 1Password CLI Integration - Setup Complete

## Overview

All Restic backup passwords are now stored in **1Password** instead of hardcoded in scripts.

## 1Password Item Details

- **Item Name:** BabyNAS Restic Backup
- **Item ID:** lnlllusdtcha2jczvzglf5qzji
- **Vault:** TrueNAS Infrastructure
- **Category:** Password
- **Tags:** backup, restic, baby-nas
- **Password:** `BabyNAS-Restic-2026-SecureBackup!`

## How It Works

All backup scripts now retrieve the Restic password from 1Password using the CLI:

```powershell
$env:RESTIC_PASSWORD = & op item get "BabyNAS Restic Backup" `
    --vault "TrueNAS Infrastructure" `
    --fields password `
    --reveal
```

## Scripts Updated

The following scripts now use 1Password:

1. **backup-wrapper.ps1** - Main scheduled task wrapper
2. **restore-baby-nas.ps1** - Restore utility
3. **verify-backup-health.ps1** - Health check script

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
# Should show: my.1password.com, admin@isn.biz
```

## Manual Password Retrieval

### Get Password
```powershell
op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
```

### Get Full Item Details
```powershell
op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure"
```

### Update Password (If Needed)
```powershell
op item edit "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" password="NewPassword"
```

## Benefits of 1Password Integration

1. **No Hardcoded Secrets** - Passwords are never stored in script files
2. **Centralized Management** - All passwords managed in 1Password
3. **Audit Trail** - 1Password tracks all password access
4. **Easy Rotation** - Update password in one place, all scripts use new password
5. **Secure Storage** - 1Password encryption > local environment variables

## Testing 1Password Integration

### Test Backup
```powershell
cd D:\workspace\baby_nas\backup-scripts
.\backup-wrapper.ps1
```

### Test Restore
```powershell
.\restore-baby-nas.ps1
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

The scheduled task **BabyNAS-Restic-Backup** uses `backup-wrapper.ps1` which:
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

### Error: "restic.exe not found in PATH"

**Cause:** Restic not in system PATH

**Fix:** Script now adds `C:\Tools\restic` to PATH automatically

### Error: "vault query must be provided"

**Cause:** Missing vault parameter

**Fix:** Always specify `--vault "TrueNAS Infrastructure"`

### Test 1Password Access
```powershell
# This should return the password
op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
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
$env:RESTIC_PASSWORD = "BabyNAS-Restic-2026-SecureBackup!"
restic snapshots --repo D:\backups\baby_nas_restic
```

## Files Modified

```
backup-scripts/
├── backup-wrapper.ps1           Now retrieves from 1Password
├── restore-baby-nas.ps1         Now retrieves from 1Password
├── verify-backup-health.ps1     Now retrieves from 1Password
├── get-restic-password.ps1      NEW: Helper script for password retrieval
└── 1PASSWORD-SETUP.md           This file
```

## No Hardcoded Passwords

**Before (Insecure):**
```powershell
$env:RESTIC_PASSWORD = "BabyNAS-Restic-2026-SecureBackup!"
```

**After (Secure):**
```powershell
$env:RESTIC_PASSWORD = & op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
```

## Backup Verification

All backups completed successfully with 1Password integration:

```
Recent snapshots:
ID        Time                 Host             Tags        Size
--------------------------------------------------------------------------------------------
e1a0cbab  2026-01-07 20:20:36  DESKTOP-RYZ3900  automated   2.712 MB
6fa1ddf1  2026-01-07 20:36:31  DESKTOP-RYZ3900  automated   2.721 MB
```

Health check: **no errors were found**

---

**1Password Integration Completed:** 2026-01-07 8:36 PM
**1Password CLI Version:** 2.31.1
**All Scripts Tested:** PASS ✓
