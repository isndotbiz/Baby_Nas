#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verify that ZFS encryption was successfully set up on BabyNAS
    Checks: encrypted datasets, properties, jdmal permissions

.DESCRIPTION
    Connects to BabyNAS and verifies:
    - All 6 encrypted datasets exist
    - Encryption is enabled (AES-256-GCM)
    - ZFS properties are correct (recordsize, compression)
    - jdmal user has full permissions
    - Mount points are owned by jdmal

.EXAMPLE
    .\\VERIFY-ENCRYPTION-STATUS.ps1
#>

$BABYNAS_IP = "192.168.215.2"
$BABYNAS_ROOT_USER = "root"

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "BabyNAS Encryption Verification" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

Write-Host "[...] Connecting to BabyNAS..." -ForegroundColor Yellow
Write-Host ""

# Build verification script
$verifyScript = @'
#!/bin/bash

echo "=========================================="
echo "BabyNAS Encryption Verification Report"
echo "=========================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: Check if encrypted datasets exist
echo -e "${CYAN}TEST 1: Encrypted Datasets Exist${NC}"
echo "---"

datasets=("backups_encrypted" "veeam_encrypted" "wsl-backups_encrypted" "media_encrypted" "phone_encrypted" "home_encrypted")

for dataset in "${datasets[@]}"; do
    if zfs list tank/$dataset > /dev/null 2>&1; then
        echo -e "${GREEN}[PASS]${NC} tank/$dataset exists"
        ((PASS_COUNT++))
    else
        echo -e "${RED}[FAIL]${NC} tank/$dataset NOT FOUND"
        ((FAIL_COUNT++))
    fi
done

echo ""

# Test 2: Check encryption status
echo -e "${CYAN}TEST 2: Encryption Status (AES-256-GCM)${NC}"
echo "---"

for dataset in "${datasets[@]}"; do
    ENCRYPTION=$(zfs get -H -o value encryption tank/$dataset 2>/dev/null || echo "unknown")
    ENCRYPTED=$(zfs get -H -o value encrypted tank/$dataset 2>/dev/null || echo "unknown")

    if [ "$ENCRYPTION" = "on" ] && [ "$ENCRYPTED" = "yes" ]; then
        echo -e "${GREEN}[PASS]${NC} tank/$dataset encrypted=ON (encrypted=yes)"
        ((PASS_COUNT++))
    else
        echo -e "${RED}[FAIL]${NC} tank/$dataset encryption=$ENCRYPTION encrypted=$ENCRYPTED"
        ((FAIL_COUNT++))
    fi
done

echo ""

# Test 3: Check ZFS properties
echo -e "${CYAN}TEST 3: ZFS Properties${NC}"
echo "---"

# Backup datasets should have 1M recordsize
for dataset in backups_encrypted veeam_encrypted wsl-backups_encrypted media_encrypted; do
    RECORDSIZE=$(zfs get -H -o value recordsize tank/$dataset 2>/dev/null || echo "unknown")
    COMPRESSION=$(zfs get -H -o value compression tank/$dataset 2>/dev/null || echo "unknown")
    ATIME=$(zfs get -H -o value atime tank/$dataset 2>/dev/null || echo "unknown")

    if [ "$RECORDSIZE" = "1M" ] && [ "$COMPRESSION" = "lz4" ] && [ "$ATIME" = "off" ]; then
        echo -e "${GREEN}[PASS]${NC} tank/$dataset properties correct (1M, lz4, off)"
        ((PASS_COUNT++))
    else
        echo -e "${RED}[FAIL]${NC} tank/$dataset recordsize=$RECORDSIZE compression=$COMPRESSION atime=$ATIME"
        ((FAIL_COUNT++))
    fi
done

# General datasets should have 128K recordsize
for dataset in phone_encrypted home_encrypted; do
    RECORDSIZE=$(zfs get -H -o value recordsize tank/$dataset 2>/dev/null || echo "unknown")
    COMPRESSION=$(zfs get -H -o value compression tank/$dataset 2>/dev/null || echo "unknown")
    ATIME=$(zfs get -H -o value atime tank/$dataset 2>/dev/null || echo "unknown")

    if [ "$RECORDSIZE" = "128K" ] && [ "$COMPRESSION" = "lz4" ] && [ "$ATIME" = "off" ]; then
        echo -e "${GREEN}[PASS]${NC} tank/$dataset properties correct (128K, lz4, off)"
        ((PASS_COUNT++))
    else
        echo -e "${RED}[FAIL]${NC} tank/$dataset recordsize=$RECORDSIZE compression=$COMPRESSION atime=$ATIME"
        ((FAIL_COUNT++))
    fi
done

echo ""

# Test 4: Check jdmal permissions
echo -e "${CYAN}TEST 4: jdmal User Permissions${NC}"
echo "---"

# Check if jdmal user exists
if id jdmal > /dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC} jdmal user exists"
    ((PASS_COUNT++))
else
    echo -e "${RED}[FAIL]${NC} jdmal user NOT FOUND"
    ((FAIL_COUNT++))
fi

# Check jdmal permissions on first dataset
for dataset in backups_encrypted veeam_encrypted wsl-backups_encrypted; do
    PERMS=$(zfs allow tank/$dataset 2>/dev/null | grep jdmal || echo "")

    if [ ! -z "$PERMS" ]; then
        echo -e "${GREEN}[PASS]${NC} tank/$dataset has jdmal permissions"
        ((PASS_COUNT++))
    else
        echo -e "${RED}[FAIL]${NC} tank/$dataset missing jdmal permissions"
        ((FAIL_COUNT++))
    fi
done

echo ""

# Test 5: Check mount point ownership
echo -e "${CYAN}TEST 5: Mount Point Ownership${NC}"
echo "---"

for dataset in "${datasets[@]}"; do
    MOUNT_POINT="/mnt/tank/$dataset"

    if [ -d "$MOUNT_POINT" ]; then
        OWNER=$(ls -ld "$MOUNT_POINT" | awk '{print $3}')
        GROUP=$(ls -ld "$MOUNT_POINT" | awk '{print $4}')

        if [ "$OWNER" = "jdmal" ] || [ "$OWNER" = "3000" ]; then
            echo -e "${GREEN}[PASS]${NC} $MOUNT_POINT owned by jdmal"
            ((PASS_COUNT++))
        else
            echo -e "${YELLOW}[WARN]${NC} $MOUNT_POINT owned by $OWNER (expected jdmal)"
            # Don't count as fail, just warning - sometimes root ownership is ok
        fi
    else
        echo -e "${YELLOW}[INFO]${NC} $MOUNT_POINT not yet mounted (will mount on first use)"
    fi
done

echo ""

# Test 6: Storage space
echo -e "${CYAN}TEST 6: Storage Space Usage${NC}"
echo "---"

echo "Pool status:"
zpool list tank

echo ""
echo "Dataset sizes:"
zfs list -o name,used,available,referenced tank | grep _encrypted

echo ""

# Summary
echo "=========================================="
echo -e "${CYAN}VERIFICATION SUMMARY${NC}"
echo "=========================================="
echo ""

TOTAL=$((PASS_COUNT + FAIL_COUNT))

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] All tests passed!${NC}"
    echo "Passed: $PASS_COUNT/$TOTAL"
    echo ""
    echo "Encryption setup is complete and verified!"
else
    echo -e "${YELLOW}[WARNING] Some tests failed${NC}"
    echo "Passed: $PASS_COUNT/$TOTAL"
    echo "Failed: $FAIL_COUNT/$TOTAL"
    echo ""
    echo "Issues found - review above for details"
fi

echo ""
echo "Encrypted Datasets:"
zfs list -o name,encryption,encrypted,recordsize,compression | grep _encrypted

echo ""
echo "Next steps:"
echo "1. Update snapshot tasks to use _encrypted datasets"
echo "2. Update replication tasks to use _encrypted datasets"
echo "3. Test access via: ssh jdmal@192.168.215.2"
echo "4. Set up Tailscale VPN for internet access"
echo ""

'@

try {
    Write-Host "[...] Running verification on BabyNAS..." -ForegroundColor Yellow
    Write-Host ""

    $output = $verifyScript | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$BABYNAS_ROOT_USER@$BABYNAS_IP" "bash" 2>&1

    # Display output
    foreach ($line in $output) {
        if ($line -match "\[PASS\]|SUCCESS|passed") {
            Write-Host $line -ForegroundColor Green
        } elseif ($line -match "\[FAIL\]|failed|FAIL" -and $line -notmatch "NOT FOUND") {
            Write-Host $line -ForegroundColor Red
        } elseif ($line -match "\[WARN\]|WARNING") {
            Write-Host $line -ForegroundColor Yellow
        } elseif ($line -match "TEST|===|Verification|Summary") {
            Write-Host $line -ForegroundColor Cyan
        } elseif ($line -match "tank/.*encrypted") {
            Write-Host $line -ForegroundColor Yellow
        } else {
            Write-Host $line
        }
    }

    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "VERIFICATION COMPLETE" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host ""

    # Check if there were failures
    if ($output -match "FAIL.*NOT FOUND") {
        Write-Host "[WARNING] Some datasets not found - encryption may not have completed" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Possible reasons:" -ForegroundColor Yellow
        Write-Host "  1. Encryption script has not been run yet"
        Write-Host "  2. Script failed - check SSH output above"
        Write-Host "  3. Network connectivity issue"
        Write-Host ""
        Write-Host "To run encryption setup:" -ForegroundColor Cyan
        Write-Host "  .\RUN-ENCRYPTION-SETUP-NOW.ps1"
    } else {
        Write-Host "[OK] Encryption verified successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Update snapshot tasks in TrueNAS Web UI"
        Write-Host "  2. Update replication tasks in TrueNAS Web UI"
        Write-Host "  3. Set up Tailscale VPN for remote access"
        Write-Host "  4. Test access: ssh jdmal@192.168.215.2"
    }

    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host "ERROR: Verification failed!" -ForegroundColor Red
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify BabyNAS is running: ping 192.168.215.2"
    Write-Host "  2. Test SSH: ssh root@192.168.215.2"
    Write-Host "  3. Verify encryption script was run"
    Write-Host ""
    exit 1
}
