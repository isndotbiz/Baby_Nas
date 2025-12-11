# Baby NAS Full Automation - START HERE

## Welcome to Baby NAS Full Automation

This guide will walk you through setting up your Baby NAS completely automated from start to finish.

## Quick Start (3 Steps)

### Step 1: Open PowerShell as Administrator
```powershell
# Press Windows Key, type "PowerShell"
# Right-click "Windows PowerShell"
# Click "Run as Administrator"
```

### Step 2: Navigate to Scripts Directory
```powershell
cd D:\workspace\True_Nas\windows-scripts
```

### Step 3: Run the Automation
```powershell
.\FULL-AUTOMATION.ps1
```

**That's it!** The script will handle everything else.

---

## Alternative: Double-Click Method

1. Navigate to: `D:\workspace\True_Nas\windows-scripts\`
2. Right-click `RUN-FULL-AUTOMATION.bat`
3. Select "Run as Administrator"

---

## What Happens During Automation?

The script automatically:

```
✓ Tests connectivity to Baby NAS
✓ Uploads and executes configuration script
✓ Creates ZFS pool (RAIDZ1 + SLOG + L2ARC)
✓ Creates encrypted datasets
✓ Sets up users and permissions
✓ Configures SSH keys
✓ Sets DNS servers
✓ Runs comprehensive tests
✓ Configures replication to Main NAS
✓ Optimizes VM settings
```

**Time Required:** 20-30 minutes (mostly automated)

---

## Prerequisites Checklist

Before running automation, ensure:

- [ ] Baby NAS VM is running
- [ ] You can access Baby NAS Web UI at `https://172.21.203.18`
- [ ] SSH is enabled on Baby NAS
- [ ] You have administrator access on Windows
- [ ] You know the Baby NAS admin password (default: `uppercut%$##`)

**Not sure?** Run the troubleshooter first:
```powershell
.\troubleshoot-automation.ps1
```

---

## Enable SSH on Baby NAS (If Needed)

If SSH is not enabled:

1. Open browser to: `https://172.21.203.18`
2. Login as: `admin` / `uppercut%$##`
3. Go to: **System Settings** → **Services**
4. Find **SSH** service
5. Click the toggle to **Start**
6. Click **Save**

Then re-run the automation.

---

## Common Scenarios

### Scenario 1: Fresh Setup (First Time)
```powershell
# Default IPs, interactive mode
.\FULL-AUTOMATION.ps1
```

### Scenario 2: Different IP Addresses
```powershell
# Custom IPs
.\FULL-AUTOMATION.ps1 -BabyNasIP "192.168.1.100" -MainNasIP "192.168.1.200"
```

### Scenario 3: Main NAS Offline
```powershell
# Skip replication (can add later)
.\FULL-AUTOMATION.ps1 -SkipReplication
```

### Scenario 4: Quick Re-run (Testing)
```powershell
# Skip tests, minimal prompts
.\FULL-AUTOMATION.ps1 -SkipTests -UnattendedMode
```

---

## During Execution

### What You'll See
- Colored progress indicators (✓ success, ✗ error, ⚠ warning)
- Step-by-step status updates
- Occasional prompts for confirmation

### When You'll Be Prompted
1. **Disk Selection** - Choose which disks for pool
2. **DNS Choice** - Select DNS provider (Cloudflare, Google, Quad9)
3. **Replication** - Confirm replication setup
4. **Continue After Errors** - Choose whether to proceed

### What to Do
- Read prompts carefully
- Answer with `yes` or `no` when asked
- If unsure, choose the default option

---

## After Automation Completes

You'll see a success summary with:
- Execution time
- Configuration details
- Access information
- Next steps

### Verify Everything Works

**Test 1: SSH Access**
```powershell
ssh babynas "hostname"
```
Expected: Returns Baby NAS hostname

**Test 2: Pool Status**
```powershell
ssh babynas "zpool status tank"
```
Expected: Shows ONLINE pool with RAIDZ1

**Test 3: SMB Access**
```powershell
net use W: \\172.21.203.18\WindowsBackup /user:truenas_admin "uppercut%$##"
```
Expected: Drive W: is mapped successfully

---

## What Was Created?

### On Baby NAS
- ZFS pool `tank` (~12TB usable)
- Encrypted datasets for backups, Veeam, development
- User: `truenas_admin`
- SMB shares: WindowsBackup, Veeam, Development, Home
- Automated snapshots (hourly, daily, weekly)
- Replication scripts (to Main NAS)
- Security hardening (firewall, SSH config)

### On Windows
- SSH keys for Baby NAS and Main NAS
- SSH config for easy access
- Log files in `D:\workspace\True_Nas\logs\`

---

## Next Steps

After successful automation:

### 1. Test SMB Shares
```powershell
# Map network drive
net use W: \\172.21.203.18\WindowsBackup /user:truenas_admin "uppercut%$##"

# Create test file
echo "Test" > W:\test.txt

# Verify
dir W:
```

### 2. Deploy Veeam Backups
```powershell
.\veeam\0-DEPLOY-VEEAM-COMPLETE.ps1
```

### 3. Schedule Regular Backups
```powershell
.\schedule-backup-tasks.ps1
```

### 4. Monitor Health
```powershell
ssh babynas "/usr/local/bin/check-pool-health.sh"
```

---

## Troubleshooting

### Problem: Script Fails Early

**Solution:**
```powershell
# Run diagnostic tool
.\troubleshoot-automation.ps1

# Fix any blocking issues shown
# Then re-run automation
```

### Problem: "Cannot reach Baby NAS"

**Solutions:**
```powershell
# Check VM status
Get-VM "TrueNAS-BabyNAS"

# Start VM if stopped
Start-VM "TrueNAS-BabyNAS"

# Wait 30 seconds, then re-run
```

### Problem: "SSH service not accessible"

**Solutions:**
1. Open `https://172.21.203.18` in browser
2. Enable SSH (see "Enable SSH" section above)
3. Re-run automation

### Problem: Configuration Step Fails

**Solutions:**
```powershell
# Check Baby NAS logs
ssh admin@172.21.203.18 "journalctl -xe -n 100"

# Review error messages
# Fix specific issues
# Re-run automation
```

### Problem: Need to Start Over

**Solutions:**
```powershell
# Stop and restart VM
Stop-VM "TrueNAS-BabyNAS" -Force
Start-VM "TrueNAS-BabyNAS"

# Wait for boot (30-60 seconds)
# Re-run automation
.\FULL-AUTOMATION.ps1
```

---

## Getting Help

### View Logs
```powershell
# Find latest log
Get-ChildItem D:\workspace\True_Nas\logs\full-automation-*.log |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 |
    Get-Content -Tail 100
```

### Check Baby NAS Status
```powershell
# System logs
ssh babynas "journalctl -xe -n 50"

# ZFS status
ssh babynas "zpool status -v"

# Disk status
ssh babynas "lsblk"
```

### Review Documentation
- **Full Guide:** `FULL-AUTOMATION-README.md`
- **Quick Reference:** `FULL-AUTOMATION-QUICKREF.md`
- **Summary:** `FULL-AUTOMATION-SUMMARY.md`

---

## Advanced Options

### Unattended Mode
```powershell
# Minimal prompts, uses defaults
.\FULL-AUTOMATION.ps1 -UnattendedMode
```

### Custom Parameters
```powershell
.\FULL-AUTOMATION.ps1 `
    -BabyNasIP "192.168.1.100" `
    -MainNasIP "192.168.1.200" `
    -Username "admin" `
    -Password "MyPassword"
```

### Skip Optional Steps
```powershell
# Skip replication
.\FULL-AUTOMATION.ps1 -SkipReplication

# Skip tests
.\FULL-AUTOMATION.ps1 -SkipTests

# Skip both
.\FULL-AUTOMATION.ps1 -SkipReplication -SkipTests
```

---

## File Reference

| File | Purpose |
|------|---------|
| `FULL-AUTOMATION.ps1` | Main automation script |
| `RUN-FULL-AUTOMATION.bat` | Double-click launcher |
| `troubleshoot-automation.ps1` | Diagnostic tool |
| `FULL-AUTOMATION-README.md` | Detailed documentation |
| `FULL-AUTOMATION-QUICKREF.md` | Command reference |
| `FULL-AUTOMATION-SUMMARY.md` | Implementation details |
| `START-HERE-FULL-AUTOMATION.md` | This guide |

---

## Safety Notes

- Script can be safely re-run (idempotent operations)
- Existing configuration is preserved
- Logs are kept in `D:\workspace\True_Nas\logs\`
- No data is deleted without confirmation

---

## Ready to Begin?

### Pre-Flight Check
```powershell
# Quick diagnostic
.\troubleshoot-automation.ps1
```

### Launch Automation
```powershell
# Interactive mode (recommended first time)
.\FULL-AUTOMATION.ps1
```

---

## Success Indicators

After automation completes successfully, you should have:

✅ Baby NAS accessible via SSH: `ssh babynas`
✅ ZFS pool healthy: `zpool status tank` shows ONLINE
✅ SMB shares accessible: `\\172.21.203.18\WindowsBackup`
✅ Encryption enabled: Datasets use AES-256-GCM
✅ Automatic snapshots: Hourly, daily, weekly
✅ Replication configured: Baby NAS → Main NAS (if enabled)
✅ VM optimized: 8GB RAM, properly configured

---

## Questions?

1. **First Time?** Read this entire guide
2. **Issues?** Run `.\troubleshoot-automation.ps1`
3. **Need Details?** See `FULL-AUTOMATION-README.md`
4. **Quick Commands?** Check `FULL-AUTOMATION-QUICKREF.md`

---

## You're Ready!

The automation script is production-ready and tested. Follow the steps above and you'll have a fully configured Baby NAS in 20-30 minutes.

**Good luck!** 🚀

---

*Version 1.0 - Last Updated: 2024-12-10*
