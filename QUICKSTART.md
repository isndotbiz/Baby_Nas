# TrueNAS SCALE Quick Start

## Complete Setup in 15 Minutes

This guide walks you through setting up TrueNAS SCALE with all optimizations, SSH keys, and API access.

---

## Prerequisites

- ✅ TrueNAS SCALE installed and accessible
- ✅ Network connectivity between Windows and TrueNAS
- ✅ Admin credentials for TrueNAS
- ✅ PowerShell (Administrator)
- ✅ Python 3.7+ installed

---

## Step 1: Initial TrueNAS Setup (5 min)

### Option A: Automated (Recommended)

1. **From Windows**, upload the setup script:
   ```powershell
   # Replace <truenas-ip> with your TrueNAS IP address
   scp .\truenas-initial-setup.sh root@<truenas-ip>:/root/
   ```

2. **SSH into TrueNAS**:
   ```bash
   ssh root@<truenas-ip>
   ```

3. **Run the setup script**:
   ```bash
   chmod +x /root/truenas-initial-setup.sh
   /root/truenas-initial-setup.sh
   ```

4. **Review output** and note:
   - User created: `jdmal`
   - Password: `uppercut%$##`
   - SSH public keys location

5. **Reboot TrueNAS**:
   ```bash
   reboot
   ```

### Option B: Manual (Web UI)

If automated setup fails, follow the detailed instructions in [TRUENAS_SETUP_GUIDE.md](./TRUENAS_SETUP_GUIDE.md).

---

## Step 2: Create Storage Pool (5 min)

### Via Web UI (Recommended for First-Time)

1. **Open browser**: `https://<truenas-ip>`
2. **Login**: `root` / `<your-password>`
3. **Navigate**: Storage → Create Pool

4. **Configure Pool**:
   - **Name**: `tank`
   - **Data VDevs**:
     - Add Vdev → RAIDZ1
     - Drag 3x 6TB HDDs
   - **Log Device**:
     - Add Vdev → Log
     - Drag 1x 256GB SSD
   - **Cache Device**:
     - Add Vdev → Cache
     - Drag 1x 256GB SSD
   - **Advanced Options**:
     - Compression: `lz4`
     - atime: `off`

5. **Click "Create Pool"** and confirm

### Expected Result

```
Pool: tank
├─ RAIDZ1: 3x 6TB HDDs (~12TB usable)
├─ SLOG: 1x 256GB SSD
└─ L2ARC: 1x 256GB SSD
```

---

## Step 3: Configure SSH Access (3 min)

### From Windows PowerShell (Administrator)

```powershell
# Navigate to scripts directory
cd D:\workspace\True_Nas\windows-scripts

# Run SSH setup (replace IP address)
.\setup-ssh-keys.ps1 -TrueNASIP "192.168.1.50" -Username "jdmal"

# Follow prompts and test connection
ssh truenas
```

### Expected Result

- ✅ SSH keys generated
- ✅ Keys copied to TrueNAS
- ✅ Passwordless SSH working
- ✅ Desktop shortcut created

---

## Step 4: Configure API Access (2 min)

### Generate API Key

1. **In TrueNAS Web UI**:
   - Credentials → API Keys → Add
   - Name: `windows-automation`
   - Click "Save"
   - **Copy the API key** (you won't see it again!)

2. **From Windows**, configure API:
   ```bash
   cd D:\workspace\True_Nas\windows-scripts
   python truenas-api-setup.py --setup
   ```

3. **Follow prompts**:
   - Enter TrueNAS IP
   - Enter username: `jdmal`
   - Enter password: `uppercut%$##`
   - Paste API key when prompted

### Test API Access

```bash
# Display system status
python truenas-api-setup.py --status

# List pools
python truenas-api-setup.py --pools

# List shares
python truenas-api-setup.py --shares
```

---

## Step 5: Create Datasets and SMB Shares (Optional, 5 min)

### Via SSH

```bash
# SSH into TrueNAS
ssh truenas

# Create datasets
zfs create tank/backups
zfs create tank/veeam
zfs create tank/wsl-backups
zfs create tank/media

# Optimize for large files
zfs set recordsize=1M tank/backups
zfs set recordsize=1M tank/veeam
zfs set recordsize=1M tank/media

# Enable compression
zfs set compression=lz4 tank/backups
zfs set compression=lz4 tank/veeam
zfs set compression=zstd tank/media

# Set permissions
chown -R jdmal:users /mnt/tank/backups
chown -R jdmal:users /mnt/tank/veeam
chown -R jdmal:users /mnt/tank/wsl-backups
chown -R jdmal:users /mnt/tank/media

# Exit SSH
exit
```

### Via Web UI

1. **Create Datasets**:
   - Storage → Datasets → Add Dataset
   - Create: `backups`, `veeam`, `wsl-backups`, `media`
   - Set record size and compression as above

2. **Create SMB Shares**:
   - Shares → Windows (SMB) Shares → Add
   - Path: `/mnt/tank/backups`
   - Name: `backups`
   - Enable: ✓
   - Repeat for other datasets

3. **Enable SMB Service**:
   - System Settings → Services → SMB → Toggle ON

---

## Step 6: Connect from Windows (1 min)

### Map Network Drive

```powershell
# Map backups share
net use Z: \\truenas\backups /user:jdmal "uppercut%$##" /persistent:yes

# Or use File Explorer:
# This PC → Map network drive → \\truenas\backups
```

### Test Connection

```powershell
# Test file creation
New-Item Z:\test.txt -ItemType File
Add-Content Z:\test.txt "TrueNAS is working!"
Get-Content Z:\test.txt

# Test large file transfer
Copy-Item C:\some-large-file.zip Z:\
```

---

## Verification Checklist

Run through this checklist to ensure everything is working:

- [ ] **TrueNAS accessible** via web UI: `https://<truenas-ip>`
- [ ] **Pool created** and status shows `ONLINE`
- [ ] **SLOG and L2ARC** visible in pool configuration
- [ ] **SSH access** working without password: `ssh truenas`
- [ ] **API access** working: `python truenas-api-setup.py --status`
- [ ] **Datasets created** and visible in Storage
- [ ] **SMB shares** accessible from Windows
- [ ] **Network drive** mapped and writable
- [ ] **User authentication** working for SMB

---

## What's Configured?

After completing this quick start, you have:

### ✅ Storage
- RAIDZ1 pool with ~12TB usable capacity
- Single-disk fault tolerance
- SLOG (ZIL) for write acceleration
- L2ARC for read caching
- LZ4 compression enabled

### ✅ Performance Optimizations
- ZFS record sizes optimized for workload
- SMB multichannel enabled
- Network tuning applied
- ARC size optimized (8GB)

### ✅ Monitoring & Maintenance
- SMART monitoring scheduled (weekly short, monthly long)
- Monthly scrub scheduled
- Snapshot automation (hourly, daily, weekly)

### ✅ Access Methods
- SSH key-based authentication
- SMB shares for Windows
- REST API with authentication
- PowerShell shortcuts

### ✅ Security
- SMB1 disabled
- Strong user authentication
- SSH key-only access (password disabled)
- API key generated

---

## Common Commands

### Quick SSH Access
```bash
# Connect to TrueNAS
ssh truenas

# Or with full address
ssh jdmal@<truenas-ip>

# As root
ssh root@<truenas-ip>
```

### Quick Status Checks
```bash
# Pool status
ssh truenas "zpool status tank"

# Disk usage
ssh truenas "zfs list -o name,used,available"

# System info
python truenas-api-setup.py --status
```

### Quick File Transfer
```powershell
# Copy to TrueNAS
scp file.txt truenas:/mnt/tank/backups/

# Copy from TrueNAS
scp truenas:/mnt/tank/backups/file.txt ./

# Recursive copy
scp -r folder/ truenas:/mnt/tank/backups/
```

---

## Troubleshooting

### Can't SSH to TrueNAS
```powershell
# Test connectivity
ping <truenas-ip>

# Try with password
ssh jdmal@<truenas-ip>

# Check SSH service
ssh root@<truenas-ip> "systemctl status ssh"
```

### Can't Access SMB Share
```powershell
# Test SMB connectivity
Test-NetConnection -ComputerName <truenas-ip> -Port 445

# List shares
smbclient -L //<truenas-ip> -U jdmal

# Check firewall
Get-NetFirewallRule -DisplayName "*SMB*" | Format-Table
```

### API Connection Fails
```bash
# Test API endpoint
curl -k https://<truenas-ip>/api/v2.0/system/info

# Verify API key
python truenas-api-setup.py --setup
```

### Pool Performance Issues
```bash
# Check pool health
ssh truenas "zpool status -v tank"

# Monitor I/O
ssh truenas "zpool iostat -v tank 2"

# Check compression ratio
ssh truenas "zfs get compressratio tank"
```

---

## Next Steps

Now that your TrueNAS is set up, you can:

1. **Configure Veeam** backup repository:
   - Add SMB/CIFS share: `\\truenas\veeam`
   - Credentials: `jdmal` / `uppercut%$##`

2. **Set up WSL backups**:
   - Use `rsync` or `rclone` to `\\truenas\wsl-backups`

3. **Archive media files**:
   - Copy to `\\truenas\media`
   - Enjoy automatic compression and redundancy

4. **Monitor system**:
   - Check Dashboard regularly
   - Review alerts
   - Monitor disk health

5. **Create backup schedule**:
   - Schedule regular backups
   - Test restore procedures
   - Document recovery process

---

## Files Reference

| File | Purpose |
|------|---------|
| `truenas-initial-setup.sh` | Automated TrueNAS configuration script |
| `setup-ssh-keys.ps1` | Windows SSH client setup |
| `truenas-api-setup.py` | API configuration and management |
| `TRUENAS_SETUP_GUIDE.md` | Comprehensive setup guide |
| `QUICKSTART.md` | This file - quick setup guide |

---

## Support

For detailed information, see:
- **Full Guide**: [TRUENAS_SETUP_GUIDE.md](./TRUENAS_SETUP_GUIDE.md)
- **TrueNAS Docs**: https://www.truenas.com/docs/scale/
- **API Docs**: `https://<truenas-ip>/api/docs`

---

**Setup Time**: ~15-20 minutes
**Difficulty**: Beginner-Friendly
**Status**: Production-Ready

🎉 **Congratulations!** Your TrueNAS SCALE server is ready for production use!
