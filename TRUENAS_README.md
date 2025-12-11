# TrueNAS SCALE Setup Scripts

Complete automation scripts for setting up TrueNAS SCALE from Windows with optimal configurations for backup storage.

## 🚀 Quick Start (15 minutes)

```powershell
# 1. Run complete setup (from PowerShell as Administrator)
cd D:\workspace\True_Nas\windows-scripts
.\run-complete-setup.ps1 -TrueNASIP "192.168.1.50"

# 2. Follow the prompts
# 3. Done! Your TrueNAS is ready to use
```

See [QUICKSTART.md](./QUICKSTART.md) for detailed step-by-step instructions.

## 📦 What's Included

### Scripts

| Script | Purpose | Platform |
|--------|---------|----------|
| **run-complete-setup.ps1** | Master orchestrator - runs all setup steps | Windows PowerShell |
| **truenas-initial-setup.sh** | Automated TrueNAS configuration and optimization | TrueNAS (Bash) |
| **setup-ssh-keys.ps1** | Generate and configure SSH keys | Windows PowerShell |
| **truenas-api-setup.py** | Configure and test API access | Python (Cross-platform) |

### Documentation

| Document | Description |
|----------|-------------|
| **QUICKSTART.md** | 15-minute quick start guide |
| **TRUENAS_SETUP_GUIDE.md** | Comprehensive setup and reference guide |
| **TRUENAS_README.md** | This file - overview and usage |

## 🎯 What Gets Configured

### User Account
- **Username**: `jdmal`
- **Password**: `uppercut%$##`
- **Home**: `/mnt/tank/home/jdmal`
- **Permissions**: Full access to datasets
- **SMB**: Enabled for Windows share access
- **SSH**: Key-based authentication

### Storage Optimization
- **RAIDZ1 Pool**: 3x 6TB HDDs (~12TB usable)
- **SLOG/ZIL**: 256GB SSD for write acceleration
- **L2ARC**: 256GB SSD for read caching
- **Compression**: lz4 (fast) or zstd (better ratio)
- **Record Size**: Optimized for workload (1M for backups)
- **ATime**: Disabled for performance

### Performance Tuning
- **ZFS ARC**: Tuned to 8GB (50% of RAM)
- **SMB Multichannel**: Enabled
- **Network Buffers**: Optimized for high throughput
- **TCP Window Scaling**: Enabled
- **Compression**: Saves space with minimal CPU cost

### Monitoring & Maintenance
- **SMART Tests**: Weekly short, monthly long
- **Scrub Schedule**: Monthly data integrity check
- **Snapshots**: Hourly (24h), Daily (7d), Weekly (4w)
- **Email Alerts**: Critical system notifications

### Security
- **SSH Keys**: Passwordless authentication
- **SMB1**: Disabled (security risk)
- **API Keys**: Secure programmatic access
- **Firewall**: Configured for required services

## 📚 Usage Examples

### Complete Setup (Recommended)

```powershell
# Run everything at once
.\run-complete-setup.ps1 -TrueNASIP "192.168.1.50" -RootPassword "your-root-pass"
```

### Individual Components

```powershell
# SSH setup only
.\setup-ssh-keys.ps1 -TrueNASIP "192.168.1.50" -Username "jdmal"

# API setup only
python truenas-api-setup.py --setup

# TrueNAS configuration only (run on TrueNAS)
ssh root@truenas "bash /root/truenas-initial-setup.sh"
```

### API Usage

```bash
# Display system status
python truenas-api-setup.py --status

# List storage pools
python truenas-api-setup.py --pools

# List SMB shares
python truenas-api-setup.py --shares

# List all datasets
python truenas-api-setup.py --datasets
```

### SSH Access

```bash
# Connect to TrueNAS
ssh truenas
# or
ssh jdmal@192.168.1.50

# Execute remote command
ssh truenas "zpool status tank"

# Copy files
scp file.txt truenas:/mnt/tank/backups/
scp -r folder/ truenas:/mnt/tank/backups/
```

## 🔧 Advanced Configuration

### Custom Dataset Creation

```bash
# SSH into TrueNAS
ssh truenas

# Create custom dataset
zfs create tank/mydata

# Set properties
zfs set recordsize=1M tank/mydata
zfs set compression=lz4 tank/mydata
zfs set quota=1T tank/mydata

# Set permissions
sudo chown -R jdmal:users /mnt/tank/mydata
sudo chmod -R 770 /mnt/tank/mydata
```

### Performance Monitoring

```bash
# Pool I/O statistics (update every 2 seconds)
ssh truenas "zpool iostat -v tank 2"

# ARC statistics
ssh truenas "arc_summary"

# Disk I/O
ssh truenas "iostat -x 2"

# Network throughput
ssh truenas "iftop -i eth0"
```

### Snapshot Management

```bash
# List snapshots
ssh truenas "zfs list -t snapshot"

# Create manual snapshot
ssh truenas "zfs snapshot tank/backups@manual-$(date +%Y%m%d)"

# Rollback to snapshot
ssh truenas "zfs rollback tank/backups@manual-20250109"

# Delete snapshot
ssh truenas "zfs destroy tank/backups@manual-20250109"
```

### Scrub Operations

```bash
# Start manual scrub
ssh truenas "zpool scrub tank"

# Check scrub status
ssh truenas "zpool status -v tank"

# Stop scrub
ssh truenas "zpool scrub -s tank"
```

## 🐛 Troubleshooting

### Can't SSH to TrueNAS

```powershell
# Test connectivity
ping 192.168.1.50

# Test SSH service
Test-NetConnection -ComputerName 192.168.1.50 -Port 22

# Try with password authentication
ssh jdmal@192.168.1.50

# Check SSH service on TrueNAS
ssh root@192.168.1.50 "systemctl status ssh"
```

### Can't Access SMB Shares

```powershell
# Test SMB connectivity
Test-NetConnection -ComputerName 192.168.1.50 -Port 445

# List available shares
smbclient -L //192.168.1.50 -U jdmal

# Check Windows firewall
Get-NetFirewallRule -DisplayName "*SMB*" | Format-Table

# Enable File and Printer Sharing
Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True
```

### API Connection Issues

```bash
# Test API endpoint
curl -k https://192.168.1.50/api/v2.0/system/info

# Reconfigure API
python truenas-api-setup.py --setup

# Check API key in config
cat ~/.truenas/config.json
```

### Performance Issues

```bash
# Check pool health
ssh truenas "zpool status tank"

# Monitor real-time I/O
ssh truenas "zpool iostat -v tank 2"

# Check compression effectiveness
ssh truenas "zfs get compressratio,used,available tank"

# Network speed test
# On TrueNAS:
ssh truenas "iperf3 -s"
# On Windows:
iperf3 -c 192.168.1.50
```

## 📋 Requirements

### Windows
- Windows 10/11 or Server 2016+
- PowerShell 5.1+ (Run as Administrator)
- OpenSSH Client (auto-installed by scripts)
- Python 3.7+ (for API scripts)

### TrueNAS SCALE
- TrueNAS SCALE 22.12+ installed
- Network connectivity to Windows host
- SSH access enabled (configured by scripts)
- 3x 6TB HDDs + 2x 256GB SSDs (or equivalent)
- 16GB RAM minimum (32GB recommended)

### Network
- Both systems on same network (or routable)
- No firewall blocking: SSH (22), SMB (445), HTTPS (443)
- Static IP for TrueNAS recommended

## 🔐 Security Considerations

### Default Credentials

**IMPORTANT**: The scripts use default credentials for demonstration:
- Username: `jdmal`
- Password: `uppercut%$##`

**For production use:**
1. Change the password after setup:
   ```bash
   ssh truenas "passwd jdmal"
   ```

2. Or modify the scripts before running to use your own credentials

3. Consider using stronger passwords or passphrase

### SSH Key Security

- Private key: `~/.ssh/id_rsa` (Keep secure! Never share!)
- Public key: `~/.ssh/id_rsa.pub` (Safe to share)
- Keys are 4096-bit RSA (strong)

**Best practices:**
- Use a passphrase on your private key
- Disable password authentication after key setup
- Rotate keys periodically

### API Key Security

- Store API keys securely
- Don't commit keys to version control
- Rotate keys periodically
- Use minimal permissions when possible

## 🔄 Maintenance

### Regular Tasks

```bash
# Weekly: Check pool status
ssh truenas "zpool status tank"

# Weekly: Check disk health
ssh truenas "smartctl -a /dev/sda"

# Monthly: Verify scrub completed
ssh truenas "zpool status -v tank | grep scrub"

# Monthly: Review snapshots and cleanup old ones
ssh truenas "zfs list -t snapshot | grep tank"

# Quarterly: Update TrueNAS
# Via Web UI: System Settings → Update
```

### Backup Configuration

```bash
# Export TrueNAS config (via Web UI)
# System Settings → General → Save Config

# Or via CLI
ssh truenas "midclt call system.config_upload" > truenas-config-$(date +%Y%m%d).tar

# Store config backup securely offline!
```

## 📖 Reference

### Common ZFS Commands

```bash
# Pool operations
zpool status [pool]              # Show pool status
zpool iostat [pool] [interval]   # I/O statistics
zpool scrub [pool]               # Start scrub
zpool list                       # List all pools

# Dataset operations
zfs list                         # List all datasets
zfs get all [dataset]            # Show all properties
zfs set [prop=value] [dataset]   # Set property
zfs snapshot [dataset]@[name]    # Create snapshot
zfs rollback [dataset]@[name]    # Restore snapshot

# Monitoring
arc_summary                      # ARC cache statistics
zpool iostat -v [pool] 2         # Detailed I/O stats
```

### Storage Paths

| Dataset | Mount Path | Windows Share | Purpose |
|---------|------------|---------------|---------|
| tank | /mnt/tank | - | Root pool |
| tank/backups | /mnt/tank/backups | \\truenas\backups | General backups |
| tank/veeam | /mnt/tank/veeam | \\truenas\veeam | Veeam repository |
| tank/wsl-backups | /mnt/tank/wsl-backups | \\truenas\wsl-backups | WSL backups |
| tank/media | /mnt/tank/media | \\truenas\media | Media archive |

### Useful URLs

| Service | URL |
|---------|-----|
| Web UI | https://192.168.1.50 |
| API Docs | https://192.168.1.50/api/docs |
| Shell | https://192.168.1.50/ui/shell |

## 🤝 Contributing

Improvements and suggestions welcome! Key areas:

- Additional optimization parameters
- Support for different hardware configs
- Enhanced error handling
- Additional automation scripts

## 📄 License

These scripts are provided as-is for educational and production use. Modify as needed for your environment.

## 🆘 Support

- **TrueNAS Forums**: https://forums.truenas.com/
- **TrueNAS Docs**: https://www.truenas.com/docs/scale/
- **GitHub Issues**: Report bugs or request features

## 📊 Performance Benchmarks

Expected performance with this configuration:

| Metric | Expected Value |
|--------|----------------|
| Sequential Read | 300-500 MB/s (1GbE) |
| Sequential Write | 200-400 MB/s (1GbE) |
| Random Read (cached) | 500-1000 MB/s |
| Compression Ratio | 1.2-2.0x (depending on data) |
| Usable Capacity | ~12TB (with RAIDZ1) |
| Fault Tolerance | 1 disk failure |

*Note: Actual performance depends on network speed, workload, and hardware.*

## 🎓 Learning Resources

- [OpenZFS Documentation](https://openzfs.github.io/openzfs-docs/)
- [TrueNAS SCALE Documentation](https://www.truenas.com/docs/scale/)
- [SMB/CIFS Configuration Guide](https://www.samba.org/samba/docs/)
- [ZFS Best Practices](https://www.truenas.com/docs/references/zfsprimer/)

---

**Version**: 1.0.0
**Last Updated**: 2025-12-09
**Tested On**: TrueNAS SCALE 23.10, Windows 11
**Author**: Automated by Claude (Anthropic)

---

## 🚀 Get Started Now!

```powershell
# Clone or download these scripts
cd D:\workspace\True_Nas\windows-scripts

# Run the complete setup
.\run-complete-setup.ps1 -TrueNASIP "<your-truenas-ip>"

# Follow the prompts - you'll be done in 15 minutes!
```

**Need help?** Start with [QUICKSTART.md](./QUICKSTART.md) for step-by-step instructions.

**Want details?** See [TRUENAS_SETUP_GUIDE.md](./TRUENAS_SETUP_GUIDE.md) for comprehensive documentation.

🎉 **Happy Storage!**
