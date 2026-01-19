# TrueNAS API Tools - Complete Index

## Getting Started

### Installation & Setup
1. **Install dependencies**: `pip install -r requirements.txt`
2. **Configure API access**: `python truenas-api-setup.py --setup`
3. **Test installation**: `python test-truenas-tools.py`

### Quick Start
- **Dashboard**: `python truenas-dashboard.py`
- **System health**: `python truenas-manager.py health system`
- **View pools**: `python truenas-manager.py pool list`

## Tool Files

### Core Management Tools

| File | Purpose | Lines | Key Features |
|------|---------|-------|--------------|
| `truenas-manager.py` | Comprehensive management CLI | ~700 | Pools, datasets, snapshots, replication, SMB, users, health |
| `truenas-dashboard.py` | Real-time monitoring TUI | ~400 | Live dashboard with auto-refresh, color-coded alerts |
| `truenas-snapshot-manager.py` | Advanced snapshot operations | ~600 | Filtering, bulk ops, retention policies, comparison |
| `truenas-replication-manager.py` | Replication control | ~650 | Monitoring, retry, bandwidth control, statistics |
| `truenas-api-examples.py` | Code examples & best practices | ~750 | 12 interactive examples with documentation |

### Setup & Configuration

| File | Purpose |
|------|---------|
| `truenas-api-setup.py` | Initial API configuration (existing) |
| `test-truenas-tools.py` | Installation validation & testing |
| `requirements.txt` | Python package dependencies |

### Documentation

| File | Purpose |
|------|---------|
| `TRUENAS_API_TOOLS_README.md` | Comprehensive documentation (main) |
| `QUICK_REFERENCE.md` | Quick command reference |
| `TRUENAS_TOOLS_INDEX.md` | This file - complete index |

## Command Reference

### truenas-manager.py

#### Pool Commands
```
pool list                           # List all pools
pool status <name>                  # Pool details
pool check-capacity [--threshold N] # Capacity alerts
```

#### Dataset Commands
```
dataset list [--pool NAME]                      # List datasets
dataset create <path> [--compression TYPE]      # Create dataset
dataset delete <id> [--recursive]               # Delete dataset
```

#### Snapshot Commands
```
snapshot list [--dataset NAME]               # List snapshots
snapshot create <dataset> [--name NAME]      # Create snapshot
snapshot delete <id>                         # Delete snapshot
snapshot rollback <id>                       # Rollback to snapshot
```

#### Replication Commands
```
replication list    # List replication tasks
replication run <id> # Run task manually
```

#### SMB Commands
```
smb list                              # List shares
smb create <path> <name>              # Create share
smb delete <id>                       # Delete share
```

#### User Commands
```
user list    # List all users
```

#### Health Commands
```
health system    # System information
health alerts    # Active alerts
health services  # Service status
health disks     # Disk information
```

### truenas-dashboard.py

```
python truenas-dashboard.py [--refresh N]  # Launch dashboard (N seconds refresh)
```

**Displays:**
- Pool status & I/O
- Dataset usage
- Recent snapshots
- Replication status
- Service status
- System alerts

### truenas-snapshot-manager.py

#### List & Filter
```
list [--dataset NAME]                    # List all snapshots
     [--name-pattern REGEX]              # Filter by name
     [--dataset-pattern REGEX]           # Filter by dataset
     [--created-after YYYY-MM-DD]        # Date filter
     [--created-before YYYY-MM-DD]       # Date filter
     [--sort name|created|size]          # Sort by
     [--reverse]                         # Reverse order
```

#### Create
```
create <dataset> [--name NAME]          # Create snapshot
                 [--recursive]          # Include children
                 [--comment TEXT]       # Add comment
```

#### Delete
```
delete <id> [--defer]                   # Delete snapshot
bulk-delete --dataset NAME              # Bulk delete
            [--name-pattern REGEX]      # Filter by pattern
            [--older-than N]            # Older than N days
            [--dry-run]                 # Preview only
```

#### Advanced
```
clone <id> <new-dataset>                # Clone to new dataset
rollback <id> [--force]                 # Rollback
compare <id1> <id2>                     # Compare two snapshots
info <id>                               # Detailed info
```

#### Retention Policy
```
retention <dataset> [--hourly N]        # Keep N hourly snapshots
                    [--daily N]         # Keep N daily snapshots
                    [--weekly N]        # Keep N weekly snapshots
                    [--monthly N]       # Keep N monthly snapshots
                    [--dry-run]         # Preview only
```

### truenas-replication-manager.py

#### List & Monitor
```
list [--enabled-only] [--failed-only]   # List tasks
status <id>                             # Detailed status
monitor [--refresh N]                   # Real-time monitoring
```

#### Run & Control
```
run <id> [--wait] [--timeout N]         # Run task
enable <id>                             # Enable task
disable <id>                            # Disable (pause) task
```

#### Bandwidth
```
bandwidth <id> --limit N                # Set limit (KB/s)
bandwidth <id> --limit 0                # Remove limit
```

#### Retry & History
```
retry-failed [--max-retries N]          # Retry all failed tasks
             [--delay N]                # Delay between retries
history [--task-id N] [--days N]        # Show history
stats [--task-id N]                     # Show statistics
```

### truenas-api-examples.py

```
python truenas-api-examples.py          # Interactive menu
```

**Available Examples:**
1. Get System Information
2. List Pools and Usage
3. Create Dataset
4. Create Snapshot
5. List Recent Snapshots
6. Cleanup Old Snapshots
7. Create SMB Share
8. Monitor Replication
9. Disk Health Check
10. Backup Configuration
11. Service Management
12. Alert Monitoring

## File Locations

```
D:\workspace\True_Nas\windows-scripts\
├── Core Tools
│   ├── truenas-manager.py              # Main management CLI
│   ├── truenas-dashboard.py            # Monitoring dashboard
│   ├── truenas-snapshot-manager.py     # Snapshot operations
│   ├── truenas-replication-manager.py  # Replication control
│   └── truenas-api-examples.py         # Code examples
├── Setup & Config
│   ├── truenas-api-setup.py            # Initial setup (existing)
│   ├── test-truenas-tools.py           # Validation script
│   └── requirements.txt                # Dependencies
└── Documentation
    ├── TRUENAS_API_TOOLS_README.md     # Main documentation
    ├── QUICK_REFERENCE.md              # Quick reference
    └── TRUENAS_TOOLS_INDEX.md          # This index

Configuration:
~/.truenas/config.json                  # API configuration
```

## Use Case Matrix

| Task | Tool | Command |
|------|------|---------|
| View system status | truenas-manager.py | `health system` |
| Monitor live | truenas-dashboard.py | Launch dashboard |
| Create backup snapshot | truenas-snapshot-manager.py | `create tank/data --recursive` |
| List recent snapshots | truenas-snapshot-manager.py | `list --sort created` |
| Apply retention policy | truenas-snapshot-manager.py | `retention tank/data --daily 7 --weekly 4` |
| Clean old snapshots | truenas-snapshot-manager.py | `bulk-delete --older-than 30` |
| Run replication | truenas-replication-manager.py | `run 1 --wait` |
| Retry failed replications | truenas-replication-manager.py | `retry-failed` |
| Monitor replication | truenas-replication-manager.py | `monitor` |
| Create dataset | truenas-manager.py | `dataset create tank/new` |
| Create SMB share | truenas-manager.py | `smb create /mnt/tank/share Name` |
| Check pool capacity | truenas-manager.py | `pool check-capacity` |
| View alerts | truenas-manager.py | `health alerts` |
| Learn API usage | truenas-api-examples.py | Run interactive menu |

## Common Workflows

### Daily Health Check
```bash
python truenas-manager.py health alerts
python truenas-manager.py pool check-capacity --threshold 80
python truenas-replication-manager.py list --failed-only
```

### Weekly Maintenance
```bash
# Snapshot retention cleanup
python truenas-snapshot-manager.py retention tank/data --hourly 24 --daily 7 --weekly 4 --monthly 12

# Check disk health
python truenas-manager.py health disks

# Review replication stats
python truenas-replication-manager.py stats
```

### Pre-Update Snapshot
```bash
python truenas-snapshot-manager.py create tank \
  --name "pre-update-$(date +%Y%m%d)" \
  --recursive \
  --comment "Before system update"
```

### Monitor Active Operations
```bash
# Option 1: Dashboard
python truenas-dashboard.py

# Option 2: Replication monitor
python truenas-replication-manager.py monitor
```

## Automation Scripts

### Windows Batch Files

**daily-health-check.bat**
```batch
@echo off
cd D:\workspace\True_Nas\windows-scripts
python truenas-manager.py health alerts > logs\health-%date%.log 2>&1
python truenas-manager.py pool check-capacity --threshold 80 >> logs\health-%date%.log 2>&1
```

**weekly-snapshot-cleanup.bat**
```batch
@echo off
cd D:\workspace\True_Nas\windows-scripts
python truenas-snapshot-manager.py retention tank/important --hourly 24 --daily 7 --weekly 4 --monthly 12 > logs\cleanup-%date%.log 2>&1
```

**retry-failed-replications.bat**
```batch
@echo off
cd D:\workspace\True_Nas\windows-scripts
python truenas-replication-manager.py retry-failed --max-retries 3 > logs\replication-%date%.log 2>&1
```

## Tips & Tricks

### Get Help
```bash
# Tool help
python <tool-name>.py --help

# Command help
python truenas-manager.py pool --help

# Subcommand help
python truenas-manager.py pool list --help
```

### Use Custom Config
```bash
python truenas-manager.py --config /path/to/config.json pool list
```

### Dry Run Before Destructive Operations
```bash
# Always test with --dry-run first
python truenas-snapshot-manager.py bulk-delete --dataset tank/data --older-than 30 --dry-run
```

### Combine with PowerShell
```powershell
# Parse output in PowerShell
$health = python truenas-manager.py health system | Out-String
if ($health -match "CRITICAL") {
    Send-MailMessage -To admin@example.com -Subject "TrueNAS Alert" -Body $health
}
```

### Schedule with Task Scheduler
1. Create batch file
2. Open Task Scheduler
3. Create Basic Task
4. Set trigger (daily, weekly, etc.)
5. Action: Start program → Your batch file

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Module not found | `pip install -r requirements.txt` |
| Config not found | `python truenas-api-setup.py --setup` |
| Connection failed | Check TrueNAS is running, verify IP in config |
| Permission denied | Check API key permissions in TrueNAS |
| SSL errors | Ensure `verify_ssl: false` in config |

## Dependencies

All tools require:
- Python 3.8+
- requests
- urllib3
- rich
- click
- tabulate
- python-dateutil

Install with: `pip install -r requirements.txt`

## Version Information

- **Created**: 2024-12-10
- **Tools Version**: 1.0
- **Target Platform**: Windows 10/11
- **TrueNAS Compatibility**: TrueNAS SCALE (API v2.0)

## Quick Links

- Main Documentation: `TRUENAS_API_TOOLS_README.md`
- Quick Reference: `QUICK_REFERENCE.md`
- Test Tools: `python test-truenas-tools.py`
- Interactive Examples: `python truenas-api-examples.py`
