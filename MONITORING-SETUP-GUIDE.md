# Comprehensive Backup Monitoring Infrastructure Guide

## Overview

This monitoring system provides real-time status tracking and alerting for all three backup systems:
- Veeam Backup (Windows backup)
- Phone Backup (Android/iPhone backups)
- Time Machine (macOS backups)

## Components

### 1. BACKUP-MONITORING-DASHBOARD.ps1
**Real-time interactive dashboard** showing backup status with color-coded indicators.

**Features:**
- Live monitoring of all three backup systems
- Storage quota usage visualization
- Network connectivity status
- 5-minute auto-refresh (configurable)
- Color-coded status (green/yellow/red)

**Usage:**
```powershell
# Run with default 5-minute refresh
.\BACKUP-MONITORING-DASHBOARD.ps1

# Custom refresh interval (60 seconds)
.\BACKUP-MONITORING-DASHBOARD.ps1 -RefreshInterval 60

# Specify TrueNAS and Baby NAS IPs
.\BACKUP-MONITORING-DASHBOARD.ps1 -TrueNASIP "10.0.0.89" -BabyNASIP "10.0.0.90"
```

**Status Indicators:**
- `✓ OK` (Green) - System is healthy and current
- `⚠ WARNING` (Yellow) - Action needed within 24 hours
- `✗ CRITICAL` (Red) - Immediate action required

### 2. BACKUP-ALERTING-SETUP.ps1
**Configuration wizard** for setting up email and webhook alerts.

**Features:**
- Interactive setup menu
- Email alert configuration (SMTP)
- Slack webhook integration
- Microsoft Teams webhook integration
- Discord webhook integration
- Alert channel testing

**Usage:**
```powershell
# Interactive setup mode
.\BACKUP-ALERTING-SETUP.ps1

# Command-line configuration
.\BACKUP-ALERTING-SETUP.ps1 -EmailRecipients "admin@company.com,ops@company.com" `
    -EmailFrom "backups@company.com" `
    -EnableSlack `
    -SlackWebhookUrl "https://hooks.slack.com/services/..."
```

**Configuration File:** `C:\BackupMonitoring\Config\alerting-config.json`

**Alert Thresholds:**
- Veeam Backup: Alert if older than 28 hours
- Phone Backup: Alert if older than 24 hours
- Time Machine: Alert if older than 24 hours
- Storage Quota: Alert at 80% usage

### 3. HEALTH-CHECK-DAILY.ps1
**Automated daily health check** running every morning at 6:00 AM.

**Features:**
- Comprehensive backup system checks
- SMB connectivity verification
- Network path accessibility testing
- Daily HTML report generation
- Email report delivery
- Pass/fail status logging

**Usage:**
```powershell
# Run manual health check
.\HEALTH-CHECK-DAILY.ps1

# Run with email report
.\HEALTH-CHECK-DAILY.ps1 -EmailReport $true

# Custom report path
.\HEALTH-CHECK-DAILY.ps1 -ReportPath "E:\Backup-Reports"
```

**Checks Performed:**
1. Veeam backup status and age
2. Phone backup status and age
3. Time Machine backup status and age
4. SMB share accessibility
5. Network connectivity (TrueNAS, Baby NAS)
6. Local disk space
7. Scheduled tasks status

**Report Location:** `C:\Logs\BackupMonitoring\Reports\health-check-*.html`

### 4. BACKUP-METRICS-REPORT.ps1
**Weekly metrics and capacity planning** report.

**Features:**
- Backup size growth trends
- Compression ratio analysis
- Storage quota utilization
- Backup success rate tracking
- Capacity forecasting
- Capacity planning recommendations
- HTML report generation

**Usage:**
```powershell
# Generate weekly metrics report
.\BACKUP-METRICS-REPORT.ps1

# Generate with PDF output
.\BACKUP-METRICS-REPORT.ps1 -GeneratePDF $true

# Custom data path
.\BACKUP-METRICS-REPORT.ps1 -DataPath "X:\"
```

**Report Contents:**
- Total backup sizes
- Compression ratios
- Weekly growth trends
- Storage capacity forecast
- Recommendations for capacity management

**Report Location:** `C:\Logs\BackupMonitoring\Reports\metrics-report-weekly-*.html`

### 5. MONITORING-WEBHOOK-ALERTING.ps1
**Real-time webhook integration** for Slack, Teams, and Discord.

**Features:**
- Slack webhook support
- Microsoft Teams integration
- Discord webhook support
- Custom webhook messages
- Real-time failure notifications
- Backup completion confirmations
- Webhook testing utilities

**Usage:**
```powershell
# Send alert to webhooks
.\MONITORING-WEBHOOK-ALERTING.ps1 `
    -AlertType "failure" `
    -SystemName "veeam" `
    -Message "Veeam backup failed" `
    -Details "Backup job 'Daily Backup' failed with exit code 1"

# Test all configured webhooks
.\MONITORING-WEBHOOK-ALERTING.ps1 -TestAll

# Send success notification
.\MONITORING-WEBHOOK-ALERTING.ps1 `
    -AlertType "success" `
    -SystemName "phone" `
    -Message "Phone backup completed successfully"
```

**Alert Types:**
- `failure` - Backup job failed
- `warning` - Backup is aging or quota is high
- `success` - Backup completed successfully
- `summary` - Weekly summary report
- `test` - Test alert

**Systems:**
- `veeam` - Veeam Backup system
- `phone` - Phone backup system
- `timemachine` - Time Machine backup system
- `storage` - Storage capacity alerts
- `system` - General system alerts

## Installation and Setup

### Step 1: Create Directories
```powershell
# Create log directory
New-Item -Path "C:\Logs\BackupMonitoring" -ItemType Directory -Force

# Create config directory
New-Item -Path "C:\BackupMonitoring\Config" -ItemType Directory -Force

# Create reports directory
New-Item -Path "C:\Logs\BackupMonitoring\Reports" -ItemType Directory -Force
```

### Step 2: Configure Alerting
```powershell
# Run setup wizard
cd C:\path\to\windows-scripts
.\BACKUP-ALERTING-SETUP.ps1
```

**Follow the interactive menu:**
1. Configure Email Alerts
2. Configure Slack Webhook
3. Configure Teams Webhook
4. Configure Discord Webhook
5. Test All Alert Channels

### Step 3: Schedule Daily Health Check
```powershell
# Create scheduled task for 6:00 AM daily
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\path\to\HEALTH-CHECK-DAILY.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "Daily Backup Health Check" -Action $action -Trigger $trigger -Principal $principal -Description "Daily backup system health check"
```

### Step 4: Schedule Weekly Metrics Report
```powershell
# Create scheduled task for Monday at 7:00 AM
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\path\to\BACKUP-METRICS-REPORT.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 7:00AM
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "Weekly Backup Metrics Report" -Action $action -Trigger $trigger -Principal $principal -Description "Weekly backup metrics and capacity planning report"
```

## Webhook Configuration

### Slack
1. Create Slack Webhook URL:
   - Go to your Slack workspace settings
   - Navigate to Apps & Integrations > Incoming Webhooks
   - Create new webhook, copy URL
   - Example: `https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX`

2. Configure in alerting setup:
   - Enter webhook URL when prompted
   - Run tests to verify connectivity

### Microsoft Teams
1. Create Teams Webhook URL:
   - Open your Teams channel
   - Click "..." (More options) > Connectors
   - Search for "Incoming Webhook"
   - Configure name and icon
   - Copy webhook URL

2. Configure in alerting setup:
   - Enter webhook URL when prompted
   - Run tests to verify connectivity

### Discord
1. Create Discord Webhook URL:
   - Right-click channel > Edit Channel
   - Go to Integrations > Webhooks
   - Create New Webhook
   - Copy webhook URL
   - Example: `https://discord.com/api/webhooks/123456789/abcdefghijklmnop`

2. Configure in alerting setup:
   - Enter webhook URL when prompted
   - Run tests to verify connectivity

## Email Configuration

### Gmail
```
SMTP Server: smtp.gmail.com
SMTP Port: 587
Username: your-email@gmail.com
Password: app-specific password (not your regular password)
```

**Note:** Enable 2-factor authentication and create an App Password at https://myaccount.google.com/apppasswords

### Office 365
```
SMTP Server: smtp.office365.com
SMTP Port: 587
Username: your-email@company.com
Password: your office 365 password
```

### Custom SMTP Server
Configure your organization's SMTP server details during setup wizard.

## Monitoring Dashboard Usage

The dashboard displays:

### Backup Systems Section
- System name with status indicator
- Last backup time
- Backup size in GB
- Next scheduled run time
- Days since last backup

### Storage Quotas Section
- Storage used/total capacity
- Percentage utilization
- Visual progress bar
- Status indicator

### Network Connectivity Section
- TrueNAS connectivity status
- Baby NAS connectivity status
- Ping response time

## Alert Message Templates

### Email Alerts
Subject: `[SEVERITY] System - Alert Type`
```
Backup Monitoring Alert

System: [SystemName]
Severity: [CRITICAL/WARNING/INFO]
Time: [Timestamp]

Message:
[Alert message text]

Details:
[Additional details]

---
This is an automated alert from Backup Monitoring System
```

### Slack Alerts
```
❌ 💾 Veeam Backup - failure
Veeam backup failed or did not complete

Hostname: MYPC
Timestamp: 2024-01-15T10:30:45Z
Details: [Alert details]
```

### Teams Alerts
```
MessageCard format with:
- Color-coded header (red for failure, yellow for warning, green for success)
- System and alert type
- Hostname and timestamp
- Detailed facts section
```

### Discord Alerts
```
Embeds with:
- Color-coded title
- Description field
- Alert type, hostname, timestamp fields
- Details section
```

## Log Files

### Dashboard Logs
Location: `C:\Logs\BackupMonitoring\dashboard-YYYYMMDD.log`
- Real-time status updates
- Backup system status snapshots
- Network connectivity checks

### Health Check Logs
Location: `C:\Logs\BackupMonitoring\health-check-YYYYMMDD-hhmmss.log`
- Individual check results
- Pass/fail status
- Detailed error messages

### Reports
Location: `C:\Logs\BackupMonitoring\Reports\`
- `health-check-*.html` - Daily health reports
- `metrics-report-weekly-*.html` - Weekly metrics
- `dashboard-*.log` - Dashboard activity logs

## Troubleshooting

### Dashboard Shows "UNKNOWN" Status
1. Verify backup paths are accessible
2. Check SMB share connectivity
3. Confirm backup locations contain files
4. Review log file for errors

### Alerts Not Sending
1. Check alerting configuration: `C:\BackupMonitoring\Config\alerting-config.json`
2. Test SMTP connection (for email)
3. Test webhooks: `.\MONITORING-WEBHOOK-ALERTING.ps1 -TestAll`
4. Verify firewall allows outbound connections

### No Health Check Report Generated
1. Check task scheduler is enabled
2. Verify script has read permissions to backup paths
3. Check `C:\Logs\BackupMonitoring\` directory exists
4. Run script manually to see error messages

### Webhook Tests Pass but Alerts Don't Send
1. Verify webhook URLs in configuration
2. Check network connectivity to webhook services
3. Review actual alert message format
4. Check webhook service logs/settings

## Performance Optimization

### Dashboard Performance
- Reduce refresh interval for more responsive updates (30-60 seconds)
- For slower networks, increase interval (10-15 minutes)
- Close other resource-intensive applications

### Storage Usage
- Health check reports keep 30 days of logs
- Old logs automatically cleaned up
- Manually delete reports to free space: `Remove-Item C:\Logs\BackupMonitoring\Reports\health-check-*.html`

### Network Impact
- Dashboard performs minimal network queries
- Webhook alerts are lightweight JSON payloads
- Email alerts create brief SMTP connections

## Security Considerations

### Credentials
- SMTP passwords stored in alerting-config.json
- Restrict file permissions: `icacls C:\BackupMonitoring\Config /grant:r "%USERNAME%:(F)"`
- Consider using Azure Key Vault or credential manager

### Webhook URLs
- Keep webhook URLs confidential
- Regenerate webhooks if exposed
- Restrict webhook access in platform settings

### Log Files
- Logs may contain sensitive information
- Restrict access to `C:\Logs\BackupMonitoring\`
- Archive old logs securely

## Best Practices

1. **Regular Testing**
   - Test alerts monthly: `.\MONITORING-WEBHOOK-ALERTING.ps1 -TestAll`
   - Verify dashboard displays current data
   - Check that reports are generating

2. **Threshold Adjustment**
   - Review thresholds quarterly
   - Adjust based on actual backup patterns
   - Consider business SLAs

3. **Report Review**
   - Review daily health checks
   - Analyze weekly metrics for trends
   - Plan capacity based on forecasts

4. **Documentation**
   - Keep webhook URLs in secure location
   - Document alert recipients
   - Maintain runbook for alerts

## Integration Examples

### PowerShell Task Scheduler
```powershell
# Create comprehensive monitoring task
$script = @"
# Combined health check and metrics
.\HEALTH-CHECK-DAILY.ps1 -EmailReport $true
if ((Get-Date).DayOfWeek -eq 'Monday') {
    .\BACKUP-METRICS-REPORT.ps1
}
"@

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -Command `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM
Register-ScheduledTask -TaskName "Backup Monitoring Suite" -Action $action -Trigger $trigger -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest)
```

### Automated Alert Response
```powershell
# Send webhook alert when backup fails
if ($backupFailed) {
    .\MONITORING-WEBHOOK-ALERTING.ps1 `
        -AlertType "failure" `
        -SystemName "veeam" `
        -Message "Backup failed at $(Get-Date)" `
        -Details $errorDetails
}
```

## Additional Resources

- TrueNAS Documentation: https://www.truenas.com/docs/
- Veeam Agent for Windows: https://www.veeam.com/windows-backup-free.html
- PowerShell Documentation: https://learn.microsoft.com/en-us/powershell/
- Webhook Guides:
  - Slack: https://api.slack.com/messaging/webhooks
  - Teams: https://docs.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/connectors-using
  - Discord: https://discord.com/developers/docs/resources/webhook

## Support

For issues or feature requests:
1. Check troubleshooting section above
2. Review log files for error messages
3. Run individual scripts manually to isolate issues
4. Verify configuration with setup wizard

---

**Version:** 1.0
**Last Updated:** January 2025
**Author:** Automated Backup Monitoring System
