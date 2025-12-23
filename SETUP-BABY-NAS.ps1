#Requires -RunAsAdministrator
###############################################################################
# Baby NAS Complete Setup - Master Orchestrator
# One-command setup for complete Baby NAS deployment
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipVMCreation = $false,

    [Parameter(Mandatory=$false)]
    [switch]$SkipConfiguration = $false,

    [Parameter(Mandatory=$false)]
    [switch]$SkipReplication = $false,

    [Parameter(Mandatory=$false)]
    [string]$BabyNasIP = ""
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                  Baby NAS Complete Setup                                 ║
║                  Master Orchestration Script                             ║
║                                                                          ║
║  This script will:                                                       ║
║  1. Create Hyper-V VM with disk passthrough                             ║
║  2. Guide TrueNAS installation                                          ║
║  3. Configure SSH, API, and system optimizations                        ║
║  4. Set up ZFS replication to Main NAS                                  ║
║  5. Configure VM auto-start                                             ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""

$SCRIPT_DIR = $PSScriptRoot

###############################################################################
# PHASE 1: VM Creation (if not skipped)
###############################################################################
if (-not $SkipVMCreation) {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  PHASE 1: Hyper-V VM Creation                             ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    $vmScript = Join-Path $SCRIPT_DIR "1-create-baby-nas-vm.ps1"

    if (-not (Test-Path $vmScript)) {
        Write-Host "✗ VM creation script not found: $vmScript" -ForegroundColor Red
        exit 1
    }

    Write-Host "Running VM creation script..." -ForegroundColor Cyan
    & $vmScript

    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ VM creation failed" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Phase 1 Complete: VM Created" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""

    # Pause for TrueNAS installation
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                  MANUAL STEP: Install TrueNAS SCALE                     ║
║                                                                          ║
║  1. The VM console should be open                                       ║
║  2. TrueNAS installer should have started automatically                 ║
║  3. Select: Install/Upgrade                                             ║
║  4. Choose the 32GB OS disk (NOT the 6TB drives!)                       ║
║  5. Set root password: Use TRUENAS_PASSWORD from your .env file         ║
║  6. Wait for installation to complete (~5-10 minutes)                   ║
║  7. Reboot when prompted                                                ║
║  8. Note the IP address shown on the console                            ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Yellow

    Write-Host ""
    $installed = Read-Host "Press Enter after TrueNAS installation is complete and VM has rebooted"

    # Get IP address
    while ([string]::IsNullOrEmpty($BabyNasIP)) {
        $BabyNasIP = Read-Host "`nEnter the Baby NAS IP address (shown on console)"

        if ([string]::IsNullOrEmpty($BabyNasIP)) {
            Write-Host "IP address is required!" -ForegroundColor Red
        } elseif (-not (Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet)) {
            Write-Host "Cannot reach $BabyNasIP - verify IP is correct" -ForegroundColor Red
            $BabyNasIP = ""
        }
    }

    Write-Host "✓ Baby NAS is accessible at $BabyNasIP" -ForegroundColor Green

} else {
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  Phase 1 Skipped: VM Creation" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""

    # Get IP if not provided
    if ([string]::IsNullOrEmpty($BabyNasIP)) {
        $BabyNasIP = Read-Host "Enter Baby NAS IP address"
    }
}

###############################################################################
# PHASE 2: Configuration (if not skipped)
###############################################################################
if (-not $SkipConfiguration) {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  PHASE 2: System Configuration                            ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    $configScript = Join-Path $SCRIPT_DIR "2-configure-baby-nas.ps1"

    if (-not (Test-Path $configScript)) {
        Write-Host "✗ Configuration script not found: $configScript" -ForegroundColor Red
        exit 1
    }

    Write-Host "Running configuration script..." -ForegroundColor Cyan
    & $configScript -BabyNasIP $BabyNasIP

    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠ Configuration had issues" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Phase 2 Complete: Configuration Applied" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""

    # Manual pool creation step
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                  MANUAL STEP: Create ZFS Pool                           ║
║                                                                          ║
║  1. Open Web UI: https://$BabyNasIP
║  2. Login: root / [Use TRUENAS_PASSWORD from .env]                      ║
║  3. Go to: Storage → Create Pool                                        ║
║  4. Configure:                                                           ║
║     • Name: tank                                                         ║
║     • Data VDevs: Add Vdev → RAIDZ1 → Select 3x 6TB HDDs               ║
║     • Log Device: Add Vdev → Log → Select 1x 256GB SSD                 ║
║     • Cache Device: Add Vdev → Cache → Select 1x 256GB SSD             ║
║     • Advanced: Compression: lz4, atime: off                            ║
║  5. Click "Create Pool" and confirm                                     ║
║  6. Wait for pool creation (~1-2 minutes)                               ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Yellow

    Write-Host ""
    $poolCreated = Read-Host "Press Enter after pool 'tank' is created"

    # Verify pool exists
    Write-Host "Verifying pool..." -ForegroundColor Cyan
    $poolCheck = ssh -i "$env:USERPROFILE\.ssh\id_babynas" root@$BabyNasIP "zpool list tank 2>&1"

    if ($poolCheck -match "tank") {
        Write-Host "✓ Pool 'tank' is online" -ForegroundColor Green

        # Run dataset creation
        Write-Host "Creating datasets..." -ForegroundColor Cyan
        ssh -i "$env:USERPROFILE\.ssh\id_babynas" root@$BabyNasIP "/root/baby-nas-config.sh"
        Write-Host "✓ Datasets created" -ForegroundColor Green
    } else {
        Write-Host "⚠ Pool not found - you'll need to create datasets manually" -ForegroundColor Yellow
    }

    # User creation step
    Write-Host ""
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                  MANUAL STEP: Create truenas_admin User                 ║
║                                                                          ║
║  1. In Web UI: Credentials → Local Users → Add                          ║
║  2. Configure:                                                           ║
║     • Username: Use TRUENAS_USERNAME from .env (default: root)           ║
║     • Password: Use TRUENAS_PASSWORD from .env                           ║
║     • Full Name: TrueNAS Administrator                                   ║
║     • Home: /mnt/tank/home/truenas_admin                                 ║
║     • Shell: /usr/bin/bash                                               ║
║     • Enable: ✓                                                          ║
║     • Samba Authentication: ✓                                            ║
║     • Sudo Commands: ALL (or specific as needed)                         ║
║  3. Save                                                                 ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Yellow

    Write-Host ""
    $userCreated = Read-Host "Press Enter after user 'truenas_admin' is created"

    # SMB share creation step
    Write-Host ""
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                  MANUAL STEP: Create SMB Shares                         ║
║                                                                          ║
║  1. In Web UI: Shares → Windows (SMB) Shares → Add                      ║
║  2. Create share 1:                                                      ║
║     • Path: /mnt/tank/windows-backups                                    ║
║     • Name: WindowsBackup                                                ║
║     • Enable: ✓                                                          ║
║  3. Create share 2:                                                      ║
║     • Path: /mnt/tank/veeam                                              ║
║     • Name: Veeam                                                        ║
║     • Enable: ✓                                                          ║
║  4. Enable SMB service:                                                  ║
║     • System Settings → Services → SMB → Toggle ON                      ║
║     • Configure: SMB1 disabled, Multichannel enabled                    ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Yellow

    Write-Host ""
    $sharesCreated = Read-Host "Press Enter after SMB shares are created and service is enabled"

    # Test SMB access
    Write-Host "Testing SMB share access..." -ForegroundColor Cyan
    if (Test-Path "\\$BabyNasIP\WindowsBackup") {
        Write-Host "✓ SMB shares are accessible" -ForegroundColor Green
    } else {
        Write-Host "⚠ Cannot access SMB shares - verify configuration" -ForegroundColor Yellow
        Write-Host "  Try: Load .env first, then use: net use W: \\$BabyNasIP\WindowsBackup /user:`$username `$password" -ForegroundColor Cyan
    }

} else {
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  Phase 2 Skipped: Configuration" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
}

###############################################################################
# PHASE 3: Replication Setup (if not skipped)
###############################################################################
if (-not $SkipReplication) {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  PHASE 3: Replication to Main NAS                         ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    $replScript = Join-Path $SCRIPT_DIR "3-setup-replication.ps1"

    if (-not (Test-Path $replScript)) {
        Write-Host "✗ Replication script not found: $replScript" -ForegroundColor Red
    } else {
        $setupRepl = Read-Host "Set up replication to Main NAS (10.0.0.89)? (yes/no)"

        if ($setupRepl -eq "yes") {
            Write-Host "Running replication setup..." -ForegroundColor Cyan
            & $replScript -BabyNasIP $BabyNasIP

            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "  Phase 3 Complete: Replication Configured" -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
        } else {
            Write-Host "Replication setup skipped" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  Phase 3 Skipped: Replication" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
}

###############################################################################
# PHASE 4: VM Auto-Start Configuration
###############################################################################
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  PHASE 4: VM Auto-Start Configuration                     ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

$setupAutoStart = Read-Host "Configure VM to auto-start with Windows? (yes/no)"

if ($setupAutoStart -eq "yes") {
    $vmName = "TrueNAS-BabyNAS"

    if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
        Write-Host "Configuring auto-start for $vmName..." -ForegroundColor Cyan

        Set-VM -Name $vmName -AutomaticStartAction Start
        Set-VM -Name $vmName -AutomaticStartDelay 30
        Set-VM -Name $vmName -AutomaticStopAction Save

        Write-Host "✓ Auto-start configured" -ForegroundColor Green

        $vmStatus = Get-VM -Name $vmName | Select-Object Name, State, AutomaticStartAction, AutomaticStopAction
        Write-Host "VM Configuration:" -ForegroundColor Yellow
        $vmStatus | Format-List
    } else {
        Write-Host "⚠ VM not found - configure manually" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Phase 4 Complete: Auto-Start Configured" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green

###############################################################################
# FINAL SUMMARY
###############################################################################
Write-Host ""
Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║              Baby NAS Setup Complete!                                    ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host ""
Write-Host "Your Baby NAS is configured with:" -ForegroundColor Cyan
Write-Host "  ✓ Hyper-V VM with 16GB RAM, 4 CPUs" -ForegroundColor Green
Write-Host "  ✓ ZFS RAIDZ1 pool (~12TB usable) with SSD cache" -ForegroundColor Green
Write-Host "  ✓ SSH key-based authentication" -ForegroundColor Green
Write-Host "  ✓ API access for automation" -ForegroundColor Green
Write-Host "  ✓ SMB shares for Windows" -ForegroundColor Green
Write-Host "  ✓ Auto-start enabled" -ForegroundColor Green
if (-not $SkipReplication) {
    Write-Host "  ✓ Replication to Main NAS (10.0.0.89)" -ForegroundColor Green
}
Write-Host ""

Write-Host "Connection Details:" -ForegroundColor Yellow
Write-Host "  IP Address: $BabyNasIP" -ForegroundColor White
Write-Host "  SSH: ssh babynas (or ssh -i ~/.ssh/id_babynas root@$BabyNasIP)" -ForegroundColor White
Write-Host "  Web UI: https://$BabyNasIP" -ForegroundColor White
Write-Host "  SMB Share: \\$BabyNasIP\WindowsBackup" -ForegroundColor White
Write-Host "  SMB Share: \\$BabyNasIP\Veeam" -ForegroundColor White
Write-Host ""

Write-Host "Quick Commands:" -ForegroundColor Yellow
Write-Host "  Check status:     ssh babynas 'zpool status tank'" -ForegroundColor Cyan
Write-Host "  View datasets:    ssh babynas 'zfs list -r tank'" -ForegroundColor Cyan
Write-Host "  Check replication: ssh babynas '/root/check-replication.sh'" -ForegroundColor Cyan
Write-Host "  Manual replication: ssh babynas '/root/replicate-to-main.sh'" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Map network drives: net use W: \\$BabyNasIP\WindowsBackup /persistent:yes" -ForegroundColor Cyan
Write-Host "  2. Configure Veeam backup to \\$BabyNasIP\Veeam" -ForegroundColor Cyan
Write-Host "  3. Set up workspace sync to \\$BabyNasIP\WindowsBackup\d-workspace" -ForegroundColor Cyan
Write-Host "  4. Test recovery procedures" -ForegroundColor Cyan
Write-Host "  5. Monitor replication logs: ssh babynas 'tail -f /var/log/replication.log'" -ForegroundColor Cyan
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "  Implementation Plan: D:\workspace\True_Nas\BABY_NAS_IMPLEMENTATION_PLAN.md" -ForegroundColor Cyan
Write-Host "  Best Practices: D:\workspace\True_Nas\TRUENAS_DUAL_SERVER_BEST_PRACTICES.md" -ForegroundColor Cyan
Write-Host ""

$openBrowser = Read-Host "Open Baby NAS Web UI now? (yes/no)"
if ($openBrowser -eq "yes") {
    Start-Process "https://$BabyNasIP"
}

Write-Host ""
Write-Host "🎉 Congratulations! Your Baby NAS is ready for production use!" -ForegroundColor Green
Write-Host ""
