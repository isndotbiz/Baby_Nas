###############################################################################
# Webhook Alert Sender for n8n Integration
# Purpose: Send monitoring alerts to n8n webhook for SMS/Email
# Usage: .\send-webhook-alert.ps1 -Severity <level> -Message <text> [-Details <text>]
###############################################################################

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('info','warning','critical')]
    [string]$Severity,

    [Parameter(Mandatory=$true)]
    [string]$Message,

    [Parameter(Mandatory=$false)]
    [string]$Details = "",

    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "$PSScriptRoot\monitoring-config.json"
)

$ErrorActionPreference = "Stop"

###############################################################################
# LOAD CONFIGURATION
###############################################################################

if (-not (Test-Path $ConfigPath)) {
    Write-Host "Config file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "Failed to parse config: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

###############################################################################
# BUILD PAYLOAD
###############################################################################

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$hostname = $env:COMPUTERNAME

$payload = @{
    timestamp = $timestamp
    hostname = $hostname
    severity = $Severity
    message = $Message
    details = $Details
    source = "Baby NAS Windows Monitor"
}

# Add Baby NAS IP if available
try {
    $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1
    if ($vm) {
        $vmNet = Get-VMNetworkAdapter -VM $vm
        if ($vmNet.IPAddresses) {
            $babyNasIP = ($vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
            if ($babyNasIP) {
                $payload.babyNasIP = $babyNasIP
            }
        }
    }
} catch {}

$jsonPayload = $payload | ConvertTo-Json -Depth 10

###############################################################################
# SEND WEBHOOK
###############################################################################

Write-Host "Sending webhook alert..." -ForegroundColor Cyan
Write-Host "Severity: $Severity" -ForegroundColor $(if ($Severity -eq 'critical') { 'Red' } elseif ($Severity -eq 'warning') { 'Yellow' } else { 'Cyan' })
Write-Host "Message: $Message" -ForegroundColor Gray

# Send to configured webhook
if ($config.alerts.webhook.enabled -and $config.alerts.webhook.url) {
    try {
        $webhookUrl = $config.alerts.webhook.url
        $headers = @{}

        # Add configured headers
        if ($config.alerts.webhook.headers) {
            $config.alerts.webhook.headers.PSObject.Properties | ForEach-Object {
                $headers[$_.Name] = $_.Value
            }
        }

        $response = Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $jsonPayload -Headers $headers -ContentType "application/json"

        Write-Host "Webhook sent successfully" -ForegroundColor Green
        if ($response) {
            Write-Host "Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Failed to send webhook: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "URL: $webhookUrl" -ForegroundColor Gray
        exit 1
    }
} else {
    Write-Host "Webhook not configured or disabled in config" -ForegroundColor Yellow
    Write-Host "Configure webhook in: $ConfigPath" -ForegroundColor Gray
    Write-Host "Set: alerts.webhook.enabled = true" -ForegroundColor Gray
    Write-Host "Set: alerts.webhook.url = <your-n8n-webhook-url>" -ForegroundColor Gray
    exit 0
}

# Send to n8n for SMS (if configured)
if ($config.alerts.sms.enabled -and $Severity -eq 'critical') {
    Write-Host "" -ForegroundColor Gray
    Write-Host "SMS notifications enabled for critical alerts" -ForegroundColor Cyan

    # Build SMS payload for Twilio via n8n
    $smsPayload = @{
        provider = $config.alerts.sms.provider
        severity = $Severity
        message = "$hostname - $Message"
        to = $config.alerts.sms.toNumbers
    } | ConvertTo-Json

    # You would send this to a separate n8n webhook configured for SMS
    Write-Host "SMS payload prepared (configure n8n workflow for delivery)" -ForegroundColor Gray
}

# Send email notification (if configured)
if ($config.alerts.email.enabled) {
    $sendEmail = $false

    if ($Severity -eq 'critical') {
        $sendEmail = $true
    } elseif ($Severity -eq 'warning' -and -not $config.alerts.email.criticalOnly) {
        $sendEmail = $true
    }

    if ($sendEmail) {
        Write-Host "" -ForegroundColor Gray
        Write-Host "Email notifications enabled" -ForegroundColor Cyan

        # Build email payload for n8n
        $emailPayload = @{
            to = $config.alerts.email.to
            from = $config.alerts.email.from
            subject = "[$Severity] Baby NAS Alert: $Message"
            body = @"
Baby NAS Monitoring Alert

Severity: $Severity
Time: $timestamp
Host: $hostname

Message:
$Message

Details:
$Details

--
This is an automated alert from Baby NAS Monitoring System
"@
        } | ConvertTo-Json

        Write-Host "Email payload prepared (configure n8n workflow for delivery)" -ForegroundColor Gray
    }
}

Write-Host "" -ForegroundColor Gray
Write-Host "Alert processing complete" -ForegroundColor Green
