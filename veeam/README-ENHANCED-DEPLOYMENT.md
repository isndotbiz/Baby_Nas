# Enhanced Veeam Deployment System

Complete automated backup solution for Windows with TrueNAS integration.

## Overview

This enhanced deployment system provides:

1. **Automated Veeam Agent Installation** - Silent install from D:\ISOs\
2. **Full System Backup** - Daily 1 AM to \\baby.isn.biz\Veeam (7 days retention)
3. **Workspace Hourly Sync** - D:\workspace to \\baby.isn.biz\WindowsBackup\d-workspace (30 days retention)
4. **WSL Daily Backup** - WSL distributions to \\baby.isn.biz\WindowsBackup\wsl (14 days retention)
5. **Comprehensive Monitoring** - HTML reports and automated health checks
6. **Scheduled Task Management** - Windows Task Scheduler integration
7. **Network Share Mapping** - Automatic SMB credential management

## Quick Start

### Prerequisites

- Windows 7 SP1+ or Windows Server 2008 R2 SP1+
- PowerShell 5.1 or later
- Administrator privileges
- Network access to TrueNAS (baby.isn.biz / 172.21.203.18)
- SMB credentials configured in .env file (see .env.example)
- Veeam Agent installer in D:\ISOs\ (optional, can download)

### One-Command Deployment

```powershell
# Run as Administrator
cd D:\workspace\Baby_Nas\veeam

# Interactive deployment (recommended for first time - uses .env credentials)
.\DEPLOY-VEEAM-ENHANCED.ps1

# Or automated deployment (unattended mode - uses .env credentials)
.\DEPLOY-VEEAM-ENHANCED.ps1 -Unattended $true

# If you need to specify password explicitly (not recommended):
# $password = ConvertTo-SecureString "YOUR-PASSWORD-HERE" -AsPlainText -Force
# .\DEPLOY-VEEAM-ENHANCED.ps1 -Unattended $true -SmbPassword $password
```

### What Happens During Deployment

1. **Environment Initialization**
   - Creates C:\Logs\Veeam directory
   - Verifies administrator privileges
   - Tests TrueNAS connectivity
   - Updates hosts file with baby.isn.biz entry

2. **Network Configuration**
   - Mounts \\baby.isn.biz\Veeam
   - Mounts \\baby.isn.biz\WindowsBackup\d-workspace
   - Mounts \\baby.isn.biz\WindowsBackup\wsl
   - Tests write access to all shares

3. **Veeam Installation** (if needed)
   - Auto-detects installer in D:\ISOs\
   - Supports both .exe and .iso formats
   - Silent installation with optimal parameters
   - Verifies service startup

4. **Backup Job Configuration**
   - **Full System Backup**: Manual configuration guide in Veeam UI
   - **Workspace Sync**: Automated via scheduled task (hourly)
   - **WSL Backup**: Automated via scheduled task (daily 2 AM)

5. **Monitoring Setup**
   - Creates daily monitoring scheduled task
   - Generates HTML reports
   - Saves status to JSON

## File Structure

```
D:\workspace\True_Nas\windows-scripts\veeam\
│
├── DEPLOY-VEEAM-ENHANCED.ps1          # Main deployment script
├── MONITOR-VEEAM-ENHANCED.ps1         # Enhanced monitoring script
├── README-ENHANCED-DEPLOYMENT.md      # This file
│
├── 0-DEPLOY-VEEAM-COMPLETE.ps1        # Original orchestration script
├── 1-install-veeam-agent.ps1          # Original installation script
├── 2-configure-backup-jobs.ps1        # Original job configuration
├── 3-setup-truenas-repository.ps1     # Original TrueNAS setup
├── 4-monitor-backup-jobs.ps1          # Original monitoring script
├── 5-test-recovery.ps1                # Recovery testing
└── 6-integration-replication.ps1      # Replication integration
```

## Configuration Details

### Full System Backup

- **Job Name**: System-Full-Backup
- **Drives**: C:, D:
- **Destination**: \\baby.isn.biz\Veeam
- **Schedule**: Daily at 1:00 AM
- **Retention**: 7 restore points (7 days)
- **Compression**: Optimal
- **Application-Aware**: Yes (VSS)
- **Configuration**: **MANUAL** in Veeam UI

### Workspace Hourly Sync

- **Job Name**: Workspace-Hourly-Sync
- **Source**: D:\workspace
- **Destination**: \\baby.isn.biz\WindowsBackup\d-workspace
- **Schedule**: Hourly
- **Retention**: 30 days (files older than 30 days are removed)
- **Method**: Robocopy mirror with multi-threading
- **Configuration**: **AUTOMATED** via scheduled task

### WSL Daily Backup

- **Job Name**: WSL-Daily-Backup
- **Source**: All WSL distributions
- **Destination**: \\baby.isn.biz\WindowsBackup\wsl
- **Schedule**: Daily at 2:00 AM
- **Retention**: 14 days
- **Format**: .tar.gz archives (VHD format)
- **Configuration**: **AUTOMATED** via scheduled task

## Usage

### Initial Deployment

```powershell
# Interactive mode (recommended)
.\DEPLOY-VEEAM-ENHANCED.ps1

# Skip installation (Veeam already installed)
.\DEPLOY-VEEAM-ENHANCED.ps1 -SkipInstallation $true

# Skip workspace sync configuration
.\DEPLOY-VEEAM-ENHANCED.ps1 -SkipWorkspaceSync $true

# Skip WSL backup configuration
.\DEPLOY-VEEAM-ENHANCED.ps1 -SkipWSLBackup $true

# Complete unattended deployment (uses .env credentials)
.\DEPLOY-VEEAM-ENHANCED.ps1 -Unattended $true
```

### Monitoring

```powershell
# Single status check with HTML report
.\MONITOR-VEEAM-ENHANCED.ps1

# Continuous monitoring (every 30 minutes)
.\MONITOR-VEEAM-ENHANCED.ps1 -ContinuousMonitoring $true -CheckInterval 30

# With email alerts (requires configuration)
.\MONITOR-VEEAM-ENHANCED.ps1 -EnableEmailAlerts $true -EmailTo "admin@example.com" -SmtpServer "smtp.example.com"
```

### Manual Operations

```powershell
# Trigger workspace backup manually
& "C:\Logs\Veeam\workspace-backup.ps1"

# Trigger WSL backup manually
& "C:\Logs\Veeam\wsl-backup.ps1"

# View scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like "*Veeam*" -or $_.TaskName -like "*Workspace*" -or $_.TaskName -like "*WSL*" }

# Check scheduled task status
Get-ScheduledTaskInfo -TaskName "Workspace-Hourly-Sync"
Get-ScheduledTaskInfo -TaskName "WSL-Daily-Backup"

# View recent logs
Get-ChildItem "C:\Logs\Veeam\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

## Post-Deployment Steps

### 1. Configure Veeam Full Backup (IMPORTANT)

The script provides configuration guidance, but you **must** manually configure the Veeam backup job:

1. Open Veeam Agent Control Panel
   - Press `Win+R` and run: `control.exe /name Veeam.EndpointBackup`
   - Or search for "Veeam" in Start Menu

2. Click "Configure Backup" or "Add Job"

3. Select "Volume Level Backup"

4. Select drives: **C:, D:**

5. Destination: **\\baby.isn.biz\Veeam**
   - Enter credentials when prompted (use values from your .env file):
   - Username: Use TRUENAS_USERNAME from .env
   - Password: Use TRUENAS_PASSWORD from .env

6. Cache location: **C:\VeeamCache** (10-20 GB recommended)

7. Advanced Settings:
   - Compression: **Optimal**
   - Block size: **Local target**
   - Enable **Application-Aware Processing** (VSS)

8. Schedule:
   - Daily backup
   - Time: **01:00** (1 AM)
   - Days: All days
   - Enable retry: 3 attempts, 10 min interval

9. Retention: **7 restore points**

10. Job name: **System-Full-Backup**

11. Click **Finish**, then **Backup Now** to test

### 2. Verify Scheduled Tasks

```powershell
# Open Task Scheduler
taskschd.msc

# Verify these tasks exist and are enabled:
# - Workspace-Hourly-Sync
# - WSL-Daily-Backup
# - Veeam-Backup-Monitoring

# Check task history to ensure they run successfully
```

### 3. Test Backups

```powershell
# Test workspace backup
& "C:\Logs\Veeam\workspace-backup.ps1"
# Check: \\baby.isn.biz\WindowsBackup\d-workspace for files

# Test WSL backup (if WSL is installed)
& "C:\Logs\Veeam\wsl-backup.ps1"
# Check: \\baby.isn.biz\WindowsBackup\wsl for .tar.gz files

# Test full system backup via Veeam UI
# Open Veeam > Backup Now
# Monitor progress in Veeam Control Panel
# Check: \\baby.isn.biz\Veeam for .vbk files
```

### 4. Verify Network Shares

```powershell
# Check mounted shares
net use

# Should see:
# \\baby.isn.biz\Veeam
# \\baby.isn.biz\WindowsBackup\d-workspace
# \\baby.isn.biz\WindowsBackup\wsl

# Test write access
echo "test" > "\\baby.isn.biz\Veeam\test.txt"
del "\\baby.isn.biz\Veeam\test.txt"
```

### 5. Review Monitoring Report

```powershell
# Run monitoring script
.\MONITOR-VEEAM-ENHANCED.ps1

# Opens HTML report in browser automatically
# Or manually open: C:\Logs\Veeam\Reports\report-*.html

# Check JSON status
Get-Content "C:\Logs\Veeam\latest-status.json" | ConvertFrom-Json
```

## Logs and Reports

### Log Locations

- **Deployment logs**: `C:\Logs\Veeam\enhanced-deploy-*.log`
- **Workspace backup logs**: `C:\Logs\Veeam\workspace-backup-*.log`
- **WSL backup logs**: `C:\Logs\Veeam\wsl-backup-*.log`
- **Monitoring logs**: `C:\Logs\Veeam\monitor-*.log`
- **Veeam logs**: `C:\ProgramData\Veeam\Endpoint\Logs\`

### Report Locations

- **HTML reports**: `C:\Logs\Veeam\Reports\report-*.html`
- **JSON status**: `C:\Logs\Veeam\latest-status.json`
- **Configuration files**: `C:\Logs\Veeam\*-config.xml`

### Reading Logs

```powershell
# View latest deployment log
Get-Content "C:\Logs\Veeam\enhanced-deploy-*.log" -Tail 50

# View latest workspace backup log
Get-Content "C:\Logs\Veeam\workspace-backup-*.log" -Tail 50

# Search for errors
Get-ChildItem "C:\Logs\Veeam\*.log" | Select-String "ERROR" -Context 2

# View monitoring status
Get-Content "C:\Logs\Veeam\latest-status.json" | ConvertFrom-Json | Format-List
```

## Troubleshooting

### Issue: Cannot access network shares

**Symptoms**: Error mounting \\baby.isn.biz shares

**Solutions**:
```powershell
# 1. Verify TrueNAS is reachable
Test-Connection -ComputerName 172.21.203.18 -Count 4

# 2. Check hosts file
Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" | Select-String "baby.isn.biz"

# 3. Manually add to hosts file if missing
Add-Content "$env:SystemRoot\System32\drivers\etc\hosts" "`n172.21.203.18`tbaby.isn.biz"

# 4. Test SMB connectivity
Test-NetConnection -ComputerName baby.isn.biz -Port 445

# 5. Manually mount with credentials (use your .env values)
# Load .env first
. .\Load-EnvFile.ps1
$username = Get-EnvVariable "TRUENAS_USERNAME"
$password = Get-EnvVariable "TRUENAS_PASSWORD"
net use \\baby.isn.biz\Veeam /user:$username "$password"

# 6. Check firewall
Test-NetConnection -ComputerName 172.21.203.18 -Port 445 -InformationLevel Detailed
```

### Issue: Veeam installer not found

**Symptoms**: "No Veeam installer found" warning

**Solutions**:
```powershell
# 1. Download Veeam Agent for Windows FREE
# URL: https://www.veeam.com/windows-endpoint-server-backup-free.html

# 2. Save to D:\ISOs\VeeamAgentWindows.exe or .iso

# 3. Verify file exists
Get-ChildItem "D:\ISOs\VeeamAgent*"

# 4. Run with explicit path
.\DEPLOY-VEEAM-ENHANCED.ps1 -VeeamInstallerPath "D:\ISOs\VeeamAgentWindows_6.0.0.1258.exe"
```

### Issue: Scheduled tasks not running

**Symptoms**: Backups not running automatically

**Solutions**:
```powershell
# 1. Check task exists
Get-ScheduledTask -TaskName "Workspace-Hourly-Sync"

# 2. Check task is enabled
Get-ScheduledTask -TaskName "Workspace-Hourly-Sync" | Select-Object State, TaskName

# 3. Check last run time and result
Get-ScheduledTaskInfo -TaskName "Workspace-Hourly-Sync"

# 4. Manually trigger task to test
Start-ScheduledTask -TaskName "Workspace-Hourly-Sync"

# 5. Check task history in Task Scheduler GUI
taskschd.msc
# Navigate to Task Scheduler Library
# Find task > History tab

# 6. Re-create task
.\DEPLOY-VEEAM-ENHANCED.ps1 -SkipInstallation $true -SkipBackupConfiguration $false
```

### Issue: Workspace backup fails

**Symptoms**: Robocopy errors in workspace-backup logs

**Solutions**:
```powershell
# 1. Check source exists
Test-Path "D:\workspace"

# 2. Check destination accessible
Test-Path "\\baby.isn.biz\WindowsBackup\d-workspace"

# 3. Check write permissions
$testFile = "\\baby.isn.biz\WindowsBackup\d-workspace\test.txt"
"test" | Out-File $testFile
Remove-Item $testFile

# 4. Review robocopy log
Get-Content "C:\Logs\Veeam\workspace-backup-*.log" -Tail 100

# 5. Manually run robocopy to test
robocopy "D:\workspace" "\\baby.isn.biz\WindowsBackup\d-workspace" /MIR /R:3 /W:10 /MT:8

# 6. Check for locked files
# Close any open applications that might be locking files in D:\workspace
```

### Issue: WSL backup fails

**Symptoms**: No WSL backups in \\baby.isn.biz\WindowsBackup\wsl

**Solutions**:
```powershell
# 1. Check WSL is installed and distributions exist
wsl --list --verbose

# 2. If no WSL, skip WSL backup
.\DEPLOY-VEEAM-ENHANCED.ps1 -SkipWSLBackup $true

# 3. Check WSL export manually
wsl --export Ubuntu "C:\Temp\ubuntu-test.tar.gz"

# 4. Check destination accessible
Test-Path "\\baby.isn.biz\WindowsBackup\wsl"

# 5. Review WSL backup log
Get-Content "C:\Logs\Veeam\wsl-backup-*.log"

# 6. Manually run WSL backup script
& "C:\Logs\Veeam\wsl-backup.ps1"
```

### Issue: Veeam full backup not working

**Symptoms**: No .vbk files in \\baby.isn.biz\Veeam

**Solutions**:
```powershell
# 1. Check Veeam service is running
Get-Service -Name "VeeamEndpointBackupSvc"

# 2. Start service if stopped
Start-Service -Name "VeeamEndpointBackupSvc"

# 3. Open Veeam Control Panel
control.exe /name Veeam.EndpointBackup

# 4. Verify backup job is configured
# Check: Job name, drives, destination, schedule

# 5. Check Veeam event log
Get-WinEvent -LogName "Veeam Backup" -MaxEvents 20

# 6. Check destination accessible from Veeam
# Open Veeam > Configure > Test Connection

# 7. Review Veeam logs
Get-ChildItem "C:\ProgramData\Veeam\Endpoint\Logs" -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50

# 8. Test immediate backup
# Open Veeam > Backup Now > Monitor progress
```

### Issue: Monitoring reports show "Unknown" status

**Symptoms**: Monitoring script doesn't detect backups

**Solutions**:
```powershell
# 1. Wait for first backup to complete
# Status will be "Unknown" until first backup runs

# 2. Manually trigger backups to populate status
Start-ScheduledTask -TaskName "Workspace-Hourly-Sync"
Start-ScheduledTask -TaskName "WSL-Daily-Backup"
# Trigger Veeam backup via UI

# 3. Check Event Log
Get-WinEvent -LogName "Veeam Backup" -MaxEvents 10

# 4. Re-run monitoring after backups complete
.\MONITOR-VEEAM-ENHANCED.ps1

# 5. Check monitoring script permissions
# Must run as Administrator
```

## Advanced Configuration

### Custom Retention Policies

Edit the deployment script to change retention:

```powershell
# D:\workspace\True_Nas\windows-scripts\veeam\DEPLOY-VEEAM-ENHANCED.ps1

# Line ~47: Change workspace retention from 30 to 60 days
Retention = 60      # 60 days instead of 30

# Line ~58: Change WSL retention from 14 to 30 days
Retention = 30      # 30 days instead of 14
```

### Custom Backup Schedules

Edit scheduled tasks in Task Scheduler:

```powershell
# Open Task Scheduler
taskschd.msc

# Modify task:
# 1. Find "Workspace-Hourly-Sync"
# 2. Right-click > Properties
# 3. Triggers tab > Edit
# 4. Change from hourly to custom schedule
```

### Email Notifications

Configure email alerts for backup failures:

```powershell
# Use original monitoring script with email support
.\4-monitor-backup-jobs.ps1 `
    -EnableEmailAlerts $true `
    -EmailTo "admin@example.com" `
    -EmailFrom "veeam@yourdomain.com" `
    -SmtpServer "smtp.gmail.com" `
    -SmtpPort 587 `
    -SmtpUsername "your-email@gmail.com" `
    -SmtpPassword (ConvertTo-SecureString "app-password" -AsPlainText -Force) `
    -AlertOnWarning $true
```

### Exclude Folders from Workspace Backup

Edit workspace backup script:

```powershell
# Edit: C:\Logs\Veeam\workspace-backup.ps1

# Add exclusions to robocopy command (line ~31):
$robocopyArgs = @(
    $source,
    $destination,
    "/MIR",
    "/R:3",
    "/W:10",
    "/MT:8",
    "/XD", "node_modules",  # Exclude node_modules
    "/XD", ".git",          # Exclude .git
    "/XD", "venv",          # Exclude Python venv
    "/XF", "*.tmp",         # Exclude temp files
    "/NFL",
    "/NDL",
    "/NP",
    "/LOG+:$logFile"
)
```

## Security Considerations

### Credential Storage

The deployment script uses several methods to handle credentials:

1. **SecureString parameters**: Passwords passed as SecureString
2. **Prompt for passwords**: Interactive mode prompts securely
3. **Persistent network credentials**: Stored in Windows Credential Manager

### Hardcoded Credentials

The README contains hardcoded credentials for demonstration. In production:

1. Use environment variables
2. Use Windows Credential Manager
3. Use Azure Key Vault or similar
4. Implement proper secrets management

### Network Security

1. **SMB Signing**: Ensure SMB signing is enabled on TrueNAS
2. **Firewall Rules**: Only allow necessary ports (445 for SMB)
3. **VPN**: Consider using WireGuard for remote access
4. **Encryption**: Enable Veeam backup encryption for sensitive data

## Performance Optimization

### Workspace Sync Performance

Current configuration:
- **Multi-threaded**: 8 threads (faster on SSD/fast network)
- **Hourly**: May be too frequent for large workspaces

Optimize for large workspaces:

```powershell
# Edit workspace-backup.ps1
# Increase threads for faster sync (if network/storage can handle)
"/MT:16",  # 16 threads instead of 8

# Reduce frequency to every 2 hours
# Edit scheduled task trigger: "Every 2 hours" instead of hourly

# Add bandwidth throttling (if needed)
"/IPG:100",  # Inter-packet gap of 100ms
```

### Veeam Backup Performance

1. **Cache Location**: Use SSD for C:\VeeamCache
2. **Compression**: "Optimal" is good balance, "Dedupe" for better ratio
3. **Block Size**: "Local target" for network shares
4. **Scheduling**: Run during off-hours (1 AM default)

### Network Performance

1. **SMB Multichannel**: Enable on TrueNAS and Windows
2. **Jumbo Frames**: Configure if using dedicated network
3. **Link Aggregation**: Use LACP on TrueNAS for multiple NICs

## Maintenance

### Weekly Tasks

```powershell
# 1. Review monitoring reports
.\MONITOR-VEEAM-ENHANCED.ps1

# 2. Check log directory size
Get-ChildItem "C:\Logs\Veeam" -Recurse | Measure-Object -Property Length -Sum

# 3. Review scheduled task history
Get-ScheduledTask | Where-Object { $_.TaskName -like "*Veeam*" } | Get-ScheduledTaskInfo

# 4. Verify backup files exist
Get-ChildItem "\\baby.isn.biz\Veeam" -Recurse -File | Select-Object Name, Length, LastWriteTime -First 10
```

### Monthly Tasks

```powershell
# 1. Test backup restore (critical!)
# Use: 5-test-recovery.ps1

# 2. Clean up old logs
Get-ChildItem "C:\Logs\Veeam" -Filter "*.log" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item

# 3. Review retention policies
# Ensure old backups are being removed properly

# 4. Check TrueNAS storage capacity
# Ensure adequate free space for backups

# 5. Update Veeam Agent
# Check for new version at veeam.com
```

### Quarterly Tasks

```powershell
# 1. Perform full restore test
# Critical: Test actual restore to verify backups work

# 2. Review backup strategy
# Ensure backup jobs still meet requirements

# 3. Security audit
# Review credentials, access logs, shares

# 4. Documentation update
# Update procedures, contacts, changes
```

## Support and Documentation

### Additional Resources

- **Veeam Documentation**: https://www.veeam.com/documentation-guides-datasheets.html
- **Veeam Community**: https://forums.veeam.com/
- **TrueNAS Forums**: https://www.truenas.com/community/
- **PowerShell Gallery**: https://www.powershellgallery.com/

### Script Locations

All scripts are located in:
```
D:\workspace\True_Nas\windows-scripts\veeam\
```

### Getting Help

```powershell
# View script help
Get-Help .\DEPLOY-VEEAM-ENHANCED.ps1 -Full
Get-Help .\MONITOR-VEEAM-ENHANCED.ps1 -Full

# View parameter details
Get-Help .\DEPLOY-VEEAM-ENHANCED.ps1 -Parameter *
```

## Changelog

### Version 2.0 (Enhanced) - 2025-12-10

- Added comprehensive deployment automation
- Integrated workspace hourly sync
- Integrated WSL daily backup
- Enhanced monitoring with HTML reports
- Automated scheduled task creation
- Improved credential management
- Added extensive logging and error handling
- Created detailed troubleshooting guide

### Version 1.0 (Original) - Previous

- Basic Veeam installation script
- Manual backup configuration
- Basic monitoring
- TrueNAS repository setup

## License

These scripts are provided as-is for educational and operational purposes.

## Credits

- Original scripts: Automated Veeam Deployment System
- Enhanced version: Enhanced Veeam Deployment System v2.0
- Created for TrueNAS "Baby NAS" integration project
