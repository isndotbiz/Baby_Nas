# TrueNAS SCALE Complete Setup Guide

## Overview

This guide provides complete setup instructions for TrueNAS SCALE with optimal performance configurations, SSH access, and API integration.

## Hardware Configuration

- **OS Disk**: 32GB (TrueNAS installation)
- **Data Disks**: 3x 6TB SATA HDDs (RAIDZ1 pool ~12TB usable)
- **Cache Devices**:
  - 1x 256GB SSD (SLOG/ZIL - Write acceleration)
  - 1x 256GB SSD (L2ARC - Read caching)
- **RAM**: 16GB
- **CPUs**: 4 cores

## Quick Start

### 1. Initial TrueNAS Installation

```bash
# Boot from TrueNAS SCALE ISO in Hyper-V
# Select "Install/Upgrade"
# Choose 32GB OS disk
# Set root password
# Reboot after installation
# Note the IP address shown on console
```

### 2. Run Automated Setup

**On TrueNAS (via SSH or console):**

```bash
# Upload the setup script
scp truenas-initial-setup.sh root@<truenas-ip>:/root/

# SSH into TrueNAS
ssh root@<truenas-ip>

# Make executable and run
chmod +x /root/truenas-initial-setup.sh
/root/truenas-initial-setup.sh

# Review output and reboot
reboot
```

### 3. Configure SSH Keys (Windows)

**On Windows (PowerShell as Administrator):**

```powershell
# Run the SSH setup script
cd D:\workspace\True_Nas\windows-scripts
.\setup-ssh-keys.ps1 -TrueNASIP "192.168.1.50" -Username "jdmal"

# Test connection
ssh jdmal@192.168.1.50

# Or use alias
ssh truenas
```

### 4. Configure API Access

**On Windows:**

```bash
# Run API setup
python truenas-api-setup.py --setup

# Follow prompts to:
# 1. Enter TrueNAS IP
# 2. Enter credentials (jdmal / uppercut%$##)
# 3. Create or paste API key

# Test API access
python truenas-api-setup.py --status
```

## Detailed Configuration

### Storage Pool Setup (Web UI)

#### Creating the RAIDZ1 Pool

1. **Navigate to Storage**
   - Open browser: `https://<truenas-ip>`
   - Login: `root` / `<your-password>`
   - Click **Storage** → **Create Pool**

2. **Configure Pool Layout**
   - **Name**: `tank`
   - **Data VDevs**:
     - Click "Add Vdev" → Select "Raidz1"
     - Drag 3x 6TB HDDs into this vdev
   - **Log Device (SLOG)**:
     - Click "Add Vdev" → Select "Log"
     - Drag 1x 256GB SSD here
   - **Cache Device (L2ARC)**:
     - Click "Add Vdev" → Select "Cache"
     - Drag 1x 256GB SSD here

3. **Advanced Options**
   - **Compression**: `lz4` (recommended) or `zstd`
   - **atime**: `off` (better performance)
   - **Encryption**: Optional (adds security, slight performance cost)

4. **Create Pool**
   - Review configuration
   - Click "Create Pool"
   - Confirm (destroys data on selected disks)

#### Expected Pool Layout

```
tank (RAIDZ1)
├─ Data: raidz1-0 (sda, sdb, sdc) - ~12TB usable
├─ Log: sdd (256GB SSD) - SLOG/ZIL
└─ Cache: sde (256GB SSD) - L2ARC
```

### Dataset Configuration

#### Create Datasets via Web UI

**Storage → Datasets → Add Dataset**

| Dataset | Path | Share Type | Record Size | Compression | Purpose |
|---------|------|------------|-------------|-------------|---------|
| backups | /tank/backups | SMB | 1M | lz4 | General backups |
| veeam | /tank/veeam | SMB | 1M | lz4 | Veeam backup repository |
| wsl-backups | /tank/wsl-backups | SMB | 128K | lz4 | WSL backups |
| media | /tank/media | SMB | 1M | zstd | Media archive |

#### Create Datasets via CLI

```bash
# SSH into TrueNAS
ssh jdmal@truenas

# Create datasets
zfs create tank/backups
zfs create tank/veeam
zfs create tank/wsl-backups
zfs create tank/media

# Set properties
zfs set recordsize=1M tank/backups
zfs set recordsize=1M tank/veeam
zfs set recordsize=128K tank/wsl-backups
zfs set recordsize=1M tank/media

# Set compression
zfs set compression=lz4 tank/backups
zfs set compression=lz4 tank/veeam
zfs set compression=lz4 tank/wsl-backups
zfs set compression=zstd tank/media

# Verify
zfs list -o name,recordsize,compression
```

### SMB Share Configuration

#### Create Shares via Web UI

**Shares → Windows (SMB) Shares → Add**

1. **Share Configuration**:
   - Path: `/mnt/tank/backups`
   - Name: `backups`
   - Purpose: `Default share parameters`
   - Enabled: ✓

2. **Advanced Options**:
   - Enable ACL: ✓
   - Browseable to Network Clients: ✓
   - Allow Guest Access: ✗ (use authentication)

3. **Repeat for other datasets**:
   - `/mnt/tank/veeam` → Share name: `veeam`
   - `/mnt/tank/wsl-backups` → Share name: `wsl-backups`
   - `/mnt/tank/media` → Share name: `media`

#### Enable SMB Service

**System Settings → Services**
- Find **SMB** service
- Toggle **ON**
- Click pencil icon:
  - NetBIOS Name: `TRUENAS`
  - Workgroup: `WORKGROUP`
  - Enable SMB1: ✗ (security risk)
  - Multichannel: ✓ (performance)

### User and Permissions Setup

#### Create User (Web UI)

**Credentials → Local Users → Add**

- **Username**: `jdmal`
- **Full Name**: `JD Mal`
- **Password**: `uppercut%$##`
- **Confirm Password**: `uppercut%$##`
- **User ID**: `3000` (auto)
- **Shell**: `/usr/bin/bash`
- **Home Directory**: `/mnt/tank/home/jdmal`
- **Samba Authentication**: ✓ (critical for SMB!)
- **Enabled**: ✓

#### Set Dataset Permissions

**Storage → Datasets → Select dataset → Edit Permissions**

1. **Permission Type**: `ACL` (recommended)

2. **ACL Entries**:
   - Click "Add Item"
   - Who: `User` → `jdmal`
   - Permissions: `Full Control`
   - Type: `Allow`
   - Flags: `Inherit`

3. **Apply Changes**:
   - Check "Apply permissions recursively"
   - Save

### SSH Configuration

#### Enable SSH Service

**System Settings → Services → SSH**

- Toggle **ON**
- Click pencil icon:
  - TCP Port: `22`
  - Log in as Root with Password: ✗ (use keys)
  - Allow Password Authentication: ✓ (initially)
  - Allow TCP Port Forwarding: ✓

#### Add SSH Public Key

1. **From Windows**, copy your public key:
   ```powershell
   cat $env:USERPROFILE\.ssh\id_rsa.pub | clip
   ```

2. **In TrueNAS Web UI**:
   - Go to **Credentials → Local Users**
   - Click on `jdmal` user
   - Paste public key into "SSH Public Key" field
   - Save

3. **Test Connection**:
   ```bash
   ssh jdmal@truenas
   ```

### API Key Generation

#### Create API Key (Web UI)

**Credentials → API Keys → Add**

1. **Key Configuration**:
   - Name: `windows-automation`
   - User: `root` (for full access)

2. **Copy the API Key**:
   - Save this key securely!
   - You won't be able to view it again

3. **Save to Configuration**:
   ```bash
   # Windows
   python truenas-api-setup.py --setup
   # Paste API key when prompted
   ```

## Performance Optimizations Applied

### ZFS Optimizations

```bash
# Pool-level settings
zfs set atime=off tank                 # Disable access time updates
zfs set compression=lz4 tank           # Enable fast compression
zfs set xattr=sa tank                  # Store extended attrs in inodes
zfs set dnodesize=auto tank            # Auto-tune dnode size

# Dataset-specific optimizations
zfs set recordsize=1M tank/veeam       # Large blocks for backup files
zfs set sync=standard tank/veeam       # Standard sync for Veeam
zfs set primarycache=metadata tank/veeam # Cache only metadata

# ARC tuning (8GB max for 16GB system)
echo "options zfs zfs_arc_max=8589934592" > /etc/modprobe.d/zfs.conf
```

### SMB Optimizations

- **Multichannel**: Enabled (use multiple NICs if available)
- **SMB1**: Disabled (security)
- **SMB2/3**: Enabled (performance + security)
- **AAPL Extensions**: Enabled (Time Machine support)

### Network Tuning

```bash
# Added to /etc/sysctl.conf
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.netdev_max_backlog = 5000
```

### SLOG and L2ARC Configuration

- **SLOG (ZIL)**: Accelerates synchronous writes
  - Critical for Veeam backup performance
  - Improves write consistency
  - 256GB SSD provides ample ZIL space

- **L2ARC**: Caches frequently read data
  - Extends ARC with SSD storage
  - Improves read performance for hot data
  - 256GB provides significant cache space

## Monitoring and Maintenance

### SMART Monitoring

**Tasks → S.M.A.R.T. Tests → Add**

| Test Type | Schedule | Purpose |
|-----------|----------|---------|
| Short | Weekly (Sunday 3 AM) | Quick health check |
| Long | Monthly (1st @ 2 AM) | Comprehensive test |

### Scrub Schedule

**Tasks → Scrub Tasks → Add**

- **Pool**: `tank`
- **Schedule**: Monthly (1st @ 1 AM)
- **Threshold**: 35 days
- **Purpose**: Verify data integrity, fix silent corruption

### Snapshot Automation

**Data Protection → Periodic Snapshot Tasks → Add**

| Frequency | Retention | Schedule | Naming |
|-----------|-----------|----------|--------|
| Hourly | 24 hours | Every hour | auto-%Y%m%d-%H%M |
| Daily | 7 days | Daily @ midnight | daily-%Y%m%d |
| Weekly | 4 weeks | Monday @ midnight | weekly-%Y-W%W |

### Email Alerts

**System Settings → Alert Settings**

1. **Configure Email**:
   - SMTP Server: (your email server)
   - Port: 587 (TLS) or 465 (SSL)
   - From: `truenas@yourdomain.com`
   - To: `your-email@domain.com`

2. **Alert Levels**:
   - Critical: Immediate notification
   - Warning: Daily digest
   - Info: Optional

## Windows Integration

### Map Network Drives

#### Method 1: File Explorer

1. Open File Explorer
2. Right-click "This PC" → "Map network drive"
3. Drive: `Z:`
4. Folder: `\\truenas\backups`
5. Check "Reconnect at sign-in"
6. Enter credentials: `jdmal` / `uppercut%$##`

#### Method 2: PowerShell

```powershell
# Map drive
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\truenas\backups" -Persist

# With credentials
$cred = Get-Credential -UserName "jdmal" -Message "TrueNAS Password"
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\truenas\backups" -Credential $cred -Persist
```

#### Method 3: CMD

```cmd
net use Z: \\truenas\backups /user:jdmal "uppercut%$##" /persistent:yes
```

### Veeam Integration

1. **Add Backup Repository**:
   - Backup Infrastructure → Backup Repositories → Add
   - Type: SMB/CIFS
   - Path: `\\truenas\veeam`
   - Credentials: `jdmal` / `uppercut%$##`

2. **Configure Repository**:
   - Load Control: Adjust based on your needs
   - Mount Server: Leave default
   - Per-VM Backup Files: ✓ (recommended)

3. **Create Backup Job**:
   - Backup → Add Job
   - Target: TrueNAS SMB share
   - Retention: Configure based on space

## Programmatic Access

### Python API Example

```python
from truenas_api_setup import TrueNASAPI

# Initialize API client
api = TrueNASAPI("192.168.1.50", "your-api-key-here")

# Get system info
info = api.get_system_info()
print(f"Hostname: {info['hostname']}")
print(f"Version: {info['version']}")

# Get pool status
pools = api.get_pools()
for pool in pools:
    print(f"Pool: {pool['name']} - Status: {pool['status']}")

# List datasets
datasets = api.get_datasets("tank")
for ds in datasets:
    print(f"Dataset: {ds['name']}")
```

### PowerShell API Example

```powershell
# Set API credentials
$apiKey = "your-api-key-here"
$truenasIP = "192.168.1.50"
$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type" = "application/json"
}

# Get system info
$uri = "https://$truenasIP/api/v2.0/system/info"
$response = Invoke-RestMethod -Uri $uri -Headers $headers -SkipCertificateCheck

# Display info
$response | Format-List
```

### Bash API Example

```bash
#!/bin/bash
API_KEY="your-api-key-here"
TRUENAS_IP="192.168.1.50"

# Get system info
curl -k -X GET \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  "https://$TRUENAS_IP/api/v2.0/system/info" | jq .
```

## Troubleshooting

### Can't Access SMB Share

**Symptoms**: Cannot connect to `\\truenas\backups`

**Solutions**:
1. Check SMB service is running:
   - System Settings → Services → SMB → Status: Running
2. Verify firewall allows SMB (ports 139, 445)
3. Test with IP: `\\192.168.1.50\backups`
4. Check user has Samba authentication enabled
5. Verify dataset permissions include user

### SSH Key Authentication Fails

**Symptoms**: Asked for password despite having key

**Solutions**:
1. Check key permissions:
   ```bash
   # On TrueNAS
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```
2. Verify key is in authorized_keys:
   ```bash
   cat ~/.ssh/authorized_keys
   ```
3. Check SSH config allows key auth:
   ```bash
   grep -i pubkey /etc/ssh/sshd_config
   ```
4. Check SSH logs:
   ```bash
   tail -f /var/log/auth.log
   ```

### Pool Performance Issues

**Symptoms**: Slow read/write speeds

**Diagnostics**:
1. Check pool status:
   ```bash
   zpool status tank
   zpool iostat -v tank 2
   ```
2. Monitor disk I/O:
   - Dashboard → Reports → Disk I/O
3. Check network speed:
   ```bash
   iperf3 -s  # On TrueNAS
   iperf3 -c <truenas-ip>  # On Windows
   ```

**Solutions**:
1. Verify SLOG and L2ARC are active:
   ```bash
   zpool iostat -v tank
   ```
2. Check ARC hit rate:
   ```bash
   arc_summary
   ```
3. Monitor compression ratio:
   ```bash
   zfs get compressratio tank
   ```

### API Connection Fails

**Symptoms**: Cannot connect to TrueNAS API

**Solutions**:
1. Verify API key is valid
2. Check HTTPS access: `https://<truenas-ip>/api/docs`
3. Disable SSL verification for self-signed cert:
   ```python
   api = TrueNASAPI(host, api_key, verify_ssl=False)
   ```
4. Test with curl:
   ```bash
   curl -k -H "Authorization: Bearer $API_KEY" \
     https://<truenas-ip>/api/v2.0/system/info
   ```

## Security Best Practices

### 1. Disable SMB1
- Legacy protocol with security vulnerabilities
- Only use SMB2/3

### 2. Use SSH Keys
- Disable password authentication after key setup
- Use strong passphrases on private keys

### 3. Enable Encryption
- Encrypt sensitive datasets
- Store encryption keys securely offline

### 4. Regular Updates
- Keep TrueNAS SCALE updated
- Review security advisories

### 5. Firewall Configuration
- Limit access to trusted networks
- Use VPN for remote access

### 6. API Key Security
- Store API keys securely
- Rotate keys periodically
- Limit key permissions to minimum required

### 7. Backup Configuration
- Export system configuration: System Settings → General → Save Config
- Store offline securely

## Quick Reference Commands

### ZFS Commands

```bash
# Pool status
zpool status tank
zpool iostat -v tank 2

# List datasets
zfs list -o name,used,available,compression,recordsize

# Get compression ratio
zfs get compressratio tank

# Create snapshot
zfs snapshot tank@backup-$(date +%Y%m%d)

# List snapshots
zfs list -t snapshot

# Rollback to snapshot
zfs rollback tank@backup-20250101

# Check scrub status
zpool status -v tank
```

### Network Commands

```bash
# Check connectivity
ping 192.168.1.50

# Test SMB connectivity
smbclient -L //192.168.1.50 -U jdmal

# Monitor network traffic
iftop -i eth0

# Test transfer speed
iperf3 -c 192.168.1.50
```

### System Commands

```bash
# View system info
midclt call system.info

# Restart services
midclt call service.restart smb
midclt call service.restart ssh

# View logs
tail -f /var/log/samba4/log.smbd
tail -f /var/log/auth.log
```

## Useful Web UI Paths

- **Dashboard**: Overview of system status
- **Storage**: Pool and dataset management
- **Shares**: SMB/NFS share configuration
- **Data Protection**: Snapshots and replication
- **Tasks**: Scheduled tasks (scrubs, SMART tests)
- **System Settings**: Services, SSH, updates
- **Credentials**: Users, API keys
- **Reports**: Performance monitoring

## Support Resources

- **TrueNAS Documentation**: https://www.truenas.com/docs/scale/
- **TrueNAS Forums**: https://forums.truenas.com/
- **API Documentation**: `https://<truenas-ip>/api/docs`
- **GitHub**: https://github.com/truenas

## Files Created

| File | Purpose |
|------|---------|
| `truenas-initial-setup.sh` | Automated TrueNAS configuration |
| `setup-ssh-keys.ps1` | Windows SSH client setup |
| `truenas-api-setup.py` | API configuration and testing |
| `TRUENAS_SETUP_GUIDE.md` | This comprehensive guide |

## Next Steps

After completing this setup:

1. ✅ **Test all SMB shares** from Windows
2. ✅ **Verify SSH access** with key authentication
3. ✅ **Configure Veeam** backup repository
4. ✅ **Set up monitoring** and alerts
5. ✅ **Create first backup** to test performance
6. ✅ **Document** any site-specific configurations
7. ✅ **Schedule** regular maintenance windows
8. ✅ **Test restore** procedures

---

**Document Version**: 1.0
**Last Updated**: 2025-12-09
**Author**: Claude (Anthropic)
