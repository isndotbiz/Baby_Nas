# Veeam Agent Automated Deployment System

Complete automation suite for deploying and managing Veeam Agent for Windows with TrueNAS (Baby NAS) integration.

## Overview

This system provides **complete automation** for:
- ✅ Veeam Agent installation
- ✅ TrueNAS repository configuration
- ✅ Backup job creation and scheduling
- ✅ Monitoring and alerting
- ✅ Recovery testing
- ✅ Replication integration with Baby NAS

## Quick Start

### One-Command Complete Deployment

```powershell
# Run as Administrator
cd D:\workspace\True_Nas\windows-scripts\veeam
.\0-DEPLOY-VEEAM-COMPLETE.ps1
```

This master script orchestrates the entire deployment process in the correct order.

### Estimated Time
- **Interactive Mode**: 30-40 minutes (includes manual configuration steps)
- **Unattended Mode**: 20-30 minutes (automated where possible)

## Scripts Overview

### 0-DEPLOY-VEEAM-COMPLETE.ps1
**Master orchestration script** - Runs all components in order
- Tracks deployment progress
- Handles errors gracefully
- Provides comprehensive summary
- Can skip already-completed steps

**Usage:**
```powershell
# Full deployment (interactive)
.\0-DEPLOY-VEEAM-COMPLETE.ps1

# Unattended deployment
.\0-DEPLOY-VEEAM-COMPLETE.ps1 -Unattended $true

# Skip already completed steps
.\0-DEPLOY-VEEAM-COMPLETE.ps1 -SkipInstallation $true -SkipRepository $true

# Custom configuration
.\0-DEPLOY-VEEAM-COMPLETE.ps1 -BackupDrives "C:","D:","E:" -RetentionPoints 14
```

---

### 1-install-veeam-agent.ps1
**Automated Veeam Agent installation**
- Detects existing installation
- Supports ISO and EXE installers
- Silent installation with optimal settings
- Post-installation verification

**Usage:**
```powershell
# Auto-detect installer
.\1-install-veeam-agent.ps1

# Specify installer path
.\1-install-veeam-agent.ps1 -InstallerPath "C:\Downloads\VeeamAgentWindows.exe"

# Custom install path
.\1-install-veeam-agent.ps1 -InstallPath "D:\Program Files\Veeam"
```

**What it does:**
1. Checks system requirements (OS, RAM, disk space)
2. Searches for Veeam installer in common locations
3. Performs silent installation
4. Verifies services are running
5. Configures FREE edition settings

---

### 2-configure-backup-jobs.ps1
**Automated backup job configuration**
- Creates backup job configuration
- Configures retention policies
- Sets up schedules
- Manages network credentials

**Usage:**
```powershell
# Default configuration (C:, D: drives, 7 restore points)
.\2-configure-backup-jobs.ps1

# Custom drives and retention
.\2-configure-backup-jobs.ps1 -BackupDrives "C:","D:","E:" -RetentionPoints 30

# With encryption
.\2-configure-backup-jobs.ps1 -EnableEncryption $true -EncryptionPassword "SecurePass123"

# Custom schedule
.\2-configure-backup-jobs.ps1 -ScheduleTime "01:00" -Compression "High"
```

**Configuration Options:**
- **BackupDrives**: Array of drives to backup (default: C:, D:)
- **RetentionPoints**: Number of restore points (default: 7)
- **ScheduleTime**: Daily backup time in HH:MM (default: 02:00)
- **Compression**: None, Dedupe, Optimal, High, Extreme (default: Optimal)
- **EnableEncryption**: Encrypt backups (default: false)
- **EnableAppAware**: VSS application-aware processing (default: true)

**Output:**
- Provides step-by-step manual configuration guide
- Saves configuration to XML for reference
- Tests backup destination accessibility

---

### 3-setup-truenas-repository.ps1
**TrueNAS repository setup and optimization**
- Creates ZFS dataset with optimal properties
- Configures SMB share
- Sets up user permissions
- Performance tuning for Veeam workloads

**Usage:**
```powershell
# Basic setup
.\3-setup-truenas-repository.ps1

# With API key
.\3-setup-truenas-repository.ps1 -TrueNasApiKey "1-abc123..."

# Custom dataset and quota
.\3-setup-truenas-repository.ps1 -DatasetName "backups/veeam" -DatasetQuota "1T"

# Performance tuning
.\3-setup-truenas-repository.ps1 -RecordSize "256K" -EnableCompression $true
```

**ZFS Optimization for Veeam:**
- **recordsize**: 128K (optimal for Veeam's block size)
- **compression**: lz4 (fast, effective for backup data)
- **dedup**: OFF (not recommended for Veeam - CPU intensive)
- **atime**: OFF (improves performance)
- **sync**: standard (balanced performance/safety)

**Configuration Methods:**
1. **API Method**: Fully automated using TrueNAS API
2. **SSH Method**: Provides commands for manual execution
3. **Web UI Method**: Step-by-step guide for manual config

---

### 4-monitor-backup-jobs.ps1
**Comprehensive backup monitoring and reporting**
- Job status checking
- Failed backup detection
- Storage capacity monitoring
- Email alerts (optional)
- HTML/JSON reporting

**Usage:**
```powershell
# Single status check
.\4-monitor-backup-jobs.ps1

# Continuous monitoring (every 60 minutes)
.\4-monitor-backup-jobs.ps1 -CheckInterval 60

# With email alerts
.\4-monitor-backup-jobs.ps1 `
    -EnableEmailAlerts $true `
    -EmailTo "admin@example.com" `
    -SmtpServer "smtp.example.com" `
    -SmtpUsername "user" `
    -SmtpPassword (ConvertTo-SecureString "password" -AsPlainText -Force)

# Alert on warnings too
.\4-monitor-backup-jobs.ps1 -EnableEmailAlerts $true -AlertOnWarning $true
```

**Monitoring Features:**
- ✅ Backup job status (Success/Failed/Warning)
- ✅ Last backup timestamp
- ✅ Backup destination space monitoring
- ✅ Backup file analysis (types, sizes, age)
- ✅ Historical trend tracking
- ✅ Email alerts for failures
- ✅ HTML and JSON reports

**Reports Location:**
- JSON: `C:\Logs\Veeam\veeam-status-latest.json`
- HTML: `C:\Logs\Veeam\Reports\veeam-report-*.html`
- Logs: `C:\Logs\Veeam\veeam-monitor-*.log`

---

### 5-test-recovery.ps1
**Automated recovery testing and validation**
- Backup file integrity checking
- Recovery capability testing
- RTO measurement
- Restore procedure documentation

**Usage:**
```powershell
# Standard recovery test
.\5-test-recovery.ps1

# Test volume restore capability
.\5-test-recovery.ps1 -TestVolumeRestore $true

# Keep restored files for inspection
.\5-test-recovery.ps1 -CleanupAfterTest $false

# Custom restore location
.\5-test-recovery.ps1 -TestRestorePath "D:\VeeamRestoreTest"
```

**What it tests:**
- ✅ Backup file accessibility and integrity
- ✅ Veeam restore functionality
- ✅ Recovery procedures documentation
- ✅ Recovery Time Objective (RTO) estimates
- ✅ Data validation after restore

**Test Types:**
1. **File-Level Restore**: Quick test of individual file recovery
2. **Volume-Level Restore**: Full volume recovery test
3. **Integrity Check**: Validate backup file health

**Reports:**
- Test results: JSON format with all findings
- HTML report: Detailed recovery test documentation
- Manual procedures: Step-by-step restore guides

---

### 6-integration-replication.ps1
**Veeam and TrueNAS replication coordination**
- Schedule conflict detection
- Bandwidth management configuration
- Snapshot coordination
- Optimal schedule recommendations

**Usage:**
```powershell
# Default coordination
.\6-integration-replication.ps1

# Custom schedule
.\6-integration-replication.ps1 `
    -VeeamBackupTime "01:00" `
    -ReplicationStartTime "04:00"

# With bandwidth limiting
.\6-integration-replication.ps1 `
    -EnableBandwidthLimit $true `
    -BandwidthLimitMbps 50 `
    -BusinessHoursStart "08:00" `
    -BusinessHoursEnd "18:00"
```

**Integration Features:**
- ✅ Schedule conflict detection
- ✅ Optimal timing recommendations
- ✅ Buffer time calculation
- ✅ Timeline visualization
- ✅ TrueNAS replication configuration commands
- ✅ Bandwidth management setup
- ✅ Business hours protection

**Recommended Schedule:**
```
02:00 - Veeam backup starts
04:00 - Veeam backup completes (estimated)
05:00 - TrueNAS replication starts (30 min buffer)
07:30 - Replication completes
08:00 - Business hours start
```

---

## Configuration Files

All configuration and logs stored in: `C:\Logs\Veeam\`

### Generated Files:
- `veeam-config-*.xml` - Backup job configuration
- `truenas-repo-config.json` - Repository settings
- `integration-schedule.json` - Coordinated schedule
- `deployment-status.json` - Deployment tracking
- `veeam-status-latest.json` - Current backup status

### Logs:
- `veeam-install-*.log` - Installation logs
- `veeam-configure-*.log` - Configuration logs
- `truenas-repo-setup-*.log` - Repository setup logs
- `veeam-monitor-*.log` - Monitoring logs
- `recovery-test-*.log` - Recovery test logs
- `integration-*.log` - Integration logs
- `complete-deployment-*.log` - Master deployment log

---

## Prerequisites

### System Requirements:
- ✅ Windows 7 SP1 / Server 2008 R2 SP1 or later
- ✅ 2 GB RAM minimum (4+ GB recommended)
- ✅ 150 MB disk space for Veeam Agent
- ✅ 20+ GB disk space for backup cache
- ✅ Administrator privileges

### Network Requirements:
- ✅ Network connectivity to TrueNAS (172.21.203.18)
- ✅ SMB/CIFS ports accessible (445)
- ✅ Sufficient bandwidth for backups

### TrueNAS Requirements:
- ✅ TrueNAS Scale or Core
- ✅ ZFS pool with available space
- ✅ SMB service enabled
- ✅ API access (optional, for automation)

---

## Installation Workflow

### Phase 1: Preparation (5 minutes)
1. Download Veeam Agent for Windows (FREE)
   - URL: https://www.veeam.com/windows-endpoint-server-backup-free.html
   - Register for free account
   - Download latest version

2. Verify TrueNAS accessibility
   ```powershell
   Test-Connection -ComputerName 172.21.203.18 -Count 4
   ```

3. Ensure sufficient backup storage on TrueNAS

### Phase 2: Automated Deployment (20-30 minutes)
1. Run master deployment script:
   ```powershell
   cd D:\workspace\True_Nas\windows-scripts\veeam
   .\0-DEPLOY-VEEAM-COMPLETE.ps1
   ```

2. Follow prompts for:
   - Veeam installer location
   - TrueNAS credentials
   - Backup job preferences

3. Review configuration guides for manual steps

### Phase 3: Verification (5-10 minutes)
1. Open Veeam Control Panel
   ```powershell
   control.exe /name Veeam.EndpointBackup
   ```

2. Verify backup job is created

3. Run test backup immediately

4. Verify backup files on TrueNAS:
   ```powershell
   dir \\172.21.203.18\Veeam
   ```

### Phase 4: Monitoring Setup (5 minutes)
1. Schedule monitoring script:
   ```powershell
   # Create scheduled task for daily monitoring
   .\4-monitor-backup-jobs.ps1
   ```

2. Configure email alerts (optional)

3. Test monitoring reports

---

## Common Scenarios

### Scenario 1: Fresh Installation
```powershell
# Complete automated deployment
.\0-DEPLOY-VEEAM-COMPLETE.ps1

# Or step-by-step:
.\1-install-veeam-agent.ps1
.\3-setup-truenas-repository.ps1
.\2-configure-backup-jobs.ps1
.\4-monitor-backup-jobs.ps1
.\5-test-recovery.ps1
.\6-integration-replication.ps1
```

### Scenario 2: Veeam Already Installed
```powershell
# Skip installation step
.\0-DEPLOY-VEEAM-COMPLETE.ps1 -SkipInstallation $true

# Or configure directly:
.\2-configure-backup-jobs.ps1
```

### Scenario 3: Reconfigure Existing Setup
```powershell
# Reconfigure backup jobs only
.\2-configure-backup-jobs.ps1 -BackupDrives "C:","E:" -RetentionPoints 30

# Adjust replication schedule
.\6-integration-replication.ps1 -ReplicationStartTime "06:00"
```

### Scenario 4: Continuous Monitoring
```powershell
# Run monitoring every hour
.\4-monitor-backup-jobs.ps1 -CheckInterval 60

# Or create scheduled task:
$trigger = New-ScheduledTaskTrigger -Daily -At "09:00"
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File D:\workspace\True_Nas\windows-scripts\veeam\4-monitor-backup-jobs.ps1"
Register-ScheduledTask -TaskName "Veeam-Monitoring" -Trigger $trigger -Action $action -RunLevel Highest
```

### Scenario 5: Recovery Testing
```powershell
# Monthly recovery test
.\5-test-recovery.ps1

# Test with volume restore
.\5-test-recovery.ps1 -TestVolumeRestore $true
```

---

## Troubleshooting

### Issue: Veeam Agent Installation Fails

**Symptoms:**
- Installation script reports errors
- Veeam service not found after installation

**Solutions:**
1. Verify system requirements met
2. Check Windows Update is current
3. Disable antivirus temporarily
4. Try manual installation:
   ```powershell
   # Run installer directly
   VeeamAgentWindows.exe /silent /accepteula
   ```
5. Check installation logs: `C:\ProgramData\Veeam\Logs`

---

### Issue: Cannot Access TrueNAS Share

**Symptoms:**
- "Path not accessible" errors
- Permission denied when writing test file

**Solutions:**
1. Test connectivity:
   ```powershell
   Test-Connection 172.21.203.18
   Test-NetConnection -ComputerName 172.21.203.18 -Port 445
   ```

2. Map network drive manually:
   ```powershell
   net use \\172.21.203.18\Veeam /user:USERNAME PASSWORD
   ```

3. Check TrueNAS:
   - Verify SMB service is running
   - Check share permissions
   - Verify dataset exists
   - Check firewall rules

4. Re-run repository setup:
   ```powershell
   .\3-setup-truenas-repository.ps1
   ```

---

### Issue: Backup Job Not Running

**Symptoms:**
- No backup files created
- Job shows as configured but doesn't execute

**Solutions:**
1. Check Veeam service:
   ```powershell
   Get-Service VeeamEndpointBackupSvc
   Start-Service VeeamEndpointBackupSvc
   ```

2. Verify schedule in Veeam UI:
   - Open Veeam Control Panel
   - Check job schedule settings
   - Run backup manually to test

3. Check logs:
   ```powershell
   Get-Content "C:\ProgramData\Veeam\Endpoint\Logs\*.log" | Select-String -Pattern "error|fail" -CaseSensitive:$false
   ```

4. Verify destination access:
   ```powershell
   Test-Path \\172.21.203.18\Veeam
   ```

---

### Issue: Schedule Conflicts

**Symptoms:**
- Backups and replication overlap
- Performance issues during operations

**Solutions:**
1. Run integration analysis:
   ```powershell
   .\6-integration-replication.ps1
   ```

2. Adjust schedules:
   ```powershell
   # Move backup earlier
   .\2-configure-backup-jobs.ps1 -ScheduleTime "01:00"

   # Move replication later
   .\6-integration-replication.ps1 -ReplicationStartTime "06:00"
   ```

3. Check actual backup duration:
   ```powershell
   .\4-monitor-backup-jobs.ps1
   ```

---

### Issue: Slow Backups

**Symptoms:**
- Backups take longer than expected
- Network performance degradation

**Solutions:**
1. Enable bandwidth limiting:
   ```powershell
   .\6-integration-replication.ps1 -EnableBandwidthLimit $true -BandwidthLimitMbps 100
   ```

2. Adjust compression level:
   ```powershell
   .\2-configure-backup-jobs.ps1 -Compression "Optimal"  # or "None" for faster
   ```

3. Check TrueNAS dataset properties:
   ```bash
   # On TrueNAS
   zfs get all tank/veeam-backups
   ```

4. Verify network connectivity:
   ```powershell
   # Test network speed to TrueNAS
   robocopy \\172.21.203.18\Veeam C:\Temp test.file /L
   ```

---

## Advanced Configuration

### Custom Backup Schedule
Edit in Veeam UI after initial configuration:
1. Open Veeam Control Panel
2. Edit backup job
3. Modify schedule settings
4. Save changes

### Multiple Backup Destinations
```powershell
# Create additional backup jobs manually in Veeam UI
# Or configure multiple repositories on TrueNAS
```

### Email Notifications
```powershell
# Configure in monitoring script
.\4-monitor-backup-jobs.ps1 `
    -EnableEmailAlerts $true `
    -EmailTo "admin@company.com" `
    -EmailFrom "veeam@company.com" `
    -SmtpServer "smtp.company.com" `
    -SmtpPort 587 `
    -SmtpUsername "notifications@company.com" `
    -SmtpPassword (Read-Host -AsSecureString -Prompt "SMTP Password")
```

### Encryption
Enable encryption for sensitive data:
```powershell
.\2-configure-backup-jobs.ps1 `
    -EnableEncryption $true `
    -EncryptionPassword "YourSecurePassword123!"
```

**Note**: Store encryption password securely! Lost passwords = unrecoverable backups.

---

## Maintenance Tasks

### Daily
- ✅ Check backup completion status
  ```powershell
  .\4-monitor-backup-jobs.ps1
  ```

### Weekly
- ✅ Review backup logs for warnings
- ✅ Check storage space on TrueNAS
- ✅ Verify replication is working

### Monthly
- ✅ Run recovery test
  ```powershell
  .\5-test-recovery.ps1
  ```
- ✅ Review retention policy
- ✅ Clean up old logs if disk space low

### Quarterly
- ✅ Full recovery test (volume restore)
- ✅ Review and update backup schedule
- ✅ Update Veeam Agent if new version available
- ✅ Test bare-metal recovery procedure

### Annually
- ✅ Review entire backup strategy
- ✅ Update documentation
- ✅ Disaster recovery drill

---

## Best Practices

### 1. Retention Policy
- **Short-term**: 7-14 daily restore points
- **Long-term**: Use TrueNAS snapshots + replication
- **Archive**: Consider separate archival backups

### 2. Testing
- **Test restores regularly** - backups are only good if you can restore
- **Document RTO/RPO** - know your recovery times
- **Practice recovery procedures** - ensure team knows process

### 3. Monitoring
- **Set up email alerts** for failures
- **Review logs weekly** for warnings
- **Monitor storage growth** to avoid space issues

### 4. Security
- **Encrypt backups** if data is sensitive
- **Secure credentials** - use Windows Credential Manager
- **Limit access** to backup repository
- **Test restored data** for corruption

### 5. Performance
- **Schedule during off-hours** (2 AM recommended)
- **Monitor network impact** during backups
- **Use compression** to save storage space
- **Adjust recordsize** on TrueNAS for performance

### 6. Documentation
- **Keep recovery procedures updated**
- **Document all configuration changes**
- **Maintain contact lists** for emergencies
- **Track test results** over time

---

## Support and Resources

### Official Documentation
- Veeam Agent for Windows: https://helpcenter.veeam.com/
- TrueNAS Scale: https://www.truenas.com/docs/scale/
- PowerShell: https://learn.microsoft.com/powershell/

### Log Locations
- **Veeam Logs**: `C:\ProgramData\Veeam\Endpoint\Logs\`
- **Script Logs**: `C:\Logs\Veeam\`
- **Windows Event Log**: Event Viewer > Applications and Services Logs > Veeam Backup

### Useful Commands
```powershell
# Check Veeam service status
Get-Service VeeamEndpointBackupSvc

# View recent backup events
Get-WinEvent -LogName "Veeam Backup" -MaxEvents 20

# Check backup file sizes
Get-ChildItem \\172.21.203.18\Veeam -Recurse | Measure-Object -Property Length -Sum

# Test network path
Test-Path \\172.21.203.18\Veeam -Verbose

# View scheduled tasks
Get-ScheduledTask | Where-Object {$_.TaskName -like "*Veeam*"}
```

---

## License

Veeam Agent for Windows (FREE) - No license required for basic features.

This automation system provided as-is for use with TrueNAS infrastructure.

---

## Version History

### v1.0 (2025-12-10)
- Initial release
- Complete automation suite
- 6 core scripts + master orchestrator
- Comprehensive documentation
- TrueNAS integration support

---

## Credits

Developed for automated Veeam deployment on Windows systems with TrueNAS (Baby NAS) backup infrastructure.

For issues or enhancements, review logs in `C:\Logs\Veeam\` and check configuration files.
