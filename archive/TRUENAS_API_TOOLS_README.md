# TrueNAS API Automation Tools

Comprehensive suite of Python tools for managing TrueNAS SCALE via API from Windows.

## Overview

This toolkit provides powerful command-line interfaces for managing all aspects of your TrueNAS SCALE system, including:

- Pool and dataset management
- Snapshot operations with retention policies
- Replication monitoring and control
- SMB share management
- User administration
- Real-time system monitoring
- Health checks and alerting

## Prerequisites

1. **Python 3.8 or higher**
2. **TrueNAS SCALE** system with API access
3. **Required Python packages** (install with `pip install -r requirements.txt`)

## Installation

### 1. Install Dependencies

```bash
cd D:\workspace\True_Nas\windows-scripts
pip install -r requirements.txt
```

### 2. Configure API Access

Run the setup script to configure your TrueNAS connection:

```bash
python truenas-api-setup.py --setup
```

This will:
- Prompt for your TrueNAS IP address
- Create an API key
- Save configuration to `~/.truenas/config.json`
- Test the connection

## Tools Overview

### 1. truenas-manager.py - Comprehensive Management CLI

Full-featured management tool with commands for all TrueNAS operations.

#### Pool Management

```bash
# List all storage pools
python truenas-manager.py pool list

# Get detailed pool status
python truenas-manager.py pool status tank

# Check pools exceeding capacity threshold
python truenas-manager.py pool check-capacity --threshold 80
```

#### Dataset Management

```bash
# List all datasets
python truenas-manager.py dataset list

# List datasets in specific pool
python truenas-manager.py dataset list --pool tank

# Create new dataset
python truenas-manager.py dataset create tank/backups --compression lz4 --quota 500G

# Delete dataset
python truenas-manager.py dataset delete tank/old-data --recursive
```

#### Snapshot Management

```bash
# List all snapshots
python truenas-manager.py snapshot list

# List snapshots for specific dataset
python truenas-manager.py snapshot list --dataset tank/important

# Create snapshot
python truenas-manager.py snapshot create tank/important --name manual-backup --recursive

# Delete snapshot
python truenas-manager.py snapshot delete tank/important@backup-20231201

# Rollback to snapshot
python truenas-manager.py snapshot rollback tank/important@backup-20231201
```

#### Replication Management

```bash
# List replication tasks
python truenas-manager.py replication list

# Run replication task manually
python truenas-manager.py replication run 1
```

#### SMB Share Management

```bash
# List SMB shares
python truenas-manager.py smb list

# Create SMB share
python truenas-manager.py smb create /mnt/tank/shared "SharedFolder" --comment "Team files"

# Delete SMB share
python truenas-manager.py smb delete 5
```

#### User Management

```bash
# List all users
python truenas-manager.py user list
```

#### Health Monitoring

```bash
# Show system information
python truenas-manager.py health system

# Show active alerts
python truenas-manager.py health alerts

# Show service status
python truenas-manager.py health services

# Show disk information
python truenas-manager.py health disks
```

### 2. truenas-dashboard.py - Real-Time Monitoring Dashboard

Beautiful terminal-based dashboard with auto-refresh.

```bash
# Launch dashboard (default 5-second refresh)
python truenas-dashboard.py

# Custom refresh interval
python truenas-dashboard.py --refresh 10
```

**Features:**
- Storage pool status and usage with color-coded alerts
- Top datasets by usage
- Recent snapshots
- Replication task status
- Service status
- System alerts
- Auto-refresh every 5 seconds (configurable)
- Press Ctrl+C to exit

### 3. truenas-snapshot-manager.py - Advanced Snapshot Operations

Powerful snapshot management with filtering, bulk operations, and retention policies.

#### List and Filter Snapshots

```bash
# List all snapshots
python truenas-snapshot-manager.py list

# Filter by dataset
python truenas-snapshot-manager.py list --dataset tank/data

# Filter by name pattern (regex)
python truenas-snapshot-manager.py list --name-pattern "auto-.*"

# Filter by date range
python truenas-snapshot-manager.py list --created-after 2023-11-01 --created-before 2023-12-01

# Sort by size
python truenas-snapshot-manager.py list --sort size --reverse
```

#### Create Snapshots

```bash
# Create snapshot with auto-generated name
python truenas-snapshot-manager.py create tank/important

# Create named snapshot
python truenas-snapshot-manager.py create tank/important --name pre-upgrade

# Create recursive snapshot with comment
python truenas-snapshot-manager.py create tank/important --recursive --comment "Before major update"
```

#### Bulk Operations

```bash
# Delete snapshots matching pattern (dry run)
python truenas-snapshot-manager.py bulk-delete --dataset tank/data --name-pattern "temp-.*" --dry-run

# Delete snapshots older than 30 days
python truenas-snapshot-manager.py bulk-delete --dataset tank/data --older-than 30
```

#### Retention Policies

```bash
# Apply retention policy (dry run)
python truenas-snapshot-manager.py retention tank/important \
  --hourly 24 \
  --daily 7 \
  --weekly 4 \
  --monthly 12 \
  --dry-run

# Apply retention policy (actually delete)
python truenas-snapshot-manager.py retention tank/important --hourly 24 --daily 7 --weekly 4 --monthly 12
```

#### Advanced Operations

```bash
# Clone snapshot to new dataset
python truenas-snapshot-manager.py clone tank/data@backup-20231201 tank/data-restore

# Rollback to snapshot (with force)
python truenas-snapshot-manager.py rollback tank/data@backup-20231201 --force

# Compare two snapshots
python truenas-snapshot-manager.py compare tank/data@snap1 tank/data@snap2

# Show detailed snapshot info
python truenas-snapshot-manager.py info tank/data@backup-20231201
```

### 4. truenas-replication-manager.py - Replication Control

Advanced replication management with monitoring, retry, and bandwidth control.

#### List and Monitor

```bash
# List all replication tasks
python truenas-replication-manager.py list

# Show only enabled tasks
python truenas-replication-manager.py list --enabled-only

# Show only failed tasks
python truenas-replication-manager.py list --failed-only

# Show detailed task status
python truenas-replication-manager.py status 1

# Real-time monitoring
python truenas-replication-manager.py monitor --refresh 5
```

#### Run and Control

```bash
# Run replication task
python truenas-replication-manager.py run 1

# Run and wait for completion
python truenas-replication-manager.py run 1 --wait --timeout 3600

# Enable/disable tasks
python truenas-replication-manager.py enable 1
python truenas-replication-manager.py disable 1
```

#### Bandwidth Control

```bash
# Set bandwidth limit to 10 MB/s
python truenas-replication-manager.py bandwidth 1 --limit 10240

# Remove bandwidth limit (unlimited)
python truenas-replication-manager.py bandwidth 1 --limit 0
```

#### Automatic Retry

```bash
# Retry all failed replication tasks
python truenas-replication-manager.py retry-failed --max-retries 3 --delay 60
```

#### History and Statistics

```bash
# Show replication history (last 7 days)
python truenas-replication-manager.py history

# Show history for specific task
python truenas-replication-manager.py history --task-id 1 --days 30

# Show statistics
python truenas-replication-manager.py stats

# Show statistics for specific task
python truenas-replication-manager.py stats --task-id 1
```

### 5. truenas-api-examples.py - Code Examples and Best Practices

Interactive examples demonstrating common API operations.

```bash
# Launch interactive menu
python truenas-api-examples.py
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

Each example includes:
- Well-commented code
- Error handling
- Best practices
- Safety checks (commented out destructive operations)

## Configuration

All tools use the same configuration file: `~/.truenas/config.json`

Example configuration:

```json
{
  "host": "10.0.0.89",
  "api_key": "1-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "username": "jdmal",
  "verify_ssl": false
}
```

### Using Custom Configuration

All tools support the `--config` option to use a different configuration file:

```bash
python truenas-manager.py --config /path/to/config.json pool list
```

## Common Use Cases

### Daily Health Check

```bash
# Quick system health check
python truenas-manager.py health system
python truenas-manager.py health alerts
python truenas-manager.py pool check-capacity --threshold 80
```

### Automated Snapshot Cleanup

```bash
# Clean up old snapshots with retention policy
python truenas-snapshot-manager.py retention tank/data \
  --hourly 24 --daily 7 --weekly 4 --monthly 12
```

### Replication Monitoring

```bash
# Check replication status and retry failures
python truenas-replication-manager.py list --failed-only
python truenas-replication-manager.py retry-failed --max-retries 3
```

### Pre-Maintenance Snapshot

```bash
# Create comprehensive snapshot before maintenance
python truenas-snapshot-manager.py create tank \
  --name "pre-maintenance-$(date +%Y%m%d)" \
  --recursive \
  --comment "Before system maintenance"
```

### Bulk Dataset Creation

```python
# Use truenas-manager.py in a script
datasets = ["backups/windows", "backups/linux", "backups/mac"]
for ds in datasets:
    python truenas-manager.py dataset create f"tank/{ds}" --compression lz4
```

## Scheduling with Windows Task Scheduler

### Example: Daily Health Check

1. Create a batch file `truenas-health-check.bat`:

```batch
@echo off
cd D:\workspace\True_Nas\windows-scripts
python truenas-manager.py health alerts > health-check.log 2>&1
python truenas-manager.py pool check-capacity --threshold 80 >> health-check.log 2>&1
```

2. Create scheduled task:
   - Open Task Scheduler
   - Create Basic Task
   - Set trigger: Daily at 6:00 AM
   - Action: Start a program
   - Program: `D:\workspace\True_Nas\windows-scripts\truenas-health-check.bat`

### Example: Weekly Snapshot Cleanup

1. Create `truenas-cleanup-snapshots.bat`:

```batch
@echo off
cd D:\workspace\True_Nas\windows-scripts
python truenas-snapshot-manager.py retention tank/important --hourly 24 --daily 7 --weekly 4 --monthly 12 > cleanup.log 2>&1
```

2. Schedule weekly on Sunday at 2:00 AM

## Troubleshooting

### Connection Issues

```bash
# Test API connection
python truenas-api-setup.py --status
```

### SSL Certificate Errors

If you get SSL errors, ensure `verify_ssl: false` in your config file for self-signed certificates.

### Permission Errors

Ensure your API key has sufficient permissions. You may need to create the API key with admin privileges.

### Finding IDs

Most commands accept IDs. To find them:

```bash
# Get dataset IDs
python truenas-manager.py dataset list

# Get snapshot IDs
python truenas-snapshot-manager.py list

# Get replication task IDs
python truenas-replication-manager.py list
```

## Security Best Practices

1. **Protect your config file**: `chmod 600 ~/.truenas/config.json` (on WSL/Git Bash)
2. **Use dedicated API keys**: Create separate API keys for different purposes
3. **Limit API key permissions**: Only grant necessary permissions
4. **Rotate API keys regularly**: Generate new keys periodically
5. **Never commit API keys**: Add `.truenas/` to `.gitignore`

## Advanced Tips

### Combining with PowerShell

```powershell
# Get pool usage as JSON for processing
$pools = python truenas-manager.py pool list --json | ConvertFrom-Json

# Alert if any pool is over 80%
foreach ($pool in $pools) {
    if ($pool.usage -gt 80) {
        Send-MailMessage -To admin@example.com -Subject "Pool Alert" -Body "Pool $($pool.name) is at $($pool.usage)%"
    }
}
```

### Using with WSL

All tools work seamlessly in WSL:

```bash
# In WSL
cd /mnt/d/workspace/True_Nas/windows-scripts
python3 truenas-manager.py pool list
```

### Remote Monitoring

Set up multiple config files for different TrueNAS systems:

```bash
# Monitor production system
python truenas-manager.py --config ~/.truenas/prod.json pool list

# Monitor backup system
python truenas-manager.py --config ~/.truenas/backup.json pool list
```

## API Documentation

For detailed API documentation, refer to:
- TrueNAS SCALE API Docs: `https://YOUR-TRUENAS-IP/api/docs`
- Online Documentation: https://www.truenas.com/docs/scale/

## Support

For issues or questions:
1. Check the TrueNAS API documentation
2. Review the example scripts in `truenas-api-examples.py`
3. Check TrueNAS community forums
4. Review error logs and API responses

## License

These tools are provided as-is for managing TrueNAS SCALE systems.

## Version History

- **v1.0** (2024-12-10) - Initial release
  - truenas-manager.py - Comprehensive management CLI
  - truenas-dashboard.py - Real-time monitoring dashboard
  - truenas-snapshot-manager.py - Advanced snapshot management
  - truenas-replication-manager.py - Replication control
  - truenas-api-examples.py - Code examples and best practices
