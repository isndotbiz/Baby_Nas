# ZFS Replication: Baby NAS to Main NAS

This document describes the ZFS replication configuration from Baby NAS (10.0.0.88) to Main NAS (10.0.0.89).

## Overview

| Setting | Value |
|---------|-------|
| **Source** | Baby NAS (10.0.0.88) |
| **Destination** | Main NAS (10.0.0.89) |
| **Schedule** | Daily at 2:30 AM |
| **Direction** | PUSH (Baby NAS sends to Main NAS) |
| **Transport** | SSH |

## Replicated Datasets

| Source Dataset | Target Dataset |
|----------------|----------------|
| tank/workspace | tank/babynas/workspace |
| tank/models | tank/babynas/models |
| tank/staging | tank/babynas/staging |
| tank/backups | tank/babynas/backups |

## Snapshot Configuration

All datasets have automatic snapshot tasks:

### Hourly Snapshots
- **Schedule**: Every hour
- **Retention**: 24 hours
- **Naming Schema**: `hourly-%Y-%m-%d_%H-%M`

### Daily Snapshots
- **Schedule**: Daily at midnight
- **Retention**: 7 days
- **Naming Schema**: `daily-%Y-%m-%d_%H-%M`

## SSH Credentials

### Keypair Credential (ID: 1)
- **Name**: main-nas-replication
- **Type**: SSH_KEY_PAIR
- **Purpose**: Stores the RSA keypair for authentication

### Connection Credential (ID: 2)
- **Name**: main-nas-connection
- **Type**: SSH_CREDENTIALS
- **Host**: 10.0.0.89
- **Port**: 22
- **Username**: root

## Replication Task Details

- **Task ID**: 1
- **Name**: Baby NAS to Main NAS
- **Retention Policy**: SOURCE (follows source snapshot retention)
- **Properties**: Replicated (includes compression, recordsize, etc.)
- **Large Block**: Enabled
- **Compression**: Enabled (for network transfer)
- **Recursive**: Yes
- **Read-only**: Target datasets are read-only

## Management Commands

### Check Replication Status
```bash
ssh babynas "midclt call replication.query | python3 -c 'import sys, json; data = json.load(sys.stdin); print(json.dumps(data[0][\"state\"], indent=2))'"
```

### Run Manual Replication
```bash
ssh babynas "midclt call replication.run 1"
```

### Check Replication Job Status
```bash
ssh babynas 'midclt call core.get_jobs "[[\"method\", \"=\", \"replication.run\"]]" | python3 -c "import sys, json; jobs = json.load(sys.stdin); print(jobs[0][\"state\"] if jobs else \"No jobs\")"'
```

### View Snapshots on Baby NAS
```bash
ssh babynas "sudo zfs list -t snapshot -r tank"
```

### View Replicated Data on Main NAS
```bash
ssh 10.0.0.89 "zfs list -r tank/babynas"
```

### View Replicated Snapshots on Main NAS
```bash
ssh 10.0.0.89 "zfs list -t snapshot -r tank/babynas"
```

## TrueNAS Web UI

Replication can also be managed via the TrueNAS Web UI:

1. **Baby NAS**: https://10.0.0.88 or https://baby.isn.biz
2. Navigate to: **Data Protection** -> **Replication Tasks**
3. The task "Baby NAS to Main NAS" should be visible and enabled

## Troubleshooting

### SSH Connection Issues
```bash
# Test SSH from Baby NAS to Main NAS
ssh babynas "ssh -i /root/.ssh/replication_key root@10.0.0.89 'zfs list tank/babynas'"
```

### Check Replication Logs
```bash
ssh babynas "cat /var/log/jobs/$(midclt call replication.query | python3 -c 'import sys, json; print(json.load(sys.stdin)[0].get(\"job\", {}).get(\"id\", 0))').log 2>/dev/null || echo 'No recent job log'"
```

### Verify Credentials
```bash
ssh babynas "midclt call keychaincredential.query | python3 -c 'import sys, json; [print(c[\"id\"], c[\"name\"], c[\"type\"]) for c in json.load(sys.stdin)]'"
```

## Recovery Procedures

### Restore from Replication
If Baby NAS fails and needs restoration from Main NAS:

1. The replicated data is at `tank/babynas/*` on Main NAS
2. Snapshots preserve point-in-time recovery options
3. Use `zfs send/receive` to restore to a new Baby NAS

### Example Restore Command
```bash
# On Main NAS, send latest snapshot to new Baby NAS
ssh 10.0.0.89 "zfs send -R tank/babynas/workspace@latest" | ssh new-baby-nas "zfs receive -F tank/workspace"
```

## Configuration Date

- **Setup Date**: 2026-01-08
- **Last Verified**: 2026-01-08
- **Configured By**: Claude Code automation

## Notes

- Replication uses incremental sends after initial full sync
- Target datasets on Main NAS are automatically set to read-only
- Snapshots are retained according to source retention policy
- Network transfer is compressed for efficiency
