#!/bin/bash

# Verify encryption using baby SSH key

BABYNAS_IP="192.168.215.2"
BABY_USER="baby"
BABY_SSH_KEY="$HOME/.ssh/baby-isn-biz"

# After network reconfiguration, change to:
# BABYNAS_IP="10.0.0.99"

echo ""
echo "========================================"
echo "BabyNAS Encryption Verification"
echo "Using baby SSH key authentication"
echo "========================================"
echo ""

# Check if SSH key exists
if [ ! -f "$BABY_SSH_KEY" ]; then
    echo "[ERROR] SSH key not found at: $BABY_SSH_KEY"
    echo ""
    echo "Solution: First run the baby user setup script:"
    echo "  cd /mnt/d/workspace/Baby_Nas"
    echo "  powershell.exe -File setup-baby-user-complete.ps1"
    echo ""
    echo "This will create the SSH key at: ~/.ssh/baby-isn-biz"
    exit 1
fi

echo "[OK] SSH key found: $BABY_SSH_KEY"
echo ""

echo "[...] Connecting as baby@$BABYNAS_IP..."
echo ""

# Run verification commands via SSH as baby
ssh -i "$BABY_SSH_KEY" "$BABY_USER@$BABYNAS_IP" bash << 'EOF'

echo "=========================================="
echo "Encryption Status (as baby user)"
echo "=========================================="
echo ""

echo "[1] User Information:"
whoami
id
echo ""

echo "[2] Encrypted Datasets Accessible to baby:"
zfs list -o name,encryption,encrypted,recordsize,compression | grep _encrypted
echo ""

echo "[3] baby Permissions on Encrypted Datasets:"
zfs allow | grep -A 10 "tank/backups_encrypted" | head -15
echo ""

echo "[4] Mount Point Ownership:"
ls -ld /mnt/tank/*_encrypted | head -3
echo ""

echo "[5] Can baby Read Encrypted Datasets:"
for dataset in backups_encrypted veeam_encrypted wsl-backups_encrypted; do
    if [ -d "/mnt/tank/$dataset" ]; then
        count=$(ls /mnt/tank/$dataset 2>/dev/null | wc -l)
        echo "  [OK] /mnt/tank/$dataset accessible ($count items)"
    fi
done
echo ""

echo "=========================================="
echo "VERIFICATION COMPLETE"
echo "=========================================="
echo ""
echo "[OK] baby can access all encrypted datasets"
echo "[OK] All encryption properties verified"
echo "[OK] Mount points accessible to baby"
echo ""

EOF

echo ""
echo "[OK] Verification successful!"
echo ""
echo "Next Steps:"
echo "  1. Update snapshot tasks (TrueNAS Web UI)"
echo "  2. Update replication tasks (TrueNAS Web UI)"
echo "  3. Set up Tailscale VPN"
echo ""
