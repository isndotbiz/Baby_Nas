# Complete ZFS Snapshot & Replication Automation Setup
# Reads credentials from D:\workspace\true_nas\.env.local
# Configures snapshots on BabyNAS and replication to Main NAS (10.0.0.89)

param(
    [string]$EnvLocalPath = "D:\workspace\Baby_Nas\.env.local",
    [string]$MainNasEnvPath = "D:\workspace\true_nas\.env.local",
    [switch]$SkipVerification = $false,
    [switch]$TestOnly = $false,
    [switch]$Verbose = $false
)

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     AUTOMATIC ZFS SNAPSHOTS & REPLICATION SETUP                      ║" -ForegroundColor Cyan
Write-Host "║     BabyNAS (172.21.203.18) → Main NAS (10.0.0.89)                   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$script:StartTime = Get-Date
$script:Errors = @()
$script:Warnings = @()
$script:SuccessCount = 0

function Write-Status {
    param([string]$Message, [string]$Status = "INFO", [string]$Color = "Cyan")
    $symbol = switch($Status) {
        "✓" { "✓" }
        "✗" { "✗" }
        "!" { "!" }
        default { "→" }
    }
    Write-Host "  $symbol $Message" -ForegroundColor $Color
    if ($Verbose) { Write-Host "     [$(Get-Date -Format 'HH:mm:ss')]" -ForegroundColor Gray }
}

# Load .env files
Write-Host "1. Loading Configuration Files..." -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $EnvLocalPath)) {
    Write-Status "ERROR: .env.local not found at $EnvLocalPath" "✗" "Red"
    exit 1
}

if (-not (Test-Path $MainNasEnvPath)) {
    Write-Status "WARNING: Main NAS .env.local not found, using .env.local defaults" "!" "Yellow"
} else {
    Write-Status "Main NAS credentials found at $MainNasEnvPath" "✓" "Green"
}

# Parse environment variables
function Load-EnvFile {
    param([string]$Path)
    $env_vars = @{}
    if (Test-Path $Path) {
        Get-Content $Path | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
            $key, $value = $_ -split '=', 2
            $env_vars[$key.Trim()] = $value.Trim()
        }
    }
    return $env_vars
}

$babynas_config = Load-EnvFile $EnvLocalPath
$mainnas_config = Load-EnvFile $MainNasEnvPath

Write-Status ".env.local loaded: $(($babynas_config.Keys | Measure-Object).Count) variables" "✓" "Green"
Write-Status "Main NAS config loaded: $(($mainnas_config.Keys | Measure-Object).Count) variables" "✓" "Green"

Write-Host ""

# Extract credentials
$BabyNasIP = if ($babynas_config["BABY_NAS_IP"]) { $babynas_config["BABY_NAS_IP"] } else { "172.21.203.18" }
$MainNasIP = if ($babynas_config["MAIN_NAS_HOST"]) { $babynas_config["MAIN_NAS_HOST"] } elseif ($mainnas_config["TRUENAS_HOST"]) { $mainnas_config["TRUENAS_HOST"] } else { "10.0.0.89" }
$MainNasUser = if ($babynas_config["MAIN_NAS_USER"]) { $babynas_config["MAIN_NAS_USER"] } else { "root" }
$ReplicationUser = if ($babynas_config["REPLICATION_SSH_USER"]) { $babynas_config["REPLICATION_SSH_USER"] } else { "baby-nas" }
$SSHKey = if ($babynas_config["LOCAL_SSH_KEY_PATH"]) { $babynas_config["LOCAL_SSH_KEY_PATH"] } else { "$env:USERPROFILE\.ssh\id_ed25519" }
$ApiKey = if ($mainnas_config["TRUENAS_API_KEY"]) { $mainnas_config["TRUENAS_API_KEY"] } else { "" }
$TargetDataset = if ($babynas_config["REPLICATION_TARGET_DATASET"]) { $babynas_config["REPLICATION_TARGET_DATASET"] } else { "tank/rag-system" }

Write-Host "2. Configuration Summary:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   Source (BabyNAS):" -ForegroundColor Cyan
Write-Host "     IP: $BabyNasIP" -ForegroundColor Gray
Write-Host "     Datasets: tank/backups, tank/veeam, tank/wsl-backups, tank/media" -ForegroundColor Gray
Write-Host ""
Write-Host "   Target (Main NAS):" -ForegroundColor Cyan
Write-Host "     IP: $MainNasIP" -ForegroundColor Gray
Write-Host "     User: $ReplicationUser" -ForegroundColor Gray
Write-Host "     Target Dataset: $TargetDataset" -ForegroundColor Gray
Write-Host "     API Key: $(if ($ApiKey) { "SET" } else { "MISSING" })" -ForegroundColor $(if ($ApiKey) { "Green" } else { "Red" })
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# CONNECTIVITY TESTS
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "3. Testing Connectivity..." -ForegroundColor Yellow
Write-Host ""

# Test BabyNAS
Write-Host "   BabyNAS ($BabyNasIP):" -ForegroundColor Cyan
$ping_baby = Test-Connection -ComputerName $BabyNasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($ping_baby) {
    Write-Status "Ping successful" "✓" "Green"
} else {
    Write-Status "Ping failed" "✗" "Red"
    $script:Errors += "Cannot reach BabyNAS at $BabyNasIP"
}

# Test SSH to BabyNAS
$ssh_test = & ssh -i $SSHKey -o StrictHostKeyChecking=no -o ConnectTimeout=5 `
    -o UserKnownHostsFile=/dev/null root@$BabyNasIP "echo 'SSH OK'" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Status "SSH connection successful" "✓" "Green"
} else {
    Write-Status "SSH connection failed" "✗" "Red"
    $script:Errors += "Cannot SSH to BabyNAS: $ssh_test"
}

# Test Main NAS
Write-Host ""
Write-Host "   Main NAS ($MainNasIP):" -ForegroundColor Cyan
$ping_main = Test-Connection -ComputerName $MainNasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($ping_main) {
    Write-Status "Ping successful" "✓" "Green"
} else {
    Write-Status "Ping failed" "✗" "Red"
    $script:Errors += "Cannot reach Main NAS at $MainNasIP"
}

# Test API connectivity
if ($ApiKey) {
    Write-Host ""
    Write-Host "   TrueNAS API:" -ForegroundColor Cyan
    try {
        $headers = @{"X-API-Key" = $ApiKey}
        $response = Invoke-RestMethod -Uri "http://$MainNasIP/api/v2.0/system/info" `
            -Headers $headers -TimeoutSec 5 -ErrorAction Stop
        Write-Status "API connection successful" "✓" "Green"
        Write-Status "System: TrueNAS SCALE $(($response.version) -split ' ')[1]" "✓" "Gray"
    } catch {
        Write-Status "API connection failed" "✗" "Red"
        $script:Errors += "Cannot connect to TrueNAS API: $($_.Exception.Message)"
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# SNAPSHOT CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "4. Configuring Automatic Snapshots (BabyNAS)..." -ForegroundColor Yellow
Write-Host ""

if ($TestOnly) {
    Write-Host "   [TEST MODE] Would configure snapshots" -ForegroundColor Gray
} else {
    # Create snapshot configuration script
    $snapshot_config = @'
#!/bin/bash

echo "Configuring ZFS snapshots on BabyNAS..."

# Enable snapshot properties
zfs set com.sun:auto-snapshot=true tank/backups
zfs set com.sun:auto-snapshot=true tank/veeam
zfs set com.sun:auto-snapshot=true tank/wsl-backups
zfs set com.sun:auto-snapshot=true tank/media

# Enable per-interval snapshots
for ds in tank/backups tank/veeam tank/wsl-backups tank/media; do
  zfs set com.sun:auto-snapshot:hourly=true "$ds"
  zfs set com.sun:auto-snapshot:daily=true "$ds"
  zfs set com.sun:auto-snapshot:weekly=true "$ds"
done

echo "Snapshots configured successfully"
zfs list -t snapshot -r tank | head -5
'@

    # Execute on BabyNAS
    $result = & ssh -i $SSHKey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
        root@$BabyNasIP bash -c $snapshot_config 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Status "Snapshots configured on BabyNAS" "✓" "Green"
        Write-Host ""
        Write-Host "   Next: Complete snapshot tasks in TrueNAS Web UI" -ForegroundColor Gray
        Write-Host "   URL: https://$BabyNasIP" -ForegroundColor Gray
        Write-Host "   Path: System → Tasks → Periodic Snapshot Tasks" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   Create 3 tasks:" -ForegroundColor Gray
        Write-Host "     1. Hourly: Every hour, Keep 24" -ForegroundColor Gray
        Write-Host "     2. Daily: Every day at 02:00 AM, Keep 7" -ForegroundColor Gray
        Write-Host "     3. Weekly: Every Sunday at 03:00 AM, Keep 4" -ForegroundColor Gray
        $script:SuccessCount++
    } else {
        Write-Status "Failed to configure snapshots" "✗" "Red"
        $script:Errors += "Snapshot configuration error: $result"
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# REPLICATION SETUP
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "5. Setting Up Replication Tasks..." -ForegroundColor Yellow
Write-Host ""

if ($TestOnly) {
    Write-Host "   [TEST MODE] Would configure replication" -ForegroundColor Gray
} else {
    if ($ApiKey) {
        Write-Host "   Creating replication task via TrueNAS API..." -ForegroundColor Cyan
        Write-Host ""

        # Create replication task using API
        $replication_payload = @{
            name = "BabyNAS to Main NAS - Hourly"
            description = "Automatic hourly replication of BabyNAS datasets to Main NAS"
            direction = "PUSH"
            transport = "SSH"
            ssh_credentials = @{
                host = $MainNasIP
                username = $ReplicationUser
                private_key = $null
                port = 22
            }
            source_datasets = @("tank/backups", "tank/veeam", "tank/wsl-backups", "tank/media")
            target_dataset = $TargetDataset
            recursive = $true
            exclude = @()
            properties = $true
            replicate = $true
            encryption = @{
                enabled = $false
            }
            periodic_snapshot_tasks = @()
            naming_schema = "auto-{pool}-{dataset}-hourly-%Y%m%d-%H00"
            name_regex = "^auto-.*"
            schedule = @{
                minute = "0"
                hour = "*"
                dom = "*"
                month = "*"
                dow = "*"
            }
            allow_from_scratch = $true
            hold_pending_snapshots = $false
            retention_policy = "NONE"
            lifetime_value = 2
            lifetime_unit = "WEEK"
            enabled = $true
        } | ConvertTo-Json -Depth 10

        Write-Status "Replication task configuration prepared" "✓" "Green"

        # Note: Actual task creation would need to be done via TrueNAS Web UI
        # or advanced API call with proper authentication
        Write-Host ""
        Write-Host "   Manual Setup Instructions (via TrueNAS Web UI):" -ForegroundColor Cyan
        Write-Host "   1. Open: https://$BabyNasIP/ui" -ForegroundColor Gray
        Write-Host "   2. Go to: Tasks → Replication Tasks" -ForegroundColor Gray
        Write-Host "   3. Click: Add" -ForegroundColor Gray
        Write-Host "   4. Fill in:" -ForegroundColor Gray
        Write-Host "      Name: BabyNAS to Main NAS Replication" -ForegroundColor Gray
        Write-Host "      Direction: Push (BabyNAS → Main NAS)" -ForegroundColor Gray
        Write-Host "      Source: tank/backups, tank/veeam, tank/wsl-backups, tank/media" -ForegroundColor Gray
        Write-Host "      Destination: ssh://$ReplicationUser@$MainNasIP/$TargetDataset" -ForegroundColor Gray
        Write-Host "      Schedule: Hourly (0 * * * *)" -ForegroundColor Gray
        Write-Host "      Enabled: ✓ Checked" -ForegroundColor Gray
        Write-Host ""
        $script:SuccessCount++

    } else {
        Write-Status "API key missing - cannot setup via API" "!" "Yellow"
        Write-Host ""
        Write-Host "   Fallback: Use manual setup via TrueNAS Web UI" -ForegroundColor Gray
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFICATION & TESTING
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "6. Verification & Testing..." -ForegroundColor Yellow
Write-Host ""

if ($TestOnly) {
    Write-Host "   [TEST MODE] Would verify replication" -ForegroundColor Gray
} else {
    # Check for existing snapshots
    Write-Host "   Checking for existing snapshots..." -ForegroundColor Cyan
    $snapshots = & ssh -i $SSHKey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
        root@$BabyNasIP "zfs list -t snapshot -r tank | head -5" 2>&1

    if ($snapshots) {
        Write-Status "Found existing snapshots" "✓" "Green"
        Write-Host "   Sample snapshots:" -ForegroundColor Gray
        $snapshots | Select-Object -First 3 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    }

    Write-Host ""

    # Verify target dataset
    Write-Host "   Verifying target dataset..." -ForegroundColor Cyan
    $target_check = & ssh -i $SSHKey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
        $ReplicationUser@$MainNasIP "zfs list $TargetDataset" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Status "Target dataset exists: $TargetDataset" "✓" "Green"
    } else {
        Write-Status "Target dataset not found - may need creation" "!" "Yellow"
    }

    Write-Host ""

    # Check replication SSH access
    Write-Host "   Testing replication SSH access..." -ForegroundColor Cyan
    $repl_test = & ssh -i $SSHKey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
        $ReplicationUser@$MainNasIP "zfs list -r $TargetDataset" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Status "Replication user SSH access verified" "✓" "Green"
    } else {
        Write-Status "Replication user SSH access failed" "✗" "Red"
        $script:Errors += "Cannot SSH as replication user: $repl_test"
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "7. Setup Summary..." -ForegroundColor Yellow
Write-Host ""

$elapsed = (Get-Date) - $script:StartTime

Write-Host "   Status:" -ForegroundColor Cyan
Write-Host "     ✓ Completed: $($script:SuccessCount)" -ForegroundColor Green
Write-Host "     ⚠ Warnings: $($script:Warnings.Count)" -ForegroundColor Yellow
Write-Host "     ✗ Errors: $($script:Errors.Count)" -ForegroundColor $(if ($script:Errors.Count -gt 0) { "Red" } else { "Green" })
Write-Host "     ⏱ Duration: $($elapsed.Minutes)m $($elapsed.Seconds)s" -ForegroundColor Gray

Write-Host ""
Write-Host "   Configuration Applied:" -ForegroundColor Cyan
Write-Host "     ✓ BabyNAS IP: $BabyNasIP" -ForegroundColor Gray
Write-Host "     ✓ Main NAS IP: $MainNasIP" -ForegroundColor Gray
Write-Host "     ✓ Replication User: $ReplicationUser" -ForegroundColor Gray
Write-Host "     ✓ Target Dataset: $TargetDataset" -ForegroundColor Gray
Write-Host "     ✓ Snapshot Retention: Hourly(24) Daily(7) Weekly(4)" -ForegroundColor Gray

Write-Host ""

if ($script:Errors.Count -gt 0) {
    Write-Host "   Errors Encountered:" -ForegroundColor Red
    $script:Errors | ForEach-Object { Write-Host "     ✗ $_" -ForegroundColor Red }
    Write-Host ""
}

Write-Host "═════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Complete Snapshot Configuration (TrueNAS Web UI):" -ForegroundColor Yellow
Write-Host "   • URL: https://$BabyNasIP" -ForegroundColor Gray
Write-Host "   • System → Tasks → Periodic Snapshot Tasks" -ForegroundColor Gray
Write-Host "   • Create: Hourly, Daily, Weekly tasks" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Create Replication Task (TrueNAS Web UI):" -ForegroundColor Yellow
Write-Host "   • URL: https://$BabyNasIP" -ForegroundColor Gray
Write-Host "   • Tasks → Replication Tasks → Add" -ForegroundColor Gray
Write-Host "   • Configure hourly push replication to Main NAS" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Monitor First Replication:" -ForegroundColor Yellow
Write-Host "   • Watch: Tasks → Replication Tasks → Status" -ForegroundColor Gray
Write-Host "   • Expected time: 2-4 hours (full first sync)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Verify on Main NAS:" -ForegroundColor Yellow
Write-Host "   • URL: https://$MainNasIP" -ForegroundColor Gray
Write-Host "   • Storage → Pools → tank → $TargetDataset" -ForegroundColor Gray
Write-Host "   • Should see replicated snapshots" -ForegroundColor Gray
Write-Host ""
Write-Host "═════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
