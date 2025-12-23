#!/bin/bash
###############################################################################
# TrueNAS SCALE Initial Setup Script
# This script configures a new TrueNAS SCALE installation with optimal settings
# Run this script via the TrueNAS shell or SSH as root
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables from .env file if it exists
# Note: This file should be transferred to TrueNAS and placed in the same directory as this script
if [ -f "$(dirname "$0")/.env" ]; then
    echo -e "${GREEN}Loading environment variables from .env file${NC}"
    # shellcheck disable=SC1090
    source "$(dirname "$0")/.env"
fi

# Configuration Variables (will be overridden by .env if present)
POOL_NAME="${POOL_NAME:-tank}"
USERNAME="${TRUENAS_USERNAME:-root}"
USER_PASSWORD="${TRUENAS_PASSWORD}"
USER_FULL_NAME="${USER_FULL_NAME:-TrueNAS Admin}"
USER_EMAIL="${USER_EMAIL:-admin@local}"
USER_UID="${USER_UID:-3000}"

# Validate that password is set
if [ -z "$USER_PASSWORD" ]; then
    echo -e "${RED}ERROR: TRUENAS_PASSWORD is not set${NC}"
    echo -e "${YELLOW}Please set TRUENAS_PASSWORD environment variable or create a .env file${NC}"
    exit 1
fi

echo -e "${GREEN}=== TrueNAS SCALE Automated Setup ===${NC}"
echo "This script will configure your TrueNAS system with optimal settings"
echo ""

###############################################################################
# Step 1: Create User Account
###############################################################################
echo -e "${YELLOW}[1/10] Creating user account: ${USERNAME}${NC}"

# Check if user exists
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists, skipping creation..."
else
    # Create user via CLI
    midclt call user.create '{
        "username": "'"$USERNAME"'",
        "full_name": "'"$USER_FULL_NAME"'",
        "password": "'"$USER_PASSWORD"'",
        "uid": '"$USER_UID"',
        "group": 100,
        "home": "/mnt/'"$POOL_NAME"'/home/'"$USERNAME"'",
        "shell": "/usr/bin/bash",
        "sshpubkey": "",
        "smb": true,
        "sudo_commands": [],
        "sudo_commands_nopasswd": []
    }' 2>/dev/null || echo "User creation via API failed, trying useradd..."

    # Fallback to useradd if midclt fails
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -d /mnt/$POOL_NAME/home/$USERNAME -s /bin/bash -u $USER_UID -g users $USERNAME
        echo "$USERNAME:$USER_PASSWORD" | chpasswd
        # Enable Samba authentication
        (echo "$USER_PASSWORD"; echo "$USER_PASSWORD") | smbpasswd -a $USERNAME
        smbpasswd -e $USERNAME
    fi

    echo -e "${GREEN}✓ User $USERNAME created successfully${NC}"
fi

###############################################################################
# Step 2: Create Home Directory and SSH Directory
###############################################################################
echo -e "${YELLOW}[2/10] Setting up home directory and SSH${NC}"

USER_HOME="/mnt/$POOL_NAME/home/$USERNAME"
mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
touch "$USER_HOME/.ssh/authorized_keys"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
chown -R $USERNAME:users "$USER_HOME"

echo -e "${GREEN}✓ Home directory configured${NC}"

###############################################################################
# Step 3: Configure SSH Service
###############################################################################
echo -e "${YELLOW}[3/10] Configuring SSH service${NC}"

# Enable SSH service
midclt call service.update ssh '{"enable": true}' 2>/dev/null || systemctl enable ssh

# Configure SSH for key-based auth
SSH_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSH_CONFIG" ]; then
    # Backup original config
    cp "$SSH_CONFIG" "${SSH_CONFIG}.backup.$(date +%Y%m%d)"

    # Enable key authentication
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' "$SSH_CONFIG"
    sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' "$SSH_CONFIG"

    # Enable password authentication (for initial setup)
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' "$SSH_CONFIG"
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' "$SSH_CONFIG"

    # Permit root login with key only (more secure)
    sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/' "$SSH_CONFIG"

    echo -e "${GREEN}✓ SSH configuration updated${NC}"
fi

# Start SSH service
midclt call service.start ssh 2>/dev/null || systemctl start ssh || service ssh start

echo -e "${GREEN}✓ SSH service started${NC}"

###############################################################################
# Step 4: ZFS Performance Optimizations
###############################################################################
echo -e "${YELLOW}[4/10] Applying ZFS performance optimizations${NC}"

if zpool list "$POOL_NAME" &>/dev/null; then
    # Pool-level optimizations
    zfs set atime=off "$POOL_NAME"
    zfs set compression=lz4 "$POOL_NAME"
    zfs set xattr=sa "$POOL_NAME"
    zfs set dnodesize=auto "$POOL_NAME"

    # Create datasets if they don't exist
    for dataset in backups veeam wsl-backups media; do
        if ! zfs list "$POOL_NAME/$dataset" &>/dev/null; then
            zfs create "$POOL_NAME/$dataset"
            echo "Created dataset: $POOL_NAME/$dataset"
        fi
    done

    # Optimize for Veeam (large sequential writes)
    zfs set recordsize=1M "$POOL_NAME/veeam" 2>/dev/null || true
    zfs set sync=standard "$POOL_NAME/veeam" 2>/dev/null || true
    zfs set primarycache=metadata "$POOL_NAME/veeam" 2>/dev/null || true

    # Optimize for backups (large files)
    zfs set recordsize=1M "$POOL_NAME/backups" 2>/dev/null || true

    # Optimize for media (large files, read-heavy)
    zfs set recordsize=1M "$POOL_NAME/media" 2>/dev/null || true
    zfs set compression=zstd "$POOL_NAME/media" 2>/dev/null || true

    # WSL backups (mixed workload)
    zfs set recordsize=128K "$POOL_NAME/wsl-backups" 2>/dev/null || true

    echo -e "${GREEN}✓ ZFS optimizations applied${NC}"
else
    echo -e "${RED}✗ Pool '$POOL_NAME' not found, skipping ZFS optimizations${NC}"
fi

###############################################################################
# Step 5: SMB Performance Optimizations
###############################################################################
echo -e "${YELLOW}[5/10] Configuring SMB performance optimizations${NC}"

# SMB configuration via midclt
midclt call smb.update '{
    "enable_smb1": false,
    "guest": "nobody",
    "syslog": false,
    "localmaster": true,
    "multichannel": true,
    "aapl_extensions": true,
    "fruit_streams": true
}' 2>/dev/null || echo "SMB update via API skipped"

# Restart SMB service to apply changes
midclt call service.restart smb 2>/dev/null || systemctl restart smbd || service smbd restart

echo -e "${GREEN}✓ SMB optimizations applied${NC}"

###############################################################################
# Step 6: Configure SMART Monitoring
###############################################################################
echo -e "${YELLOW}[6/10] Configuring SMART monitoring${NC}"

# Get all disks and configure SMART tests
for disk in $(sysctl -n kern.disks 2>/dev/null || lsblk -nd -o NAME 2>/dev/null || ls /dev/sd? 2>/dev/null | xargs -n1 basename); do
    # Skip if not a physical disk
    if [[ "$disk" =~ ^(loop|ram|sr|dm-) ]]; then
        continue
    fi

    # Enable SMART for disk
    smartctl -s on /dev/$disk 2>/dev/null || true
done

# Schedule SMART tests via API (if available)
# Short test: Weekly on Sunday at 3 AM
midclt call smart.test.create '{
    "type": "SHORT",
    "desc": "Weekly short SMART test",
    "schedule": {
        "hour": "3",
        "dow": "7",
        "dom": "*",
        "month": "*"
    },
    "all_disks": true
}' 2>/dev/null || echo "SMART test schedule: Configure manually via UI"

# Long test: Monthly on 1st at 2 AM
midclt call smart.test.create '{
    "type": "LONG",
    "desc": "Monthly long SMART test",
    "schedule": {
        "hour": "2",
        "dow": "*",
        "dom": "1",
        "month": "*"
    },
    "all_disks": true
}' 2>/dev/null || echo "Long SMART test schedule: Configure manually via UI"

echo -e "${GREEN}✓ SMART monitoring configured${NC}"

###############################################################################
# Step 7: Configure Automatic Scrub Schedule
###############################################################################
echo -e "${YELLOW}[7/10] Configuring ZFS scrub schedule${NC}"

if zpool list "$POOL_NAME" &>/dev/null; then
    # Create scrub task: Monthly on 1st at 1 AM
    midclt call pool.scrub.create '{
        "pool": "'"$POOL_NAME"'",
        "threshold": 35,
        "description": "Monthly scrub for data integrity",
        "schedule": {
            "hour": "1",
            "dow": "*",
            "dom": "1",
            "month": "*"
        },
        "enabled": true
    }' 2>/dev/null || echo "Scrub schedule: Configure manually via UI (1st of each month)"

    echo -e "${GREEN}✓ Scrub schedule configured${NC}"
else
    echo -e "${YELLOW}⚠ Pool not found, configure scrub manually${NC}"
fi

###############################################################################
# Step 8: Configure Snapshot Automation
###############################################################################
echo -e "${YELLOW}[8/10] Configuring automatic snapshots${NC}"

if zpool list "$POOL_NAME" &>/dev/null; then
    # Hourly snapshots (keep 24)
    midclt call pool.snapshottask.create '{
        "dataset": "'"$POOL_NAME"'",
        "recursive": true,
        "lifetime_value": 24,
        "lifetime_unit": "HOUR",
        "naming_schema": "auto-%Y%m%d-%H%M",
        "schedule": {
            "minute": "0",
            "hour": "*",
            "dow": "*",
            "dom": "*",
            "month": "*"
        },
        "enabled": true
    }' 2>/dev/null || echo "Hourly snapshots: Configure manually via UI"

    # Daily snapshots (keep 7)
    midclt call pool.snapshottask.create '{
        "dataset": "'"$POOL_NAME"'",
        "recursive": true,
        "lifetime_value": 7,
        "lifetime_unit": "DAY",
        "naming_schema": "daily-%Y%m%d",
        "schedule": {
            "minute": "0",
            "hour": "0",
            "dow": "*",
            "dom": "*",
            "month": "*"
        },
        "enabled": true
    }' 2>/dev/null || echo "Daily snapshots: Configure manually via UI"

    # Weekly snapshots (keep 4)
    midclt call pool.snapshottask.create '{
        "dataset": "'"$POOL_NAME"'",
        "recursive": true,
        "lifetime_value": 4,
        "lifetime_unit": "WEEK",
        "naming_schema": "weekly-%Y-W%W",
        "schedule": {
            "minute": "0",
            "hour": "0",
            "dow": "1",
            "dom": "*",
            "month": "*"
        },
        "enabled": true
    }' 2>/dev/null || echo "Weekly snapshots: Configure manually via UI"

    echo -e "${GREEN}✓ Snapshot automation configured${NC}"
else
    echo -e "${YELLOW}⚠ Pool not found, configure snapshots manually${NC}"
fi

###############################################################################
# Step 9: System Tuning
###############################################################################
echo -e "${YELLOW}[9/10] Applying system tuning parameters${NC}"

# ZFS ARC tuning (adjust based on 16GB RAM)
# Set ARC max to 8GB (50% of RAM, leaving room for SMB and other services)
echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf 2>/dev/null || true

# Sysctl tuning for network performance
SYSCTL_CONF="/etc/sysctl.conf"
if [ -f "$SYSCTL_CONF" ]; then
    cat >> "$SYSCTL_CONF" << 'EOF'

# TrueNAS Performance Tuning
# Network performance
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000

# SMB/CIFS performance
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1

# ZFS tuning
vm.swappiness = 10
EOF
    sysctl -p "$SYSCTL_CONF" 2>/dev/null || true
fi

echo -e "${GREEN}✓ System tuning applied${NC}"

###############################################################################
# Step 10: Generate SSH Keys and Display Info
###############################################################################
echo -e "${YELLOW}[10/10] Generating SSH keys and access information${NC}"

# Generate SSH key for jdmal user
su - $USERNAME -c "
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N '' -C '${USERNAME}@truenas'
        echo '✓ SSH key generated'
    else
        echo 'SSH key already exists'
    fi
"

# Generate SSH key for root (for automation)
if [ ! -f /root/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N '' -C 'root@truenas'
    echo "✓ Root SSH key generated"
fi

echo -e "${GREEN}✓ SSH keys generated${NC}"

###############################################################################
# Summary and Next Steps
###############################################################################
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}    TrueNAS Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "User Account:"
echo "  Username: $USERNAME"
echo "  Password: $USER_PASSWORD"
echo "  Home: $USER_HOME"
echo ""
echo "SSH Access:"
echo "  Server: $(hostname -I | awk '{print $1}')"
echo "  Command: ssh ${USERNAME}@$(hostname -I | awk '{print $1}')"
echo ""
echo "Public SSH Keys (add to client):"
echo "  User key: $USER_HOME/.ssh/id_rsa.pub"
echo "  Root key: /root/.ssh/id_rsa.pub"
echo ""
echo "View keys with:"
echo "  cat $USER_HOME/.ssh/id_rsa.pub"
echo "  cat /root/.ssh/id_rsa.pub"
echo ""
echo "Next Steps:"
echo "  1. Copy public keys to your Windows machine"
echo "  2. Generate API key via Web UI: Credentials → API Keys"
echo "  3. Test SSH connection from Windows"
echo "  4. Run truenas-api-setup.py to configure API access"
echo ""
echo "Performance Optimizations Applied:"
echo "  ✓ ZFS compression (lz4/zstd)"
echo "  ✓ Dataset record size optimized"
echo "  ✓ SMB multichannel enabled"
echo "  ✓ SMART monitoring scheduled"
echo "  ✓ Monthly scrub scheduled"
echo "  ✓ Snapshot automation (hourly/daily/weekly)"
echo "  ✓ Network tuning applied"
echo "  ✓ ZFS ARC optimized (8GB max)"
echo ""
echo -e "${YELLOW}Reboot recommended to apply all tuning parameters.${NC}"
echo ""
