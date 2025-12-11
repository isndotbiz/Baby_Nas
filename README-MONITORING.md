# Backup Monitoring & Alerting Infrastructure

Complete production-ready monitoring solution for Veeam, Phone Backup, and Time Machine systems.

## Quick Start (2 minutes)

```powershell
# Run one-click setup
.\SETUP-MONITORING-QUICK-START.ps1

# Follow the interactive wizard to:
# - Create directories
# - Configure alerts
# - Set up scheduled tasks
# - Test monitoring
```

## Core Components

### 1. BACKUP-MONITORING-DASHBOARD.ps1
Real-time visual dashboard with live backup status, storage metrics, and network connectivity.

**Features:**
- Color-coded status indicators (✓ OK / ⚠ WARNING / ✗ CRITICAL)
- Live storage quota visualization
- Network connectivity monitoring
- Auto-refresh every 5 minutes (configurable)

**Run:**
```powershell
.\BACKUP-MONITORING-DASHBOARD.ps1
.\BACKUP-MONITORING-DASHBOARD.ps1 -RefreshInterval 60  # 60 seconds
```

### 2. HEALTH-CHECK-DAILY.ps1
Comprehensive daily health check with HTML reporting.

**Checks:**
- All three backup systems
- SMB share accessibility
- Network path connectivity
- Local disk space
- Scheduled task status

**Usage:**
```powershell
.\HEALTH-CHECK-DAILY.ps1                    # Run once
.\HEALTH-CHECK-DAILY.ps1 -EmailReport $true # With email
```

**Reports:** `C:\Logs\BackupMonitoring\Reports\health-check-*.html`

### 3. BACKUP-METRICS-REPORT.ps1
Weekly capacity planning and trend analysis report.

**Metrics:**
- Backup size growth trends
- Compression ratios
- Storage quota utilization
- Backup success rates
- Capacity forecasting
- Recommendations

**Run:**
```powershell
.\BACKUP-METRICS-REPORT.ps1
.\BACKUP-METRICS-REPORT.ps1 -GeneratePDF $true
```

**Reports:** `C:\Logs\BackupMonitoring\Reports\metrics-report-weekly-*.html`

### 4. BACKUP-ALERTING-SETUP.ps1
Interactive configuration wizard for email and webhook alerts.

**Configures:**
- Email alerts (SMTP)
- Slack webhooks
- Microsoft Teams webhooks
- Discord webhooks
- Alert thresholds
- Notification rules

**Run:**
```powershell
.\BACKUP-ALERTING-SETUP.ps1
```

**Configuration:** `C:\BackupMonitoring\Config\alerting-config.json`

### 5. MONITORING-WEBHOOK-ALERTING.ps1
Send real-time alerts to Slack, Teams, or Discord.

**Usage:**
```powershell
# Send failure alert
.\MONITORING-WEBHOOK-ALERTING.ps1 `
    -AlertType failure `
    -SystemName veeam `
    -Message "Veeam backup failed"

# Test all webhooks
.\MONITORING-WEBHOOK-ALERTING.ps1 -TestAll
```

## Installation

### Method 1: Quick Setup (Recommended)
```powershell
# Run one-click installer
.\SETUP-MONITORING-QUICK-START.ps1

# This creates:
# - Directories (C:\BackupMonitoring, C:\Logs\BackupMonitoring)
# - Scheduled tasks (Daily health check, Weekly metrics)
# - Configuration template
```

### Method 2: Manual Setup
```powershell
# Create directories
New-Item -Path "C:\BackupMonitoring\Config" -ItemType Directory -Force
New-Item -Path "C:\Logs\BackupMonitoring\Reports" -ItemType Directory -Force

# Configure alerts
.\BACKUP-ALERTING-SETUP.ps1

# Schedule daily health check
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File $PWD\HEALTH-CHECK-DAILY.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "Daily Backup Health Check" `
    -Action $action -Trigger $trigger -Principal $principal
```

## Configuration

### Alert Thresholds
Edit `C:\BackupMonitoring\Config\alerting-config.json`:

```json
{
  "thresholds": {
    "veeamBackupAgeHours": 28,
    "phoneBackupAgeHours": 24,
    "timeMachineAgeHours": 24,
    "storageQuotaPercent": 80
  }
}
```

### Email Configuration
```json
{
  "alerts": {
    "email": {
      "enabled": true,
      "recipients": ["admin@company.com"],
      "smtpServer": "smtp.gmail.com",
      "smtpPort": 587,
      "fromAddress": "backups@company.com"
    }
  }
}
```

### Webhook Configuration
```json
{
  "alerts": {
    "webhooks": {
      "slack": {
        "enabled": true,
        "url": "https://hooks.slack.com/services/..."
      },
      "teams": {
        "enabled": true,
        "url": "https://outlook.webhook.office.com/..."
      },
      "discord": {
        "enabled": true,
        "url": "https://discord.com/api/webhooks/..."
      }
    }
  }
}
```

## Webhook URLs

### Slack
1. Go to your workspace → Apps & Integrations
2. Create Incoming Webhook
3. Copy URL: `https://hooks.slack.com/services/T.../B.../...`

### Microsoft Teams
1. Open channel → Connectors
2. Configure Incoming Webhook
3. Copy URL: `https://outlook.webhook.office.com/webhookb2/...`

### Discord
1. Channel → Edit → Integrations → Webhooks
2. Create Webhook
3. Copy URL: `https://discord.com/api/webhooks/...`

## Scheduled Tasks

After setup, verify tasks in Windows Task Scheduler:

- **Daily Backup Health Check** - 6:00 AM daily
- **Weekly Backup Metrics Report** - 7:00 AM Monday

To manually manage:
```powershell
# View all backup-related tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like "*Backup*" }

# Disable a task
Disable-ScheduledTask -TaskName "Daily Backup Health Check"

# Enable a task
Enable-ScheduledTask -TaskName "Daily Backup Health Check"

# Run task manually
Start-ScheduledTask -TaskName "Daily Backup Health Check"
```

## Monitoring Locations

### Logs
- Dashboard: `C:\Logs\BackupMonitoring\dashboard-YYYYMMDD.log`
- Health checks: `C:\Logs\BackupMonitoring\health-check-*.log`

### Reports
- Health reports: `C:\Logs\BackupMonitoring\Reports\health-check-*.html`
- Metrics reports: `C:\Logs\BackupMonitoring\Reports\metrics-report-*.html`

### Configuration
- Main config: `C:\BackupMonitoring\Config\alerting-config.json`

## Alert Types

### Severity Levels
- **CRITICAL** (Red) - Immediate action required
- **WARNING** (Yellow) - Action needed within 24 hours
- **SUCCESS** (Green) - Backup completed successfully
- **INFO** (Blue) - Informational alert

### Alert Messages
- Veeam backup failure/warning/success
- Phone backup not synced
- Time Machine backup overdue
- Storage quota exceeded
- Network path unavailable
- Disk space warnings

## Troubleshooting

### Dashboard Shows "UNKNOWN" Status
```powershell
# Verify backup paths exist and contain files
Test-Path "X:\VeeamBackups"
Get-ChildItem "X:\VeeamBackups" -Recurse | Measure-Object

# Check SMB share connectivity
Test-Path "\\10.0.0.89\Veeam"
```

### Alerts Not Sending
```powershell
# Test SMTP connection
Test-NetConnection smtp.gmail.com -Port 587

# Test webhooks
.\MONITORING-WEBHOOK-ALERTING.ps1 -TestAll

# Check configuration
Get-Content "C:\BackupMonitoring\Config\alerting-config.json" | ConvertFrom-Json | ConvertTo-Json
```

### No Reports Generated
```powershell
# Verify scheduled task exists
Get-ScheduledTask -TaskName "Daily Backup Health Check"

# Check task history
$taskName = "Daily Backup Health Check"
$task = Get-ScheduledTask -TaskName $taskName
Get-ScheduledTaskInfo -TaskName $taskName

# Run script manually to see errors
.\HEALTH-CHECK-DAILY.ps1
```

### Network Issues
```powershell
# Test connectivity to backup systems
Test-Connection 10.0.0.89 -Count 2
Test-Connection 10.0.0.90 -Count 2

# Test SMB shares
Test-Path "\\10.0.0.89\Veeam"
Test-Path "\\10.0.0.89\Phone-Backups"
Test-Path "\\10.0.0.89\TimeMachine"
```

## Performance Considerations

### Dashboard Refresh Intervals
- **30 seconds**: Real-time monitoring (high network usage)
- **60-120 seconds**: Balance between responsiveness and efficiency
- **300 seconds (5 min)**: Default, recommended for most installations
- **600+ seconds**: Low-traffic environments

### Storage
- Automatic cleanup of logs older than 30 days
- Reports retained for 1 year
- To manually clean: `Remove-Item C:\Logs\BackupMonitoring\Reports\health-check-*.html`

### Network Impact
- Minimal: Dashboard uses cached data
- Webhooks: Lightweight JSON payloads (~2KB)
- Email: Brief SMTP connections

## Security

### Credentials
- SMTP passwords stored in `alerting-config.json`
- Restrict file permissions: `icacls C:\BackupMonitoring\Config /grant:r "%USERNAME%:(F)"`
- Regenerate webhook URLs if exposed
- Use Azure Key Vault for production deployments

### Access Control
```powershell
# Restrict config directory to administrators
icacls "C:\BackupMonitoring\Config" /inheritance:r /grant:r "Administrators:(F)" /grant:r "SYSTEM:(F)"

# Restrict logs directory
icacls "C:\Logs\BackupMonitoring" /inheritance:r /grant:r "Administrators:(F)" /grant:r "SYSTEM:(F)"
```

## Documentation

- **MONITORING-SETUP-GUIDE.md** - Comprehensive setup and configuration guide
- **ALERTING-CONFIG-TEMPLATE.json** - Example configuration with all options
- **README-MONITORING.md** - This file (quick reference)

## Common Tasks

### View Current Backup Status
```powershell
.\BACKUP-MONITORING-DASHBOARD.ps1
```

### Run Health Check Now
```powershell
.\HEALTH-CHECK-DAILY.ps1
```

### Generate Weekly Report Now
```powershell
.\BACKUP-METRICS-REPORT.ps1
```

### Send Test Alert
```powershell
.\MONITORING-WEBHOOK-ALERTING.ps1 -TestAll
```

### Reconfigure Alerts
```powershell
.\BACKUP-ALERTING-SETUP.ps1
```

### Update Configuration
```powershell
# Edit directly
notepad C:\BackupMonitoring\Config\alerting-config.json

# Or use setup wizard
.\BACKUP-ALERTING-SETUP.ps1
```

## Advanced

### Integrate with Existing Tools
```powershell
# Send to custom API
.\MONITORING-WEBHOOK-ALERTING.ps1 `
    -AlertType warning `
    -SystemName storage `
    -Message "Storage quota at 80%" `
    -Details "Drive X: 8000GB/10000GB"

# Parse configuration programmatically
$config = Get-Content "C:\BackupMonitoring\Config\alerting-config.json" | ConvertFrom-Json
$emailRecipients = $config.alerts.email.recipients
```

### Custom Alerts
Add to your backup scripts:
```powershell
# After backup completes
if ($backupSuccess) {
    .\MONITORING-WEBHOOK-ALERTING.ps1 `
        -AlertType success `
        -SystemName veeam `
        -Message "Daily backup completed" `
        -Details "Size: 500GB, Duration: 2 hours"
} else {
    .\MONITORING-WEBHOOK-ALERTING.ps1 `
        -AlertType failure `
        -SystemName veeam `
        -Message "Daily backup failed" `
        -Details "Error: $(Get-LastError)"
}
```

### Email Attachments
```powershell
# Manually attach report to email
$reportPath = Get-ChildItem "C:\Logs\BackupMonitoring\Reports\" -Filter "health-check-*.html" -Latest

# Can be sent via Send-MailMessage with -Attachments parameter
```

## Support & Resources

- **PowerShell Docs**: https://learn.microsoft.com/powershell/
- **Veeam Docs**: https://www.veeam.com/windows-backup-free.html
- **TrueNAS Docs**: https://www.truenas.com/docs/
- **Slack Webhooks**: https://api.slack.com/messaging/webhooks
- **Teams Webhooks**: https://docs.microsoft.com/teams/platform/webhooks-and-connectors
- **Discord Webhooks**: https://discord.com/developers/docs/resources/webhook

## Version History

### v1.0 (January 2025)
- Initial release
- All three backup systems monitoring
- Email and webhook alerting
- Comprehensive dashboard
- Daily health checks
- Weekly metrics and capacity planning
- Production-ready configuration

---

**Questions or issues?** Check MONITORING-SETUP-GUIDE.md for detailed documentation.

**Author**: Automated Backup Monitoring System
**License**: MIT
**Compatibility**: Windows Server 2016+, Windows 10/11
