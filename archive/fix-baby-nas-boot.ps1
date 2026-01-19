#Requires -RunAsAdministrator
###############################################################################
# Baby NAS VM Boot Fix
# Diagnoses and fixes boot issues with TrueNAS-BabyNAS VM
###############################################################################

$VMName = "TrueNAS-BabyNAS"

Write-Host "=== Baby NAS VM Boot Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# Check if VM exists
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Host "✗ VM not found: $VMName" -ForegroundColor Red
    exit 1
}

Write-Host "✓ VM exists: $VMName" -ForegroundColor Green
Write-Host "  State: $($vm.State)" -ForegroundColor White
Write-Host "  Status: $($vm.Status)" -ForegroundColor White
Write-Host ""

# Check DVD drive and ISO
Write-Host "=== Checking DVD Drive ===" -ForegroundColor Cyan
$dvd = Get-VMDvdDrive -VMName $VMName

if ($dvd) {
    Write-Host "✓ DVD drive attached" -ForegroundColor Green
    if ($dvd.Path) {
        Write-Host "  ISO: $($dvd.Path)" -ForegroundColor White
        if (Test-Path $dvd.Path) {
            Write-Host "  ✓ ISO file exists" -ForegroundColor Green
        } else {
            Write-Host "  ✗ ISO file not found!" -ForegroundColor Red

            # Try to find ISO
            Write-Host ""
            Write-Host "Searching for TrueNAS ISO..." -ForegroundColor Yellow
            $searchPaths = @(
                "D:\ISOs\TrueNAS*.iso",
                "C:\ISOs\TrueNAS*.iso",
                "$env:USERPROFILE\Downloads\TrueNAS*.iso"
            )

            foreach ($pattern in $searchPaths) {
                $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    Write-Host "  Found: $($found.FullName)" -ForegroundColor Green
                    Write-Host "  Attaching ISO..." -ForegroundColor Cyan
                    Set-VMDvdDrive -VMName $VMName -Path $found.FullName
                    Write-Host "  ✓ ISO attached" -ForegroundColor Green
                    break
                }
            }
        }
    } else {
        Write-Host "  ⚠ No ISO attached to DVD drive" -ForegroundColor Yellow

        # Try to find and attach ISO
        Write-Host ""
        Write-Host "Searching for TrueNAS ISO..." -ForegroundColor Yellow
        $searchPaths = @(
            "D:\ISOs\TrueNAS*.iso",
            "C:\ISOs\TrueNAS*.iso",
            "$env:USERPROFILE\Downloads\TrueNAS*.iso"
        )

        $found = $false
        foreach ($pattern in $searchPaths) {
            $iso = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($iso) {
                Write-Host "  Found: $($iso.FullName)" -ForegroundColor Green
                Write-Host "  Attaching ISO..." -ForegroundColor Cyan
                Set-VMDvdDrive -VMName $VMName -Path $iso.FullName
                Write-Host "  ✓ ISO attached" -ForegroundColor Green
                $found = $true
                break
            }
        }

        if (-not $found) {
            Write-Host "  ✗ TrueNAS ISO not found!" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please download TrueNAS SCALE ISO from:" -ForegroundColor Yellow
            Write-Host "  https://www.truenas.com/download-truenas-scale/" -ForegroundColor Cyan
            Write-Host ""
            $manualPath = Read-Host "Enter path to TrueNAS ISO (or press Enter to skip)"
            if (-not [string]::IsNullOrEmpty($manualPath) -and (Test-Path $manualPath)) {
                Set-VMDvdDrive -VMName $VMName -Path $manualPath
                Write-Host "  ✓ ISO attached" -ForegroundColor Green
            }
        }
    }
} else {
    Write-Host "✗ No DVD drive found" -ForegroundColor Red
    Write-Host "  Adding DVD drive..." -ForegroundColor Cyan
    Add-VMDvdDrive -VMName $VMName
    Write-Host "  ✓ DVD drive added" -ForegroundColor Green
}

Write-Host ""

# Check hard disks
Write-Host "=== Checking Hard Disks ===" -ForegroundColor Cyan
$disks = Get-VMHardDiskDrive -VMName $VMName | Sort-Object ControllerLocation

Write-Host "Attached disks:" -ForegroundColor White
foreach ($disk in $disks) {
    $sizeGB = if ($disk.Path -match "\.vhdx?$") {
        $vhd = Get-VHD -Path $disk.Path -ErrorAction SilentlyContinue
        if ($vhd) { [math]::Round($vhd.Size / 1GB, 2) } else { "?" }
    } else {
        "Physical"
    }
    Write-Host "  • Controller $($disk.ControllerType) $($disk.ControllerNumber):$($disk.ControllerLocation) - $sizeGB GB" -ForegroundColor Gray
    if ($disk.Path) {
        Write-Host "    Path: $($disk.Path)" -ForegroundColor DarkGray
    }
}

$expectedDisks = 6  # 1 OS + 3 data + 2 cache
if ($disks.Count -ne $expectedDisks) {
    Write-Host "  ⚠ Expected $expectedDisks disks, found $($disks.Count)" -ForegroundColor Yellow
}

Write-Host ""

# Check boot order
Write-Host "=== Checking Boot Order ===" -ForegroundColor Cyan
$firmware = Get-VMFirmware -VMName $VMName

Write-Host "First boot device: $($firmware.BootOrder[0].BootType) - $($firmware.BootOrder[0].Device)" -ForegroundColor White

# Set DVD as first boot device
$dvd = Get-VMDvdDrive -VMName $VMName
if ($dvd) {
    Write-Host "Setting DVD as first boot device..." -ForegroundColor Cyan
    Set-VMFirmware -VMName $VMName -FirstBootDevice $dvd
    Write-Host "✓ Boot order updated" -ForegroundColor Green
}

Write-Host ""

# Check network adapter
Write-Host "=== Checking Network ===" -ForegroundColor Cyan
$netAdapter = Get-VMNetworkAdapter -VMName $VMName

if ($netAdapter) {
    Write-Host "✓ Network adapter attached" -ForegroundColor Green
    Write-Host "  Switch: $($netAdapter.SwitchName)" -ForegroundColor White
    Write-Host "  MAC Spoofing: $($netAdapter.MacAddressSpoofing)" -ForegroundColor White
} else {
    Write-Host "✗ No network adapter found" -ForegroundColor Red
}

Write-Host ""

# Summary and action
Write-Host "=== Ready to Start VM ===" -ForegroundColor Green
Write-Host ""

$dvdCheck = Get-VMDvdDrive -VMName $VMName
if ($dvdCheck.Path -and (Test-Path $dvdCheck.Path)) {
    Write-Host "✓ Configuration looks good!" -ForegroundColor Green
    Write-Host ""
    Write-Host "VM will boot from: $($dvdCheck.Path)" -ForegroundColor Cyan
    Write-Host ""

    $start = Read-Host "Start VM now? (yes/no)"

    if ($start -eq "yes") {
        Write-Host ""
        Write-Host "Starting VM..." -ForegroundColor Cyan
        Start-VM -Name $VMName

        Write-Host "Waiting for VM to start..." -ForegroundColor Cyan
        Start-Sleep -Seconds 5

        $vmState = (Get-VM -Name $VMName).State
        Write-Host "VM State: $vmState" -ForegroundColor White

        if ($vmState -eq "Running") {
            Write-Host "✓ VM is running!" -ForegroundColor Green
            Write-Host ""

            $openConsole = Read-Host "Open VM console? (yes/no)"
            if ($openConsole -eq "yes") {
                vmconnect.exe localhost $VMName
            }

            Write-Host ""
            Write-Host "=== Next Steps ===" -ForegroundColor Yellow
            Write-Host "1. In the VM console, you should see TrueNAS boot menu" -ForegroundColor White
            Write-Host "2. Select: Install/Upgrade" -ForegroundColor White
            Write-Host "3. Choose the 32GB OS disk (smallest disk)" -ForegroundColor White
            Write-Host "4. Set root password: uppercut%`$##" -ForegroundColor White
            Write-Host "5. Wait for installation (~5-10 minutes)" -ForegroundColor White
            Write-Host "6. Reboot when prompted" -ForegroundColor White
            Write-Host "7. Note the IP address shown after reboot" -ForegroundColor White
            Write-Host ""
        } else {
            Write-Host "⚠ VM didn't start properly. State: $vmState" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Try opening the console manually:" -ForegroundColor Cyan
            Write-Host "  vmconnect.exe localhost $VMName" -ForegroundColor White
            Write-Host ""
            Write-Host "Or check Hyper-V Manager for error details" -ForegroundColor Cyan
        }
    } else {
        Write-Host ""
        Write-Host "To start manually:" -ForegroundColor Yellow
        Write-Host "  Start-VM -Name '$VMName'" -ForegroundColor Cyan
        Write-Host "  vmconnect.exe localhost '$VMName'" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠ No ISO attached or ISO file not found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "1. Download TrueNAS SCALE ISO" -ForegroundColor White
    Write-Host "2. Run this script again" -ForegroundColor White
    Write-Host "   OR" -ForegroundColor Yellow
    Write-Host "3. Attach manually:" -ForegroundColor White
    Write-Host "   Set-VMDvdDrive -VMName '$VMName' -Path 'path\to\truenas.iso'" -ForegroundColor Cyan
}

Write-Host ""
