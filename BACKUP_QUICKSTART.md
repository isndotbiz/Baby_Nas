# Windows Backup Integration - Quick Start Guide

**Last Updated:** 2025-12-10
**Version:** 1.0
**Status:** Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Setup (5 Minutes)](#quick-setup-5-minutes)
4. [Detailed Setup Instructions](#detailed-setup-instructions)
5. [Veeam Configuration](#veeam-configuration)
6. [WSL Backup Configuration](#wsl-backup-configuration)
7. [Network Drive Mapping](#network-drive-mapping)
8. [Backup Verification](#backup-verification)
9. [Restoration Procedures](#restoration-procedures)
10. [Troubleshooting](#troubleshooting)
11. [Maintenance](#maintenance)
12. [Advanced Configuration](#advanced-configuration)

---

## Overview

This backup solution provides comprehensive, automated backup for Windows systems to Baby NAS (TrueNAS):

### What Gets Backed Up
- **Veeam Agent**: Full system backup (C:, D: drives) - Daily at 2:00 AM
- **WSL Distributions**: Linux subsystem backups - Weekly on Sundays at 1:00 AM
- **Retention**: 14-30 days (configurable)
- **Destination**: Baby NAS SMB shares (\\babynas\)

### Key Features
- Automated scheduling via Windows Task Scheduler
- Secure credential storage in Windows Credential Manager
- Comprehensive verification and health monitoring
- HTML reports with email notifications (optional)
- Easy restoration procedures
- Incremental backups to save space

---

## Prerequisites

### System Requirements
- Windows 10/11 or Windows Server 2016+
- Administrator privileges
- PowerShell 5.1 or later
- 20+ GB free disk space for backup cache
- Network connectivity to Baby NAS (10.0.0.89)

### Baby NAS Requirements
- TrueNAS Scale (installed and running)
- SMB shares configured:
  - `\\babynas\WindowsBackup`
  - `\\babynas\Veeam`
  - `\\babynas\WSLBackups`
- User account with read/write permissions

### Software Requirements
- **Veeam Agent for Windows** (FREE) - Download during setup
- **WSL2** (if backing up Linux distributions)
- **PowerShell Execution Policy**: RemoteSigned or Unrestricted

### Network Requirements
- SMB/CIFS enabled (port 445)
- Network connectivity to 10.0.0.89
- Firewall rules allowing SMB traffic

---

## Quick Setup (5 Minutes)

For experienced users who want to get started immediately:

### Step 1: Open PowerShell as Administrator
```powershell
# Right-click PowerShell icon → "Run as Administrator"
```

### Step 2: Navigate to Scripts Directory
```powershell
cd D:\workspace\True_Nas\windows-scripts
```

### Step 3: Set Execution Policy (if needed)
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### Step 4: Run Network Drive Setup
```powershell
.\network-drive-setup.ps1 -NASServer "babynas" -Username "admin"
# Enter password when prompted
```

### Step 5: Install and Configure Veeam
```powershell
.\veeam-setup.ps1 -BackupDestination "V:\" -BackupDrives "C:","D:"
# Follow download link if Veeam not installed
```

### Step 6: Test WSL Backup (if applicable)
```powershell
.\wsl-backup.ps1 -BackupPath "L:\" -RetentionDays 30
```

### Step 7: Schedule Tasks
```powershell
.\5-schedule-tasks.ps1
```

### Step 8: Verify Setup
```powershell
.\backup-verification.ps1 -VeeamPath "V:\" -WSLPath "L:\"
```

**Done!** Your backups are now configured and scheduled.

---

## Detailed Setup Instructions

### Phase 1: Preparation

#### 1.1 Verify Network Connectivity to Baby NAS

```powershell
# Test ping
Test-Connection -ComputerName babynas -Count 4

# Test SMB port
Test-NetConnection -ComputerName babynas -Port 445

# If using IP address instead
Test-Connection -ComputerName 10.0.0.89 -Count 4
```

**Expected Result:** All tests should succeed. If ping fails but SMB port is open, that's acceptable (ICMP may be blocked).

#### 1.2 Check PowerShell Version

```powershell
$PSVersionTable.PSVersion
# Should be 5.1 or higher
```

#### 1.3 Verify Administrator Privileges

```powershell
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# Should return: True
```

#### 1.4 Check Disk Space

```powershell
Get-PSDrive C, D | Select-Object Name, Used, Free, @{Name="SizeGB";Expression={[math]::Round($_.Used/1GB + $_.Free/1GB, 2)}}
```

**Requirement:** Ensure at least 20 GB free on C: drive for Veeam cache.

---

### Phase 2: Network Drive Mapping

The `network-drive-setup.ps1` script maps Baby NAS SMB shares to Windows drive letters.

#### 2.1 Basic Network Drive Setup

```powershell
# Open PowerShell as Administrator
cd D:\workspace\True_Nas\windows-scripts

# Run setup with default settings
.\network-drive-setup.ps1 -NASServer "babynas" -Username "admin"
```

**What happens:**
1. Tests connectivity to Baby NAS
2. Prompts for password (stored securely)
3. Maps drives:
   - `W:` → `\\babynas\WindowsBackup`
   - `V:` → `\\babynas\Veeam`
   - `L:` → `\\babynas\WSLBackups`
4. Tests read/write access
5. Saves credentials to Windows Credential Manager

#### 2.2 Advanced Options

```powershell
# Use IP address instead of hostname
.\network-drive-setup.ps1 -NASServer "10.0.0.89" -Username "admin"

# Skip WSL backup share
.\network-drive-setup.ps1 -SkipWSLBackup

# Force remap existing drives
.\network-drive-setup.ps1 -ForceRemap

# Test connectivity only (no mapping)
.\network-drive-setup.ps1 -TestOnly

# Custom drive letters
.\network-drive-setup.ps1 -WindowsBackupDrive "X:" -VeeamDrive "Y:" -WSLBackupDrive "Z:"
```

#### 2.3 Verify Mapping

```powershell
# Check mapped drives
Get-PSDrive W, V, L

# Test access
Test-Path V:\
Test-Path L:\

# View in File Explorer
explorer V:\
```

#### 2.4 Manual Mapping (if script fails)

```powershell
# Map Veeam drive
net use V: \\babynas\Veeam /user:admin PASSWORD /persistent:yes

# Map WSL drive
net use L: \\babynas\WSLBackups /user:admin PASSWORD /persistent:yes

# Map Windows Backup drive
net use W: \\babynas\WindowsBackup /user:admin PASSWORD /persistent:yes
```

---

### Phase 3: Veeam Agent Installation and Configuration

#### 3.1 Download Veeam Agent for Windows

The `veeam-setup.ps1` script will check if Veeam is installed and provide download instructions if needed.

```powershell
cd D:\workspace\True_Nas\windows-scripts
.\veeam-setup.ps1
```

**If Veeam is NOT installed**, the script will display:

```
DOWNLOAD INFORMATION:
  Product: Veeam Agent for Microsoft Windows (FREE)
  URL: https://www.veeam.com/windows-endpoint-server-backup-free.html

INSTALLATION STEPS:
  1. Visit the URL above in your web browser
  2. Click 'Download Free' and register/login (free account)
  3. Download 'Veeam Agent for Microsoft Windows'
  4. Run the installer with Administrator privileges
  5. Follow the installation wizard (accept defaults)
  6. Restart this script after installation completes
```

#### 3.2 Install Veeam (Manual Steps)

1. Visit https://www.veeam.com/windows-endpoint-server-backup-free.html
2. Create free Veeam account (or login)
3. Download installer (~300 MB)
4. Run installer as Administrator
5. Accept license agreement
6. Choose "Typical" installation
7. Wait 5-10 minutes for installation
8. Reboot if prompted

#### 3.3 Configure Veeam Backup Job

After Veeam is installed, run the setup script again:

```powershell
# Basic configuration
.\veeam-setup.ps1 -BackupDestination "V:\" -BackupDrives "C:","D:"

# Advanced configuration
.\veeam-setup.ps1 `
    -BackupDestination "V:\" `
    -BackupDrives "C:","D:" `
    -RetentionPoints 30 `
    -ScheduleTime "02:00" `
    -JobName "Windows-Daily-Backup" `
    -Compression "Optimal"
```

**Parameters:**
- `BackupDestination`: Where to store backups (V:\ = Baby NAS)
- `BackupDrives`: Which drives to backup (C: = system, D: = data)
- `RetentionPoints`: How many backup versions to keep (14-30 recommended)
- `ScheduleTime`: When to run backup (24-hour format, e.g., "02:00" = 2 AM)
- `Compression`: None, Dedupe, Optimal, High, Extreme (Optimal recommended)

#### 3.4 Manual Veeam Configuration (via GUI)

If PowerShell configuration fails, configure manually:

1. **Open Veeam Control Panel**
   - Press `Win + R`
   - Type: `control.exe /name Veeam.EndpointBackup`
   - Or search "Veeam Agent" in Start Menu

2. **Create Backup Job**
   - Click "Configure Backup" or "Add Job"
   - Job Name: `Windows-Daily-Backup`

3. **Select Backup Mode**
   - Choose: "Volume Level Backup"
   - Select drives: C: and D:

4. **Configure Destination**
   - Backup Mode: "Local or network shared folder"
   - Path: `V:\` (or `\\babynas\Veeam`)
   - Browse and enter credentials if prompted

5. **Set Backup Cache**
   - Cache location: `C:\VeeamCache` (default)
   - Cache size: 10-20 GB

6. **Advanced Options**
   - Compression Level: **Optimal**
   - Block Size: Local target (default)
   - Encryption: Optional (recommended for network)

7. **Configure Schedule**
   - Enable: **Daily backup**
   - Time: **02:00** (2:00 AM daily)
   - Retry: Enable (3 attempts, 10 min interval)

8. **Set Retention**
   - Keep: **14 restore points**
   - (Approximately 2 weeks of backups)

9. **Advanced Settings**
   - Application-aware processing: Enabled
   - VSS snapshot: Microsoft Software Provider
   - Email notifications: Configure if SMTP available

10. **Review and Finish**
    - Review all settings
    - Click "Finish"
    - Click "Backup Now" to test

#### 3.5 Verify Veeam Backup

```powershell
# Check Veeam service status
Get-Service VeeamEndpointBackupSvc

# Verify backup files
dir V:\

# Check Veeam logs
dir C:\ProgramData\Veeam\Endpoint

# Run verification script
.\backup-verification.ps1 -VeeamPath "V:\"
```

---

### Phase 4: WSL Backup Configuration

If you use Windows Subsystem for Linux (WSL), configure automated backups.

#### 4.1 Check WSL Installation

```powershell
# List WSL distributions
wsl --list --verbose

# Expected output: Ubuntu, Debian, etc.
# If nothing appears, WSL is not installed or has no distributions
```

#### 4.2 Run WSL Backup Manually

```powershell
# Basic backup
.\wsl-backup.ps1 -BackupPath "L:\" -RetentionDays 30

# Advanced backup
.\wsl-backup.ps1 `
    -BackupPath "L:\" `
    -RetentionDays 30 `
    -CompressionLevel "Optimal" `
    -VerifyBackups `
    -ExcludeDistros "docker-desktop","docker-desktop-data"
```

**Parameters:**
- `BackupPath`: Where to store backups (L:\ = Baby NAS)
- `RetentionDays`: How long to keep old backups (30 recommended)
- `CompressionLevel`: None, Fastest, Optimal, Maximum
- `VerifyBackups`: Test backup integrity after creation
- `ExcludeDistros`: Skip specific distributions (Docker is large and auto-managed)

#### 4.3 Verify WSL Backup

```powershell
# Check backup files
dir L:\

# View backup details
dir L:\ | Sort-Object LastWriteTime -Descending

# Verify specific backup
.\backup-verification.ps1 -WSLPath "L:\"
```

#### 4.4 Schedule WSL Backups

The `5-schedule-tasks.ps1` script creates a weekly scheduled task for WSL backups.

```powershell
# Create scheduled tasks
.\5-schedule-tasks.ps1

# Verify task created
Get-ScheduledTask -TaskName "WSL-Weekly-Backup"

# View task details
Get-ScheduledTaskInfo -TaskName "WSL-Weekly-Backup"

# Run task manually (test)
Start-ScheduledTask -TaskName "WSL-Weekly-Backup"
```

**Default Schedule:** Sundays at 1:00 AM

---

### Phase 5: Automated Scheduling

#### 5.1 Create Scheduled Tasks

```powershell
# Create all scheduled tasks
.\5-schedule-tasks.ps1

# Expected tasks:
# - WSL-Weekly-Backup (Sundays at 1:00 AM)
# - Backup-Health-Check (Daily at 8:00 AM)
```

#### 5.2 Verify Scheduled Tasks

```powershell
# List all backup-related tasks
Get-ScheduledTask | Where-Object {$_.TaskName -match "Backup|WSL"}

# View task properties
Get-ScheduledTask -TaskName "WSL-Weekly-Backup" | Format-List *

# Check task history
Get-ScheduledTaskInfo -TaskName "WSL-Weekly-Backup"
```

#### 5.3 Test Scheduled Tasks

```powershell
# Run WSL backup task manually
Start-ScheduledTask -TaskName "WSL-Weekly-Backup"

# Run health check task manually
Start-ScheduledTask -TaskName "Backup-Health-Check"

# Wait and check results
Start-Sleep -Seconds 10
Get-ScheduledTaskInfo -TaskName "WSL-Weekly-Backup"
```

#### 5.4 View Task Logs

```powershell
# View backup logs
dir C:\Logs\wsl-backup-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Read latest log
Get-Content (dir C:\Logs\wsl-backup-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

# View health check logs
dir C:\Logs\backup-health-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

---

## Veeam Configuration

### Understanding Veeam Backup Types

1. **Full Backup** (.vbk)
   - Complete copy of all selected data
   - First backup is always full
   - Periodic full backups for integrity

2. **Incremental Backup** (.vib)
   - Only changed data since last backup
   - Saves time and space
   - Daily backups after initial full

3. **Metadata** (.vbm)
   - Backup job metadata
   - Small files with backup information

### Veeam Backup Schedule

**Default Configuration:**
- **First Run:** Full backup (large, slow)
- **Daily:** Incremental backups (fast, small)
- **Weekly:** New full backup (recommended)
- **Time:** 2:00 AM (low system usage)

### Veeam Retention Policy

**Recommended Settings:**

| Use Case | Retention | Disk Space Required |
|----------|-----------|---------------------|
| Home User | 14 points | ~300-500 GB |
| Power User | 21 points | ~500-700 GB |
| Professional | 30 points | ~700-1000 GB |

**Formula:**
```
Required Space ≈ (Full Backup Size) + (Daily Changes × Retention Days)
```

### Veeam Performance Tuning

**Compression Level Comparison:**

| Level | Speed | Size Reduction | Use Case |
|-------|-------|----------------|----------|
| None | Fastest | 0% | Fast networks, large storage |
| Dedupe | Fast | 20-40% | Balanced performance |
| Optimal | Medium | 40-60% | **Recommended default** |
| High | Slow | 60-70% | Limited storage |
| Extreme | Slowest | 70-80% | Very limited storage |

**Recommendation:** Use "Optimal" for best balance of speed and space.

### Veeam Troubleshooting

#### Problem: Backup Job Fails with "Access Denied"

**Solution:**
```powershell
# Re-map network drive with credentials
.\network-drive-setup.ps1 -ForceRemap

# Or manually:
net use V: \\babynas\Veeam /user:admin PASSWORD /persistent:yes
```

#### Problem: Backup Job Slow

**Solutions:**
1. Change compression level to "Dedupe" or "None"
2. Increase network bandwidth
3. Use local cache (enabled by default)
4. Schedule during off-hours

#### Problem: Out of Disk Space

**Solutions:**
```powershell
# Reduce retention
# In Veeam GUI: Edit Job → Retention → Reduce restore points

# Or use V: drive space
dir V:\ | Sort-Object Length -Descending

# Delete old backups manually (careful!)
# Only delete .vib files older than retention period
```

---

## WSL Backup Configuration

### Understanding WSL Backups

WSL backups use `wsl --export` to create TAR archives:
- **Format:** Compressed TAR (.tar)
- **Contents:** Entire distribution filesystem
- **Size:** 2-20 GB per distribution (depends on usage)
- **Time:** 5-30 minutes per distribution

### WSL Backup Best Practices

1. **Exclude Docker Distributions**
   ```powershell
   .\wsl-backup.ps1 -ExcludeDistros "docker-desktop","docker-desktop-data"
   ```
   Docker distributions are large and auto-managed.

2. **Weekly Schedule**
   WSL distributions change slowly, weekly backups are sufficient.

3. **Retention: 30 Days**
   Keep 4-5 weekly backups for good coverage.

4. **Verify Backups**
   ```powershell
   .\wsl-backup.ps1 -VerifyBackups
   ```
   Occasionally test backup integrity.

### WSL Backup Troubleshooting

#### Problem: WSL Export Hangs

**Solution:**
```powershell
# Stop WSL
wsl --shutdown

# Wait 10 seconds
Start-Sleep -Seconds 10

# Try backup again
.\wsl-backup.ps1
```

#### Problem: Distribution Won't Stop

**Solution:**
```powershell
# Force terminate
wsl --terminate DISTRO_NAME

# Or shut down all WSL
wsl --shutdown
```

#### Problem: Backup Files Corrupt

**Solution:**
```powershell
# Verify backup integrity
.\backup-verification.ps1 -WSLPath "L:\" -TestRestoration

# Re-run backup
.\wsl-backup.ps1 -VerifyBackups
```

---

## Network Drive Mapping

### Understanding Drive Mapping

Drive mapping connects network shares (SMB) to Windows drive letters.

**Advantages:**
- Easy access via File Explorer
- Standard path for scripts (`V:\`)
- Persistent across reboots
- Credentials stored securely

### Persistent vs. Temporary Mapping

**Persistent** (recommended):
```powershell
net use V: \\babynas\Veeam /persistent:yes
```
- Reconnects automatically after reboot
- Credentials saved in Credential Manager

**Temporary**:
```powershell
net use V: \\babynas\Veeam /persistent:no
```
- Lost after reboot
- Good for testing

### Credential Management

Windows stores network credentials in **Credential Manager**.

**View stored credentials:**
```powershell
# PowerShell
cmdkey /list

# GUI
control /name Microsoft.CredentialManager
```

**Delete credentials:**
```powershell
cmdkey /delete:babynas
```

**Add credentials:**
```powershell
cmdkey /add:babynas /user:admin /pass:PASSWORD
```

### Network Drive Troubleshooting

#### Problem: Drive Disconnects After Reboot

**Solution:**
```powershell
# Re-map with persistent flag
.\network-drive-setup.ps1 -ForceRemap

# Verify persistence
net use
# Check "Persistent" column shows "Yes"
```

#### Problem: "Network Path Not Found"

**Solutions:**
1. Check Baby NAS is powered on
2. Test connectivity:
   ```powershell
   Test-Connection babynas
   Test-NetConnection babynas -Port 445
   ```
3. Try IP address instead:
   ```powershell
   .\network-drive-setup.ps1 -NASServer "10.0.0.89"
   ```
4. Check SMB is enabled on NAS

#### Problem: "Access Denied"

**Solutions:**
1. Check username/password
2. Verify user has permissions on NAS
3. Re-enter credentials:
   ```powershell
   .\network-drive-setup.ps1 -ForceRemap
   ```

---

## Backup Verification

### Understanding Backup Verification

The `backup-verification.ps1` script validates your backups:
- Checks backup age (alerts if too old)
- Verifies file integrity
- Tests restoration (optional)
- Monitors disk space
- Generates HTML reports

### Running Verification

```powershell
# Basic verification
.\backup-verification.ps1

# Full verification with restoration test
.\backup-verification.ps1 -TestRestoration

# Custom paths
.\backup-verification.ps1 -VeeamPath "V:\" -WSLPath "L:\"

# With email reporting
.\backup-verification.ps1 `
    -EmailReport `
    -SMTPServer "smtp.gmail.com" `
    -EmailTo "admin@example.com" `
    -EmailFrom "backup@example.com"
```

### Interpreting Results

**Exit Codes:**
- `0`: All backups healthy
- `1`: Critical errors found
- `2`: Warnings found (backups may be stale)

**Status Levels:**
- **HEALTHY**: All backups recent and accessible
- **WARNING**: Backups old or minor issues
- **CRITICAL**: Backups failed or inaccessible

### HTML Reports

Reports are saved to: `C:\Logs\backup-verification-report-YYYYMMDD-HHMMSS.html`

**Report Contents:**
- Overall backup health status
- Veeam backup status and size
- WSL backup status and size
- Disk space utilization
- Warnings and errors
- Detailed metrics

**Open report:**
```powershell
# Open latest report
$report = dir C:\Logs\backup-verification-report-*.html | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Start-Process $report.FullName
```

### Scheduled Verification

**Recommended:** Run verification daily at 8:00 AM (via scheduled task)

```powershell
# Check scheduled task
Get-ScheduledTask -TaskName "Backup-Health-Check"

# Run manually
Start-ScheduledTask -TaskName "Backup-Health-Check"
```

---

## Restoration Procedures

### Restoring from Veeam Backup

#### Full System Restoration

1. **Boot from Veeam Recovery Media**
   - Create recovery media: Veeam GUI → Tools → Recovery Media Creator
   - Boot from USB/ISO
   - Select "Bare Metal Recovery"

2. **Select Backup**
   - Choose backup location: `\\babynas\Veeam`
   - Enter network credentials if prompted
   - Select restore point (date/time)

3. **Configure Restoration**
   - Target disk: Select destination disk
   - Partition layout: Keep original or customize
   - Restore options: Verify defaults

4. **Start Restoration**
   - Click "Restore"
   - Wait 30-120 minutes (depends on data size)
   - Reboot when complete

#### File-Level Restoration

1. **Open Veeam Agent GUI**
   ```powershell
   control.exe /name Veeam.EndpointBackup
   ```

2. **Select "Restore Files"**
   - Choose backup job: "Windows-Daily-Backup"
   - Select restore point (date/time)

3. **Browse Backup**
   - Navigate to files/folders needed
   - Select items to restore

4. **Choose Restore Location**
   - Original location (overwrites)
   - Custom location (preserves existing)

5. **Start Restoration**
   - Click "Restore"
   - Wait for completion
   - Verify files

#### Volume-Level Restoration

1. **Open Veeam Agent GUI**
2. **Select "Restore Volumes"**
3. **Choose backup and restore point**
4. **Select volumes to restore** (C:, D:, etc.)
5. **Configure options:**
   - Restore mode: Replace or add
   - Power options: Reboot after restore
6. **Start restoration**

### Restoring WSL Distributions

#### Complete Distribution Restoration

```powershell
# List available WSL backups
dir L:\*.tar

# Import backup as new distribution
wsl --import DistroName "C:\WSL\DistroName" "L:\DistroName-20251210-010000.tar"

# Verify restoration
wsl -d DistroName

# Set as default (optional)
wsl --set-default DistroName
```

#### Restore Over Existing Distribution

```powershell
# CAUTION: This will DELETE the existing distribution!

# Unregister existing distribution
wsl --unregister Ubuntu

# Import backup
wsl --import Ubuntu "C:\WSL\Ubuntu" "L:\Ubuntu-20251210-010000.tar"

# Verify
wsl -d Ubuntu
```

#### Restore to Different Name

```powershell
# Import as "Ubuntu-Restored" (keeps original)
wsl --import Ubuntu-Restored "C:\WSL\Ubuntu-Restored" "L:\Ubuntu-20251210-010000.tar"

# Run restored distribution
wsl -d Ubuntu-Restored

# Compare with original
wsl -d Ubuntu
```

#### Restore Specific Files from WSL Backup

```powershell
# Extract TAR to temporary location
mkdir C:\Temp\WSLExtract
cd C:\Temp\WSLExtract

# Use 7-Zip or tar command
tar -xf L:\Ubuntu-20251210-010000.tar

# Navigate and copy needed files
explorer C:\Temp\WSLExtract

# Cleanup when done
cd \
Remove-Item C:\Temp\WSLExtract -Recurse -Force
```

### Testing Restorations

**Best Practice:** Test restorations quarterly to ensure backups work.

```powershell
# Test Veeam file restoration
# Restore a test file to verify it works

# Test WSL restoration
.\backup-verification.ps1 -TestRestoration
# Automatically tests WSL backup restoration
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: Script "Cannot be loaded because running scripts is disabled"

**Error:**
```
.\veeam-setup.ps1 : File cannot be loaded because running scripts is disabled on this system.
```

**Solution:**
```powershell
# Check current policy
Get-ExecutionPolicy

# Set to RemoteSigned (recommended)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Or Bypass (less secure)
Set-ExecutionPolicy Bypass -Scope Process -Force
```

#### Issue: "Access is denied" when creating scheduled tasks

**Error:**
```
Register-ScheduledTask : Access is denied (HRESULT 0x80070005)
```

**Solution:**
```powershell
# Run PowerShell as Administrator
# Right-click PowerShell → "Run as Administrator"

# Then run script again
.\5-schedule-tasks.ps1
```

#### Issue: Network drive not accessible

**Symptoms:**
- "Network path not found"
- "Cannot find drive X:"

**Solutions:**

1. **Check Baby NAS is reachable:**
   ```powershell
   Test-Connection babynas -Count 4
   Test-NetConnection babynas -Port 445
   ```

2. **Try IP address instead of hostname:**
   ```powershell
   .\network-drive-setup.ps1 -NASServer "10.0.0.89"
   ```

3. **Check SMB services on Windows:**
   ```powershell
   Get-Service LanmanWorkstation, LanmanServer
   # Both should be "Running"
   ```

4. **Verify firewall:**
   ```powershell
   # Check if SMB is blocked
   Test-NetConnection babynas -Port 445
   ```

5. **Re-map drive with credentials:**
   ```powershell
   .\network-drive-setup.ps1 -ForceRemap
   ```

#### Issue: Veeam backup job fails

**Symptoms:**
- Backup status: Failed
- Error in Veeam logs

**Solutions:**

1. **Check destination accessibility:**
   ```powershell
   Test-Path V:\
   dir V:\
   ```

2. **Verify disk space:**
   ```powershell
   Get-PSDrive V | Select-Object Free, Used
   ```

3. **Review Veeam logs:**
   ```powershell
   dir C:\ProgramData\Veeam\Endpoint\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
   notepad (dir C:\ProgramData\Veeam\Endpoint\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
   ```

4. **Restart Veeam service:**
   ```powershell
   Restart-Service VeeamEndpointBackupSvc
   ```

5. **Re-run backup manually:**
   - Open Veeam GUI
   - Select job
   - Click "Backup Now"

#### Issue: WSL backup hangs or fails

**Symptoms:**
- Script hangs during `wsl --export`
- "The process cannot access the file" error

**Solutions:**

1. **Stop all WSL instances:**
   ```powershell
   wsl --shutdown
   Start-Sleep -Seconds 10
   ```

2. **Close applications accessing WSL:**
   - Docker Desktop
   - VS Code with WSL extensions
   - Terminal windows

3. **Retry backup:**
   ```powershell
   .\wsl-backup.ps1
   ```

4. **Check WSL status:**
   ```powershell
   wsl --status
   wsl --list --verbose
   ```

5. **Restart LxssManager service:**
   ```powershell
   Restart-Service LxssManager
   ```

#### Issue: Backup verification reports stale backups

**Symptoms:**
- "Backup is older than X hours"
- Status: STALE

**Solutions:**

1. **Check scheduled tasks:**
   ```powershell
   Get-ScheduledTask | Where-Object {$_.TaskName -match "Backup"}
   Get-ScheduledTaskInfo -TaskName "WSL-Weekly-Backup"
   ```

2. **Run backup manually:**
   ```powershell
   # WSL
   .\wsl-backup.ps1

   # Veeam (via GUI or scheduled task)
   Start-ScheduledTask -TaskName "Veeam-Backup-Job"
   ```

3. **Check task history:**
   ```powershell
   Get-ScheduledTask -TaskName "WSL-Weekly-Backup" | Get-ScheduledTaskInfo
   ```

4. **Review logs:**
   ```powershell
   dir C:\Logs\wsl-backup-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
   notepad (dir C:\Logs\wsl-backup-*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
   ```

---

## Maintenance

### Daily Maintenance (Automated)

**No action required** - Scheduled tasks handle daily operations:
- Veeam backup: 2:00 AM daily
- Health check: 8:00 AM daily

**Review health check logs:**
```powershell
# Check latest health report
$report = dir C:\Logs\backup-verification-report-*.html | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Start-Process $report.FullName
```

### Weekly Maintenance

**Sunday mornings (automated):**
- WSL backup: 1:00 AM Sundays

**Manual checks (5 minutes):**

1. **Review backup logs:**
   ```powershell
   dir C:\Logs\*.log | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-7)} | Sort-Object LastWriteTime -Descending
   ```

2. **Check disk space:**
   ```powershell
   Get-PSDrive C, V, L | Select-Object Name, @{Name="FreeGB";Expression={[math]::Round($_.Free/1GB,2)}}, @{Name="UsedGB";Expression={[math]::Round($_.Used/1GB,2)}}
   ```

3. **Verify scheduled tasks:**
   ```powershell
   Get-ScheduledTask | Where-Object {$_.TaskName -match "Backup|WSL"} | Get-ScheduledTaskInfo
   ```

### Monthly Maintenance

**First day of month (30 minutes):**

1. **Full backup verification:**
   ```powershell
   .\backup-verification.ps1 -TestRestoration -DetailedLogging
   ```

2. **Review all backup logs:**
   ```powershell
   # Summarize backup activity
   dir C:\Logs\wsl-backup-*.log | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-30)}
   dir C:\Logs\backup-verification-*.log | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-30)}
   ```

3. **Check Veeam backup chain:**
   - Open Veeam GUI
   - View backup history
   - Verify no broken chains

4. **Review disk space trends:**
   ```powershell
   # Check backup growth
   $veeamSize = (dir V:\ -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
   $wslSize = (dir L:\*.tar | Measure-Object -Property Length -Sum).Sum / 1GB
   Write-Host "Veeam backups: $([math]::Round($veeamSize, 2)) GB"
   Write-Host "WSL backups: $([math]::Round($wslSize, 2)) GB"
   ```

5. **Test file restoration:**
   - Restore a test file from Veeam backup
   - Verify integrity

### Quarterly Maintenance

**Every 3 months (2 hours):**

1. **Full system restoration test:**
   - Test Veeam bare metal recovery (optional, advanced)
   - Or test volume-level restoration

2. **WSL restoration test:**
   ```powershell
   # Test restore WSL distribution
   .\backup-verification.ps1 -TestRestoration
   ```

3. **Update documentation:**
   - Review and update this guide
   - Document any configuration changes

4. **Review retention policies:**
   - Adjust if disk space issues
   - Increase retention if more storage available

### Annual Maintenance

**Once per year:**

1. **Disaster recovery drill:**
   - Full system restoration test
   - Document time and issues

2. **Review and optimize:**
   - Evaluate backup performance
   - Adjust schedules if needed
   - Update Baby NAS configuration

3. **Update Veeam:**
   - Check for Veeam Agent updates
   - Install and test

4. **Audit credentials:**
   - Rotate Baby NAS passwords
   - Update stored credentials

---

## Advanced Configuration

### Email Notifications

Configure SMTP for automated email reports:

```powershell
# Setup verification with email
.\backup-verification.ps1 `
    -EmailReport `
    -SMTPServer "smtp.gmail.com" `
    -EmailTo "admin@example.com" `
    -EmailFrom "backup@windows-pc.local"
```

**Gmail SMTP Configuration:**
1. Enable 2-factor authentication
2. Generate app password
3. Use settings:
   - Server: smtp.gmail.com
   - Port: 587 (TLS)
   - Username: your-email@gmail.com
   - Password: app-password

### Custom Backup Schedules

Modify scheduled tasks:

```powershell
# Get existing task
$task = Get-ScheduledTask -TaskName "WSL-Weekly-Backup"

# Modify schedule (example: daily instead of weekly)
$trigger = New-ScheduledTaskTrigger -Daily -At "1:00AM"
Set-ScheduledTask -TaskName "WSL-Weekly-Backup" -Trigger $trigger

# Verify change
Get-ScheduledTaskInfo -TaskName "WSL-Weekly-Backup"
```

### Multiple Backup Destinations

Configure backup to multiple locations:

```powershell
# Primary: Baby NAS
.\wsl-backup.ps1 -BackupPath "L:\"

# Secondary: External USB
.\wsl-backup.ps1 -BackupPath "E:\WSLBackups"

# Cloud: Mapped cloud drive (OneDrive, Google Drive, etc.)
.\wsl-backup.ps1 -BackupPath "C:\Users\YourName\OneDrive\Backups\WSL"
```

### Backup Encryption

Enable Veeam encryption for sensitive data:

1. Open Veeam GUI
2. Edit backup job
3. Advanced Settings → Encryption
4. Enable encryption
5. Set strong password
6. **IMPORTANT:** Store password securely (backup won't be readable without it)

### Custom Retention Policies

Adjust retention based on needs:

**Aggressive (save space):**
```powershell
.\wsl-backup.ps1 -RetentionDays 14  # Keep 2 weeks
```

**Conservative (more history):**
```powershell
.\wsl-backup.ps1 -RetentionDays 90  # Keep 3 months
```

### Bandwidth Throttling

Limit network usage during backups:

**Veeam GUI:**
1. Edit backup job
2. Advanced Settings → Network
3. Enable bandwidth throttling
4. Set limit (e.g., 50 Mbps)

**Windows QoS:**
```powershell
# Limit SMB traffic to 50% of bandwidth
New-NetQosPolicy -Name "Backup-Throttle" -SMB -ThrottleRateActionBitsPerSecond 50MB
```

---

## Appendix

### Script Reference

| Script | Purpose | Run As | Frequency |
|--------|---------|--------|-----------|
| `network-drive-setup.ps1` | Map Baby NAS shares | Admin | Once |
| `veeam-setup.ps1` | Configure Veeam | Admin | Once |
| `wsl-backup.ps1` | Backup WSL distributions | Admin | Weekly (automated) |
| `backup-verification.ps1` | Verify backups | Admin | Daily (automated) |
| `5-schedule-tasks.ps1` | Create scheduled tasks | Admin | Once |

### Log File Locations

| Log Type | Location |
|----------|----------|
| WSL Backup | `C:\Logs\wsl-backup-YYYYMMDD-HHMMSS.log` |
| Backup Verification | `C:\Logs\backup-verification-YYYYMMDD-HHMMSS.log` |
| Network Drive Setup | `C:\Logs\network-drive-setup-YYYYMMDD-HHMMSS.log` |
| Veeam Setup | `C:\Logs\veeam-setup-YYYYMMDD-HHMMSS.log` |
| Veeam Agent | `C:\ProgramData\Veeam\Endpoint\*.log` |

### HTML Report Locations

| Report Type | Location |
|-------------|----------|
| Backup Verification | `C:\Logs\backup-verification-report-YYYYMMDD-HHMMSS.html` |
| WSL Backup | `C:\Logs\wsl-backup-report-YYYYMMDD-HHMMSS.html` |

### Default Schedules

| Task | Frequency | Time | Run Level |
|------|-----------|------|-----------|
| Veeam Backup | Daily | 2:00 AM | System |
| WSL Backup | Weekly (Sunday) | 1:00 AM | Administrator |
| Health Check | Daily | 8:00 AM | Administrator |

### Disk Space Requirements

| Component | Initial | Daily Growth | 30-Day Total |
|-----------|---------|--------------|--------------|
| Veeam Full | 200-400 GB | 2-10 GB | 260-700 GB |
| WSL Backups | 5-20 GB | 0.5-2 GB | 15-80 GB |
| Logs | 1 MB | 0.5 MB | 15 MB |
| **Total** | **200-420 GB** | **2-12 GB** | **275-780 GB** |

### Network Requirements

| Protocol | Port | Direction | Required |
|----------|------|-----------|----------|
| SMB/CIFS | 445 | Outbound | Yes |
| NetBIOS | 137-139 | Outbound | Optional |
| ICMP | N/A | Outbound | Optional |

### Exit Codes

| Code | Meaning | Action Required |
|------|---------|-----------------|
| 0 | Success | None |
| 1 | Critical error | Review logs, fix issue |
| 2 | Warning | Review warnings, may need attention |

### Support Resources

| Resource | URL |
|----------|-----|
| Veeam Knowledge Base | https://www.veeam.com/knowledge-base.html |
| Veeam Support | https://www.veeam.com/support.html |
| WSL Documentation | https://docs.microsoft.com/windows/wsl/ |
| TrueNAS Forums | https://www.truenas.com/community/ |
| PowerShell Docs | https://docs.microsoft.com/powershell/ |

---

## Quick Reference Commands

### Essential Commands

```powershell
# Map network drives
.\network-drive-setup.ps1 -NASServer "babynas" -Username "admin"

# Setup Veeam
.\veeam-setup.ps1 -BackupDestination "V:\" -BackupDrives "C:","D:"

# Backup WSL
.\wsl-backup.ps1 -BackupPath "L:\" -RetentionDays 30

# Verify backups
.\backup-verification.ps1 -VeeamPath "V:\" -WSLPath "L:\"

# Schedule tasks
.\5-schedule-tasks.ps1

# View logs
dir C:\Logs\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Open latest report
Start-Process (dir C:\Logs\*-report-*.html | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

---

**End of Quick Start Guide**

For additional help, review logs in `C:\Logs\` or consult the support resources listed above.
