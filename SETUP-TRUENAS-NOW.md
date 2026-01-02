# Baby NAS Setup Guide - Quick Start

## 🎯 Found Your Baby NAS!

**IP Address:** `172.31.69.40`
**Status:** Online ✅ (HTTPS enabled, SSH disabled)

---

## Step 1: Change Password & Enable SSH

### Open Web UI
```powershell
start https://172.31.69.40
```

### Login
- **Username:** `root`
- **Current Password:** `uppercut%$##` (old password - we'll change this!)

### Change Password (CRITICAL!)
1. Navigate to: **Accounts** → **Users**
2. Click on **root** user
3. Click **Edit**
4. Set new password: `n=I-PT:x>FU!}gjMPN/AM[D8`
5. Click **Save**

### Enable SSH
1. Navigate to: **System** → **Services**
2. Find **SSH** service
3. Click the **pencil icon** (edit)
4. Check these settings:
   - ✅ **Allow Password Authentication** (for initial setup)
   - ✅ **Allow TCP Port Forwarding**
   - ✅ **Log in as Root with Password**
5. Click **Save**
6. Toggle the **SSH** service to **Running** (click the slider)

---

## Step 2: Create API Key

1. Navigate to: **System** → **API Keys**
2. Click **Add**
3. Configure:
   - **Name:** `windows-automation`
   - **Username:** Select `root`
4. Click **Add**
5. **IMPORTANT:** Copy the API key shown (you'll only see it once!)
6. Add it to your `.env` file:

```powershell
# Open .env file
notepad D:\workspace\Baby_Nas\.env

# Add this line (replace YOUR-API-KEY with actual key):
TRUENAS_API_KEY=YOUR-API-KEY-HERE
```

---

## Step 3: Test Connection

After completing steps 1 & 2, run this script to test everything:

```powershell
cd D:\workspace\Baby_Nas
.\test-truenas-connection.ps1
```

---

## Current Status

✅ **Found IP:** 172.31.69.40
✅ **Updated .env:** IP changed from 172.21.203.18 to 172.31.69.40
✅ **Network Test:** Baby NAS responding to ping
⏳ **Waiting:** Password change + SSH enable + API key

---

## Quick Reference

### Your Credentials
```
OLD Password: uppercut%$##
NEW Password: n=I-PT:x>FU!}gjMPN/AM[D8
```

### Connection Info
```
Web UI:  https://172.31.69.40
SSH:     ssh root@172.31.69.40
```

### After Setup - Available Commands
```powershell
# Test connection
.\test-baby-nas-complete.ps1

# Setup snapshots
.\setup-snapshots-auto.ps1

# Backup workspace
.\backup-workspace.ps1

# Monitor status
.\monitor-baby-nas.ps1
```

---

**Let me know when you've completed Steps 1 & 2, and I'll continue with automated SSH key setup and API configuration!**
