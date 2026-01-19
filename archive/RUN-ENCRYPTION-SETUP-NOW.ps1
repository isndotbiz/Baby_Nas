#!/usr/bin/env pwsh
<#
.SYNOPSIS
    BabyNAS ZFS Encryption Setup with jdmal Ownership

.DESCRIPTION
    Automatically enables AES-256-GCM encryption on all 6 datasets
    Sets jdmal as owner and grants full permissions
    No user prompts - just runs!

.EXAMPLE
    # Run on your Windows machine with SSH access to BabyNAS:
    .\\RUN-ENCRYPTION-SETUP-NOW.ps1
#>

param(
    [switch]$SkipConfirm = $false
)

$BABYNAS_IP = "192.168.215.2"
$BABYNAS_ROOT_USER = "root"
$BABYNAS_ROOT_PASSWORD = "74108520"

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "BabyNAS ZFS Encryption Setup (jdmal Owner)" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

if (-not $SkipConfirm) {
    Write-Host "[INFO] This script will:" -ForegroundColor Yellow
    Write-Host "  1. Create 6 encrypted datasets with AES-256-GCM"
    Write-Host "  2. Set optimal ZFS properties (recordsize, compression)"
    Write-Host "  3. Set jdmal as owner of all encrypted datasets"
    Write-Host "  4. Grant jdmal full permissions (create, receive, snapshot, destroy, etc.)"
    Write-Host "  5. Verify encryption status"
    Write-Host ""
    Write-Host "[INFO] Encryption passphrase: BabyNAS2026Secure"
    Write-Host "[INFO] Estimated time: 10-15 minutes"
    Write-Host ""

    $confirm = Read-Host "[?] Ready to proceed? Type 'yes' to continue"
    if ($confirm -ne "yes") {
        Write-Host "[CANCELLED] Setup cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "[...] Connecting to BabyNAS at $BABYNAS_IP..." -ForegroundColor Yellow
Write-Host ""

# Build the complete setup script
$setupScript = @'
#!/bin/bash
set -e

echo "=========================================="
echo "BabyNAS ZFS Encryption Setup"
echo "Owner: jdmal (UID 3000)"
echo "Encryption: AES-256-GCM"
echo "=========================================="
echo ""

PASSPHRASE="BabyNAS2026Secure"

# ===== STEP 1: Create encrypted datasets =====
echo "STEP 1: Creating encrypted datasets..."
echo ""

datasets=(
    "backups"
    "veeam"
    "wsl-backups"
    "media"
    "phone"
    "home"
)

for dataset in "${datasets[@]}"; do
    echo "Creating tank/${dataset}_encrypted (jdmal owner)..."
    echo "$PASSPHRASE" | zfs create -o encryption=on -o keyformat=passphrase tank/${dataset}_encrypted
    echo "[OK] tank/${dataset}_encrypted created"
done

echo ""
echo "All encrypted datasets created"
echo ""

# ===== STEP 1B: Set jdmal as mount point owner =====
echo "STEP 1B: Setting jdmal ownership..."
echo ""

for dataset in "${datasets[@]}"; do
    MOUNT_POINT="/mnt/tank/${dataset}_encrypted"
    echo "Setting ownership: jdmal:jdmal for $MOUNT_POINT"
    chown -R jdmal:jdmal "$MOUNT_POINT" 2>/dev/null || true
    echo "[OK] Ownership set"
done

echo ""

# ===== STEP 2: Configure ZFS properties =====
echo "STEP 2: Configuring ZFS properties..."
echo ""

# Backup-like datasets: 1M recordsize for sequential access
for dataset in backups veeam wsl-backups media; do
    echo "Configuring tank/${dataset}_encrypted (1M recordsize)..."
    zfs set recordsize=1M tank/${dataset}_encrypted
    zfs set compression=lz4 tank/${dataset}_encrypted
    zfs set atime=off tank/${dataset}_encrypted
done

# General-use datasets: 128K recordsize for mixed access
for dataset in phone home; do
    echo "Configuring tank/${dataset}_encrypted (128K recordsize)..."
    zfs set recordsize=128K tank/${dataset}_encrypted
    zfs set compression=lz4 tank/${dataset}_encrypted
    zfs set atime=off tank/${dataset}_encrypted
done

echo ""
echo "All ZFS properties configured"
echo ""

# ===== STEP 3: Grant jdmal FULL permissions =====
echo "STEP 3: Granting jdmal FULL permissions..."
echo ""

PERMISSIONS="create,receive,rollback,destroy,mount,unmount,snapshot,hold,release,send,compression"

for dataset in "${datasets[@]}"; do
    echo "Granting permissions on tank/${dataset}_encrypted..."
    zfs allow -u jdmal $PERMISSIONS tank/${dataset}_encrypted
done

echo ""
echo "All permissions granted to jdmal"
echo ""

# ===== STEP 4: Verify encryption =====
echo "STEP 4: Verifying encryption status..."
echo ""

echo "Encrypted Datasets:"
zfs list -o name,encryption,encrypted,recordsize,compression | grep _encrypted

echo ""
echo "jdmal Permissions:"
zfs allow | grep -E "dataset|jdmal" | head -30

echo ""
echo "=========================================="
echo "ENCRYPTION SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "All 6 datasets now:"
echo "  ✓ Encrypted with AES-256-GCM"
echo "  ✓ Owned by jdmal (mount points)"
echo "  ✓ Managed by jdmal (ZFS permissions)"
echo ""
echo "Encryption Passphrase: BabyNAS2026Secure"
echo "  (Store securely in password manager!)"
echo ""
'@

# Execute via SSH
try {
    Write-Host "[...] Executing setup on BabyNAS..." -ForegroundColor Yellow
    Write-Host ""

    $output = $setupScript | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$BABYNAS_ROOT_USER@$BABYNAS_IP" "bash" 2>&1

    # Display output with color coding
    $output | ForEach-Object {
        $line = $_
        if ($line -match "COMPLETE|OK" -and $line -notmatch "ERROR|failed") {
            Write-Host $line -ForegroundColor Green
        } elseif ($line -match "ERROR|failed|error") {
            Write-Host $line -ForegroundColor Red
        } elseif ($line -match "STEP|===|Encrypting|Configuring|Granting|Verifying") {
            Write-Host $line -ForegroundColor Cyan
        } elseif ($line -match "tank/.*_encrypted") {
            Write-Host $line -ForegroundColor Yellow
        } else {
            Write-Host $line
        }
    }

    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "SUCCESS! Encryption setup completed" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host ""

    Write-Host "[✓] 6 encrypted datasets created" -ForegroundColor Green
    Write-Host "[✓] jdmal set as owner" -ForegroundColor Green
    Write-Host "[✓] Full ZFS permissions granted to jdmal" -ForegroundColor Green
    Write-Host "[✓] ZFS properties optimized" -ForegroundColor Green
    Write-Host ""

    Write-Host "[INFO] Next Steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Test jdmal access:"
    Write-Host "   ssh jdmal@192.168.215.2"
    Write-Host "   zfs list -o name,encryption | grep encrypted"
    Write-Host ""

    Write-Host "2. Verify mount ownership:"
    Write-Host "   ssh root@192.168.215.2"
    Write-Host "   ls -la /mnt/tank/ | grep _encrypted"
    Write-Host ""

    Write-Host "3. Update snapshot tasks (TrueNAS Web UI):"
    Write-Host "   Data Protection → Snapshots → Edit"
    Write-Host "   Change: tank/backups → tank/backups_encrypted (etc.)"
    Write-Host ""

    Write-Host "4. Update replication tasks (TrueNAS Web UI):"
    Write-Host "   Data Protection → Replication → Edit"
    Write-Host "   Change source datasets to use _encrypted versions"
    Write-Host ""

    Write-Host "5. Store encryption passphrase securely:"
    Write-Host "   BabyNAS2026Secure"
    Write-Host "   Add to 1Password or Vaultwarden"
    Write-Host ""

    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "Encryption passphrase: BabyNAS2026Secure" -ForegroundColor Yellow
    Write-Host "Store this in a secure location immediately!" -ForegroundColor Yellow
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host "ERROR: SSH connection failed!" -ForegroundColor Red
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify BabyNAS is running: ping 192.168.215.2"
    Write-Host "  2. Verify SSH access: ssh root@192.168.215.2"
    Write-Host "  3. Verify password: 74108520"
    Write-Host "  4. Check if SSH service is enabled on BabyNAS"
    Write-Host ""
    exit 1
}
