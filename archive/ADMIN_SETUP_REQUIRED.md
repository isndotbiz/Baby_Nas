# ADMINISTRATOR SETUP REQUIRED

## Quick Start Guide for Completing Backup Automation

---

## STEP 1: Open PowerShell as Administrator

Right-click PowerShell icon -> "Run as Administrator"

---

## STEP 2: Update Backup Drive Paths

The scripts are configured for X: drive, but F: drive is available and recommended.

### Edit the following files:

**File: D:\workspace\True_Nas\windows-scripts\5-schedule-tasks.ps1**
- Line 19: Change `X:\WSLBackups` to `F:\WSLBackups`

**File: D:\workspace\True_Nas\windows-scripts\4-monitor-backups.ps1**
- Line 8: Change `X:\VeeamBackups` to `F:\VeeamBackups`
- Line 11: Change `X:\WSLBackups` to `F:\WSLBackups`

---

## STEP 3: Create Backup Directories

```powershell
# Run in Administrator PowerShell
New-Item -Path "F:\VeeamBackups" -ItemType Directory -Force
New-Item -Path "F:\WSLBackups" -ItemType Directory -Force
```

---

## STEP 4: Create Scheduled Tasks

```powershell
# Run in Administrator PowerShell
cd D:\workspace\True_Nas\windows-scripts
.\5-schedule-tasks.ps1
```

**Expected Output:**
- "Created: WSL-Weekly-Backup (Sundays at 1:00 AM)"
- "Created: Backup-Health-Check (Daily at 8:00 AM)"

---

## STEP 5: Verify Scheduled Tasks

```powershell
Get-ScheduledTask -TaskName "WSL-Weekly-Backup"
Get-ScheduledTask -TaskName "Backup-Health-Check"
```

---

## STEP 6: Test WSL Backup Manually

```powershell
# Run in Administrator PowerShell
D:\workspace\True_Nas\windows-scripts\3-backup-wsl.ps1 -BackupPath "F:\WSLBackups"
```

**Expected:** Backups of WSL distributions created in F:\WSLBackups\

---

## STEP 7: Download and Install Veeam Agent

1. **Download:** https://www.veeam.com/windows-endpoint-server-backup-free.html
2. **Install:** Run installer as Administrator
3. **Register:** Free account required

---

## STEP 8: Configure Veeam Backup Job

### Configuration Settings:

- **Backup Mode:** Entire Computer or Volume Level
- **Volumes to backup:**
  - C: (System drive)
  - D: (Data drive - Cruical-2tb)
- **Destination:** Local folder -> `F:\VeeamBackups`
- **Schedule:** Daily at 2:00 AM
- **Retention:** Keep 14 restore points (2 weeks)
- **Options:**
  - Compression: Standard
  - Application-aware processing: Enabled
  - VSS provider: Microsoft Software
  - Verification: Enabled

---

## STEP 9: Verify Health Monitoring

```powershell
# Run health check
D:\workspace\True_Nas\windows-scripts\4-monitor-backups.ps1 -VeeamBackupPath "F:\VeeamBackups" -WSLBackupPath "F:\WSLBackups"
```

**Expected Status:** HEALTHY with all checks showing OK

---

## STEP 10: Test Scheduled Tasks

```powershell
# Manually trigger tasks to test
Start-ScheduledTask -TaskName "WSL-Weekly-Backup"
Start-ScheduledTask -TaskName "Backup-Health-Check"

# Check results in logs
Get-Content C:\Logs\wsl-backup-*.log | Select-Object -Last 50
Get-Content C:\Logs\backup-health-*.log | Select-Object -Last 50
```

---

## Verification Checklist

- [ ] Backup directories created on F: drive
- [ ] WSL-Weekly-Backup scheduled task exists and is Ready
- [ ] Backup-Health-Check scheduled task exists and is Ready
- [ ] WSL backup completes successfully
- [ ] Veeam Agent installed
- [ ] Veeam backup job configured and running
- [ ] Health monitoring shows HEALTHY status
- [ ] Log files being created in C:\Logs\

---

## Quick Verification Commands

```powershell
# One-liner to check everything
Get-ScheduledTask | Where-Object {$_.TaskName -match "Backup|WSL"} | Select-Object TaskName, State, @{N='NextRun';E={(Get-ScheduledTaskInfo $_).NextRunTime}} | Format-Table -AutoSize

# Check backup directories
dir F:\VeeamBackups
dir F:\WSLBackups

# Check logs
dir C:\Logs | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Check TrueNAS connection
Test-Connection 10.0.0.89 -Count 2
```

---

## Support Resources

**Veeam Documentation:**
- Agent Guide: https://helpcenter.veeam.com/docs/agentforwindows/

**PowerShell Resources:**
- Task Scheduler: https://docs.microsoft.com/powershell/module/scheduledtasks/
- WSL Management: https://docs.microsoft.com/windows/wsl/

**Local Documentation:**
- Full Report: D:\workspace\True_Nas\windows-scripts\BACKUP_SETUP_REPORT.md
- Scripts: D:\workspace\True_Nas\windows-scripts\

---

## Estimated Time

- Drive path updates: 5 minutes
- Directory creation: 1 minute
- Scheduled task creation: 2 minutes
- WSL backup test: 5-15 minutes (depending on distribution size)
- Veeam download/install: 10-20 minutes
- Veeam configuration: 10 minutes
- Testing and verification: 10 minutes

**Total: ~45-65 minutes**

---

*Quick Setup Guide - 2025-12-09*
