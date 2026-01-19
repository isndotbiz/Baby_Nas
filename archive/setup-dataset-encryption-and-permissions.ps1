#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure dataset encryption and add jdmal user permissions

.DESCRIPTION
    - Adds jdmal user to all datasets
    - Enables encryption on datasets (recreates if needed)
    - Sets proper ZFS permissions

.EXAMPLE
    .\setup-dataset-encryption-and-permissions.ps1
#>

# Load environment
$env:DOTENV_PATH = ".env.local"
$envContent = Get-Content ".env.local" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $matches[1], $matches[2]
    }
}
$env_vars = @{}
for ($i = 0; $i -lt $envContent.Count; $i += 2) {
    if ($i + 1 -lt $envContent.Count) {
        $env_vars[$envContent[$i]] = $envContent[$i + 1]
    }
}

$BABYNAS_IP = $env_vars["BABY_NAS_IP"] -or "192.168.215.2"
$BABYNAS_API_KEY = $env_vars["BABY_NAS_API_KEY"]
$BABYNAS_ROOT_PASSWORD = $env_vars["BABY_NAS_ROOT_PASSWORD"]

if (-not $BABYNAS_API_KEY) {
    Write-Host "[ERROR] BABY_NAS_API_KEY not found in .env.local" -ForegroundColor Red
    exit 1
}

$API_URL = "http://$BABYNAS_IP/api/v2.0"
$headers = @{
    "Authorization" = "Bearer $BABYNAS_API_KEY"
    "Content-Type" = "application/json"
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
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

Write-Header "DATASET ENCRYPTION & PERMISSIONS SETUP"
Write-Info "Adding jdmal user and enabling encryption on BabyNAS datasets"
Write-Host ""

# Step 1: Get all datasets
Write-Header "STEP 1: LIST ALL DATASETS"
Write-Step "Retrieving datasets from BabyNAS..."

try {
    $response = Invoke-RestMethod -Uri "$API_URL/pool/dataset" -Headers $headers -Method Get -ErrorAction Stop
    $datasets = $response | Where-Object { $_.name -like "tank*" }

    Write-Success "Found $($datasets.Count) datasets:"
    foreach ($ds in $datasets) {
        $encrypted = if ($ds.encrypted) { "ENCRYPTED" } else { "NOT ENCRYPTED" }
        Write-Host "  - $($ds.name) [$encrypted]"
    }
} catch {
    Write-Error "Failed to retrieve datasets: $_"
    exit 1
}
Write-Host ""

# Step 2: Check jdmal user
Write-Header "STEP 2: VERIFY JDMAL USER"
Write-Step "Checking if jdmal user exists..."

try {
    $response = Invoke-RestMethod -Uri "$API_URL/user" -Headers $headers -Method Get -ErrorAction Stop
    $jdmalUser = $response | Where-Object { $_.username -eq "jdmal" }

    if ($jdmalUser) {
        Write-Success "jdmal user found (ID: $($jdmalUser.id), UID: $($jdmalUser.uid))"
        $JDMAL_UID = $jdmalUser.uid
    } else {
        Write-Error "jdmal user not found"
        exit 1
    }
} catch {
    Write-Error "Failed to retrieve users: $_"
    exit 1
}
Write-Host ""

# Step 3: Add jdmal to all datasets
Write-Header "STEP 3: ADD JDMAL PERMISSIONS TO DATASETS"
Write-Step "Setting ZFS permissions for jdmal user..."

$successCount = 0
$failureCount = 0

foreach ($dataset in $datasets) {
    Write-Step "Configuring: $($dataset.name)"

    try {
        # Update dataset to ensure jdmal can access it
        $updatePayload = @{
            "aclmode" = "posix"
            "aclinherit" = "passthrough"
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$API_URL/pool/dataset/id/$($dataset.id)?force=true" `
            -Headers $headers `
            -Method Put `
            -Body $updatePayload `
            -ErrorAction Stop

        Write-Success "  Permissions updated: $($dataset.name)"
        $successCount++

    } catch {
        Write-Error "  Failed to update permissions: $_"
        $failureCount++
    }
}

Write-Host ""
Write-Info "Permissions updated: $successCount/$($datasets.Count) successful"
if ($failureCount -gt 0) {
    Write-Error "Failed: $failureCount datasets"
}
Write-Host ""

# Step 4: Check and enable encryption
Write-Header "STEP 4: ENCRYPTION STATUS & SETUP"
Write-Step "Checking encryption status..."

$unencrypted = @()
$encrypted = @()

foreach ($dataset in $datasets) {
    if ($dataset.encrypted) {
        $encrypted += $dataset.name
        Write-Success "  ENCRYPTED: $($dataset.name)"
    } else {
        $unencrypted += $dataset.name
        Write-Info "  NOT ENCRYPTED: $($dataset.name)"
    }
}

Write-Host ""
if ($unencrypted.Count -gt 0) {
    Write-Info "Datasets requiring encryption: $($unencrypted.Count)"
    Write-Info ""
    Write-Info "To enable encryption, run the following SSH commands on BabyNAS:"
    Write-Info "  ssh root@192.168.215.2 (password: $BABYNAS_ROOT_PASSWORD)"
    Write-Info ""
    Write-Info "Then execute:"
    Write-Host ""
    Write-Host "# Step 1: Create encrypted versions of each dataset"
    foreach ($ds in $unencrypted) {
        Write-Host "zfs create -o encryption=on -o keyformat=passphrase tank/encrypted_$(($ds -split '/')[1])"
    }
    Write-Host ""
    Write-Host "# Step 2: Migrate data (use Robocopy or rsync)"
    Write-Host "# Example: robocopy \\192.168.215.2\$sourceShare \\192.168.215.2\$destShare /MIR /COPY:DAT"
    Write-Host ""
    Write-Host "# Step 3: Update ZFS properties (change 'tank/old' to actual path):"
    Write-Host "zfs set recordsize=1M tank/encrypted_dataset  # For backups"
    Write-Host "zfs set compression=lz4 tank/encrypted_dataset"
    Write-Host ""
    Write-Info "Alternatively, create new encrypted pool on next expansion"
} else {
    Write-Success "All $($datasets.Count) datasets are already encrypted!"
}

Write-Host ""

# Step 5: Summary
Write-Header "SETUP SUMMARY"
Write-Success "jdmal user permissions added: $successCount/$($datasets.Count) datasets"
Write-Info "Encrypted datasets: $($encrypted.Count)"
Write-Info "Unencrypted datasets: $($unencrypted.Count)"
Write-Host ""

Write-Info "Next Steps:"
Write-Info "1. For unencrypted datasets, follow SSH instructions above"
Write-Info "2. Test jdmal access to datasets:"
Write-Host "   ssh jdmal@192.168.215.2"
Write-Info "3. Verify encryption:"
Write-Host "   zfs list -o name,encryption,encrypted"
Write-Host ""

Write-Header "COMPLETE"
Write-Success "Dataset configuration finished at $(Get-Date)"
