#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Backup System Alert Configuration and Setup

.DESCRIPTION
    Configures email and webhook alerts for all three backup systems:
    - Veeam backup failures
    - Phone backup not synced in 24 hours
    - Time Machine not backed up in 24 hours
    - Storage quota warnings (>80% usage)
    - Custom webhook alerts to Slack/Teams/Discord

.PARAMETER EmailRecipients
    Email addresses to receive alerts (comma-separated)

.PARAMETER SMTPServer
    SMTP server address (default: smtp.gmail.com)

.PARAMETER SMTPPort
    SMTP port (default: 587)

.PARAMETER EmailFrom
    From email address for alerts

.PARAMETER EnableSlack
    Enable Slack webhook notifications

.PARAMETER SlackWebhookUrl
    Slack webhook URL

.PARAMETER EnableTeams
    Enable Microsoft Teams webhook notifications

.PARAMETER TeamsWebhookUrl
    Teams webhook URL

.PARAMETER EnableDiscord
    Enable Discord webhook notifications

.PARAMETER DiscordWebhookUrl
    Discord webhook URL

.EXAMPLE
    .\BACKUP-ALERTING-SETUP.ps1 -EmailRecipients "admin@example.com" -EmailFrom "backups@example.com"

.NOTES
    Author: Automated Backup Monitoring System
    Version: 1.0
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$EmailRecipients = "",

    [Parameter(Mandatory=$false)]
    [string]$SMTPServer = "smtp.gmail.com",

    [Parameter(Mandatory=$false)]
    [int]$SMTPPort = 587,

    [Parameter(Mandatory=$false)]
    [string]$EmailFrom = "",

    [Parameter(Mandatory=$false)]
    [switch]$EnableSlack,

    [Parameter(Mandatory=$false)]
    [string]$SlackWebhookUrl = "",

    [Parameter(Mandatory=$false)]
    [switch]$EnableTeams,

    [Parameter(Mandatory=$false)]
    [string]$TeamsWebhookUrl = "",

    [Parameter(Mandatory=$false)]
    [switch]$EnableDiscord,

    [Parameter(Mandatory=$false)]
    [string]$DiscordWebhookUrl = ""
)

$ErrorActionPreference = "Stop"

# Configuration directory
$ConfigDir = "C:\BackupMonitoring\Config"
$ConfigFile = "$ConfigDir\alerting-config.json"
$LogDir = "C:\Logs\BackupMonitoring"

# Create directories
if (-not (Test-Path $ConfigDir)) {
    New-Item -Path $ConfigDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

###############################################################################
# FUNCTIONS
###############################################################################

function Test-SMTPConnection {
    param(
        [string]$Server,
        [int]$Port
    )

    Write-Host "Testing SMTP connection to $Server`:$Port..." -ForegroundColor Yellow

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($Server, $Port)

        if ($tcpClient.Connected) {
            Write-Host "SMTP connection successful" -ForegroundColor Green
            return $true
        }
        $tcpClient.Dispose()
    } catch {
        Write-Host "SMTP connection failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }

    return $false
}

function Test-WebhookUrl {
    param(
        [string]$Url,
        [string]$Name
    )

    Write-Host "Testing $Name webhook..." -ForegroundColor Yellow

    try {
        $testPayload = @{
            text = "Test alert from Backup Monitoring System"
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri $Url -Method Post -Body $testPayload -ContentType "application/json" -TimeoutSec 10

        Write-Host "$Name webhook test successful" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "$Name webhook test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function New-AlertingConfiguration {
    param(
        [string]$EmailRecipients,
        [string]$SMTPServer,
        [int]$SMTPPort,
        [string]$EmailFrom,
        [bool]$EnableSlack,
        [string]$SlackWebhookUrl,
        [bool]$EnableTeams,
        [string]$TeamsWebhookUrl,
        [bool]$EnableDiscord,
        [string]$DiscordWebhookUrl
    )

    $config = @{
        version = "1.0"
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        alerts = @{
            email = @{
                enabled = $false
                recipients = @()
                smtpServer = $SMTPServer
                smtpPort = $SMTPPort
                fromAddress = ""
                criticalOnly = $false
                includeAttachments = $false
            }
            webhooks = @{
                slack = @{
                    enabled = $EnableSlack
                    url = $SlackWebhookUrl
                }
                teams = @{
                    enabled = $EnableTeams
                    url = $TeamsWebhookUrl
                }
                discord = @{
                    enabled = $EnableDiscord
                    url = $DiscordWebhookUrl
                }
            }
        }
        thresholds = @{
            veeamBackupAgeHours = 28
            phoneBackupAgeHours = 24
            timeMachineAgeHours = 24
            storageQuotaPercent = 80
            diskSpaceWarningPercent = 10
        }
        backupSystems = @{
            veeam = @{
                enabled = $true
                name = "Veeam Backup"
                paths = @("X:\VeeamBackups", "D:\VeeamBackups")
                tlsPath = "\\10.0.0.89\Veeam"
            }
            phone = @{
                enabled = $true
                name = "Phone Backup"
                paths = @("X:\Phone-Backups", "D:\Phone-Backups")
                tlsPath = "\\10.0.0.89\Phone-Backups"
            }
            timeMachine = @{
                enabled = $true
                name = "Time Machine"
                paths = @("X:\TimeMachine", "D:\TimeMachine")
                tlsPath = "\\10.0.0.89\TimeMachine"
            }
        }
        alertMessages = @{
            veeamFailure = @{
                subject = "ALERT: Veeam Backup Failed"
                template = "Veeam backup has failed or has not completed in the expected time."
            }
            phoneNotSynced = @{
                subject = "ALERT: Phone Backup Not Synced"
                template = "Phone backups have not synced in over 24 hours."
            }
            timeMachineNotBacked = @{
                subject = "ALERT: Time Machine Backup Overdue"
                template = "Time Machine backup has not completed in over 24 hours."
            }
            storageQuotaWarning = @{
                subject = "WARNING: Backup Storage Quota High"
                template = "Backup storage quota has exceeded configured threshold."
            }
        }
    }

    if (-not [string]::IsNullOrEmpty($EmailRecipients)) {
        $config.alerts.email.enabled = $true
        $config.alerts.email.recipients = @($EmailRecipients -split ',').Trim()
        $config.alerts.email.fromAddress = $EmailFrom
    }

    return $config
}

function Save-Configuration {
    param([object]$Config)

    try {
        $Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigFile -Encoding UTF8
        Write-Host "Configuration saved to: $ConfigFile" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Failed to save configuration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-AlertConfiguration {
    param([object]$Config)

    Write-Host ""
    Write-Host "TESTING ALERT CHANNELS" -ForegroundColor Cyan
    Write-Host "═" * 50 -ForegroundColor Cyan
    Write-Host ""

    $results = @()

    # Test Email
    if ($Config.alerts.email.enabled) {
        $result = Test-SMTPConnection -Server $Config.alerts.email.smtpServer -Port $Config.alerts.email.smtpPort

        $results += [PSCustomObject]@{
            Channel = "Email (SMTP)"
            Configured = $true
            Connected = $result
            Details = "Server: $($Config.alerts.email.smtpServer) Recipients: $($Config.alerts.email.recipients -join ', ')"
        }
    }

    # Test Slack
    if ($Config.alerts.webhooks.slack.enabled -and -not [string]::IsNullOrEmpty($Config.alerts.webhooks.slack.url)) {
        $result = Test-WebhookUrl -Url $Config.alerts.webhooks.slack.url -Name "Slack"

        $results += [PSCustomObject]@{
            Channel = "Slack Webhook"
            Configured = $true
            Connected = $result
            Details = "Webhook configured"
        }
    }

    # Test Teams
    if ($Config.alerts.webhooks.teams.enabled -and -not [string]::IsNullOrEmpty($Config.alerts.webhooks.teams.url)) {
        $result = Test-WebhookUrl -Url $Config.alerts.webhooks.teams.url -Name "Teams"

        $results += [PSCustomObject]@{
            Channel = "Microsoft Teams"
            Configured = $true
            Connected = $result
            Details = "Webhook configured"
        }
    }

    # Test Discord
    if ($Config.alerts.webhooks.discord.enabled -and -not [string]::IsNullOrEmpty($Config.alerts.webhooks.discord.url)) {
        $result = Test-WebhookUrl -Url $Config.alerts.webhooks.discord.url -Name "Discord"

        $results += [PSCustomObject]@{
            Channel = "Discord Webhook"
            Configured = $true
            Connected = $result
            Details = "Webhook configured"
        }
    }

    if ($results.Count -eq 0) {
        Write-Host "No alert channels configured" -ForegroundColor Yellow
        return $false
    }

    $results | Format-Table -Property Channel, Configured, Connected, Details -AutoSize
    Write-Host ""

    $successful = ($results | Where-Object { $_.Connected }).Count
    Write-Host "Alert Channels Status: $successful/$($results.Count) connected" -ForegroundColor $(if ($successful -eq $results.Count) { 'Green' } else { 'Yellow' })

    return $successful -gt 0
}

function Show-Configuration {
    param([object]$Config)

    Write-Host ""
    Write-Host "CURRENT ALERTING CONFIGURATION" -ForegroundColor Cyan
    Write-Host "═" * 50 -ForegroundColor Cyan
    Write-Host ""

    # Email
    Write-Host "EMAIL ALERTS" -ForegroundColor Yellow
    Write-Host "  Enabled: $($Config.alerts.email.enabled)" -ForegroundColor Gray
    if ($Config.alerts.email.enabled) {
        Write-Host "  Recipients: $($Config.alerts.email.recipients -join ', ')" -ForegroundColor Gray
        Write-Host "  SMTP Server: $($Config.alerts.email.smtpServer):$($Config.alerts.email.smtpPort)" -ForegroundColor Gray
        Write-Host "  From: $($Config.alerts.email.fromAddress)" -ForegroundColor Gray
    }

    # Webhooks
    Write-Host ""
    Write-Host "WEBHOOK ALERTS" -ForegroundColor Yellow

    foreach ($webhook in @('slack', 'teams', 'discord')) {
        $webhookConfig = $Config.alerts.webhooks.$webhook
        $status = if ($webhookConfig.enabled) { "Enabled" } else { "Disabled" }
        $statusColor = if ($webhookConfig.enabled) { 'Green' } else { 'Gray' }
        Write-Host "  $(($webhook.Substring(0, 1).ToUpper() + $webhook.Substring(1))): $status" -ForegroundColor $statusColor
    }

    # Thresholds
    Write-Host ""
    Write-Host "ALERT THRESHOLDS" -ForegroundColor Yellow
    Write-Host "  Veeam Backup Age: $($Config.thresholds.veeamBackupAgeHours) hours" -ForegroundColor Gray
    Write-Host "  Phone Backup Age: $($Config.thresholds.phoneBackupAgeHours) hours" -ForegroundColor Gray
    Write-Host "  Time Machine Age: $($Config.thresholds.timeMachineAgeHours) hours" -ForegroundColor Gray
    Write-Host "  Storage Quota Warning: $($Config.thresholds.storageQuotaPercent)%" -ForegroundColor Gray

    # Systems
    Write-Host ""
    Write-Host "MONITORED SYSTEMS" -ForegroundColor Yellow
    foreach ($system in @('veeam', 'phone', 'timeMachine')) {
        $sysConfig = $Config.backupSystems.$system
        $status = if ($sysConfig.enabled) { "Enabled" } else { "Disabled" }
        $statusColor = if ($sysConfig.enabled) { 'Green' } else { 'Gray' }
        Write-Host "  $($sysConfig.name): $status" -ForegroundColor $statusColor
    }

    Write-Host ""
}

###############################################################################
# INTERACTIVE SETUP
###############################################################################

function Show-SetupMenu {
    Write-Host ""
    Write-Host "BACKUP ALERTING CONFIGURATION" -ForegroundColor Cyan
    Write-Host "═" * 50 -ForegroundColor Cyan
    Write-Host ""

    Write-Host "1. Configure Email Alerts" -ForegroundColor White
    Write-Host "2. Configure Slack Webhook" -ForegroundColor White
    Write-Host "3. Configure Teams Webhook" -ForegroundColor White
    Write-Host "4. Configure Discord Webhook" -ForegroundColor White
    Write-Host "5. Test All Alert Channels" -ForegroundColor White
    Write-Host "6. View Current Configuration" -ForegroundColor White
    Write-Host "7. Save and Exit" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Select option (1-7)"
    return $choice
}

function Setup-EmailAlerts {
    param([object]$Config)

    Write-Host ""
    Write-Host "EMAIL ALERT SETUP" -ForegroundColor Cyan
    Write-Host "─" * 50 -ForegroundColor Cyan
    Write-Host ""

    $Config.alerts.email.enabled = $true

    # Get recipients
    $recipients = Read-Host "Email recipients (comma-separated, e.g., admin@company.com, ops@company.com)"
    $Config.alerts.email.recipients = @($recipients -split ',').Trim()

    # Get from address
    $Config.alerts.email.fromAddress = Read-Host "From email address"

    # Get SMTP server
    $smtpServer = Read-Host "SMTP Server (default: smtp.gmail.com)"
    if (-not [string]::IsNullOrEmpty($smtpServer)) {
        $Config.alerts.email.smtpServer = $smtpServer
    }

    # Get SMTP port
    $smtpPort = Read-Host "SMTP Port (default: 587)"
    if (-not [string]::IsNullOrEmpty($smtpPort)) {
        $Config.alerts.email.smtpPort = [int]$smtpPort
    }

    # Test connection
    Write-Host ""
    $testEmail = Read-Host "Test SMTP connection? (y/n)"
    if ($testEmail -eq 'y') {
        Test-SMTPConnection -Server $Config.alerts.email.smtpServer -Port $Config.alerts.email.smtpPort | Out-Null
    }

    Write-Host "Email alerts configured" -ForegroundColor Green
    return $Config
}

function Setup-WebhookAlert {
    param(
        [object]$Config,
        [string]$WebhookType,
        [string]$DisplayName
    )

    Write-Host ""
    Write-Host "$DisplayName WEBHOOK SETUP" -ForegroundColor Cyan
    Write-Host "─" * 50 -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Example webhook URLs:" -ForegroundColor Gray
    Write-Host "  Slack: https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX" -ForegroundColor Gray
    Write-Host "  Teams: https://outlook.webhook.office.com/webhookb2/..." -ForegroundColor Gray
    Write-Host "  Discord: https://discord.com/api/webhooks/123456789/abcdefg..." -ForegroundColor Gray
    Write-Host ""

    $url = Read-Host "Enter $DisplayName Webhook URL"

    if (-not [string]::IsNullOrEmpty($url)) {
        $Config.alerts.webhooks.$WebhookType.enabled = $true
        $Config.alerts.webhooks.$WebhookType.url = $url

        # Test webhook
        $testWebhook = Read-Host "Test webhook? (y/n)"
        if ($testWebhook -eq 'y') {
            Test-WebhookUrl -Url $url -Name $DisplayName | Out-Null
        }

        Write-Host "$DisplayName webhook configured" -ForegroundColor Green
    } else {
        Write-Host "Webhook URL not provided" -ForegroundColor Yellow
    }

    return $Config
}

###############################################################################
# MAIN SETUP FLOW
###############################################################################

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   BACKUP MONITORING ALERTING SETUP                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if config exists
if (Test-Path $ConfigFile) {
    Write-Host "Existing configuration found at: $ConfigFile" -ForegroundColor Yellow

    try {
        $existingConfig = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-Host "Loaded existing configuration" -ForegroundColor Green
        $config = $existingConfig
    } catch {
        Write-Host "Failed to load existing configuration, creating new one" -ForegroundColor Yellow
        $config = New-AlertingConfiguration -EmailRecipients $EmailRecipients -SMTPServer $SMTPServer `
                      -SMTPPort $SMTPPort -EmailFrom $EmailFrom -EnableSlack $EnableSlack `
                      -SlackWebhookUrl $SlackWebhookUrl -EnableTeams $EnableTeams `
                      -TeamsWebhookUrl $TeamsWebhookUrl -EnableDiscord $EnableDiscord `
                      -DiscordWebhookUrl $DiscordWebhookUrl
    }
} else {
    Write-Host "Creating new alerting configuration" -ForegroundColor Green
    $config = New-AlertingConfiguration -EmailRecipients $EmailRecipients -SMTPServer $SMTPServer `
                  -SMTPPort $SMTPPort -EmailFrom $EmailFrom -EnableSlack $EnableSlack `
                  -SlackWebhookUrl $SlackWebhookUrl -EnableTeams $EnableTeams `
                  -TeamsWebhookUrl $TeamsWebhookUrl -EnableDiscord $EnableDiscord `
                  -DiscordWebhookUrl $DiscordWebhookUrl
}

# Interactive setup loop
$setupComplete = $false

if ([string]::IsNullOrEmpty($EmailRecipients) -and -not $EnableSlack -and -not $EnableTeams -and -not $EnableDiscord) {
    # Run interactive mode
    do {
        Show-Configuration -Config $config
        $choice = Show-SetupMenu

        switch ($choice) {
            "1" { $config = Setup-EmailAlerts -Config $config }
            "2" { $config = Setup-WebhookAlert -Config $config -WebhookType "slack" -DisplayName "Slack" }
            "3" { $config = Setup-WebhookAlert -Config $config -WebhookType "teams" -DisplayName "Teams" }
            "4" { $config = Setup-WebhookAlert -Config $config -WebhookType "discord" -DisplayName "Discord" }
            "5" { Test-AlertConfiguration -Config $config | Out-Null }
            "6" { Show-Configuration -Config $config }
            "7" { $setupComplete = $true }
            default { Write-Host "Invalid option" -ForegroundColor Red }
        }
    } while (-not $setupComplete)
} else {
    # Command-line mode
    Write-Host "Configuring alerting with provided parameters..." -ForegroundColor Yellow
}

# Final configuration test and save
Write-Host ""
Write-Host "FINALIZING CONFIGURATION" -ForegroundColor Cyan
Write-Host "═" * 50 -ForegroundColor Cyan
Write-Host ""

# Test all configured channels
$channelsOK = Test-AlertConfiguration -Config $config

# Save configuration
if (Save-Configuration -Config $config) {
    Write-Host ""
    Write-Host "SETUP COMPLETE" -ForegroundColor Green
    Write-Host "═" * 50 -ForegroundColor Green
    Write-Host ""
    Write-Host "Configuration saved to: $ConfigFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Configure Task Scheduler to run HEALTH-CHECK-DAILY.ps1" -ForegroundColor White
    Write-Host "2. Run backup monitoring dashboard: .\BACKUP-MONITORING-DASHBOARD.ps1" -ForegroundColor White
    Write-Host "3. Configure metrics reporting: .\BACKUP-METRICS-REPORT.ps1" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Failed to save configuration" -ForegroundColor Red
    exit 1
}
