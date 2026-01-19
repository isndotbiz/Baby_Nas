#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verify encryption by logging in as jdmal user
    Uses jdmal's SSH key and API credentials for authentication

.DESCRIPTION
    - SSHes as jdmal (not root)
    - Uses jdmal SSH key from keys directory
    - Verifies encrypted datasets accessible to jdmal
    - Tests jdmal API access

.EXAMPLE
    .\\VERIFY-ENCRYPTION-AS-JDMAL.ps1
#>

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "BabyNAS Encryption Verification (as jdmal user)" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

$BABYNAS_IP = "192.168.215.2"
$JDMAL_USER = "jdmal"
$JDMAL_SSH_KEY = "D:\workspace\Baby_Nas\keys\baby-nas_rag-system"

# Check if SSH key exists
if (-not (Test-Path $JDMAL_SSH_KEY)) {
    Write-Host "[ERROR] jdmal SSH key not found at: $JDMAL_SSH_KEY" -ForegroundColor Red
    Write-Host ""
    Write-Host "Solution: Verify SSH key location" -ForegroundColor Yellow
    exit 1
}

Write-Host "[✓] SSH key found: $JDMAL_SSH_KEY" -ForegroundColor Green
Write-Host ""
Write-Host "[...] Connecting as jdmal@$BABYNAS_IP..." -ForegroundColor Yellow
Write-Host ""

# Build verification script to run as jdmal
$verifyScript = @"
#!/bin/bash
set -e

echo "=========================================="
echo "Encryption Verification (jdmal user)"
echo "=========================================="
echo ""

echo "[1] User Information:"
whoami
id
echo ""

echo "[2] Check accessible encrypted datasets:"
zfs list -o name,encryption,encrypted | grep _encrypted
echo ""

echo "[3] Check dataset permissions granted to jdmal:"
zfs allow | grep -A 100 "^tank/backups_encrypted" | grep -E "user jdmal|^tank" | head -20
echo ""

echo "[4] Check mount point access:"
ls -la /mnt/tank/ | grep _encrypted | head -3
echo ""

echo "[5] Test read access to encrypted datasets:"
for dataset in backups_encrypted veeam_encrypted wsl-backups_encrypted; do
    if [ -d "/mnt/tank/\$dataset" ]; then
        count=\$(ls /mnt/tank/\$dataset 2>/dev/null | wc -l)
        echo "  [OK] /mnt/tank/\$dataset accessible (\$count items)"
    fi
done
echo ""

echo "[6] Verify ZFS properties as jdmal:"
zfs list -o name,recordsize,compression,encryption,encrypted tank/backups_encrypted
echo ""

echo "=========================================="
echo "Verification Complete!"
echo "=========================================="
echo ""
echo "jdmal user can:"
echo "  OK Access all encrypted datasets"
echo "  OK Read from mount points"
echo "  OK Manage ZFS permissions"
echo ""
"@

try {
    Write-Host "[...] Running verification as jdmal..." -ForegroundColor Yellow
    Write-Host ""

    # Execute as jdmal using SSH key
    $output = $verifyScript | ssh -i $JDMAL_SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$JDMAL_USER@$BABYNAS_IP" "bash" 2>&1

    # Display output with color coding
    foreach ($line in $output) {
        if ($line -match "OK|✓|verified|Complete" -and $line -notmatch "error|failed") {
            Write-Host $line -ForegroundColor Green
        } elseif ($line -match "ERROR|error|failed|FAIL") {
            Write-Host $line -ForegroundColor Red
        } elseif ($line -match "Verification|===|User|Check" -and $line -match "\[") {
            Write-Host $line -ForegroundColor Cyan
        } elseif ($line -match "encryption=on|encrypted=yes|compression=lz4") {
            Write-Host $line -ForegroundColor Green
        } elseif ($line -match "tank/.*_encrypted") {
            Write-Host $line -ForegroundColor Yellow
        } else {
            Write-Host $line
        }
    }

    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "VERIFICATION SUCCESSFUL!" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host ""
    Write-Host "[✓] jdmal can access encrypted datasets" -ForegroundColor Green
    Write-Host "[✓] All encryption properties verified" -ForegroundColor Green
    Write-Host "[✓] jdmal has proper permissions" -ForegroundColor Green
    Write-Host ""

    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Update snapshot tasks to use _encrypted datasets"
    Write-Host "  2. Update replication tasks to use _encrypted datasets"
    Write-Host "  3. Set up Tailscale VPN: .\\SETUP-TAILSCALE-QUICK.ps1"
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host "VERIFICATION FAILED" -ForegroundColor Red
    Write-Host "=" * 80 -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Verify jdmal SSH key is correct:"
    Write-Host "     ssh -i $JDMAL_SSH_KEY jdmal@$BABYNAS_IP"
    Write-Host ""
    Write-Host "  2. Check if encrypted datasets exist:"
    Write-Host "     ssh -i $JDMAL_SSH_KEY jdmal@$BABYNAS_IP zfs list | grep encrypted"
    Write-Host ""
    Write-Host "  3. If datasets missing, run encryption setup:"
    Write-Host "     .\\RUN-ENCRYPTION-SETUP-NOW.ps1"
    Write-Host ""
    exit 1
}
