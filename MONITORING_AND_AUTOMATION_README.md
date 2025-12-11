# Baby NAS Monitoring and Automation Scripts

## Overview

This collection provides comprehensive monitoring, backup, and automation scripts for the Baby NAS infrastructure. These production-ready scripts include error handling, logging, and email notification capabilities.

## Scripts Included

### 1. **monitor-baby-nas.ps1** - Real-Time Health Monitoring

Provides real-time monitoring of the Baby NAS infrastructure with color-coded status indicators.

**Features:**
- VM status and uptime monitoring
- Network connectivity checks (Baby NAS + Main NAS)
- ZFS pool health verification
- Pool capacity monitoring with threshold alerts
- Replication status tracking
- SMB share accessibility testing
- Auto-detection of Baby NAS IP from Hyper-V
- Continuous monitoring mode with auto-refresh

**Usage:**
```powershell
# Basic monitoring (single check)
.\monitor-baby-nas.ps1

# With explicit Baby NAS IP
.\monitor-baby-nas.ps1 -BabyNasIP 192.168.1.100

# Continuous monitoring (refreshes every 30 seconds)
.\monitor-baby-nas.ps1 -Continuous

# Custom refresh interval
.\monitor-baby-nas.ps1 -Continuous -RefreshSeconds 60
```

**Status Indicators:**
- ✓ Green = OK / Healthy
- ⚠ Yellow = Warning / Attention needed
- ✗ Red = Error / Critical issue

**Exit Codes:**
- 0 = All healthy
- 1 = Critical errors detected
- 2 = Warnings detected

---

### 2. **backup-workspace.ps1** - Automated Workspace Backup

Comprehensive backup solution using Robocopy with intelligent exclusions and detailed logging.

**Features:**
- Mirrors D:\workspace to Baby NAS
- Excludes development artifacts (node_modules, .git, etc.)
- Multi-threaded operation (8 threads)
- Pre-backup validation (space checks, write access)
- Detects locked processes that might interfere
- Creates timestamped backup logs
- Generates backup marker files for verification
- Auto-cleanup of old logs (>30 days)
- WhatIf mode for testing

**Usage:**
```powershell
# Auto-detect destination
.\backup-workspace.ps1

# Explicit destination
.\backup-workspace.ps1 -Destination "\\192.168.1.100\WindowsBackup\d-workspace"

# Test run (no changes)
.\backup-workspace.ps1 -WhatIf

# With custom source
.\backup-workspace.ps1 -Source "D:\projects" -Destination "W:\projects-backup"

# With email notification (requires SMTP configuration)
.\backup-workspace.ps1 -SendEmail -EmailTo "admin@example.com"
```

**Excluded Patterns:**
- Directories: node_modules, .git, .vscode, bin, obj, dist, build, venv, __pycache__
- Files: *.tmp, *.log, *.cache, package-lock.json, yarn.lock

**Exit Codes:**
- 0 = Backup successful
- 1 = Backup failed
- 2 = Backup completed with warnings

---

### 3. **test-recovery.ps1** - Recovery Testing Automation

Automated recovery testing to verify backup integrity and restore capabilities.

**Features:**
- 7 comprehensive test suites
- Baby NAS auto-detection
- Network connectivity verification
- SSH access validation
- Snapshot availability check
- SMB share access testing
- Test restore operations
- Pool health verification
- Detailed JSON and text reports
- Optional automatic cleanup

**Usage:**
```powershell
# Run all recovery tests
.\test-recovery.ps1

# With explicit Baby NAS IP
.\test-recovery.ps1 -BabyNasIP 192.168.1.100

# With cleanup after test
.\test-recovery.ps1 -CleanupAfterTest

# Custom test restore location
.\test-recovery.ps1 -TestPath "C:\Recovery-Test-$(Get-Date -Format 'yyyyMMdd')"

# Custom dataset
.\test-recovery.ps1 -Dataset "tank/veeam"
```

**Test Suites:**
1. Baby NAS Detection
2. Network Connectivity
3. SSH Access
4. Snapshot Availability
5. SMB Share Access
6. Test Restore Operation
7. Pool Health Check

**Reports Generated:**
- Text log: `C:\Logs\recovery-tests\recovery-test-YYYYMMDD-HHMMSS.log`
- JSON report: `C:\Logs\recovery-tests\recovery-test-YYYYMMDD-HHMMSS.json`

**Exit Codes:**
- 0 = All tests passed
- 1 = One or more tests failed
- 2 = Tests passed with warnings

---

### 4. **daily-health-check.ps1** - Scheduled Daily Health Check

Comprehensive daily health check that runs all system validations and generates a detailed report.

**Features:**
- 9+ comprehensive health checks
- VM status monitoring
- Network connectivity (Baby + Main NAS)
- ZFS pool health (all pools)
- Backup freshness verification
- Snapshot count validation
- SMB share accessibility
- Local disk space monitoring
- Scheduled task verification
- Replication status tracking
- Customizable thresholds
- Email notifications (configurable)
- Auto-cleanup of old logs

**Usage:**
```powershell
# Basic daily check
.\daily-health-check.ps1

# With email notification (requires SMTP configuration)
.\daily-health-check.ps1 -SendEmail -EmailTo "admin@example.com"

# Custom Baby NAS IP
.\daily-health-check.ps1 -BabyNasIP 192.168.1.100

# Custom log location
.\daily-health-check.ps1 -LogPath "D:\Logs\health-checks"
```

**Health Thresholds (Default):**
- Backup Age: 28 hours max
- Disk Space: 20% min free
- Pool Capacity: 85% max
- Snapshots: 10 minimum
- Replication Age: 26 hours max

**Checks Performed:**
1. Hyper-V VM Status
2. Network Connectivity (Baby + Main NAS)
3. Storage Pool Health (tank, backup)
4. Backup Freshness
5. Snapshot Availability
6. SMB Share Accessibility
7. Local Disk Space
8. Scheduled Backup Tasks
9. Replication Status

**Exit Codes:**
- 0 = System healthy
- 1 = Critical issues detected
- 2 = Warnings present

---

### 5. **schedule-backup-tasks.ps1** - Task Scheduler Setup

Automates the creation of Windows scheduled tasks for all monitoring and backup operations.

**Features:**
- Creates 4 scheduled tasks automatically
- Configures proper permissions (runs as SYSTEM)
- Sets optimal task priorities
- Configures retry and power options
- Supports WhatIf mode for testing
- Can recreate existing tasks
- Creates required log directories
- Provides detailed task summaries
- Interactive test option

**Usage:**
```powershell
# Create all scheduled tasks
.\schedule-backup-tasks.ps1

# Test mode (no changes)
.\schedule-backup-tasks.ps1 -WhatIf

# Recreate existing tasks
.\schedule-backup-tasks.ps1 -RemoveExisting

# With Baby NAS IP
.\schedule-backup-tasks.ps1 -BabyNasIP 192.168.1.100

# With email notifications
.\schedule-backup-tasks.ps1 -EmailTo "admin@example.com"

# Combined options
.\schedule-backup-tasks.ps1 -RemoveExisting -BabyNasIP 192.168.1.100 -EmailTo "admin@example.com"
```

**Tasks Created:**

| Task Name | Schedule | Description | Status |
|-----------|----------|-------------|--------|
| BabyNAS-DailyWorkspaceBackup | Daily 12:30 AM | Backup D:\workspace to Baby NAS | Enabled |
| BabyNAS-DailyHealthCheck | Daily 8:00 AM | Run comprehensive health check | Enabled |
| BabyNAS-WeeklyRecoveryTest | Sunday 6:00 AM | Test backup recovery capabilities | Enabled |
| BabyNAS-HourlyMonitor | Every hour | Quick health monitoring | Disabled* |

*Hourly monitor disabled by default - enable manually if needed

---

## Quick Start Guide

### Initial Setup

1. **Prerequisites:**
   ```powershell
   # Ensure running as Administrator
   # Verify Baby NAS VM is running
   Get-VM | Where-Object { $_.Name -like "*Baby*" }

   # Verify SSH keys are configured
   Test-Path "$env:USERPROFILE\.ssh\id_babynas"
   ```

2. **Test Monitoring:**
   ```powershell
   cd D:\workspace\True_Nas\windows-scripts
   .\monitor-baby-nas.ps1
   ```

3. **Run Initial Health Check:**
   ```powershell
   .\daily-health-check.ps1
   ```

4. **Test Backup (WhatIf mode):**
   ```powershell
   .\backup-workspace.ps1 -WhatIf
   ```

5. **Run Recovery Test:**
   ```powershell
   .\test-recovery.ps1 -CleanupAfterTest
   ```

6. **Schedule Automated Tasks:**
   ```powershell
   # Test first
   .\schedule-backup-tasks.ps1 -WhatIf

   # Then create for real
   .\schedule-backup-tasks.ps1
   ```

---

## Common Operations

### View Scheduled Tasks
```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like 'BabyNAS-*' }
```

### Manually Run a Task
```powershell
Start-ScheduledTask -TaskName 'BabyNAS-DailyHealthCheck'
```

### View Task History
```powershell
Get-ScheduledTaskInfo -TaskName 'BabyNAS-DailyHealthCheck'
```

### Enable/Disable Tasks
```powershell
Enable-ScheduledTask -TaskName 'BabyNAS-HourlyMonitor'
Disable-ScheduledTask -TaskName 'BabyNAS-WeeklyRecoveryTest'
```

### View Recent Logs
```powershell
# Health check logs
Get-ChildItem C:\Logs\daily-health-checks | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Backup logs
Get-ChildItem C:\Logs\workspace-backup | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Recovery test logs
Get-ChildItem C:\Logs\recovery-tests | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

### Check Last Backup Time
```powershell
# View backup marker file
Get-Content "\\babynas\WindowsBackup\d-workspace\.last-backup-info.txt"
```

---

## Log Locations

All scripts generate detailed logs in `C:\Logs\`:

- **Workspace Backups:** `C:\Logs\workspace-backup\backup-YYYYMMDD-HHMMSS.log`
- **Health Checks:** `C:\Logs\daily-health-checks\health-check-YYYYMMDD-HHMMSS.log`
- **Recovery Tests:** `C:\Logs\recovery-tests\recovery-test-YYYYMMDD-HHMMSS.log` + `.json`

Logs older than 30 days are automatically cleaned up.

---

## Email Notifications

### Configuration Required

To enable email notifications, edit the scripts and configure SMTP settings:

```powershell
# In daily-health-check.ps1 and backup-workspace.ps1
# Uncomment and configure the Send-MailMessage section:

Send-MailMessage `
    -To $EmailTo `
    -From "backups@example.com" `
    -Subject $emailSubject `
    -Body $emailBody `
    -SmtpServer "smtp.gmail.com" `
    -Port 587 `
    -UseSsl `
    -Credential (Get-Credential)
```

### Gmail Configuration Example

1. Enable 2-factor authentication on your Gmail account
2. Create an App Password: https://myaccount.google.com/apppasswords
3. Use the app password in the script:

```powershell
$password = ConvertTo-SecureString "your-app-password" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ("your-email@gmail.com", $password)

Send-MailMessage `
    -To $EmailTo `
    -From "your-email@gmail.com" `
    -Subject $emailSubject `
    -Body $emailBody `
    -SmtpServer "smtp.gmail.com" `
    -Port 587 `
    -UseSsl `
    -Credential $credential
```

---

## Troubleshooting

### Baby NAS IP Not Detected

**Problem:** Scripts cannot auto-detect Baby NAS IP

**Solution:**
```powershell
# Manually specify IP in all commands
.\monitor-baby-nas.ps1 -BabyNasIP 192.168.1.100

# Or set as default in scheduled tasks
.\schedule-backup-tasks.ps1 -BabyNasIP 192.168.1.100
```

### SSH Connection Fails

**Problem:** "Cannot establish SSH connection"

**Solution:**
```powershell
# Reconfigure SSH keys
cd D:\workspace\True_Nas\windows-scripts
.\2-configure-baby-nas.ps1 -BabyNasIP 192.168.1.100
```

### Backup Task Fails

**Problem:** Scheduled backup task shows "Failed" status

**Solution:**
```powershell
# Check task result details
Get-ScheduledTaskInfo -TaskName 'BabyNAS-DailyWorkspaceBackup'

# View last backup log
Get-ChildItem C:\Logs\workspace-backup | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50

# Run manually to see errors
.\backup-workspace.ps1
```

### SMB Shares Not Accessible

**Problem:** "SMB shares not accessible"

**Solution:**
```powershell
# Test connectivity
Test-Connection -ComputerName babynas -Count 2

# Try to access share manually
Test-Path "\\babynas\WindowsBackup"

# Check SMB service on Baby NAS (via SSH)
ssh root@babynas "systemctl status smb"

# Verify share is enabled in TrueNAS web UI
# https://babynas-ip/
```

### Pool Degraded Warning

**Problem:** Health check reports "Pool is DEGRADED"

**Solution:**
```powershell
# Check pool status directly
ssh root@babynas "zpool status tank"

# Look for disk errors
ssh root@babynas "zpool status -x"

# If resilver in progress, wait for completion
# Otherwise, investigate disk failures
```

---

## Best Practices

### Daily Operations

1. **Review morning health check** (arrives at 8 AM if email configured)
2. **Check failed task notifications** in Task Scheduler
3. **Verify backups completed** (scheduled for 12:30 AM)
4. **Monitor pool capacity** - act when >80%

### Weekly Tasks

1. **Review Sunday recovery test results**
2. **Check replication logs** on Baby NAS
3. **Verify snapshot counts** are increasing
4. **Review disk space trends**

### Monthly Tasks

1. **Test manual recovery** of important files
2. **Review and archive old logs** (auto-cleanup after 30 days)
3. **Update excluded patterns** if new project types added
4. **Verify all scheduled tasks** are running correctly
5. **Check for Baby NAS system updates**

### Quarterly Tasks

1. **Perform full system restore test**
2. **Review and update backup strategy**
3. **Verify off-site replication** (to Main NAS)
4. **Test emergency recovery procedures**
5. **Update documentation** with any changes

---

## Advanced Configuration

### Customize Backup Exclusions

Edit `backup-workspace.ps1` and modify these arrays:

```powershell
$ExcludeDirs = @(
    "node_modules",
    ".git",
    # Add your custom exclusions here
    "my-temp-folder",
    "large-downloads"
)

$ExcludeFiles = @(
    "*.tmp",
    "*.log",
    # Add custom file patterns
    "*.iso",
    "*.vmdk"
)
```

### Adjust Health Check Thresholds

Edit `daily-health-check.ps1`:

```powershell
$thresholds = @{
    BackupAgeHours = 28          # Change to 48 for less frequent alerts
    DiskSpacePercent = 20         # Change to 10 for tighter monitoring
    PoolCapacityPercent = 85      # Change to 90 for more capacity
    SnapshotMinCount = 10         # Adjust based on retention policy
    ReplicationMaxAgeHours = 26   # Match replication schedule
}
```

### Custom Backup Schedules

Modify `schedule-backup-tasks.ps1`:

```powershell
@{
    Name = "BabyNAS-DailyWorkspaceBackup"
    Schedule = @{
        Time = "02:00"  # Change to 2:00 AM
        Days = @("Daily")
    }
}
```

---

## Integration with Existing Infrastructure

### Main NAS Replication

These scripts work alongside the Main NAS replication setup:

```
Windows Host (D:\workspace)
    ↓ (backup-workspace.ps1)
Baby NAS (tank/windows-backups)
    ↓ (ZFS replication - configured separately)
Main NAS (backup/babynas/windows-backups)
```

### Veeam Integration

These scripts complement Veeam:
- Veeam: System state, C: drive, applications
- These scripts: D:\workspace, user data, development files

### Monitoring Integration

Health check status codes can integrate with monitoring systems:
- Exit code 0 = Healthy
- Exit code 1 = Critical (trigger alerts)
- Exit code 2 = Warning (log for review)

---

## Security Considerations

### SSH Key Security

- Keys stored in `$env:USERPROFILE\.ssh\`
- Protected by Windows file permissions
- Used for passwordless authentication
- Never commit keys to git

### Scheduled Task Security

- Tasks run as SYSTEM account
- Highest privilege level required for Hyper-V access
- Logs contain no sensitive data
- Email notifications (if configured) sent over SSL

### Network Security

- Baby NAS should be on trusted network only
- Use WireGuard VPN for remote access
- SMB shares use authentication
- Consider firewall rules for additional security

---

## Performance Optimization

### Backup Performance

Robocopy is configured for optimal performance:
- 8 threads (`/MT:8`) - adjust based on CPU
- Excludes unnecessary files
- Mirror mode (`/MIR`) for efficiency
- File attribute copying for speed

### Monitoring Performance

- Continuous monitoring adds minimal overhead
- SSH connections are lightweight
- Pool status queries are cached by ZFS
- Use hourly monitor sparingly

---

## Disaster Recovery

### Recovery Procedures

1. **File-Level Recovery:**
   ```powershell
   # Browse to backup location
   explorer "\\babynas\WindowsBackup\d-workspace"

   # Copy specific files back
   Copy-Item "\\babynas\WindowsBackup\d-workspace\project\file.txt" -Destination "D:\workspace\project\"
   ```

2. **Snapshot-Based Recovery:**
   ```powershell
   # List available snapshots via SSH
   ssh root@babynas "zfs list -t snapshot -r tank/windows-backups"

   # Browse snapshot via SMB
   explorer "\\babynas\WindowsBackup\.zfs\snapshot\"
   ```

3. **Full Workspace Restore:**
   ```powershell
   # Use backup-workspace.ps1 in reverse
   robocopy "\\babynas\WindowsBackup\d-workspace" "D:\workspace" /MIR /R:3 /W:5 /MT:8
   ```

4. **Emergency Recovery from Main NAS:**
   ```powershell
   # If Baby NAS fails, recover from Main NAS
   robocopy "\\10.0.0.89\backup\babynas\windows-backups" "D:\workspace" /MIR /R:3 /W:5 /MT:8
   ```

---

## Support and Maintenance

### Getting Help

1. Check logs in `C:\Logs\`
2. Review this README
3. Check TrueNAS web UI: `https://babynas-ip/`
4. Review Windows Event Viewer for task scheduler events

### Maintenance Tasks

- **Scripts are self-maintaining:** Old logs auto-delete after 30 days
- **No database or state files** to maintain
- **Idempotent:** Safe to run repeatedly
- **Update scripts:** Pull latest from git repository

---

## Version History

**Version 1.0** (2025-12-10)
- Initial release
- 5 comprehensive scripts
- Full monitoring and automation suite
- Production-ready with error handling
- Detailed logging and reporting

---

## License and Credits

These scripts are part of the Baby NAS Infrastructure project.

**Created:** 2025-12-10
**Author:** JD Mal
**Environment:** Windows Server/10/11 with Hyper-V and TrueNAS SCALE

---

## Quick Reference Card

### Most Common Commands

```powershell
# Check system health right now
.\monitor-baby-nas.ps1

# Run full health check
.\daily-health-check.ps1

# Backup workspace now
.\backup-workspace.ps1

# Test recovery capabilities
.\test-recovery.ps1 -CleanupAfterTest

# View scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like 'BabyNAS-*' }

# Check last backup
Get-Content "\\babynas\WindowsBackup\d-workspace\.last-backup-info.txt"

# View recent logs
Get-ChildItem C:\Logs\*-health-checks | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 20
```

---

**End of Documentation**

For more information about the Baby NAS infrastructure, see:
- `BABY_NAS_IMPLEMENTATION_PLAN.md` - Complete setup guide
- `START_HERE.md` - Initial setup instructions
- `QUICK_REFERENCE_GUIDE.md` - System overview
