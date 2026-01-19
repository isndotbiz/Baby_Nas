# BabyNAS Network and SMB Performance Optimization Guide

## System Context

- **Baby NAS**: TrueNAS SCALE VM (Hyper-V guest) - 172.21.203.18
- **Network**: 192.168.215.0/24 (Hyper-V Default Switch)
- **Clients**: Windows 10/11, macOS (Time Machine)
- **Main NAS**: 10.0.0.89 (replication target via 10.0.0.x network)

---

## 1. SMB Performance Tuning

### 1.1 TrueNAS SMB Auxiliary Parameters

Navigate to: **Services > SMB > Configure > Auxiliary Parameters**

Add the following optimized settings:

```
# TCP Performance Optimizations
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072

# Async I/O for Better Throughput
use sendfile = yes
aio read size = 16384
aio write size = 16384

# Write Caching (512KB cache per connection)
write cache size = 524288

# Read-Ahead Optimization
min receivefile size = 16384

# Disable Sync on Write for Backups (ZFS handles integrity)
strict sync = no

# Oplocks for Better Client Caching
oplocks = yes
level2 oplocks = yes

# Deadtime for Idle Connections (10 minutes)
deadtime = 10

# Large Read/Write Operations
max xmit = 65535
getwd cache = yes

# Disable Printer Support (not needed)
load printers = no
printing = bsd
```

### 1.2 Per-Share Optimizations

For **backup-intensive shares** (Veeam, WindowsBackup):

```bash
# Via TrueNAS Web UI > Shares > SMB > [Share] > Advanced Options
# Or add to share's Auxiliary Parameters:

strict locking = no
posix locking = no
oplocks = yes
level2 oplocks = yes
```

### 1.3 Windows Client SMB Tuning

Run these commands on Windows clients (as Administrator):

```powershell
# Enable SMB Multichannel (if multiple NICs available)
Set-SmbClientConfiguration -EnableMultiChannel $true -Force

# Optimize SMB Direct (RDMA) - not applicable in VM but harmless
Set-SmbClientConfiguration -EnableBandwidthThrottling $false -Force
Set-SmbClientConfiguration -EnableLargeMtu $true -Force

# Increase file sharing connections
Set-SmbClientConfiguration -ConnectionCountPerRssNetworkInterface 4 -Force

# Verify current settings
Get-SmbClientConfiguration | Format-List *
```

---

## 2. Network Interface Configuration

### 2.1 TrueNAS Static IP Configuration

Apply via TrueNAS Web UI or CLI (SSH to Baby NAS):

```bash
# View current configuration
ip addr show
ip route show

# Static IP configuration via CLI (for reference)
# Note: Use TrueNAS Web UI > Network > Interfaces for persistent changes

# Current expected config:
#   IP: 172.21.203.18/24 (or dynamic DHCP from Hyper-V)
#   Gateway: 172.21.203.1 (Hyper-V Default Switch)
#   DNS: Use host DNS or 8.8.8.8, 8.8.4.4
```

### 2.2 MTU Configuration

**Standard MTU (1500)** - Recommended for Hyper-V Default Switch:

```bash
# Check current MTU
ip link show | grep mtu

# Standard MTU is recommended because:
# 1. Hyper-V Default Switch typically doesn't support jumbo frames
# 2. Virtual switches add overhead
# 3. Mismatched MTU causes fragmentation (worse performance)
```

**Jumbo Frames (9000)** - Only if ALL network path supports it:

```bash
# Test MTU support first (from Windows):
ping -f -l 8972 172.21.203.18

# If successful, configure in TrueNAS:
# Network > Interfaces > Edit > MTU: 9000

# Also set on Windows:
# Get-NetAdapter | Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword "*JumboPacket" -RegistryValue 9014
```

**IMPORTANT**: For Hyper-V Default Switch, stick with MTU 1500.

### 2.3 DNS Configuration for Hostname Resolution

On Baby NAS (via Web UI or `/etc/hosts`):

```bash
# Add to /etc/hosts for reliable resolution
172.21.203.18   babynas baby.isn.biz
10.0.0.89       mainnas baremetal.isn.biz
```

On Windows clients:

```powershell
# Add to C:\Windows\System32\drivers\etc\hosts
# Run as Administrator:
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "172.21.203.18 babynas baby.isn.biz"
Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "10.0.0.89 mainnas baremetal.isn.biz"
```

---

## 3. SSH Optimization for ZFS Replication

### 3.1 Fast Cipher Selection

Edit Baby NAS SSH client config for replication (`/root/.ssh/config`):

```bash
# SSH config for replication to Main NAS
Host mainnas 10.0.0.89
    HostName 10.0.0.89
    User root
    IdentityFile /root/.ssh/id_replication

    # Performance Ciphers (fastest to slowest)
    Ciphers aes128-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-gcm@openssh.com

    # Compression OFF (ZFS already compresses)
    Compression no

    # Connection Reuse (ControlMaster)
    ControlMaster auto
    ControlPath /tmp/ssh-%r@%h:%p
    ControlPersist 600

    # TCP Keepalive
    ServerAliveInterval 30
    ServerAliveCountMax 6
    TCPKeepAlive yes

    # Disable unnecessary features
    ForwardAgent no
    ForwardX11 no

    # Faster key exchange
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
```

### 3.2 Apply SSH Config on Baby NAS

```bash
# SSH into Baby NAS and create/update config
ssh babynas

# Create SSH config
cat > /root/.ssh/config << 'EOF'
Host mainnas 10.0.0.89
    HostName 10.0.0.89
    User root
    IdentityFile /root/.ssh/id_replication
    Ciphers aes128-gcm@openssh.com,chacha20-poly1305@openssh.com
    Compression no
    ControlMaster auto
    ControlPath /tmp/ssh-%r@%h:%p
    ControlPersist 600
    ServerAliveInterval 30
    ServerAliveCountMax 6
    TCPKeepAlive yes
    ForwardAgent no
    ForwardX11 no
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
EOF

chmod 600 /root/.ssh/config
```

### 3.3 Test SSH Performance

```bash
# Benchmark SSH throughput (from Baby NAS to Main NAS)
dd if=/dev/zero bs=1M count=100 | ssh mainnas "cat > /dev/null"

# Compare with different ciphers
ssh -c aes128-gcm@openssh.com mainnas "dd if=/dev/zero bs=1M count=100" > /dev/null
ssh -c chacha20-poly1305@openssh.com mainnas "dd if=/dev/zero bs=1M count=100" > /dev/null
```

---

## 4. ZFS Send/Receive Tuning

### 4.1 Optimized Replication Script

Update `/root/replicate-to-main.sh` on Baby NAS:

```bash
#!/bin/bash
###############################################################################
# Optimized ZFS Replication: Baby NAS -> Main NAS
###############################################################################

set -e

MAIN_NAS="10.0.0.89"
SSH_KEY="/root/.ssh/id_replication"
TIMESTAMP=$(date +%Y%m%d-%H%M)
LOG="/var/log/replication.log"

# SSH options for performance
SSH_OPTS="-i $SSH_KEY -o Compression=no -c aes128-gcm@openssh.com"

echo "=== ZFS Replication Started ===" | tee -a $LOG
echo "Time: $(date)" | tee -a $LOG

# Function: Replicate with progress and large block support
replicate_dataset() {
    local SOURCE=$1
    local TARGET=$2

    echo "Replicating: $SOURCE -> $TARGET" | tee -a $LOG

    if ! zfs list $SOURCE &>/dev/null; then
        echo "  [SKIP] Source not found" | tee -a $LOG
        return 0
    fi

    # Create snapshot
    zfs snapshot -r ${SOURCE}@auto-${TIMESTAMP}
    LATEST="${SOURCE}@auto-${TIMESTAMP}"
    echo "  [OK] Snapshot: $LATEST" | tee -a $LOG

    # Get remote latest
    REMOTE=$(ssh $SSH_OPTS root@$MAIN_NAS "zfs list -H -o name -t snapshot -r $TARGET 2>/dev/null | grep '@auto-' | tail -1" || echo "")

    if [ -z "$REMOTE" ]; then
        # Full send with large blocks and embedded data
        echo "  [SEND] Full replication..." | tee -a $LOG
        zfs send -v -L -e -c $LATEST 2>&1 | \
            ssh $SSH_OPTS root@$MAIN_NAS "zfs receive -F -v $TARGET" 2>&1 | \
            tee -a $LOG
    else
        # Incremental send
        REMOTE_SNAP=$(basename $REMOTE)
        echo "  [SEND] Incremental from @$REMOTE_SNAP..." | tee -a $LOG

        if zfs list ${SOURCE}@${REMOTE_SNAP} &>/dev/null; then
            zfs send -v -L -e -c -I ${SOURCE}@${REMOTE_SNAP} $LATEST 2>&1 | \
                ssh $SSH_OPTS root@$MAIN_NAS "zfs receive -F -v $TARGET" 2>&1 | \
                tee -a $LOG
        else
            echo "  [WARN] Common snapshot not found, full send" | tee -a $LOG
            zfs send -v -L -e -c $LATEST 2>&1 | \
                ssh $SSH_OPTS root@$MAIN_NAS "zfs receive -F -v $TARGET" 2>&1 | \
                tee -a $LOG
        fi
    fi

    echo "  [OK] Replication complete" | tee -a $LOG
}

# ZFS send flags explained:
#   -v: Verbose (show progress)
#   -L: Large blocks (up to 1MB, matches recordsize)
#   -e: Embed data in stream (better for small files)
#   -c: Compressed send (uses native compression)
#   -I: Incremental from snapshot

# Replicate datasets
replicate_dataset "tank/windows-backups" "backup/babynas/windows-backups"
replicate_dataset "tank/veeam" "backup/babynas/veeam"

# Cleanup old snapshots (keep 7 days)
echo "" | tee -a $LOG
echo "Cleaning old snapshots..." | tee -a $LOG
CUTOFF=$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d)

for snap in $(zfs list -H -o name -t snapshot -r tank | grep "@auto-"); do
    SNAP_DATE=$(echo $snap | grep -oP '(?<=@auto-)\d{8}' || echo "99999999")
    if [ "$SNAP_DATE" -lt "$CUTOFF" ]; then
        echo "  Deleting: $snap" | tee -a $LOG
        zfs destroy $snap 2>/dev/null || true
    fi
done

echo "" | tee -a $LOG
echo "=== Replication Complete: $(date) ===" | tee -a $LOG
```

### 4.2 Large Block and Compression Settings

On Baby NAS datasets (optimized for backups):

```bash
# Set optimal recordsize for backup workloads
zfs set recordsize=1M tank/veeam           # Large files (Veeam VBK)
zfs set recordsize=128K tank/windows-backups  # Mixed workload

# Enable compression (if not already)
zfs set compression=lz4 tank

# Enable large blocks for replication efficiency
zfs set largeblocks=on tank
```

---

## 5. Hyper-V Specific Optimizations

### 5.1 Virtual Network Adapter Settings

On the Hyper-V host (run as Administrator):

```powershell
# Get Baby NAS VM name
$vmName = "TrueNAS-BabyNAS"

# Enable VMQ (Virtual Machine Queue) for better throughput
Set-VMNetworkAdapter -VMName $vmName -VmqWeight 100

# Enable IPsec Task Offload
Set-VMNetworkAdapter -VMName $vmName -IPsecOffloadMaximumSecurityAssociation 512

# Disable RSC (Receive Segment Coalescing) if experiencing issues
# Set-VMNetworkAdapter -VMName $vmName -RscEnabled $false

# Check current settings
Get-VMNetworkAdapter -VMName $vmName | Format-List *
```

### 5.2 Integration Services Verification

```powershell
# Ensure Integration Services are up to date
Get-VMIntegrationService -VMName "TrueNAS-BabyNAS"

# Should show all services enabled:
# - Guest Service Interface
# - Heartbeat
# - Key-Value Pair Exchange
# - Shutdown
# - Time Synchronization
# - VSS
```

### 5.3 Memory and CPU Optimization

```powershell
# Check current VM configuration
Get-VM -Name "TrueNAS-BabyNAS" | Format-List *

# Recommended settings for NAS workload:
# - Minimum 8GB RAM (16GB recommended for ZFS ARC)
# - 4 vCPUs minimum
# - Dynamic memory can help, but static is more predictable

# Set static memory for consistent ARC performance
Set-VMMemory -VMName "TrueNAS-BabyNAS" -DynamicMemoryEnabled $false -StartupBytes 16GB

# Allocate more processors if available
Set-VMProcessor -VMName "TrueNAS-BabyNAS" -Count 4
```

---

## 6. Windows Client Optimization

### 6.1 SMB Client Performance Script

Save and run on Windows clients:

```powershell
# SMB-Client-Optimization.ps1
# Run as Administrator

Write-Host "Optimizing SMB Client Settings..." -ForegroundColor Cyan

# Enable Large MTU
Set-SmbClientConfiguration -EnableLargeMtu $true -Force
Write-Host "  [OK] Large MTU enabled" -ForegroundColor Green

# Enable Multichannel (if multiple NICs)
Set-SmbClientConfiguration -EnableMultiChannel $true -Force
Write-Host "  [OK] Multichannel enabled" -ForegroundColor Green

# Disable Bandwidth Throttling
Set-SmbClientConfiguration -EnableBandwidthThrottling $false -Force
Write-Host "  [OK] Bandwidth throttling disabled" -ForegroundColor Green

# Increase concurrent connections
Set-SmbClientConfiguration -ConnectionCountPerRssNetworkInterface 4 -Force
Write-Host "  [OK] Connection count increased" -ForegroundColor Green

# Optimize for backup workloads
Set-SmbClientConfiguration -DirectoryCacheLifetime 10 -Force
Set-SmbClientConfiguration -FileInfoCacheLifetime 10 -Force
Write-Host "  [OK] Cache lifetimes optimized" -ForegroundColor Green

# Verify settings
Write-Host ""
Write-Host "Current SMB Client Configuration:" -ForegroundColor Yellow
Get-SmbClientConfiguration | Format-List EnableLargeMtu, EnableMultiChannel, EnableBandwidthThrottling, ConnectionCountPerRssNetworkInterface

Write-Host ""
Write-Host "SMB Client optimization complete!" -ForegroundColor Green
```

### 6.2 Network Adapter Optimization

```powershell
# Get physical network adapters
Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

# Enable advanced features (replace "Ethernet" with your adapter name)
$adapter = "Ethernet"

# Enable Jumbo Frames (only if network supports it)
# Set-NetAdapterAdvancedProperty -Name $adapter -RegistryKeyword "*JumboPacket" -RegistryValue 9014

# Enable Receive Side Scaling (RSS)
Enable-NetAdapterRss -Name $adapter

# Enable Large Send Offload
Set-NetAdapterAdvancedProperty -Name $adapter -RegistryKeyword "*LsoV2IPv4" -RegistryValue 1
Set-NetAdapterAdvancedProperty -Name $adapter -RegistryKeyword "*LsoV2IPv6" -RegistryValue 1

# Verify settings
Get-NetAdapterAdvancedProperty -Name $adapter | Format-Table Name, DisplayName, DisplayValue
```

---

## 7. Performance Testing and Validation

### 7.1 SMB Throughput Test

```powershell
# Test SMB write speed to Baby NAS
$testFile = "\\babynas\WindowsBackup\speedtest-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".bin"
$testSize = 1GB

Write-Host "Testing SMB write speed ($($testSize / 1GB) GB)..." -ForegroundColor Cyan
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Generate and write test file
$buffer = New-Object byte[] (1MB)
[System.IO.File]::WriteAllBytes($testFile, (New-Object byte[] $testSize))

$stopwatch.Stop()
$speedMBps = ($testSize / 1MB) / $stopwatch.Elapsed.TotalSeconds

Write-Host "Write Speed: $([math]::Round($speedMBps, 2)) MB/s" -ForegroundColor Green

# Clean up
Remove-Item $testFile -Force

# Test read speed
$existingFile = "\\babynas\WindowsBackup\any-existing-large-file.vbk"  # Use a real file
if (Test-Path $existingFile) {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    [System.IO.File]::ReadAllBytes($existingFile) | Out-Null
    $stopwatch.Stop()
    $readSpeed = ((Get-Item $existingFile).Length / 1MB) / $stopwatch.Elapsed.TotalSeconds
    Write-Host "Read Speed: $([math]::Round($readSpeed, 2)) MB/s" -ForegroundColor Green
}
```

### 7.2 SSH Replication Benchmark

```bash
# On Baby NAS - test SSH replication throughput
SSH_OPTS="-i /root/.ssh/id_replication -o Compression=no -c aes128-gcm@openssh.com"

# Test raw SSH throughput
echo "Testing SSH throughput to Main NAS..."
dd if=/dev/zero bs=1M count=1000 2>/dev/null | ssh $SSH_OPTS root@10.0.0.89 "cat > /dev/null"

# Test ZFS send throughput (dry run)
echo ""
echo "Testing ZFS send throughput (estimate)..."
zfs send -nv tank/windows-backups@latest 2>&1 | tail -5
```

### 7.3 Network Latency Test

```powershell
# Comprehensive network test
$targets = @(
    @{Name="Baby NAS"; IP="172.21.203.18"},
    @{Name="Main NAS"; IP="10.0.0.89"}
)

foreach ($target in $targets) {
    Write-Host ""
    Write-Host "Testing $($target.Name) ($($target.IP)):" -ForegroundColor Cyan

    # Ping test
    $ping = Test-Connection -ComputerName $target.IP -Count 10
    $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
    Write-Host "  Latency: $([math]::Round($avgLatency, 2)) ms (avg)" -ForegroundColor White

    # SMB port test
    $smbTest = Test-NetConnection -ComputerName $target.IP -Port 445
    Write-Host "  SMB (445): $(if($smbTest.TcpTestSucceeded){'Open'}else{'Closed'})" -ForegroundColor $(if($smbTest.TcpTestSucceeded){'Green'}else{'Red'})

    # SSH port test
    $sshTest = Test-NetConnection -ComputerName $target.IP -Port 22
    Write-Host "  SSH (22): $(if($sshTest.TcpTestSucceeded){'Open'}else{'Closed'})" -ForegroundColor $(if($sshTest.TcpTestSucceeded){'Green'}else{'Red'})
}
```

---

## 8. Quick Reference Commands

### TrueNAS SCALE (Baby NAS) CLI

```bash
# Check network interfaces
ip addr show
ip route show

# Check SMB status
systemctl status smbd
smbstatus

# View active SMB connections
smbstatus -S

# Check ZFS pool I/O
zpool iostat -v tank 5

# Monitor replication
tail -f /var/log/replication.log

# Test replication manually
/root/replicate-to-main.sh
```

### Windows Client CLI

```powershell
# Check SMB connections
Get-SmbConnection

# View SMB session details
Get-SmbSession

# Check network adapter stats
Get-NetAdapterStatistics

# Clear DNS cache
Clear-DnsClientCache

# Reset SMB connection
net use * /delete /yes
```

---

## 9. Troubleshooting

### Slow SMB Transfers

1. **Check MTU mismatch**:
   ```bash
   ping -c 5 -M do -s 1472 172.21.203.18
   ```

2. **Verify SMB version**:
   ```powershell
   Get-SmbConnection | Select-Object ServerName, Dialect
   # Should show SMB 3.0 or higher
   ```

3. **Check for packet loss**:
   ```powershell
   Test-Connection -ComputerName 172.21.203.18 -Count 100 |
       Where-Object { $_.StatusCode -ne 0 } | Measure-Object
   ```

### Slow Replication

1. **Check SSH cipher speed**:
   ```bash
   ssh -v -c aes128-gcm@openssh.com mainnas "exit" 2>&1 | grep "cipher"
   ```

2. **Test raw network speed**:
   ```bash
   iperf3 -c 10.0.0.89 -t 30
   ```

3. **Check ZFS compression ratio**:
   ```bash
   zfs get compressratio tank
   ```

---

## 10. Recommended Configuration Summary

| Component | Setting | Value |
|-----------|---------|-------|
| SMB MTU | TrueNAS/Windows | 1500 (standard) |
| SMB Version | Minimum | SMB 2.1+ |
| SMB Multichannel | Windows | Enabled |
| SSH Cipher | Replication | aes128-gcm |
| SSH Compression | Replication | Off |
| ZFS recordsize | Veeam | 1M |
| ZFS recordsize | Windows | 128K |
| ZFS compression | All datasets | LZ4 |
| Hyper-V VMQ | Baby NAS VM | Enabled |
| Replication Schedule | Cron | Daily 2:30 AM |

---

*Last Updated: 2026-01-01*
*Document Version: 1.0*
