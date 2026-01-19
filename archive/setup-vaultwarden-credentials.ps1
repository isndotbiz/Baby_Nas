#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup Vaultwarden credential entries for BabyNAS

.DESCRIPTION
    Creates vault entries in Vaultwarden for all BabyNAS credentials
    Uses OAuth 2.0 Client Credentials authentication

.EXAMPLE
    .\setup-vaultwarden-credentials.ps1
#>

param(
    [string]$VaultUrl = "https://vault.isn.biz",
    [string]$PythonScript = "vaultwarden-credential-manager.py"
)

# Color output
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

Write-Status "═══════════════════════════════════════════════════════════" "Info"
Write-Status "Vaultwarden BabyNAS Credential Setup" "Info"
Write-Status "═══════════════════════════════════════════════════════════" "Info"
Write-Host ""

# Verify Python script exists
if (-not (Test-Path $PythonScript)) {
    Write-Status "[FAIL] Python script not found: $PythonScript" "Error"
    exit 1
}

# Test Vaultwarden connection
Write-Status "Testing Vaultwarden connection..." "Info"
& python $PythonScript test
if ($LASTEXITCODE -ne 0) {
    Write-Status "✗ Failed to connect to Vaultwarden" "Error"
    exit 1
}

Write-Host ""
Write-Status "Creating credential entries..." "Info"
Write-Host ""

# BabyNAS SMB Credentials
$babyNasSmbCreds = @{
    ip = "192.168.215.2"
    hostname = "baby.isn.biz"
    protocol = "smb"
    shares = @(
        "backups",
        "veeam",
        "wsl-backups",
        "phone",
        "media"
    )
    username = "jdmal"
    description = "BabyNAS SMB file shares for backup storage"
} | ConvertTo-Json

Write-Status "1. BabyNAS-SMB" "Info"
Write-Host $babyNasSmbCreds
$babyNasSmbCreds | & python $PythonScript create "BabyNAS-SMB"
Write-Host ""

# BabyNAS API Credentials
$babyNasApiCreds = @{
    ip = "192.168.215.2"
    hostname = "baby.isn.biz"
    api_url = "http://192.168.215.2/api/v2.0"
    api_key = "1-VkZdCiOTla5o0cs2lDBocRiTS14RIGDPchTiSVg2Hflt1AcmBzYzJiBuJLkOTI9A"
    root_password = "74108520"
    description = "BabyNAS TrueNAS REST API credentials"
} | ConvertTo-Json

Write-Status "2. BabyNAS-API" "Info"
Write-Host $babyNasApiCreds
$babyNasApiCreds | & python $PythonScript create "BabyNAS-API"
Write-Host ""

# BabyNAS SSH Credentials
$babyNasSshCreds = @{
    hostname = "baby.isn.biz"
    ip = "192.168.215.2"
    ssh_user = "jdmal"
    ssh_key_path = "$env:USERPROFILE\.ssh\id_ed25519"
    ssh_port = 22
    description = "BabyNAS SSH key authentication for jdmal user"
} | ConvertTo-Json

Write-Status "3. BabyNAS-SSH" "Info"
Write-Host $babyNasSshCreds
$babyNasSshCreds | & python $PythonScript create "BabyNAS-SSH"
Write-Host ""

# ZFS Replication Credentials
$zfsReplicationCreds = @{
    source_host = "192.168.215.2"
    source_user = "root"
    target_host = "10.0.0.89"
    target_user = "baby-nas"
    ssh_key_path = "D:\workspace\Baby_Nas\keys\baby-nas-replication"
    ssh_pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwjIxc7vunMCVBfIGsOXr1xwQ9mLLTLA58ztyd5gUSC baby-nas-replication"
    datasets = @("tank/backups", "tank/veeam", "tank/wsl-backups", "tank/media", "tank/phone")
    schedule = "daily"
    description = "BabyNAS to Main NAS ZFS replication credentials"
} | ConvertTo-Json

Write-Status "4. ZFS-Replication" "Info"
Write-Host $zfsReplicationCreds
$zfsReplicationCreds | & python $PythonScript create "ZFS-Replication"
Write-Host ""

# Storage Pool Configuration
$storagePoolCreds = @{
    pool_name = "tank"
    pool_type = "RAIDZ1"
    data_vdevs = @(
        "/dev/disk/by-id/ata-HDD1",
        "/dev/disk/by-id/ata-HDD2",
        "/dev/disk/by-id/ata-HDD3"
    )
    slog_vdev = "250GB SSD"
    l2arc_vdev = "256GB SSD"
    compression = "lz4"
    recordsize = "1M"
    description = "BabyNAS ZFS pool configuration"
} | ConvertTo-Json

Write-Status "5. StoragePool-Config" "Info"
Write-Host $storagePoolCreds
$storagePoolCreds | & python $PythonScript create "StoragePool-Config"
Write-Host ""

# List all created entries
Write-Host ""
Write-Status "Listing all credential entries in Vaultwarden..." "Info"
Write-Host ""
& python $PythonScript list

Write-Host ""
Write-Status "[OK] Vaultwarden credential setup complete!" "Success"
Write-Status "================================================================" "Success"

Write-Host @"

NEXT STEPS:

1. Verify credentials in Vaultwarden:
   Visit: $VaultUrl

2. Share Vault access with other Claude Code instances:
   - Use VAULTWARDEN_CLIENT_ID and VAULTWARDEN_CLIENT_SECRET from .env.local
   - These credentials are already in both Baby_Nas and True_Nas .env.local files

3. Retrieve credentials programmatically:
   python vaultwarden-credential-manager.py get "BabyNAS-SMB"
   python vaultwarden-credential-manager.py get "BabyNAS-API"
   python vaultwarden-credential-manager.py get "BabyNAS-SSH"

4. Use 1Password CLI for additional credential management:
   op vault list
   op item list --vault "BabyNAS"

"@
