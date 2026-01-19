#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# BabyNAS Storage Configuration Script
# Run on BabyNAS via SSH as root
# ═══════════════════════════════════════════════════════════════

set -e

echo "═══════════════════════════════════════════════════════════════"
echo " BabyNAS Storage Configuration"
echo "═══════════════════════════════════════════════════════════════"

# Color helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
err() { echo -e "${RED}✗ $1${NC}"; }
info() { echo -e "  ℹ $1"; }

# ═══════════════════════════════════════════════════════════════
# STEP 1: Identify Disks
# ═══════════════════════════════════════════════════════════════

echo ""
echo "STEP 1: Identifying available disks..."
echo ""

# List all disks
echo "Available disks by ID:"
ls -la /dev/disk/by-id/ | grep -E "ata-|nvme-|scsi-" | grep -v part

echo ""
echo "Disk information:"
lsblk -d -o NAME,SIZE,MODEL,SERIAL

echo ""
warn "IMPORTANT: Identify your HDDs (6TB) and SSDs (~256GB) from the list above"
echo "Update the variables below before running the configuration steps"
echo ""

# ═══════════════════════════════════════════════════════════════
# CONFIGURATION - UPDATE THESE VALUES
# ═══════════════════════════════════════════════════════════════

# Example disk IDs - REPLACE WITH YOUR ACTUAL DISK IDs
HDD1="/dev/disk/by-id/ata-REPLACE_WITH_HDD1_ID"
HDD2="/dev/disk/by-id/ata-REPLACE_WITH_HDD2_ID"
HDD3="/dev/disk/by-id/ata-REPLACE_WITH_HDD3_ID"
SSD1="/dev/disk/by-id/ata-REPLACE_WITH_SSD1_ID"
SSD2="/dev/disk/by-id/ata-REPLACE_WITH_SSD2_ID"

# ═══════════════════════════════════════════════════════════════
# STEP 2: Create RAIDZ1 Pool (Manual - uncomment to run)
# ═══════════════════════════════════════════════════════════════

create_pool() {
    echo ""
    echo "STEP 2: Creating RAIDZ1 pool..."

    if zpool list tank &>/dev/null; then
        warn "Pool 'tank' already exists"
        zpool status tank
        return 0
    fi

    zpool create -o ashift=12 \
      -O compression=lz4 \
      -O atime=off \
      -O xattr=sa \
      -O dnodesize=auto \
      -O normalization=formD \
      -O aclinherit=passthrough \
      -O acltype=posixacl \
      tank raidz1 "$HDD1" "$HDD2" "$HDD3"

    ok "Pool 'tank' created"
    zpool status tank
}

# ═══════════════════════════════════════════════════════════════
# STEP 3: Partition SSDs for SLOG + L2ARC
# ═══════════════════════════════════════════════════════════════

partition_ssds() {
    echo ""
    echo "STEP 3: Partitioning SSDs..."

    # SSD1
    echo "Partitioning SSD1..."
    sgdisk -Z "$SSD1" 2>/dev/null || true
    sgdisk -n 1:0:+16G -t 1:bf01 -c 1:"slog1" "$SSD1"
    sgdisk -n 2:0:0 -t 2:bf01 -c 2:"l2arc1" "$SSD1"
    ok "SSD1 partitioned"

    # SSD2
    echo "Partitioning SSD2..."
    sgdisk -Z "$SSD2" 2>/dev/null || true
    sgdisk -n 1:0:+16G -t 1:bf01 -c 1:"slog2" "$SSD2"
    sgdisk -n 2:0:0 -t 2:bf01 -c 2:"l2arc2" "$SSD2"
    ok "SSD2 partitioned"

    # Refresh partition table
    partprobe
    sleep 2
}

# ═══════════════════════════════════════════════════════════════
# STEP 4: Add SLOG and L2ARC to pool
# ═══════════════════════════════════════════════════════════════

add_ssd_vdevs() {
    echo ""
    echo "STEP 4: Adding SLOG and L2ARC..."

    # Add mirrored SLOG
    echo "Adding mirrored SLOG..."
    zpool add tank log mirror "${SSD1}-part1" "${SSD2}-part1"
    ok "SLOG added (mirrored)"

    # Add L2ARC (striped for capacity)
    echo "Adding L2ARC..."
    zpool add tank cache "${SSD1}-part2" "${SSD2}-part2"
    ok "L2ARC added"

    echo ""
    echo "Pool configuration:"
    zpool status tank
}

# ═══════════════════════════════════════════════════════════════
# STEP 5: Create Datasets
# ═══════════════════════════════════════════════════════════════

create_datasets() {
    echo ""
    echo "STEP 5: Creating datasets..."

    # Veeam (large sequential writes)
    if ! zfs list tank/veeam &>/dev/null; then
        zfs create -o recordsize=1M \
          -o compression=lz4 \
          -o atime=off \
          -o primarycache=metadata \
          -o quota=4T \
          tank/veeam
        ok "Created tank/veeam"
    else
        info "tank/veeam already exists"
    fi

    # Backups
    if ! zfs list tank/backups &>/dev/null; then
        zfs create -o recordsize=1M \
          -o compression=lz4 \
          -o atime=off \
          -o primarycache=metadata \
          -o quota=4T \
          tank/backups
        ok "Created tank/backups"
    else
        info "tank/backups already exists"
    fi

    # WSL Backups
    if ! zfs list tank/wsl-backups &>/dev/null; then
        zfs create -o recordsize=1M \
          -o compression=lz4 \
          -o atime=off \
          -o quota=500G \
          tank/wsl-backups
        ok "Created tank/wsl-backups"
    else
        info "tank/wsl-backups already exists"
    fi

    # Phone Backups (mixed file sizes)
    if ! zfs list tank/phone &>/dev/null; then
        zfs create -o recordsize=128K \
          -o compression=lz4 \
          -o atime=off \
          -o quota=500G \
          tank/phone
        ok "Created tank/phone"
    else
        info "tank/phone already exists"
    fi

    # Media
    if ! zfs list tank/media &>/dev/null; then
        zfs create -o recordsize=1M \
          -o compression=lz4 \
          -o atime=off \
          -o quota=2T \
          tank/media
        ok "Created tank/media"
    else
        info "tank/media already exists"
    fi

    echo ""
    echo "Dataset configuration:"
    zfs list -o name,used,avail,refer,quota,recordsize,compression tank -r
}

# ═══════════════════════════════════════════════════════════════
# STEP 6: Configure ARC/L2ARC Tuning
# ═══════════════════════════════════════════════════════════════

configure_arc() {
    echo ""
    echo "STEP 6: Configuring ARC/L2ARC tuning..."

    # Get total RAM
    TOTAL_RAM=$(free -b | awk '/^Mem:/{print $2}')
    ARC_MAX=$((TOTAL_RAM / 2))
    ARC_MIN=$((TOTAL_RAM / 4))

    echo "Total RAM: $((TOTAL_RAM / 1024 / 1024 / 1024)) GB"
    echo "Setting ARC max to: $((ARC_MAX / 1024 / 1024 / 1024)) GB"

    # Create/update ZFS module config
    cat > /etc/modprobe.d/zfs.conf << EOF
# BabyNAS ZFS Tuning
# ARC limits (50% of RAM)
options zfs zfs_arc_max=$ARC_MAX
options zfs zfs_arc_min=$ARC_MIN

# L2ARC write speed (100MB/s max, 200MB/s boost)
options zfs l2arc_write_max=104857600
options zfs l2arc_write_boost=209715200
options zfs l2arc_headroom=8
EOF

    # Apply immediately
    echo $ARC_MAX > /sys/module/zfs/parameters/zfs_arc_max 2>/dev/null || true
    echo 104857600 > /sys/module/zfs/parameters/l2arc_write_max 2>/dev/null || true

    ok "ARC/L2ARC tuning configured"
}

# ═══════════════════════════════════════════════════════════════
# STEP 7: Generate Replication SSH Key
# ═══════════════════════════════════════════════════════════════

generate_ssh_key() {
    echo ""
    echo "STEP 7: Generating SSH key for replication..."

    if [ -f /root/.ssh/id_ed25519_replication ]; then
        warn "Replication key already exists"
    else
        ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519_replication -N "" -C "baby-nas-replication"
        ok "SSH key generated"
    fi

    echo ""
    echo "Public key (add to Main NAS baby-nas user):"
    echo "═══════════════════════════════════════════════════════════════"
    cat /root/.ssh/id_ed25519_replication.pub
    echo "═══════════════════════════════════════════════════════════════"
}

# ═══════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════

show_menu() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo " BabyNAS Storage Configuration Menu"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  1) List disks (identify HDDs and SSDs)"
    echo "  2) Create RAIDZ1 pool"
    echo "  3) Partition SSDs"
    echo "  4) Add SLOG + L2ARC to pool"
    echo "  5) Create datasets"
    echo "  6) Configure ARC tuning"
    echo "  7) Generate replication SSH key"
    echo "  8) Run all steps (2-7)"
    echo "  9) Show current status"
    echo "  0) Exit"
    echo ""
}

show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo " Current Status"
    echo "═══════════════════════════════════════════════════════════════"

    echo ""
    echo "Pool Status:"
    zpool status tank 2>/dev/null || echo "No pool named 'tank' found"

    echo ""
    echo "Dataset Status:"
    zfs list -r tank 2>/dev/null || echo "No datasets found"

    echo ""
    echo "ARC Status:"
    arc_summary 2>/dev/null | head -20 || cat /proc/spl/kstat/zfs/arcstats | grep -E "^size|^c_max" | head -5
}

run_all() {
    echo "Running full configuration..."
    create_pool
    partition_ssds
    add_ssd_vdevs
    create_datasets
    configure_arc
    generate_ssh_key
    echo ""
    ok "Full configuration complete!"
    show_status
}

# ═══════════════════════════════════════════════════════════════
# Entry Point
# ═══════════════════════════════════════════════════════════════

if [ "$1" == "--auto" ]; then
    run_all
    exit 0
fi

while true; do
    show_menu
    read -p "Select option: " choice

    case $choice in
        1) ls -la /dev/disk/by-id/ | grep -E "ata-|nvme-" | grep -v part; lsblk -d -o NAME,SIZE,MODEL ;;
        2) create_pool ;;
        3) partition_ssds ;;
        4) add_ssd_vdevs ;;
        5) create_datasets ;;
        6) configure_arc ;;
        7) generate_ssh_key ;;
        8) run_all ;;
        9) show_status ;;
        0) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
done
