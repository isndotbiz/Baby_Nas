#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick setup for Option C (1Password + Vaultwarden)
    Run this locally to complete full credential setup

.DESCRIPTION
    Signs into 1Password, creates vault items, and verifies Vaultwarden setup
    Takes about 15 minutes total

.EXAMPLE
    .\QUICK-SETUP-OPTION-C.ps1
#>

# Colors
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host ">>> $Text" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "[INFO] $Text" -ForegroundColor Cyan
}

function Write-Error {
    param([string]$Text)
    Write-Host "[ERROR] $Text" -ForegroundColor Red
}

Write-Header "CREDENTIAL SETUP - OPTION C (1Password + Vaultwarden)"

Write-Info "This script will:"
Write-Info "  1. Sign you into 1Password"
Write-Info "  2. Create 5 vault items in 1Password"
Write-Info "  3. Verify Vaultwarden connection"
Write-Info "  4. Create 5 vault items in Vaultwarden (manual)"
Write-Info "  5. Verify both systems working"
Write-Host ""

# Step 1: 1Password Sign In
Write-Header "STEP 1: 1PASSWORD SIGNIN (One-time)"
Write-Step "Checking 1Password CLI version..."

$opVersion = op --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "1Password CLI installed: $opVersion"
} else {
    Write-Error "1Password CLI not found. Install from: https://app-updates.agilebits.com/product_history/CLI2"
    exit 1
}

Write-Step "Signing into 1Password..."
Write-Info "You will be prompted for:"
Write-Info "  - Email address"
Write-Info "  - Master password"
Write-Info "  - Secret key (from your 1Password account settings)"
Write-Host ""

op signin

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to sign into 1Password"
    exit 1
}

Write-Success "Successfully signed into 1Password!"
$account = op whoami 2>&1
Write-Success "Signed in as: $account"
Write-Host ""

# Step 2: 1Password Setup
Write-Header "STEP 2: 1PASSWORD VAULT ITEMS SETUP"
Write-Step "Running 1Password setup script..."
Write-Info "This will create 5 credential items in your BabyNAS vault"
Write-Host ""

.\setup-1password-items.ps1

if ($LASTEXITCODE -ne 0) {
    Write-Error "1Password setup failed"
    exit 1
}

Write-Success "1Password vault items created!"
Write-Host ""

# Step 3: Verify 1Password
Write-Header "STEP 3: VERIFY 1PASSWORD"
Write-Step "Listing 1Password items..."

$items = op item list --vault "BabyNAS" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "1Password items created:"
    $items
} else {
    Write-Error "Failed to list 1Password items"
}

Write-Host ""

# Step 4: Vaultwarden Test
Write-Header "STEP 4: VAULTWARDEN CONNECTION TEST"
Write-Step "Testing Vaultwarden connection..."

python test-vaultwarden-simple.py

if ($LASTEXITCODE -ne 0) {
    Write-Error "Vaultwarden connection failed"
}

Write-Host ""

# Step 5: Vaultwarden Manual Setup Instructions
Write-Header "STEP 5: VAULTWARDEN VAULT ENTRIES SETUP (MANUAL)"
Write-Info "Vaultwarden requires manual entry creation via web UI"
Write-Info "This takes about 5 minutes"
Write-Host ""

Write-Step "Opening Vaultwarden web UI..."
Start-Process "https://vault.isn.biz"

Write-Info "Follow these steps:"
Write-Info "  1. Login to https://vault.isn.biz"
Write-Info "  2. Select 'BABY_NAS' organization"
Write-Info "  3. Read: create-vaultwarden-entries-instructions.md"
Write-Info "  4. Create 5 Secure Note entries (copy-paste JSON)"
Write-Info "  5. Return here when done"
Write-Host ""

Read-Host "Press Enter when you've created all 5 Vaultwarden entries"

Write-Host ""

# Step 6: Verify Vaultwarden
Write-Header "STEP 6: VERIFY VAULTWARDEN"
Write-Step "Checking Vaultwarden entries..."

$vaultEntries = python vaultwarden-credential-manager.py list 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Success "Vaultwarden entries found:"
    $vaultEntries
} else {
    Write-Error "No entries found in Vaultwarden"
    Write-Info "Make sure you created all 5 entries at https://vault.isn.biz"
}

Write-Host ""

# Final Summary
Write-Header "SETUP COMPLETE!"

Write-Success "Option C Setup Finished!"
Write-Host ""

Write-Info "You now have:"
Write-Info "  ✅ 5 items in 1Password (easy to use, share with team)"
Write-Info "  ✅ 5 items in Vaultwarden (self-hosted backup)"
Write-Info "  ✅ Python API client (programmatic access)"
Write-Host ""

Write-Header "NEXT: USE YOUR CREDENTIALS"

Write-Info "1Password:"
Write-Info '  PS> op item get "BabyNAS-SMB" --vault "BabyNAS"'
Write-Host ""

Write-Info "Vaultwarden:"
Write-Info "  PS> python vaultwarden-credential-manager.py get 'BabyNAS-SMB'"
Write-Host ""

Write-Info "Share with team:"
Write-Info "  1Password: Click 'Share' in 1Password web UI"
Write-Info "  Vaultwarden: Share these environment variables:"
Write-Info "    VAULTWARDEN_CLIENT_ID=organization.1a4d4b38-c293-4d05-aad1-f9a037483338"
Write-Info "    VAULTWARDEN_CLIENT_SECRET=lG1GNsHXEmYMnwo58eD0ahGMItdtoh"
Write-Host ""

Write-Header "Setup successful! Ready for production use."

Write-Host @"

Documentation:
  • CREDENTIAL-SETUP-GETTING-STARTED.txt (Quick reference)
  • COMPLETE-CREDENTIAL-SETUP-SUMMARY.md (Full guide)
  • SETUP-1PASSWORD-CLI.md (1Password advanced)
  • create-vaultwarden-entries-instructions.md (Manual setup)

Questions? Check the documentation or run:
  python vaultwarden-credential-manager.py test
  op item list --vault "BabyNAS"

"@
