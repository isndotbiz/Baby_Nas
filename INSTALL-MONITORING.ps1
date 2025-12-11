#Requires -RunAsAdministrator
###############################################################################
# Baby NAS Monitoring System - Installation Script
# Purpose: Install and configure the comprehensive monitoring system
# Usage: .\INSTALL-MONITORING.ps1 [-InstallWebDashboard] [-InstallTrayApp] [-ConfigureScheduledTasks]
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [switch]$InstallWebDashboard,

    [Parameter(Mandatory=$false)]
    [switch]$InstallTrayApp,

    [Parameter(Mandatory=$false)]
    [switch]$ConfigureScheduledTasks,

    [Parameter(Mandatory=$false)]
    [switch]$InstallAll
)

$ErrorActionPreference = "Stop"

###############################################################################
# BANNER
###############################################################################

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║              Baby NAS Monitoring System - Installation                   ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

if ($InstallAll) {
    $InstallWebDashboard = $true
    $InstallTrayApp = $true
    $ConfigureScheduledTasks = $true
}

###############################################################################
# FUNCTIONS
###############################################################################

function Write-InstallLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR','SECTION')]
        [string]$Level = 'INFO'
    )

    $color = switch ($Level) {
        'INFO'    { 'Cyan' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        'SECTION' { 'Magenta' }
    }

    $symbol = switch ($Level) {
        'SUCCESS' { '[+]' }
        'WARNING' { '[!]' }
        'ERROR'   { '[X]' }
        'SECTION' { '===' }
        'INFO'    { '[i]' }
    }

    if ($Level -eq 'SECTION') {
        Write-Host ""
        Write-Host "$symbol $Message $symbol" -ForegroundColor $color
        Write-Host ""
    } else {
        Write-Host "$symbol $Message" -ForegroundColor $color
    }
}

###############################################################################
# STEP 1: VERIFY PREREQUISITES
###############################################################################

Write-InstallLog "Step 1: Verify Prerequisites" -Level SECTION

Write-InstallLog "Checking PowerShell version..." -Level INFO
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 5) {
    Write-InstallLog "PowerShell 5.0 or higher required. Current: $psVersion" -Level ERROR
    exit 1
}
Write-InstallLog "PowerShell version: $psVersion" -Level SUCCESS

Write-InstallLog "Checking Hyper-V module..." -Level INFO
if (Get-Module -ListAvailable -Name Hyper-V) {
    Write-InstallLog "Hyper-V module available" -Level SUCCESS
} else {
    Write-InstallLog "Hyper-V module not found (optional, but recommended)" -Level WARNING
}

Write-InstallLog "Checking administrator privileges..." -Level INFO
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-InstallLog "This script must be run as Administrator" -Level ERROR
    exit 1
}
Write-InstallLog "Running with administrator privileges" -Level SUCCESS

###############################################################################
# STEP 2: CREATE DIRECTORY STRUCTURE
###############################################################################

Write-InstallLog "Step 2: Create Directory Structure" -Level SECTION

$directories = @(
    "C:\Logs\baby-nas-monitoring",
    "$PSScriptRoot\..\monitoring\web",
    "$PSScriptRoot\..\monitoring\reports"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        Write-InstallLog "Creating directory: $dir" -Level INFO
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-InstallLog "Created: $dir" -Level SUCCESS
    } else {
        Write-InstallLog "Already exists: $dir" -Level INFO
    }
}

###############################################################################
# STEP 3: VERIFY CONFIGURATION FILE
###############################################################################

Write-InstallLog "Step 3: Verify Configuration File" -Level SECTION

$configPath = "$PSScriptRoot\monitoring-config.json"

if (Test-Path $configPath) {
    Write-InstallLog "Configuration file found: $configPath" -Level SUCCESS

    # Validate JSON
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        Write-InstallLog "Configuration file is valid JSON" -Level SUCCESS
    } catch {
        Write-InstallLog "Configuration file has invalid JSON: $($_.Exception.Message)" -Level ERROR
        exit 1
    }
} else {
    Write-InstallLog "Configuration file not found: $configPath" -Level ERROR
    Write-InstallLog "Please ensure monitoring-config.json exists" -Level ERROR
    exit 1
}

###############################################################################
# STEP 4: VERIFY REQUIRED SCRIPTS
###############################################################################

Write-InstallLog "Step 4: Verify Required Scripts" -Level SECTION

$requiredScripts = @(
    "monitor-baby-nas.ps1",
    "START-MONITORING.ps1",
    "dashboard.ps1",
    "send-webhook-alert.ps1"
)

$missingScripts = @()

foreach ($script in $requiredScripts) {
    $scriptPath = Join-Path $PSScriptRoot $script
    if (Test-Path $scriptPath) {
        Write-InstallLog "Found: $script" -Level SUCCESS
    } else {
        Write-InstallLog "Missing: $script" -Level ERROR
        $missingScripts += $script
    }
}

if ($missingScripts.Count -gt 0) {
    Write-InstallLog "Missing $($missingScripts.Count) required script(s)" -Level ERROR
    exit 1
}

###############################################################################
# STEP 5: CONFIGURE BABY NAS IP
###############################################################################

Write-InstallLog "Step 5: Configure Baby NAS IP" -Level SECTION

Write-InstallLog "Attempting to auto-detect Baby NAS IP..." -Level INFO

try {
    $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1

    if ($vm) {
        Write-InstallLog "Found VM: $($vm.Name)" -Level SUCCESS

        $vmNet = Get-VMNetworkAdapter -VM $vm
        if ($vmNet.IPAddresses) {
            $babyNasIP = ($vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)

            if ($babyNasIP) {
                Write-InstallLog "Detected Baby NAS IP: $babyNasIP" -Level SUCCESS

                # Update config
                $config.babyNAS.ip = $babyNasIP
                $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
                Write-InstallLog "Updated configuration with Baby NAS IP" -Level SUCCESS
            } else {
                Write-InstallLog "Could not determine IP address from VM" -Level WARNING
            }
        }
    } else {
        Write-InstallLog "Baby NAS VM not found" -Level WARNING
    }
} catch {
    Write-InstallLog "Error detecting Baby NAS: $($_.Exception.Message)" -Level WARNING
}

###############################################################################
# STEP 6: INSTALL WEB DASHBOARD (Optional)
###############################################################################

if ($InstallWebDashboard) {
    Write-InstallLog "Step 6: Install Web Dashboard" -Level SECTION

    $webDir = "$PSScriptRoot\..\monitoring\web"

    $webFiles = @("index.html", "style.css", "dashboard.js")
    $missingWebFiles = @()

    foreach ($file in $webFiles) {
        $filePath = Join-Path $webDir $file
        if (Test-Path $filePath) {
            Write-InstallLog "Found: $file" -Level SUCCESS
        } else {
            Write-InstallLog "Missing: $file" -Level ERROR
            $missingWebFiles += $file
        }
    }

    if ($missingWebFiles.Count -eq 0) {
        Write-InstallLog "Web dashboard files are ready" -Level SUCCESS
        Write-InstallLog "Start with: .\START-MONITORING.ps1 -WebDashboard" -Level INFO
    } else {
        Write-InstallLog "Missing $($missingWebFiles.Count) web dashboard file(s)" -Level WARNING
    }
}

###############################################################################
# STEP 7: INSTALL TRAY APP (Optional)
###############################################################################

if ($InstallTrayApp) {
    Write-InstallLog "Step 7: Install System Tray App" -Level SECTION

    $trayScript = "$PSScriptRoot\tray-notification-app.ps1"

    if (Test-Path $trayScript) {
        Write-InstallLog "Tray app script found" -Level SUCCESS

        # Create startup shortcut
        $startupFolder = [Environment]::GetFolderPath('Startup')
        $shortcutPath = Join-Path $startupFolder "BabyNAS-Monitor.lnk"

        try {
            $wsh = New-Object -ComObject WScript.Shell
            $shortcut = $wsh.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = "powershell.exe"
            $shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$trayScript`""
            $shortcut.WorkingDirectory = $PSScriptRoot
            $shortcut.Description = "Baby NAS Monitoring Tray App"
            $shortcut.Save()

            Write-InstallLog "Created startup shortcut: $shortcutPath" -Level SUCCESS
            Write-InstallLog "Tray app will start automatically on login" -Level INFO
        } catch {
            Write-InstallLog "Failed to create startup shortcut: $($_.Exception.Message)" -Level WARNING
        }

        # Ask if user wants to start now
        Write-Host ""
        $startNow = Read-Host "Start tray app now? (Y/N)"
        if ($startNow -eq 'Y' -or $startNow -eq 'y') {
            try {
                Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$trayScript`""
                Write-InstallLog "Tray app started" -Level SUCCESS
            } catch {
                Write-InstallLog "Failed to start tray app: $($_.Exception.Message)" -Level WARNING
            }
        }
    } else {
        Write-InstallLog "Tray app script not found: $trayScript" -Level WARNING
    }
}

###############################################################################
# STEP 8: CONFIGURE SCHEDULED TASKS (Optional)
###############################################################################

if ($ConfigureScheduledTasks) {
    Write-InstallLog "Step 8: Configure Scheduled Tasks" -Level SECTION

    # Task 1: Daily Health Check
    $taskName = "Baby NAS - Daily Health Check"
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if ($existingTask) {
        Write-InstallLog "Scheduled task already exists: $taskName" -Level INFO
        $overwrite = Read-Host "Overwrite existing task? (Y/N)"
        if ($overwrite -ne 'Y' -and $overwrite -ne 'y') {
            Write-InstallLog "Skipping scheduled task creation" -Level INFO
        } else {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            $existingTask = $null
        }
    }

    if (-not $existingTask) {
        try {
            $action = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\daily-health-check.ps1`""

            $trigger = New-ScheduledTaskTrigger -Daily -At "8:00AM"

            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                -StartWhenAvailable -RunOnlyIfNetworkAvailable

            Register-ScheduledTask -TaskName $taskName `
                -Action $action `
                -Trigger $trigger `
                -Principal $principal `
                -Settings $settings `
                -Description "Daily health check for Baby NAS system" | Out-Null

            Write-InstallLog "Created scheduled task: $taskName" -Level SUCCESS
            Write-InstallLog "Runs daily at 8:00 AM" -Level INFO
        } catch {
            Write-InstallLog "Failed to create scheduled task: $($_.Exception.Message)" -Level WARNING
        }
    }
}

###############################################################################
# STEP 9: DEPLOY TO BABY NAS (Optional)
###############################################################################

Write-InstallLog "Step 9: Deploy Monitoring Daemon to Baby NAS" -Level SECTION

$daemonScript = "$PSScriptRoot\..\truenas-scripts\monitoring-daemon.sh"

if (Test-Path $daemonScript) {
    Write-InstallLog "Found monitoring daemon script" -Level SUCCESS

    $deploy = Read-Host "Deploy monitoring daemon to Baby NAS? (Y/N)"
    if ($deploy -eq 'Y' -or $deploy -eq 'y') {
        # Get Baby NAS IP
        $babyNasIP = $config.babyNAS.ip
        if ([string]::IsNullOrEmpty($babyNasIP)) {
            $babyNasIP = Read-Host "Enter Baby NAS IP address"
        }

        # Check SSH key
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        if (-not (Test-Path $sshKey)) {
            Write-InstallLog "SSH key not found: $sshKey" -Level WARNING
            Write-InstallLog "Please set up SSH keys first" -Level INFO
        } else {
            try {
                Write-InstallLog "Copying monitoring daemon to Baby NAS..." -Level INFO

                # Copy script
                & scp -i $sshKey -o StrictHostKeyChecking=no $daemonScript "root@${babyNasIP}:/root/monitoring-daemon.sh"

                # Make executable and start
                & ssh -i $sshKey -o StrictHostKeyChecking=no "root@$babyNasIP" @"
chmod +x /root/monitoring-daemon.sh
/root/monitoring-daemon.sh start
"@

                Write-InstallLog "Monitoring daemon deployed and started on Baby NAS" -Level SUCCESS
            } catch {
                Write-InstallLog "Failed to deploy daemon: $($_.Exception.Message)" -Level WARNING
            }
        }
    }
} else {
    Write-InstallLog "Monitoring daemon script not found: $daemonScript" -Level WARNING
}

###############################################################################
# STEP 10: SUMMARY
###############################################################################

Write-InstallLog "Installation Complete" -Level SECTION

Write-Host @"

Installation Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Configuration file validated
✓ Directory structure created
✓ Required scripts verified
"@ -ForegroundColor Green

if ($InstallWebDashboard) {
    Write-Host "✓ Web dashboard files verified" -ForegroundColor Green
}

if ($InstallTrayApp) {
    Write-Host "✓ System tray app configured" -ForegroundColor Green
}

if ($ConfigureScheduledTasks) {
    Write-Host "✓ Scheduled tasks configured" -ForegroundColor Green
}

Write-Host @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Next Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Start Monitoring Service:
   .\START-MONITORING.ps1

2. Open Interactive Dashboard:
   .\dashboard.ps1

3. Start Web Dashboard:
   .\START-MONITORING.ps1 -WebDashboard

4. Configure Webhooks/Alerts:
   Edit: $configPath
   Set alerts.webhook.url to your n8n webhook URL

5. View Logs:
   C:\Logs\baby-nas-monitoring\

6. Check Status:
   .\START-MONITORING.ps1 -Status

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Documentation:
  - Monitoring Config: $configPath
  - n8n Workflow: $PSScriptRoot\..\monitoring\n8n-workflow-example.json
  - Logs Directory: C:\Logs\baby-nas-monitoring\

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"@ -ForegroundColor Cyan

Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host ""
