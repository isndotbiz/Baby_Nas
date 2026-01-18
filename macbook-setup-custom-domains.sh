#!/bin/bash
#
# Baby NAS Custom Domain Setup for MacBook
# Adds custom *.isn.biz domains for Baby NAS services
#
# This creates local DNS entries so you can use friendly names like:
#   - baby.isn.biz (general access)
#   - workspace.isn.biz (workspace share)
#   - timemachine.isn.biz (Time Machine)
#   - models.isn.biz (model archive)
#
# Usage: sudo ./macbook-setup-custom-domains.sh
#

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

BABY_NAS_IP="100.95.3.18"
HOSTS_FILE="/etc/hosts"
BACKUP_FILE="/etc/hosts.backup.$(date +%Y%m%d_%H%M%S)"

echo "========================================="
echo "Baby NAS Custom Domain Setup"
echo "========================================="
echo ""

# Backup current hosts file
echo "Backing up current /etc/hosts to $BACKUP_FILE"
cp "$HOSTS_FILE" "$BACKUP_FILE"

# Check if entries already exist
if grep -q "# Baby NAS Tailscale Custom Domains" "$HOSTS_FILE"; then
    echo "Baby NAS entries already exist in /etc/hosts"
    read -p "Remove and re-add? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove old entries
        sed -i.bak '/# Baby NAS Tailscale Custom Domains/,/# End Baby NAS/d' "$HOSTS_FILE"
        echo "Removed old entries"
    else
        echo "Skipping..."
        exit 0
    fi
fi

# Add custom domain entries
echo ""
echo "Adding custom domain entries to /etc/hosts..."

cat >> "$HOSTS_FILE" << EOF

# Baby NAS Tailscale Custom Domains (Added $(date))
# Tailscale IP: $BABY_NAS_IP
$BABY_NAS_IP    baby.isn.biz babynas.isn.biz
$BABY_NAS_IP    workspace.isn.biz
$BABY_NAS_IP    models.isn.biz
$BABY_NAS_IP    staging.isn.biz
$BABY_NAS_IP    backups.isn.biz
$BABY_NAS_IP    timemachine.isn.biz
# End Baby NAS

EOF

echo "✓ Custom domains added successfully!"
echo ""
echo "========================================="
echo "Available Hostnames"
echo "========================================="
echo "  baby.isn.biz          - General access"
echo "  babynas.isn.biz       - Alternate name"
echo "  workspace.isn.biz     - Workspace share"
echo "  models.isn.biz        - Models share"
echo "  staging.isn.biz       - Staging share"
echo "  backups.isn.biz       - Backups share"
echo "  timemachine.isn.biz   - Time Machine"
echo ""
echo "Test with: ping baby.isn.biz"
echo ""
echo "You can now mount shares using:"
echo "  smb://workspace.isn.biz/workspace"
echo "  smb://timemachine.isn.biz/timemachine"
echo ""
echo "Backup saved to: $BACKUP_FILE"
echo "========================================="
