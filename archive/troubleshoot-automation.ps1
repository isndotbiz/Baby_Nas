#Requires -RunAsAdministrator
###############################################################################
# Troubleshooting Helper for Full Automation
# Diagnoses common issues and provides solutions
###############################################################################

param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$MainNasIP = "10.0.0.89"
)

$issues = @()
$warnings = @()
$info = @()

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                   ║" -ForegroundColor Cyan
Write-Host "║           BABY NAS AUTOMATION TROUBLESHOOTER                      ║" -ForegroundColor Cyan
Write-Host "║                                                                   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

###############################################################################
# Check 1: Baby NAS VM Status
###############################################################################
Write-Host "[1/10] Checking Baby NAS VM status..." -ForegroundColor Yellow

$vm = Get-VM -Name "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue

if ($vm) {
    if ($vm.State -eq "Running") {
        Write-Host "  ✓ VM is running" -ForegroundColor Green
        $info += "VM State: Running"
        $info += "VM RAM: $($vm.MemoryStartup / 1GB)GB"
    } else {
        Write-Host "  ✗ VM is not running (State: $($vm.State))" -ForegroundColor Red
        $issues += "VM is not running. Start it with: Start-VM 'TrueNAS-BabyNAS'"
    }
} else {
    Write-Host "  ✗ VM not found" -ForegroundColor Red
    $issues += "VM 'TrueNAS-BabyNAS' does not exist. Create it first with: .\1-create-baby-nas-vm.ps1"
}

###############################################################################
# Check 2: Network Connectivity
###############################################################################
Write-Host "[2/10] Checking network connectivity..." -ForegroundColor Yellow

if (Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet) {
    Write-Host "  ✓ Baby NAS is reachable at $BabyNasIP" -ForegroundColor Green
    $info += "Network: Reachable"
} else {
    Write-Host "  ✗ Cannot ping Baby NAS at $BabyNasIP" -ForegroundColor Red
    $issues += "Baby NAS not reachable. Check VM network settings and IP configuration."
}

###############################################################################
# Check 3: SSH Service
###############################################################################
Write-Host "[3/10] Checking SSH service..." -ForegroundColor Yellow

$sshTest = Test-NetConnection -ComputerName $BabyNasIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet

if ($sshTest) {
    Write-Host "  ✓ SSH service is accessible on port 22" -ForegroundColor Green
    $info += "SSH Port: Open"
} else {
    Write-Host "  ✗ SSH port 22 is not accessible" -ForegroundColor Red
    $issues += "SSH service not running. Enable in TrueNAS: System Settings → Services → SSH → Start"
}

###############################################################################
# Check 4: SSH Client
###############################################################################
Write-Host "[4/10] Checking SSH client..." -ForegroundColor Yellow

$sshClient = Get-Command ssh.exe -ErrorAction SilentlyContinue

if ($sshClient) {
    Write-Host "  ✓ OpenSSH client is installed" -ForegroundColor Green
    Write-Host "    Location: $($sshClient.Path)" -ForegroundColor Gray
    $info += "SSH Client: $($sshClient.Path)"
} else {
    $plinkClient = Get-Command plink.exe -ErrorAction SilentlyContinue
    if ($plinkClient) {
        Write-Host "  ✓ PuTTY plink is available" -ForegroundColor Green
        $warnings += "Using PuTTY instead of OpenSSH. Consider installing OpenSSH for better compatibility."
    } else {
        Write-Host "  ✗ No SSH client found" -ForegroundColor Red
        $issues += "Install OpenSSH: Settings → Apps → Optional Features → OpenSSH Client"
    }
}

###############################################################################
# Check 5: PowerShell Execution Policy
###############################################################################
Write-Host "[5/10] Checking PowerShell execution policy..." -ForegroundColor Yellow

$execPolicy = Get-ExecutionPolicy

if ($execPolicy -eq "Unrestricted" -or $execPolicy -eq "RemoteSigned" -or $execPolicy -eq "Bypass") {
    Write-Host "  ✓ Execution policy allows scripts ($execPolicy)" -ForegroundColor Green
    $info += "Execution Policy: $execPolicy"
} else {
    Write-Host "  ⚠ Execution policy may block scripts ($execPolicy)" -ForegroundColor Yellow
    $warnings += "Execution policy is restrictive. Run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
}

###############################################################################
# Check 6: Required Directories
###############################################################################
Write-Host "[6/10] Checking required directories..." -ForegroundColor Yellow

$requiredDirs = @(
    "D:\workspace\True_Nas\windows-scripts",
    "D:\workspace\True_Nas\truenas-scripts"
)

$allExist = $true
foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Host "  ✓ $dir" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $dir (missing)" -ForegroundColor Red
        $issues += "Directory missing: $dir"
        $allExist = $false
    }
}

if ($allExist) {
    $info += "All required directories exist"
}

###############################################################################
# Check 7: Configuration Scripts
###############################################################################
Write-Host "[7/10] Checking configuration scripts..." -ForegroundColor Yellow

$requiredScripts = @(
    "D:\workspace\True_Nas\windows-scripts\FULL-AUTOMATION.ps1",
    "D:\workspace\True_Nas\truenas-scripts\configure-baby-nas-complete.sh",
    "D:\workspace\True_Nas\windows-scripts\setup-ssh-keys-complete.ps1",
    "D:\workspace\True_Nas\windows-scripts\test-baby-nas-complete.ps1",
    "D:\workspace\True_Nas\windows-scripts\3-setup-replication.ps1"
)

$allExist = $true
foreach ($script in $requiredScripts) {
    if (Test-Path $script) {
        Write-Host "  ✓ $(Split-Path $script -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $(Split-Path $script -Leaf) (missing)" -ForegroundColor Red
        $issues += "Script missing: $script"
        $allExist = $false
    }
}

if ($allExist) {
    $info += "All required scripts exist"
}

###############################################################################
# Check 8: SSH Keys
###############################################################################
Write-Host "[8/10] Checking SSH keys..." -ForegroundColor Yellow

$sshDir = "$env:USERPROFILE\.ssh"
$babyKeyPath = "$sshDir\id_babynas"
$mainKeyPath = "$sshDir\id_mainnas"

if (Test-Path $babyKeyPath) {
    Write-Host "  ✓ Baby NAS SSH key exists" -ForegroundColor Green
    $info += "Baby NAS key: $babyKeyPath"
} else {
    Write-Host "  • Baby NAS SSH key not generated yet" -ForegroundColor Gray
    $warnings += "SSH keys will be generated during automation"
}

if (Test-Path $mainKeyPath) {
    Write-Host "  ✓ Main NAS SSH key exists" -ForegroundColor Green
    $info += "Main NAS key: $mainKeyPath"
} else {
    Write-Host "  • Main NAS SSH key not generated yet" -ForegroundColor Gray
}

###############################################################################
# Check 9: Main NAS Connectivity (Optional)
###############################################################################
Write-Host "[9/10] Checking Main NAS connectivity (optional)..." -ForegroundColor Yellow

if (Test-Connection -ComputerName $MainNasIP -Count 2 -Quiet) {
    Write-Host "  ✓ Main NAS is reachable at $MainNasIP" -ForegroundColor Green
    $info += "Main NAS: Reachable"
} else {
    Write-Host "  ⚠ Main NAS not reachable (replication will be skipped)" -ForegroundColor Yellow
    $warnings += "Main NAS not reachable. Replication setup will be skipped."
}

###############################################################################
# Check 10: Recent Logs
###############################################################################
Write-Host "[10/10] Checking for recent logs..." -ForegroundColor Yellow

$logDir = "D:\workspace\True_Nas\logs"

if (Test-Path $logDir) {
    $recentLogs = Get-ChildItem -Path $logDir -Filter "full-automation-*.log" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 3

    if ($recentLogs) {
        Write-Host "  ✓ Found recent log files:" -ForegroundColor Green
        foreach ($log in $recentLogs) {
            Write-Host "    • $($log.Name) ($($log.LastWriteTime))" -ForegroundColor Gray
        }
        $info += "Recent logs available in: $logDir"
    } else {
        Write-Host "  • No previous automation runs found" -ForegroundColor Gray
    }
} else {
    Write-Host "  • Log directory will be created during automation" -ForegroundColor Gray
}

###############################################################################
# SUMMARY
###############################################################################
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor White
Write-Host "DIAGNOSTIC SUMMARY" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor White
Write-Host ""

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "✓ All checks passed! Ready to run automation." -ForegroundColor Green
    Write-Host ""
    Write-Host "Run automation with:" -ForegroundColor Cyan
    Write-Host "  .\FULL-AUTOMATION.ps1" -ForegroundColor White
    Write-Host ""
} elseif ($issues.Count -eq 0) {
    Write-Host "⚠ Ready to run with minor warnings ($($warnings.Count))" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "✗ Found $($issues.Count) blocking issue(s) that must be resolved:" -ForegroundColor Red
    Write-Host ""
}

# Display issues
if ($issues.Count -gt 0) {
    Write-Host "BLOCKING ISSUES:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "  ✗ $issue" -ForegroundColor Red
    }
    Write-Host ""
}

# Display warnings
if ($warnings.Count -gt 0) {
    Write-Host "WARNINGS:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  ⚠ $warning" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Display info
if ($info.Count -gt 0) {
    Write-Host "SYSTEM INFORMATION:" -ForegroundColor Cyan
    foreach ($i in $info) {
        Write-Host "  • $i" -ForegroundColor Gray
    }
    Write-Host ""
}

###############################################################################
# RECOMMENDATIONS
###############################################################################
if ($issues.Count -gt 0 -or $warnings.Count -gt 0) {
    Write-Host "RECOMMENDED ACTIONS:" -ForegroundColor Cyan
    Write-Host ""

    if ($issues.Count -gt 0) {
        Write-Host "1. Fix all blocking issues listed above" -ForegroundColor White
        Write-Host "2. Re-run this troubleshooter: .\troubleshoot-automation.ps1" -ForegroundColor White
        Write-Host "3. Once all issues are resolved, run: .\FULL-AUTOMATION.ps1" -ForegroundColor White
    } else {
        Write-Host "1. Review warnings (these are usually non-critical)" -ForegroundColor White
        Write-Host "2. Run automation: .\FULL-AUTOMATION.ps1" -ForegroundColor White
        Write-Host "3. Warnings will be addressed during automation if needed" -ForegroundColor White
    }

    Write-Host ""
}

# Quick fixes
if ($issues.Count -gt 0) {
    Write-Host "QUICK FIXES:" -ForegroundColor Yellow
    Write-Host ""

    if ($vm -and $vm.State -ne "Running") {
        Write-Host "Start Baby NAS VM:" -ForegroundColor Cyan
        Write-Host "  Start-VM 'TrueNAS-BabyNAS'" -ForegroundColor White
        Write-Host ""
    }

    if (-not $sshTest) {
        Write-Host "Enable SSH on Baby NAS:" -ForegroundColor Cyan
        Write-Host "  1. Open https://$BabyNasIP" -ForegroundColor White
        Write-Host "  2. Login as admin" -ForegroundColor White
        Write-Host "  3. Go to System Settings → Services" -ForegroundColor White
        Write-Host "  4. Find SSH and click Start button" -ForegroundColor White
        Write-Host ""
    }

    if (-not $sshClient -and -not $plinkClient) {
        Write-Host "Install OpenSSH Client:" -ForegroundColor Cyan
        Write-Host "  1. Open Settings" -ForegroundColor White
        Write-Host "  2. Go to Apps → Optional Features" -ForegroundColor White
        Write-Host "  3. Click 'Add a feature'" -ForegroundColor White
        Write-Host "  4. Find and install 'OpenSSH Client'" -ForegroundColor White
        Write-Host ""
    }
}

Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor White
Write-Host ""

# Exit code
if ($issues.Count -gt 0) {
    exit 1
} else {
    exit 0
}
