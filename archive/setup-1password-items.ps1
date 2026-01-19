#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup 1Password vault items for BabyNAS credentials

.DESCRIPTION
    Creates 1Password items in the BabyNAS vault for credential management
    Requires 1Password CLI to be installed and authenticated

.EXAMPLE
    .\setup-1password-items.ps1
#>

# Colors
function Write-Status {
    param([string]$Message, [ValidateSet("Info", "Success", "Warning", "Error")]$Type = "Info")
    $colors = @{
        Info    = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error   = "Red"
    }
    Write-Host $Message -ForegroundColor $colors[$Type]
}

Write-Status "============================================================" "Info"
Write-Status "1Password BabyNAS Credential Setup" "Info"
Write-Status "============================================================" "Info"
Write-Host ""

# Check if op CLI is installed
Write-Status "Checking 1Password CLI installation..." "Info"
$opVersion = op --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Status "[OK] 1Password CLI installed: $opVersion" "Success"
} else {
    Write-Status "[FAIL] 1Password CLI not found" "Error"
    Write-Status "Install from: https://app-updates.agilebits.com/product_history/CLI2" "Info"
    exit 1
}
Write-Host ""

# Check if signed in
Write-Status "Checking 1Password authentication..." "Info"
$whoami = op whoami 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Status "[WARN] Not signed in to 1Password" "Warning"
    Write-Host "Please sign in:"
    Write-Host "  op signin"
    Write-Host ""
    exit 1
} else {
    Write-Status "[OK] Authenticated as: $whoami" "Success"
}
Write-Host ""

# Check/create BabyNAS vault
Write-Status "Checking BabyNAS vault..." "Info"
$vaults = op vault list --format json | ConvertFrom-Json
$babyNasVault = $vaults | Where-Object { $_.name -eq "BabyNAS" }

if ($null -eq $babyNasVault) {
    Write-Status "[CREATE] Creating BabyNAS vault..." "Warning"
    op vault create --name "BabyNAS" --description "BabyNAS backup infrastructure credentials"
    if ($LASTEXITCODE -eq 0) {
        Write-Status "[OK] BabyNAS vault created" "Success"
    } else {
        Write-Status "[FAIL] Failed to create vault" "Error"
        exit 1
    }
} else {
    Write-Status "[OK] BabyNAS vault exists (ID: $($babyNasVault.id))" "Success"
}
Write-Host ""

# Create items
Write-Status "Creating credential items..." "Info"
Write-Host ""

# 1. BabyNAS-SMB
Write-Status "1. BabyNAS-SMB" "Info"
try {
    op item create `
      --vault "BabyNAS" `
      --category "server" `
      --title "BabyNAS-SMB" `
      --generate-password=off `
      ipv4_address="192.168.215.2" `
      hostname="baby.isn.biz" `
      username="jdmal" `
      "notes=BabyNAS SMB file shares for backup storage. Shares: backups, veeam, wsl-backups, phone, media" 2>&1 | Out-Null

    Write-Status "   [OK] Created" "Success"
} catch {
    Write-Status "   [INFO] Already exists or error (may be normal)" "Info"
}
Write-Host ""

# 2. BabyNAS-API
Write-Status "2. BabyNAS-API" "Info"
try {
    op item create `
      --vault "BabyNAS" `
      --category "server" `
      --title "BabyNAS-API" `
      ipv4_address="192.168.215.2" `
      hostname="baby.isn.biz" `
      password="1-VkZdCiOTla5o0cs2lDBocRiTS14RIGDPchTiSVg2Hflt1AcmBzYzJiBuJLkOTI9A" `
      "notes=TrueNAS REST API endpoint: http://192.168.215.2/api/v2.0" 2>&1 | Out-Null

    Write-Status "   [OK] Created" "Success"
} catch {
    Write-Status "   [INFO] Already exists or error (may be normal)" "Info"
}
Write-Host ""

# 3. BabyNAS-SSH
Write-Status "3. BabyNAS-SSH" "Info"
try {
    op item create `
      --vault "BabyNAS" `
      --category "server" `
      --title "BabyNAS-SSH" `
      ipv4_address="192.168.215.2" `
      hostname="baby.isn.biz" `
      username="jdmal" `
      "notes=SSH authentication with Ed25519 key. Key path: ~/.ssh/id_ed25519. Port: 22" 2>&1 | Out-Null

    Write-Status "   [OK] Created" "Success"
} catch {
    Write-Status "   [INFO] Already exists or error (may be normal)" "Info"
}
Write-Host ""

# 4. ZFS-Replication
Write-Status "4. ZFS-Replication" "Info"
try {
    op item create `
      --vault "BabyNAS" `
      --category "server" `
      --title "ZFS-Replication" `
      hostname="baby.isn.biz" `
      username="baby-nas" `
      "notes=Replication from BabyNAS (192.168.215.2) to Main NAS (10.0.0.89). Key: keys/baby-nas-replication. Datasets: tank/backups, tank/veeam, tank/wsl-backups, tank/media, tank/phone" 2>&1 | Out-Null

    Write-Status "   [OK] Created" "Success"
} catch {
    Write-Status "   [INFO] Already exists or error (may be normal)" "Info"
}
Write-Host ""

# 5. StoragePool-Config
Write-Status "5. StoragePool-Config" "Info"
try {
    op item create `
      --vault "BabyNAS" `
      --category "server" `
      --title "StoragePool-Config" `
      "notes=Pool: tank (RAIDZ1, 3x6TB). SLOG: 250GB SSD. L2ARC: 256GB SSD. Compression: LZ4. Record Size: 1M" 2>&1 | Out-Null

    Write-Status "   [OK] Created" "Success"
} catch {
    Write-Status "   [INFO] Already exists or error (may be normal)" "Info"
}
Write-Host ""

# List items
Write-Status "Listing all items in BabyNAS vault..." "Info"
Write-Host ""
op item list --vault "BabyNAS" --format table | Select-Object -First 20

Write-Host ""
Write-Status "[OK] 1Password setup complete!" "Success"
Write-Status "============================================================" "Success"

Write-Host @"

NEXT STEPS:

1. Access 1Password Web Vault:
   https://my.1password.com

2. View BabyNAS credentials:
   op item get "BabyNAS-SMB" --vault "BabyNAS"
   op item list --vault "BabyNAS"

3. Use in scripts:
   PowerShell:
     `$ip = op item get "BabyNAS-SMB" --vault "BabyNAS" --fields "ipv4_address"

   Bash:
     IP=`$(op item get "BabyNAS-SMB" --vault "BabyNAS" --fields "ipv4_address")

4. Share with team:
   - Via 1Password: Invite users to BabyNAS vault
   - Via CLI: Share credentials programmatically

5. Further documentation:
   - Read: SETUP-1PASSWORD-CLI.md
   - Read: CREDENTIAL-SHARING-GUIDE.md

"@
