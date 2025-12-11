# Windows Backup Scripts

Automated PowerShell scripts for Windows workstation backup to TrueNAS.

## Scripts Overview

| Script | Purpose | Run Frequency | Requires Admin |
|--------|---------|---------------|----------------|
| `1-identify-drives.ps1` | Identify available 6TB drives | Once (setup) | Yes |
| `2-initialize-single-drive.ps1` | Initialize backup drive | Once (setup) | Yes |
| `3-backup-wsl.ps1` | Backup WSL distributions | Weekly (automated) | Yes |
| `4-monitor-backups.ps1` | Health check and monitoring | Daily (automated) | No |
| `5-schedule-tasks.ps1` | Setup automated tasks | Once (setup) | Yes |

## Quick Start

### Setup (Run Once)

```powershell
# Run as Administrator

# Step 1: Identify your 6TB drives
.\1-identify-drives.ps1

# Step 2: Initialize one drive (replace X with disk number)
.\2-initialize-single-drive.ps1 -DiskNumber X

# Step 3: Setup automated tasks
.\5-schedule-tasks.ps1
```

### Manual Operations

```powershell
# Manual WSL backup
.\3-backup-wsl.ps1 -BackupPath "X:\WSLBackups"

# Manual health check
.\4-monitor-backups.ps1
```

## Automated Schedule

Once configured, these tasks run automatically:

- **WSL Backup**: Sundays at 1:00 AM
- **Health Check**: Daily at 8:00 AM

## Requirements

- Windows 10/11 or Windows Server
- PowerShell 5.1 or later
- Administrator privileges for setup
- At least one 6TB drive available
- Network connectivity to TrueNAS (10.0.0.89)

## Configuration

### Backup Paths

Default paths (can be customized):
- **Veeam backups**: `X:\VeeamBackups`
- **WSL backups**: `X:\WSLBackups`
- **Manual backups**: `X:\ManualBackups`
- **Logs**: `C:\Logs\`

### TrueNAS Connection

Default settings:
- **IP**: 10.0.0.89
- **Share**: `\\10.0.0.89\WindowsBackup`
- **SSH Key**: `~/.ssh/truenas_admin_10_0_0_89`

## Troubleshooting

### Execution Policy Error

```powershell
# Allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Permission Errors

```powershell
# Run PowerShell as Administrator
# Right-click PowerShell → "Run as Administrator"
```

### Network Errors

```powershell
# Test TrueNAS connectivity
Test-Connection -ComputerName 10.0.0.89

# Test SMB share
Test-Path \\10.0.0.89\WindowsBackup
```

## Logs

All scripts write logs to:
```
C:\Logs\
  ├── wsl-backup-YYYYMMDD-HHMMSS.log
  ├── backup-health-YYYYMMDD-HHMMSS.log
  └── truenas-replication-YYYYMMDD.log
```

## Support

For detailed documentation, see:
- `../WINDOWS_BACKUP_IMPLEMENTATION.md` - Full implementation guide
- `../BACKUP_IMPLEMENTATION_QUICKSTART.md` - Quick start guide
- `../BACKUP_STRATEGY.md` - Backup strategy details

## Version

**Version**: 1.0
**Last Updated**: 2025-12-09
**Status**: Production Ready
