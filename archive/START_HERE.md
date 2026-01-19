# Baby NAS Setup - START HERE

## 🚀 One-Command Setup

```powershell
# Open PowerShell as Administrator
cd D:\workspace\True_Nas\windows-scripts
.\SETUP-BABY-NAS.ps1
```

**That's it!** The master script will guide you through the entire setup process.

---

## 📋 What This Setup Does

This complete automation will:

1. ✅ **Create Hyper-V VM** with physical disk passthrough
2. ✅ **Guide TrueNAS installation** (minimal manual steps)
3. ✅ **Configure SSH access** with key-based authentication
4. ✅ **Set up ZFS pool** (RAIDZ1 + SLOG + L2ARC)
5. ✅ **Create datasets** for Windows backups, Veeam, WSL
6. ✅ **Configure SMB shares** for Windows network access
7. ✅ **Generate API keys** for programmatic management
8. ✅ **Set up replication** to Main NAS (10.0.0.89)
9. ✅ **Configure auto-start** (VM starts with Windows)
10. ✅ **Apply optimizations** (ZFS tuning, network, monitoring)

---

## 🎯 What You Get

### Baby NAS (Local VM)
- **Purpose**: Primary Windows backup target
- **Storage**: ~12TB usable (RAIDZ1 with 3x 6TB)
- **Performance**: SSD-accelerated (SLOG + L2ARC)
- **Access**: SSH, SMB, API

### Main NAS (Remote Server at 10.0.0.89)
- **Purpose**: Final backup destination
- **Method**: ZFS replication (automatic)
- **Schedule**: Daily at 2:30 AM
- **Retention**: 7 days of snapshots

### Backup Flow
```
Windows Workstation
    ↓
Baby NAS (Hyper-V VM)
    ↓ (ZFS Replication)
Main NAS (10.0.0.89)
```

---

## 📁 Files Created

### Automation Scripts
```
D:\workspace\True_Nas\windows-scripts\
├── SETUP-BABY-NAS.ps1                   ⭐ Master orchestrator (START HERE!)
├── 1-create-baby-nas-vm.ps1             🔧 Creates Hyper-V VM with disk passthrough
├── 2-configure-baby-nas.ps1             🔧 Configures SSH, datasets, optimizations
├── 3-setup-replication.ps1              🔧 Sets up replication to Main NAS
├── truenas-api-setup.py                 🐍 API configuration and testing
└── truenas-baby-nas-config.sh           🐧 TrueNAS system configuration (auto-created)
```

### Documentation
```
D:\workspace\True_Nas\
├── BABY_NAS_IMPLEMENTATION_PLAN.md      📖 Complete 6-phase implementation plan
├── TRUENAS_DUAL_SERVER_BEST_PRACTICES.md 📖 Best practices from research
├── QUICKSTART.md                         📖 Quick start guide
├── TRUENAS_SETUP_GUIDE.md               📖 Comprehensive reference
└── windows-scripts\START_HERE.md        📖 This file!
```

---

## ⚡ Quick Start Options

### Option 1: Full Automated Setup (Recommended)
```powershell
# Run everything at once
.\SETUP-BABY-NAS.ps1
```

### Option 2: Step-by-Step Manual
```powershell
# Step 1: Create VM
.\1-create-baby-nas-vm.ps1

# Step 2: Install TrueNAS manually via console
# (Script will prompt you when ready)

# Step 3: Configure Baby NAS
.\2-configure-baby-nas.ps1 -BabyNasIP "192.168.1.x"

# Step 4: Set up replication
.\3-setup-replication.ps1 -BabyNasIP "192.168.1.x"
```

### Option 3: Skip Completed Phases
```powershell
# If VM already exists and TrueNAS is installed:
.\SETUP-BABY-NAS.ps1 -SkipVMCreation -BabyNasIP "192.168.1.50"

# If only need replication:
.\SETUP-BABY-NAS.ps1 -SkipVMCreation -SkipConfiguration -BabyNasIP "192.168.1.50"
```

---

## 🔑 Default Credentials

**IMPORTANT**: These are the default credentials used by the scripts.

| Account | Password | Purpose |
|---------|----------|---------|
| `root` | `uppercut%$##` | TrueNAS administrator |
| `truenas_admin` | `uppercut%$##` | Standard user for Windows access |

**Security Note**: Change these passwords after setup if this is a production system!

---

## 📊 Expected Configuration

### Hardware
| Component | Configuration |
|-----------|---------------|
| VM Name | TrueNAS-BabyNAS |
| RAM | 16GB |
| CPUs | 4 cores |
| OS Disk | 32GB VHDX |
| Data Disks | 3x 6TB HDDs (RAIDZ1) |
| Cache | 2x 256GB SSDs (SLOG + L2ARC) |

### Storage Pool
| Property | Value |
|----------|-------|
| Pool Name | tank |
| Type | RAIDZ1 |
| Usable Capacity | ~12TB |
| Compression | lz4 |
| Fault Tolerance | 1 disk failure |
| SLOG | 256GB SSD (write acceleration) |
| L2ARC | 256GB SSD (read caching) |

### Datasets
| Dataset | Quota | Purpose |
|---------|-------|---------|
| tank/windows-backups/c-drive | 500GB | System drive backup |
| tank/windows-backups/d-workspace | 2TB | Development workspace |
| tank/windows-backups/wsl | 500GB | WSL distributions |
| tank/veeam | 3TB | Veeam backup repository |
| tank/home/truenas_admin | - | User home directory |

---

## 🌐 Network Access

### SSH Access
```bash
# Connect to Baby NAS
ssh babynas

# Or with full path
ssh -i ~/.ssh/id_babynas root@<baby-nas-ip>

# Check status
ssh babynas "zpool status tank"
```

### Web UI
```
URL: https://<baby-nas-ip>
User: root
Pass: uppercut%$##
```

### SMB Shares (Windows)
```powershell
# Map WindowsBackup share
net use W: \\<baby-nas-ip>\WindowsBackup /user:truenas_admin "uppercut%$##" /persistent:yes

# Map Veeam share
net use V: \\<baby-nas-ip>\Veeam /user:truenas_admin "uppercut%$##" /persistent:yes
```

### API Access
```bash
# After API setup
python truenas-api-setup.py --status
python truenas-api-setup.py --pools
```

---

## 📅 Automated Tasks

### Baby NAS → Main NAS Replication
- **Schedule**: Daily at 2:30 AM
- **Method**: ZFS incremental send/receive
- **Retention**: 7 days of auto snapshots
- **Script**: `/root/replicate-to-main.sh`

### Snapshots
| Type | Schedule | Retention |
|------|----------|-----------|
| Hourly | Every hour | 24 snapshots |
| Daily | Midnight | 7 snapshots |
| Weekly | Monday midnight | 4 snapshots |

### Maintenance
| Task | Schedule |
|------|----------|
| SMART short test | Weekly (Sunday 3 AM) |
| SMART long test | Monthly (1st @ 2 AM) |
| ZFS scrub | Monthly (1st @ 1 AM) |

---

## 🔍 Troubleshooting

### VM Won't Start
```powershell
# Check VM status
Get-VM "TrueNAS-BabyNAS"

# Check disk status
Get-Disk | Where-Object IsOffline -eq $true

# Bring disks online if needed (CAUTION!)
Set-Disk -Number X -IsOnline $true
```

### Can't Connect to Baby NAS
```powershell
# Test network connectivity
Test-Connection -ComputerName <baby-nas-ip>

# Check if VM is running
Get-VM "TrueNAS-BabyNAS" | Select-Object Name, State

# Connect to VM console
vmconnect.exe localhost "TrueNAS-BabyNAS"
```

### SSH Not Working
```bash
# Test with password first
ssh root@<baby-nas-ip>
# Password: uppercut%$##

# Check SSH service on Baby NAS
ssh root@<baby-nas-ip> "systemctl status ssh"

# Regenerate SSH key
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_babynas" -N '""'
```

### SMB Share Not Accessible
```powershell
# Test SMB port
Test-NetConnection -ComputerName <baby-nas-ip> -Port 445

# List shares
smbclient -L //<baby-nas-ip> -U truenas_admin

# Check Windows firewall
Get-NetFirewallRule -DisplayName "*SMB*" | Format-Table
```

### Replication Failed
```bash
# Check replication log
ssh babynas "tail -50 /var/log/replication.log"

# Check replication health
ssh babynas "/root/check-replication.sh"

# Manual replication
ssh babynas "/root/replicate-to-main.sh"
```

---

## 📚 Additional Resources

### Quick Reference
- **Installation Plan**: `BABY_NAS_IMPLEMENTATION_PLAN.md`
- **Best Practices**: `TRUENAS_DUAL_SERVER_BEST_PRACTICES.md`
- **Quick Start**: `QUICKSTART.md`
- **Full Guide**: `TRUENAS_SETUP_GUIDE.md`

### Management Commands
```bash
# Pool status
ssh babynas "zpool status tank"

# Dataset usage
ssh babynas "zfs list -r tank"

# Compression ratio
ssh babynas "zfs get compressratio tank"

# Replication status
ssh babynas "/root/check-replication.sh"

# Manual replication
ssh babynas "/root/replicate-to-main.sh"
```

### Useful URLs
- **TrueNAS Documentation**: https://www.truenas.com/docs/scale/
- **API Documentation**: https://<baby-nas-ip>/api/docs
- **OpenZFS Docs**: https://openzfs.github.io/openzfs-docs/

---

## ⚙️ What Happens During Setup

### Phase 1: VM Creation (15 minutes)
1. Identifies available disks (3x 6TB + 2x 256GB)
2. Takes disks offline
3. Creates Hyper-V VM
4. Passes through physical disks
5. Attaches TrueNAS ISO
6. Starts VM and opens console
7. **⏸️ PAUSE**: You install TrueNAS manually (~5-10 minutes)

### Phase 2: Configuration (20 minutes)
1. Generates SSH keys
2. Copies keys to Baby NAS
3. Creates SSH config alias
4. Uploads configuration script
5. **⏸️ PAUSE**: You create ZFS pool via Web UI (~5 minutes)
6. Runs dataset creation script
7. **⏸️ PAUSE**: You create truenas_admin user (~2 minutes)
8. **⏸️ PAUSE**: You create SMB shares (~3 minutes)
9. Tests SMB connectivity
10. Configures API access (optional)

### Phase 3: Replication (15 minutes)
1. Verifies connectivity to Main NAS (10.0.0.89)
2. Generates replication SSH key on Baby NAS
3. Adds key to Main NAS
4. Tests replication connection
5. Creates target datasets on Main NAS
6. Creates replication script
7. Tests initial replication (optional)
8. Schedules automatic replication (daily 2:30 AM)
9. Creates monitoring script

### Phase 4: Auto-Start (2 minutes)
1. Configures VM to start automatically with Windows
2. Sets graceful shutdown on host stop
3. Verifies configuration

**Total Time**: ~1 hour (including manual steps)

---

## ✅ Post-Setup Checklist

After setup completes, verify:

- [ ] Baby NAS VM is running: `Get-VM "TrueNAS-BabyNAS"`
- [ ] Can SSH to Baby NAS: `ssh babynas`
- [ ] Pool is online: `ssh babynas "zpool status tank"`
- [ ] Datasets created: `ssh babynas "zfs list -r tank"`
- [ ] SMB shares accessible: `Test-Path \\<baby-nas-ip>\WindowsBackup`
- [ ] Network drives mapped: `Get-PSDrive W,V`
- [ ] Replication scheduled: `ssh babynas "crontab -l | grep replicate"`
- [ ] VM auto-start enabled: Check VM properties
- [ ] API access working: `python truenas-api-setup.py --status`

---

## 🎯 Next Steps After Setup

### 1. Configure Windows Backup Jobs

**Veeam Backup:**
```
1. Open Veeam Agent for Windows
2. Create backup job:
   - Type: Entire computer
   - Destination: \\<baby-nas-ip>\Veeam
   - Schedule: Daily 1:00 AM
   - Retention: 7 restore points
```

**Robocopy Workspace Sync:**
```powershell
# D:\scripts\backup-workspace.ps1
robocopy D:\workspace \\<baby-nas-ip>\WindowsBackup\d-workspace /MIR /Z /FFT
```

### 2. Map Network Drives
```powershell
net use W: \\<baby-nas-ip>\WindowsBackup /user:truenas_admin "uppercut%$##" /persistent:yes
net use V: \\<baby-nas-ip>\Veeam /user:truenas_admin "uppercut%$##" /persistent:yes
```

### 3. Test Recovery
```bash
# List available snapshots
ssh babynas "zfs list -t snapshot -r tank/windows-backups"

# Test restore from snapshot
ssh babynas "zfs rollback tank/windows-backups/d-workspace@auto-<date>-<time>"
```

### 4. Monitor System
```bash
# Create monitoring script
# D:\scripts\check-baby-nas.ps1

Write-Host "Baby NAS Status:" -ForegroundColor Cyan
ssh babynas "zpool status tank"
ssh babynas "/root/check-replication.sh"
```

### 5. Schedule Health Checks
```powershell
# Windows Task Scheduler
# Task: Daily at 8:00 AM
# Action: PowerShell -File "D:\scripts\check-baby-nas.ps1"
```

---

## 🚨 Important Notes

### Security
- **Change default passwords** if this is production!
- **Backup TrueNAS config**: Web UI → System Settings → General → Save Config
- **Keep SSH keys secure**: Never share `~/.ssh/id_babynas`
- **Firewall**: Consider restricting access to local network only

### Maintenance
- **Weekly**: Check pool status, verify backups succeeded
- **Monthly**: Review scrub results, check disk health
- **Quarterly**: Test recovery procedures, update TrueNAS
- **Yearly**: Review capacity trends, plan upgrades

### Critical: Main NAS Backup Pool
⚠️ **WARNING**: The Main NAS `backup` pool is currently a **SINGLE DISK** with no redundancy!

**Action Required**:
1. Order matching 6TB drive (~$100)
2. Add as mirror when it arrives:
   ```bash
   ssh root@10.0.0.89
   zpool attach backup <existing-disk> <new-disk>
   ```

---

## 💡 Tips & Tricks

### PowerShell Shortcuts
Add these to your PowerShell profile (`$PROFILE`):

```powershell
# Quick access functions
function Connect-BabyNAS { ssh babynas }
function Get-BabyNASStatus { ssh babynas "zpool status tank && zfs list -r tank" }
function Start-BabyNASReplication { ssh babynas "/root/replicate-to-main.sh" }

Set-Alias -Name bnconnect -Value Connect-BabyNAS
Set-Alias -Name bnstatus -Value Get-BabyNASStatus
Set-Alias -Name bnreplicate -Value Start-BabyNASReplication
```

### ZFS Commands
```bash
# Check compression effectiveness
ssh babynas "zfs get compressratio,used,available tank"

# List all snapshots
ssh babynas "zfs list -t snapshot -r tank | grep auto-"

# Delete old snapshots manually
ssh babynas "zfs destroy tank/veeam@auto-20250101-0200"

# Monitor pool I/O real-time
ssh babynas "zpool iostat -v tank 2"
```

### Performance Tuning
```bash
# Check ARC hit rate (should be >80%)
ssh babynas "arc_summary | grep 'Hit Rate'"

# Monitor network throughput
ssh babynas "iftop -i eth0"

# Check SLOG/L2ARC usage
ssh babynas "zpool iostat -v tank"
```

---

## 📞 Support & Help

### Getting Help
1. Check troubleshooting section above
2. Review log files: `ssh babynas "tail -50 /var/log/replication.log"`
3. Search TrueNAS forums: https://forums.truenas.com/
4. Check official docs: https://www.truenas.com/docs/scale/

### Useful Diagnostic Commands
```bash
# System info
ssh babynas "midclt call system.info"

# Pool health
ssh babynas "zpool status -v tank"

# Disk health
ssh babynas "smartctl -a /dev/sda"

# Network connectivity
ssh babynas "ping -c 4 10.0.0.89"

# Service status
ssh babynas "systemctl status ssh smbd"
```

---

## 🎉 You're Ready!

Everything is now configured and ready to use. Your backup pipeline is:

```
Windows → Baby NAS → Main NAS → (Optional: Cloud)
```

**Start using it:**
1. Configure Veeam to backup to `V:\` drive
2. Start syncing workspace to `W:\d-workspace`
3. Monitor with daily health checks
4. Test recovery monthly

**Questions?** Refer to the comprehensive guides in `D:\workspace\True_Nas\`:
- `BABY_NAS_IMPLEMENTATION_PLAN.md`
- `TRUENAS_DUAL_SERVER_BEST_PRACTICES.md`

---

**Ready to begin?**

```powershell
cd D:\workspace\True_Nas\windows-scripts
.\SETUP-BABY-NAS.ps1
```

Let's build that backup infrastructure! 🚀
