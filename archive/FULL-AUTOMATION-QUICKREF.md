# Baby NAS Full Automation - Quick Reference Card

## One-Line Quick Start

```powershell
cd D:\workspace\True_Nas\windows-scripts && .\FULL-AUTOMATION.ps1
```

## Common Commands

### Run Full Automation (Interactive)
```powershell
.\FULL-AUTOMATION.ps1
```

### Run Unattended (Minimal Prompts)
```powershell
.\FULL-AUTOMATION.ps1 -UnattendedMode
```

### Custom IPs
```powershell
.\FULL-AUTOMATION.ps1 -BabyNasIP "192.168.1.100" -MainNasIP "192.168.1.200"
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

### Troubleshoot Issues
```powershell
.\troubleshoot-automation.ps1
```

## Parameters Quick Reference

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BabyNasIP` | `172.21.203.18` | Baby NAS IP address |
| `-MainNasIP` | `10.0.0.89` | Main NAS IP address |
| `-Username` | `truenas_admin` | TrueNAS username |
| `-Password` | `uppercut%$##` | TrueNAS password |
| `-UnattendedMode` | False | Skip prompts |
| `-SkipReplication` | False | Skip replication setup |
| `-SkipTests` | False | Skip testing |

## DNS Options

1. **Cloudflare** (Default) - `1.1.1.1, 1.0.0.1`
2. **Google** - `8.8.8.8, 8.8.4.4`
3. **Quad9** - `9.9.9.9, 149.112.112.112`

## Execution Steps

```
1. Test Connectivity      → Verify Baby NAS is reachable
2. Deploy Configuration   → Upload and run setup script
3. Setup SSH Keys         → Generate and deploy keys
4. Configure DNS          → Set DNS servers
5. Run Tests              → Comprehensive validation
6. Setup Replication      → Configure Baby→Main sync
7. Optimize VM            → Adjust memory to 8GB
```

## Log Files

**Location:** `D:\workspace\True_Nas\logs\full-automation-YYYYMMDD-HHMMSS.log`

**View latest log:**
```powershell
Get-ChildItem D:\workspace\True_Nas\logs\full-automation-*.log |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 |
    Get-Content -Tail 50
```

## Quick Verification

### Test Baby NAS Access
```powershell
# Ping test
Test-Connection 172.21.203.18 -Count 4

# SSH test
ssh babynas "hostname"

# Pool status
ssh babynas "zpool status tank"
```

### Test SMB Access
```powershell
net use W: \\172.21.203.18\WindowsBackup /user:truenas_admin "uppercut%$##"
dir W:
```

### Check Replication Status
```powershell
ssh babynas "/root/check-replication.sh"
```

## Individual Step Scripts

| Step | Script |
|------|--------|
| Deploy Config | `.\DEPLOY-BABY-NAS-CONFIG.ps1` |
| SSH Keys | `.\setup-ssh-keys-complete.ps1` |
| Tests | `.\test-baby-nas-complete.ps1` |
| Replication | `.\3-setup-replication.ps1` |
| Troubleshoot | `.\troubleshoot-automation.ps1` |

## Common Issues & Fixes

### "Cannot reach Baby NAS"
```powershell
# Check VM status
Get-VM "TrueNAS-BabyNAS"

# Start VM if stopped
Start-VM "TrueNAS-BabyNAS"

# Get VM IP
.\get-vm-ip.ps1
```

### "SSH service not accessible"
1. Open `https://172.21.203.18`
2. Go to: System Settings → Services → SSH
3. Click Start

### "SSH authentication failed"
```powershell
# Test manual login
ssh admin@172.21.203.18

# Check credentials
# Default: admin / uppercut%$##
```

### "Configuration script failed"
```powershell
# Run configuration manually
ssh admin@172.21.203.18
bash /root/configure-baby-nas.sh
```

### "Replication setup failed"
```powershell
# Run replication setup manually
.\3-setup-replication.ps1 -BabyNasIP "172.21.203.18"
```

## Post-Automation Checklist

- [ ] Verify SMB access: `net use W: \\172.21.203.18\WindowsBackup`
- [ ] Test SSH: `ssh babynas "zpool status"`
- [ ] Check pool health: `ssh babynas "/usr/local/bin/check-pool-health.sh"`
- [ ] Verify datasets: `ssh babynas "zfs list -r tank"`
- [ ] Test replication: `ssh babynas "/root/replicate-to-main.sh"`
- [ ] Deploy Veeam: `.\veeam\0-DEPLOY-VEEAM-COMPLETE.ps1`
- [ ] Schedule backups: `.\schedule-backup-tasks.ps1`

## Useful SSH Commands

```bash
# Pool status
ssh babynas "zpool status tank"

# Dataset list
ssh babynas "zfs list -r tank"

# Snapshot list
ssh babynas "zfs list -t snapshot -r tank"

# Check replication
ssh babynas "/root/check-replication.sh"

# Manual replication
ssh babynas "/root/replicate-to-main.sh"

# System health
ssh babynas "/usr/local/bin/check-pool-health.sh"

# Disk status
ssh babynas "lsblk"

# Free space
ssh babynas "df -h"
```

## Windows Network Drive Mapping

```powershell
# Map WindowsBackup share
net use W: \\172.21.203.18\WindowsBackup /user:truenas_admin "uppercut%$##" /persistent:yes

# Map Veeam share
net use V: \\172.21.203.18\Veeam /user:truenas_admin "uppercut%$##" /persistent:yes

# Map Development share
net use D: \\172.21.203.18\Development /user:truenas_admin "uppercut%$##" /persistent:yes

# List mapped drives
net use
```

## Emergency Procedures

### Reset Automation (Start Over)
```powershell
# Stop VM
Stop-VM "TrueNAS-BabyNAS" -Force

# Optionally destroy and recreate VM
# (Warning: This deletes all data!)
Remove-VM "TrueNAS-BabyNAS" -Force

# Re-create VM
.\1-create-baby-nas-vm.ps1

# Run full automation
.\FULL-AUTOMATION.ps1
```

### View Live Logs
```powershell
# PowerShell
Get-Content D:\workspace\True_Nas\logs\full-automation-*.log -Wait

# Or use tail (if Git Bash installed)
tail -f D:\workspace\True_Nas\logs\full-automation-*.log
```

### Check Baby NAS System Logs
```powershell
# System journal
ssh babynas "journalctl -xe -n 100"

# ZFS events
ssh babynas "zpool events tank"

# Samba logs
ssh babynas "tail -f /var/log/samba/log.smbd"

# Replication logs
ssh babynas "tail -f /var/log/replication.log"
```

## Performance Monitoring

```powershell
# ZFS ARC stats
ssh babynas "arc_summary"

# I/O stats
ssh babynas "zpool iostat tank 1"

# Network stats
ssh babynas "iftop -i eth0"

# Disk I/O
ssh babynas "iostat -x 1"
```

## Backup & Recovery

### Export ZFS Pool Configuration
```bash
ssh babynas "zpool export tank"
ssh babynas "zpool import tank"
```

### Snapshot Operations
```bash
# Create manual snapshot
ssh babynas "zfs snapshot -r tank@manual-$(date +%Y%m%d)"

# List snapshots
ssh babynas "zfs list -t snapshot -r tank"

# Rollback to snapshot
ssh babynas "zfs rollback tank/windows-backups@snapshot-name"
```

### Encryption Key Backup
```bash
# Backup encryption key (IMPORTANT!)
ssh babynas "cat /root/.zfs_encryption_key" > encryption-key-backup.txt

# Store in secure location
# Do NOT lose this key!
```

## Support Files

| File | Purpose |
|------|---------|
| `FULL-AUTOMATION.ps1` | Main orchestration script |
| `FULL-AUTOMATION-README.md` | Detailed documentation |
| `RUN-FULL-AUTOMATION.bat` | Quick launcher (double-click) |
| `troubleshoot-automation.ps1` | Diagnostic tool |

## Version Info

**Script Version:** 1.0
**Last Updated:** 2024-12-10
**Compatibility:** Windows 10/11, PowerShell 5.1+, TrueNAS SCALE

## Quick Help

```powershell
# View script help
Get-Help .\FULL-AUTOMATION.ps1 -Detailed

# View parameters
Get-Help .\FULL-AUTOMATION.ps1 -Parameter *

# View examples
Get-Help .\FULL-AUTOMATION.ps1 -Examples
```

## Contact & Support

For issues:
1. Run troubleshooter: `.\troubleshoot-automation.ps1`
2. Check logs: `D:\workspace\True_Nas\logs\`
3. Review README: `FULL-AUTOMATION-README.md`
4. Check Baby NAS logs: `ssh babynas "journalctl -xe"`

---

**Remember:** Always run PowerShell as Administrator for full automation!
