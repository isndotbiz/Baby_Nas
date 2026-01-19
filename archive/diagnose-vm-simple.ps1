# Baby NAS VM Quick Diagnostic

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  Baby NAS VM Diagnostic - Quick Check" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# STEP 1: VM State
Write-Host "=== STEP 1: VM State / Status / Uptime ===" -ForegroundColor Cyan
Write-Host ""

$vm = Get-VM -Name "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue

if ($vm) {
    Write-Host "OK: VM found" -ForegroundColor Green
    $vm | Select-Object Name, State, Status, Uptime, Heartbeat | Format-List
} else {
    Write-Host "ERROR: VM not found" -ForegroundColor Red
    Get-VM -ErrorAction SilentlyContinue | Select-Object Name, State | Format-Table
    exit 1
}

# STEP 2: Start if needed
Write-Host ""
Write-Host "=== STEP 2: Start VM if not running ===" -ForegroundColor Cyan
Write-Host ""

if ($vm.State -ne "Running") {
    Write-Host "VM not running, attempting start..." -ForegroundColor Yellow
    try {
        Start-VM -Name "TrueNAS-BabyNAS" -Passthru -ErrorAction Stop | Select-Object Name, State, Status | Format-List
        Write-Host "OK: VM started" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "OK: VM already running" -ForegroundColor Green
}

# STEP 3: Waiting
Write-Host ""
Write-Host "=== STEP 3: Waiting for boot ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Waiting 30 seconds for VM to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# STEP 4: Check Firmware
Write-Host ""
Write-Host "=== STEP 4: Firmware / Boot Order ===" -ForegroundColor Cyan
Write-Host ""

$fw = Get-VMFirmware -VMName "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue

if ($fw) {
    Write-Host "VM Generation: 2 (UEFI)" -ForegroundColor White
    Write-Host "Secure Boot: $($fw.SecureBootTemplate)" -ForegroundColor Gray
    Write-Host "Boot Order:" -ForegroundColor Yellow
    $fw.BootOrder | ForEach-Object {
        Write-Host "  - $($_.BootType): $($_.Device)" -ForegroundColor Gray
    }
} else {
    Write-Host "VM Generation: 1 (BIOS)" -ForegroundColor White
}

# STEP 5: Network Adapter
Write-Host ""
Write-Host "=== STEP 5: Network Adapter ===" -ForegroundColor Cyan
Write-Host ""

$nics = Get-VMNetworkAdapter -VMName "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue

if ($nics) {
    $nics | Format-List VMName, SwitchName, Status, MacAddress, DynamicMacAddressEnabled, IPAddresses

    if (!$nics.SwitchName) {
        Write-Host ""
        Write-Host "WARNING: Network adapter NOT connected!" -ForegroundColor Yellow
        Write-Host "Attempting to connect..." -ForegroundColor Yellow
        try {
            Connect-VMNetworkAdapter -VMName "TrueNAS-BabyNAS" -SwitchName "Default Switch" -ErrorAction Stop
            Write-Host "OK: Connected to Default Switch" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "ERROR: No network adapters found!" -ForegroundColor Red
}

# STEP 6: Virtual Switch
Write-Host ""
Write-Host "=== STEP 6: Virtual Switch ===" -ForegroundColor Cyan
Write-Host ""

$switches = Get-VMSwitch -ErrorAction SilentlyContinue

if ($switches) {
    $switches | Format-Table Name, SwitchType, AllowManagementOS

    $defaultSwitch = $switches | Where-Object { $_.Name -eq "Default Switch" }
    if ($defaultSwitch) {
        Write-Host "OK: Default Switch exists" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Default Switch NOT found" -ForegroundColor Yellow
    }
} else {
    Write-Host "ERROR: No switches found" -ForegroundColor Red
}

# STEP 7: Connectivity Tests
Write-Host ""
Write-Host "=== STEP 7: Network Connectivity ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Testing ping to 172.21.203.18..." -ForegroundColor Yellow
$ping = Test-Connection -ComputerName "172.21.203.18" -Count 4 -ErrorAction SilentlyContinue

if ($ping) {
    Write-Host "OK: PING SUCCESSFUL!" -ForegroundColor Green
    $ping | Select-Object Address, ResponseTime | Format-Table

    Write-Host ""
    Write-Host "Testing SSH port (22)..." -ForegroundColor Yellow
    $ssh = Test-NetConnection -ComputerName "172.21.203.18" -Port 22 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($ssh.TcpTestSucceeded) {
        Write-Host "OK: SSH port OPEN" -ForegroundColor Green
    } else {
        Write-Host "WARNING: SSH port not responding yet" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Testing SMB port (445)..." -ForegroundColor Yellow
    $smb = Test-NetConnection -ComputerName "172.21.203.18" -Port 445 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ($smb.TcpTestSucceeded) {
        Write-Host "OK: SMB port OPEN" -ForegroundColor Green
    } else {
        Write-Host "WARNING: SMB port not responding yet" -ForegroundColor Yellow
    }
} else {
    Write-Host "ERROR: PING FAILED" -ForegroundColor Red

    Write-Host ""
    Write-Host "Checking ARP cache..." -ForegroundColor Yellow
    $arp = arp -a | Select-String "172.21.203.18"
    if ($arp) {
        Write-Host "PARTIAL: VM in ARP cache (has IP)" -ForegroundColor Yellow
        Write-Host $arp -ForegroundColor Gray
    } else {
        Write-Host "ERROR: VM not in ARP cache (no DHCP IP yet)" -ForegroundColor Red
    }
}

# STEP 8: Disks
Write-Host ""
Write-Host "=== STEP 8: VM Disks ===" -ForegroundColor Cyan
Write-Host ""

$disks = Get-VMHardDiskDrive -VMName "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue

if ($disks) {
    $disks | Select-Object VMName, ControllerType, ControllerNumber, ControllerLocation, Path | Format-Table

    foreach ($disk in $disks) {
        if ($disk.Path) {
            $file = Get-Item -Path $disk.Path -ErrorAction SilentlyContinue
            if ($file) {
                Write-Host "OK: Disk exists: $($disk.Path)" -ForegroundColor Green
            } else {
                Write-Host "ERROR: Disk NOT found: $($disk.Path)" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "ERROR: No disks found!" -ForegroundColor Red
}

# STEP 9: Snapshots
Write-Host ""
Write-Host "=== STEP 9: VM Snapshots ===" -ForegroundColor Cyan
Write-Host ""

$snapshots = Get-VMSnapshot -VMName "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue

if ($snapshots) {
    Write-Host "WARNING: Found $($snapshots.Count) snapshot(s)" -ForegroundColor Yellow
    $snapshots | Select-Object Name, CreationTime | Format-Table
} else {
    Write-Host "OK: No snapshots (normal)" -ForegroundColor Green
}

# SUMMARY
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "  Diagnostic Complete" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host ""

# Determine status
$online = $ping -ne $null

if ($online) {
    Write-Host "RESULT: VM IS ONLINE AND ACCESSIBLE" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step: Run configuration" -ForegroundColor Yellow
    Write-Host "  .\DEPLOY-BABY-NAS-CONFIG.ps1" -ForegroundColor White
} else {
    Write-Host "RESULT: VM is NOT yet network accessible" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "  1. VM still booting (TrueNAS takes 2-5 minutes)" -ForegroundColor White
    Write-Host "  2. Network adapter not connected" -ForegroundColor White
    Write-Host "  3. Secure boot issue" -ForegroundColor White
    Write-Host "  4. VHD corrupt" -ForegroundColor White
    Write-Host ""
    Write-Host "Recommended next steps:" -ForegroundColor Yellow
    Write-Host "  1. Open console: vmconnect.exe localhost TrueNAS-BabyNAS" -ForegroundColor White
    Write-Host "  2. Wait 2-5 more minutes" -ForegroundColor White
    Write-Host "  3. Run this script again" -ForegroundColor White
}

Write-Host ""
