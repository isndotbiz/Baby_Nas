#Requires -RunAsAdministrator
###############################################################################
# Deploy Baby NAS Configuration
# Uploads and executes the complete configuration script
###############################################################################

# Load environment variables from .env file
. "$PSScriptRoot\Load-EnvFile.ps1"

$BabyNasIP = Get-EnvVariable "TRUENAS_IP" -Default "172.21.203.18"
$Username = Get-EnvVariable "TRUENAS_USERNAME" -Default "root"
$Password = Get-EnvVariable "TRUENAS_PASSWORD"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "║          Baby NAS Complete Configuration                 ║" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

###############################################################################
# Step 1: Verify connectivity
###############################################################################
Write-Host "[1/6] Testing connectivity to Baby NAS..." -ForegroundColor Cyan
if (Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet) {
    Write-Host "      ✓ Baby NAS is reachable" -ForegroundColor Green
} else {
    Write-Host "      ✗ Cannot reach Baby NAS at $BabyNasIP" -ForegroundColor Red
    exit 1
}

###############################################################################
# Step 2: Check SSH availability
###############################################################################
Write-Host "[2/6] Checking SSH service..." -ForegroundColor Cyan
$tcpConnection = Test-NetConnection -ComputerName $BabyNasIP -Port 22 -WarningAction SilentlyContinue

if ($tcpConnection.TcpTestSucceeded) {
    Write-Host "      ✓ SSH service is running" -ForegroundColor Green
} else {
    Write-Host "      ✗ SSH service not accessible" -ForegroundColor Red
    Write-Host "      Please enable SSH in TrueNAS Web UI:" -ForegroundColor Yellow
    Write-Host "      https://$BabyNasIP → System Settings → Services → SSH → Start" -ForegroundColor White
    exit 1
}

###############################################################################
# Step 3: Test SSH authentication
###############################################################################
Write-Host "[3/6] Testing SSH authentication..." -ForegroundColor Cyan

# Check if plink (PuTTY) is available
$plinkPath = Get-Command plink.exe -ErrorAction SilentlyContinue

if (-not $plinkPath) {
    Write-Host "      • plink not found, checking for OpenSSH..." -ForegroundColor Gray

    # Try using built-in OpenSSH
    $sshPath = Get-Command ssh.exe -ErrorAction SilentlyContinue

    if ($sshPath) {
        Write-Host "      ✓ Using OpenSSH" -ForegroundColor Green

        # Test connection
        $testCmd = "echo 'Connection test successful'"
        $result = echo "y" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$Username@$BabyNasIP" "$testCmd" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✓ SSH authentication successful" -ForegroundColor Green
        } else {
            Write-Host "      ✗ SSH authentication failed" -ForegroundColor Red
            Write-Host "      Error: $result" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "      ✗ No SSH client found (need OpenSSH or PuTTY)" -ForegroundColor Red
        Write-Host "      Install OpenSSH: Settings → Apps → Optional Features → OpenSSH Client" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "      ✓ Using PuTTY plink" -ForegroundColor Green
}

###############################################################################
# Step 4: Upload configuration script
###############################################################################
Write-Host "[4/6] Uploading configuration script..." -ForegroundColor Cyan

$localScript = "D:\workspace\True_Nas\truenas-scripts\configure-baby-nas-complete.sh"
$remoteScript = "/root/configure-baby-nas.sh"

if (-not (Test-Path $localScript)) {
    Write-Host "      ✗ Configuration script not found: $localScript" -ForegroundColor Red
    exit 1
}

# Use SCP to upload
Write-Host "      • Uploading via SCP..." -ForegroundColor Gray

if ($sshPath) {
    # Using OpenSSH scp
    echo "y" | scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$localScript" "${Username}@${BabyNasIP}:${remoteScript}" 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "      ✓ Configuration script uploaded" -ForegroundColor Green
    } else {
        Write-Host "      ✗ Upload failed" -ForegroundColor Red
        exit 1
    }
} else {
    # Using PuTTY pscp
    $pscpPath = Get-Command pscp.exe -ErrorAction SilentlyContinue
    if ($pscpPath) {
        & pscp.exe -pw "$Password" "$localScript" "${Username}@${BabyNasIP}:${remoteScript}"
        Write-Host "      ✓ Configuration script uploaded" -ForegroundColor Green
    } else {
        Write-Host "      ✗ No SCP client available" -ForegroundColor Red
        exit 1
    }
}

###############################################################################
# Step 5: Make script executable and run
###############################################################################
Write-Host "[5/6] Executing configuration script..." -ForegroundColor Cyan
Write-Host "      This will:" -ForegroundColor White
Write-Host "        1. Identify available disks" -ForegroundColor Gray
Write-Host "        2. Create ZFS pool (RAIDZ1 + SLOG + L2ARC)" -ForegroundColor Gray
Write-Host "        3. Create encrypted datasets" -ForegroundColor Gray
Write-Host "        4. Create truenas_admin user" -ForegroundColor Gray
Write-Host "        5. Configure SSH, SMB, security" -ForegroundColor Gray
Write-Host "        6. Apply performance tuning" -ForegroundColor Gray
Write-Host ""

$confirm = Read-Host "      Ready to proceed? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "      Aborted by user" -ForegroundColor Yellow
    exit 0
}

# Make executable
Write-Host "      • Making script executable..." -ForegroundColor Gray
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$Username@$BabyNasIP" "chmod +x $remoteScript"

Write-Host "      • Starting configuration (this will take several minutes)..." -ForegroundColor Yellow
Write-Host ""

# Run the script interactively so user can provide disk IDs
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t "$Username@$BabyNasIP" "bash $remoteScript"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "      ✓ Configuration completed successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "      ⚠ Configuration exited with code: $LASTEXITCODE" -ForegroundColor Yellow
    Write-Host "      Check the output above for details" -ForegroundColor Yellow
}

###############################################################################
# Step 6: Reduce VM Memory to 8GB
###############################################################################
Write-Host ""
Write-Host "[6/6] Optimizing VM memory allocation..." -ForegroundColor Cyan

$VMName = "TrueNAS-BabyNAS"
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

if ($vm) {
    $currentRAM = $vm.MemoryStartup / 1GB
    Write-Host "      Current RAM: $currentRAM GB" -ForegroundColor White

    if ($currentRAM -gt 8) {
        Write-Host "      • Reducing to 8GB for optimal backup workload..." -ForegroundColor Gray

        # Stop VM
        Write-Host "      • Stopping VM..." -ForegroundColor Gray
        Stop-VM -Name $VMName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5

        # Change memory
        Set-VMMemory -VMName $VMName -StartupBytes 8GB -MinimumBytes 4GB -MaximumBytes 8GB

        Write-Host "      ✓ VM memory set to 8GB" -ForegroundColor Green

        # Restart VM
        Write-Host "      • Restarting VM..." -ForegroundColor Gray
        Start-VM -Name $VMName

        Write-Host "      • Waiting for VM to boot..." -ForegroundColor Gray
        Start-Sleep -Seconds 15

        # Wait for SSH to be available
        $retries = 0
        $maxRetries = 20
        while ($retries -lt $maxRetries) {
            if (Test-NetConnection -ComputerName $BabyNasIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet) {
                Write-Host "      ✓ VM restarted and online" -ForegroundColor Green
                break
            }
            Start-Sleep -Seconds 3
            $retries++
        }

        if ($retries -eq $maxRetries) {
            Write-Host "      ⚠ VM took longer than expected to come online" -ForegroundColor Yellow
        }
    } else {
        Write-Host "      ✓ VM already at 8GB" -ForegroundColor Green
    }
} else {
    Write-Host "      • VM $VMName not found locally (skip)" -ForegroundColor Gray
}

###############################################################################
# COMPLETION
###############################################################################
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                          ║" -ForegroundColor Green
Write-Host "║          Baby NAS Configuration Complete!                ║" -ForegroundColor Green
Write-Host "║                                                          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "Configuration Summary:" -ForegroundColor Cyan
Write-Host "  • Baby NAS IP: $BabyNasIP" -ForegroundColor White
Write-Host "  • Pool: tank (RAIDZ1 + SLOG + L2ARC)" -ForegroundColor White
Write-Host "  • Capacity: ~12TB usable" -ForegroundColor White
Write-Host "  • Encryption: AES-256-GCM" -ForegroundColor White
Write-Host "  • User: truenas_admin" -ForegroundColor White
Write-Host "  • RAM: 8GB (4GB ARC)" -ForegroundColor White
Write-Host ""

Write-Host "Test SMB Connectivity:" -ForegroundColor Cyan
Write-Host "  net use W: \\$BabyNasIP\WindowsBackup /user:truenas_admin `"uppercut%`$##`"" -ForegroundColor White
Write-Host ""

Write-Host "SSH Access:" -ForegroundColor Cyan
Write-Host "  ssh truenas_admin@$BabyNasIP" -ForegroundColor White
Write-Host ""

Write-Host "Web UI:" -ForegroundColor Cyan
Write-Host "  https://$BabyNasIP" -ForegroundColor White
Write-Host "  User: admin" -ForegroundColor White
Write-Host "  Pass: uppercut%`$##" -ForegroundColor White
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test SMB shares from Windows" -ForegroundColor White
Write-Host "  2. Set up replication to Main NAS (10.0.0.89)" -ForegroundColor White
Write-Host "  3. Deploy Veeam backup jobs" -ForegroundColor White
Write-Host "  4. Configure development environment" -ForegroundColor White
Write-Host ""

Write-Host "Run these scripts next:" -ForegroundColor Yellow
Write-Host "  • .\3-setup-replication.ps1 -BabyNasIP $BabyNasIP" -ForegroundColor Cyan
Write-Host "  • .\veeam\0-DEPLOY-VEEAM-COMPLETE.ps1" -ForegroundColor Cyan
Write-Host ""
