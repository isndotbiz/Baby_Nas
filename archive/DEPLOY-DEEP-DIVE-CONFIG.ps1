#Requires -Version 5.0
<#
.SYNOPSIS
    BabyNAS Deep Dive Configuration Deployment Script

.DESCRIPTION
    Deploys the optimized configuration from the 4-agent deep dive analysis.
    Configures: Storage, Security, Network, Backup/Replication

.NOTES
    Prerequisites:
    - BabyNAS accessible at 192.168.215.2
    - TrueNAS SCALE initial setup completed
    - Root password or API key configured
#>

param(
    [string]$BabyNasIP = "192.168.215.2",
    [string]$MainNasIP = "10.0.0.89",
    [switch]$DryRun,
    [switch]$SkipStorage,
    [switch]$SkipSecurity,
    [switch]$SkipNetwork,
    [switch]$SkipReplication
)

# Load configuration
$envFile = Join-Path $PSScriptRoot ".env.local"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
        }
    }
}

$ApiKey = $env:BABY_NAS_API_KEY
$RootPassword = $env:BABY_NAS_ROOT_PASSWORD

# Color output helpers
function Write-Phase { param($msg) Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan; Write-Host " $msg" -ForegroundColor Cyan; Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan }
function Write-Step { param($msg) Write-Host "  ► $msg" -ForegroundColor Yellow }
function Write-OK { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "  ℹ $msg" -ForegroundColor Gray }

# API helper
function Invoke-TrueNasApi {
    param(
        [string]$Endpoint,
        [string]$Method = "GET",
        [object]$Body = $null
    )

    $headers = @{ 'Content-Type' = 'application/json' }

    if ($ApiKey) {
        $headers['Authorization'] = "Bearer $ApiKey"
    } else {
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("root:$RootPassword"))
        $headers['Authorization'] = "Basic $auth"
    }

    $uri = "http://$BabyNasIP/api/v2.0$Endpoint"

    $params = @{
        Uri = $uri
        Method = $Method
        Headers = $headers
        ErrorAction = 'Stop'
    }

    if ($Body) {
        $params['Body'] = ($Body | ConvertTo-Json -Depth 10)
    }

    if ($DryRun) {
        Write-Info "[DRY-RUN] $Method $uri"
        if ($Body) { Write-Info ($Body | ConvertTo-Json -Compress) }
        return $null
    }

    try {
        $response = Invoke-RestMethod @params
        return $response
    } catch {
        Write-Err "API Error: $($_.Exception.Message)"
        return $null
    }
}

# ═══════════════════════════════════════════════════════════════
# MAIN SCRIPT
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║     BABYNAS DEEP DIVE CONFIGURATION DEPLOYMENT                ║" -ForegroundColor Magenta
Write-Host "║     Target: $BabyNasIP                                    ║" -ForegroundColor Magenta
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

if ($DryRun) {
    Write-Warn "DRY-RUN MODE - No changes will be made"
}

# Test connectivity
Write-Step "Testing connectivity to BabyNAS..."
$pingResult = Test-Connection -ComputerName $BabyNasIP -Count 1 -Quiet
if (-not $pingResult) {
    Write-Err "Cannot reach $BabyNasIP - check network configuration"
    exit 1
}
Write-OK "BabyNAS is reachable"

# Test API
Write-Step "Testing TrueNAS API..."
$version = Invoke-TrueNasApi -Endpoint "/system/version"
if ($version -and -not $DryRun) {
    Write-OK "API connected: $version"
} elseif ($DryRun) {
    Write-OK "API test skipped (dry-run)"
} else {
    Write-Err "API authentication failed"
    Write-Info "Ensure API key or root password is configured in .env.local"
    exit 1
}

# ═══════════════════════════════════════════════════════════════
# PHASE 1: STORAGE CONFIGURATION
# ═══════════════════════════════════════════════════════════════

if (-not $SkipStorage) {
    Write-Phase "PHASE 1: STORAGE CONFIGURATION"

    Write-Info "Storage configuration requires Web UI or SSH access."
    Write-Info "The API cannot create pools - use TrueNAS Web UI."
    Write-Host ""
    Write-Host @"
    MANUAL STEPS REQUIRED:

    1. Open Web UI: https://$BabyNasIP

    2. Create Pool:
       - Storage → Create Pool
       - Name: tank
       - Layout: RAIDZ1
       - Select 3x 6TB HDDs
       - Click Create

    3. Add SSDs (via SSH as root):
       # Partition SSDs
       sgdisk -n 1:0:+16G -t 1:bf01 /dev/disk/by-id/YOUR_SSD1
       sgdisk -n 2:0:0 -t 2:bf01 /dev/disk/by-id/YOUR_SSD1
       # Repeat for SSD2

       # Add SLOG (mirrored)
       zpool add tank log mirror SSD1-part1 SSD2-part1

       # Add L2ARC
       zpool add tank cache SSD1-part2 SSD2-part2

    4. Create Datasets (can be done via API after pool exists)
"@ -ForegroundColor Gray

    # Check if pool exists
    Write-Step "Checking if tank pool exists..."
    $pools = Invoke-TrueNasApi -Endpoint "/pool"
    $tankPool = $pools | Where-Object { $_.name -eq "tank" }

    if ($tankPool -and -not $DryRun) {
        Write-OK "Pool 'tank' exists"

        # Create datasets via API
        Write-Step "Creating datasets..."

        $datasets = @(
            @{
                name = "tank/veeam"
                type = "FILESYSTEM"
                compression = "LZ4"
                atime = "OFF"
                recordsize = "1M"
                quota = 4398046511104  # 4TB
            },
            @{
                name = "tank/backups"
                type = "FILESYSTEM"
                compression = "LZ4"
                atime = "OFF"
                recordsize = "1M"
                quota = 4398046511104
            },
            @{
                name = "tank/wsl-backups"
                type = "FILESYSTEM"
                compression = "LZ4"
                atime = "OFF"
                recordsize = "1M"
                quota = 536870912000  # 500GB
            },
            @{
                name = "tank/phone"
                type = "FILESYSTEM"
                compression = "LZ4"
                atime = "OFF"
                recordsize = "128K"
                quota = 536870912000
            },
            @{
                name = "tank/media"
                type = "FILESYSTEM"
                compression = "LZ4"
                atime = "OFF"
                recordsize = "1M"
                quota = 2199023255552  # 2TB
            }
        )

        foreach ($ds in $datasets) {
            $existing = Invoke-TrueNasApi -Endpoint "/pool/dataset?name=$($ds.name)"
            if ($existing.Count -eq 0 -or $DryRun) {
                Write-Step "Creating dataset: $($ds.name)"
                $result = Invoke-TrueNasApi -Endpoint "/pool/dataset" -Method "POST" -Body $ds
                if ($result) { Write-OK "Created $($ds.name)" }
            } else {
                Write-Info "Dataset $($ds.name) already exists"
            }
        }
    } else {
        Write-Warn "Pool 'tank' not found - create it first via Web UI"
    }
}

# ═══════════════════════════════════════════════════════════════
# PHASE 2: SECURITY HARDENING
# ═══════════════════════════════════════════════════════════════

if (-not $SkipSecurity) {
    Write-Phase "PHASE 2: SECURITY HARDENING"

    # Configure SSH service
    Write-Step "Configuring SSH service..."
    $sshConfig = @{
        tcpport = 22
        rootlogin = $false
        passwordauth = $false
        tcpfwd = $false
    }
    $result = Invoke-TrueNasApi -Endpoint "/ssh" -Method "PUT" -Body $sshConfig
    if ($result -or $DryRun) { Write-OK "SSH hardened (key-only, no root password login)" }

    # Enable SSH service
    Write-Step "Enabling SSH service..."
    $result = Invoke-TrueNasApi -Endpoint "/service/start" -Method "POST" -Body @{ service = "ssh" }
    if ($result -or $DryRun) { Write-OK "SSH service enabled" }

    # Configure SMB service
    Write-Step "Configuring SMB service..."
    $smbConfig = @{
        enable_smb1 = $false
        guest = "DISABLED"
        # Note: server_min_protocol and smb_options via auxiliary parameters
    }
    $result = Invoke-TrueNasApi -Endpoint "/smb" -Method "PUT" -Body $smbConfig
    if ($result -or $DryRun) { Write-OK "SMB hardened (SMB1 disabled, no guest)" }

    # Create groups
    Write-Step "Creating SMB groups..."
    $groups = @(
        @{ name = "smb-readonly"; gid = 1100 },
        @{ name = "smb-readwrite"; gid = 1101 },
        @{ name = "backup-operators"; gid = 1102 }
    )

    foreach ($group in $groups) {
        $existing = Invoke-TrueNasApi -Endpoint "/group?name=$($group.name)"
        if ($existing.Count -eq 0 -or $DryRun) {
            $result = Invoke-TrueNasApi -Endpoint "/group" -Method "POST" -Body $group
            if ($result -or $DryRun) { Write-OK "Created group: $($group.name)" }
        } else {
            Write-Info "Group $($group.name) already exists"
        }
    }

    # Create nas-admin user
    Write-Step "Creating nas-admin user..."
    $adminUser = @{
        username = "nas-admin"
        full_name = "NAS Administrator"
        shell = "/bin/bash"
        group_create = $true
        groups = @("builtin_administrators")
        password = "ChangeMe123!"  # Placeholder - change immediately
        sudo_commands_nopasswd = @()
        sudo_commands = @("ALL")
    }
    $existing = Invoke-TrueNasApi -Endpoint "/user?username=nas-admin"
    if ($existing.Count -eq 0 -or $DryRun) {
        $result = Invoke-TrueNasApi -Endpoint "/user" -Method "POST" -Body $adminUser
        if ($result -or $DryRun) {
            Write-OK "Created nas-admin user"
            Write-Warn "CHANGE THE PASSWORD IMMEDIATELY via Web UI!"
        }
    } else {
        Write-Info "nas-admin user already exists"
    }

    # Create baby-nas replication user
    Write-Step "Creating baby-nas replication user..."
    $replUser = @{
        username = "baby-nas"
        full_name = "BabyNAS Replication Service"
        shell = "/usr/sbin/nologin"
        group_create = $true
        password_disabled = $true
    }
    $existing = Invoke-TrueNasApi -Endpoint "/user?username=baby-nas"
    if ($existing.Count -eq 0 -or $DryRun) {
        $result = Invoke-TrueNasApi -Endpoint "/user" -Method "POST" -Body $replUser
        if ($result -or $DryRun) { Write-OK "Created baby-nas user" }
    } else {
        Write-Info "baby-nas user already exists"
    }

    Write-Host ""
    Write-Info "SMB Auxiliary Parameters (add via Web UI → Services → SMB → Auxiliary):"
    Write-Host @"
    server signing = mandatory
    smb encrypt = desired
    restrict anonymous = 2
    socket options = TCP_NODELAY IPTOS_LOWDELAY
    use sendfile = yes
    aio read size = 16384
    aio write size = 16384
    write cache size = 524288
"@ -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════
# PHASE 3: NETWORK CONFIGURATION
# ═══════════════════════════════════════════════════════════════

if (-not $SkipNetwork) {
    Write-Phase "PHASE 3: NETWORK CONFIGURATION"

    Write-Step "Configuring network (static IP)..."
    Write-Info "Network interface configuration should be done via Web UI"
    Write-Info "to prevent accidental disconnection."

    Write-Host @"

    RECOMMENDED SETTINGS (Web UI → Network → Interfaces):

    - DHCP: No (static)
    - IP Address: $BabyNasIP
    - Netmask: 255.255.255.0 (/24)
    - IPv4 Gateway: 192.168.215.1
    - MTU: 1500

    DNS SETTINGS (Web UI → Network → Global Configuration):
    - Nameserver 1: 8.8.8.8
    - Nameserver 2: 8.8.4.4
    - Hostname: babynas
    - Domain: local
"@ -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════
# PHASE 4: BACKUP & REPLICATION
# ═══════════════════════════════════════════════════════════════

if (-not $SkipReplication) {
    Write-Phase "PHASE 4: BACKUP & REPLICATION"

    # Create snapshot tasks
    Write-Step "Creating periodic snapshot tasks..."

    $snapshotTasks = @(
        @{
            dataset = "tank/backups"
            recursive = $true
            lifetime_value = 24
            lifetime_unit = "HOUR"
            naming_schema = "hourly-%Y-%m-%d_%H-%M"
            schedule = @{ minute = "0"; hour = "*"; dom = "*"; month = "*"; dow = "*" }
        },
        @{
            dataset = "tank/backups"
            recursive = $true
            lifetime_value = 7
            lifetime_unit = "DAY"
            naming_schema = "daily-%Y-%m-%d"
            schedule = @{ minute = "0"; hour = "0"; dom = "*"; month = "*"; dow = "*" }
        },
        @{
            dataset = "tank/veeam"
            recursive = $true
            lifetime_value = 7
            lifetime_unit = "DAY"
            naming_schema = "veeam-daily-%Y-%m-%d"
            schedule = @{ minute = "0"; hour = "2"; dom = "*"; month = "*"; dow = "*" }
        },
        @{
            dataset = "tank/phone"
            recursive = $true
            lifetime_value = 24
            lifetime_unit = "HOUR"
            naming_schema = "phone-hourly-%Y-%m-%d_%H-%M"
            schedule = @{ minute = "0"; hour = "*"; dom = "*"; month = "*"; dow = "*" }
        }
    )

    foreach ($task in $snapshotTasks) {
        Write-Step "Creating snapshot task: $($task.dataset) ($($task.naming_schema))"
        $result = Invoke-TrueNasApi -Endpoint "/pool/snapshottask" -Method "POST" -Body $task
        if ($result -or $DryRun) { Write-OK "Created snapshot task" }
    }

    Write-Host ""
    Write-Info "REPLICATION SETUP (requires SSH key configuration):"
    Write-Host @"

    1. Generate SSH key on BabyNAS (SSH as root):
       ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519_replication -N "" -C "baby-nas-replication"

    2. Add public key to Main NAS ($MainNasIP):
       - Create baby-nas user on Main NAS
       - Add public key to /home/baby-nas/.ssh/authorized_keys
       - Grant ZFS permissions:
         zfs allow -u baby-nas create,receive,rollback,destroy,mount,snapshot,hold,release tank/rag-system

    3. Create SSH Connection in BabyNAS Web UI:
       - Credentials → Backup Credentials → SSH Connections → Add
       - Host: $MainNasIP
       - Username: baby-nas
       - Private Key: [paste from /root/.ssh/id_ed25519_replication]

    4. Create Replication Tasks:
       - Data Protection → Replication Tasks → Add
       - Source: tank/backups (and others)
       - Destination: tank/rag-system/backups
       - Schedule: Daily 02:30
"@ -ForegroundColor Gray
}

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    DEPLOYMENT COMPLETE                         ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host @"

NEXT STEPS:

1. STORAGE (if not done):
   - Create tank pool via Web UI
   - Add SSDs as SLOG + L2ARC via SSH

2. SECURITY:
   - Change nas-admin password immediately
   - Add your SSH public key to nas-admin user
   - Review and apply SMB auxiliary parameters

3. ENCRYPTION (recommended):
   - Enable encryption on sensitive datasets via Web UI
   - Document passphrases securely offline

4. REPLICATION:
   - Generate SSH keys
   - Configure Main NAS baby-nas user
   - Create replication tasks

5. TESTING:
   - Test SMB access from Windows
   - Test snapshot creation
   - Test restore from snapshot

DOCUMENTATION:
   - Full plan: DEEP-DIVE-IMPLEMENTATION-PLAN.md
   - Storage details: Agent 1 output
   - Security details: Agent 2 output
   - Network details: Agent 3 output
   - Backup details: Agent 4 output

"@ -ForegroundColor Gray

Write-Host "BabyNAS Web UI: https://$BabyNasIP" -ForegroundColor Cyan
Write-Host ""
