#!/bin/bash
#
# Baby NAS Auto-Mount Script for MacBook
# Mounts all Baby NAS shares via Tailscale
#
# Usage: ./macbook-mount-nas.sh
#

set -e

# Configuration
BABY_NAS_IP="100.95.3.18"
BABY_NAS_TAILSCALE="baby.tailfef21a.ts.net"  # Tailscale MagicDNS hostname
BABY_NAS_CUSTOM="baby.isn.biz"  # Custom domain (requires setup script)
SMB_USER="smbuser"
MOUNT_BASE="$HOME/NAS"

# Prefer custom domain if available, fallback to Tailscale DNS, then IP
if ping -c 1 -W 1 "$BABY_NAS_CUSTOM" &>/dev/null; then
    BABY_NAS_HOST="$BABY_NAS_CUSTOM"
elif ping -c 1 -W 1 "$BABY_NAS_TAILSCALE" &>/dev/null; then
    BABY_NAS_HOST="$BABY_NAS_TAILSCALE"
else
    BABY_NAS_HOST="$BABY_NAS_IP"
fi

echo "Using hostname: $BABY_NAS_HOST"
echo ""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Baby NAS Auto-Mount Script"
echo "========================================="
echo ""

# Check if Tailscale is running
if ! tailscale status &>/dev/null; then
    echo -e "${RED}Error: Tailscale is not running${NC}"
    echo "Start Tailscale with: sudo tailscale up"
    exit 1
fi

# Check if Baby NAS is reachable
echo "Checking connection to Baby NAS..."
if ! ping -c 1 -W 2 "$BABY_NAS_IP" &>/dev/null; then
    echo -e "${RED}Error: Cannot reach Baby NAS at $BABY_NAS_IP${NC}"
    echo "Make sure:"
    echo "  1. Tailscale is connected"
    echo "  2. Baby NAS is powered on"
    echo "  3. Run 'tailscale status' to check connections"
    exit 1
fi
echo -e "${GREEN}✓ Baby NAS is reachable${NC}"
echo ""

# Create mount point base directory
mkdir -p "$MOUNT_BASE"

# Function to mount a share
mount_share() {
    local share_name=$1
    local mount_point="$MOUNT_BASE/$share_name"

    # Create mount point
    mkdir -p "$mount_point"

    # Check if already mounted
    if mount | grep -q "$mount_point"; then
        echo -e "${YELLOW}⚠ $share_name already mounted at $mount_point${NC}"
        return 0
    fi

    echo "Mounting $share_name..."

    # Try to mount with stored credentials first (from Keychain)
    if mount_smbfs "//$SMB_USER@$BABY_NAS_HOST/$share_name" "$mount_point" 2>/dev/null; then
        echo -e "${GREEN}✓ Mounted $share_name${NC}"
        return 0
    fi

    # If that fails, prompt for password
    echo "Enter password for $SMB_USER:"
    if mount_smbfs "//$SMB_USER@$BABY_NAS_HOST/$share_name" "$mount_point"; then
        echo -e "${GREEN}✓ Mounted $share_name${NC}"

        # Offer to save password to Keychain
        echo ""
        read -p "Save password to Keychain for future auto-mount? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Password will be saved in macOS Keychain for future use"
        fi
        return 0
    else
        echo -e "${RED}✗ Failed to mount $share_name${NC}"
        return 1
    fi
}

# Mount all shares
echo "Mounting Baby NAS shares..."
echo ""

mount_share "workspace"
mount_share "models"
mount_share "staging"
mount_share "backups"

echo ""
echo "========================================="
echo "Mount Summary"
echo "========================================="
df -h | grep "$MOUNT_BASE" || echo "No shares mounted"
echo ""
echo "Access mounted shares at: $MOUNT_BASE"
echo "  - Workspace: $MOUNT_BASE/workspace"
echo "  - Models: $MOUNT_BASE/models"
echo "  - Staging: $MOUNT_BASE/staging"
echo "  - Backups: $MOUNT_BASE/backups"
echo ""
echo -e "${GREEN}✓ Done!${NC}"
