# Backup System Deployment Suite

**Complete production-ready backup deployment system for Baby NAS (172.21.203.18) and Bare Metal (10.0.0.89)**

---

## Getting Started (5 Minutes)

### Option 1: Automated Complete Deployment (Recommended)

```powershell
# Run as Administrator
cd D:\workspace\True_Nas\windows-scripts
.\AUTOMATED-BACKUP-SETUP.ps1
```

This interactive script will:
1. Validate prerequisites
2. Guide you through configuration
3. Deploy Veeam Agent
4. Deploy phone backup infrastructure
5. Provide Time Machine instructions
6. Verify all systems
7. Generate comprehensive report

**Time Required:** 10-20 minutes

### Option 2: Deploy Individual Systems

```powershell
# Deploy Veeam only
.\DEPLOY-VEEAM-COMPLETE.ps1

# Deploy phone backups only
.\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1

# Time Machine (run on Mac)
./DEPLOY-TIME-MACHINE-MAC.sh

# Verify everything works
.\VERIFY-ALL-BACKUPS.ps1
```

### Option 3: View Documentation First

Start with one of these documents:
- **QUICK-REFERENCE-BACKUP-DEPLOYMENT.txt** - Fast lookup guide
- **BACKUP-DEPLOYMENT-GUIDE.md** - Complete detailed guide
- **BACKUP-DEPLOYMENT-SUMMARY.md** - Executive overview

---

## What Gets Deployed

### 1. Veeam Agent for Windows
- **What:** Windows system backup software
- **When:** Daily at 1:00 AM
- **Where:** \\baby.isn.biz\Veeam (2.5 TB)
- **Keeps:** 7 days of backups
- **Time to Deploy:** 5-10 minutes

### 2. Phone Backup Infrastructure
- **What:** SMB share for mobile device backups
- **Devices:** Galaxy S24, iPhone, iPad, etc.
- **Where:** \\baby.isn.biz\PhoneBackups (500 GB)
- **Frequency:** Per-app configured (typically hourly/daily)
- **Time to Deploy:** 2-5 minutes

### 3. Time Machine for Mac
- **What:** Automated macOS system backup
- **When:** Every hour (configurable)
- **Where:** \\baremetal.isn.biz\TimeMachine (5 TB)
- **Frequency:** Hourly backups
- **Time to Deploy:** 5-10 minutes

---

## Prerequisites

### For All Systems
- Administrator privileges
- Network access to backup servers
- VPN connection (if remote)

### For Veeam (Windows)
- Windows 10/11 or Server 2016+
- PowerShell 5.0+
- 10 GB free disk space

### For Phone Backups (Windows)
- Windows 10/11 or Server 2016+
- PowerShell 5.0+
- Available drive letters (X, Y, Z)

### For Time Machine (macOS)
- macOS 10.7+
- Network access to 10.0.0.89
- Administrator/sudo privileges

---

## Files Included

### Deployment Scripts

| File | Purpose | Lines | Time |
|------|---------|-------|------|
| **DEPLOY-VEEAM-COMPLETE.ps1** | Veeam installation & config | 600+ | 5-10 min |
| **DEPLOY-PHONE-BACKUPS-WINDOWS.ps1** | Phone backup setup | 500+ | 2-5 min |
| **DEPLOY-TIME-MACHINE-MAC.sh** | Mac Time Machine config | 500+ | 5-10 min |
| **VERIFY-ALL-BACKUPS.ps1** | System verification | 450+ | 2-3 min |
| **AUTOMATED-BACKUP-SETUP.ps1** | Master orchestration | 700+ | 10-20 min |

### Documentation

| File | Purpose | Size |
|------|---------|------|
| **BACKUP-DEPLOYMENT-GUIDE.md** | Complete how-to guide | 3000+ lines |
| **QUICK-REFERENCE-BACKUP-DEPLOYMENT.txt** | Fast lookup card | 500+ lines |
| **BACKUP-DEPLOYMENT-SUMMARY.md** | Executive summary | 400+ lines |
| **README-BACKUP-DEPLOYMENT.md** | This file | Start here |

---

## Quick Command Reference

### Windows PowerShell

```powershell
# Automated complete setup (interactive)
.\AUTOMATED-BACKUP-SETUP.ps1

# Silent deployment (no prompts)
.\AUTOMATED-BACKUP-SETUP.ps1 -NoGUI

# Deploy specific system
.\DEPLOY-VEEAM-COMPLETE.ps1
.\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1
.\VERIFY-ALL-BACKUPS.ps1

# With custom parameters
.\DEPLOY-VEEAM-COMPLETE.ps1 -BackupDrives "C:","D:","E:" -RetentionDays 14
.\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1 -QuotaGB 1000
```

### macOS Bash

```bash
# Make executable
chmod +x DEPLOY-TIME-MACHINE-MAC.sh

# Run deployment
./DEPLOY-TIME-MACHINE-MAC.sh

# Check Time Machine status
tmutil status
mount | grep TimeMachine
```

### Network Testing

```powershell
# Test connectivity
ping 172.21.203.18  # Baby NAS
ping 10.0.0.89      # Bare Metal
Test-NetConnection -ComputerName baby.isn.biz -Port 445
```

---

## Network Configuration

### Addresses
- **Baby NAS:** 172.21.203.18 (baby.isn.biz)
- **Bare Metal:** 10.0.0.89 (baremetal.isn.biz)

### SMB Shares
- **Veeam:** \\baby.isn.biz\Veeam (2.5 TB)
- **Phone:** \\baby.isn.biz\PhoneBackups (500 GB)
- **Time Machine:** \\baremetal.isn.biz\TimeMachine (5 TB)

### Firewall
- Port 445 (SMB3) - Primary
- Port 139 (SMB) - Legacy (optional)

---

## Expected Output Examples

### Successful Veeam Deployment
```
[2024-12-10 10:30:15] [INFO] Starting Veeam deployment
[2024-12-10 10:30:16] [SUCCESS] Veeam Agent service found: Running
[2024-12-10 10:30:17] [SUCCESS] Network connectivity OK
[2024-12-10 10:30:20] [SUCCESS] SMB share access verified
[2024-12-10 10:30:22] [SUCCESS] Creating Veeam backup job

Veeam Installation: ✓ OK
Network Connectivity: ✓ OK
SMB Share Access: ✓ OK
Backup Job Configuration: ✓ AUTOMATED

Log file: C:\Logs\VEEAM-DEPLOYMENT-20241210-103015.log
Report file: C:\Logs\VEEAM-DEPLOYMENT-Report-20241210-103015.html
```

### Successful Phone Backup Deployment
```
[2024-12-10 10:35:20] [SUCCESS] Connectivity OK
[2024-12-10 10:35:23] [SUCCESS] SMB share mounted: X:
[2024-12-10 10:35:25] [SUCCESS] Write permissions verified
[2024-12-10 10:35:28] [SUCCESS] Device folders created (5)

Network Connectivity: ✓ OK
SMB Share Access: ✓ OK (X:)
Device Folders: ✓ Galaxy-S24, iPhone, iPad, etc.
Available Space: 462 GB / 500 GB
```

### Successful Verification
```
[2024-12-10 11:00:16] [SUCCESS] Baby NAS is reachable
[2024-12-10 11:00:20] [SUCCESS] Veeam service status: Running
[2024-12-10 11:00:22] [SUCCESS] Veeam share is accessible
[2024-12-10 11:00:25] [SUCCESS] Phone Backups share accessible

Baby NAS (172.21.203.18): ✓ OK
Bare Metal (10.0.0.89): ✓ OK
Veeam Service: ✓ RUNNING
Phone Backups: ✓ OK
```

---

## Troubleshooting

### Network Not Accessible
```powershell
# Test connectivity
ping 172.21.203.18
Test-NetConnection -ComputerName baby.isn.biz -Port 445

# Clear old connections
net use * /delete /yes
```

### SMB Share Permission Issues
- Verify TrueNAS share permissions
- Ensure user has read/write access
- Check firewall allows port 445

### Veeam Not Running
```powershell
Get-Service VeeamEndpointBackupSvc
Start-Service VeeamEndpointBackupSvc
```

### Time Machine Issues
```bash
mount | grep TimeMachine  # Check mount
tmutil status             # Check backup status
./DEPLOY-TIME-MACHINE-MAC.sh  # Reconfigure
```

**Full troubleshooting guide:** See BACKUP-DEPLOYMENT-GUIDE.md

---

## Support Documents

### For Quick Answers
- **QUICK-REFERENCE-BACKUP-DEPLOYMENT.txt** - Fast lookup commands

### For Complete Information
- **BACKUP-DEPLOYMENT-GUIDE.md** - Comprehensive guide with:
  - Detailed system requirements
  - Complete script documentation
  - Parameter references
  - Network configuration
  - Troubleshooting procedures
  - Emergency recovery steps
  - Performance optimization
  - Maintenance schedule

### For Executives
- **BACKUP-DEPLOYMENT-SUMMARY.md** - Executive overview including:
  - Deliverables summary
  - Architecture overview
  - Key features
  - Timeline and effort
  - Support and resources

---

## Maintenance

### Daily
- Monitor backup completion

### Weekly
```powershell
.\VERIFY-ALL-BACKUPS.ps1
```

### Monthly
- Test file restoration
- Review logs
- Check storage usage

### Quarterly
- Full system backup test
- Update documentation

### Annually
- Disaster recovery drill
- Verify recovery procedures

---

## Log Files

### Windows
```
C:\Logs\
├── VEEAM-DEPLOYMENT-*.log
├── PHONE-BACKUPS-DEPLOYMENT-*.log
├── BACKUP-VERIFICATION-*.log
├── AUTOMATED-BACKUP-SETUP-*.log
└── (multiple HTML reports)
```

### macOS
```
~/Library/Logs/
├── DEPLOY-TIME-MACHINE-MAC-*.log
└── (text reports)
```

---

## Next Steps

### Right Now
1. Read this file (you're doing it!)
2. Check QUICK-REFERENCE-BACKUP-DEPLOYMENT.txt

### Within 1 Hour
1. Review network configuration
2. Prepare SMB credentials
3. Run AUTOMATED-BACKUP-SETUP.ps1

### Within 1 Week
1. Verify all systems operational
2. Test backup restoration
3. Document any customizations
4. Review logs for issues

### Ongoing
1. Monitor backups daily
2. Run VERIFY-ALL-BACKUPS.ps1 weekly
3. Test restoration monthly
4. Schedule annual disaster recovery drill

---

## Common Tasks

### Check Backup Status
```powershell
# Veeam backups
Get-EventLog -LogName Application -Source "*Veeam*" -Newest 5

# Phone backups
dir "X:\PhoneBackups\*" -Recurse | Measure-Object -Property Length -Sum

# Time Machine (on Mac)
tmutil status
```

### Restart Backup Service
```powershell
# Veeam
Stop-Service VeeamEndpointBackupSvc
Start-Service VeeamEndpointBackupSvc

# SMB
net stop LanmanServer
net start LanmanServer
```

### Check Available Space
```powershell
# Baby NAS shares
Get-Volume
dir "\\baby.isn.biz\Veeam"
dir "\\baby.isn.biz\PhoneBackups"

# Bare Metal share (on Mac)
df /Volumes/TimeMachine-Backup
```

---

## FAQ

**Q: How long does the complete setup take?**
A: 10-20 minutes for all systems (excluding Mac manual configuration)

**Q: Can I run scripts remotely?**
A: Yes, with appropriate PowerShell remoting configured

**Q: What if I only want one backup system?**
A: Run individual scripts - no dependencies between systems

**Q: Can I change the backup schedule?**
A: Yes - modify parameters or configure manually in Veeam

**Q: How much space do I need?**
A: Veeam: 2.5 TB, Phone: 500 GB, Time Machine: 5 TB

**Q: What if deployment fails?**
A: Check logs (C:\Logs\), review troubleshooting guide, re-run script

**Q: How often should I test restores?**
A: At least monthly for critical systems, quarterly for others

**Q: Who should have access to backups?**
A: Restrict to authorized administrators only

**Full FAQ:** See BACKUP-DEPLOYMENT-GUIDE.md

---

## Contact & Support

### Documentation
- All docs in this directory
- Inline help in each script (use `Get-Help script-name.ps1`)

### External Resources
- **Veeam:** https://www.veeam.com
- **TrueNAS:** https://www.truenas.com
- **Time Machine:** https://support.apple.com/en-us/108958

### Emergency
- Check logs: `C:\Logs\`
- Review troubleshooting: BACKUP-DEPLOYMENT-GUIDE.md
- Re-run deployment script: AUTOMATED-BACKUP-SETUP.ps1

---

## Version Information

**Deployment Suite Version:** 1.0
**Created:** 2024-12-10
**Status:** Production Ready
**Location:** D:\workspace\True_Nas\windows-scripts\

All scripts tested and ready for immediate deployment.

---

## Start Here

1. **First time?** → Read this file (README)
2. **Need quick help?** → QUICK-REFERENCE-BACKUP-DEPLOYMENT.txt
3. **Want details?** → BACKUP-DEPLOYMENT-GUIDE.md
4. **Ready to deploy?** → Run AUTOMATED-BACKUP-SETUP.ps1
5. **Having issues?** → Check BACKUP-DEPLOYMENT-GUIDE.md troubleshooting section

---

**Let's get your backups running!**

```powershell
cd D:\workspace\True_Nas\windows-scripts
.\AUTOMATED-BACKUP-SETUP.ps1
```

Good luck! 🚀
