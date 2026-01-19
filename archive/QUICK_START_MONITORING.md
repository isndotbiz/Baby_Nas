# Quick Start: Baby NAS Monitoring & Automation

## 5-Minute Setup Guide

### Step 1: Verify Prerequisites (30 seconds)

Open PowerShell as Administrator:

```powershell
# Check you're an admin
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# Should return: True

# Check Baby NAS VM exists and is running
Get-VM | Where-Object { $_.Name -like "*Baby*" }
# Should show: TrueNAS-BabyNAS with State: Running

# Check SSH keys configured
Test-Path "$env:USERPROFILE\.ssh\id_babynas"
# Should return: True
```

If any checks fail, fix them first before continuing.

---

### Step 2: Test Monitoring (1 minute)

```powershell
cd D:\workspace\True_Nas\windows-scripts
.\monitor-baby-nas.ps1
```

**Expected Output:**
```
╔══════════════════════════════════════════════════════════════════════════╗
║                    Baby NAS Health Monitor                               ║
╚══════════════════════════════════════════════════════════════════════════╝

═══ Hyper-V VM Status ═══
✓ VM 'TrueNAS-BabyNAS' is Running
✓ Auto-start: Enabled

═══ Network Connectivity ═══
✓ Baby NAS reachable at 192.168.1.100
✓ Main NAS reachable at 10.0.0.89

═══ Baby NAS Pool Health ═══
✓ Pool 'tank': ONLINE
✓ Capacity: 45% used

OVERALL STATUS: OK
```

If you see errors, see Troubleshooting section below.

---

### Step 3: Run Health Check (1 minute)

```powershell
.\daily-health-check.ps1
```

This runs all 9 health checks and generates a report. Look for:
- **OVERALL HEALTH STATUS: HEALTHY** (green)

If you see warnings or errors, note them for later review.

---

### Step 4: Test Backup (1 minute)

```powershell
# WhatIf mode - no actual changes
.\backup-workspace.ps1 -WhatIf
```

This shows what would be backed up without making changes. Review the output and ensure:
- Source path exists (D:\workspace)
- Destination is detected or accessible
- No critical errors

---

### Step 5: Schedule Automated Tasks (1 minute)

```powershell
# Test first
.\schedule-backup-tasks.ps1 -WhatIf

# If test looks good, create for real
.\schedule-backup-tasks.ps1
```

This creates 4 scheduled tasks:
- ✓ Daily workspace backup (12:30 AM)
- ✓ Daily health check (8:00 AM)
- ✓ Weekly recovery test (Sunday 6:00 AM)
- ✓ Hourly monitor (disabled by default)

**Answer "y" when prompted to test the health check task.**

---

### Step 6: Verify Setup (1 minute)

```powershell
# View scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like 'BabyNAS-*' }

# Check log directories were created
Test-Path C:\Logs\workspace-backup
Test-Path C:\Logs\daily-health-checks
Test-Path C:\Logs\recovery-tests
```

All should return **True**.

---

## Done! What Happens Now?

### Automatic Operations

| Time | Task | What Happens |
|------|------|--------------|
| **12:30 AM** | Workspace Backup | D:\workspace → Baby NAS |
| **8:00 AM** | Health Check | Full system validation |
| **Sunday 6:00 AM** | Recovery Test | Verify backup integrity |

### Check Status Anytime

```powershell
# Quick status check
cd D:\workspace\True_Nas\windows-scripts
.\monitor-baby-nas.ps1

# View recent health check
Get-ChildItem C:\Logs\daily-health-checks | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 30

# View last backup info
Get-Content "\\babynas\WindowsBackup\d-workspace\.last-backup-info.txt"
```

---

## Troubleshooting Common Issues

### Issue: "Baby NAS IP not detected"

**Fix:** Specify IP manually:
```powershell
.\monitor-baby-nas.ps1 -BabyNasIP 192.168.1.100
.\schedule-backup-tasks.ps1 -BabyNasIP 192.168.1.100
```

---

### Issue: "Cannot establish SSH connection"

**Fix:** Reconfigure SSH keys:
```powershell
.\2-configure-baby-nas.ps1 -BabyNasIP 192.168.1.100
```

Follow prompts to copy SSH key to Baby NAS.

---

### Issue: "SMB shares not accessible"

**Fix 1:** Try different paths:
```powershell
Test-Path "\\192.168.1.100\WindowsBackup"  # By IP
Test-Path "\\babynas\WindowsBackup"        # By name
```

**Fix 2:** Check SMB service on Baby NAS:
```powershell
ssh root@babynas "systemctl status smb"
# Should show: active (running)
```

**Fix 3:** Verify shares in TrueNAS web UI:
- Open browser: `https://babynas-ip/`
- Navigate to: Shares → Windows (SMB) Shares
- Verify: WindowsBackup and Veeam shares are enabled

---

### Issue: "Pool is DEGRADED"

**Check pool status:**
```powershell
ssh root@babynas "zpool status tank"
```

**Common causes:**
- Resilver in progress (wait for completion)
- Disk error (check output for failed disks)
- Normal maintenance (check if scrub is running)

If disk failed, replace and resilver will auto-start.

---

## Daily Operations

### Morning Routine (30 seconds)

```powershell
# Quick health check
.\monitor-baby-nas.ps1

# Or review automated health check log from 8 AM
Get-ChildItem C:\Logs\daily-health-checks | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 20
```

Look for:
- ✓ All green (healthy)
- ⚠ Yellow warnings (review and address)
- ✗ Red errors (immediate attention needed)

---

## Weekly Tasks (5 minutes)

```powershell
# Review Sunday recovery test
Get-ChildItem C:\Logs\recovery-tests | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content

# Check scheduled tasks ran successfully
Get-ScheduledTask | Where-Object { $_.TaskName -like 'BabyNAS-*' } | ForEach-Object {
    $info = Get-ScheduledTaskInfo -TaskName $_.TaskName
    [PSCustomObject]@{
        Task = $_.TaskName
        LastRun = $info.LastRunTime
        Result = $info.LastTaskResult
        NextRun = $info.NextRunTime
    }
} | Format-Table -AutoSize
```

All "Result" should be **0** (success).

---

## Manual Backup Trigger

Need to backup right now?

```powershell
cd D:\workspace\True_Nas\windows-scripts
.\backup-workspace.ps1
```

Or trigger scheduled task:
```powershell
Start-ScheduledTask -TaskName 'BabyNAS-DailyWorkspaceBackup'
```

---

## View Task History

```powershell
# Health check task
Get-ScheduledTaskInfo -TaskName 'BabyNAS-DailyHealthCheck'

# All backup tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like 'BabyNAS-*' } | ForEach-Object {
    $info = Get-ScheduledTaskInfo -TaskName $_.TaskName
    Write-Host "`n$($_.TaskName):" -ForegroundColor Cyan
    Write-Host "  Last Run: $($info.LastRunTime)"
    Write-Host "  Next Run: $($info.NextRunTime)"
    Write-Host "  Last Result: $($info.LastTaskResult) $(if($info.LastTaskResult -eq 0){'(Success)'}else{'(Failed)'})"
}
```

---

## Enable Email Notifications (Optional)

### Gmail Example

1. **Create App Password:**
   - Go to: https://myaccount.google.com/apppasswords
   - Create app password for "Windows Backup Scripts"
   - Copy the 16-character password

2. **Edit Health Check Script:**
   ```powershell
   notepad D:\workspace\True_Nas\windows-scripts\daily-health-check.ps1
   ```

3. **Find and uncomment the Send-MailMessage section (around line 265):**
   ```powershell
   # Change FROM:
   <#
   Send-MailMessage `
       -To $EmailTo `
   #>

   # TO:
   $password = ConvertTo-SecureString "your-app-password-here" -AsPlainText -Force
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

4. **Test:**
   ```powershell
   .\daily-health-check.ps1 -SendEmail -EmailTo "your-email@gmail.com"
   ```

5. **Update Scheduled Task:**
   ```powershell
   .\schedule-backup-tasks.ps1 -RemoveExisting -EmailTo "your-email@gmail.com"
   ```

You'll now receive daily health reports at 8:00 AM!

---

## Advanced: Enable Hourly Monitoring

Only enable if you want continuous monitoring (adds minimal load):

```powershell
Enable-ScheduledTask -TaskName 'BabyNAS-HourlyMonitor'
```

This runs `monitor-baby-nas.ps1` every hour and logs results.

To disable:
```powershell
Disable-ScheduledTask -TaskName 'BabyNAS-HourlyMonitor'
```

---

## Customization Examples

### Change Backup Time

Option 1: Task Scheduler GUI
1. Open Task Scheduler
2. Find: BabyNAS-DailyWorkspaceBackup
3. Right-click → Properties → Triggers → Edit
4. Change time

Option 2: Recreate task with new schedule
1. Edit `schedule-backup-tasks.ps1`
2. Change the time in task definition
3. Run: `.\schedule-backup-tasks.ps1 -RemoveExisting`

---

### Exclude Additional Directories from Backup

Edit `backup-workspace.ps1` around line 33:

```powershell
$ExcludeDirs = @(
    "node_modules",
    ".git",
    ".vscode",
    # Add your exclusions here:
    "large-media-files",
    "temp-downloads",
    "iso-images"
)
```

Test changes:
```powershell
.\backup-workspace.ps1 -WhatIf
```

---

## Get Help

### Documentation
- **Full Manual:** `MONITORING_AND_AUTOMATION_README.md`
- **Script Details:** `SCRIPTS_SUMMARY.md`
- **Baby NAS Setup:** `BABY_NAS_IMPLEMENTATION_PLAN.md`

### Check Logs
```powershell
# Most recent health check
Get-ChildItem C:\Logs\daily-health-checks | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content

# Most recent backup
Get-ChildItem C:\Logs\workspace-backup | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50

# Most recent recovery test
Get-ChildItem C:\Logs\recovery-tests | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
```

---

## Recovery Example

### Restore a Single File

```powershell
# Browse backup share
explorer "\\babynas\WindowsBackup\d-workspace"

# Or browse snapshots
explorer "\\babynas\WindowsBackup\.zfs\snapshot"

# Copy file back
Copy-Item "\\babynas\WindowsBackup\d-workspace\project\file.txt" -Destination "D:\workspace\project\"
```

### Restore Entire Project

```powershell
# Restore specific folder
robocopy "\\babynas\WindowsBackup\d-workspace\MyProject" "D:\workspace\MyProject" /MIR /R:3 /W:5
```

### Full Workspace Restore (Disaster Recovery)

```powershell
# CAUTION: This will overwrite D:\workspace with backup
robocopy "\\babynas\WindowsBackup\d-workspace" "D:\workspace" /MIR /R:3 /W:5 /MT:8

# Or from Main NAS if Baby NAS failed
robocopy "\\10.0.0.89\backup\babynas\windows-backups\d-workspace" "D:\workspace" /MIR /R:3 /W:5 /MT:8
```

---

## Uninstall / Cleanup

### Remove Scheduled Tasks

```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like 'BabyNAS-*' } | Unregister-ScheduledTask -Confirm:$false
```

### Remove Logs (Optional)

```powershell
Remove-Item C:\Logs\workspace-backup -Recurse -Force
Remove-Item C:\Logs\daily-health-checks -Recurse -Force
Remove-Item C:\Logs\recovery-tests -Recurse -Force
```

Scripts themselves remain in `D:\workspace\True_Nas\windows-scripts\` for future use.

---

## Quick Reference Card

**Print or save this section for daily use:**

### Essential Commands
```powershell
# Go to scripts
cd D:\workspace\True_Nas\windows-scripts

# Quick health check
.\monitor-baby-nas.ps1

# Full health report
.\daily-health-check.ps1

# Backup now
.\backup-workspace.ps1

# Test recovery
.\test-recovery.ps1 -CleanupAfterTest

# View scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like 'BabyNAS-*' }

# Check last backup
Get-Content "\\babynas\WindowsBackup\d-workspace\.last-backup-info.txt"

# View recent logs
Get-ChildItem C:\Logs\daily-health-checks | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 20
```

### Key Paths
- **Scripts:** `D:\workspace\True_Nas\windows-scripts\`
- **Logs:** `C:\Logs\`
- **Backups:** `\\babynas\WindowsBackup\d-workspace\`
- **Snapshots:** `\\babynas\WindowsBackup\.zfs\snapshot\`

### Status Indicators
- ✓ Green = Healthy
- ⚠ Yellow = Warning
- ✗ Red = Error

### Exit Codes
- 0 = Success
- 1 = Critical error
- 2 = Warning

---

**Setup Complete!**

Your Baby NAS infrastructure now has comprehensive monitoring and automated backups.

**Next Steps:**
1. Monitor logs for first week
2. Review Sunday recovery test results
3. Adjust schedules/thresholds as needed
4. Set up email notifications (optional)
5. Read full documentation for advanced features

---

**Created:** 2025-12-10
**Version:** 1.0
**Status:** Production Ready

**Questions?** See `MONITORING_AND_AUTOMATION_README.md` for complete documentation.
