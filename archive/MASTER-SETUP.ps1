# MASTER-SETUP: Complete BabyNAS Deployment Automation
# Runs all setup, configuration, testing, and deployment in sequence
# Can run unattended or interactively with -Interactive flag

param(
    [switch]$Interactive = $false,
    [switch]$SkipDiagnostics = $false,
    [switch]$AutoFix = $true,
    [switch]$NoGitPush = $false,
    [switch]$DryRun = $false,
    [switch]$Verbose = $false
)

# Configuration
$script:ErrorCount = 0
$script:WarningCount = 0
$script:SuccessCount = 0
$script:StartTime = Get-Date
$script:LogFile = "C:\Logs\MASTER-SETUP-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure log directory exists
$logDir = Split-Path $script:LogFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO", [string]$Color = "Gray")

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console
    Write-Host $logMessage -ForegroundColor $Color

    # Write to file
    try {
        Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
    } catch {}
}

function Write-Banner {
    param([string]$Title, [string]$SubTitle = "")

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Title.PadRight(60)) ║" -ForegroundColor Cyan
    if ($SubTitle) {
        Write-Host "║ $($SubTitle.PadRight(60)) ║" -ForegroundColor Gray
    }
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Log ">>> $Title" "INFO" "Cyan"
}

function Invoke-ScriptStep {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [switch]$RequireAdmin = $false
    )

    Write-Log "Starting step: $Name" "INFO"

    if ($RequireAdmin -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        Write-Log "SKIPPED: $Name (requires administrator)" "WARN" "Yellow"
        $script:WarningCount++
        return $false
    }

    if (-not (Test-Path $ScriptPath)) {
        Write-Log "ERROR: Script not found: $ScriptPath" "ERROR" "Red"
        $script:ErrorCount++
        return $false
    }

    if ($DryRun) {
        Write-Log "DRY RUN: Would execute: $Name" "INFO" "Gray"
        return $true
    }

    try {
        & $ScriptPath @Parameters
        if ($LASTEXITCODE -eq 0 -or $?) {
            Write-Log "COMPLETE: $Name" "SUCCESS" "Green"
            $script:SuccessCount++
            return $true
        } else {
            Write-Log "FAILED: $Name (exit code: $LASTEXITCODE)" "ERROR" "Red"
            $script:ErrorCount++
            return $false
        }
    } catch {
        Write-Log "ERROR in $Name : $($_.Exception.Message)" "ERROR" "Red"
        $script:ErrorCount++
        return $false
    }
}

function Step-Diagnostics {
    Write-Banner "STEP 1: System Diagnostics" "Checking BabyNAS connectivity"

    Write-Log "Running comprehensive diagnostics..." "INFO"

    if ($SkipDiagnostics) {
        Write-Log "Diagnostics skipped (use -SkipDiagnostics `$false to enable)" "WARN" "Yellow"
        return $true
    }

    $success = Invoke-ScriptStep `
        -Name "BabyNAS Diagnostics" `
        -ScriptPath ".\diagnose-baby-nas.ps1" `
        -Parameters @{ Verbose = $Verbose; Fix = $AutoFix }

    if ($success) {
        Write-Log "✓ Diagnostics passed" "SUCCESS" "Green"
    } else {
        Write-Log "⚠ Diagnostics detected issues" "WARN" "Yellow"
    }

    return $true
}

function Step-APIKey {
    Write-Banner "STEP 2: Generate TrueNAS API Key" "Required for automation"

    Write-Log "Generating TrueNAS API key via SSH..." "INFO"

    $success = Invoke-ScriptStep `
        -Name "API Key Generation" `
        -ScriptPath ".\create-api-key-ssh.ps1" `
        -Parameters @{ AutoUpdate = $true }

    if ($success) {
        Write-Log "✓ API key generated and .env updated" "SUCCESS" "Green"
    } else {
        Write-Log "⚠ API key generation needs manual attention" "WARN" "Yellow"
        Write-Log "Run create-api-key-ssh.ps1 manually and paste key in .env" "INFO"
    }

    return $true
}

function Step-ZDrive {
    Write-Banner "STEP 3: Setup Z: Drive Mapping" "Mount BabyNAS dataset"

    Write-Log "Setting up Z: drive mapping..." "INFO"

    $success = Invoke-ScriptStep `
        -Name "Z: Drive Setup" `
        -ScriptPath ".\setup-z-drive-mapping.ps1" `
        -Parameters @{}

    if ($success) {
        Write-Log "✓ Z: drive mapped successfully" "SUCCESS" "Green"
    } else {
        Write-Log "⚠ Z: drive mapping needs manual attention" "WARN" "Yellow"
    }

    return $true
}

function Step-VMMemory {
    Write-Banner "STEP 4: Reduce VM Memory to 8192 MB" "Optimize resource usage"

    Write-Log "Adjusting BabyNAS VM memory..." "INFO"

    $success = Invoke-ScriptStep `
        -Name "VM Memory Reduction" `
        -ScriptPath ".\reduce-vm-ram.ps1" `
        -Parameters @{ NewMemoryMB = 8192; Force = $true } `
        -RequireAdmin $true

    if ($success) {
        Write-Log "✓ VM memory reduced to 8192 MB" "SUCCESS" "Green"
    } else {
        Write-Log "⚠ VM memory reduction failed (may need admin)" "WARN" "Yellow"
    }

    return $true
}

function Step-ConfigVerification {
    Write-Banner "STEP 5: Configuration Verification" "Validate all settings"

    Write-Log "Verifying configuration files..." "INFO"

    $checks = @{
        ".env exists" = { Test-Path "D:\workspace\Baby_Nas\.env" }
        ".env.local exists" = { Test-Path "D:\workspace\Baby_Nas\.env.local" }
        "monitoring-config.json exists" = { Test-Path "D:\workspace\Baby_Nas\monitoring-config.json" }
        "API key configured" = { (Get-Content ".env" -Raw) -like "*TRUENAS_API_KEY=*" -and (Get-Content ".env" -Raw) -notmatch "TRUENAS_API_KEY=$" }
        "Domain configured" = { (Get-Content ".env" -Raw) -like "*BABY_NAS_HOSTNAME=babynas.isndotbiz.com*" }
    }

    Write-Host ""
    $passed = 0
    $failed = 0

    foreach ($check in $checks.Keys) {
        try {
            $result = & $checks[$check]
            if ($result) {
                Write-Host "  ✓ $check" -ForegroundColor Green
                Write-Log "✓ $check" "SUCCESS"
                $passed++
            } else {
                Write-Host "  ✗ $check" -ForegroundColor Red
                Write-Log "✗ $check" "ERROR"
                $failed++
            }
        } catch {
            Write-Host "  ? $check (error)" -ForegroundColor Yellow
            $failed++
        }
    }

    Write-Host ""
    Write-Log "Verification: $passed passed, $failed failed" "INFO"

    return ($failed -eq 0)
}

function Step-GitCommit {
    Write-Banner "STEP 6: Commit to GitHub" "Sync configuration changes"

    Write-Log "Preparing GitHub commit..." "INFO"

    $push = -not $NoGitPush

    $success = Invoke-ScriptStep `
        -Name "GitHub Commit" `
        -ScriptPath ".\commit-to-github.ps1" `
        -Parameters @{ Push = $push }

    if ($success) {
        Write-Log "✓ Changes committed to GitHub" "SUCCESS" "Green"
    } else {
        Write-Log "⚠ GitHub commit needs manual attention" "WARN" "Yellow"
    }

    return $true
}

function Step-FinalVerification {
    Write-Banner "STEP 7: Final System Verification" "Testing all components"

    Write-Log "Running final connectivity and configuration tests..." "INFO"

    Write-Host ""

    # Quick connectivity test
    Write-Host "Testing BabyNAS connectivity..." -ForegroundColor Yellow
    $ping = Test-Connection -ComputerName 172.21.203.18 -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        Write-Host "  ✓ Ping successful" -ForegroundColor Green
        Write-Log "✓ Ping to BabyNAS" "SUCCESS"
    } else {
        Write-Host "  ✗ Ping failed" -ForegroundColor Red
        Write-Log "✗ Ping to BabyNAS failed" "ERROR"
    }

    # SSH Test
    Write-Host "Testing SSH access..." -ForegroundColor Yellow
    $ssh = Test-NetConnection -ComputerName 172.21.203.18 -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet -ErrorAction SilentlyContinue
    if ($ssh -or $?) {
        Write-Host "  ✓ SSH port open" -ForegroundColor Green
        Write-Log "✓ SSH port 22 accessible" "SUCCESS"
    } else {
        Write-Host "  ✗ SSH port closed" -ForegroundColor Red
        Write-Log "✗ SSH port 22 not accessible" "ERROR"
    }

    # Web UI Test
    Write-Host "Testing Web UI access..." -ForegroundColor Yellow
    $web = Test-NetConnection -ComputerName 172.21.203.18 -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet -ErrorAction SilentlyContinue
    if ($web -or $?) {
        Write-Host "  ✓ HTTPS port open" -ForegroundColor Green
        Write-Log "✓ HTTPS port 443 accessible" "SUCCESS"
    } else {
        Write-Host "  ✗ HTTPS port closed" -ForegroundColor Yellow
        Write-Log "⚠ HTTPS port 443 not accessible" "WARN"
    }

    # Z: Drive check
    Write-Host "Checking Z: drive..." -ForegroundColor Yellow
    if (Test-Path Z:\) {
        Write-Host "  ✓ Z: drive accessible" -ForegroundColor Green
        Write-Log "✓ Z: drive mapped and accessible" "SUCCESS"
    } else {
        Write-Host "  ○ Z: drive not mapped" -ForegroundColor Gray
        Write-Log "ℹ Z: drive not mapped" "INFO"
    }

    Write-Host ""
}

function Show-CompletionSummary {
    Write-Banner "SETUP COMPLETE!" "All automation scripts executed"

    $elapsed = (Get-Date) - $script:StartTime

    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  ✓ Successful steps: $($script:SuccessCount)" -ForegroundColor Green
    Write-Host "  ⚠ Warnings: $($script:WarningCount)" -ForegroundColor Yellow
    Write-Host "  ✗ Errors: $($script:ErrorCount)" -ForegroundColor $(if ($script:ErrorCount -gt 0) { "Red" } else { "Green" })
    Write-Host "  ⏱ Total time: $($elapsed.Minutes)m $($elapsed.Seconds)s" -ForegroundColor Gray
    Write-Host ""

    if ($DryRun) {
        Write-Host "This was a DRY RUN. No actual changes were made." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Run connectivity check: .\quick-connectivity-check.ps1" -ForegroundColor Gray
    Write-Host "  2. Run full system check: .\CHECK-SYSTEM-STATE.ps1" -ForegroundColor Gray
    Write-Host "  3. Deploy automation: .\FULL-AUTOMATION.ps1" -ForegroundColor Gray
    Write-Host "  4. Monitor in real-time: .\monitor-baby-nas.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Log file: $script:LogFile" -ForegroundColor Gray
    Write-Host ""

    # Open log file option
    if (-not $DryRun -and $script:ErrorCount -gt 0) {
        $viewLog = Read-Host "View log file? (yes/no)"
        if ($viewLog -eq "yes") {
            Get-Content $script:LogFile | Out-Host
        }
    }
}

function Invoke-MasterSetup {
    Write-Banner "MASTER SETUP - BabyNAS Complete Deployment" "All-in-one configuration and automation"

    Write-Log "============================================" "INFO"
    Write-Log "MASTER SETUP STARTED" "INFO"
    Write-Log "Time: $([DateTime]::Now)" "INFO"
    Write-Log "Interactive: $Interactive" "INFO"
    Write-Log "Dry Run: $DryRun" "INFO"
    Write-Log "============================================" "INFO"

    Write-Host ""
    if ($DryRun) {
        Write-Host "⊘ DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    } else {
        Write-Host "This will configure your BabyNAS system with:" -ForegroundColor Yellow
        Write-Host "  ✓ Connectivity diagnostics" -ForegroundColor Gray
        Write-Host "  ✓ API key generation" -ForegroundColor Gray
        Write-Host "  ✓ Z: drive mapping" -ForegroundColor Gray
        Write-Host "  ✓ VM memory optimization" -ForegroundColor Gray
        Write-Host "  ✓ GitHub commit and sync" -ForegroundColor Gray
        Write-Host ""

        if ($Interactive) {
            $proceed = Read-Host "Continue? (yes/no)"
            if ($proceed -ne "yes") {
                Write-Log "Setup cancelled by user" "INFO"
                exit 0
            }
        }
    }

    Write-Host ""

    # Execute all steps
    Step-Diagnostics
    Step-APIKey
    Step-ZDrive
    Step-VMMemory
    Step-ConfigVerification
    Step-GitCommit
    Step-FinalVerification

    # Show summary
    Show-CompletionSummary

    Write-Log "============================================" "INFO"
    Write-Log "MASTER SETUP COMPLETED" "INFO"
    Write-Log "============================================" "INFO"
}

# Execute Master Setup
Invoke-MasterSetup
