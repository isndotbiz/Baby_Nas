# Baby NAS Monitoring & Automation Scripts - Summary

## Scripts Created (2025-12-10)

All scripts are production-ready with comprehensive error handling, logging, and documentation.

---

## 📊 1. monitor-baby-nas.ps1 (20 KB)

**Real-time health monitoring dashboard**

### Key Features
- Live VM status monitoring with uptime tracking
- Network connectivity tests (Baby NAS + Main NAS)
- ZFS pool health and capacity monitoring
- Replication status verification
- SMB share accessibility testing
- Color-coded status indicators (Red/Yellow/Green)
- Continuous monitoring mode with auto-refresh
- Auto-detects Baby NAS IP from Hyper-V

### Quick Start
```powershell
# Single check
.\monitor-baby-nas.ps1

# Continuous monitoring (refresh every 30s)
.\monitor-baby-nas.ps1 -Continuous

# With specific IP
.\monitor-baby-nas.ps1 -BabyNasIP 192.168.1.100
```

### Output Example
```
═══ Hyper-V VM Status ═══
✓ VM 'TrueNAS-BabyNAS' is Running
  Uptime: 05.14:23:45
  CPU: 12% | Memory: 14.5 GB assigned

═══ Network Connectivity ═══
✓ Baby NAS reachable at 192.168.1.100
✓ Main NAS reachable at 10.0.0.89

OVERALL STATUS: OK
```

---

## 💾 2. backup-workspace.ps1 (17 KB)

**Automated workspace backup using Robocopy**

### Key Features
- Mirrors D:\workspace to Baby NAS
- Smart exclusions (node_modules, .git, .vscode, etc.)
- Multi-threaded (8 threads) for speed
- Pre-backup validation (space, permissions)
- Detects locked files/processes
- Detailed logging with timestamps
- Auto-cleanup of logs >30 days
- WhatIf mode for testing
- Creates backup marker files

### Quick Start
```powershell
# Auto-detect destination
.\backup-workspace.ps1

# Test run (no changes)
.\backup-workspace.ps1 -WhatIf

# Custom destination
.\backup-workspace.ps1 -Destination "\\192.168.1.100\WindowsBackup\d-workspace"
```

### Excluded by Default
- **Dirs:** node_modules, .git, .vscode, bin, obj, dist, build, venv, __pycache__, target
- **Files:** *.tmp, *.log, *.cache, package-lock.json, yarn.lock

### Log Location
`C:\Logs\workspace-backup\backup-YYYYMMDD-HHMMSS.log`

---

## 🧪 3. test-recovery.ps1 (23 KB)

**Automated recovery testing and validation**

### Key Features
- 7 comprehensive test suites
- Baby NAS auto-detection
- Network connectivity tests
- SSH access validation
- Snapshot availability check
- SMB share testing
- Test restore operations
- Pool health verification
- JSON + text report generation
- Optional cleanup after test

### Quick Start
```powershell
# Run all tests
.\test-recovery.ps1

# With cleanup
.\test-recovery.ps1 -CleanupAfterTest

# Custom restore location
.\test-recovery.ps1 -TestPath "C:\Recovery-Test"
```

### Test Suites
1. ✓ Baby NAS Detection
2. ✓ Network Connectivity
3. ✓ SSH Access
4. ✓ Snapshot Availability
5. ✓ SMB Share Access
6. ✓ Test Restore Operation
7. ✓ Pool Health Check

### Reports Generated
- Text: `C:\Logs\recovery-tests\recovery-test-YYYYMMDD-HHMMSS.log`
- JSON: `C:\Logs\recovery-tests\recovery-test-YYYYMMDD-HHMMSS.json`

---

## 🏥 4. daily-health-check.ps1 (26 KB)

**Comprehensive daily system health check**

### Key Features
- 9+ health check categories
- VM and network monitoring
- Pool health (Baby + Main NAS)
- Backup freshness validation
- Snapshot count tracking
- SMB share testing
- Local disk space monitoring
- Scheduled task verification
- Replication status
- Customizable thresholds
- Email notifications (configurable)
- Auto-cleanup of old logs

### Quick Start
```powershell
# Run health check
.\daily-health-check.ps1

# With email (requires SMTP setup)
.\daily-health-check.ps1 -SendEmail -EmailTo "admin@example.com"
```

### Health Thresholds
| Check | Threshold | Action |
|-------|-----------|--------|
| Backup Age | 28 hours | Alert if older |
| Disk Space | 20% free | Alert if less |
| Pool Capacity | 85% used | Alert if more |
| Snapshots | 10 minimum | Alert if fewer |
| Replication | 26 hours | Alert if older |

### Checks Performed
1. Hyper-V VM Status
2. Network Connectivity
3. Storage Pool Health
4. Backup Freshness
5. Snapshot Count
6. SMB Shares
7. Local Disk Space
8. Scheduled Tasks
9. Replication Status

---

## 📅 5. schedule-backup-tasks.ps1 (19 KB)

**Automates Windows Task Scheduler setup**

### Key Features
- Creates 4 scheduled tasks
- Runs as SYSTEM with highest privileges
- Configurable schedules
- Automatic log directory creation
- WhatIf mode for testing
- Can recreate existing tasks
- Interactive test option
- Detailed task summaries

### Quick Start
```powershell
# Test mode
.\schedule-backup-tasks.ps1 -WhatIf

# Create tasks
.\schedule-backup-tasks.ps1

# Recreate existing
.\schedule-backup-tasks.ps1 -RemoveExisting

# With Baby NAS IP and email
.\schedule-backup-tasks.ps1 -BabyNasIP 192.168.1.100 -EmailTo "admin@example.com"
```

### Tasks Created

| Task Name | Schedule | Description | Default State |
|-----------|----------|-------------|---------------|
| **BabyNAS-DailyWorkspaceBackup** | Daily 12:30 AM | Backup D:\workspace | Enabled |
| **BabyNAS-DailyHealthCheck** | Daily 8:00 AM | Comprehensive health check | Enabled |
| **BabyNAS-WeeklyRecoveryTest** | Sunday 6:00 AM | Test recovery capabilities | Enabled |
| **BabyNAS-HourlyMonitor** | Every hour | Quick health monitoring | Disabled* |

*Enable manually if needed:
```powershell
Enable-ScheduledTask -TaskName 'BabyNAS-HourlyMonitor'
```

---

## 📖 6. MONITORING_AND_AUTOMATION_README.md (19 KB)

**Comprehensive documentation**

### Contents
- Detailed script documentation
- Quick start guide
- Common operations
- Troubleshooting guide
- Best practices
- Advanced configuration
- Disaster recovery procedures
- Quick reference card

---

## Installation & Setup

### Prerequisites
```powershell
# 1. Verify Administrator access
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Running as Admin: $isAdmin"

# 2. Verify Baby NAS VM exists
Get-VM | Where-Object { $_.Name -like "*Baby*" }

# 3. Verify SSH keys configured
Test-Path "$env:USERPROFILE\.ssh\id_babynas"
```

### Quick Setup (5 minutes)
```powershell
# 1. Change to scripts directory
cd D:\workspace\True_Nas\windows-scripts

# 2. Test monitoring
.\monitor-baby-nas.ps1

# 3. Run health check
.\daily-health-check.ps1

# 4. Test backup (no changes)
.\backup-workspace.ps1 -WhatIf

# 5. Test recovery validation
.\test-recovery.ps1 -CleanupAfterTest

# 6. Schedule automated tasks
.\schedule-backup-tasks.ps1
```

---

## Common Commands

### View Scheduled Tasks
```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like 'BabyNAS-*' }
```

### Manually Run a Task
```powershell
Start-ScheduledTask -TaskName 'BabyNAS-DailyHealthCheck'
```

### View Task Status
```powershell
Get-ScheduledTaskInfo -TaskName 'BabyNAS-DailyHealthCheck'
```

### Check Recent Logs
```powershell
# Health checks
Get-ChildItem C:\Logs\daily-health-checks | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Backups
Get-ChildItem C:\Logs\workspace-backup | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Recovery tests
Get-ChildItem C:\Logs\recovery-tests | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

### View Last Backup Info
```powershell
Get-Content "\\babynas\WindowsBackup\d-workspace\.last-backup-info.txt"
```

---

## Troubleshooting Quick Reference

### Issue: Baby NAS IP Not Detected
```powershell
# Solution: Specify IP explicitly
.\monitor-baby-nas.ps1 -BabyNasIP 192.168.1.100
```

### Issue: SSH Connection Fails
```powershell
# Solution: Reconfigure SSH keys
.\2-configure-baby-nas.ps1 -BabyNasIP 192.168.1.100
```

### Issue: SMB Shares Not Accessible
```powershell
# Solution: Test manually
Test-Path "\\babynas\WindowsBackup"

# Check SMB service
ssh root@babynas "systemctl status smb"
```

### Issue: Task Shows Failed Status
```powershell
# Solution: Check task details
Get-ScheduledTaskInfo -TaskName 'BabyNAS-DailyWorkspaceBackup'

# View last log
Get-ChildItem C:\Logs\workspace-backup | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50
```

---

## Script Statistics

| Script | Size | Lines | Functions | Features |
|--------|------|-------|-----------|----------|
| monitor-baby-nas.ps1 | 20 KB | ~550 | 3 | Real-time monitoring |
| backup-workspace.ps1 | 17 KB | ~480 | 3 | Robocopy automation |
| test-recovery.ps1 | 23 KB | ~640 | 6 | Recovery testing |
| daily-health-check.ps1 | 26 KB | ~720 | 5 | Health validation |
| schedule-backup-tasks.ps1 | 19 KB | ~570 | 3 | Task automation |

**Total:** 105 KB, ~2,960 lines of production-ready PowerShell code

---

## Exit Codes

All scripts use consistent exit codes:

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | All checks passed, operation successful |
| 1 | Error | Critical errors detected, immediate attention needed |
| 2 | Warning | Operation completed with warnings, review recommended |

Use in automation:
```powershell
.\daily-health-check.ps1
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "All healthy"
} elseif ($exitCode -eq 1) {
    Write-Host "Critical issues - send alert"
} else {
    Write-Host "Warnings present - log for review"
}
```

---

## Integration Points

### With Existing Infrastructure
- **Baby NAS VM:** Hyper-V monitoring and management
- **Main NAS (10.0.0.89):** Replication target monitoring
- **ZFS:** Pool health, snapshots, replication
- **SMB:** Share accessibility testing
- **SSH:** Remote command execution

### With External Systems
- **Task Scheduler:** Automated execution
- **Email (optional):** Notifications and alerts
- **Monitoring Systems:** Exit codes for integration
- **Log Aggregation:** Structured logs in C:\Logs\

---

## Security Features

- **SSH key authentication** (no passwords in scripts)
- **Runs as SYSTEM** (scheduled tasks)
- **No sensitive data** in logs
- **SSL email** notifications (if configured)
- **Audit trail** via detailed logging
- **WhatIf mode** for testing

---

## Performance Impact

| Script | CPU | Network | Disk I/O | Runtime |
|--------|-----|---------|----------|---------|
| monitor-baby-nas.ps1 | Minimal | Low | None | 5-10s |
| backup-workspace.ps1 | Moderate | High | High | 2-30 min* |
| test-recovery.ps1 | Low | Moderate | Low | 30-60s |
| daily-health-check.ps1 | Low | Low | Low | 10-20s |
| schedule-backup-tasks.ps1 | Minimal | None | None | 1-2s |

*Depends on workspace size

---

## Maintenance Schedule

### Automated
- ✓ Log cleanup (>30 days) - Automatic
- ✓ Daily backups - 12:30 AM
- ✓ Daily health checks - 8:00 AM
- ✓ Weekly recovery tests - Sunday 6:00 AM

### Manual
- Monthly: Review logs and trends
- Quarterly: Full system restore test
- As needed: Adjust thresholds and schedules

---

## Next Steps

1. **Review README:** Read `MONITORING_AND_AUTOMATION_README.md` for detailed documentation
2. **Test Scripts:** Run each script manually to verify operation
3. **Schedule Tasks:** Run `schedule-backup-tasks.ps1` to automate
4. **Configure Email:** Set up SMTP for notifications (optional)
5. **Monitor:** Check logs daily for first week, then weekly

---

## Support Resources

- **Full Documentation:** `MONITORING_AND_AUTOMATION_README.md`
- **Baby NAS Setup:** `BABY_NAS_IMPLEMENTATION_PLAN.md`
- **Quick Reference:** `QUICK_REFERENCE_GUIDE.md`
- **Logs Directory:** `C:\Logs\`
- **Scripts Directory:** `D:\workspace\True_Nas\windows-scripts\`

---

**Created:** 2025-12-10
**Version:** 1.0
**Status:** Production Ready
**Author:** JD Mal

---

## Quick Test Command

Test everything at once:
```powershell
# Run from scripts directory
cd D:\workspace\True_Nas\windows-scripts

# 1. Monitor (quick check)
.\monitor-baby-nas.ps1

# 2. Health check
.\daily-health-check.ps1

# 3. Backup test (no changes)
.\backup-workspace.ps1 -WhatIf

# 4. Recovery test
.\test-recovery.ps1 -CleanupAfterTest

# 5. Schedule (test mode)
.\schedule-backup-tasks.ps1 -WhatIf
```

All tests should complete in under 2 minutes.

---

**End of Summary**
