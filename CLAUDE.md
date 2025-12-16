# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Baby_Nas** is a production-ready, enterprise-grade backup automation suite for TrueNAS SCALE. It manages multi-system backups (Windows, Mac, mobile) across two NAS systems:

- **Baby NAS**: Hyper-V VM (172.21.203.18) running TrueNAS SCALE with 3x 6TB RAIDZ1 pool + SSD cache
- **Main NAS**: Bare metal system (10.0.0.89) as replication target

The suite is **~28,000 lines of code** across PowerShell, Python, and Bash with comprehensive monitoring, alerting, and recovery capabilities.

## Quick Start Commands

### Setup and Deployment
```powershell
# Master deployment script (interactive, recommended for first-time)
.\SETUP-BABY-NAS.ps1

# Complete automated deployment (unattended)
.\FULL-AUTOMATION.ps1

# Multi-system backup deployment (Veeam, Phone, Time Machine)
.\AUTOMATED-BACKUP-SETUP.ps1
```

### Monitoring and Health
```powershell
# Real-time monitoring dashboard (30-second refresh, continuous)
.\monitor-baby-nas.ps1

# Daily health check (pool, disks, replication, snapshots)
.\daily-health-check.ps1

# Comprehensive system diagnostics
.\CHECK-SYSTEM-STATE.ps1
```

### Testing and Verification
```powershell
# 7-part comprehensive test suite
.\test-baby-nas-complete.ps1

# Backup integrity verification
.\backup-verification.ps1

# Verify all backup systems (Veeam, Phone, Time Machine)
.\VERIFY-ALL-BACKUPS.ps1

# Recovery testing
.\test-recovery.ps1
```

### Backup Operations (Manual)
```powershell
# Windows/Veeam backup
.\3-backup-wsl.ps1 -BackupPath "X:\Backups"

# Workspace mirror sync
.\backup-workspace.ps1

# WSL backup (Ubuntu, Debian, etc.)
.\wsl-backup.ps1
```

### Python API Tools
```bash
# Main TrueNAS CLI management tool
python truenas-manager.py [command]

# API configuration and authentication setup
python truenas-api-setup.py --setup

# Real-time monitoring dashboard
python truenas-dashboard.py

# Replication lifecycle management
python truenas-replication-manager.py

# Snapshot automation and management
python truenas-snapshot-manager.py
```

### SSH and Remote Operations
```bash
# SSH key setup and deployment
.\setup-ssh-keys-complete.ps1

# Auto-detect Baby NAS IP from Hyper-V
.\find-baby-nas-ip.ps1

# Network connectivity test
.\quick-connectivity-check.ps1

# Map SMB network drives
.\network-drive-setup.ps1
```

## Codebase Architecture

### Directory Organization

```
D:\workspace\Baby_Nas\
├── PowerShell Scripts (50+)
│   ├── Setup: 1-create-baby-nas-vm.ps1, 2-configure-baby-nas.ps1, etc.
│   ├── Orchestration: FULL-AUTOMATION.ps1, SETUP-BABY-NAS.ps1
│   ├── Backup Deployment: DEPLOY-VEEAM-COMPLETE.ps1, DEPLOY-PHONE-BACKUPS-WINDOWS.ps1
│   ├── Monitoring: monitor-baby-nas.ps1, daily-health-check.ps1, BACKUP-MONITORING-DASHBOARD.ps1
│   ├── Testing: test-baby-nas-complete.ps1, backup-verification.ps1
│   └── Utilities: SSH setup, network config, diagnostics
│
├── Python Scripts (8)
│   ├── truenas-manager.py (main CLI tool)
│   ├── truenas-api-setup.py (API configuration)
│   ├── truenas-dashboard.py (monitoring)
│   ├── truenas-replication-manager.py (replication)
│   ├── truenas-snapshot-manager.py (snapshots)
│   └── API examples and utilities
│
├── Bash Scripts (3)
│   ├── truenas-initial-setup.sh (deployed to TrueNAS)
│   ├── complete-baby-nas-setup.sh
│   └── get-detailed-info.sh
│
├── Configuration Files
│   ├── .env (environment variables, API keys - SENSITIVE)
│   ├── monitoring-config.json (thresholds, webhook config)
│   ├── ALERTING-CONFIG-TEMPLATE.json (alert configuration)
│   └── .gitignore
│
├── Documentation (15+ files)
│   ├── 00-START-HERE.txt (entry point)
│   ├── QUICKSTART.md (TrueNAS setup guide)
│   ├── BACKUP-DEPLOYMENT-GUIDE.md
│   ├── BACKUP-DEPLOYMENT-SUMMARY.md
│   └── Various implementation guides and setup reports
│
├── veeam/ (12 files)
│   └── Veeam backup lifecycle management scripts
│
└── agent-logs/ (parallel execution logs)
```

### Architecture and Execution Flow

**Three-Tier Backup Architecture:**

```
Windows Workstation (System drives, Workspace, WSL)
        ↓ (Veeam + Robocopy + exports)
Baby NAS Hyper-V VM (TrueNAS SCALE, SMB shares)
        ↓ (ZFS incremental send/receive replication)
Main NAS Bare Metal (10.0.0.89, 7-day snapshots)
```

**Execution Phases:**

1. **Infrastructure Setup** → Creates Hyper-V VM, configures TrueNAS, sets up SSH keys
2. **Backup Deployment** → Configures Veeam, phone backups, Time Machine, workspace sync
3. **Replication** → Configures ZFS replication from Baby NAS to Main NAS
4. **Monitoring** → Deploys real-time dashboards, alerts, health checks, scheduled tasks
5. **Ongoing Operations** → Automated backups, monitoring, verification, recovery testing

**Key Entry Points:**
- `SETUP-BABY-NAS.ps1` - Interactive phase-based setup (user-guided)
- `FULL-AUTOMATION.ps1` - Complete unattended automation
- `AUTOMATED-BACKUP-SETUP.ps1` - Multi-system backup deployment

### Core Components

#### 1. **TrueNAS Management** (Python API Tools)
- **Primary Tool**: `truenas-manager.py` (24 KB)
- **Functions**: Pool/dataset/snapshot operations, replication, SMB shares, user management
- **Authentication**: API key or username/password
- **Configuration**: `.env` file with TrueNAS IP, credentials, API key

#### 2. **Backup Systems** (PowerShell)
- **Veeam Agent**: Windows system backup (Daily 1 AM, 7-day retention)
- **Phone Backups**: SMB shares for mobile devices (Galaxy S24, iPhone, iPad)
- **Time Machine**: macOS backup (hourly, continuous)
- **Workspace Sync**: Robocopy mirror of D:\workspace
- **WSL Backup**: Ubuntu/Debian distribution exports

#### 3. **Monitoring & Alerting** (PowerShell + Python)
- **Real-Time Dashboard**: `monitor-baby-nas.ps1` (30-sec refresh, continuous)
- **Web Dashboard**: `BACKUP-MONITORING-DASHBOARD.ps1` (port 8888)
- **Health Checks**: Daily automated checks (pool, disk SMART, replication freshness)
- **Alerts**: Email (SMTP), webhooks (Discord/Slack), SMS (Twilio), Windows notifications
- **Alert Thresholds**:
  - Pool capacity: 80% warning, 90% critical
  - Replication freshness: 26 hours max
  - Backup freshness: 28 hours max
  - Disk temperature: >50°C warning, >55°C critical

#### 4. **ZFS Replication** (PowerShell + Bash)
- **Source**: Baby NAS datasets
- **Target**: Main NAS (10.0.0.89)
- **Frequency**: Daily, configurable schedule
- **Snapshots**: Hourly, daily, weekly retention
- **Validation**: Automated replication verification

#### 5. **Testing & Validation** (PowerShell)
- **Connectivity Tests**: Ping, SSH, SMB, API access
- **Storage Tests**: Pool status, dataset creation, capacity
- **Backup Tests**: Backup freshness, snapshot count, recovery readiness
- **Replication Tests**: Status, target accessibility, sync verification
- **Performance Tests**: Network throughput, ZFS IOPS, compression ratios
- **Security Tests**: SSH key permissions, SMB auth, firewall rules

### Technology Stack

**Languages:**
- **PowerShell** (70% of code): Core automation engine, Windows integration
- **Python** (20% of code): TrueNAS REST API management, monitoring
- **Bash** (10% of code): Server-side Linux automation (deployed to TrueNAS)

**Infrastructure:**
- **Hyper-V** - Windows virtualization (TrueNAS-BabyNAS VM)
- **TrueNAS SCALE** - Open-source NAS OS with ZFS
- **ZFS** - Advanced filesystem, snapshots, replication
- **SMB/CIFS** - Network file sharing (Windows compatibility)
- **SSH** - Key-based remote administration (Ed25519 keys)
- **Veeam Agent** - Windows backup software
- **Windows Task Scheduler** - Automated job scheduling
- **Hyper-V Manager** - VM management

**External Services:**
- **Discord/Slack Webhooks** - Alert notifications
- **Gmail SMTP** - Email alerting
- **Twilio** - SMS alerting
- **TrueNAS REST API v2.0** - System management

### Important Configuration Details

**Network Setup:**
- **Baby NAS**: 172.21.203.18 (auto-detected from Hyper-V)
- **Main NAS**: 10.0.0.89 (bare metal replication target)
- **Protocol**: SMB (port 445) for file sharing, SSH (port 22) for administration
- **Shares**: Created dynamically on demand (backups, veeam, wsl-backups, media, phone)

**Backup Paths:**
- **Veeam**: `\\baby.isn.biz\Veeam` or SMB mount
- **Workspace**: `\\baby.isn.biz\WindowsBackup` or SMB mount
- **WSL**: `\\baby.isn.biz\WSLBackups` or SMB mount
- **Phone Backups**: `\\baby.isn.biz\PhoneBackups` (organized by device)
- **Time Machine**: `\\baremetal.isn.biz\TimeMachine` (macOS target)

**Storage Pool Configuration:**
```
Pool: tank (RAIDZ1, 3x 6TB = ~12TB usable)
├── SLOG Device: 256GB SSD (write acceleration)
├── L2ARC Device: 256GB SSD (read cache)
├── Compression: LZ4 (pool-wide)
├── Record Size: 1MB (optimized for backups)
└── ATime: OFF (performance optimization)

Datasets:
├── tank/backups (Windows backups)
├── tank/veeam (Veeam repository)
├── tank/wsl-backups (WSL distributions)
└── tank/media (Media files)
```

**SSH Key Authentication:**
- **Key Type**: Ed25519 (modern, secure)
- **Location**: `~/.ssh/id_ed25519` (Windows) → `/root/.ssh/authorized_keys` (TrueNAS)
- **Certificates**: Generated automatically by setup scripts
- **Passphrase**: Optional (can be passwordless for automation)

**Scheduled Tasks (Windows Task Scheduler):**
- **WSL Backup**: Weekly (Sunday 1:00 AM)
- **Health Check**: Daily (8:00 AM)
- **Workspace Sync**: Configurable (daily/weekly)
- **ZFS Replication**: Daily (2:30 AM)
- **Snapshot Management**: Hourly/daily/weekly

**Logging:**
- **Windows Logs**: `C:\Logs\` (PowerShell scripts)
- **Repository Logs**: `D:\workspace\Baby_Nas\logs\` (execution logs)
- **Agent Logs**: `D:\workspace\Baby_Nas\agent-logs\` (parallel agent output)
- **Log Format**: Text files with timestamps, HTML reports for deployments

### Common Development Tasks

**Adding a New Backup System:**
1. Create dataset on Baby NAS: `zfs create tank/new-system`
2. Configure ZFS properties (compression, recordsize)
3. Create SMB share: Web UI → Shares → Add Windows Share
4. Test SMB access from Windows
5. Deploy backup client (Veeam, rsync, etc.)
6. Add monitoring rule to `monitoring-config.json`
7. Update verification script to test new backup
8. Test complete backup/recovery cycle

**Adding a New Monitoring Alert:**
1. Define metric in `monitoring-config.json` (threshold, alert type)
2. Add webhook/email configuration if needed (SMTP, Discord, Slack, etc.)
3. Update `BACKUP-ALERTING-SETUP.ps1` to deploy alert configuration
4. Test alert trigger in safe environment
5. Verify alert delivery through all channels
6. Document alert in `MONITORING_AND_AUTOMATION_README.md`

**Modifying Replication Schedule:**
1. Edit replication configuration in Python tool or TrueNAS Web UI
2. Test replication in dry-run mode
3. Monitor first full replication cycle
4. Verify snapshot retention policy
5. Update monitoring thresholds if needed

**Troubleshooting Backup Failures:**
1. Check logs: `C:\Logs\*backup*.log` (Windows) or TrueNAS logs
2. Run health check: `.\daily-health-check.ps1`
3. Verify network connectivity: `ping <target-ip>`
4. Test credentials: SMB mount or SSH login
5. Run specific component test: `test-baby-nas-complete.ps1 -TestCategory Backup`
6. Review TrueNAS Web UI for dataset/pool issues
7. Check replication status: `truenas-manager.py replication status`

### Key Files to Know

**Entry Points (Start Here):**
- `00-START-HERE.txt` - Quick start and overview
- `QUICKSTART.md` - TrueNAS setup guide
- `SETUP-BABY-NAS.ps1` - Interactive setup wizard

**Master Scripts (Multi-Component):**
- `FULL-AUTOMATION.ps1` - Complete unattended deployment
- `AUTOMATED-BACKUP-SETUP.ps1` - Multi-system backup (Veeam, Phone, Time Machine)
- `CHECK-SYSTEM-STATE.ps1` - Comprehensive diagnostics

**Monitoring (Real-Time):**
- `monitor-baby-nas.ps1` - Live dashboard (30-sec updates)
- `BACKUP-MONITORING-DASHBOARD.ps1` - Web UI (port 8888)
- `daily-health-check.ps1` - Automated daily checks

**Testing & Verification:**
- `test-baby-nas-complete.ps1` - 7-part test suite
- `backup-verification.ps1` - Backup integrity checks
- `test-recovery.ps1` - Recovery procedure testing

**API Management (TrueNAS):**
- `truenas-manager.py` - Main CLI tool for all operations
- `truenas-api-setup.py` - API configuration and testing
- `truenas-replication-manager.py` - Replication automation

**Configuration:**
- `.env` - Environment variables (SENSITIVE: API keys, credentials)
- `monitoring-config.json` - Alert thresholds and behavior
- `ALERTING-CONFIG-TEMPLATE.json` - Alert channel configuration

## Code Style and Patterns

### PowerShell Conventions
- **Parameter Validation**: Mandatory parameters, ValidateSet for enumerations, ValidateScript for complex checks
- **Error Handling**: Try/catch blocks with detailed error messages, exit codes for automation
- **Logging**: All operations logged to `C:\Logs\` with timestamps
- **Functions**: Parameters at top, validation, main logic, return values
- **Comments**: Explain "why", not "what" (code is self-documenting for obvious operations)

### Python Conventions
- **API Calls**: Requests library with retry logic, error handling on all HTTP calls
- **Configuration**: `.env` file for credentials, `monitoring-config.json` for parameters
- **Logging**: Structured logging to files and stdout
- **Argument Parsing**: Click or argparse for CLI tools
- **Type Hints**: Used where helpful for clarity (Python 3.6+ only)

### Bash Conventions
- **Error Handling**: Exit on error with meaningful messages
- **Portability**: POSIX-compatible where possible (TrueNAS uses Linux)
- **Logging**: Structured logging to files
- **Security**: No hardcoded credentials, use SSH keys for authentication

## Testing Strategy

**Test Levels:**
1. **Unit Tests** - Individual script/function functionality
2. **Integration Tests** - Multi-component interactions (e.g., Baby NAS → Main NAS replication)
3. **System Tests** - End-to-end backup flow (backup → replicate → verify → recover)
4. **Performance Tests** - Network throughput, replication speed, IOPS
5. **Recovery Tests** - Actual file restoration from backups

**Running Tests:**
- `test-baby-nas-complete.ps1` - Comprehensive 7-part suite (covers all levels)
- `test-recovery.ps1` - Focus on recovery procedures
- `backup-verification.ps1` - Verify backup completeness

**Testing Best Practices:**
- Always test on Baby NAS first (non-critical replica)
- Never test destructive operations on Main NAS without explicit approval
- Generate HTML reports for all test runs
- Log all test results for audit trail
- Test recovery procedures quarterly

## Maintenance and Monitoring

**Health Check Frequency:**
- **Real-Time**: `monitor-baby-nas.ps1` (dashboard, user-initiated)
- **Daily**: Automated 8 AM health check via Task Scheduler
- **Weekly**: Full backup verification and recovery testing
- **Monthly**: Disk SMART tests (short and long)

**Backup Verification:**
- **Automatic**: Nightly freshness check (backup age < 28 hours)
- **Weekly**: VERIFY-ALL-BACKUPS.ps1 (full integrity check)
- **Monthly**: Restore sample file from each backup system
- **Quarterly**: Full disaster recovery drill

**Capacity Management:**
- **Monitoring**: Pool usage tracked continuously (alert at 80%, critical at 90%)
- **Expansion Strategy**: Add 3x 6TB drives to RAIDZ1 when reaching 80%
- **Cleanup**: Old snapshots pruned per retention policy (7-day default)

## Debugging and Logging

**Log Locations:**
- **Windows**: `C:\Logs\` (all PowerShell scripts)
- **Repository**: `D:\workspace\Baby_Nas\logs\` (main scripts)
- **Agent**: `D:\workspace\Baby_Nas\agent-logs\` (parallel execution)
- **TrueNAS**: SSH into system → `/var/log/` (system logs)
- **TrueNAS Web**: Dashboard → System → Logs → Services

**Log Files to Check:**
1. PowerShell execution logs in `C:\Logs\`
2. TrueNAS syslog (via Web UI or SSH)
3. Veeam backup logs (Veeam console or SMB share)
4. Python script output (stdout in command window)
5. HTML reports generated after deployments

**Debugging Approach:**
1. Check logs for error messages and timestamps
2. Identify which component failed (TrueNAS, Baby NAS, Windows, network)
3. Test connectivity at failure point
4. Run component-specific health check
5. Verify configuration (credentials, network, permissions)
6. Review TrueNAS Web UI for storage/replication status
7. Run `CHECK-SYSTEM-STATE.ps1` for comprehensive diagnostics

## Security Considerations

**SSH Authentication:**
- Ed25519 keys (modern, secure) required
- No password-based SSH (keys only)
- Keys stored in `~/.ssh/` with proper permissions (600)
- Generated automatically by setup scripts

**SMB/CIFS Security:**
- SMB1 disabled (security risk)
- SMB 2.1+ required (encryption support)
- User authentication required for all shares
- Credentials stored in `.env` (SENSITIVE, never commit)

**API Security:**
- API key generated via TrueNAS Web UI (one-time display)
- Keys stored in `.env` (SENSITIVE, never commit)
- HTTPS only for API calls (SSL/TLS verification)
- API rate limiting respected (TrueNAS default 100 req/min)

**Data Protection:**
- LZ4 compression enabled (reduces storage, improves performance)
- ZFS checksums protect against silent corruption
- 7-day snapshot retention on Main NAS (recovery window)
- Incremental replication (only deltas sent)
- No sensitive data in logs (credentials redacted)

**Credential Management:**
- All credentials in `.env` file (git-ignored)
- No hardcoded credentials in scripts
- `.env` file not included in version control
- Credentials rotated quarterly
- API keys rotated after any compromise

## Version Control

**Git Configuration:**
- Repository: `D:\workspace\Baby_Nas\` (git initialized)
- Main branch: `master`
- `.gitignore`: Excludes logs, `.env`, sensitive files
- Commits: Include script updates, documentation changes

**What NOT to Commit:**
- `.env` file (credentials)
- `C:\Logs\` directory (runtime logs)
- `agent-logs/` directory (execution output)
- `vm-status-output.txt`, `vm-ip-output.txt` (cached data)
- Any file with credentials, API keys, or sensitive data

**What TO Commit:**
- PowerShell scripts (.ps1)
- Python scripts (.py)
- Bash scripts (.sh)
- Documentation (.md, .txt)
- Configuration templates (ALERTING-CONFIG-TEMPLATE.json)

## Related Documentation

**Quick References:**
- `00-START-HERE.txt` - Quick start overview
- `QUICK_REFERENCE.md` - Command reference
- `QUICKSTART.md` - TrueNAS setup guide

**Comprehensive Guides:**
- `BACKUP-DEPLOYMENT-GUIDE.md` - Complete deployment walkthrough
- `BACKUP-DEPLOYMENT-SUMMARY.md` - Executive overview
- `MONITORING_AND_AUTOMATION_README.md` - Monitoring setup

**Implementation Details:**
- `BACKUP_IMPLEMENTATION_SUMMARY.md` - Technical overview
- `BACKUP_QUICKSTART.md` - Backup system quick start
- `FULL-AUTOMATION-README.md` - Full automation guide

**Troubleshooting:**
- See "Troubleshooting" section in `BACKUP-DEPLOYMENT-GUIDE.md`
- Run `CHECK-SYSTEM-STATE.ps1` for diagnostics
- Check logs in `C:\Logs\` and `D:\workspace\Baby_Nas\logs\`
