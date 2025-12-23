#Requires -RunAsAdministrator
<#
.SYNOPSIS
Comprehensive diagnostic script for Baby NAS Hyper-V VM
#>

Write-Host '╔════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║  Baby NAS VM Diagnostic - Complete Analysis   ║' -ForegroundColor Cyan
Write-Host '╚════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

# STEP 1: VM State & Status
Write-Host '=== STEP 1: VM State & Status ===' -ForegroundColor Cyan
Write-Host ''

$vm = Get-VM -Name 'TrueNAS-BabyNAS' -ErrorAction SilentlyContinue

if ($vm) {
    Write-Host '✓ VM found' -ForegroundColor Green
    Write-Host ''
    Write-Host 'VM Properties:' -ForegroundColor Yellow
    $vm | Select-Object Name, State, Status, Uptime, ProcessorCount, MemoryStartup | Format-List

    Write-Host ''
    Write-Host 'Integration Services State:' -ForegroundColor Yellow
    $vm.IntegrationServicesState | Format-List
} else {
    Write-Host '✗ VM not found!' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Available VMs:' -ForegroundColor Yellow
    Get-VM -ErrorAction SilentlyContinue | Select-Object Name, State | Format-Table
    Write-Host ''
    Write-Host 'Cannot proceed without VM. Exiting.' -ForegroundColor Red
    exit 1
}

# STEP 2: Start VM if not running
Write-Host ''
Write-Host '=== STEP 2: Starting VM (if needed) ===' -ForegroundColor Cyan
Write-Host ''

if ($vm.State -eq "Running") {
    Write-Host '✓ VM already running' -ForegroundColor Green
} else {
    Write-Host "VM is in state: $($vm.State)" -ForegroundColor Yellow
    Write-Host 'Attempting to start...' -ForegroundColor Cyan

    try {
        $startResult = Start-VM -Name "TrueNAS-BabyNAS" -Passthru -ErrorAction Stop
        Write-Host '✓ VM start command succeeded' -ForegroundColor Green
        Write-Host ''
        $startResult | Select-Object Name, State, Status | Format-List
    } catch {
        Write-Host "✗ Error starting VM: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host 'Waiting 30 seconds for VM to initialize...' -ForegroundColor Yellow
Start-Sleep -Seconds 30

# STEP 3: Console info
Write-Host ''
Write-Host '=== STEP 3: Console Access ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'To view VM console, run:' -ForegroundColor Yellow
Write-Host '  vmconnect.exe localhost TrueNAS-BabyNAS' -ForegroundColor White
Write-Host ''
Write-Host 'Watch for boot messages and check if VM is stuck.' -ForegroundColor Gray

# STEP 4: Firmware & Boot Order
Write-Host ''
Write-Host '=== STEP 4: Firmware & Boot Order ===' -ForegroundColor Cyan
Write-Host ''

$fw = Get-VMFirmware -VMName "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue

if ($fw) {
    Write-Host 'VM Generation: 2 (UEFI)' -ForegroundColor White
    Write-Host ''
    Write-Host 'Secure Boot:' -ForegroundColor Yellow
    $fw | Select-Object -ExpandProperty SecureBootTemplate

    Write-Host ''
    Write-Host 'Boot Order:' -ForegroundColor Yellow
    $fw.BootOrder | ForEach-Object {
        Write-Host "  - $($_.BootType): $($_.Device)" -ForegroundColor Gray
    }
} else {
    Write-Host 'VM Generation: 1 (BIOS)' -ForegroundColor White
    Write-Host 'Using legacy BIOS boot order' -ForegroundColor Gray
}

# STEP 5: Network Adapter
Write-Host ''
Write-Host '=== STEP 5: Network Adapter Configuration ===' -ForegroundColor Cyan
Write-Host ''

$nics = Get-VMNetworkAdapter -VMName "TrueNAS-BabyNAS" -ErrorAction SilentlyContinue

if ($nics) {
    $nicCount = @($nics).Count
    Write-Host "✓ Network Adapters Found: $nicCount" -ForegroundColor Green
    Write-Host ''

    if ($nics -is [array]) {
        foreach ($nic in $nics) {
            Write-Host "Adapter: $($nic.Name)" -ForegroundColor White
            Write-Host "  Switch Name:     $($nic.SwitchName)" -ForegroundColor Gray
            Write-Host "  Status:          $($nic.Status)" -ForegroundColor Gray
            Write-Host "  MAC Address:     $($nic.MacAddress)" -ForegroundColor Gray
            Write-Host "  Dynamic MAC:     $($nic.DynamicMacAddressEnabled)" -ForegroundColor Gray
            if ($nic.IPAddresses) {
                Write-Host "  IP Addresses:    $($nic.IPAddresses -join ', ')" -ForegroundColor Gray
            } else {
                Write-Host "  IP Addresses:    (none yet)" -ForegroundColor Yellow
            }
            Write-Host ''
        }
    } else {
        Write-Host "Adapter: $($nics.Name)" -ForegroundColor White
        Write-Host "  Switch Name:     $($nics.SwitchName)" -ForegroundColor Gray
        Write-Host "  Status:          $($nics.Status)" -ForegroundColor Gray
        Write-Host "  MAC Address:     $($nics.MacAddress)" -ForegroundColor Gray
        Write-Host "  Dynamic MAC:     $($nics.DynamicMacAddressEnabled)" -ForegroundColor Gray
        if ($nics.IPAddresses) {
            Write-Host "  IP Addresses:    $($nics.IPAddresses -join ', ')" -ForegroundColor Gray
        } else {
            Write-Host "  IP Addresses:    (none yet)" -ForegroundColor Yellow
        }
        Write-Host ''
    }
} else {
    Write-Host '✗ No network adapters found!' -ForegroundColor Red
}

# STEP 6: Virtual Switch
Write-Host ''
Write-Host '=== STEP 6: Virtual Switch Status ===' -ForegroundColor Cyan
Write-Host ''

$switches = Get-VMSwitch -ErrorAction SilentlyContinue

if ($switches) {
    Write-Host 'Available Switches:' -ForegroundColor Green
    Write-Host ''

    foreach ($switch in $switches) {
        Write-Host "Switch: $($switch.Name)" -ForegroundColor White
        Write-Host "  Type:            $($switch.SwitchType)" -ForegroundColor Gray
        Write-Host "  Management OS:   $($switch.AllowManagementOS)" -ForegroundColor Gray

        try {
            $adapterCount = @(Get-VMNetworkAdapter -ManagementOS -SwitchName $switch.Name -ErrorAction SilentlyContinue).Count
            Write-Host "  Adapters:        $adapterCount" -ForegroundColor Gray
        } catch {
            Write-Host "  Adapters:        (unable to query)" -ForegroundColor Gray
        }

        Write-Host ''
    }

    # Check for Default Switch specifically
    $defaultSwitch = $switches | Where-Object { $_.Name -eq "Default Switch" }
    if ($defaultSwitch) {
        Write-Host '✓ Default Switch EXISTS' -ForegroundColor Green
    } else {
        Write-Host '⚠ Default Switch NOT found' -ForegroundColor Yellow
        Write-Host '  This may be the problem!' -ForegroundColor Yellow
    }
} else {
    Write-Host '✗ No switches found!' -ForegroundColor Red
}

# STEP 7: Network Connectivity
Write-Host ''
Write-Host '=== STEP 7: Network Connectivity Tests ===' -ForegroundColor Cyan
Write-Host ''

Write-Host 'Testing connectivity to 172.21.203.18...' -ForegroundColor Yellow
Write-Host ''

# Ping Test
Write-Host '[PING TEST]' -ForegroundColor Cyan
$ping = Test-Connection -ComputerName "172.21.203.18" -Count 4 -ErrorAction SilentlyContinue

if ($ping) {
    Write-Host '✓ PING SUCCESSFUL!' -ForegroundColor Green
    Write-Host ''
    $ping | Select-Object Address, ResponseTime, @{Name='Status';Expression={'Success'}} | Format-Table

    # SSH Port Test
    Write-Host ''
    Write-Host '[SSH PORT TEST (22)]' -ForegroundColor Cyan
    $ssh = Test-NetConnection -ComputerName "172.21.203.18" -Port 22 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($ssh.TcpTestSucceeded) {
        Write-Host '✓ SSH port (22) is OPEN' -ForegroundColor Green
    } else {
        Write-Host '✗ SSH port (22) not responding' -ForegroundColor Yellow
        Write-Host '  (Services may still be starting)' -ForegroundColor Gray
    }

    # SMB Port Test
    Write-Host ''
    Write-Host '[SMB PORT TEST (445)]' -ForegroundColor Cyan
    $smb = Test-NetConnection -ComputerName "172.21.203.18" -Port 445 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($smb.TcpTestSucceeded) {
        Write-Host '✓ SMB port (445) is OPEN' -ForegroundColor Green
    } else {
        Write-Host '✗ SMB port (445) not responding' -ForegroundColor Yellow
        Write-Host '  (Services may still be starting)' -ForegroundColor Gray
    }
} else {
    Write-Host '✗ PING FAILED - VM not yet responding on network' -ForegroundColor Red
    Write-Host ''

    Write-Host '[ARP CHECK]' -ForegroundColor Cyan
    $arp = arp -a | Select-String "172.21.203.18"
    if ($arp) {
        Write-Host '✓ Found in ARP cache:' -ForegroundColor Green
        Write-Host "  $arp" -ForegroundColor Gray
        Write-Host '  VM has IP but ICMP (ping) is blocked' -ForegroundColor Gray
    } else {
        Write-Host '✗ Not in ARP cache' -ForegroundColor Red
        Write-Host '  VM may not have received DHCP IP yet' -ForegroundColor Yellow
    }
}

# SUMMARY
Write-Host ''
Write-Host '╔════════════════════════════════════════════════╗' -ForegroundColor Green
Write-Host '║           Diagnostic Complete                 ║' -ForegroundColor Green
Write-Host '╚════════════════════════════════════════════════╝' -ForegroundColor Green
Write-Host ''

Write-Host 'SUMMARY:' -ForegroundColor Cyan
Write-Host ''

if ($ping) {
    Write-Host '✓ VM is ONLINE and network accessible!' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Next steps:' -ForegroundColor Yellow
    Write-Host '  1. Run: .\DEPLOY-BABY-NAS-CONFIG.ps1' -ForegroundColor White
    Write-Host '  2. Configure the ZFS pool and datasets' -ForegroundColor White
} else {
    Write-Host '⚠ VM is not yet network accessible' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Possible issues:' -ForegroundColor Yellow

    if ($vm.State -ne "Running") {
        Write-Host "  1. VM not running (State: $($vm.State))" -ForegroundColor White
    }

    if (!$nics -or !$nics.SwitchName) {
        Write-Host "  2. Network adapter not connected to a switch" -ForegroundColor White
    }

    if ($arp) {
        Write-Host "  3. VM has IP but not responding to ping" -ForegroundColor White
        Write-Host "     (Try opening console, VM may be stuck at boot)" -ForegroundColor White
    } else {
        Write-Host "  4. VM didn't receive DHCP IP" -ForegroundColor White
        Write-Host "     (Check if booting properly via console)" -ForegroundColor White
    }

    Write-Host ''
    Write-Host 'Recommended actions:' -ForegroundColor Yellow
    Write-Host "  1. Open console: vmconnect.exe localhost TrueNAS-BabyNAS" -ForegroundColor White
    Write-Host "  2. Check if VM is still booting" -ForegroundColor White
    Write-Host "  3. Wait 2-5 minutes for full TrueNAS boot" -ForegroundColor White
    Write-Host "  4. Re-run this script to check status" -ForegroundColor White
}

Write-Host ''
