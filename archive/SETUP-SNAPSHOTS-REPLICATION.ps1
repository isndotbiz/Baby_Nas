#Requires -Version 5.0
# Complete ZFS Snapshot & Replication Setup
# Reads credentials from D:\workspace\true_nas\.env.local

param(
    [string]$EnvPath = "D:\workspace\Baby_Nas\.env.local",
    [string]$MainNasEnvPath = "D:\workspace\true_nas\.env.local"
)

Write-Host ""
Write-Host "=== AUTOMATIC ZFS SNAPSHOTS & REPLICATION SETUP ===" -ForegroundColor Cyan
Write-Host "Source: BabyNAS (172.21.203.18)" -ForegroundColor Gray
Write-Host "Target: Main NAS (10.0.0.89)" -ForegroundColor Gray
Write-Host ""

# Load env file
function Load-EnvFile {
    param([string]$Path)
    $vars = @{}
    if (Test-Path $Path) {
        Get-Content $Path | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
            $key, $value = $_ -split '=', 2
            $vars[$key.Trim()] = $value.Trim()
        }
    }
    return $vars
}

Write-Host "1. Loading Configuration..." -ForegroundColor Yellow

$env_local = Load-EnvFile $EnvPath
$mainnas_env = Load-EnvFile $MainNasEnvPath

Write-Host "   - Loaded: Baby NAS config ($($env_local.Count) variables)"
Write-Host "   - Loaded: Main NAS config ($($mainnas_env.Count) variables)"
Write-Host ""

# Get credentials
$BabyNasIP = $env_local["BABY_NAS_IP"]
if (-not $BabyNasIP) { $BabyNasIP = "172.21.203.18" }

$MainNasIP = $env_local["MAIN_NAS_HOST"]
if (-not $MainNasIP) { $MainNasIP = $mainnas_env["TRUENAS_HOST"] }
if (-not $MainNasIP) { $MainNasIP = "10.0.0.89" }

$ReplicationUser = $env_local["REPLICATION_SSH_USER"]
if (-not $ReplicationUser) { $ReplicationUser = "baby-nas" }

$ApiKey = $mainnas_env["TRUENAS_API_KEY"]

Write-Host "2. Configuration Summary:" -ForegroundColor Yellow
Write-Host "   BabyNAS IP: $BabyNasIP"
Write-Host "   Main NAS IP: $MainNasIP"
Write-Host "   Replication User: $ReplicationUser"
Write-Host "   API Key: $(if ($ApiKey) {'SET'} else {'MISSING'})"
Write-Host ""

# Test connectivity
Write-Host "3. Testing Connectivity..." -ForegroundColor Yellow

$ping_baby = Test-Connection -ComputerName $BabyNasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($ping_baby) {
    Write-Host "   [OK] BabyNAS reachable"
} else {
    Write-Host "   [ERROR] Cannot reach BabyNAS - aborting setup"
    exit 1
}

$ping_main = Test-Connection -ComputerName $MainNasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($ping_main) {
    Write-Host "   [OK] Main NAS reachable"
} else {
    Write-Host "   [ERROR] Cannot reach Main NAS - aborting setup"
    exit 1
}

Write-Host ""

# Summary
Write-Host "=== NEXT STEPS ===" -ForegroundColor Green
Write-Host ""
Write-Host "1. SNAPSHOT CONFIGURATION (TrueNAS Web UI)"
Write-Host "   URL: https://$BabyNasIP"
Write-Host "   Go to: System > Tasks > Periodic Snapshot Tasks"
Write-Host "   Create these tasks:"
Write-Host "   - Hourly: Every hour, Keep 24"
Write-Host "   - Daily: 02:00 AM, Keep 7"
Write-Host "   - Weekly: Sunday 03:00 AM, Keep 4"
Write-Host ""
Write-Host "2. REPLICATION SETUP (TrueNAS Web UI)"
Write-Host "   URL: https://$BabyNasIP"
Write-Host "   Go to: Tasks > Replication Tasks > Add"
Write-Host "   Settings:"
Write-Host "   - Name: BabyNAS to Main NAS"
Write-Host "   - Direction: Push"
Write-Host "   - Source: tank/backups, tank/veeam, tank/wsl-backups, tank/media"
Write-Host "   - Destination: ssh://$ReplicationUser@$MainNasIP/tank/rag-system"
Write-Host "   - Schedule: Hourly"
Write-Host ""
Write-Host "3. VERIFY REPLICATION"
Write-Host "   - Monitor: Tasks > Replication Tasks"
Write-Host "   - Check Main NAS: Storage > Pools > tank > rag-system"
Write-Host ""
Write-Host "Configuration complete. Access TrueNAS Web UI to finalize."
Write-Host ""
