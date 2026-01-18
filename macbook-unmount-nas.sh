#!/bin/bash
#
# Baby NAS Unmount Script for MacBook
# Unmounts all Baby NAS shares
#
# Usage: ./macbook-unmount-nas.sh
#

MOUNT_BASE="$HOME/NAS"

echo "Unmounting Baby NAS shares..."

# Unmount all shares in the NAS directory
for share in workspace models staging backups; do
    mount_point="$MOUNT_BASE/$share"
    if mount | grep -q "$mount_point"; then
        echo "Unmounting $share..."
        umount "$mount_point" && echo "✓ Unmounted $share" || echo "✗ Failed to unmount $share"
    fi
done

echo ""
echo "✓ Done!"
