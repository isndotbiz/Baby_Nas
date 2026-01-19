# BabyNAS Setup Wizard - Interactive Configuration and Deployment
# Guides users through complete setup process with options and validation

param(
    [switch]$Verbose = $false,
    [switch]$SkipDiagnostics = $false
)

# Initialize
$ErrorActionPreference = "Continue"
$ProgressSteps = @()
$CompletedSteps = @()

function Write-Banner {
    param([string]$Title)
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $($Title.PadRight(60)) ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Menu {
    param([string]$Title, [hashtable]$Options, [int]$DefaultOption = 1)

    Write-Host $Title -ForegroundColor Yellow
    Write-Host ""

    $i = 1
    foreach ($key in $Options.Keys | Sort-Object { [int]$_ }) {
        $selected = if ($i -eq $DefaultOption) { " (default)" } else { "" }
        Write-Host "  $key) $($Options[$key])$selected" -ForegroundColor Gray
        $i++
    }

    Write-Host ""
    $choice = Read-Host "Select option"
    return $choice
}

function Test-Prerequisites {
    Write-Banner "Checking Prerequisites"

    $prereqs = @{
        PowerShell = @{
            Test = { $PSVersionTable.PSVersion.Major -ge 5 }
            Message = "PowerShell 5.0+"
        }
        Git = @{
            Test = { git --version >$null 2>&1; $LASTEXITCODE -eq 0 }
            Message = "Git installed"
        }
        Hyper-V = @{
            Test = { Get-Module Hyper-V -ErrorAction SilentlyContinue }
            Message = "Hyper-V module available"
        }
    }

    $allPass = $true
    foreach ($check in $prereqs.Keys) {
        $result = & $prereqs[$check].Test
        $status = if ($result) { "✓" } else { "✗" }
        $color = if ($result) { "Green" } else { "Red" }
        Write-Host "  $status $($prereqs[$check].Message)" -ForegroundColor $color
        if (-not $result) { $allPass = $false }
    }

    Write-Host ""
    if (-not $allPass) {
        Write-Host "⚠ Some prerequisites are missing. Setup may not work correctly." -ForegroundColor Yellow
        $continue = Read-Host "Continue anyway? (yes/no)"
        if ($continue -ne "yes") { exit 1 }
    }

    Write-Host "✓ Prerequisites check complete" -ForegroundColor Green
}

function Step-Diagnostics {
    Write-Banner "BabyNAS Connectivity Diagnostics"

    Write-Host "Running comprehensive diagnostics..." -ForegroundColor Yellow
    Write-Host "(This may take 30 seconds)" -ForegroundColor Gray
    Write-Host ""

    if ($SkipDiagnostics) {
        Write-Host "⊘ Diagnostics skipped (use -SkipDiagnostics `$false to enable)" -ForegroundColor Gray
        return $false
    }

    # Run diagnostics script if it exists
    if (Test-Path ".\diagnose-baby-nas.ps1") {
        & ".\diagnose-baby-nas.ps1" -Verbose:$Verbose
        $diagPass = $?
    } else {
        Write-Host "⚠ Diagnostics script not found. Skipping detailed checks." -ForegroundColor Yellow
        $diagPass = $false
    }

    Write-Host ""
    $fix = Read-Host "Attempt to fix connectivity issues? (yes/no)"
    if ($fix -eq "yes") {
        Write-Host "Running auto-fix..." -ForegroundColor Yellow
        & ".\diagnose-baby-nas.ps1" -Fix -Verbose:$Verbose
    }

    return $diagPass
}

function Step-APIKey {
    Write-Banner "Generate TrueNAS API Key"

    Write-Host "The API key is required for automation scripts." -ForegroundColor Yellow
    Write-Host ""

    $options = @{
        "1" = "Automatic (via SSH key)"
        "2" = "Manual (via Web UI)"
        "3" = "Skip for now"
    }

    $choice = Write-Menu "How would you like to generate the API key?" $options 1

    switch ($choice) {
        "1" {
            Write-Host "Running API key generation script..." -ForegroundColor Yellow
            if (Test-Path ".\create-api-key-ssh.ps1") {
                & ".\create-api-key-ssh.ps1" -AutoUpdate $true
                $CompletedSteps += "API Key Generated (Auto)"
            } else {
                Write-Host "✗ Script not found: create-api-key-ssh.ps1" -ForegroundColor Red
            }
        }
        "2" {
            Write-Host "Opening TrueNAS Web UI..." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "1. Open: https://172.21.203.18" -ForegroundColor Cyan
            Write-Host "2. Login with root credentials from .env" -ForegroundColor Cyan
            Write-Host "3. Go to: System → API Keys" -ForegroundColor Cyan
            Write-Host "4. Click: Add" -ForegroundColor Cyan
            Write-Host "5. Name: Baby-Nas-Automation" -ForegroundColor Cyan
            Write-Host "6. Copy the generated key" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Paste the API key below:" -ForegroundColor Yellow
            $apiKey = Read-Host "API Key"

            if ($apiKey -and $apiKey.Length -gt 30) {
                Write-Host "Updating .env file..." -ForegroundColor Yellow
                $envFile = "D:\workspace\Baby_Nas\.env"
                if (Test-Path $envFile) {
                    $content = Get-Content $envFile -Raw
                    $content = $content -replace 'TRUENAS_API_KEY=.*', "TRUENAS_API_KEY=$apiKey"
                    Set-Content $envFile -Value $content -Encoding UTF8
                    Write-Host "✓ API key saved to .env" -ForegroundColor Green
                    $CompletedSteps += "API Key Configured (Manual)"
                }
            }
        }
        "3" {
            Write-Host "Skipping API key generation." -ForegroundColor Gray
            Write-Host "⚠ Some scripts will not work without the API key." -ForegroundColor Yellow
        }
    }
}

function Step-ZDrive {
    Write-Banner "Setup Z: Drive Mapping"

    Write-Host "Map a BabyNAS dataset as Z: drive for easy access." -ForegroundColor Yellow
    Write-Host ""

    $options = @{
        "1" = "Yes, setup Z: drive now"
        "2" = "Manual setup later"
        "3" = "Skip"
    }

    $choice = Write-Menu "Setup Z: drive mapping?" $options 1

    switch ($choice) {
        "1" {
            Write-Host "Running Z: drive setup..." -ForegroundColor Yellow
            if (Test-Path ".\setup-z-drive-mapping.ps1") {
                & ".\setup-z-drive-mapping.ps1"
                $CompletedSteps += "Z: Drive Mapped"
            } else {
                Write-Host "✗ Script not found: setup-z-drive-mapping.ps1" -ForegroundColor Red
            }
        }
        "2" {
            Write-Host "To setup manually later, run:" -ForegroundColor Yellow
            Write-Host "  .\setup-z-drive-mapping.ps1" -ForegroundColor Gray
        }
        "3" {
            Write-Host "Skipping Z: drive setup." -ForegroundColor Gray
        }
    }
}

function Step-VMMemory {
    Write-Banner "Adjust VM Memory Settings"

    Write-Host "Current VM memory: (detecting...)" -ForegroundColor Yellow

    try {
        $vm = Get-VM | Where-Object { $_.Name -like '*baby*' -or $_.Name -like '*truenas*' } | Select-Object -First 1
        if ($vm) {
            $currentMemoryMB = [int]($vm.MemoryAssigned / 1MB)
            Write-Host "Current VM memory: $currentMemoryMB MB" -ForegroundColor Gray
            Write-Host ""

            $options = @{
                "1" = "Reduce to 8192 MB (8 GB)"
                "2" = "Reduce to 12288 MB (12 GB)"
                "3" = "Keep current settings"
                "4" = "Specify custom value"
            }

            $choice = Write-Menu "Adjust VM memory?" $options 3

            switch ($choice) {
                "1" {
                    Write-Host "⚠ Administrator privileges required!" -ForegroundColor Yellow
                    if (Test-Path ".\reduce-vm-ram.ps1") {
                        & ".\reduce-vm-ram.ps1" -NewMemoryMB 8192
                        $CompletedSteps += "VM Memory Reduced to 8GB"
                    }
                }
                "2" {
                    Write-Host "⚠ Administrator privileges required!" -ForegroundColor Yellow
                    if (Test-Path ".\reduce-vm-ram.ps1") {
                        & ".\reduce-vm-ram.ps1" -NewMemoryMB 12288
                        $CompletedSteps += "VM Memory Reduced to 12GB"
                    }
                }
                "4" {
                    $customMB = Read-Host "Enter memory in MB (e.g., 10240)"
                    if ($customMB -match '^\d+$') {
                        Write-Host "⚠ Administrator privileges required!" -ForegroundColor Yellow
                        if (Test-Path ".\reduce-vm-ram.ps1") {
                            & ".\reduce-vm-ram.ps1" -NewMemoryMB $customMB
                            $CompletedSteps += "VM Memory Adjusted to ${customMB}MB"
                        }
                    } else {
                        Write-Host "Invalid memory value." -ForegroundColor Red
                    }
                }
                default {
                    Write-Host "Keeping current memory settings." -ForegroundColor Gray
                }
            }
        }
    } catch {
        Write-Host "Could not detect VM or adjust memory." -ForegroundColor Yellow
        Write-Host "Try manual adjustment: `$vm = Get-VM -Name 'Baby-NAS'; Set-VMMemory `$vm -StartupBytes 8GB" -ForegroundColor Gray
    }
}

function Step-GitHub {
    Write-Banner "Commit Changes to GitHub"

    Write-Host "Ready to commit configuration changes to GitHub." -ForegroundColor Yellow
    Write-Host ""

    $options = @{
        "1" = "Commit and push to GitHub"
        "2" = "Commit only (don't push)"
        "3" = "Skip for now"
    }

    $choice = Write-Menu "Commit changes?" $options 1

    switch ($choice) {
        "1" {
            Write-Host "Running commit with push..." -ForegroundColor Yellow
            if (Test-Path ".\commit-to-github.ps1") {
                & ".\commit-to-github.ps1" -Push
                $CompletedSteps += "Committed to GitHub"
            }
        }
        "2" {
            Write-Host "Running commit (no push)..." -ForegroundColor Yellow
            if (Test-Path ".\commit-to-github.ps1") {
                & ".\commit-to-github.ps1"
                $CompletedSteps += "Local Commit Created"
            }
        }
        "3" {
            Write-Host "Skipping GitHub commit." -ForegroundColor Gray
        }
    }
}

function Step-Verification {
    Write-Banner "Verify Setup Completion"

    Write-Host "Quick verification tests:" -ForegroundColor Yellow
    Write-Host ""

    # Test connectivity
    Write-Host "Testing network connectivity..." -ForegroundColor Gray
    $ping = Test-Connection -ComputerName 172.21.203.18 -Count 1 -Quiet -ErrorAction SilentlyContinue
    Write-Host "  Ping to BabyNAS: $(if ($ping) { '✓ OK' } else { '✗ Failed' })" -ForegroundColor $(if ($ping) { 'Green' } else { 'Red' })

    # Test Z: drive
    if (Test-Path Z:\) {
        Write-Host "  Z: drive access: ✓ OK" -ForegroundColor Green
    } else {
        Write-Host "  Z: drive access: ○ Not mapped" -ForegroundColor Gray
    }

    # Test .env API key
    $envFile = "D:\workspace\Baby_Nas\.env"
    $envContent = Get-Content $envFile -Raw -ErrorAction SilentlyContinue
    $hasApiKey = $envContent -like "*TRUENAS_API_KEY=*" -and $envContent -notmatch "TRUENAS_API_KEY=$"
    Write-Host "  API key in .env: $(if ($hasApiKey) { '✓ Configured' } else { '✗ Missing' })" -ForegroundColor $(if ($hasApiKey) { 'Green' } else { 'Yellow' })

    Write-Host ""
    Write-Host "Completed steps:" -ForegroundColor Yellow
    if ($CompletedSteps.Count -gt 0) {
        $CompletedSteps | ForEach-Object { Write-Host "  ✓ $_" -ForegroundColor Green }
    } else {
        Write-Host "  (None yet)" -ForegroundColor Gray
    }
}

function Show-NextSteps {
    Write-Banner "Next Steps"

    Write-Host "Setup wizard complete! Here's what to do next:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Verify Configuration" -ForegroundColor Cyan
    Write-Host "   Run: .\quick-connectivity-check.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Full System Check" -ForegroundColor Cyan
    Write-Host "   Run: .\CHECK-SYSTEM-STATE.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Deploy Automation" -ForegroundColor Cyan
    Write-Host "   Run: .\FULL-AUTOMATION.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Monitor in Real-Time" -ForegroundColor Cyan
    Write-Host "   Run: .\monitor-baby-nas.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. Check Logs" -ForegroundColor Cyan
    Write-Host "   Location: C:\Logs\" -ForegroundColor Gray
    Write-Host ""
}

# Main Wizard Flow
function Invoke-SetupWizard {
    Write-Banner "BabyNAS Complete Setup Wizard"

    Write-Host "This wizard will guide you through:" -ForegroundColor Yellow
    Write-Host "  ✓ Connectivity diagnostics" -ForegroundColor Gray
    Write-Host "  ✓ API key generation" -ForegroundColor Gray
    Write-Host "  ✓ Z: drive mapping" -ForegroundColor Gray
    Write-Host "  ✓ VM memory optimization" -ForegroundColor Gray
    Write-Host "  ✓ GitHub commit and sync" -ForegroundColor Gray
    Write-Host ""

    $start = Read-Host "Begin setup? (yes/no)"
    if ($start -ne "yes") {
        Write-Host "Setup cancelled." -ForegroundColor Gray
        exit 0
    }

    # Run setup steps
    Test-Prerequisites
    Step-Diagnostics
    Step-APIKey
    Step-ZDrive
    Step-VMMemory
    Step-GitHub
    Step-Verification
    Show-NextSteps

    Write-Host "Setup wizard completed successfully!" -ForegroundColor Green
    Write-Host ""
}

# Execute
Invoke-SetupWizard
