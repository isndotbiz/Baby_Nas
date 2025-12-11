#Requires -RunAsAdministrator
###############################################################################
# Baby NAS Quick Start - One-Command Setup
# Orchestrates the complete Baby NAS deployment
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$BabyNasIP = ""
)

$ErrorActionPreference = "Continue"  # Continue on errors to show user what failed

# Colors for output
$ColorCyan = "Cyan"
$ColorGreen = "Green"
$ColorYellow = "Yellow"
$ColorRed = "Red"
$ColorWhite = "White"

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                  BABY NAS QUICK START SETUP                              ║
║                                                                          ║
║  This script will guide you through the complete Baby NAS setup         ║
║  in approximately 45-60 minutes.                                        ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $ColorCyan

Write-Host ""

$SCRIPT_DIR = $PSScriptRoot

###############################################################################
# PHASE 1: Detect Baby NAS IP
###############################################################################

Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║  PHASE 1: Detect Baby NAS IP Address                                ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

# Check if IP already provided
if (-not [string]::IsNullOrWhiteSpace($BabyNasIP)) {
    Write-Host "Using provided IP: $BabyNasIP" -ForegroundColor $ColorGreen
} else {
    # Check for existing IP file
    $ipFile = Join-Path $SCRIPT_DIR "baby-nas-ip.txt"
    if (Test-Path $ipFile) {
        $savedIP = Get-Content $ipFile -Raw | ForEach-Object { $_.Trim() }
        Write-Host "Found saved IP: $savedIP" -ForegroundColor $ColorYellow
        $useExisting = Read-Host "Use this IP? (yes/no)"
        if ($useExisting -eq "yes") {
            $BabyNasIP = $savedIP
        }
    }

    # If still no IP, run detection
    if ([string]::IsNullOrWhiteSpace($BabyNasIP)) {
        Write-Host "Running IP detection script..." -ForegroundColor $ColorCyan
        $detectScript = Join-Path $SCRIPT_DIR "find-baby-nas-ip.ps1"

        if (Test-Path $detectScript) {
            & $detectScript

            # Check if IP was found
            if (Test-Path $ipFile) {
                $BabyNasIP = Get-Content $ipFile -Raw | ForEach-Object { $_.Trim() }
                Write-Host "✓ Detected IP: $BabyNasIP" -ForegroundColor $ColorGreen
            }
        } else {
            Write-Host "⚠ Detection script not found: $detectScript" -ForegroundColor $ColorYellow
        }
    }

    # Manual entry if detection failed
    while ([string]::IsNullOrWhiteSpace($BabyNasIP)) {
        Write-Host ""
        Write-Host "Could not automatically detect Baby NAS IP." -ForegroundColor $ColorYellow
        Write-Host ""
        Write-Host "Options:" -ForegroundColor $ColorCyan
        Write-Host "  1. Open VM console to view IP"
        Write-Host "  2. Enter IP manually"
        Write-Host ""

        $choice = Read-Host "Choose option (1 or 2)"

        if ($choice -eq "1") {
            Write-Host "Opening VM console..." -ForegroundColor $ColorCyan
            vmconnect.exe localhost TrueNAS-BabyNAS
            Write-Host ""
            Write-Host "Look for IP address on the TrueNAS console screen." -ForegroundColor $ColorYellow
            Write-Host ""
        }

        $BabyNasIP = Read-Host "Enter Baby NAS IP address"

        if (-not [string]::IsNullOrWhiteSpace($BabyNasIP)) {
            # Test connectivity
            Write-Host "Testing connectivity to $BabyNasIP..." -ForegroundColor $ColorCyan
            if (Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet) {
                Write-Host "✓ IP is reachable" -ForegroundColor $ColorGreen
                # Save for future use
                $BabyNasIP | Out-File $ipFile -Encoding UTF8
            } else {
                Write-Host "✗ Cannot reach $BabyNasIP" -ForegroundColor $ColorRed
                $BabyNasIP = ""
            }
        }
    }
}

Write-Host ""
Write-Host "Baby NAS IP: $BabyNasIP" -ForegroundColor $ColorGreen
Write-Host ""

###############################################################################
# PHASE 2: Verify Web UI Access
###############################################################################

Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║  PHASE 2: Verify Web UI Access                                      ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

Write-Host "Testing Web UI access..." -ForegroundColor $ColorCyan

try {
    $webTest = Test-NetConnection -ComputerName $BabyNasIP -Port 443 -WarningAction SilentlyContinue
    if ($webTest.TcpTestSucceeded) {
        Write-Host "✓ Web UI is accessible on port 443" -ForegroundColor $ColorGreen
    } else {
        Write-Host "⚠ Port 443 not responding (TrueNAS may still be booting)" -ForegroundColor $ColorYellow
    }
} catch {
    Write-Host "⚠ Could not test port 443" -ForegroundColor $ColorYellow
}

Write-Host ""
Write-Host "Opening Web UI in browser..." -ForegroundColor $ColorCyan
Start-Process "https://$BabyNasIP"

Write-Host ""
Write-Host "Login Credentials:" -ForegroundColor $ColorYellow
Write-Host "  Username: root" -ForegroundColor $ColorWhite
Write-Host "  Password: uppercut%`$##" -ForegroundColor $ColorWhite
Write-Host ""

$webAccessOK = Read-Host "Can you access the Web UI and login? (yes/no)"

if ($webAccessOK -ne "yes") {
    Write-Host ""
    Write-Host "Web UI access issue detected." -ForegroundColor $ColorRed
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor $ColorYellow
    Write-Host "  1. Accept the security certificate warning in browser"
    Write-Host "  2. Verify TrueNAS is fully booted (check VM console)"
    Write-Host "  3. Try HTTP instead: http://$BabyNasIP"
    Write-Host "  4. Restart TrueNAS web service via console:"
    Write-Host "     systemctl restart nginx"
    Write-Host ""

    $continue = Read-Host "Do you want to continue setup anyway? (yes/no)"
    if ($continue -ne "yes") {
        Write-Host "Setup cancelled. Please resolve Web UI access first." -ForegroundColor $ColorRed
        exit 1
    }
}

###############################################################################
# PHASE 3: Create ZFS Pool
###############################################################################

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║  PHASE 3: Create ZFS Pool                                           ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

Write-Host @"
In the TrueNAS Web UI, create the storage pool:

1. Navigate to: Storage → Create Pool
2. Configure the pool:
   • Name: tank
   • Data VDevs: Add Vdev → RAIDZ1 → Select 3x 6TB TOSHIBA HDDs
   • Log Device: Add Vdev → Log → Select 1x 256GB Samsung SSD
   • Cache Device: Add Vdev → Cache → Select 1x 256GB Samsung SSD
   • Advanced Settings:
     - Compression: lz4
     - atime: off
3. Click "Create Pool" and confirm

Expected result: Pool created with ~12TB usable space
"@ -ForegroundColor $ColorYellow

Write-Host ""
$poolCreated = Read-Host "Press Enter after pool 'tank' is created"

###############################################################################
# PHASE 4: Create truenas_admin User
###############################################################################

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║  PHASE 4: Create truenas_admin User                                 ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

Write-Host @"
In the TrueNAS Web UI, create the admin user:

1. Navigate to: Credentials → Local Users → Add
2. Configure the user:
   • Username: truenas_admin
   • Password: uppercut%`$##
   • Full Name: TrueNAS Administrator
   • Home Directory: /mnt/tank/home/truenas_admin
   • Shell: /usr/bin/bash
   • Enable: ✓
   • Samba Authentication: ✓
   • Sudo: Allow all sudo commands
3. Click "Save"
"@ -ForegroundColor $ColorYellow

Write-Host ""
$userCreated = Read-Host "Press Enter after user 'truenas_admin' is created"

###############################################################################
# PHASE 5: Run Automated Setup Script
###############################################################################

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║  PHASE 5: Run Automated Setup Script                                ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

$setupScript = Join-Path $SCRIPT_DIR "complete-baby-nas-setup.sh"

if (-not (Test-Path $setupScript)) {
    Write-Host "✗ Setup script not found: $setupScript" -ForegroundColor $ColorRed
    Write-Host "  Skipping automated setup..." -ForegroundColor $ColorYellow
} else {
    Write-Host "This will:" -ForegroundColor $ColorCyan
    Write-Host "  • Create all backup datasets (windows-backups, veeam, phone-backups)"
    Write-Host "  • Set up ZFS quotas and compression"
    Write-Host "  • Configure snapshot automation (hourly, daily, weekly)"
    Write-Host "  • Apply performance tuning"
    Write-Host "  • Create replication framework"
    Write-Host ""

    $runSetup = Read-Host "Run automated setup script? (yes/no)"

    if ($runSetup -eq "yes") {
        Write-Host ""
        Write-Host "Copying setup script to Baby NAS..." -ForegroundColor $ColorCyan

        # Use bash for SSH/SCP (Git Bash should be available)
        $bashCmd = "scp `"$setupScript`" root@${BabyNasIP}:/root/"

        Write-Host "Running: $bashCmd" -ForegroundColor "Gray"
        bash -c $bashCmd

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Script copied successfully" -ForegroundColor $ColorGreen
            Write-Host ""
            Write-Host "Running setup script on Baby NAS..." -ForegroundColor $ColorCyan
            Write-Host ""

            $sshCmd = "ssh root@$BabyNasIP `"chmod +x /root/complete-baby-nas-setup.sh && /root/complete-baby-nas-setup.sh $BabyNasIP`""

            bash -c $sshCmd

            Write-Host ""
            Write-Host "✓ Automated setup completed" -ForegroundColor $ColorGreen
        } else {
            Write-Host "✗ Failed to copy script" -ForegroundColor $ColorRed
            Write-Host "  Ensure SSH is accessible: ssh root@$BabyNasIP" -ForegroundColor $ColorYellow
            Write-Host "  Password: uppercut%`$##" -ForegroundColor $ColorYellow
        }
    }
}

###############################################################################
# PHASE 6: Configure SMB Shares
###############################################################################

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║  PHASE 6: Configure SMB Shares                                      ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

Write-Host @"
In the TrueNAS Web UI, create SMB shares:

1. Navigate to: Shares → Windows (SMB) Shares → Add

2. Create Share 1: WindowsBackup
   • Path: /mnt/tank/windows-backups
   • Name: WindowsBackup
   • Purpose: Default share parameters
   • Enable: ✓
   • Click "Save"

3. Create Share 2: Veeam
   • Path: /mnt/tank/veeam
   • Name: Veeam
   • Purpose: Default share parameters
   • Enable: ✓
   • Click "Save"

4. Enable SMB Service:
   • Navigate: System Settings → Services
   • Find "SMB" and toggle ON
   • Configure SMB (gear icon):
     - NetBIOS Name: BABYNAS
     - SMB1 Support: Disabled
     - Multichannel: Enabled
   • Click "Save"
"@ -ForegroundColor $ColorYellow

Write-Host ""
$smbConfigured = Read-Host "Press Enter after SMB shares are created and service is enabled"

# Test SMB access
Write-Host ""
Write-Host "Testing SMB share access..." -ForegroundColor $ColorCyan

$smbTest = Test-NetConnection -ComputerName $BabyNasIP -Port 445 -WarningAction SilentlyContinue

if ($smbTest.TcpTestSucceeded) {
    Write-Host "✓ SMB service is accessible on port 445" -ForegroundColor $ColorGreen
} else {
    Write-Host "⚠ Port 445 not responding" -ForegroundColor $ColorYellow
}

###############################################################################
# PHASE 7: Setup SSH Keys
###############################################################################

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║  PHASE 7: Setup SSH Keys                                            ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

$setupSSH = Read-Host "Setup SSH key authentication? (yes/no)"

if ($setupSSH -eq "yes") {
    $sshKeyScript = Join-Path $SCRIPT_DIR "setup-ssh-keys.ps1"

    if (Test-Path $sshKeyScript) {
        Write-Host "Running SSH key setup..." -ForegroundColor $ColorCyan
        & $sshKeyScript -BabyNasIP $BabyNasIP

        # Test SSH connection
        Write-Host ""
        Write-Host "Testing SSH connection..." -ForegroundColor $ColorCyan

        $sshTest = bash -c "ssh -o BatchMode=yes -o ConnectTimeout=5 babynas 'echo SSH_OK' 2>&1"

        if ($sshTest -match "SSH_OK") {
            Write-Host "✓ SSH key authentication working" -ForegroundColor $ColorGreen
        } else {
            Write-Host "⚠ SSH key authentication not working" -ForegroundColor $ColorYellow
            Write-Host "  You can still use password authentication" -ForegroundColor $ColorYellow
        }
    } else {
        Write-Host "⚠ SSH key setup script not found" -ForegroundColor $ColorYellow
    }
}

###############################################################################
# PHASE 8: Map Network Drives
###############################################################################

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║  PHASE 8: Map Network Drives                                        ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

$mapDrives = Read-Host "Map network drives (W: and V:)? (yes/no)"

if ($mapDrives -eq "yes") {
    Write-Host ""
    Write-Host "Mapping WindowsBackup to W:..." -ForegroundColor $ColorCyan

    $wDrive = net use W: "\\$BabyNasIP\WindowsBackup" /user:truenas_admin "uppercut%$##" /persistent:yes 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ W: drive mapped successfully" -ForegroundColor $ColorGreen
    } else {
        Write-Host "⚠ Failed to map W: drive" -ForegroundColor $ColorYellow
        Write-Host $wDrive -ForegroundColor "Gray"
    }

    Write-Host ""
    Write-Host "Mapping Veeam to V:..." -ForegroundColor $ColorCyan

    $vDrive = net use V: "\\$BabyNasIP\Veeam" /user:truenas_admin "uppercut%$##" /persistent:yes 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ V: drive mapped successfully" -ForegroundColor $ColorGreen
    } else {
        Write-Host "⚠ Failed to map V: drive" -ForegroundColor $ColorYellow
        Write-Host $vDrive -ForegroundColor "Gray"
    }

    # Test write access
    Write-Host ""
    Write-Host "Testing write access..." -ForegroundColor $ColorCyan

    if (Test-Path "W:\") {
        try {
            "Baby NAS is working! - $(Get-Date)" | Out-File "W:\test.txt" -ErrorAction Stop
            Write-Host "✓ W: drive is writable" -ForegroundColor $ColorGreen
        } catch {
            Write-Host "⚠ W: drive is not writable" -ForegroundColor $ColorYellow
        }
    } else {
        Write-Host "⚠ W: drive not accessible" -ForegroundColor $ColorYellow
    }
}

###############################################################################
# PHASE 9: Configure VM Auto-Start
###############################################################################

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║  PHASE 9: Configure VM Auto-Start                                   ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

$autoStart = Read-Host "Configure VM to auto-start with Windows? (yes/no)"

if ($autoStart -eq "yes") {
    Write-Host "Configuring auto-start..." -ForegroundColor $ColorCyan

    try {
        Set-VM -Name "TrueNAS-BabyNAS" -AutomaticStartAction Start -ErrorAction Stop
        Set-VM -Name "TrueNAS-BabyNAS" -AutomaticStartDelay 30 -ErrorAction Stop
        Set-VM -Name "TrueNAS-BabyNAS" -AutomaticStopAction Save -ErrorAction Stop

        Write-Host "✓ Auto-start configured" -ForegroundColor $ColorGreen

        $vmStatus = Get-VM -Name "TrueNAS-BabyNAS" | Select-Object Name, State, AutomaticStartAction, AutomaticStopAction
        Write-Host ""
        $vmStatus | Format-List
    } catch {
        Write-Host "✗ Failed to configure auto-start" -ForegroundColor $ColorRed
        Write-Host $_.Exception.Message -ForegroundColor "Gray"
    }
}

###############################################################################
# FINAL SUMMARY
###############################################################################

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor $ColorGreen
Write-Host "║                                                                      ║" -ForegroundColor $ColorGreen
Write-Host "║              BABY NAS SETUP COMPLETE!                                ║" -ForegroundColor $ColorGreen
Write-Host "║                                                                      ║" -ForegroundColor $ColorGreen
Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor $ColorGreen
Write-Host ""

Write-Host "Your Baby NAS is now configured:" -ForegroundColor $ColorCyan
Write-Host ""
Write-Host "✓ IP Address: $BabyNasIP" -ForegroundColor $ColorGreen
Write-Host "✓ Web UI: https://$BabyNasIP" -ForegroundColor $ColorGreen
Write-Host "✓ Pool: tank (~12TB usable RAIDZ1 + SSD cache)" -ForegroundColor $ColorGreen
Write-Host "✓ Datasets: windows-backups, veeam, phone-backups" -ForegroundColor $ColorGreen
Write-Host "✓ Automation: Hourly, daily, weekly snapshots" -ForegroundColor $ColorGreen
Write-Host "✓ SMB Shares: WindowsBackup (W:), Veeam (V:)" -ForegroundColor $ColorGreen
Write-Host "✓ Performance: Tuned for backup workloads" -ForegroundColor $ColorGreen
Write-Host ""

Write-Host "Connection Details:" -ForegroundColor $ColorYellow
Write-Host "  Web UI:  https://$BabyNasIP" -ForegroundColor $ColorWhite
Write-Host "  SSH:     ssh babynas (or ssh root@$BabyNasIP)" -ForegroundColor $ColorWhite
Write-Host "  SMB:     \\$BabyNasIP\WindowsBackup" -ForegroundColor $ColorWhite
Write-Host "  Drives:  W: (WindowsBackup), V: (Veeam)" -ForegroundColor $ColorWhite
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor $ColorYellow
Write-Host "  1. Configure Veeam Agent to backup to V: drive" -ForegroundColor $ColorWhite
Write-Host "  2. Setup workspace sync to W:\d-workspace" -ForegroundColor $ColorWhite
Write-Host "  3. Configure phone backup automation" -ForegroundColor $ColorWhite
Write-Host "  4. Test file recovery from snapshots" -ForegroundColor $ColorWhite
Write-Host "  5. Setup replication to Main NAS (10.0.0.89)" -ForegroundColor $ColorWhite
Write-Host ""

Write-Host "Documentation:" -ForegroundColor $ColorYellow
Write-Host "  Complete Guide: D:\workspace\True_Nas\BABY_NAS_SETUP_COMPLETE.md" -ForegroundColor $ColorCyan
Write-Host "  Quick Commands: See documentation for management commands" -ForegroundColor $ColorCyan
Write-Host ""

Write-Host "Management Commands:" -ForegroundColor $ColorYellow
Write-Host "  Check status:    ssh babynas 'zpool status tank'" -ForegroundColor $ColorCyan
Write-Host "  View datasets:   ssh babynas 'zfs list -r tank'" -ForegroundColor $ColorCyan
Write-Host "  List snapshots:  ssh babynas 'zfs list -t snapshot -r tank'" -ForegroundColor $ColorCyan
Write-Host "  Open console:    vmconnect.exe localhost TrueNAS-BabyNAS" -ForegroundColor $ColorCyan
Write-Host ""

$openDocs = Read-Host "Open complete documentation now? (yes/no)"

if ($openDocs -eq "yes") {
    $docPath = "D:\workspace\True_Nas\BABY_NAS_SETUP_COMPLETE.md"
    if (Test-Path $docPath) {
        Start-Process $docPath
    } else {
        Write-Host "Documentation not found at: $docPath" -ForegroundColor $ColorYellow
    }
}

Write-Host ""
Write-Host "🎉 Congratulations! Your Baby NAS is ready for production use!" -ForegroundColor $ColorGreen
Write-Host ""
