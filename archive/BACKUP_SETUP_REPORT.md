# Windows Backup Automation Setup Report

**Date:** 2025-12-09
**Status:** Partially Completed - Administrator Privileges Required

---

## Executive Summary

Attempted to set up Windows backup automation using PowerShell scripts. Some tasks completed successfully, but scheduled task creation requires Administrator privileges. Manual intervention needed to complete setup.

---

## Setup Steps Executed

### 1. Log Directory Creation - SUCCESS
**Status:** COMPLETED
**Command:** `mkdir C:\Logs -ErrorAction SilentlyContinue`
**Result:** Log directory successfully created at `C:\Logs`

### 2. Schedule Tasks Script - PARTIAL FAILURE
**Status:** REQUIRES ADMINISTRATOR
**Script:** `D:\workspace\True_Nas\windows-scripts\5-schedule-tasks.ps1`
**Error:** `Register-ScheduledTask : Access is denied (HRESULT 0x80070005)`

**Tasks Attempted:**
- WSL-Weekly-Backup (Sundays at 1:00 AM)
- Backup-Health-Check (Daily at 8:00 AM)

**Resolution Required:** Run PowerShell as Administrator and re-execute:
```powershell
# Run as Administrator
D:\workspace\True_Nas\windows-scripts\5-schedule-tasks.ps1
```

### 3. WSL Backup Script - FAILED (Missing Drive)
**Status:** CONFIGURATION REQUIRED
**Script:** `D:\workspace\True_Nas\windows-scripts\3-backup-wsl.ps1`
**Error:** `Cannot find drive. A drive with the name 'X' does not exist`

**Issue:** Script configured for X: drive, but available drives are:
- C: (499GB total, 272GB free)
- D: Cruical-2tb (2TB total, 557GB free)
- F: ExFAT (1TB total, 700GB free)

**WSL Distributions Detected:**
- Ubuntu
- docker-desktop (3 instances detected)

**Resolution Required:** Either:
1. Create X: drive mapping, OR
2. Modify scripts to use existing drive (recommended: F: drive)

**Recommended Configuration:**
```powershell
# Use F: drive for backups
D:\workspace\True_Nas\windows-scripts\3-backup-wsl.ps1 -BackupPath "F:\WSLBackups"
```

### 4. Backup Health Monitoring - SUCCESS (with warnings)
**Status:** PARTIALLY WORKING
**Script:** `D:\workspace\True_Nas\windows-scripts\4-monitor-backups.ps1`
**Result:** Script executes successfully but reports configuration issues

**Health Check Results:**
- Veeam Local Backup: NOT CONFIGURED (X:\VeeamBackups path not found)
- WSL Backup: NOT CONFIGURED (X:\WSLBackups path not found)
- Backup Drive Space: Not found
- TrueNAS Network: OK (10.0.0.89 reachable)
- Scheduled Tasks: OK (7 enabled, 0 disabled)

**Overall Status:** HEALTHY (with configuration warnings)
**Log File:** `C:\Logs\backup-health-20251209-054608.log`

### 5. Scheduled Task Verification - UNABLE TO COMPLETE
**Status:** BLOCKED BY STEP 2
**Reason:** Tasks not created due to permission denied

**Existing Backup-Related Tasks:** 7 tasks found (enabled)
- Tasks not specifically created by our script
- Appears to be pre-existing scheduled tasks

---

## Available System Resources

### Drive Configuration
| Drive | Label | Total Size | Free Space | Usage |
|-------|-------|-----------|------------|-------|
| C: | System | 499GB | 272GB (54%) | System/Programs |
| D: | Cruical-2tb | 2TB | 557GB (27%) | Data/Workspace |
| F: | ExFAT | 1TB | 700GB (70%) | **RECOMMENDED FOR BACKUPS** |

### Network Status
- TrueNAS Server: 10.0.0.89 (REACHABLE)
- Network connectivity: VERIFIED

---

## Veeam Agent for Windows Installation

### Download Information
**Product:** Veeam Agent for Windows FREE
**Download URL:** https://www.veeam.com/windows-endpoint-server-backup-free.html

**Installation Steps:**
1. Visit download URL
2. Register/login to Veeam account (free)
3. Download Veeam Agent for Microsoft Windows
4. Run installer with Administrator privileges
5. Follow installation wizard

### Recommended Veeam Configuration

**Backup Job Configuration:**
- **Source Drives:** C: (System) and D: (Data)
- **Destination:** F:\VeeamBackups (or configured backup drive)
- **Schedule:** Daily at 2:00 AM
- **Retention Policy:** 14 restore points (2 weeks)
- **Compression:** Enable (standard)
- **Verification:** Enable post-backup verification

**Advanced Settings:**
- Application-aware processing: Enabled
- VSS snapshot provider: Microsoft Software
- Pre/post job scripts: None (initially)
- Email notifications: Configure SMTP if available

---

## Required Actions to Complete Setup

### CRITICAL - Administrator Privileges Required

**Action 1: Create Scheduled Tasks**
```powershell
# Open PowerShell as Administrator
# Navigate to scripts directory
cd D:\workspace\True_Nas\windows-scripts

# Run schedule tasks script
.\5-schedule-tasks.ps1

# Verify tasks created
Get-ScheduledTask | Where-Object {$_.TaskName -like "*Backup*" -or $_.TaskName -like "*WSL*"}
```

**Action 2: Configure Backup Drive Paths**

**Option A - Map X: Drive (as scripted):**
```powershell
# Map network drive or create subst drive
subst X: F:\Backups
# Or use net use for network mapping
```

**Option B - Update Scripts to Use F: Drive (RECOMMENDED):**

Update these scripts to use F: drive instead of X:
- `5-schedule-tasks.ps1` - Line 19: Change `X:\WSLBackups` to `F:\WSLBackups`
- `4-monitor-backups.ps1` - Line 8: Change `X:\VeeamBackups` to `F:\VeeamBackups`
- `4-monitor-backups.ps1` - Line 11: Change `X:\WSLBackups` to `F:\WSLBackups`

**Action 3: Create Backup Directories**
```powershell
# Create backup directories on F: drive
New-Item -Path "F:\VeeamBackups" -ItemType Directory -Force
New-Item -Path "F:\WSLBackups" -ItemType Directory -Force
```

**Action 4: Test WSL Backup Manually**
```powershell
# Run as Administrator
D:\workspace\True_Nas\windows-scripts\3-backup-wsl.ps1 -BackupPath "F:\WSLBackups"
```

**Action 5: Install Veeam Agent**
1. Download from: https://www.veeam.com/windows-endpoint-server-backup-free.html
2. Install with Administrator privileges
3. Configure backup job per recommendations above
4. Set schedule: Daily at 2:00 AM
5. Set retention: 14 restore points

**Action 6: Verify Health Monitoring**
```powershell
# Run health check
D:\workspace\True_Nas\windows-scripts\4-monitor-backups.ps1 -VeeamBackupPath "F:\VeeamBackups" -WSLBackupPath "F:\WSLBackups"

# Verify scheduled task
Get-ScheduledTask -TaskName "Backup-Health-Check" | Get-ScheduledTaskInfo
```

---

## Scheduled Tasks Summary

### Planned Tasks (Pending Administrator Execution)

**Task 1: WSL-Weekly-Backup**
- Schedule: Weekly, Sundays at 1:00 AM
- Action: Execute `3-backup-wsl.ps1`
- Target: WSL distribution backups
- Run Level: Highest (Administrator)
- Settings: Start when available, require network

**Task 2: Backup-Health-Check**
- Schedule: Daily at 8:00 AM
- Action: Execute `4-monitor-backups.ps1`
- Target: Monitor all backup systems
- Run Level: Highest (Administrator)
- Settings: Start when available, require network

### Manual Task Execution Commands

```powershell
# Test tasks manually (after creation)
Start-ScheduledTask -TaskName "WSL-Weekly-Backup"
Start-ScheduledTask -TaskName "Backup-Health-Check"

# View task details
Get-ScheduledTask -TaskName "WSL-Weekly-Backup" | Get-ScheduledTaskInfo
Get-ScheduledTask -TaskName "Backup-Health-Check" | Get-ScheduledTaskInfo

# Open Task Scheduler GUI
taskschd.msc
```

---

## Log Files

All backup operations log to `C:\Logs\`:
- WSL Backups: `wsl-backup-YYYYMMDD-HHMMSS.log`
- Health Checks: `backup-health-YYYYMMDD-HHMMSS.log`

**Recent Log Files:**
- `C:\Logs\wsl-backup-20251209-054549.log` (Failed - missing X: drive)
- `C:\Logs\backup-health-20251209-054608.log` (Success - configuration warnings)

---

## Troubleshooting

### Common Issues

**Issue 1: "Access is denied" when creating scheduled tasks**
- **Cause:** Script not run as Administrator
- **Solution:** Right-click PowerShell, select "Run as Administrator"

**Issue 2: "Cannot find drive. A drive with the name 'X' does not exist"**
- **Cause:** X: drive not mapped or configured
- **Solution:** Update scripts to use F: drive or create X: drive mapping

**Issue 3: WSL backup fails**
- **Cause:** Must run as Administrator, WSL requires elevated privileges
- **Solution:** Ensure scheduled task runs with "Highest" run level

**Issue 4: Veeam backups not detected**
- **Cause:** Veeam not installed or not configured
- **Solution:** Install Veeam Agent and create backup job

### Verification Commands

```powershell
# Check scheduled tasks
Get-ScheduledTask | Where-Object {$_.TaskName -match "Backup|WSL"}

# Check WSL distributions
wsl --list --verbose

# Check backup directories
Test-Path "F:\VeeamBackups"
Test-Path "F:\WSLBackups"

# Check TrueNAS connectivity
Test-Connection -ComputerName 10.0.0.89 -Count 4

# Run manual health check
D:\workspace\True_Nas\windows-scripts\4-monitor-backups.ps1 -VeeamBackupPath "F:\VeeamBackups" -WSLBackupPath "F:\WSLBackups"
```

---

## Next Steps

1. **IMMEDIATE:** Run scheduled task creation script as Administrator
2. **IMMEDIATE:** Update backup paths in scripts (X: to F:)
3. **IMMEDIATE:** Create backup directories on F: drive
4. **TODAY:** Download and install Veeam Agent for Windows
5. **TODAY:** Configure Veeam backup job with recommended settings
6. **TODAY:** Test WSL backup manually
7. **TODAY:** Verify health monitoring scheduled task
8. **WEEKLY:** Monitor backup logs in C:\Logs\
9. **MONTHLY:** Review backup retention and disk space usage

---

## Success Criteria

- [ ] Scheduled tasks created successfully (requires Administrator)
- [x] Log directory created (C:\Logs)
- [ ] WSL backup executes successfully
- [ ] Veeam Agent installed
- [ ] Veeam backup job configured (daily at 2:00 AM)
- [x] Health monitoring script executes
- [ ] Health monitoring scheduled task active
- [ ] TrueNAS connectivity verified (COMPLETED)
- [ ] Backup drives configured and accessible

**Current Progress:** 3/9 (33%)

---

## Scripts Reference

| Script | Purpose | Status |
|--------|---------|--------|
| `1-identify-drives.ps1` | Identify available drives | Not executed |
| `2-initialize-single-drive.ps1` | Initialize backup drive | Not executed |
| `3-backup-wsl.ps1` | Backup WSL distributions | Failed (no X: drive) |
| `4-monitor-backups.ps1` | Health check monitoring | Working (warnings) |
| `5-schedule-tasks.ps1` | Create scheduled tasks | Failed (needs Admin) |

---

## Documentation

**Report Location:** D:\workspace\True_Nas\windows-scripts\BACKUP_SETUP_REPORT.md

**Related Documentation:**
- PowerShell scripts: D:\workspace\True_Nas\windows-scripts\
- TrueNAS configs: D:\workspace\True_Nas\
- Log files: C:\Logs\

---

## Contact & Support

**Veeam Support:**
- Website: https://www.veeam.com/support.html
- Knowledge Base: https://www.veeam.com/knowledge-base.html

**PowerShell Resources:**
- Scheduled Tasks: https://docs.microsoft.com/powershell/module/scheduledtasks/
- WSL Commands: https://docs.microsoft.com/windows/wsl/

---

*Report generated: 2025-12-09 05:46:09*
*System: Windows (MINGW32_NT-6.2)*
*Working Directory: D:\workspace\True_Nas*
