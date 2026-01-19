# Comprehensive Backup System Deployment Guide

## Overview

This guide provides complete instructions for deploying three integrated backup systems targeting Baby NAS (172.21.203.18) and Bare Metal (10.0.0.89) TrueNAS servers.

**Deployment Includes:**
1. Veeam Agent for Windows (local system backup)
2. Phone Backup Infrastructure (SMB share for mobile devices)
3. Time Machine for Mac (automated Mac backups)

---

## Quick Start

### Option 1: Automated Complete Deployment (Recommended)

```powershell
# Run as Administrator
.\AUTOMATED-BACKUP-SETUP.ps1
```

This script will:
- Guide you through interactive configuration
- Deploy all three systems in correct order
- Verify each system
- Generate comprehensive report

### Option 2: Individual System Deployment

Deploy systems separately as needed:

```powershell
# Veeam Agent only
.\DEPLOY-VEEAM-COMPLETE.ps1

# Phone Backups only
.\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1

# Time Machine (run on Mac)
./DEPLOY-TIME-MACHINE-MAC.sh

# Verify all systems
.\VERIFY-ALL-BACKUPS.ps1
```

---

## System Requirements

### Windows System (for Veeam and Phone Backups)
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.0 or later
- Administrator privileges
- Network access to Baby NAS (172.21.203.18)
- At least 10 GB free disk space

### Mac System (for Time Machine)
- macOS 10.7 or later
- Network access to Bare Metal (10.0.0.89)
- Administrator/sudo privileges
- SSH configured (optional, for remote deployment)

---

## Script Details

### 1. DEPLOY-VEEAM-COMPLETE.ps1

**Purpose:** Automate Veeam Agent installation and configuration

**Features:**
- Detects Veeam installation (downloads if needed)
- Maps \\baby.isn.biz\Veeam network share
- Creates daily backup jobs
- Sets 1:00 AM schedule
- Configures 7-day retention
- Tests backup destination connectivity
- Generates deployment report

**Usage:**

```powershell
# Basic deployment (interactive)
.\DEPLOY-VEEAM-COMPLETE.ps1

# Silent deployment with custom parameters
.\DEPLOY-VEEAM-COMPLETE.ps1 `
    -BabyNASIP 172.21.203.18 `
    -BackupDrives "C:","D:","E:" `
    -RetentionDays 14 `
    -ScheduleTime "23:00" `
    -NoGUI

# With network credentials
.\DEPLOY-VEEAM-COMPLETE.ps1 `
    -Username "administrator" `
    -Password "P@ssw0rd" `
    -NoGUI
```

**Parameters:**
- `-BabyNASIP` - IP of Baby NAS (default: 172.21.203.18)
- `-BabyNASHostname` - Hostname (default: baby.isn.biz)
- `-VeeamSharePath` - Share path (default: \\baby.isn.biz\Veeam)
- `-BackupDrives` - Drives to backup (default: C:, D:)
- `-RetentionDays` - Days to keep backups (default: 7)
- `-ScheduleTime` - Daily schedule time (default: 01:00)
- `-Username` - SMB username
- `-Password` - SMB password
- `-NoGUI` - Skip interactive prompts
- `-SkipInstallation` - Skip Veeam installation check
- `-SkipNetworkTest` - Skip network connectivity test

**Expected Output:**

```
========================================================================
Veeam Agent Deployment - Complete Configuration
========================================================================

[2024-12-10 10:30:15] [INFO] Starting Veeam deployment
[2024-12-10 10:30:15] [INFO] Checking Veeam Installation...
[2024-12-10 10:30:16] [SUCCESS] Veeam Agent service found: Running
[2024-12-10 10:30:17] [INFO] Testing network connectivity to 172.21.203.18...
[2024-12-10 10:30:18] [SUCCESS] Network connectivity OK
[2024-12-10 10:30:19] [INFO] Testing SMB share: \\baby.isn.biz\Veeam
[2024-12-10 10:30:20] [SUCCESS] SMB share access verified
[2024-12-10 10:30:21] [INFO] Available space in repository: 2457.84 GB
[2024-12-10 10:30:22] [SUCCESS] Creating Veeam backup job

Veeam Installation: ✓ OK
Network Connectivity: ✓ OK
SMB Share Access: ✓ OK
Backup Job Configuration: ✓ AUTOMATED

Log file: C:\Logs\VEEAM-DEPLOYMENT-20241210-103015.log
Report file: C:\Logs\VEEAM-DEPLOYMENT-Report-20241210-103015.html
```

**Troubleshooting:**

| Issue | Solution |
|-------|----------|
| "Veeam Agent not installed" | Download from https://www.veeam.com/windows-endpoint-server-backup-free.html |
| "Network share not accessible" | Verify VPN/network connectivity, check firewall rules |
| "Write permission denied" | Check SMB share permissions on TrueNAS |
| "Service not running" | Enable Veeam service: `net start VeeamEndpointBackupSvc` |

---

### 2. DEPLOY-PHONE-BACKUPS-WINDOWS.ps1

**Purpose:** Configure Windows as phone backup server via SMB

**Features:**
- Maps \\baby.isn.biz\PhoneBackups share
- Verifies 500GB quota
- Creates device folders (Galaxy-S24, iPhone, iPad)
- Tests write permissions
- Optimizes SMB performance
- Configures firewall rules
- Generates configuration report

**Usage:**

```powershell
# Basic deployment
.\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1

# Custom quota and drive letter
.\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1 `
    -QuotaGB 1000 `
    -DriveLetters "X","Y","Z"

# Silent deployment
.\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1 `
    -BabyNASIP 172.21.203.18 `
    -Username "admin" `
    -Password "P@ssw0rd" `
    -NoGUI
```

**Parameters:**
- `-BabyNASIP` - Baby NAS IP (default: 172.21.203.18)
- `-BabyNASHostname` - Hostname (default: baby.isn.biz)
- `-PhoneBackupShare` - Share path (default: \\baby.isn.biz\PhoneBackups)
- `-QuotaGB` - Expected quota (default: 500)
- `-Username` - SMB username
- `-Password` - SMB password
- `-DriveLetters` - Available drive letters (default: X, Y, Z)
- `-CreateDeviceFolders` - Auto-create device folders (default: true)
- `-NoGUI` - Skip interactive prompts

**Expected Output:**

```
======================================================================
Phone Backup Deployment - Windows SMB Configuration
======================================================================

[2024-12-10 10:35:20] [INFO] Testing connectivity to 172.21.203.18...
[2024-12-10 10:35:21] [SUCCESS] Connectivity OK
[2024-12-10 10:35:22] [INFO] Available drive letter found: X
[2024-12-10 10:35:23] [SUCCESS] SMB share mounted successfully: X:
[2024-12-10 10:35:24] [SUCCESS] Write permissions verified
[2024-12-10 10:35:25] [INFO] Total Space: 512.50 GB
[2024-12-10 10:35:26] [INFO] Used Space: 50.25 GB
[2024-12-10 10:35:27] [INFO] Free Space: 462.25 GB
[2024-12-10 10:35:28] [SUCCESS] Created folder: Galaxy-S24-Ultra
[2024-12-10 10:35:29] [SUCCESS] Created folder: iPhone-15-Pro
[2024-12-10 10:35:30] [SUCCESS] SMB optimization complete

Network Connectivity: ✓ OK
SMB Share Access: ✓ OK (X:)
Write Permissions: ✓ OK
Device Folders: ✓ 5 folders created
Available Space: 462.25 GB / 500 GB

Mounted at: X:\PhoneBackups
Log file: C:\Logs\PHONE-BACKUPS-DEPLOYMENT-20241210-103520.log
Report file: C:\Logs\PHONE-BACKUPS-DEPLOYMENT-Report-20241210-103520.html
```

**Device Folders Created:**
- Galaxy-S24-Ultra
- Galaxy-S24
- iPhone-15-Pro
- iPhone-15
- iPad

**Phone Configuration Instructions:**

**Android (Galaxy S24 Ultra):**
1. Install "Synology Drive" or "Nextcloud" from Google Play
2. Connect to SMB: \\172.21.203.18\PhoneBackups
3. Select Galaxy-S24-Ultra folder
4. Enable auto-sync for camera/gallery

**iPhone:**
1. Install "SMB Client Pro" or "Nextcloud" from App Store
2. Connect to SMB: \\172.21.203.18\PhoneBackups
3. Select iPhone-15-Pro folder
4. Enable automatic backup

**Troubleshooting:**

| Issue | Solution |
|-------|----------|
| "No available drive letters" | Free up drive letter: `net use * /delete /yes` |
| "Share not accessible" | Ping 172.21.203.18, check firewall SMB port (445) |
| "Permission denied" | Verify TrueNAS share permissions, ensure user has write access |

---

### 3. DEPLOY-TIME-MACHINE-MAC.sh

**Purpose:** Configure macOS Time Machine for TrueNAS backup

**Features:**
- Mounts \\baremetal.isn.biz\TimeMachine SMB share
- Configures Time Machine backup destination
- Sets hourly backup schedule
- Tests network connectivity
- Verifies mount point access
- Generates deployment report

**Usage (on Mac):**

```bash
# Make script executable
chmod +x DEPLOY-TIME-MACHINE-MAC.sh

# Run deployment
./DEPLOY-TIME-MACHINE-MAC.sh

# With debug output
bash -x DEPLOY-TIME-MACHINE-MAC.sh
```

**Expected Output:**

```
======================================================================
Time Machine Configuration for TrueNAS
======================================================================

[2024-12-10 10:40:15] [INFO] Starting Time Machine deployment
[2024-12-10 10:40:16] [INFO] Testing network connectivity to 10.0.0.89...
[2024-12-10 10:40:17] [SUCCESS] Network connectivity OK
[2024-12-10 10:40:18] [INFO] Mounting SMB share to /Volumes/TimeMachine-Backup...
[2024-12-10 10:40:20] [SUCCESS] SMB share mounted successfully
[2024-12-10 10:40:21] [INFO] Testing write permissions...
[2024-12-10 10:40:22] [SUCCESS] Write permissions verified
[2024-12-10 10:40:23] [INFO] Checking available space...
[2024-12-10 10:40:24] [INFO] Available space: 5324 GB
[2024-12-10 10:40:25] [INFO] Configuring Time Machine...
[2024-12-10 10:40:26] [SUCCESS] Backup schedule configured (hourly interval)

Network Connectivity:    ✓ OK
SMB Share Access:        ✓ OK
Write Permissions:       ✓ OK
Configuration:           ✓ COMPLETE

Mount Point:  /Volumes/TimeMachine-Backup
Log File:     /Users/username/Library/Logs/DEPLOY-TIME-MACHINE-MAC-20241210-104015.log
```

**Manual Time Machine Configuration:**

If automatic configuration fails:

1. Open System Preferences/Settings
2. Navigate to Time Machine
3. Click "Add Disk..." or "Select Disk..."
4. Select "TimeMachine-Backup" from list
5. Click "Use for Time Machine"
6. Enable "Back Up Automatically"

**Monitor Backup Status:**

```bash
# View current backup status
tmutil status

# Monitor backup in real-time
log stream --predicate 'process == "backupd"' --level debug

# Trigger manual backup
sudo tmutil startbackup

# List backup destinations
tmutil destinationinfo -X

# Check recent backups
tmutil latestbackup
```

**Troubleshooting:**

| Issue | Solution |
|-------|----------|
| "Permission denied" | Run with `sudo`: `sudo ./DEPLOY-TIME-MACHINE-MAC.sh` |
| "Mount failed" | Check SMB: `mount_smbfs //baremetal.isn.biz/TimeMachine /Volumes/TimeMachine-Backup` |
| "Backup not starting" | Check Time Machine prefs, verify mount: `mount \| grep TimeMachine` |
| "Low disk warnings" | Increase share quota on TrueNAS (currently targets 5TB+) |

---

### 4. VERIFY-ALL-BACKUPS.ps1

**Purpose:** Comprehensive verification of all backup systems

**Features:**
- Tests network connectivity to all systems
- Verifies SMB share accessibility
- Checks Veeam service status
- Validates phone backup devices
- Checks data integrity
- Reports storage usage
- Generates detailed HTML report

**Usage:**

```powershell
# Quick verification
.\VERIFY-ALL-BACKUPS.ps1

# Detailed with data integrity tests
.\VERIFY-ALL-BACKUPS.ps1 -DetailedReport -TestDataIntegrity

# Custom thresholds
.\VERIFY-ALL-BACKUPS.ps1 `
    -BabyNASIP 172.21.203.18 `
    -BareMetalIP 10.0.0.89 `
    -AlertThresholdGB 100

# Email report
.\VERIFY-ALL-BACKUPS.ps1 `
    -EmailReport `
    -SMTPServer "mail.example.com" `
    -EmailTo "admin@example.com"
```

**Expected Output:**

```
======================================================================
Testing Network Connectivity
======================================================================

[2024-12-10 11:00:15] [INFO] Testing Baby NAS (172.21.203.18)...
[2024-12-10 11:00:16] [SUCCESS] Baby NAS is reachable
[2024-12-10 11:00:17] [INFO] Testing Bare Metal (10.0.0.89)...
[2024-12-10 11:00:18] [SUCCESS] Bare Metal is reachable

======================================================================
Verifying Veeam Backup System
======================================================================

[2024-12-10 11:00:19] [INFO] Checking Veeam backup status...
[2024-12-10 11:00:20] [SUCCESS] Veeam service status: Running
[2024-12-10 11:00:21] [INFO] Testing SMB share: \\baby.isn.biz\Veeam
[2024-12-10 11:00:22] [SUCCESS] Veeam share is accessible
[2024-12-10 11:00:23] [INFO] Space: 2450.32 GB free / 2500 GB total (2.0% used)

======================================================================
Verifying Phone Backup System
======================================================================

[2024-12-10 11:00:24] [INFO] Testing SMB share: \\baby.isn.biz\PhoneBackups
[2024-12-10 11:00:25] [SUCCESS] Phone Backups share is accessible
[2024-12-10 11:00:26] [INFO] Space: 462.25 GB free / 500 GB total (7.6% used)
[2024-12-10 11:00:27] [SUCCESS] Device Galaxy-S24-Ultra: OK (524 files, 38.50 GB)
[2024-12-10 11:00:28] [SUCCESS] Device iPhone-15-Pro: OK (1024 files, 42.75 GB)

======================================================================
Verification Summary
======================================================================

Baby NAS (172.21.203.18):        ✓ OK
Bare Metal (10.0.0.89):          ✓ OK
Veeam Service:                   ✓ RUNNING
Veeam Backups:                   ✓ OK
Phone Backups:                   ✓ OK
Configured Devices:              5 folders

Report:  C:\Logs\BACKUP-VERIFICATION-Report-20241210-110015.html
Log:     C:\Logs\BACKUP-VERIFICATION-20241210-110015.log
```

---

### 5. AUTOMATED-BACKUP-SETUP.ps1

**Purpose:** Master orchestration script for complete deployment

**Features:**
- Interactive configuration wizard
- Validates prerequisites
- Orchestrates all three deployments
- Tracks execution status
- Generates consolidated report
- Step-by-step guidance
- Color-coded status indicators

**Usage:**

```powershell
# Interactive complete setup (recommended)
.\AUTOMATED-BACKUP-SETUP.ps1

# Silent deployment (all systems)
.\AUTOMATED-BACKUP-SETUP.ps1 `
    -Username "administrator" `
    -Password "P@ssw0rd" `
    -NoGUI

# Deploy specific systems only
.\AUTOMATED-BACKUP-SETUP.ps1 `
    -DeployVeeam $true `
    -DeployPhoneBackups $true `
    -DeployTimeMachine $false
```

**Interactive Configuration Flow:**

```
Step 1: Validating Prerequisites
  • PowerShell version check
  • Network connectivity test
  • Disk space verification

Step 2: Configuring Backup Deployment
  • Enter SMB credentials
  • Select systems to deploy
  • Confirm network settings

Step 3: Deploying Veeam Agent
  • Check installation
  • Configure backup job
  • Set schedule (1:00 AM daily)

Step 4: Deploying Phone Backup
  • Mount SMB share
  • Create device folders
  • Optimize SMB settings

Step 5: Deploying Time Machine
  • Display Mac configuration instructions
  • Generate deployment script

Step 6: Verifying Backup Systems
  • Test all connectivity
  • Verify job configurations
  • Generate comprehensive report
```

**Expected Timeline:**

- Veeam Deployment: 2-5 minutes
- Phone Backup Deployment: 1-2 minutes
- Time Machine Setup: Manual on Mac
- Verification: 1-2 minutes
- **Total: 5-10 minutes** (excluding Mac setup)

---

## Network Configuration

### Required Network Access

| System | Source | Destination | Port | Service |
|--------|--------|-------------|------|---------|
| Windows | 172.21.x.x | 172.21.203.18 | 445 | SMB (Veeam) |
| Windows | 172.21.x.x | 172.21.203.18 | 445 | SMB (Phone) |
| Mac | 10.x.x.x | 10.0.0.89 | 445 | SMB (Time Machine) |

### Firewall Rules

**Windows Defender Firewall (inbound SMB):**

```powershell
# Enable SMB port 445
New-NetFirewallRule -DisplayName "SMB-In-445" `
    -Direction Inbound -Protocol tcp -LocalPort 445 -Action Allow

# Enable SMB port 139
New-NetFirewallRule -DisplayName "SMB-In-139" `
    -Direction Inbound -Protocol tcp -LocalPort 139 -Action Allow
```

**TrueNAS SMB Configuration:**

```
Services > SMB (CIFS)
- Enable SMB
- Min Protocol Version: SMB2
- Max Protocol Version: SMB3
- Security Policy: Recommended
- DNS Domain: isn.biz
```

---

## Backup Scheduling

### Veeam Daily Schedule

**Default:** 1:00 AM (01:00)

To modify:
1. Open Veeam Endpoint Backup Control Panel
2. Select backup job
3. Edit > Schedule
4. Change time as needed
5. Apply changes

### Phone Backup Schedule

Phone backup apps vary, but typically offer:
- Hourly automatic sync
- Daily scheduled backup
- On-demand manual backup
- WiFi-only option (recommended)

### Time Machine Schedule

**Default:** Hourly automatic backups

```bash
# Modify backup interval (in minutes)
defaults write /Library/Preferences/com.apple.TimeMachine.plist BackupInterval -int 120
killall -HUP backupd
```

---

## Storage Quotas

### Baby NAS Quotas

| Share | Quota | Current Usage | Recommendation |
|-------|-------|----------------|-----------------|
| Veeam | 2.5 TB | ~50 GB | Monitor monthly |
| PhoneBackups | 500 GB | ~90 GB | Expand to 1TB |

### Bare Metal Quota

| Share | Quota | Current Usage | Recommendation |
|-------|-------|----------------|-----------------|
| TimeMachine | 5 TB | ~500 GB | Maintain current |

---

## Troubleshooting Guide

### Common Issues

#### 1. Network Connectivity Problems

**Symptom:** "Network share not accessible"

```powershell
# Test connectivity
ping 172.21.203.18
ping 10.0.0.89

# Test SMB port
Test-NetConnection -ComputerName baby.isn.biz -Port 445

# Verify DNS
nslookup baby.isn.biz
nslookup baremetal.isn.biz
```

**Solutions:**
- Check VPN connection
- Verify firewall rules allow SMB (port 445)
- Confirm network cables are connected
- Restart network adapter: `ipconfig /renew`

#### 2. SMB Share Mounting Issues

**Symptom:** "Failed to mount SMB share"

```powershell
# List existing connections
net use

# Remove existing connections
net use * /delete /yes

# Manual mount with debugging
$credential = Get-Credential
New-PSDrive -Name "Test" -PSProvider "FileSystem" -Root "\\baby.isn.biz\Veeam" `
    -Credential $credential -Verbose
```

**Solutions:**
- Verify share exists on TrueNAS
- Check SMB share permissions
- Verify username/password
- Enable SMB legacy protocols if needed

#### 3. Permission Denied Errors

**Symptom:** "Access denied" when writing to share

**TrueNAS Fix:**
1. Navigate to Shares > Windows (SMB)
2. Edit share > Advanced Options
3. Verify user has read/write permissions
4. Check "Restrict Symbolic Links": Disabled
5. Verify "Unix Permissions Mode": 0755 or 0777

```bash
# SSH into TrueNAS
ssh admin@172.21.203.18

# Check share permissions
zfs get permissions pool/datasets/share
chmod -R 777 /mnt/pool/share
```

#### 4. Veeam Service Issues

**Symptom:** "Veeam service not running"

```powershell
# Check service status
Get-Service VeeamEndpointBackupSvc

# Start service
Start-Service VeeamEndpointBackupSvc

# Check service startup type
Get-Service VeeamEndpointBackupSvc | Select StartType

# Change to automatic
Set-Service VeeamEndpointBackupSvc -StartupType Automatic
```

#### 5. Time Machine Backup Failures

**Symptom:** "Time Machine backup incomplete"

```bash
# Check current status
tmutil status

# Verify mount
mount | grep TimeMachine

# Remount share
sudo mount -t smbfs //baremetal.isn.biz/TimeMachine /Volumes/TimeMachine-Backup

# Check logs
log stream --predicate 'process == "backupd"' --level debug
```

**Solutions:**
- Ensure Mac stays connected to network during backup
- Disable sleep during backup: System Preferences > Energy Saver
- Exclude large temporary folders: System Preferences > Time Machine > Options
- Verify sufficient space available

---

## Performance Optimization

### Veeam Performance

```powershell
# Monitor backup progress
Get-EventLog -LogName Application -Source "*Veeam*" -Newest 20

# Check backup cache
dir "C:\VeeamCache"

# Optimize compression (in job settings)
# Recommended: "Optimal" (balance speed/size)
```

### SMB Performance Tuning

```powershell
# Windows Registry optimization
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
    /v EnableBandwidthThrottling /t REG_DWORD /d 0 /f

reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
    /v Smb2CreditsMin /t REG_DWORD /d 128 /f

reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
    /v Smb2CreditsMax /t REG_DWORD /d 2048 /f

# Restart networking
net stop LanmanServer
net start LanmanServer
```

### Mac Time Machine Optimization

```bash
# Exclude temporary/cache folders
defaults write com.apple.TimeMachine ExcludedVolumes -array
tmutil addexclusion /var/tmp
tmutil addexclusion /var/cache
tmutil addexclusion ~/Library/Caches

# Verify exclusions
tmutil listexclusions

# Disable Spotlight indexing (optional)
mdutil -i off /Volumes/TimeMachine-Backup
```

---

## Log File Locations

| System | Log Location | Retention |
|--------|--------------|-----------|
| Veeam | C:\Logs\*VEEAM*.log | 30 days |
| Phone Backups | C:\Logs\*PHONE*.log | 30 days |
| Time Machine | ~/Library/Logs/*DEPLOY*.log | 30 days |
| Verification | C:\Logs\*VERIFY*.log | 90 days |

---

## Maintenance Schedule

### Weekly Tasks
- [ ] Verify all backup systems running
- [ ] Check available space on shares
- [ ] Review backup logs for errors

### Monthly Tasks
- [ ] Run VERIFY-ALL-BACKUPS.ps1
- [ ] Test backup restoration (at least one file)
- [ ] Review backup reports for issues
- [ ] Archive logs

### Quarterly Tasks
- [ ] Full restoration test
- [ ] Update Veeam Agent
- [ ] Review and optimize backup retention
- [ ] Audit backup retention policies

### Annually
- [ ] Disaster recovery drill
- [ ] Update backup documentation
- [ ] Review and plan for capacity upgrades
- [ ] Security audit of SMB shares

---

## Support & Documentation

**Veeam Resources:**
- Official Website: https://www.veeam.com
- Free Agent Download: https://www.veeam.com/windows-endpoint-server-backup-free.html
- Documentation: https://www.veeam.com/backup-replication-resources.html
- Community Forum: https://forums.veeam.com

**TrueNAS Resources:**
- Official Documentation: https://www.truenas.com/docs/
- Community: https://www.truenas.com/community/
- Download: https://www.truenas.com/download-truenas-core/

**macOS Time Machine:**
- Apple Support: https://support.apple.com/en-us/108958
- SMB Configuration: https://support.apple.com/guide/mac-help/connect-smb-mac/

---

## Emergency Recovery Procedures

### If Veeam Backups Fail

1. Check log file: `C:\Logs\*VEEAM*.log`
2. Verify SMB share accessibility
3. Check disk space on backup destination
4. Restart Veeam service
5. Re-run deployment script to reconfigure

### If Phone Backups Become Inaccessible

1. Check mount: `net use | findstr PhoneBackups`
2. Remount share: Run DEPLOY-PHONE-BACKUPS-WINDOWS.ps1
3. Verify TrueNAS SMB service is running
4. Check device application settings for correct path

### If Time Machine Backup Fails

1. Check mount: `mount | grep TimeMachine`
2. Remount: `./DEPLOY-TIME-MACHINE-MAC.sh`
3. Verify sufficient disk space
4. Check Time Machine system logs
5. Try manual backup: `tmutil startbackup`

---

## Appendix A: PowerShell Examples

### Test SMB Share Access

```powershell
$share = "\\baby.isn.biz\Veeam"
$cred = Get-Credential

# Test path
Test-Path $share

# List contents
Get-ChildItem $share -Credential $cred

# Test write permissions
$testFile = "$share\test-$(Get-Date -Format 'yyyyMMddHHmmss').txt"
"test" | Out-File -FilePath $testFile
Remove-Item $testFile
```

### Get Veeam Backup Status

```powershell
# List Veeam jobs
Get-EventLog -LogName Application -Source "*Veeam*" -Newest 50 |
    Select-Object TimeGenerated, Message |
    Format-Table -AutoSize

# Check last backup
Get-EventLog -LogName Application -Source "*Veeam*" -Newest 1 |
    Select-Object TimeGenerated, Message
```

### Monitor Backup Progress

```powershell
# Real-time monitoring
while ($true) {
    Clear-Host
    Write-Host "Backup Status - $(Get-Date)" -ForegroundColor Cyan

    Get-EventLog -LogName Application -Source "*Veeam*" -Newest 5 |
        Select-Object TimeGenerated, Message |
        Format-Table -AutoSize

    Start-Sleep -Seconds 10
}
```

---

## Appendix B: Bash Examples (macOS)

### Test SMB Mount

```bash
# Test connectivity
ping 10.0.0.89

# List SMB shares
smbutil view baremetal.isn.biz

# Mount SMB share manually
mkdir -p /Volumes/TimeMachine-Backup
mount_smbfs //baremetal.isn.biz/TimeMachine /Volumes/TimeMachine-Backup

# Verify mount
mount | grep TimeMachine
```

### Monitor Time Machine

```bash
# Current status
tmutil status

# List recent backups
tmutil listbackups

# Get latest backup
tmutil latestbackup

# Start manual backup
sudo tmutil startbackup

# Monitor in real-time
log stream --predicate 'process == "backupd"' --level debug
```

---

## Document Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-10 | Initial release with all scripts and documentation |

---

**Last Updated:** 2024-12-10
**Maintained By:** System Administrator
**Contact:** support@isn.biz
