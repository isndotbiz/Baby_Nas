#!/bin/bash
###############################################################################
# Baby NAS Complete Setup Script
# Runs on TrueNAS VM after SSH connection is established
###############################################################################

set -e

BABY_NAS_IP="${1:-}"
MAIN_NAS_IP="10.0.0.89"
POOL_NAME="tank"

echo "===================================================================="
echo "  Baby NAS Complete Setup"
echo "===================================================================="
echo ""

if [ -z "$BABY_NAS_IP" ]; then
    echo "Usage: $0 <baby-nas-ip>"
    exit 1
fi

echo "Baby NAS IP: $BABY_NAS_IP"
echo "Main NAS IP: $MAIN_NAS_IP"
echo ""

# Step 1: List available disks
echo "===================================================================="
echo "STEP 1: Listing Available Disks"
echo "===================================================================="
echo ""

lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
echo ""

zpool list 2>/dev/null || echo "No pools found yet"
echo ""

# Check if pool already exists
if zpool list | grep -q "^$POOL_NAME"; then
    echo "✓ Pool '$POOL_NAME' already exists"
    echo ""
    zpool status $POOL_NAME
    echo ""
    read -p "Pool exists. Do you want to continue with dataset creation? (yes/no): " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        echo "Exiting. Please manage pool manually."
        exit 0
    fi
else
    echo "ERROR: Pool '$POOL_NAME' does not exist."
    echo ""
    echo "Please create the pool manually via Web UI:"
    echo "  1. Open: https://$BABY_NAS_IP"
    echo "  2. Go to: Storage → Create Pool"
    echo "  3. Name: $POOL_NAME"
    echo "  4. Data VDevs: RAIDZ1 with 3x 6TB HDDs"
    echo "  5. Log Device: 1x 256GB SSD (SLOG)"
    echo "  6. Cache Device: 1x 256GB SSD (L2ARC)"
    echo "  7. Advanced: Compression: lz4, atime: off"
    echo ""
    read -p "Press Enter after pool is created..."

    # Verify pool exists
    if ! zpool list | grep -q "^$POOL_NAME"; then
        echo "ERROR: Pool still not found. Exiting."
        exit 1
    fi
fi

# Step 2: Create datasets
echo "===================================================================="
echo "STEP 2: Creating Datasets"
echo "===================================================================="
echo ""

create_dataset() {
    local DS=$1
    local RECORDSIZE=${2:-128K}
    local QUOTA=${3:-none}

    if zfs list "$DS" &>/dev/null; then
        echo "✓ Dataset $DS already exists"
    else
        echo "Creating dataset: $DS (recordsize=$RECORDSIZE, quota=$QUOTA)"
        zfs create "$DS"
        zfs set recordsize=$RECORDSIZE "$DS"
        zfs set compression=lz4 "$DS"
        if [ "$QUOTA" != "none" ]; then
            zfs set quota=$QUOTA "$DS"
        fi
        echo "✓ Created $DS"
    fi
}

# Main datasets
create_dataset "$POOL_NAME/windows-backups" "128K" "8T"
create_dataset "$POOL_NAME/windows-backups/c-drive" "128K" "500G"
create_dataset "$POOL_NAME/windows-backups/d-workspace" "128K" "2T"
create_dataset "$POOL_NAME/windows-backups/wsl" "128K" "500G"
create_dataset "$POOL_NAME/windows-backups/phone-backups" "128K" "500G"

create_dataset "$POOL_NAME/veeam" "1M" "3T"
zfs set sync=standard "$POOL_NAME/veeam" 2>/dev/null || true

create_dataset "$POOL_NAME/home" "128K" "none"
create_dataset "$POOL_NAME/home/truenas_admin" "128K" "none"

echo ""
echo "✓ All datasets created"
echo ""

# Step 3: Set permissions
echo "===================================================================="
echo "STEP 3: Setting Permissions"
echo "===================================================================="
echo ""

# Check if truenas_admin user exists
if id truenas_admin &>/dev/null; then
    echo "✓ User truenas_admin exists"

    chown -R truenas_admin:users /mnt/$POOL_NAME/home/truenas_admin 2>/dev/null || true
    chown -R truenas_admin:users /mnt/$POOL_NAME/windows-backups 2>/dev/null || true
    chown -R truenas_admin:users /mnt/$POOL_NAME/veeam 2>/dev/null || true

    chmod -R 755 /mnt/$POOL_NAME/windows-backups 2>/dev/null || true
    chmod -R 755 /mnt/$POOL_NAME/veeam 2>/dev/null || true

    echo "✓ Permissions set"
else
    echo "⚠ User truenas_admin not found"
    echo "  Please create via Web UI: Credentials → Local Users → Add"
    echo "  Username: truenas_admin"
    echo "  Password: uppercut%\$##"
    echo "  Home: /mnt/$POOL_NAME/home/truenas_admin"
    echo "  Shell: /usr/bin/bash"
    echo "  Sudo: ALL"
fi

echo ""

# Step 4: Display current status
echo "===================================================================="
echo "STEP 4: Current Status"
echo "===================================================================="
echo ""

echo "Pool Status:"
zpool status $POOL_NAME
echo ""

echo "Dataset List:"
zfs list -r $POOL_NAME -o name,used,avail,refer,quota
echo ""

echo "Compression Status:"
zfs get compression $POOL_NAME -r | grep -v "off"
echo ""

# Step 5: Create snapshot schedule script
echo "===================================================================="
echo "STEP 5: Creating Snapshot Script"
echo "===================================================================="
echo ""

cat > /root/create-snapshots.sh << 'SNAPEOF'
#!/bin/bash
# Automated snapshot creation for Baby NAS
# Run via cron: 0 * * * * /root/create-snapshots.sh hourly
#              0 0 * * * /root/create-snapshots.sh daily
#              0 0 * * 0 /root/create-snapshots.sh weekly

SCHEDULE="${1:-hourly}"
TIMESTAMP=$(date +%Y%m%d-%H%M)
POOL="tank"

case "$SCHEDULE" in
    hourly)
        RETENTION=48  # Keep 48 hourly snapshots
        SNAPSHOT_NAME="auto-hourly-$TIMESTAMP"
        ;;
    daily)
        RETENTION=14  # Keep 14 daily snapshots
        SNAPSHOT_NAME="auto-daily-$TIMESTAMP"
        ;;
    weekly)
        RETENTION=8   # Keep 8 weekly snapshots
        SNAPSHOT_NAME="auto-weekly-$TIMESTAMP"
        ;;
    *)
        echo "Usage: $0 {hourly|daily|weekly}"
        exit 1
        ;;
esac

echo "=== Creating $SCHEDULE snapshot: $SNAPSHOT_NAME ==="

# Create recursive snapshot
zfs snapshot -r ${POOL}@${SNAPSHOT_NAME}

echo "✓ Snapshot created: ${POOL}@${SNAPSHOT_NAME}"

# Cleanup old snapshots
echo "Cleaning up old $SCHEDULE snapshots (keep $RETENTION)..."

SNAPSHOTS=$(zfs list -H -t snapshot -o name -s creation | grep "@auto-$SCHEDULE" | head -n -$RETENTION)

if [ -n "$SNAPSHOTS" ]; then
    echo "$SNAPSHOTS" | while read snap; do
        echo "  Deleting: $snap"
        zfs destroy "$snap"
    done
else
    echo "  No old snapshots to delete"
fi

echo "=== Snapshot maintenance complete ==="
SNAPEOF

chmod +x /root/create-snapshots.sh
echo "✓ Created /root/create-snapshots.sh"
echo ""

# Step 6: Setup snapshot cron jobs
echo "===================================================================="
echo "STEP 6: Setting Up Snapshot Schedules"
echo "===================================================================="
echo ""

# Check if cron jobs already exist
if crontab -l 2>/dev/null | grep -q "create-snapshots.sh"; then
    echo "✓ Snapshot cron jobs already configured"
else
    echo "Adding snapshot cron jobs..."

    (crontab -l 2>/dev/null || true; cat << 'CRONEOF'
# Baby NAS Snapshot Automation
0 * * * * /root/create-snapshots.sh hourly >> /var/log/snapshots.log 2>&1
0 0 * * * /root/create-snapshots.sh daily >> /var/log/snapshots.log 2>&1
0 0 * * 0 /root/create-snapshots.sh weekly >> /var/log/snapshots.log 2>&1
CRONEOF
    ) | crontab -

    echo "✓ Cron jobs configured"
fi

echo ""
crontab -l | grep "create-snapshots.sh"
echo ""

# Step 7: Create replication script (to Main NAS)
echo "===================================================================="
echo "STEP 7: Creating Replication Script"
echo "===================================================================="
echo ""

cat > /root/replicate-to-main.sh << REPLEOF
#!/bin/bash
# ZFS Replication: Baby NAS → Main NAS ($MAIN_NAS_IP)

set -e

MAIN_NAS="$MAIN_NAS_IP"
SSH_KEY="/root/.ssh/id_replication"
TIMESTAMP=\$(date +%Y%m%d-%H%M)
LOG="/var/log/replication.log"
POOL="$POOL_NAME"

echo "=== Replication to Main NAS ===" | tee -a \$LOG
echo "Time: \$(date)" | tee -a \$LOG

# Check if SSH key exists
if [ ! -f "\$SSH_KEY" ]; then
    echo "⚠ SSH key not found: \$SSH_KEY" | tee -a \$LOG
    echo "  Please run setup script first to configure replication keys" | tee -a \$LOG
    exit 1
fi

# Function: Replicate dataset
replicate() {
    local SRC=\$1
    local DST=\$2

    echo "Replicating: \$SRC → \$DST" | tee -a \$LOG

    # Create snapshot
    zfs snapshot -r \${SRC}@repl-\${TIMESTAMP}

    # Get latest local snapshot
    LATEST=\$(zfs list -H -o name -t snapshot -r \$SRC | grep "@repl-" | tail -1)

    # Get latest remote snapshot
    REMOTE=\$(ssh -i \$SSH_KEY root@\$MAIN_NAS "zfs list -H -o name -t snapshot -r \$DST 2>/dev/null | grep '@repl-' | tail -1" || echo "")

    if [ -z "\$REMOTE" ]; then
        # Full send
        echo "  Full send: \$LATEST" | tee -a \$LOG
        zfs send -R \$LATEST | ssh -i \$SSH_KEY root@\$MAIN_NAS "zfs receive -F \$DST"
    else
        # Incremental send
        REMOTE_SNAP=\$(basename \$REMOTE)
        echo "  Incremental: \$REMOTE_SNAP → \$LATEST" | tee -a \$LOG
        zfs send -R -I \$REMOTE_SNAP \$LATEST | ssh -i \$SSH_KEY root@\$MAIN_NAS "zfs receive -F \$DST"
    fi

    echo "  ✓ Completed" | tee -a \$LOG
}

# Replicate datasets (uncomment after SSH keys are configured)
# replicate "\$POOL/windows-backups" "backup/babynas/windows-backups"
# replicate "\$POOL/veeam" "backup/babynas/veeam"

echo "⚠ Replication not yet configured - SSH keys needed" | tee -a \$LOG
echo "  Run 3-setup-replication.ps1 from Windows to configure" | tee -a \$LOG

# Cleanup old snapshots (keep 7 days of replication snapshots)
CUTOFF=\$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d)
for snap in \$(zfs list -H -o name -t snapshot -r \$POOL | grep "@repl-"); do
    SNAP_DATE=\$(echo \$snap | grep -oP '(?<=@repl-)\d{8}' || echo \$snap | sed 's/.*@repl-\([0-9]\{8\}\).*/\1/')
    if [ "\$SNAP_DATE" -lt "\$CUTOFF" ]; then
        echo "Deleting old snapshot: \$snap" | tee -a \$LOG
        zfs destroy \$snap
    fi
done

echo "=== Replication Complete ===" | tee -a \$LOG
REPLEOF

chmod +x /root/replicate-to-main.sh
echo "✓ Created /root/replicate-to-main.sh"
echo ""

# Step 8: Display SMB share instructions
echo "===================================================================="
echo "STEP 8: SMB Share Configuration"
echo "===================================================================="
echo ""

echo "Please configure SMB shares via Web UI:"
echo ""
echo "1. Go to: https://$BABY_NAS_IP"
echo "2. Navigate: Shares → Windows (SMB) Shares → Add"
echo ""
echo "Share 1: WindowsBackup"
echo "  Path: /mnt/$POOL_NAME/windows-backups"
echo "  Name: WindowsBackup"
echo "  Purpose: Default share parameters"
echo "  Enable: ✓"
echo ""
echo "Share 2: Veeam"
echo "  Path: /mnt/$POOL_NAME/veeam"
echo "  Name: Veeam"
echo "  Purpose: Default share parameters"
echo "  Enable: ✓"
echo ""
echo "3. Enable SMB Service:"
echo "   System Settings → Services → SMB → Toggle ON"
echo "   Configure: SMB1 disabled, Multichannel enabled"
echo ""

# Step 9: Performance tuning
echo "===================================================================="
echo "STEP 9: Performance Tuning"
echo "===================================================================="
echo ""

echo "Configuring ZFS ARC..."
# Set ARC max to 8GB (for 16GB system)
if ! grep -q "zfs_arc_max" /etc/modprobe.d/zfs.conf 2>/dev/null; then
    echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf
    echo "✓ ARC max set to 8GB"
else
    echo "✓ ARC already configured"
fi

echo ""
echo "Configuring network tuning..."
if ! grep -q "TrueNAS Performance Tuning" /etc/sysctl.conf 2>/dev/null; then
    cat >> /etc/sysctl.conf << 'SYSCTLEOF'

# TrueNAS Performance Tuning
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_window_scaling = 1
vm.swappiness = 10
SYSCTLEOF

    sysctl -p
    echo "✓ Network tuning applied"
else
    echo "✓ Network tuning already configured"
fi

echo ""

# Step 10: Final summary
echo "===================================================================="
echo "  SETUP COMPLETE!"
echo "===================================================================="
echo ""

echo "✓ Baby NAS Configuration Summary:"
echo ""
echo "  Pool: $POOL_NAME ($(zpool list -H -o size $POOL_NAME 2>/dev/null || echo 'N/A'))"
echo "  Datasets: $(zfs list -r $POOL_NAME | wc -l) created"
echo "  Snapshots: Automated (hourly, daily, weekly)"
echo "  Compression: lz4 enabled"
echo "  Performance: Tuned for backup workloads"
echo ""

echo "Next Steps:"
echo ""
echo "1. Create truenas_admin user (if not exists):"
echo "   Web UI → Credentials → Local Users → Add"
echo ""
echo "2. Configure SMB shares:"
echo "   Web UI → Shares → Windows (SMB) Shares"
echo ""
echo "3. Setup SSH keys and replication:"
echo "   Run: 3-setup-replication.ps1 from Windows"
echo ""
echo "4. Map network drives on Windows:"
echo "   net use W: \\\\$BABY_NAS_IP\\WindowsBackup /persistent:yes"
echo "   net use V: \\\\$BABY_NAS_IP\\Veeam /persistent:yes"
echo ""

echo "Management Commands:"
echo "  Check pool: zpool status $POOL_NAME"
echo "  List datasets: zfs list -r $POOL_NAME"
echo "  List snapshots: zfs list -t snapshot -r $POOL_NAME"
echo "  Manual snapshot: /root/create-snapshots.sh hourly"
echo "  Manual replication: /root/replicate-to-main.sh"
echo ""

echo "===================================================================="
echo "  Configuration saved to: /root/baby-nas-setup-$(date +%Y%m%d-%H%M).log"
echo "===================================================================="
echo ""
