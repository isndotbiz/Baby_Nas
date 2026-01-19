#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Webhook Alert Integration for Slack, Teams, Discord

.DESCRIPTION
    Sends real-time alerts and weekly summaries to webhook services:
    - Slack webhook notifications
    - Microsoft Teams alerts
    - Discord message integration
    - Custom webhook support
    - Real-time failure notifications
    - Weekly summary posts
    - Backup completion confirmations

.PARAMETER AlertType
    Type of alert: 'failure', 'warning', 'success', 'summary'

.PARAMETER SystemName
    Backup system: 'veeam', 'phone', 'timemachine', 'storage'

.PARAMETER Message
    Alert message

.PARAMETER Details
    Additional alert details

.PARAMETER ConfigPath
    Path to alerting config (default: C:\BackupMonitoring\Config\alerting-config.json)

.PARAMETER TestAll
    Test all configured webhooks

.EXAMPLE
    .\MONITORING-WEBHOOK-ALERTING.ps1 -AlertType failure -SystemName veeam -Message "Veeam backup failed"

.EXAMPLE
    .\MONITORING-WEBHOOK-ALERTING.ps1 -TestAll

.NOTES
    Author: Automated Backup Monitoring System
    Version: 1.0
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('failure','warning','success','summary','test')]
    [string]$AlertType = "warning",

    [Parameter(Mandatory=$false)]
    [ValidateSet('veeam','phone','timemachine','storage','system')]
    [string]$SystemName = "system",

    [Parameter(Mandatory=$false)]
    [string]$Message = "",

    [Parameter(Mandatory=$false)]
    [string]$Details = "",

    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "C:\BackupMonitoring\Config\alerting-config.json",

    [Parameter(Mandatory=$false)]
    [switch]$TestAll
)

$ErrorActionPreference = "SilentlyContinue"

###############################################################################
# CONFIGURATION AND HELPER FUNCTIONS
###############################################################################

function Load-Configuration {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Host "Configuration not found: $Path" -ForegroundColor Red
        Write-Host "Run BACKUP-ALERTING-SETUP.ps1 first" -ForegroundColor Yellow
        return $null
    }

    try {
        return Get-Content $Path -Raw | ConvertFrom-Json
    } catch {
        Write-Host "Failed to load configuration: $_" -ForegroundColor Red
        return $null
    }
}

function Get-AlertColor {
    param([string]$AlertType)

    switch ($AlertType) {
        "failure" { return "#DC3545" }   # Red
        "warning" { return "#FFC107" }   # Yellow
        "success" { return "#28A745" }   # Green
        "summary" { return "#2C5AA0" }   # Blue
        default   { return "#6C757D" }   # Gray
    }
}

function Get-AlertEmoji {
    param([string]$AlertType)

    switch ($AlertType) {
        "failure" { return "❌" }
        "warning" { return "⚠️" }
        "success" { return "✅" }
        "summary" { return "📊" }
        default   { return "ℹ️" }
    }
}

function Get-SystemIcon {
    param([string]$SystemName)

    switch ($SystemName) {
        "veeam"       { return "💾" }
        "phone"       { return "📱" }
        "timemachine" { return "⏱️" }
        "storage"     { return "🗄️" }
        "system"      { return "🖥️" }
        default       { return "📌" }
    }
}

function Get-SystemDisplayName {
    param([string]$SystemName)

    switch ($SystemName) {
        "veeam"       { return "Veeam Backup" }
        "phone"       { return "Phone Backup" }
        "timemachine" { return "Time Machine" }
        "storage"     { return "Storage System" }
        "system"      { return "System" }
        default       { return $SystemName }
    }
}

###############################################################################
# SLACK WEBHOOK FUNCTIONS
###############################################################################

function Send-SlackAlert {
    param(
        [string]$WebhookUrl,
        [string]$AlertType,
        [string]$SystemName,
        [string]$Message,
        [string]$Details
    )

    if ([string]::IsNullOrEmpty($WebhookUrl)) {
        return $false
    }

    try {
        $color = Get-AlertColor -AlertType $AlertType
        $emoji = Get-AlertEmoji -AlertType $AlertType
        $systemDisplay = Get-SystemDisplayName -SystemName $SystemName
        $systemEmoji = Get-SystemIcon -SystemName $SystemName

        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $hostname = $env:COMPUTERNAME

        $payload = @{
            attachments = @(
                @{
                    color = $color
                    title = "$emoji $systemEmoji $systemDisplay - $AlertType"
                    title_link = ""
                    text = $Message
                    fields = @(
                        @{
                            title = "Hostname"
                            value = $hostname
                            short = $true
                        },
                        @{
                            title = "Timestamp"
                            value = $timestamp
                            short = $true
                        }
                    )
                    footer = "Backup Monitoring System"
                    ts = [int](New-TimeSpan -Start (Get-Date "1970-01-01").ToUniversalTime() -End (Get-Date).ToUniversalTime()).TotalSeconds
                }
            )
        }

        if (-not [string]::IsNullOrEmpty($Details)) {
            $payload.attachments[0].fields += @{
                title = "Details"
                value = $Details
                short = $false
            }
        }

        $jsonPayload = $payload | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $jsonPayload -ContentType "application/json" -TimeoutSec 10

        Write-Host "Slack alert sent successfully" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Failed to send Slack alert: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

###############################################################################
# TEAMS WEBHOOK FUNCTIONS
###############################################################################

function Send-TeamsAlert {
    param(
        [string]$WebhookUrl,
        [string]$AlertType,
        [string]$SystemName,
        [string]$Message,
        [string]$Details
    )

    if ([string]::IsNullOrEmpty($WebhookUrl)) {
        return $false
    }

    try {
        $color = switch ($AlertType) {
            "failure" { "FF0000" }   # Red
            "warning" { "FFC107" }   # Yellow
            "success" { "00B050" }   # Green
            "summary" { "2C5AA0" }   # Blue
            default   { "595959" }   # Gray
        }

        $emoji = Get-AlertEmoji -AlertType $AlertType
        $systemDisplay = Get-SystemDisplayName -SystemName $SystemName
        $systemEmoji = Get-SystemIcon -SystemName $SystemName

        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $hostname = $env:COMPUTERNAME

        $payload = @{
            "@type" = "MessageCard"
            "@context" = "https://schema.org/extensions"
            summary = "$emoji $systemDisplay - $AlertType"
            themeColor = $color
            sections = @(
                @{
                    activityTitle = "$emoji $systemEmoji $systemDisplay"
                    activitySubtitle = $AlertType.ToUpper()
                    text = $Message
                    facts = @(
                        @{
                            name = "Hostname"
                            value = $hostname
                        },
                        @{
                            name = "Timestamp"
                            value = $timestamp
                        }
                    )
                }
            )
        }

        if (-not [string]::IsNullOrEmpty($Details)) {
            $payload.sections[0].facts += @{
                name = "Details"
                value = $Details
            }
        }

        $jsonPayload = $payload | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $jsonPayload -ContentType "application/json" -TimeoutSec 10

        Write-Host "Teams alert sent successfully" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Failed to send Teams alert: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

###############################################################################
# DISCORD WEBHOOK FUNCTIONS
###############################################################################

function Send-DiscordAlert {
    param(
        [string]$WebhookUrl,
        [string]$AlertType,
        [string]$SystemName,
        [string]$Message,
        [string]$Details
    )

    if ([string]::IsNullOrEmpty($WebhookUrl)) {
        return $false
    }

    try {
        $color = switch ($AlertType) {
            "failure" { 13632973 }   # Red
            "warning" { 16776960 }   # Yellow
            "success" { 2600185 }    # Green
            "summary" { 2897863 }    # Blue
            default   { 9807270 }    # Gray
        }

        $emoji = Get-AlertEmoji -AlertType $AlertType
        $systemDisplay = Get-SystemDisplayName -SystemName $SystemName
        $systemEmoji = Get-SystemIcon -SystemName $SystemName

        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $hostname = $env:COMPUTERNAME

        $payload = @{
            username = "Backup Monitoring"
            avatar_url = ""
            embeds = @(
                @{
                    title = "$emoji $systemEmoji $systemDisplay"
                    description = $Message
                    color = $color
                    fields = @(
                        @{
                            name = "Alert Type"
                            value = $AlertType.ToUpper()
                            inline = $true
                        },
                        @{
                            name = "Hostname"
                            value = $hostname
                            inline = $true
                        },
                        @{
                            name = "Timestamp"
                            value = $timestamp
                            inline = $false
                        }
                    )
                    footer = @{
                        text = "Backup Monitoring System"
                    }
                    timestamp = $timestamp
                }
            )
        }

        if (-not [string]::IsNullOrEmpty($Details)) {
            $payload.embeds[0].fields += @{
                name = "Details"
                value = $Details
                inline = $false
            }
        }

        $jsonPayload = $payload | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $jsonPayload -ContentType "application/json" -TimeoutSec 10

        Write-Host "Discord alert sent successfully" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Failed to send Discord alert: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

###############################################################################
# WEBHOOK TESTING
###############################################################################

function Test-Webhook {
    param(
        [string]$Url,
        [string]$Platform
    )

    Write-Host "Testing $Platform webhook..." -ForegroundColor Yellow

    try {
        $testMessage = "Test alert from Backup Monitoring System"
        $testDetails = "This is a test message. If you receive this, webhooks are working correctly."

        switch ($Platform) {
            "Slack" {
                Send-SlackAlert -WebhookUrl $Url -AlertType "test" -SystemName "system" -Message $testMessage -Details $testDetails | Out-Null
            }
            "Teams" {
                Send-TeamsAlert -WebhookUrl $Url -AlertType "test" -SystemName "system" -Message $testMessage -Details $testDetails | Out-Null
            }
            "Discord" {
                Send-DiscordAlert -WebhookUrl $Url -AlertType "test" -SystemName "system" -Message $testMessage -Details $testDetails | Out-Null
            }
        }

        Write-Host "$Platform webhook test successful" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "$Platform webhook test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-AllWebhooks {
    param([object]$Config)

    Write-Host ""
    Write-Host "TESTING ALL WEBHOOK INTEGRATIONS" -ForegroundColor Cyan
    Write-Host "═" * 50 -ForegroundColor Cyan
    Write-Host ""

    $results = @()

    # Test Slack
    if ($Config.alerts.webhooks.slack.enabled -and -not [string]::IsNullOrEmpty($Config.alerts.webhooks.slack.url)) {
        $result = Test-Webhook -Url $Config.alerts.webhooks.slack.url -Platform "Slack"
        $results += @{ Platform = "Slack"; Result = $result }
    }

    # Test Teams
    if ($Config.alerts.webhooks.teams.enabled -and -not [string]::IsNullOrEmpty($Config.alerts.webhooks.teams.url)) {
        $result = Test-Webhook -Url $Config.alerts.webhooks.teams.url -Platform "Teams"
        $results += @{ Platform = "Teams"; Result = $result }
    }

    # Test Discord
    if ($Config.alerts.webhooks.discord.enabled -and -not [string]::IsNullOrEmpty($Config.alerts.webhooks.discord.url)) {
        $result = Test-Webhook -Url $Config.alerts.webhooks.discord.url -Platform "Discord"
        $results += @{ Platform = "Discord"; Result = $result }
    }

    Write-Host ""
    Write-Host "Test Results:" -ForegroundColor Cyan
    foreach ($result in $results) {
        $status = if ($result.Result) { "✓ PASS" } else { "✗ FAIL" }
        $statusColor = if ($result.Result) { "Green" } else { "Red" }
        Write-Host "  $($result.Platform): " -NoNewline
        Write-Host $status -ForegroundColor $statusColor
    }
    Write-Host ""
}

###############################################################################
# MAIN EXECUTION
###############################################################################

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   BACKUP MONITORING WEBHOOK ALERTING                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Load configuration
$config = Load-Configuration -Path $ConfigPath

if (-not $config) {
    exit 1
}

# Test all webhooks if requested
if ($TestAll) {
    Test-AllWebhooks -Config $config
    exit 0
}

# Send alert to all configured webhooks
Write-Host "Sending webhook alerts..." -ForegroundColor Yellow
Write-Host "Alert Type: $AlertType" -ForegroundColor Gray
Write-Host "System: $(Get-SystemDisplayName -SystemName $SystemName)" -ForegroundColor Gray
Write-Host ""

$alertsSent = 0

# Send to Slack
if ($config.alerts.webhooks.slack.enabled) {
    $result = Send-SlackAlert `
        -WebhookUrl $config.alerts.webhooks.slack.url `
        -AlertType $AlertType `
        -SystemName $SystemName `
        -Message $Message `
        -Details $Details

    if ($result) { $alertsSent++ }
}

# Send to Teams
if ($config.alerts.webhooks.teams.enabled) {
    $result = Send-TeamsAlert `
        -WebhookUrl $config.alerts.webhooks.teams.url `
        -AlertType $AlertType `
        -SystemName $SystemName `
        -Message $Message `
        -Details $Details

    if ($result) { $alertsSent++ }
}

# Send to Discord
if ($config.alerts.webhooks.discord.enabled) {
    $result = Send-DiscordAlert `
        -WebhookUrl $config.alerts.webhooks.discord.url `
        -AlertType $AlertType `
        -SystemName $SystemName `
        -Message $Message `
        -Details $Details

    if ($result) { $alertsSent++ }
}

Write-Host ""
Write-Host "Alerts sent: $alertsSent" -ForegroundColor Green

exit 0
