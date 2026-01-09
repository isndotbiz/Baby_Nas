# ZFS Snapshot Configuration - Baby NAS

## Overview

Baby NAS (10.0.0.88) is configured with automated ZFS snapshots for data protection. Snapshots provide point-in-time recovery capabilities with minimal storage overhead.

## Configured Snapshot Tasks

| ID | Dataset | Schedule | Retention | Naming Schema |
|----|---------|----------|-----------|---------------|
| 1 | tank/workspace | Hourly (every hour at :00) | 24 hours | `hourly-%Y-%m-%d_%H-%M` |
| 2 | tank/workspace | Daily (midnight) | 7 days | `daily-%Y-%m-%d_%H-%M` |
| 3 | tank/models | Hourly (every hour at :00) | 24 hours | `hourly-%Y-%m-%d_%H-%M` |
| 4 | tank/models | Daily (midnight) | 7 days | `daily-%Y-%m-%d_%H-%M` |

## Retention Policy

- **Hourly snapshots**: Keep last 24 (1 day of hourly granularity)
- **Daily snapshots**: Keep last 7 (1 week of daily recovery points)

This provides:
- Fine-grained recovery for the last 24 hours
- Daily recovery points for the past week
- Automatic cleanup of old snapshots

## Snapshot Naming Convention

- `hourly-2026-01-08_14-00` = Hourly snapshot from January 8, 2026 at 14:00
- `daily-2026-01-08_00-00` = Daily snapshot from January 8, 2026 at midnight

## Management Commands

### Check Snapshot Tasks
```bash
ssh babynas "midclt call pool.snapshottask.query"
```

### List All Snapshots
```bash
ssh babynas "midclt call zfs.snapshot.query '[[\"pool\", \"=\", \"tank\"]]'"
```

### Manually Trigger a Snapshot Task
```bash
# Run task by ID (1=workspace hourly, 2=workspace daily, etc.)
ssh babynas "midclt call pool.snapshottask.run 1"
```

### Create Manual Snapshot
```bash
ssh babynas "midclt call zfs.snapshot.create '{\"dataset\": \"tank/workspace\", \"name\": \"manual-backup\"}'"
```

### Delete a Snapshot
```bash
ssh babynas "midclt call zfs.snapshot.delete 'tank/workspace@manual-backup'"
```

### Rollback to Snapshot (CAUTION: Destroys changes since snapshot)
```bash
ssh babynas "midclt call zfs.snapshot.rollback 'tank/workspace@hourly-2026-01-08_14-00'"
```

## Accessing Snapshot Data (Non-destructive)

ZFS snapshots are accessible via the `.zfs/snapshot` hidden directory:

From Windows (via SMB):
```
\\baby.isn.biz\workspace\.zfs\snapshot\hourly-2026-01-08_14-00\
```

From the NAS:
```bash
ls /mnt/tank/workspace/.zfs/snapshot/
```

## Modifying Tasks

### Disable a Task
```bash
ssh babynas "midclt call pool.snapshottask.update 1 '{\"enabled\": false}'"
```

### Delete a Task
```bash
ssh babynas "midclt call pool.snapshottask.delete 1"
```

### Create New Task
```bash
ssh babynas "midclt call pool.snapshottask.create '{
  \"dataset\": \"tank/backups\",
  \"recursive\": true,
  \"lifetime_value\": 30,
  \"lifetime_unit\": \"DAY\",
  \"naming_schema\": \"monthly-%Y-%m-%d\",
  \"schedule\": {\"minute\": \"0\", \"hour\": \"0\", \"dom\": \"1\", \"month\": \"*\", \"dow\": \"*\"}
}'"
```

## Configuration Date

Configured: January 8, 2026

## Related Documentation

- [TrueNAS SCALE API Documentation](https://www.truenas.com/docs/scale/)
- ZFS replication to Main NAS: See separate replication documentation
