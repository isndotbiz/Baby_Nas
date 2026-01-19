#Requires -RunAsAdministrator
###############################################################################
# Baby NAS to Main NAS Replication Setup
# Configures ZFS replication from Baby NAS → Main NAS (10.0.0.89)
###############################################################################

param(
    [Parameter(Mandatory=$true)]
    [string]$BabyNasIP,

    [Parameter(Mandatory=$false)]
    [string]$MainNasIP = "10.0.0.89",

    [Parameter(Mandatory=$false)]
    [string]$MainNasSSHKey = "$env:USERPROFILE\.ssh\truenas_admin_10_0_0_89"
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║           ZFS Replication Setup: Baby NAS → Main NAS                    ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "Baby NAS (Source): $BabyNasIP" -ForegroundColor Yellow
Write-Host "Main NAS (Target): $MainNasIP" -ForegroundColor Yellow
Write-Host ""

###############################################################################
# Step 1: Verify Connectivity
###############################################################################
Write-Host "=== Verifying Connectivity ===" -ForegroundColor Green

# Test Baby NAS
if (-not (Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet)) {
    Write-Host "✗ Cannot reach Baby NAS at $BabyNasIP" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Baby NAS reachable" -ForegroundColor Green

# Test Main NAS
if (-not (Test-Connection -ComputerName $MainNasIP -Count 2 -Quiet)) {
    Write-Host "✗ Cannot reach Main NAS at $MainNasIP" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Main NAS reachable" -ForegroundColor Green

# Test SSH to Baby NAS
try {
    ssh -i "$env:USERPROFILE\.ssh\id_babynas" root@$BabyNasIP "echo 'Baby NAS SSH OK'" | Out-Null
    Write-Host "✓ Baby NAS SSH access working" -ForegroundColor Green
} catch {
    Write-Host "✗ Cannot SSH to Baby NAS" -ForegroundColor Red
    exit 1
}

# Test SSH to Main NAS
if (Test-Path $MainNasSSHKey) {
    try {
        ssh -i $MainNasSSHKey root@$MainNasIP "echo 'Main NAS SSH OK'" | Out-Null
        Write-Host "✓ Main NAS SSH access working" -ForegroundColor Green
    } catch {
        Write-Host "✗ Cannot SSH to Main NAS" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "⚠ Main NAS SSH key not found: $MainNasSSHKey" -ForegroundColor Yellow
    Write-Host "  Attempting to use default root access..." -ForegroundColor Cyan
}

###############################################################################
# Step 2: Generate Replication SSH Key on Baby NAS
###############################################################################
Write-Host ""
Write-Host "=== Generating Replication SSH Key ===" -ForegroundColor Green

$genKeyScript = @'
#!/bin/bash
# Generate replication SSH key

if [ ! -f /root/.ssh/id_replication ]; then
    echo "Generating replication key..."
    ssh-keygen -t ed25519 -f /root/.ssh/id_replication -N '' -C 'babynas-to-mainnas-replication'
    echo "✓ Key generated"
else
    echo "• Key already exists"
fi

# Display public key
cat /root/.ssh/id_replication.pub
'@

Write-Host "Generating key on Baby NAS..." -ForegroundColor Cyan
$pubKey = $genKeyScript | ssh -i "$env:USERPROFILE\.ssh\id_babynas" root@$BabyNasIP "bash"

Write-Host "✓ Replication key generated" -ForegroundColor Green
Write-Host ""
Write-Host "Public Key:" -ForegroundColor Yellow
Write-Host $pubKey -ForegroundColor Cyan

###############################################################################
# Step 3: Add Baby NAS Key to Main NAS
###############################################################################
Write-Host ""
Write-Host "=== Adding Baby NAS Key to Main NAS ===" -ForegroundColor Green

$addKeyScript = @"
#!/bin/bash
# Add Baby NAS public key to Main NAS authorized_keys

mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Add key if not already present
if ! grep -q 'babynas-to-mainnas-replication' /root/.ssh/authorized_keys 2>/dev/null; then
    echo '$pubKey' >> /root/.ssh/authorized_keys
    echo '✓ Key added'
else
    echo '• Key already present'
fi
"@

if (Test-Path $MainNasSSHKey) {
    $addKeyScript | ssh -i $MainNasSSHKey root@$MainNasIP "bash"
} else {
    $addKeyScript | ssh root@$MainNasIP "bash"
}

Write-Host "✓ Key added to Main NAS" -ForegroundColor Green

###############################################################################
# Step 4: Test Baby NAS → Main NAS Connection
###############################################################################
Write-Host ""
Write-Host "=== Testing Replication Connection ===" -ForegroundColor Green

$testCmd = "ssh -i /root/.ssh/id_replication -o StrictHostKeyChecking=no root@$MainNasIP 'echo Replication SSH OK'"
$result = ssh -i "$env:USERPROFILE\.ssh\id_babynas" root@$BabyNasIP $testCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Replication connection working!" -ForegroundColor Green
} else {
    Write-Host "✗ Replication connection failed" -ForegroundColor Red
    exit 1
}

###############################################################################
# Step 5: Create Replication Target on Main NAS
###############################################################################
Write-Host ""
Write-Host "=== Creating Replication Target on Main NAS ===" -ForegroundColor Green

$createTargetScript = @'
#!/bin/bash
# Create replication target datasets on Main NAS

echo "Creating replication target datasets..."

# Check if backup pool exists
if ! zpool list backup &>/dev/null; then
    echo "✗ Pool 'backup' not found on Main NAS!"
    echo "  Create it first or use different pool"
    exit 1
fi

# Create parent dataset
if ! zfs list backup/babynas &>/dev/null; then
    zfs create backup/babynas
    echo "✓ Created backup/babynas"
else
    echo "• backup/babynas already exists"
fi

# Create subdatasets
zfs create backup/babynas/windows-backups 2>/dev/null || echo "• windows-backups exists"
zfs create backup/babynas/veeam 2>/dev/null || echo "• veeam exists"

# Set properties to match Baby NAS
zfs set compression=lz4 backup/babynas 2>/dev/null
zfs set recordsize=128K backup/babynas/windows-backups 2>/dev/null
zfs set recordsize=1M backup/babynas/veeam 2>/dev/null

echo "✓ Replication targets configured"

# Show datasets
echo ""
echo "Created datasets:"
zfs list -r backup/babynas
'@

if (Test-Path $MainNasSSHKey) {
    $createTargetScript | ssh -i $MainNasSSHKey root@$MainNasIP "bash"
} else {
    $createTargetScript | ssh root@$MainNasIP "bash"
}

Write-Host "✓ Replication targets created on Main NAS" -ForegroundColor Green

###############################################################################
# Step 6: Create Replication Script on Baby NAS
###############################################################################
Write-Host ""
Write-Host "=== Creating Replication Script on Baby NAS ===" -ForegroundColor Green

$replicationScript = @"
#!/bin/bash
###############################################################################
# ZFS Replication: Baby NAS → Main NAS
# Automatically replicates datasets to Main NAS (10.0.0.89)
###############################################################################

set -e

MAIN_NAS="$MainNasIP"
SSH_KEY="/root/.ssh/id_replication"
TIMESTAMP=\$(date +%Y%m%d-%H%M)
LOG="/var/log/replication.log"

echo "=== ZFS Replication to Main NAS ===" | tee -a \$LOG
echo "Time: \$(date)" | tee -a \$LOG
echo "" | tee -a \$LOG

# Function: Replicate dataset
replicate_dataset() {
    local SOURCE=\$1
    local TARGET=\$2

    echo "Replicating: \$SOURCE → \$TARGET" | tee -a \$LOG

    # Check if source exists
    if ! zfs list \$SOURCE &>/dev/null; then
        echo "  ⚠ Source dataset not found, skipping" | tee -a \$LOG
        return 0
    fi

    # Create snapshot
    zfs snapshot -r \${SOURCE}@auto-\${TIMESTAMP}
    echo "  • Created snapshot: \${SOURCE}@auto-\${TIMESTAMP}" | tee -a \$LOG

    # Get latest local snapshot
    LATEST=\$(zfs list -H -o name -t snapshot -r \$SOURCE | grep "@auto-" | tail -1)

    if [ -z "\$LATEST" ]; then
        echo "  ✗ No snapshots found" | tee -a \$LOG
        return 1
    fi

    # Get latest remote snapshot
    REMOTE=\$(ssh -i \$SSH_KEY root@\$MAIN_NAS "zfs list -H -o name -t snapshot -r \$TARGET 2>/dev/null | grep '@auto-' | tail -1" || echo "")

    if [ -z "\$REMOTE" ]; then
        # Full send (first replication)
        echo "  • Full send: \$LATEST" | tee -a \$LOG
        zfs send -R \$LATEST | ssh -i \$SSH_KEY root@\$MAIN_NAS "zfs receive -F \$TARGET"
        echo "  ✓ Full replication complete" | tee -a \$LOG
    else
        # Incremental send
        REMOTE_SNAP=\$(basename \$REMOTE)
        LOCAL_SNAP=\$(basename \$LATEST)

        if [ "\$REMOTE_SNAP" = "\$LOCAL_SNAP" ]; then
            echo "  • Already synchronized" | tee -a \$LOG
            return 0
        fi

        echo "  • Incremental: \$REMOTE_SNAP → \$LOCAL_SNAP" | tee -a \$LOG

        # Extract date from snapshot names
        REMOTE_DATE=\${REMOTE_SNAP#*-}
        LOCAL_DATE=\${LOCAL_SNAP#*-}

        # Find common snapshot
        if zfs list -H -o name -t snapshot -r \$SOURCE | grep -q "@\$REMOTE_SNAP"; then
            # Incremental from remote snapshot
            zfs send -R -I \$SOURCE@\$REMOTE_SNAP \$LATEST | ssh -i \$SSH_KEY root@\$MAIN_NAS "zfs receive -F \$TARGET"
            echo "  ✓ Incremental replication complete" | tee -a \$LOG
        else
            echo "  ⚠ Common snapshot not found, doing full send" | tee -a \$LOG
            zfs send -R \$LATEST | ssh -i \$SSH_KEY root@\$MAIN_NAS "zfs receive -F \$TARGET"
        fi
    fi
}

# Replicate datasets
echo "Starting replication..." | tee -a \$LOG
replicate_dataset "tank/windows-backups" "backup/babynas/windows-backups"
replicate_dataset "tank/veeam" "backup/babynas/veeam"

# Cleanup old snapshots (keep last 7 days)
echo "" | tee -a \$LOG
echo "Cleaning up old snapshots..." | tee -a \$LOG
CUTOFF=\$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d)

for snap in \$(zfs list -H -o name -t snapshot -r tank | grep "@auto-"); do
    SNAP_DATE=\$(echo \$snap | grep -oP '(?<=@auto-)\d{8}' || echo "99999999")
    if [ "\$SNAP_DATE" -lt "\$CUTOFF" ]; then
        echo "  • Deleting: \$snap" | tee -a \$LOG
        zfs destroy \$snap || echo "  ⚠ Failed to delete \$snap" | tee -a \$LOG
    fi
done

echo "" | tee -a \$LOG
echo "=== Replication Complete ===" | tee -a \$LOG
echo "Time: \$(date)" | tee -a \$LOG
echo "" | tee -a \$LOG
"@

Write-Host "Uploading replication script to Baby NAS..." -ForegroundColor Cyan
$replicationScript | ssh -i "$env:USERPROFILE\.ssh\id_babynas" root@$BabyNasIP "cat > /root/replicate-to-main.sh && chmod +x /root/replicate-to-main.sh"

Write-Host "✓ Replication script created" -ForegroundColor Green

###############################################################################
# Step 7: Test Initial Replication
###############################################################################
Write-Host ""
Write-Host "=== Testing Initial Replication ===" -ForegroundColor Green

$testRepl = Read-Host "Run test replication now? This will create snapshots and send data. (yes/no)"

if ($testRepl -eq "yes") {
    Write-Host "Running initial replication (this may take several minutes)..." -ForegroundColor Cyan
    ssh -i "$env:USERPROFILE\.ssh\id_babynas" root@$BabyNasIP "/root/replicate-to-main.sh"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Initial replication successful!" -ForegroundColor Green
    } else {
        Write-Host "⚠ Replication had issues - check log" -ForegroundColor Yellow
    }

    # Show replication status
    Write-Host ""
    Write-Host "Verifying on Main NAS..." -ForegroundColor Cyan
    if (Test-Path $MainNasSSHKey) {
        ssh -i $MainNasSSHKey root@$MainNasIP "zfs list -r backup/babynas"
    } else {
        ssh root@$MainNasIP "zfs list -r backup/babynas"
    }
}

###############################################################################
# Step 8: Schedule Automatic Replication
###############################################################################
Write-Host ""
Write-Host "=== Scheduling Automatic Replication ===" -ForegroundColor Green

$cronSchedule = "30 2 * * * /root/replicate-to-main.sh >> /var/log/replication.log 2>&1"

$scheduleCmd = @"
# Add replication cron job
(crontab -l 2>/dev/null | grep -v 'replicate-to-main.sh'; echo '$cronSchedule') | crontab -
echo '✓ Cron job scheduled: Daily at 2:30 AM'

# Show crontab
echo ''
echo 'Current crontab:'
crontab -l | grep -v '^#' || echo 'No cron jobs'
"@

$schedule = Read-Host "Schedule automatic replication (daily at 2:30 AM)? (yes/no)"

if ($schedule -eq "yes") {
    Write-Host "Scheduling on Baby NAS..." -ForegroundColor Cyan
    $scheduleCmd | ssh -i "$env:USERPROFILE\.ssh\id_babynas" root@$BabyNasIP "bash"
    Write-Host "✓ Replication scheduled" -ForegroundColor Green
}

###############################################################################
# Step 9: Create Monitoring Script
###############################################################################
Write-Host ""
Write-Host "=== Creating Replication Monitor Script ===" -ForegroundColor Green

$monitorScript = @"
#!/bin/bash
###############################################################################
# Replication Health Monitor
# Checks Baby NAS → Main NAS replication status
###############################################################################

MAIN_NAS="$MainNasIP"
SSH_KEY="/root/.ssh/id_replication"

echo "=== Replication Health Check ==="
echo "Time: \$(date)"
echo ""

# Check pool health - Baby NAS
echo "Baby NAS Pool Health:"
zpool status tank | grep -A 5 "state:"
echo ""

# Check pool health - Main NAS
echo "Main NAS Pool Health:"
ssh -i \$SSH_KEY root@\$MAIN_NAS "zpool status backup | grep -A 5 'state:'"
echo ""

# Check latest snapshots
echo "Latest Snapshots:"
echo "  Baby NAS:"
for ds in tank/windows-backups tank/veeam; do
    LATEST=\$(zfs list -H -o name -t snapshot -r \$ds 2>/dev/null | grep "@auto-" | tail -1 | sed 's/.*@/    @/')
    echo "    \$ds: \$LATEST"
done

echo "  Main NAS:"
for ds in backup/babynas/windows-backups backup/babynas/veeam; do
    LATEST=\$(ssh -i \$SSH_KEY root@\$MAIN_NAS "zfs list -H -o name -t snapshot -r \$ds 2>/dev/null | grep '@auto-' | tail -1 | sed 's/.*@/@/'")
    echo "    \$ds: \$LATEST"
done

echo ""

# Check replication lag
echo "Replication Status:"
BABY_SNAP=\$(zfs list -H -o name -t snapshot -r tank/windows-backups | grep "@auto-" | tail -1)
MAIN_SNAP=\$(ssh -i \$SSH_KEY root@\$MAIN_NAS "zfs list -H -o name -t snapshot -r backup/babynas/windows-backups | grep '@auto-' | tail -1")

BABY_NAME=\$(basename "\$BABY_SNAP")
MAIN_NAME=\$(basename "\$MAIN_SNAP")

if [ "\$BABY_NAME" = "\$MAIN_NAME" ]; then
    echo "  ✓ Synchronized (no lag)"
else
    echo "  ⚠ Lag detected:"
    echo "    Baby: \$BABY_NAME"
    echo "    Main: \$MAIN_NAME"
fi

echo ""
echo "=== Health Check Complete ==="
"@

Write-Host "Creating monitor script on Baby NAS..." -ForegroundColor Cyan
$monitorScript | ssh -i "$env:USERPROFILE\.ssh\id_babynas" root@$BabyNasIP "cat > /root/check-replication.sh && chmod +x /root/check-replication.sh"

Write-Host "✓ Monitor script created" -ForegroundColor Green

###############################################################################
# Summary
###############################################################################
Write-Host ""
Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║           Replication Setup Complete!                                    ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host ""
Write-Host "Replication Configuration:" -ForegroundColor Yellow
Write-Host "  Source: Baby NAS ($BabyNasIP)" -ForegroundColor White
Write-Host "  Target: Main NAS ($MainNasIP)" -ForegroundColor White
Write-Host "  Method: ZFS send/receive over SSH" -ForegroundColor White
Write-Host "  Schedule: Daily at 2:30 AM" -ForegroundColor White
Write-Host "  Retention: 7 days of auto snapshots" -ForegroundColor White
Write-Host ""

Write-Host "Management Commands:" -ForegroundColor Yellow
Write-Host "  Manual replication:" -ForegroundColor Cyan
Write-Host "    ssh -i ~/.ssh/id_babynas root@$BabyNasIP '/root/replicate-to-main.sh'" -ForegroundColor White
Write-Host ""
Write-Host "  Check status:" -ForegroundColor Cyan
Write-Host "    ssh -i ~/.ssh/id_babynas root@$BabyNasIP '/root/check-replication.sh'" -ForegroundColor White
Write-Host ""
Write-Host "  View logs:" -ForegroundColor Cyan
Write-Host "    ssh -i ~/.ssh/id_babynas root@$BabyNasIP 'tail -f /var/log/replication.log'" -ForegroundColor White
Write-Host ""

Write-Host "✓ Replication pipeline is ready!" -ForegroundColor Green
Write-Host ""
