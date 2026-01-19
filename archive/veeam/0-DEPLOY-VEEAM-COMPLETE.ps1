#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Complete Veeam Agent deployment and configuration orchestration

.DESCRIPTION
    Master script that orchestrates the complete Veeam deployment process.
    Runs all component scripts in the correct order:
    1. Install Veeam Agent
    2. Setup TrueNAS repository
    3. Configure backup jobs
    4. Setup monitoring
    5. Test recovery capability
    6. Configure replication integration

.PARAMETER SkipInstallation
    Skip Veeam Agent installation (if already installed)
    Default: $false

.PARAMETER SkipRepository
    Skip TrueNAS repository setup (if already configured)
    Default: $false

.PARAMETER SkipBackupConfig
    Skip backup job configuration
    Default: $false

.PARAMETER SkipMonitoring
    Skip monitoring setup
    Default: $false

.PARAMETER SkipRecoveryTest
    Skip recovery testing
    Default: $false

.PARAMETER SkipIntegration
    Skip replication integration
    Default: $false

.PARAMETER TrueNasIP
    IP address of Baby NAS
    Default: 172.21.203.18

.PARAMETER BackupDrives
    Drives to backup
    Default: @("C:", "D:")

.PARAMETER RetentionPoints
    Number of restore points to keep
    Default: 7

.PARAMETER Unattended
    Run in unattended mode (no prompts, uses defaults)
    Default: $false

.EXAMPLE
    .\0-DEPLOY-VEEAM-COMPLETE.ps1
    Interactive complete deployment

.EXAMPLE
    .\0-DEPLOY-VEEAM-COMPLETE.ps1 -Unattended $true
    Automated deployment with defaults

.EXAMPLE
    .\0-DEPLOY-VEEAM-COMPLETE.ps1 -SkipInstallation $true -SkipRepository $true
    Configure only backup jobs (installation and repository already done)

.NOTES
    Author: Automated Veeam Deployment System
    Version: 1.0
    Requires: PowerShell 5.1+, Administrator privileges
    Duration: 20-40 minutes for complete deployment
#>

param(
    [Parameter(Mandatory=$false)]
    [bool]$SkipInstallation = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SkipRepository = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SkipBackupConfig = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SkipMonitoring = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SkipRecoveryTest = $false,

    [Parameter(Mandatory=$false)]
    [bool]$SkipIntegration = $false,

    [Parameter(Mandatory=$false)]
    [string]$TrueNasIP = "172.21.203.18",

    [Parameter(Mandatory=$false)]
    [string[]]$BackupDrives = @("C:", "D:"),

    [Parameter(Mandatory=$false)]
    [int]$RetentionPoints = 7,

    [Parameter(Mandatory=$false)]
    [bool]$Unattended = $false
)

# Configuration
$scriptDir = $PSScriptRoot
$logDir = "C:\Logs\Veeam"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\complete-deployment-$timestamp.log"
$deploymentStatusFile = "$logDir\deployment-status.json"

# Create log directory
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Deployment tracking
$deploymentStatus = @{
    StartTime = (Get-Date).ToString()
    EndTime = $null
    Status = "In Progress"
    Steps = @{}
    Errors = @()
    Warnings = @()
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO"    { Write-Host $logMessage -ForegroundColor Cyan }
        "HEADER"  { Write-Host $logMessage -ForegroundColor Magenta }
        default   { Write-Host $logMessage -ForegroundColor White }
    }

    $logMessage | Out-File -FilePath $logFile -Append
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "   VEEAM AGENT COMPLETE DEPLOYMENT" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Automated Veeam Backup Solution" -ForegroundColor White
    Write-Host "  for TrueNAS Baby NAS Integration" -ForegroundColor White
    Write-Host ""
    Write-Host "  Target: $TrueNasIP" -ForegroundColor Cyan
    Write-Host "  Drives: $($BackupDrives -join ', ')" -ForegroundColor Cyan
    Write-Host "  Retention: $RetentionPoints restore points" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-DeploymentStep {
    param(
        [string]$StepName,
        [string]$StepDescription,
        [scriptblock]$ScriptBlock,
        [bool]$Skip = $false
    )

    Write-Log "" "INFO"
    Write-Log "============================================" "HEADER"
    Write-Log "STEP: $StepDescription" "HEADER"
    Write-Log "============================================" "HEADER"

    $deploymentStatus.Steps[$StepName] = @{
        Description = $StepDescription
        StartTime = (Get-Date).ToString()
        EndTime = $null
        Status = "In Progress"
        Duration = 0
    }

    if ($Skip) {
        Write-Log "SKIPPED: $StepDescription (per user request)" "WARNING"
        $deploymentStatus.Steps[$StepName].Status = "Skipped"
        $deploymentStatus.Steps[$StepName].EndTime = (Get-Date).ToString()
        return $true
    }

    $startTime = Get-Date

    try {
        Write-Log "Starting: $StepDescription" "INFO"
        $result = & $ScriptBlock

        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds

        $deploymentStatus.Steps[$StepName].EndTime = $endTime.ToString()
        $deploymentStatus.Steps[$StepName].Duration = [math]::Round($duration, 1)
        $deploymentStatus.Steps[$StepName].Status = "Completed"

        Write-Log "COMPLETED: $StepDescription (Duration: $([math]::Round($duration, 1))s)" "SUCCESS"

        # Pause between steps in interactive mode
        if (-not $Unattended) {
            Write-Host ""
            Write-Host "Press Enter to continue to next step..." -ForegroundColor Yellow
            Read-Host
        } else {
            Start-Sleep -Seconds 2
        }

        return $true

    } catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds

        $deploymentStatus.Steps[$StepName].EndTime = $endTime.ToString()
        $deploymentStatus.Steps[$StepName].Duration = [math]::Round($duration, 1)
        $deploymentStatus.Steps[$StepName].Status = "Failed"

        $errorMsg = "FAILED: $StepDescription - $($_.Exception.Message)"
        Write-Log $errorMsg "ERROR"
        $deploymentStatus.Errors += $errorMsg

        if (-not $Unattended) {
            Write-Host ""
            Write-Host "Step failed. Continue anyway? (Y/N): " -NoNewline -ForegroundColor Yellow
            $response = Read-Host

            if ($response -ne 'Y' -and $response -ne 'y') {
                Write-Log "Deployment aborted by user after failed step" "ERROR"
                return $false
            }
        } else {
            Write-Log "WARNING: Step failed but continuing in unattended mode" "WARNING"
        }

        return $true
    }
}

function Save-DeploymentStatus {
    try {
        $deploymentStatus | ConvertTo-Json -Depth 10 | Out-File -FilePath $deploymentStatusFile -Force
        Write-Log "Deployment status saved: $deploymentStatusFile" "INFO"
    } catch {
        Write-Log "WARNING: Could not save deployment status: $($_.Exception.Message)" "WARNING"
    }
}

function Show-PreDeploymentChecklist {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " PRE-DEPLOYMENT CHECKLIST" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $checks = @(
        @{ Item = "Administrator privileges"; Required = $true },
        @{ Item = "Network connectivity to TrueNAS ($TrueNasIP)"; Required = $true },
        @{ Item = "Veeam Agent installer downloaded (if not installed)"; Required = $true },
        @{ Item = "TrueNAS credentials available"; Required = $true },
        @{ Item = "Sufficient disk space for backups"; Required = $true },
        @{ Item = "Estimated time: 20-40 minutes"; Required = $false }
    )

    foreach ($check in $checks) {
        $prefix = if ($check.Required) { "[REQUIRED]" } else { "[INFO]" }
        $color = if ($check.Required) { "Yellow" } else { "Cyan" }
        Write-Host "  $prefix $($check.Item)" -ForegroundColor $color
    }

    Write-Host ""

    if (-not $Unattended) {
        Write-Host "Ready to begin deployment? (Y/N): " -NoNewline -ForegroundColor Yellow
        $response = Read-Host

        if ($response -ne 'Y' -and $response -ne 'y') {
            Write-Log "Deployment cancelled by user" "WARNING"
            exit 0
        }
    }

    Write-Log "Pre-deployment checklist acknowledged" "INFO"
}

function Show-DeploymentSummary {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host " DEPLOYMENT SUMMARY" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""

    # Calculate totals
    $totalSteps = $deploymentStatus.Steps.Count
    $completedSteps = ($deploymentStatus.Steps.Values | Where-Object { $_.Status -eq "Completed" }).Count
    $failedSteps = ($deploymentStatus.Steps.Values | Where-Object { $_.Status -eq "Failed" }).Count
    $skippedSteps = ($deploymentStatus.Steps.Values | Where-Object { $_.Status -eq "Skipped" }).Count

    $totalDuration = ($deploymentStatus.Steps.Values | Measure-Object -Property Duration -Sum).Sum

    Write-Host "EXECUTION SUMMARY:" -ForegroundColor Cyan
    Write-Host "  Total Steps: $totalSteps" -ForegroundColor White
    Write-Host "  Completed: " -NoNewline
    Write-Host "$completedSteps" -ForegroundColor Green
    Write-Host "  Failed: " -NoNewline
    Write-Host "$failedSteps" -ForegroundColor $(if ($failedSteps -gt 0) { "Red" } else { "White" })
    Write-Host "  Skipped: " -NoNewline
    Write-Host "$skippedSteps" -ForegroundColor Yellow
    Write-Host "  Total Duration: $([math]::Round($totalDuration, 1)) seconds" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "STEP DETAILS:" -ForegroundColor Cyan
    foreach ($stepName in $deploymentStatus.Steps.Keys) {
        $step = $deploymentStatus.Steps[$stepName]

        $statusColor = switch ($step.Status) {
            "Completed" { "Green" }
            "Failed" { "Red" }
            "Skipped" { "Yellow" }
            default { "White" }
        }

        Write-Host "  [$($step.Status)] " -NoNewline -ForegroundColor $statusColor
        Write-Host "$($step.Description)" -ForegroundColor White
        Write-Host "    Duration: $($step.Duration)s" -ForegroundColor Gray
    }

    Write-Host ""

    # Overall status
    if ($failedSteps -gt 0) {
        $deploymentStatus.Status = "Completed with Errors"
        Write-Host "OVERALL STATUS: " -NoNewline
        Write-Host "COMPLETED WITH ERRORS" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Some steps failed. Review logs and complete manually:" -ForegroundColor Yellow
        foreach ($error in $deploymentStatus.Errors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
    } else {
        $deploymentStatus.Status = "Completed Successfully"
        Write-Host "OVERALL STATUS: " -NoNewline
        Write-Host "COMPLETED SUCCESSFULLY" -ForegroundColor Green
    }

    Write-Host ""

    # Next steps
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "  1. Verify backup job in Veeam Control Panel" -ForegroundColor White
    Write-Host "  2. Run immediate test backup" -ForegroundColor White
    Write-Host "  3. Monitor first scheduled backup" -ForegroundColor White
    Write-Host "  4. Test recovery procedure" -ForegroundColor White
    Write-Host "  5. Schedule quarterly recovery tests" -ForegroundColor White
    Write-Host ""

    Write-Host "MONITORING:" -ForegroundColor Cyan
    Write-Host "  Run: .\4-monitor-backup-jobs.ps1" -ForegroundColor Green
    Write-Host "  Or:  .\4-monitor-backup-jobs.ps1 -CheckInterval 60" -ForegroundColor Green
    Write-Host "       (for continuous monitoring every 60 minutes)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "DOCUMENTATION:" -ForegroundColor Cyan
    Write-Host "  Deployment log: $logFile" -ForegroundColor White
    Write-Host "  Status file: $deploymentStatusFile" -ForegroundColor White
    Write-Host "  All logs: $logDir" -ForegroundColor White
    Write-Host ""
}

# ===== MAIN EXECUTION =====

Show-Banner

Write-Log "=== Veeam Complete Deployment Started ===" "INFO"
Write-Log "Mode: $(if ($Unattended) { 'Unattended' } else { 'Interactive' })" "INFO"
Write-Log "Script Directory: $scriptDir" "INFO"

# Pre-deployment checklist
Show-PreDeploymentChecklist

# STEP 1: Install Veeam Agent
$continue = Invoke-DeploymentStep `
    -StepName "Installation" `
    -StepDescription "Install Veeam Agent for Windows" `
    -Skip $SkipInstallation `
    -ScriptBlock {
        & "$scriptDir\1-install-veeam-agent.ps1"
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Installation script failed with exit code: $LASTEXITCODE"
        }
    }

if (-not $continue) {
    Write-Log "Deployment aborted" "ERROR"
    exit 1
}

# STEP 2: Setup TrueNAS Repository
$continue = Invoke-DeploymentStep `
    -StepName "Repository" `
    -StepDescription "Setup TrueNAS Veeam Repository" `
    -Skip $SkipRepository `
    -ScriptBlock {
        & "$scriptDir\3-setup-truenas-repository.ps1" -TrueNasIP $TrueNasIP
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Repository setup failed with exit code: $LASTEXITCODE"
        }
    }

if (-not $continue) {
    Write-Log "Deployment aborted" "ERROR"
    exit 1
}

# STEP 3: Configure Backup Jobs
$continue = Invoke-DeploymentStep `
    -StepName "BackupConfig" `
    -StepDescription "Configure Veeam Backup Jobs" `
    -Skip $SkipBackupConfig `
    -ScriptBlock {
        & "$scriptDir\2-configure-backup-jobs.ps1" `
            -BackupDestination "\\$TrueNasIP\Veeam" `
            -BackupDrives $BackupDrives `
            -RetentionPoints $RetentionPoints
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Backup configuration failed with exit code: $LASTEXITCODE"
        }
    }

if (-not $continue) {
    Write-Log "Deployment aborted" "ERROR"
    exit 1
}

# STEP 4: Configure Monitoring
$continue = Invoke-DeploymentStep `
    -StepName "Monitoring" `
    -StepDescription "Setup Backup Monitoring" `
    -Skip $SkipMonitoring `
    -ScriptBlock {
        & "$scriptDir\4-monitor-backup-jobs.ps1" -BackupDestination "\\$TrueNasIP\Veeam"
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Monitoring setup failed with exit code: $LASTEXITCODE"
        }
    }

if (-not $continue) {
    Write-Log "Deployment aborted" "ERROR"
    exit 1
}

# STEP 5: Test Recovery
$continue = Invoke-DeploymentStep `
    -StepName "RecoveryTest" `
    -StepDescription "Test Recovery Capability" `
    -Skip $SkipRecoveryTest `
    -ScriptBlock {
        & "$scriptDir\5-test-recovery.ps1" -BackupDestination "\\$TrueNasIP\Veeam"
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Recovery test failed with exit code: $LASTEXITCODE"
        }
    }

if (-not $continue) {
    Write-Log "Deployment aborted" "ERROR"
    exit 1
}

# STEP 6: Configure Replication Integration
$continue = Invoke-DeploymentStep `
    -StepName "Integration" `
    -StepDescription "Configure Replication Integration" `
    -Skip $SkipIntegration `
    -ScriptBlock {
        & "$scriptDir\6-integration-replication.ps1" -TrueNasIP $TrueNasIP
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Integration configuration failed with exit code: $LASTEXITCODE"
        }
    }

if (-not $continue) {
    Write-Log "Deployment aborted" "ERROR"
    exit 1
}

# Finalization
$deploymentStatus.EndTime = (Get-Date).ToString()
Save-DeploymentStatus

# Show summary
Show-DeploymentSummary

Write-Log "=== Veeam Complete Deployment Finished ===" "SUCCESS"
Write-Log "Deployment log: $logFile" "INFO"

exit 0
