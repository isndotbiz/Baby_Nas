# TrueNAS API Tools - Quick Reference

## Setup (One-time)

```bash
pip install -r requirements.txt
python truenas-api-setup.py --setup
```

## Most Common Commands

### Daily Operations

```bash
# Check system health
python truenas-manager.py health system
python truenas-manager.py health alerts

# View pools
python truenas-manager.py pool list

# Check capacity
python truenas-manager.py pool check-capacity --threshold 80

# Launch dashboard
python truenas-dashboard.py
```

### Snapshots

```bash
# Create snapshot
python truenas-snapshot-manager.py create tank/data --recursive

# List snapshots
python truenas-snapshot-manager.py list --dataset tank/data

# Apply retention (keep hourly:24, daily:7, weekly:4, monthly:12)
python truenas-snapshot-manager.py retention tank/data --hourly 24 --daily 7 --weekly 4 --monthly 12 --dry-run
```

### Replication

```bash
# List tasks
python truenas-replication-manager.py list

# Run task
python truenas-replication-manager.py run 1 --wait

# Monitor in real-time
python truenas-replication-manager.py monitor

# Retry failed
python truenas-replication-manager.py retry-failed
```

### Datasets

```bash
# List datasets
python truenas-manager.py dataset list

# Create dataset
python truenas-manager.py dataset create tank/backups --compression lz4 --quota 500G
```

### SMB Shares

```bash
# List shares
python truenas-manager.py smb list

# Create share
python truenas-manager.py smb create /mnt/tank/shared "ShareName"
```

## Emergency Commands

```bash
# Immediate snapshot before risky operation
python truenas-snapshot-manager.py create tank --name emergency-$(date +%Y%m%d-%H%M%S) --recursive

# Rollback to last good snapshot
python truenas-snapshot-manager.py rollback tank/data@last-good-snapshot

# Check for critical alerts
python truenas-manager.py health alerts
```

## Automation Examples

### Batch File: Daily Health Check

```batch
@echo off
python truenas-manager.py health alerts
python truenas-manager.py pool check-capacity --threshold 80
python truenas-replication-manager.py list --failed-only
```

### Batch File: Weekly Cleanup

```batch
@echo off
python truenas-snapshot-manager.py retention tank/important --hourly 24 --daily 7 --weekly 4 --monthly 12
python truenas-snapshot-manager.py retention tank/backups --daily 7 --weekly 4
```

## Cheat Sheet

| Task | Command |
|------|---------|
| System info | `python truenas-manager.py health system` |
| Pool status | `python truenas-manager.py pool list` |
| Create snapshot | `python truenas-snapshot-manager.py create DATASET` |
| List snapshots | `python truenas-snapshot-manager.py list` |
| Run replication | `python truenas-replication-manager.py run TASK_ID` |
| Dashboard | `python truenas-dashboard.py` |
| Examples | `python truenas-api-examples.py` |

## Help Commands

```bash
# Get help for any tool
python truenas-manager.py --help
python truenas-manager.py pool --help
python truenas-manager.py pool list --help

python truenas-snapshot-manager.py --help
python truenas-replication-manager.py --help
```

## Configuration Location

`~/.truenas/config.json` (Windows: `C:\Users\YourName\.truenas\config.json`)
