# Veeam Enhanced Deployment - Quick Start Guide

## 5-Minute Setup

### Step 1: Download Veeam (Optional - 2 minutes)
1. Visit: https://www.veeam.com/windows-endpoint-server-backup-free.html
2. Register (free account)
3. Download Veeam Agent for Windows
4. Save to D:\ISOs\ (or script will auto-detect in Downloads)

### Step 2: Run Enhanced Deployment (3 minutes to start, 30-60 minutes total)
```powershell
# Open PowerShell as Administrator
cd D:\workspace\True_Nas\windows-scripts\veeam

# Run enhanced deployment (RECOMMENDED)
.\DEPLOY-VEEAM-ENHANCED.ps1
```

### Step 3: Follow Prompts
The script will:
- Auto-detect Veeam installer in D:\ISOs\
- Prompt for TrueNAS SMB password (uppercut%$##)
- Mount network shares automatically
- Configure workspace and WSL backups
- Guide you through Veeam UI setup

### Step 4: Verify
```powershell
# Check status with enhanced monitoring
.\MONITOR-VEEAM-ENHANCED.ps1
```

---

## One-Liner Deployment

```powershell
# Enhanced deployment with credentials (Administrator PowerShell)
cd D:\workspace\True_Nas\windows-scripts\veeam
$password = ConvertTo-SecureString "uppercut%$##" -AsPlainText -Force
.\DEPLOY-VEEAM-ENHANCED.ps1 -Unattended $true -SmbPassword $password
```

---

## What Gets Configured

✅ **Veeam Agent Installed**
- FREE edition
- Silent installation from D:\ISOs\
- All services running
- Configuration: MANUAL (Veeam UI)

✅ **Full System Backup**
- Drives: C: and D:
- Destination: \\baby.isn.biz\Veeam
- Schedule: Daily at 1:00 AM
- Retention: 7 restore points
- Configuration: MANUAL (Veeam UI)

✅ **Workspace Hourly Sync** (NEW)
- Source: D:\workspace
- Destination: \\baby.isn.biz\WindowsBackup\d-workspace
- Schedule: Hourly
- Retention: 30 days
- Configuration: AUTOMATED

✅ **WSL Daily Backup** (NEW)
- Source: All WSL distributions
- Destination: \\baby.isn.biz\WindowsBackup\wsl
- Schedule: Daily at 2:00 AM
- Retention: 14 days
- Configuration: AUTOMATED

✅ **Network Share Mounting**
- Auto-mounts all backup destinations
- Credential management
- Write access verification

✅ **Monitoring & Reporting**
- HTML status reports
- JSON status files
- Email alerts (optional)
- Automated health checks

---

## Default Configuration

| Setting | Value |
|---------|-------|
| **Backup Time** | 02:00 AM daily |
| **Drives** | C: and D: |
| **Retention** | 7 restore points (~1 week) |
| **Destination** | \\\\172.21.203.18\\Veeam |
| **Compression** | Optimal |
| **Encryption** | Disabled (can enable) |
| **App-Aware** | Enabled (VSS) |

---

## Common Customizations

### Change Backup Drives
```powershell
.\2-configure-backup-jobs.ps1 -BackupDrives "C:","D:","E:"
```

### Change Retention
```powershell
.\2-configure-backup-jobs.ps1 -RetentionPoints 14  # 2 weeks
```

### Change Schedule
```powershell
.\2-configure-backup-jobs.ps1 -ScheduleTime "01:00"  # 1 AM
```

### Enable Encryption
```powershell
.\2-configure-backup-jobs.ps1 -EnableEncryption $true -EncryptionPassword "YourPassword"
```

---

## Verification Checklist

After deployment, verify:

- [ ] Veeam service running: `Get-Service VeeamEndpointBackupSvc`
- [ ] Can access share: `Test-Path \\172.21.203.18\Veeam`
- [ ] Backup job exists: Open Veeam Control Panel
- [ ] Test backup runs: Run immediate backup in Veeam UI
- [ ] Files created: Check `\\172.21.203.18\Veeam` for .vbk files
- [ ] Monitoring works: `.\4-monitor-backup-jobs.ps1`

---

## Troubleshooting

### Can't Find Installer
Place Veeam installer in:
- `C:\Users\[Username]\Downloads\`
- `D:\Downloads\`
- Or specify: `.\1-install-veeam-agent.ps1 -InstallerPath "PATH"`

### Can't Access TrueNAS
```powershell
# Test connection
Test-Connection 172.21.203.18

# Test SMB
Test-NetConnection -ComputerName 172.21.203.18 -Port 445

# Map manually
net use \\172.21.203.18\Veeam /user:USERNAME PASSWORD
```

### Backup Job Not Running
1. Open Veeam Control Panel: `control.exe /name Veeam.EndpointBackup`
2. Check job schedule
3. Run backup manually
4. Check logs: `C:\ProgramData\Veeam\Endpoint\Logs\`

---

## Next Steps

After initial setup:

1. **Run Test Backup** (5 minutes)
   - Open Veeam Control Panel
   - Click "Backup Now"
   - Wait for completion

2. **Test Recovery** (10 minutes)
   ```powershell
   .\5-test-recovery.ps1
   ```

3. **Setup Monitoring** (5 minutes)
   ```powershell
   .\4-monitor-backup-jobs.ps1 -CheckInterval 60  # Check hourly
   ```

4. **Schedule Regular Tests** (Monthly)
   - Add calendar reminder
   - Test file restore monthly
   - Test volume restore quarterly

---

## Support

- **Logs**: `C:\Logs\Veeam\`
- **Documentation**: `README.md` (full details)
- **Veeam Help**: https://helpcenter.veeam.com/

---

## Quick Reference

```powershell
# Complete deployment
.\0-DEPLOY-VEEAM-COMPLETE.ps1

# Install only
.\1-install-veeam-agent.ps1

# Setup repository only
.\3-setup-truenas-repository.ps1

# Configure backup only
.\2-configure-backup-jobs.ps1

# Check status
.\4-monitor-backup-jobs.ps1

# Test recovery
.\5-test-recovery.ps1

# Check integration
.\6-integration-replication.ps1
```

---

**Estimated Total Time:** 30-40 minutes for complete setup
**Difficulty:** Beginner-friendly (mostly automated)
**Prerequisites:** Administrator access, TrueNAS running, Network connectivity
