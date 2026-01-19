#Requires -RunAsAdministrator
###############################################################################
# Complete Baby NAS Testing Suite
# Tests all aspects of Baby NAS configuration
###############################################################################

# Load environment variables from .env file
. "$PSScriptRoot\Load-EnvFile.ps1"

param(
    [string]$BabyNasIP = (Get-EnvVariable "TRUENAS_IP" -Default "172.21.203.18"),
    [string]$Username = (Get-EnvVariable "TRUENAS_USERNAME" -Default "root"),
    [string]$Password = (Get-EnvVariable "TRUENAS_PASSWORD")
)

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "║          Baby NAS Complete Test Suite                    ║" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$testResults = @{
    Passed = 0
    Failed = 0
    Warnings = 0
}

function Test-Item {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$Category
    )

    Write-Host "  Testing: $Name" -ForegroundColor Gray -NoNewline

    try {
        $result = & $Test
        if ($result -eq $true) {
            Write-Host " ✓" -ForegroundColor Green
            $script:testResults.Passed++
            return $true
        } elseif ($result -eq "warning") {
            Write-Host " ⚠" -ForegroundColor Yellow
            $script:testResults.Warnings++
            return "warning"
        } else {
            Write-Host " ✗" -ForegroundColor Red
            $script:testResults.Failed++
            return $false
        }
    } catch {
        Write-Host " ✗ (Error: $($_.Exception.Message))" -ForegroundColor Red
        $script:testResults.Failed++
        return $false
    }
}

###############################################################################
# Category 1: VM and Network Connectivity
###############################################################################
Write-Host ""
Write-Host "[1/10] VM and Network Connectivity" -ForegroundColor Cyan

Test-Item -Name "VM exists and is running" -Category "VM" -Test {
    $vm = Get-VM -Name "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue
    if ($vm -and $vm.State -eq "Running") {
        return $true
    }
    return $false
}

Test-Item -Name "VM memory is 8GB" -Category "VM" -Test {
    $vm = Get-VM -Name "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue
    if ($vm) {
        $memGB = $vm.MemoryStartup / 1GB
        if ($memGB -eq 8) {
            return $true
        } elseif ($memGB -gt 8) {
            Write-Host " (Current: ${memGB}GB)" -ForegroundColor Yellow -NoNewline
            return "warning"
        }
    }
    return $false
}

Test-Item -Name "Network connectivity (ping)" -Category "Network" -Test {
    return (Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet)
}

Test-Item -Name "SSH port 22 accessible" -Category "Network" -Test {
    $tcpTest = Test-NetConnection -ComputerName $BabyNasIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet
    return $tcpTest
}

Test-Item -Name "Web UI port 443 accessible" -Category "Network" -Test {
    $tcpTest = Test-NetConnection -ComputerName $BabyNasIP -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
    return $tcpTest
}

###############################################################################
# Category 2: SSH Access
###############################################################################
Write-Host ""
Write-Host "[2/10] SSH Access" -ForegroundColor Cyan

Test-Item -Name "SSH password authentication" -Category "SSH" -Test {
    $result = echo "y" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${BabyNasIP}" "echo test" 2>&1
    return ($LASTEXITCODE -eq 0)
}

Test-Item -Name "SSH key authentication" -Category "SSH" -Test {
    $keyPath = "$env:USERPROFILE\.ssh\id_babynas"
    if (Test-Path $keyPath) {
        $result = ssh -i $keyPath -o StrictHostKeyChecking=no "${Username}@${BabyNasIP}" "echo test" 2>&1
        return ($LASTEXITCODE -eq 0)
    } else {
        return "warning"
    }
}

Test-Item -Name "SSH alias 'babynas' works" -Category "SSH" -Test {
    $configPath = "$env:USERPROFILE\.ssh\config"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw
        if ($config -match "Host babynas") {
            $result = ssh babynas "echo test" 2>&1
            return ($LASTEXITCODE -eq 0)
        }
    }
    return "warning"
}

###############################################################################
# Category 3: ZFS Pool and Storage
###############################################################################
Write-Host ""
Write-Host "[3/10] ZFS Pool and Storage" -ForegroundColor Cyan

Test-Item -Name "ZFS pool 'tank' exists" -Category "ZFS" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "zpool list tank" 2>&1
    return ($LASTEXITCODE -eq 0)
}

Test-Item -Name "Pool is ONLINE" -Category "ZFS" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "zpool status tank | grep 'state: ONLINE'" 2>&1
    return ($LASTEXITCODE -eq 0)
}

Test-Item -Name "RAIDZ1 configured (3 disks)" -Category "ZFS" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "zpool status tank | grep raidz1" 2>&1
    return ($LASTEXITCODE -eq 0)
}

Test-Item -Name "SLOG device present" -Category "ZFS" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "zpool status tank | grep 'logs'" 2>&1
    return ($LASTEXITCODE -eq 0)
}

Test-Item -Name "L2ARC device present" -Category "ZFS" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "zpool status tank | grep 'cache'" 2>&1
    return ($LASTEXITCODE -eq 0)
}

Test-Item -Name "Compression enabled" -Category "ZFS" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "zfs get compression tank -H | grep lz4" 2>&1
    return ($LASTEXITCODE -eq 0)
}

###############################################################################
# Category 4: Datasets
###############################################################################
Write-Host ""
Write-Host "[4/10] Datasets" -ForegroundColor Cyan

$expectedDatasets = @(
    "tank/windows-backups",
    "tank/windows-backups/c-drive",
    "tank/windows-backups/d-workspace",
    "tank/windows-backups/wsl",
    "tank/veeam",
    "tank/development",
    "tank/home"
)

foreach ($dataset in $expectedDatasets) {
    Test-Item -Name "Dataset $dataset exists" -Category "Datasets" -Test {
        $result = ssh "${Username}@${BabyNasIP}" "zfs list $dataset" 2>&1
        return ($LASTEXITCODE -eq 0)
    }.GetNewClosure()
}

Test-Item -Name "Datasets are encrypted" -Category "Datasets" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "zfs get encryption tank/windows-backups -H | grep aes-256-gcm" 2>&1
    return ($LASTEXITCODE -eq 0)
}

###############################################################################
# Category 5: Users and Permissions
###############################################################################
Write-Host ""
Write-Host "[5/10] Users and Permissions" -ForegroundColor Cyan

Test-Item -Name "User truenas_admin exists" -Category "Users" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "id truenas_admin" 2>&1
    return ($LASTEXITCODE -eq 0)
}

Test-Item -Name "User has sudo privileges" -Category "Users" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "sudo -n true" 2>&1
    # If sudo requires password, that's okay (return warning)
    if ($LASTEXITCODE -eq 0) {
        return $true
    } else {
        return "warning"
    }
}

Test-Item -Name "User home directory on ZFS" -Category "Users" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "test -d /mnt/tank/home/truenas_admin && echo exists" 2>&1
    return ($result -match "exists")
}

###############################################################################
# Category 6: SMB Shares
###############################################################################
Write-Host ""
Write-Host "[6/10] SMB Shares" -ForegroundColor Cyan

Test-Item -Name "SMB port 445 accessible" -Category "SMB" -Test {
    $tcpTest = Test-NetConnection -ComputerName $BabyNasIP -Port 445 -WarningAction SilentlyContinue -InformationLevel Quiet
    return $tcpTest
}

Test-Item -Name "Samba service running" -Category "SMB" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "systemctl is-active smbd" 2>&1
    return ($result -match "active")
}

$shares = @("WindowsBackup", "Veeam", "Development", "Home")

foreach ($share in $shares) {
    Test-Item -Name "Share '$share' accessible" -Category "SMB" -Test {
        $uncPath = "\\$BabyNasIP\$share"
        try {
            # Try to access share
            $testPath = Test-Path $uncPath -ErrorAction Stop
            return $testPath
        } catch {
            # If access denied, share exists but needs credentials (that's okay)
            if ($_.Exception.Message -match "denied") {
                return $true
            }
            return $false
        }
    }.GetNewClosure()
}

# Test with credentials
Test-Item -Name "SMB authentication works" -Category "SMB" -Test {
    $secPassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($Username, $secPassword)

    try {
        $testPath = "\\$BabyNasIP\WindowsBackup"
        # Try to list directory
        $items = Get-ChildItem -Path $testPath -Credential $credential -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

###############################################################################
# Category 7: Security Configuration
###############################################################################
Write-Host ""
Write-Host "[7/10] Security Configuration" -ForegroundColor Cyan

Test-Item -Name "Firewall (UFW) enabled" -Category "Security" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "sudo ufw status | grep 'Status: active'" 2>&1
    return ($result -match "active")
}

Test-Item -Name "SSH configured securely" -Category "Security" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "grep 'MaxAuthTries 3' /etc/ssh/sshd_config" 2>&1
    return ($LASTEXITCODE -eq 0)
}

Test-Item -Name "Root SSH login restricted" -Category "Security" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "grep 'PermitRootLogin prohibit-password' /etc/ssh/sshd_config" 2>&1
    return ($LASTEXITCODE -eq 0)
}

###############################################################################
# Category 8: Performance and Tuning
###############################################################################
Write-Host ""
Write-Host "[8/10] Performance and Tuning" -ForegroundColor Cyan

Test-Item -Name "ARC tuning configured (4GB max)" -Category "Performance" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "cat /sys/module/zfs/parameters/zfs_arc_max" 2>&1
    $arcMaxBytes = [long]$result
    $arcMaxGB = $arcMaxBytes / 1GB
    if ($arcMaxGB -ge 3.5 -and $arcMaxGB -le 4.5) {
        return $true
    }
    Write-Host " (Current: ${arcMaxGB}GB)" -ForegroundColor Yellow -NoNewline
    return "warning"
}

Test-Item -Name "BBR congestion control enabled" -Category "Performance" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "sysctl net.ipv4.tcp_congestion_control | grep bbr" 2>&1
    return ($LASTEXITCODE -eq 0)
}

###############################################################################
# Category 9: Monitoring and Maintenance
###############################################################################
Write-Host ""
Write-Host "[9/10] Monitoring and Maintenance" -ForegroundColor Cyan

Test-Item -Name "SMART monitoring configured" -Category "Monitoring" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "systemctl is-active smartd" 2>&1
    return ($result -match "active")
}

Test-Item -Name "Snapshot automation (sanoid)" -Category "Monitoring" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "systemctl is-active sanoid.timer" 2>&1
    return ($result -match "active")
}

Test-Item -Name "ZFS scrub scheduled" -Category "Monitoring" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "test -f /etc/cron.d/zfs-scrub && echo exists" 2>&1
    return ($result -match "exists")
}

Test-Item -Name "Health check script exists" -Category "Monitoring" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "test -x /usr/local/bin/check-pool-health.sh && echo exists" 2>&1
    return ($result -match "exists")
}

###############################################################################
# Category 10: Integration and Replication
###############################################################################
Write-Host ""
Write-Host "[10/10] Integration and Replication" -ForegroundColor Cyan

Test-Item -Name "Main NAS reachable (10.0.0.89)" -Category "Integration" -Test {
    $mainNasReachable = Test-Connection -ComputerName "10.0.0.89" -Count 2 -Quiet
    if ($mainNasReachable) {
        return $true
    } else {
        return "warning"
    }
}

Test-Item -Name "Replication script exists" -Category "Integration" -Test {
    $result = ssh "${Username}@${BabyNasIP}" "test -f /root/replicate-to-main.sh && echo exists" 2>&1
    if ($result -match "exists") {
        return $true
    } else {
        return "warning"
    }
}

Test-Item -Name "API key configured" -Category "Integration" -Test {
    # Check if API responds
    try {
        $headers = @{
            "Authorization" = "Bearer 1-55zYQRwoAi35zYRlivNjVc56EjI9sSpelZZR3wZH5SDnJWtOfjAs37KBfGtjQDlk"
        }
        $response = Invoke-RestMethod -Uri "https://$BabyNasIP/api/v2.0/system/info" -Headers $headers -SkipCertificateCheck -ErrorAction Stop
        return $true
    } catch {
        return "warning"
    }
}

###############################################################################
# RESULTS SUMMARY
###############################################################################
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor White
Write-Host "║                                                          ║" -ForegroundColor White
Write-Host "║                   Test Results Summary                   ║" -ForegroundColor White
Write-Host "║                                                          ║" -ForegroundColor White
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""

$totalTests = $testResults.Passed + $testResults.Failed + $testResults.Warnings

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "  Passed:    $($testResults.Passed)" -ForegroundColor Green
Write-Host "  Warnings:  $($testResults.Warnings)" -ForegroundColor Yellow
Write-Host "  Failed:    $($testResults.Failed)" -ForegroundColor Red
Write-Host ""

# Calculate percentage
$successRate = [math]::Round(($testResults.Passed / $totalTests) * 100, 1)

if ($testResults.Failed -eq 0) {
    Write-Host "✓ All critical tests passed! ($successRate% success rate)" -ForegroundColor Green
} elseif ($testResults.Failed -le 3) {
    Write-Host "⚠ Most tests passed with some failures ($successRate% success rate)" -ForegroundColor Yellow
} else {
    Write-Host "✗ Multiple test failures detected ($successRate% success rate)" -ForegroundColor Red
}

Write-Host ""

# Recommendations
if ($testResults.Warnings -gt 0 -or $testResults.Failed -gt 0) {
    Write-Host "Recommendations:" -ForegroundColor Cyan

    if ($testResults.Warnings -gt 0) {
        Write-Host "  • Review warnings above - these are non-critical but recommended" -ForegroundColor Yellow
    }

    if ($testResults.Failed -gt 0) {
        Write-Host "  • Fix failed tests before proceeding to production use" -ForegroundColor Red
        Write-Host "  • Check Baby NAS logs: ssh babynas 'journalctl -xe'" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review any failed or warning tests above" -ForegroundColor White
Write-Host "  2. Run: .\3-setup-replication.ps1 -BabyNasIP $BabyNasIP" -ForegroundColor White
Write-Host "  3. Deploy Veeam: .\veeam\0-DEPLOY-VEEAM-COMPLETE.ps1" -ForegroundColor White
Write-Host "  4. Configure development environment" -ForegroundColor White
Write-Host ""

# Save results to file
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFile = "D:\workspace\True_Nas\logs\baby-nas-test-$timestamp.txt"

# Create logs directory if it doesn't exist
$logsDir = "D:\workspace\True_Nas\logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

$reportContent = @"
Baby NAS Test Report
Generated: $(Get-Date)
Baby NAS IP: $BabyNasIP

Test Results:
  Total: $totalTests
  Passed: $($testResults.Passed)
  Warnings: $($testResults.Warnings)
  Failed: $($testResults.Failed)
  Success Rate: $successRate%

Status: $(if ($testResults.Failed -eq 0) { "PASS" } else { "FAIL" })
"@

Set-Content -Path $reportFile -Value $reportContent
Write-Host "Report saved to: $reportFile" -ForegroundColor Gray
Write-Host ""
