# Setup ZFS Replication from BabyNAS to Main NAS
# Configures replication from BabyNAS (172.21.203.18) to Main NAS (10.0.0.89)

param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$MainNasIP = "10.0.0.89",
    [string]$SshUser = "root",
    [string]$SshKey = "$env:USERPROFILE\.ssh\id_ed25519",
    [string]$ReplicationUser = "baby-nas",
    [string]$TargetDataset = "tank/rag-system",
    [switch]$TestConnection = $true,
    [switch]$Verbose = $false
)

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     ZFS Replication: BabyNAS → Main NAS                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Source (BabyNAS):   $BabyNasIP" -ForegroundColor Gray
Write-Host "  Target (Main NAS):  $MainNasIP" -ForegroundColor Gray
Write-Host "  Replication User:   $ReplicationUser" -ForegroundColor Gray
Write-Host "  Target Dataset:     $TargetDataset" -ForegroundColor Gray
Write-Host ""

# Test connectivity
Write-Host "1. Testing connectivity..." -ForegroundColor Yellow

$pingBaby = Test-Connection -ComputerName $BabyNasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
$pingMain = Test-Connection -ComputerName $MainNasIP -Count 1 -Quiet -ErrorAction SilentlyContinue

if ($pingBaby) {
    Write-Host "   ✓ BabyNAS ($BabyNasIP) is reachable" -ForegroundColor Green
} else {
    Write-Host "   ✗ BabyNAS ($BabyNasIP) is not reachable" -ForegroundColor Red
}

if ($pingMain) {
    Write-Host "   ✓ Main NAS ($MainNasIP) is reachable" -ForegroundColor Green
} else {
    Write-Host "   ✗ Main NAS ($MainNasIP) is not reachable" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. Information Needed from Main NAS (10.0.0.89)..." -ForegroundColor Yellow
Write-Host ""

Write-Host "   To complete replication setup, you need to provide:" -ForegroundColor Cyan
Write-Host ""

$infoNeeded = @(
    @{
        Item = "Replication User Username"
        Default = "baby-nas"
        Description = "SSH user for replication (should have ZFS permissions)"
        Location = "System → Users"
    }
    @{
        Item = "SSH Public Key"
        Default = "id_ed25519.pub"
        Description = "Public key from BabyNAS to authorize Main NAS"
        Location = "~/.ssh/id_ed25519.pub"
    }
    @{
        Item = "Target Dataset Path"
        Default = "tank/rag-system"
        Description = "Where to replicate snapshots on Main NAS"
        Location = "Storage → Pools → [dataset]"
    }
    @{
        Item = "Target Datasets"
        Default = "tank/backups, tank/veeam, tank/wsl-backups, tank/media"
        Description = "Which datasets to replicate"
        Location = "Storage → Pools"
    }
    @{
        Item = "ZFS Encryption"
        Default = "Check if enabled"
        Description = "If target dataset uses encryption, need passphrase"
        Location = "Storage → Pools → Dataset Properties"
    }
    @{
        Item = "Available Space"
        Default = "Estimate: 1-2 TB"
        Description = "How much space available on Main NAS"
        Location = "Storage → Pools → Tank"
    }
)

foreach ($info in $infoNeeded) {
    Write-Host "   ► $($info.Item)" -ForegroundColor Yellow
    Write-Host "     Description: $($info.Description)" -ForegroundColor Gray
    Write-Host "     Location: $($info.Location)" -ForegroundColor Gray
    Write-Host "     Default/Example: $($info.Default)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host ""
Write-Host "3. Steps to Gather Information from Main NAS..." -ForegroundColor Yellow
Write-Host ""

@"
STEP 1: Access Main NAS Web UI
  • URL: https://10.0.0.89
  • Login with admin credentials

STEP 2: Get Available Storage Info
  • Go to: Storage → Pools → Tank
  • Note:
    - Total pool size
    - Used space
    - Available space
  • You need at least as much space as the data to replicate

STEP 3: Create Replication User (if not exists)
  • Go to: System → Users → Add
  • Username: baby-nas
  • Full Name: BabyNAS Replication User
  • Disable password, use SSH key instead
  • Add SSH Public Key (from BabyNAS)

STEP 4: Get SSH Public Key from BabyNAS
  On BabyNAS, run in SSH:
    cat ~/.ssh/id_ed25519.pub

  Or via PowerShell on this computer:
    ssh -i $SshKey root@$BabyNasIP "cat ~/.ssh/id_ed25519.pub"

STEP 5: Add SSH Key to Main NAS User
  • In Main NAS Web UI:
    System → Users → baby-nas → Edit
    SSH Public Key: [Paste key from STEP 4]

  • Or via SSH:
    mkdir -p /root/.ssh
    echo "[public-key]" >> /root/.ssh/authorized_keys

STEP 6: Create Target Dataset (if needed)
  • Go to: Storage → Pools → Add Dataset
  • Name: rag-system (or desired name)
  • Parent: tank
  • Settings:
    - Compression: LZ4 (recommended)
    - Dedup: OFF (unless space is abundant)
    - Sync: Standard

STEP 7: Verify Connectivity
  • From BabyNAS, verify SSH works:
    ssh -i ~/.ssh/id_ed25519 baby-nas@10.0.0.89 "zfs list"
  • Should show list of datasets

STEP 8: Provide Information
  Once complete, provide:
  □ Main NAS username (default: baby-nas)
  □ Target dataset path (default: tank/rag-system)
  □ Replication schedule preference (hourly, daily, custom)
  □ Available space on Main NAS
  □ Any backup windows or restrictions
"@ | Write-Host -ForegroundColor Gray

Write-Host ""
Write-Host "4. What Will Be Replicated..." -ForegroundColor Yellow
Write-Host ""

$datasets = @(
    @{Name = "tank/backups"; Size = "~500 GB"; Frequency = "Hourly"; Notes = "Windows/Veeam backups" }
    @{Name = "tank/veeam"; Size = "~1.5 TB"; Frequency = "Hourly"; Notes = "Veeam backup repository" }
    @{Name = "tank/wsl-backups"; Size = "~100 GB"; Frequency = "Daily"; Notes = "WSL distributions" }
    @{Name = "tank/media"; Size = "~2 TB"; Frequency = "Weekly"; Notes = "Media files" }
)

foreach ($ds in $datasets) {
    Write-Host "   $($ds.Name)" -ForegroundColor Cyan
    Write-Host "     Size: $($ds.Size)  |  Frequency: $($ds.Frequency)  |  $($ds.Notes)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "   Total Estimated Data: 4-5 TB" -ForegroundColor Yellow
Write-Host "   Recommended Main NAS Space: 6-8 TB available" -ForegroundColor Yellow
Write-Host ""

Write-Host "5. Replication Methods..." -ForegroundColor Yellow
Write-Host ""

@"
Method 1: Manual Replication (Best for first sync)
  • One-time full sync of all snapshots
  • Then automated incremental replication
  • Command:
    zfs send -R tank/backups@snapshot | ssh root@10.0.0.89 zfs recv tank/rag-system

Method 2: TrueNAS Built-in Replication (Easiest)
  • Go to: Tasks → Replication Tasks → Add
  • Source: BabyNAS (172.21.203.18)
  • Direction: Push (BabyNAS → Main NAS)
  • Datasets: Select which to replicate
  • Schedule: Hourly, Daily, or Custom
  • Snapshots: Select retention policy

Method 3: Custom Script (Most flexible)
  • Use scheduled script for advanced options
  • Can combine with backup rotation
  • More control over bandwidth and timing
"@ | Write-Host -ForegroundColor Gray

Write-Host ""
Write-Host "6. Security Considerations..." -ForegroundColor Yellow
Write-Host ""

@"
SSH Key Security:
  ✓ Use Ed25519 keys (modern, secure)
  ✓ SSH public key auth (no passwords)
  ✓ Restrict key permissions (600)
  ✓ Use separate user for replication (not root if possible)

Firewall:
  ✓ Allow SSH (port 22) between:
    - BabyNAS (172.21.203.18)
    - Main NAS (10.0.0.89)
  ✓ If remote: Use VPN (vpn.isndotbiz.com)

Snapshots:
  ✓ Only replicate snapshots (read-only)
  ✓ Source snapshots locked during send
  ✓ No data modification during replication

Bandwidth:
  ✓ Incremental replication only sends changes
  ✓ Typically 1-50 GB per replication
  ✓ Schedule during off-peak hours if bandwidth limited
"@ | Write-Host -ForegroundColor Gray

Write-Host ""
Write-Host "7. Expected Replication Status..." -ForegroundColor Yellow
Write-Host ""

Write-Host "   After setup, you'll see:" -ForegroundColor Yellow
Write-Host "     • Hourly replication: ~500 MB - 2 GB per sync" -ForegroundColor Gray
Write-Host "     • Daily replication: ~5-20 GB per sync" -ForegroundColor Gray
Write-Host "     • Weekly replication: ~50-100 GB per sync" -ForegroundColor Gray
Write-Host ""
Write-Host "   Replication time: 5-30 minutes per sync (depends on bandwidth)" -ForegroundColor Gray
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Replication setup instructions prepared!" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Gather information from Main NAS (10.0.0.89)" -ForegroundColor Yellow
Write-Host "  2. Create replication user and dataset on Main NAS" -ForegroundColor Yellow
Write-Host "  3. Provide information back for automated setup" -ForegroundColor Yellow
Write-Host "  4. Run: configure-zfs-replication-task.ps1 (when ready)" -ForegroundColor Yellow
Write-Host ""
