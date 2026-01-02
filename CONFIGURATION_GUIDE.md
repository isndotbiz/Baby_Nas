# Baby_Nas Configuration Guide

## Overview

This guide explains the environment configuration files and how to set them up for your Baby_Nas backup automation system.

## Configuration Files

### .env (Primary Configuration)
**Location:** `D:\workspace\Baby_Nas\.env`

The main configuration file containing all necessary credentials and settings for production use.

**Key Settings:**
- `TRUENAS_IP=172.21.203.18` - Baby NAS Hyper-V VM IP address
- `TRUENAS_USERNAME=root` - TrueNAS login user
- `TRUENAS_PASSWORD=*****` - TrueNAS root password (already configured)
- `MAIN_NAS_IP=10.0.0.89` - Main NAS bare metal replication target
- `TRUENAS_API_KEY=` - **REQUIRED** - Must be generated from TrueNAS Web UI
- SMTP, Discord, Slack credentials for alerting (optional)

**Status:** ✅ Configured (IP corrected to 172.21.203.18)

### .env.local (Machine-Specific Secrets)
**Location:** `D:\workspace\Baby_Nas\.env.local`

Contains machine-specific and local-only configuration. This file overrides `.env` values for your local system.

**Key Settings:**
- `TRUENAS_RAG_HOST=10.0.0.89` - RAG system sync target
- `TRUENAS_RAG_USER=baby-nas` - RAG system user
- `TRUENAS_RAG_SSH_KEY=D:\workspace\Baby_Nas\keys\baby-nas_rag-system` - SSH key path
- Local backup staging paths and cache directories

**Status:** ✅ Created and formatted

### .env.staging (Staging/Testing Environment)
**Location:** `D:\workspace\Baby_Nas\.env.staging`

Use this for non-production testing and staging environments.

**Key Differences from Production:**
- Shorter backup retention (3 days vs 7 days)
- Shorter snapshot retention for testing
- Test email addresses for alerts
- Optional flags: DRY_RUN, SKIP_REPLICATION, DEBUG logging

**Status:** ✅ Created

### .env.production (Production Environment)
**Location:** `D:\workspace\Baby_Nas\.env.production`

Explicit production configuration with conservative settings.

**Features:**
- Full retention policies
- Production alert recipients
- Optimized thresholds
- Comprehensive RAG system configuration

**Status:** ✅ Created

### .env.example (Template Reference)
**Location:** `D:\workspace\Baby_Nas\.env.example`

Template file showing all available configuration options. Use this as a reference when adding new settings.

**Status:** ✅ Available (reference only, do not edit)

## Configuration Setup Checklist

### 1. TrueNAS API Key (CRITICAL)
You must generate an API key from TrueNAS Web UI:

```
Steps:
1. Open TrueNAS Web UI: https://172.21.203.18
2. Login with root credentials from .env
3. Go to System → API Keys
4. Click "Add"
5. Copy the generated API key
6. Paste it in .env: TRUENAS_API_KEY=<your-api-key>
```

### 2. SSH Key Authentication
The system uses SSH keys for secure authentication:

```
Files:
- D:\workspace\Baby_Nas\keys\baby-nas_rag-system (Private key)
- D:\workspace\Baby_Nas\keys\baby-nas_rag-system.pub (Public key)

Usage:
- RAG system sync uses the SSH key at TRUENAS_RAG_SSH_KEY
- PowerShell scripts use auto-detected SSH keys from %USERPROFILE%\.ssh\
```

### 3. Alerting Configuration (Optional)

**Email Alerts:**
```
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password (not regular password)
EMAIL_FROM=your-email@gmail.com
EMAIL_TO=admin@example.com
```

**Discord Webhook:**
```
DISCORD_WEBHOOK=https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN
```

**Slack Webhook:**
```
SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR_SERVICE
```

## Monitoring Configuration

### monitoring-config.json
**Location:** `D:\workspace\Baby_Nas\monitoring-config.json`

Centralized monitoring settings including thresholds, alerts, and dashboard configuration.

**Key Settings:**
```json
{
  "babyNAS": {
    "ip": "172.21.203.18",
    "sshUser": "root",
    "autoDetectIP": false
  },
  "mainNAS": {
    "ip": "10.0.0.89",
    "sshUser": "root"
  },
  "thresholds": {
    "pool": {
      "capacityWarning": 80,
      "capacityCritical": 90
    },
    "backup": {
      "maxAgeHours": 28
    },
    "replication": {
      "maxAgeHours": 26
    }
  },
  "alerts": {
    "email": { "enabled": false },
    "webhook": { "enabled": false },
    "windowsNotifications": { "enabled": true }
  }
}
```

**Status:** ✅ Updated with correct IP (172.21.203.18)

### ALERTING-CONFIG-TEMPLATE.json
**Location:** `D:\workspace\Baby_Nas\ALERTING-CONFIG-TEMPLATE.json`

Template for detailed alert configuration with message templates and scheduled alerts.

**Status:** ✅ Available for reference

## How to Use These Files

### For Development/Testing:
```powershell
# Load staging configuration
$env:ENV_FILE = ".env.staging"
.\test-baby-nas-complete.ps1
```

### For Production:
```powershell
# Default uses .env
.\FULL-AUTOMATION.ps1
```

### For Local Machine Overrides:
```powershell
# Automatically loads .env.local if it exists
# This allows machine-specific settings without modifying .env
```

## Security Best Practices

1. **Never commit .env files to git**
   - All `.env*` files are in `.gitignore`
   - Verify before committing: `git status`

2. **Protect SSH Keys**
   - Keys in `D:\workspace\Baby_Nas\keys\` should have restricted permissions
   - Never share private keys (`.key` files)

3. **Rotate Credentials Quarterly**
   - TrueNAS password: Change in TrueNAS Web UI
   - API keys: Regenerate in System → API Keys
   - SMTP/Webhook tokens: Update in respective services

4. **Use App-Specific Passwords**
   - Gmail SMTP: Use 16-character app password, not account password
   - Slack/Discord: Use dedicated webhook tokens with minimal scopes

## Troubleshooting

### API Key Issues
**Problem:** Scripts fail with "Unauthorized" errors
**Solution:**
1. Verify API key is set in .env: `$env:TRUENAS_API_KEY`
2. Regenerate key from TrueNAS Web UI if older than 30 days
3. Check IP address: Should be `172.21.203.18`

### SSH Connection Issues
**Problem:** Cannot connect to TrueNAS via SSH
**Solution:**
1. Verify SSH keys exist: `ls D:\workspace\Baby_Nas\keys\`
2. Check permissions: Private key should not be publicly readable
3. Test manually: `ssh -i "key-path" root@172.21.203.18 "echo 'Success'"`

### Credential Format Issues
**Problem:** Scripts fail to parse credentials
**Solution:**
1. Ensure no spaces around `=` in .env files
2. Use double quotes for values with special characters
3. Avoid using `#` or `;` in passwords (shell comment characters)

## Next Steps

1. **Generate TrueNAS API Key** (see Checklist #1 above)
2. **Configure Alerting** (SMTP, Discord, Slack - optional)
3. **Test Connectivity**: Run `.\quick-connectivity-check.ps1`
4. **Verify Configuration**: Run `.\CHECK-SYSTEM-STATE.ps1`
5. **Deploy Automation**: Run `.\FULL-AUTOMATION.ps1`

## Related Files

- `CLAUDE.md` - Development and architecture guide
- `00-START-HERE.txt` - Quick start overview
- `QUICKSTART.md` - TrueNAS setup guide
- `BACKUP-DEPLOYMENT-GUIDE.md` - Complete deployment walkthrough

## Questions?

If you encounter issues:
1. Check `C:\Logs\` for PowerShell script logs
2. Review `.env.example` for configuration options
3. Run `.\CHECK-SYSTEM-STATE.ps1` for system diagnostics
4. Check TrueNAS Web UI logs: System → Logs → Services
