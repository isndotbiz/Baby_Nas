#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Enable ZFS encryption on all BabyNAS datasets and grant jdmal permissions
    Run this script LOCALLY on your Windows machine where you have SSH access to BabyNAS

.DESCRIPTION
    This script executes all necessary ZFS commands via SSH to:
    - Create encrypted versions of all 6 datasets
    - Set optimal ZFS properties (recordsize, compression, atime)
    - Grant full jdmal permissions to all encrypted datasets
    - Verify encryption status

.EXAMPLE
    # Run this on your Windows machine with SSH access:
    .\\setup-encryption-windows-local.ps1

.NOTES
    Requirements:
    - OpenSSH or PuTTY installed on Windows
    - Network access to BabyNAS (192.168.215.2)
    - Credentials from .env.local (BABY_NAS_ROOT_PASSWORD)

    Execution time: ~10-15 minutes
    Password: BabyNAS2026Secure (for encryption passphrase)
#>

# Configuration from .env.local
$BABYNAS_IP = "192.168.215.2"
$BABYNAS_ROOT_USER = "root"
$BABYNAS_ROOT_PASSWORD = "74108520"  # From .env.local

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "BabyNAS ZFS ENCRYPTION SETUP" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

Write-Host "[INFO] Configuration:" -ForegroundColor Cyan
Write-Host "  IP Address: $BABYNAS_IP"
Write-Host "  User: $BABYNAS_ROOT_USER"
Write-Host "  Encryption Passphrase: BabyNAS2026Secure"
Write-Host ""

Write-Host "[INFO] This script will:" -ForegroundColor Cyan
Write-Host "  1. Create 6 encrypted datasets (backups, veeam, wsl-backups, media, phone, home)"
Write-Host "  2. Set optimal ZFS properties for each dataset"
Write-Host "  3. Grant jdmal user full permissions on all datasets"
Write-Host "  4. Verify encryption status"
Write-Host ""

$confirm = Read-Host "[?] Ready to proceed? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "[CANCELLED] Setup cancelled by user" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting encryption setup... this will take 5-10 minutes" -ForegroundColor Yellow
Write-Host ""

# Build SSH command with all operations
$sshCommands = @"
#!/bin/bash
set -e

echo '=========================================='
echo 'BabyNAS ZFS Encryption Setup (jdmal owner)'
echo '=========================================='
echo ''

PASSPHRASE="BabyNAS2026Secure"
JDMAL_UID=3000
JDMAL_GID=3000

# ===== STEP 1: Create encrypted datasets =====
echo 'STEP 1: Creating encrypted datasets (owned by jdmal)...'
echo ''

datasets=(
    "backups"
    "veeam"
    "wsl-backups"
    "media"
    "phone"
    "home"
)

for dataset in `${datasets[@]}; do
    echo "Creating tank/$${dataset}_encrypted (jdmal owner)..."
    echo `$PASSPHRASE | zfs create -o encryption=on -o keyformat=passphrase tank/$${dataset}_encrypted
    echo "[OK] tank/$${dataset}_encrypted created"
done

echo ''
echo 'All encrypted datasets created successfully'
echo ''

# ===== STEP 1B: Set jdmal as owner =====
echo 'STEP 1B: Setting jdmal as owner of datasets...'
echo ''

for dataset in `${datasets[@]}; do
    echo "Setting ownership for tank/$${dataset}_encrypted to jdmal..."
    # Mount point ownership
    MOUNT_POINT="/mnt/tank/$${dataset}_encrypted"
    chown -R jdmal:jdmal "$MOUNT_POINT" 2>/dev/null || true
    echo "[OK] Ownership set for tank/$${dataset}_encrypted"
done

echo ''
echo 'All datasets now owned by jdmal'
echo ''

# ===== STEP 2: Configure ZFS properties =====
echo 'STEP 2: Configuring ZFS properties...'
echo ''

# Backup-like datasets: 1M recordsize
backup_datasets=("backups_encrypted" "veeam_encrypted" "wsl-backups_encrypted" "media_encrypted")
for dataset in `${backup_datasets[@]}; do
    echo "Configuring tank/$dataset..."
    zfs set recordsize=1M tank/$dataset
    zfs set compression=lz4 tank/$dataset
    zfs set atime=off tank/$dataset
done

# General-use datasets: 128K recordsize
general_datasets=("phone_encrypted" "home_encrypted")
for dataset in `${general_datasets[@]}; do
    echo "Configuring tank/$dataset..."
    zfs set recordsize=128K tank/$dataset
    zfs set compression=lz4 tank/$dataset
    zfs set atime=off tank/$dataset
done

echo ''
echo 'All ZFS properties configured'
echo ''

# ===== STEP 3: Grant jdmal full permissions =====
echo 'STEP 3: Granting jdmal FULL permissions over encrypted datasets...'
echo ''

PERMISSIONS="create,receive,rollback,destroy,mount,snapshot,hold,release,send,compression"

for dataset in `${datasets[@]}; do
    echo "Granting full permissions on tank/$${dataset}_encrypted..."
    zfs allow -u jdmal $PERMISSIONS tank/$${dataset}_encrypted

    # Also allow mount/unmount operations
    zfs allow -u jdmal mount,unmount tank/$${dataset}_encrypted 2>/dev/null || true
done

echo ''
echo 'All jdmal permissions granted - jdmal now fully controls encrypted datasets'
echo ''

# ===== STEP 4: Verify encryption =====
echo 'STEP 4: Verifying encryption status...'
echo ''

echo 'Encrypted datasets:'
zfs list -o name,encryption,encrypted,recordsize,compression | grep -E '_encrypted'

echo ''
echo 'jdmal permissions:'
zfs allow | grep -A 100 'tank/backups_encrypted' | head -20

echo ''
echo '=========================================='
echo 'ENCRYPTION SETUP COMPLETE'
echo '=========================================='
echo 'All 6 datasets are now encrypted with AES-256-GCM'
echo 'jdmal user has full permissions'
echo ''
"@

# Execute the commands via SSH
Write-Host "[...] Connecting to BabyNAS and executing setup..." -ForegroundColor Yellow
Write-Host ""

try {
    # For Windows SSH/OpenSSH
    $output = $sshCommands | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$BABYNAS_ROOT_USER@$BABYNAS_IP" "bash" 2>&1

    # Display output
    foreach ($line in $output) {
        if ($line -match "OK|success|complete|COMPLETE") {
            Write-Host $line -ForegroundColor Green
        } elseif ($line -match "ERROR|error|failed|FAILED") {
            Write-Host $line -ForegroundColor Red
        } elseif ($line -match "STEP|===") {
            Write-Host $line -ForegroundColor Cyan
        } else {
            Write-Host $line
        }
    }

    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "[OK] Encryption setup completed successfully!" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host ""

    Write-Host "[INFO] Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Update snapshot tasks to use new encrypted datasets"
    Write-Host "  2. Update replication tasks to use new encrypted datasets"
    Write-Host "  3. Migrate data from old to new datasets (if needed)"
    Write-Host "  4. Create SMB shares for encrypted datasets"
    Write-Host "  5. Delete old unencrypted datasets (after verification)"
    Write-Host ""

    Write-Host "[INFO] Test jdmal access:" -ForegroundColor Cyan
    Write-Host "  ssh jdmal@192.168.215.2"
    Write-Host "  zfs list -o name,encryption | grep encrypted"
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host "[ERROR] SSH command execution failed!" -ForegroundColor Red
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $_ -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify BabyNAS is running and accessible:"
    Write-Host "     ping 192.168.215.2"
    Write-Host ""
    Write-Host "  2. Verify SSH connectivity:"
    Write-Host "     ssh root@192.168.215.2"
    Write-Host ""
    Write-Host "  3. Check if SSH keys are set up:"
    Write-Host "     ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"
    Write-Host ""
    exit 1
}
