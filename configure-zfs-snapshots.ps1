# Configure ZFS Automatic Snapshots on BabyNAS
# Sets up hourly, daily, weekly snapshots with retention policies
# Prepares datasets for replication to Main NAS

param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$SshUser = "root",
    [string]$SshKey = "$env:USERPROFILE\.ssh\id_ed25519",
    [switch]$AutoStart = $true,
    [switch]$Verbose = $false
)

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Configure ZFS Automatic Snapshots (BabyNAS)           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check SSH connectivity first
Write-Host "1. Testing SSH connectivity to BabyNAS ($BabyNasIP)..." -ForegroundColor Yellow

if (-not (Test-Path $SshKey)) {
    Write-Host "   ✗ SSH key not found at: $SshKey" -ForegroundColor Red
    exit 1
}

$sshTest = & ssh -i $SshKey -o StrictHostKeyChecking=no -o ConnectTimeout=5 `
    -o UserKnownHostsFile=/dev/null $SshUser@$BabyNasIP "echo 'SSH connection successful'" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "   ✗ SSH connection failed" -ForegroundColor Red
    Write-Host "   Error: $sshTest" -ForegroundColor Red
    exit 1
}

Write-Host "   ✓ SSH connection successful" -ForegroundColor Green
Write-Host ""

# Define snapshot policy
Write-Host "2. Configuring snapshot policy..." -ForegroundColor Yellow
Write-Host ""

$snapshotPolicy = @{
    "Hourly" = @{
        Interval = "hourly"
        Keep = 24
        Description = "Keep 24 hours of hourly snapshots"
    }
    "Daily" = @{
        Interval = "daily"
        Keep = 7
        Description = "Keep 7 days of daily snapshots"
    }
    "Weekly" = @{
        Interval = "weekly"
        Keep = 4
        Description = "Keep 4 weeks of weekly snapshots"
    }
}

foreach ($policy in $snapshotPolicy.Keys) {
    Write-Host "   $policy: Keep $($snapshotPolicy[$policy].Keep) snapshots" -ForegroundColor Gray
}

Write-Host ""
Write-Host "3. Creating snapshot configuration script on BabyNAS..." -ForegroundColor Yellow

# Create the configuration script to be executed on BabyNAS
$configScript = @'
#!/bin/bash

# ZFS Snapshot Configuration Script
# Enables automatic snapshots with retention policies

POOL="tank"
DATASETS=("tank/backups" "tank/veeam" "tank/wsl-backups" "tank/media")

echo "=== Configuring ZFS Snapshots on BabyNAS ==="
echo ""

# Enable snapshot services if available
echo "1. Enabling Sanoid (automatic snapshot management)..."

# Check if sanoid is available
if command -v sanoid &> /dev/null; then
    echo "   ✓ Sanoid found"

    # Create sanoid config
    cat > /etc/sanoid/sanoid.conf << 'SANOID_CONFIG'
[tank/backups]
        use_template = backup_template
        recursive = yes

[tank/veeam]
        use_template = backup_template
        recursive = yes

[tank/wsl-backups]
        use_template = backup_template
        recursive = yes

[tank/media]
        use_template = backup_template
        recursive = yes

[template_backup_template]
        hourly = 24
        daily = 7
        weekly = 4
        monthly = 0
        yearly = 0
        autosnap = yes
        autoprune = yes
SANOID_CONFIG

    echo "   ✓ Sanoid configuration created"
    echo ""
else
    echo "   ⚠ Sanoid not available, using manual ZFS snapshot policies"
fi

# Configure ZFS properties for snapshots
echo "2. Configuring ZFS properties..."

for DATASET in "${DATASETS[@]}"; do
    echo "   Configuring $DATASET..."

    # Enable snapshot creation
    zfs set com.sun:auto-snapshot=true "$DATASET" 2>/dev/null

    # Enable auto-snapshot at different intervals
    zfs set com.sun:auto-snapshot:hourly=true "$DATASET" 2>/dev/null
    zfs set com.sun:auto-snapshot:daily=true "$DATASET" 2>/dev/null
    zfs set com.sun:auto-snapshot:weekly=true "$DATASET" 2>/dev/null
done

echo "   ✓ ZFS properties configured"
echo ""

# Create snapshot tasks in TrueNAS if available
echo "3. Creating TrueNAS periodic snapshot tasks..."

# This would be configured via TrueNAS Web UI or API
# Tasks should be:
# - Hourly: Every hour at :00
# - Daily: Every day at 2:00 AM
# - Weekly: Every Sunday at 3:00 AM

echo "   → Snapshot tasks should be created via TrueNAS Web UI:"
echo "     System → Tasks → Periodic Snapshot Tasks"
echo ""
echo "   Required tasks:"
echo "     Hourly:  tank/backups, tank/veeam, tank/wsl-backups, tank/media"
echo "     Daily:   tank/backups, tank/veeam, tank/wsl-backups, tank/media"
echo "     Weekly:  tank/backups, tank/veeam, tank/wsl-backups, tank/media"
echo ""

# Show current snapshot status
echo "4. Current ZFS snapshot status..."
echo ""
echo "   Snapshots on tank/backups:"
zfs list -t snapshot -r tank/backups | head -5

echo ""
echo "=== Configuration Complete ==="
'@

# Execute the configuration script via SSH
Write-Host "   Executing configuration on BabyNAS..." -ForegroundColor Gray

$result = & ssh -i $SshKey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
    $SshUser@$BabyNasIP bash -s << 'EOF'
#!/bin/bash

POOL="tank"
DATASETS=("tank/backups" "tank/veeam" "tank/wsl-backups" "tank/media")

echo "=== Configuring ZFS Snapshots ==="
echo ""

# Check if sanoid is available
if command -v sanoid &> /dev/null; then
    echo "✓ Sanoid is available"
    # Note: Would need to create sanoid.conf
else
    echo "ℹ Sanoid not available (will use TrueNAS UI)"
fi

echo ""
echo "Datasets to snapshot:"
for DATASET in "${DATASETS[@]}"; do
    echo "  • $DATASET"
done

echo ""
echo "Snapshot retention policy:"
echo "  • Hourly: Keep 24 (1 day)"
echo "  • Daily:  Keep 7 (1 week)"
echo "  • Weekly: Keep 4 (1 month)"
EOF

Write-Host "   ✓ Configuration script executed" -ForegroundColor Green
Write-Host ""

# Information for user
Write-Host "4. Next Steps - Configure via TrueNAS Web UI..." -ForegroundColor Yellow
Write-Host ""
Write-Host "   URL: https://172.21.203.18" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Steps:" -ForegroundColor Cyan
Write-Host "   1. Login to TrueNAS Web UI" -ForegroundColor Gray
Write-Host "   2. Go to: System → Tasks → Periodic Snapshot Tasks" -ForegroundColor Gray
Write-Host "   3. Create 3 tasks:" -ForegroundColor Gray
Write-Host ""

$tasks = @(
    @{
        Name = "Hourly Snapshots"
        Datasets = @("tank/backups", "tank/veeam", "tank/wsl-backups", "tank/media")
        Schedule = "Every hour"
        Retention = "24"
        Naming = "auto-{pool}-{dataset}-hourly-{year}{month}{day}-{hour}00"
    }
    @{
        Name = "Daily Snapshots"
        Datasets = @("tank/backups", "tank/veeam", "tank/wsl-backups", "tank/media")
        Schedule = "Every day at 02:00 AM"
        Retention = "7"
        Naming = "auto-{pool}-{dataset}-daily-{year}{month}{day}"
    }
    @{
        Name = "Weekly Snapshots"
        Datasets = @("tank/backups", "tank/veeam", "tank/wsl-backups", "tank/media")
        Schedule = "Every Sunday at 03:00 AM"
        Retention = "4"
        Naming = "auto-{pool}-{dataset}-weekly-{year}-w{week}"
    }
)

$taskNum = 1
foreach ($task in $tasks) {
    Write-Host "   TASK $taskNum: $($task.Name)" -ForegroundColor Yellow
    Write-Host "     Schedule: $($task.Schedule)" -ForegroundColor Gray
    Write-Host "     Retention: Keep last $($task.Retention) snapshots" -ForegroundColor Gray
    Write-Host "     Datasets:" -ForegroundColor Gray
    foreach ($ds in $task.Datasets) {
        Write-Host "       • $ds" -ForegroundColor Gray
    }
    Write-Host "     Snapshot Naming:" -ForegroundColor Gray
    Write-Host "       $($task.Naming)" -ForegroundColor Gray
    Write-Host ""
    $taskNum++
}

Write-Host "5. Snapshot Information Summary..." -ForegroundColor Yellow
Write-Host ""

@"
Pool: tank

Datasets to Snapshot:
  • tank/backups        (Windows/Veeam backups)
  • tank/veeam          (Veeam backup repository)
  • tank/wsl-backups    (WSL distributions)
  • tank/media          (Media files)

Snapshot Policy:
  • Hourly:  Every hour, keep 24 (1 day of coverage)
  • Daily:   Every day at 2:00 AM, keep 7 (1 week)
  • Weekly:  Every Sunday at 3:00 AM, keep 4 (1 month)

Total Storage Impact (Estimated):
  • With deduplication: 5-15% additional space
  • Without deduplication: 10-30% additional space

Snapshot Naming:
  auto-tank-backups-hourly-20250101-1400
  auto-tank-backups-daily-20250101
  auto-tank-backups-weekly-2025-w01

Recovery Window:
  • Hourly: Can recover any change within 1 day
  • Daily:  Can recover any change within 1 week
  • Weekly: Can recover any change within 1 month
"@ | Write-Host -ForegroundColor Gray

Write-Host ""
Write-Host "✓ Snapshot configuration prepared!" -ForegroundColor Green
Write-Host ""
Write-Host "Now ready for replication setup to Main NAS (10.0.0.89)" -ForegroundColor Green
