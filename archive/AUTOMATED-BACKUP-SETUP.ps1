<#
.SYNOPSIS
    Complete end-to-end backup system deployment orchestration

.DESCRIPTION
    Master deployment script that:
    - Runs all three backup system deployments in correct order
    - Prompts for configuration inputs interactively
    - Provides step-by-step guidance
    - Generates consolidated report
    - Color-codes pass/fail status
    - Handles errors gracefully

    Deploys:
    1. Veeam Agent for Windows (local Windows backups)
    2. Phone Backup System (SMB share for mobile devices)
    3. Time Machine for Mac (automated Mac backups)

.PARAMETER BabyNASIP
    IP address of Baby NAS
    Default: 172.21.203.18

.PARAMETER BabyNASHostname
    Hostname of Baby NAS
    Default: baby.isn.biz

.PARAMETER BareMetalIP
    IP address of Bare Metal server
    Default: 10.0.0.89

.PARAMETER BareMetalHostname
    Hostname of Bare Metal server
    Default: baremetal.isn.biz

.PARAMETER Username
    Username for SMB authentication

.PARAMETER Password
    Password for SMB authentication

.PARAMETER DeployVeeam
    Deploy Veeam Agent
    Default: $true

.PARAMETER DeployPhoneBackups
    Deploy phone backup infrastructure
    Default: $true

.PARAMETER DeployTimeMachine
    Deploy Time Machine configuration
    Default: $true

.PARAMETER NoGUI
    Run without interactive prompts

.PARAMETER SkipValidation
    Skip pre-deployment validation

.EXAMPLE
    .\AUTOMATED-BACKUP-SETUP.ps1
    Complete interactive deployment of all systems

.EXAMPLE
    .\AUTOMATED-BACKUP-SETUP.ps1 -NoGUI -Username admin -Password "P@ssw0rd"
    Silent deployment with all systems

.EXAMPLE
    .\AUTOMATED-BACKUP-SETUP.ps1 -DeployVeeam -DeployPhoneBackups -SkipValidation
    Deploy Veeam and Phone only, skip validation
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BabyNASIP = "172.21.203.18",

    [Parameter(Mandatory=$false)]
    [string]$BabyNASHostname = "baby.isn.biz",

    [Parameter(Mandatory=$false)]
    [string]$BareMetalIP = "10.0.0.89",

    [Parameter(Mandatory=$false)]
    [string]$BareMetalHostname = "baremetal.isn.biz",

    [Parameter(Mandatory=$false)]
    [string]$Username,

    [Parameter(Mandatory=$false)]
    [string]$Password,

    [Parameter(Mandatory=$false)]
    [bool]$DeployVeeam = $true,

    [Parameter(Mandatory=$false)]
    [bool]$DeployPhoneBackups = $true,

    [Parameter(Mandatory=$false)]
    [bool]$DeployTimeMachine = $false,

    [Parameter(Mandatory=$false)]
    [switch]$NoGUI,

    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation
)

#Requires -RunAsAdministrator

# ===== CONFIGURATION =====
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = "C:\Logs"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = "$LogDir\AUTOMATED-BACKUP-SETUP-$Timestamp.log"
$ConsolidatedReport = "$LogDir\BACKUP-SETUP-COMPLETE-$Timestamp.html"

# Color configuration
$Colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Debug = "Gray"
}

# Status tracking
$DeploymentStatus = @{
    Overall = "IN_PROGRESS"
    Veeam = @{ Status = "PENDING"; Time = 0; Details = "" }
    PhoneBackups = @{ Status = "PENDING"; Time = 0; Details = "" }
    TimeMachine = @{ Status = "PENDING"; Time = 0; Details = "" }
    Verification = @{ Status = "PENDING"; Time = 0; Details = "" }
    StartTime = Get-Date
}

# ===== HELPER FUNCTIONS =====

function Initialize-Logging {
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"

    Write-Host $LogMessage -ForegroundColor $Colors[$Level]
    $LogMessage | Out-File -FilePath $LogFile -Append
}

function Write-Header {
    param(
        [string]$Title,
        [int]$Step
    )

    Write-Host ""
    Write-Host "╔" + ("=" * 68) + "╗" -ForegroundColor Cyan
    Write-Host "║ Step $Step - $Title" + (" " * (67 - $Title.Length - 10)) + "║" -ForegroundColor Cyan
    Write-Host "╚" + ("=" * 68) + "╝" -ForegroundColor Cyan
    Write-Host ""
}

function Get-UserConfirmation {
    param(
        [string]$Message,
        [string]$DefaultChoice = "Y"
    )

    if ($NoGUI) { return $true }

    $choices = @("&Yes", "&No")
    $decision = $Host.UI.PromptForChoice("", $Message, $choices, 0)
    return ($decision -eq 0)
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    if ($NoGUI) { return $Default }

    if ($Default) {
        Write-Host "$Prompt [$Default]: " -NoNewline -ForegroundColor Yellow
    } else {
        Write-Host "$Prompt : " -NoNewline -ForegroundColor Yellow
    }

    $input = Read-Host
    return if ($input) { $input } else { $Default }
}

function Validate-Prerequisites {
    Write-Header "Validating Prerequisites" 1

    $valid = $true

    Write-Log "Checking PowerShell version..." "INFO"
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "ERROR: PowerShell 5.0 or later required" "ERROR"
        $valid = $false
    } else {
        Write-Log "PowerShell version: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)" "SUCCESS"
    }

    Write-Log "Checking network connectivity..." "INFO"
    if (-not (Test-NetConnection -ComputerName $BabyNASIP -InformationLevel Quiet)) {
        Write-Log "WARNING: Cannot reach Baby NAS ($BabyNASIP)" "WARNING"
    } else {
        Write-Log "Baby NAS is reachable" "SUCCESS"
    }

    if (-not (Test-NetConnection -ComputerName $BareMetalIP -InformationLevel Quiet)) {
        Write-Log "WARNING: Cannot reach Bare Metal ($BareMetalIP)" "WARNING"
    } else {
        Write-Log "Bare Metal is reachable" "SUCCESS"
    }

    Write-Log "Checking disk space..." "INFO"
    $systemDrive = Get-Volume -DriveLetter C
    $freeSpaceGB = [math]::Round($systemDrive.SizeRemaining / 1GB, 2)

    if ($freeSpaceGB -lt 10) {
        Write-Log "ERROR: Less than 10 GB free on C: drive" "ERROR"
        $valid = $false
    } else {
        Write-Log "Free space: $freeSpaceGB GB" "SUCCESS"
    }

    return $valid
}

function Get-DeploymentConfiguration {
    Write-Header "Configuring Backup Deployment" 2

    Write-Host ""
    Write-Host "BACKUP SYSTEM CONFIGURATION" -ForegroundColor Cyan
    Write-Host ""

    # Network settings
    Write-Log "Gathering network configuration..." "INFO"

    if (-not $Username) {
        $Username = Get-UserInput "SMB Username" "administrator"
    }

    if (-not $Password) {
        Write-Host "SMB Password: " -NoNewline -ForegroundColor Yellow
        $securePassword = Read-Host -AsSecureString
        $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($securePassword)
        )
    }

    # Deployment selections
    Write-Host ""
    Write-Host "SELECT SYSTEMS TO DEPLOY:" -ForegroundColor Cyan
    Write-Host ""

    if ((Get-UserConfirmation "Deploy Veeam Agent for Windows backups?")) {
        $DeployVeeam = $true
    } else {
        $DeployVeeam = $false
    }

    if ((Get-UserConfirmation "Deploy Phone Backup infrastructure?")) {
        $DeployPhoneBackups = $true
    } else {
        $DeployPhoneBackups = $false
    }

    if ((Get-UserConfirmation "Deploy Time Machine for Mac (requires Mac access)?")) {
        $DeployTimeMachine = $true
    } else {
        $DeployTimeMachine = $false
    }

    Write-Host ""
    Write-Log "Configuration collected" "INFO"

    return @{
        Username = $Username
        Password = $Password
        DeployVeeam = $DeployVeeam
        DeployPhoneBackups = $DeployPhoneBackups
        DeployTimeMachine = $DeployTimeMachine
    }
}

function Deploy-VeeamSystem {
    param([hashtable]$Config)

    $startTime = Get-Date
    Write-Header "Deploying Veeam Agent for Windows" 3

    if (-not $Config.DeployVeeam) {
        Write-Log "Veeam deployment skipped by user" "INFO"
        $DeploymentStatus.Veeam = @{ Status = "SKIPPED"; Time = 0; Details = "User skipped" }
        return $false
    }

    Write-Host "This will configure Veeam Agent for Windows:" -ForegroundColor Yellow
    Write-Host "  • Backup destination: \\$BabyNASHostname\Veeam" -ForegroundColor White
    Write-Host "  • Schedule: Daily at 1:00 AM" -ForegroundColor White
    Write-Host "  • Retention: 7 days" -ForegroundColor White
    Write-Host "  • Source drives: C:, D:" -ForegroundColor White
    Write-Host ""

    if (-not (Get-UserConfirmation "Continue with Veeam deployment?")) {
        Write-Log "Veeam deployment cancelled by user" "WARNING"
        $DeploymentStatus.Veeam = @{ Status = "CANCELLED"; Time = 0; Details = "User cancelled" }
        return $false
    }

    try {
        Write-Log "Starting Veeam deployment script..." "INFO"

        $veeamScript = Join-Path $ScriptDir "DEPLOY-VEEAM-COMPLETE.ps1"

        if (-not (Test-Path $veeamScript)) {
            Write-Log "ERROR: Veeam deployment script not found at $veeamScript" "ERROR"
            $DeploymentStatus.Veeam = @{ Status = "FAILED"; Time = 0; Details = "Script not found" }
            return $false
        }

        & $veeamScript `
            -BabyNASIP $BabyNASIP `
            -BabyNASHostname $BabyNASHostname `
            -Username $Config.Username `
            -Password $Config.Password `
            -NoGUI

        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        Write-Log "Veeam deployment completed" "SUCCESS"
        $DeploymentStatus.Veeam = @{ Status = "SUCCESS"; Time = $elapsed; Details = "Deployment completed" }
        return $true

    } catch {
        Write-Log "ERROR during Veeam deployment: $($_.Exception.Message)" "ERROR"
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $DeploymentStatus.Veeam = @{ Status = "FAILED"; Time = $elapsed; Details = $_.Exception.Message }
        return $false
    }
}

function Deploy-PhoneBackupSystem {
    param([hashtable]$Config)

    $startTime = Get-Date
    Write-Header "Deploying Phone Backup Infrastructure" 4

    if (-not $Config.DeployPhoneBackups) {
        Write-Log "Phone backup deployment skipped by user" "INFO"
        $DeploymentStatus.PhoneBackups = @{ Status = "SKIPPED"; Time = 0; Details = "User skipped" }
        return $false
    }

    Write-Host "This will configure phone backup SMB share:" -ForegroundColor Yellow
    Write-Host "  • Share: \\$BabyNASHostname\PhoneBackups" -ForegroundColor White
    Write-Host "  • Quota: 500 GB" -ForegroundColor White
    Write-Host "  • Devices: Galaxy S24 Ultra, iPhone, iPad, etc." -ForegroundColor White
    Write-Host ""

    if (-not (Get-UserConfirmation "Continue with phone backup deployment?")) {
        Write-Log "Phone backup deployment cancelled by user" "WARNING"
        $DeploymentStatus.PhoneBackups = @{ Status = "CANCELLED"; Time = 0; Details = "User cancelled" }
        return $false
    }

    try {
        Write-Log "Starting phone backup deployment script..." "INFO"

        $phoneScript = Join-Path $ScriptDir "DEPLOY-PHONE-BACKUPS-WINDOWS.ps1"

        if (-not (Test-Path $phoneScript)) {
            Write-Log "ERROR: Phone backup deployment script not found at $phoneScript" "ERROR"
            $DeploymentStatus.PhoneBackups = @{ Status = "FAILED"; Time = 0; Details = "Script not found" }
            return $false
        }

        & $phoneScript `
            -BabyNASIP $BabyNASIP `
            -BabyNASHostname $BabyNASHostname `
            -Username $Config.Username `
            -Password $Config.Password `
            -NoGUI

        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        Write-Log "Phone backup deployment completed" "SUCCESS"
        $DeploymentStatus.PhoneBackups = @{ Status = "SUCCESS"; Time = $elapsed; Details = "Deployment completed" }
        return $true

    } catch {
        Write-Log "ERROR during phone backup deployment: $($_.Exception.Message)" "ERROR"
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $DeploymentStatus.PhoneBackups = @{ Status = "FAILED"; Time = $elapsed; Details = $_.Exception.Message }
        return $false
    }
}

function Deploy-TimeMachineSystem {
    param([hashtable]$Config)

    $startTime = Get-Date
    Write-Header "Deploying Time Machine for Mac" 5

    if (-not $Config.DeployTimeMachine) {
        Write-Log "Time Machine deployment skipped by user" "INFO"
        $DeploymentStatus.TimeMachine = @{ Status = "SKIPPED"; Time = 0; Details = "User skipped" }
        return $false
    }

    Write-Host "This will configure Time Machine on your Mac:" -ForegroundColor Yellow
    Write-Host "  • Share: \\$BareMetalHostname\TimeMachine" -ForegroundColor White
    Write-Host "  • IP: $BareMetalIP" -ForegroundColor White
    Write-Host "  • Schedule: Hourly automatic backups" -ForegroundColor White
    Write-Host ""
    Write-Host "NOTE: This script must be run on a Mac with SSH access configured" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Get-UserConfirmation "Do you have SSH access configured to your Mac?")) {
        Write-Log "Time Machine deployment requires SSH configuration" "WARNING"
        Write-Host "To use Time Machine deployment:" -ForegroundColor Yellow
        Write-Host "  1. Ensure SSH is enabled on your Mac" -ForegroundColor White
        Write-Host "  2. Run the script directly on Mac: DEPLOY-TIME-MACHINE-MAC.sh" -ForegroundColor White
        Write-Host "  3. Or manually configure Time Machine in System Preferences" -ForegroundColor White
        Write-Host ""
        $DeploymentStatus.TimeMachine = @{ Status = "SKIPPED"; Time = 0; Details = "SSH not configured" }
        return $false
    }

    try {
        Write-Log "Time Machine deployment requires manual configuration on Mac" "WARNING"

        $macScript = Join-Path $ScriptDir "DEPLOY-TIME-MACHINE-MAC.sh"

        if (-not (Test-Path $macScript)) {
            Write-Log "Time Machine script not found at $macScript" "ERROR"
            $DeploymentStatus.TimeMachine = @{ Status = "FAILED"; Time = 0; Details = "Script not found" }
            return $false
        }

        Write-Host "To complete Time Machine setup on your Mac:" -ForegroundColor Cyan
        Write-Host "  1. Copy DEPLOY-TIME-MACHINE-MAC.sh to your Mac" -ForegroundColor White
        Write-Host "  2. Run: chmod +x DEPLOY-TIME-MACHINE-MAC.sh" -ForegroundColor White
        Write-Host "  3. Run: ./DEPLOY-TIME-MACHINE-MAC.sh" -ForegroundColor White
        Write-Host ""

        Write-Log "Time Machine deployment information displayed" "INFO"
        $DeploymentStatus.TimeMachine = @{ Status = "MANUAL"; Time = 0; Details = "User must run on Mac" }
        return $true

    } catch {
        Write-Log "ERROR during Time Machine setup: $($_.Exception.Message)" "ERROR"
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $DeploymentStatus.TimeMachine = @{ Status = "FAILED"; Time = $elapsed; Details = $_.Exception.Message }
        return $false
    }
}

function Verify-AllBackups {
    $startTime = Get-Date
    Write-Header "Verifying Backup Systems" 6

    Write-Log "Running comprehensive backup verification..." "INFO"

    try {
        $verifyScript = Join-Path $ScriptDir "VERIFY-ALL-BACKUPS.ps1"

        if (-not (Test-Path $verifyScript)) {
            Write-Log "Verification script not found at $verifyScript" "ERROR"
            $DeploymentStatus.Verification = @{ Status = "FAILED"; Time = 0; Details = "Script not found" }
            return $false
        }

        & $verifyScript -BabyNASIP $BabyNASIP -BareMetalIP $BareMetalIP

        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        Write-Log "Backup verification completed" "SUCCESS"
        $DeploymentStatus.Verification = @{ Status = "SUCCESS"; Time = $elapsed; Details = "Verification completed" }
        return $true

    } catch {
        Write-Log "ERROR during verification: $($_.Exception.Message)" "ERROR"
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        $DeploymentStatus.Verification = @{ Status = "FAILED"; Time = $elapsed; Details = $_.Exception.Message }
        return $false
    }
}

function Generate-ConsolidatedReport {
    Write-Log "Generating consolidated deployment report..." "INFO"

    $totalTime = ((Get-Date) - $DeploymentStatus.StartTime).TotalSeconds

    $systemStatus = @()
    $systemStatus += "Veeam:          $($DeploymentStatus.Veeam.Status) ($($DeploymentStatus.Veeam.Time)s)"
    $systemStatus += "Phone Backups:  $($DeploymentStatus.PhoneBackups.Status) ($($DeploymentStatus.PhoneBackups.Time)s)"
    $systemStatus += "Time Machine:   $($DeploymentStatus.TimeMachine.Status) ($($DeploymentStatus.TimeMachine.Time)s)"
    $systemStatus += "Verification:   $($DeploymentStatus.Verification.Status) ($($DeploymentStatus.Verification.Time)s)"

    # Determine overall status
    $failCount = @("FAILED") | Where-Object { $systemStatus -match $_ } | Measure-Object | Select-Object -ExpandProperty Count
    $successCount = @("SUCCESS") | Where-Object { $systemStatus -match $_ } | Measure-Object | Select-Object -ExpandProperty Count

    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Automated Backup Setup - Complete Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .container { max-width: 1000px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); }
        h1 { color: #333; border-bottom: 4px solid #667eea; padding-bottom: 15px; }
        h2 { color: #667eea; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th { background-color: #667eea; color: white; padding: 12px; text-align: left; }
        td { padding: 12px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .success { color: #27ae60; font-weight: bold; }
        .error { color: #e74c3c; font-weight: bold; }
        .warning { color: #f39c12; font-weight: bold; }
        .skipped { color: #95a5a6; font-weight: bold; }
        .timestamp { color: #7f8c8d; font-size: 0.9em; }
        .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .summary-card h3 { margin-top: 0; }
        .status-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin-top: 15px; }
        .status-item { background: white; padding: 15px; border-left: 4px solid #667eea; border-radius: 4px; }
        .status-item.success { border-left-color: #27ae60; }
        .status-item.error { border-left-color: #e74c3c; }
        .status-item.warning { border-left-color: #f39c12; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Automated Backup Setup - Complete Deployment Report</h1>
        <p class="timestamp">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>

        <div class="summary-card">
            <h3>Deployment Summary</h3>
            <p>Total Execution Time: $([math]::Round($totalTime, 1)) seconds</p>
            <p>Systems Deployed: $successCount Successful, $failCount Failed</p>
        </div>

        <h2>Deployment Status</h2>
        <table>
            <tr>
                <th>System</th>
                <th>Status</th>
                <th>Execution Time</th>
                <th>Details</th>
            </tr>
            <tr class="$(if ($DeploymentStatus.Veeam.Status -eq 'SUCCESS') { 'success' } elseif ($DeploymentStatus.Veeam.Status -eq 'FAILED') { 'error' } else { 'warning' })">
                <td>Veeam Agent</td>
                <td class="$(if ($DeploymentStatus.Veeam.Status -eq 'SUCCESS') { 'success' } elseif ($DeploymentStatus.Veeam.Status -eq 'FAILED') { 'error' } else { 'warning' })">$($DeploymentStatus.Veeam.Status)</td>
                <td>$([math]::Round($DeploymentStatus.Veeam.Time, 1))s</td>
                <td>$($DeploymentStatus.Veeam.Details)</td>
            </tr>
            <tr class="$(if ($DeploymentStatus.PhoneBackups.Status -eq 'SUCCESS') { 'success' } elseif ($DeploymentStatus.PhoneBackups.Status -eq 'FAILED') { 'error' } else { 'warning' })">
                <td>Phone Backups</td>
                <td class="$(if ($DeploymentStatus.PhoneBackups.Status -eq 'SUCCESS') { 'success' } elseif ($DeploymentStatus.PhoneBackups.Status -eq 'FAILED') { 'error' } else { 'warning' })">$($DeploymentStatus.PhoneBackups.Status)</td>
                <td>$([math]::Round($DeploymentStatus.PhoneBackups.Time, 1))s</td>
                <td>$($DeploymentStatus.PhoneBackups.Details)</td>
            </tr>
            <tr class="$(if ($DeploymentStatus.TimeMachine.Status -eq 'SUCCESS') { 'success' } elseif ($DeploymentStatus.TimeMachine.Status -eq 'FAILED') { 'error' } else { 'warning' })">
                <td>Time Machine</td>
                <td class="$(if ($DeploymentStatus.TimeMachine.Status -eq 'SUCCESS') { 'success' } elseif ($DeploymentStatus.TimeMachine.Status -eq 'FAILED') { 'error' } else { 'warning' })">$($DeploymentStatus.TimeMachine.Status)</td>
                <td>$([math]::Round($DeploymentStatus.TimeMachine.Time, 1))s</td>
                <td>$($DeploymentStatus.TimeMachine.Details)</td>
            </tr>
            <tr class="$(if ($DeploymentStatus.Verification.Status -eq 'SUCCESS') { 'success' } elseif ($DeploymentStatus.Verification.Status -eq 'FAILED') { 'error' } else { 'warning' })">
                <td>Verification</td>
                <td class="$(if ($DeploymentStatus.Verification.Status -eq 'SUCCESS') { 'success' } elseif ($DeploymentStatus.Verification.Status -eq 'FAILED') { 'error' } else { 'warning' })">$($DeploymentStatus.Verification.Status)</td>
                <td>$([math]::Round($DeploymentStatus.Verification.Time, 1))s</td>
                <td>$($DeploymentStatus.Verification.Details)</td>
            </tr>
        </table>

        <h2>Next Steps</h2>
        <ol>
            <li><strong>Verify each system:</strong> Check each backup system is working correctly</li>
            <li><strong>Run first backups:</strong> Trigger manual backups on each system</li>
            <li><strong>Monitor logs:</strong> Check C:\Logs for detailed logs from each deployment</li>
            <li><strong>Schedule regular checks:</strong> Run VERIFY-ALL-BACKUPS.ps1 monthly</li>
            <li><strong>Document setup:</strong> Keep a copy of this report for reference</li>
        </ol>

        <h2>Support Resources</h2>
        <ul>
            <li><strong>Veeam Documentation:</strong> https://www.veeam.com/backup-replication-resources.html</li>
            <li><strong>TrueNAS Documentation:</strong> https://www.truenas.com/docs/</li>
            <li><strong>Log Files:</strong> All logs available in C:\Logs</li>
        </ul>

        <div class="footer">
            <p>Deployment Report Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
            <p>Log Directory: $LogDir</p>
        </div>
    </div>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $ConsolidatedReport -Encoding UTF8
    Write-Log "Consolidated report generated: $ConsolidatedReport" "SUCCESS"
}

# ===== MAIN EXECUTION =====

Clear-Host
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                    ║" -ForegroundColor Cyan
Write-Host "║              Automated Backup System Deployment                    ║" -ForegroundColor Cyan
Write-Host "║                 Complete End-to-End Setup                          ║" -ForegroundColor Cyan
Write-Host "║                                                                    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Initialize-Logging
Write-Log "Automated backup setup started" "INFO"

# Step 1: Validate Prerequisites
if (-not $SkipValidation) {
    if (-not (Validate-Prerequisites)) {
        Write-Log "Prerequisites validation failed" "ERROR"
        exit 1
    }
} else {
    Write-Log "Skipping prerequisites validation" "DEBUG"
}

# Step 2: Get Configuration
$config = Get-DeploymentConfiguration

# Step 3: Deploy Veeam
Deploy-VeeamSystem -Config $config

# Step 4: Deploy Phone Backups
Deploy-PhoneBackupSystem -Config $config

# Step 5: Deploy Time Machine
Deploy-TimeMachineSystem -Config $config

# Step 6: Verify All Systems
Verify-AllBackups

# Step 7: Generate Report
Write-Header "Generating Final Report" 7
Generate-ConsolidatedReport

# Final Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    DEPLOYMENT COMPLETE                             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "System Status Summary:" -ForegroundColor Yellow
Write-Host "  Veeam Agent:       $($DeploymentStatus.Veeam.Status)" -ForegroundColor $(if ($DeploymentStatus.Veeam.Status -eq "SUCCESS") { "Green" } else { "Yellow" })
Write-Host "  Phone Backups:     $($DeploymentStatus.PhoneBackups.Status)" -ForegroundColor $(if ($DeploymentStatus.PhoneBackups.Status -eq "SUCCESS") { "Green" } else { "Yellow" })
Write-Host "  Time Machine:      $($DeploymentStatus.TimeMachine.Status)" -ForegroundColor $(if ($DeploymentStatus.TimeMachine.Status -eq "SUCCESS") { "Green" } else { "Yellow" })
Write-Host "  Verification:      $($DeploymentStatus.Verification.Status)" -ForegroundColor $(if ($DeploymentStatus.Verification.Status -eq "SUCCESS") { "Green" } else { "Yellow" })
Write-Host ""

Write-Host "Files Generated:" -ForegroundColor Cyan
Write-Host "  Consolidated Report: $ConsolidatedReport" -ForegroundColor Gray
Write-Host "  Log File:            $LogFile" -ForegroundColor Gray
Write-Host ""

Write-Log "Automated backup setup completed" "SUCCESS"

if ((Read-Host "Open final report? (Y/N)") -eq "Y") {
    Start-Process $ConsolidatedReport
}

Write-Host "Setup complete! Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
