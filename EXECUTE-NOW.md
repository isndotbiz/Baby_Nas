# Baby NAS Setup - Execute Now

## 🚀 What I've Created For You

I've created a complete automation script that will configure your entire Baby NAS. Here's what it does:

### Automated Configuration Includes:
1. ✅ Identifies your 3x 6TB HDDs and 2x 256GB SSDs
2. ✅ Creates ZFS pool with RAIDZ1 + SLOG + L2ARC
3. ✅ Creates encrypted datasets (AES-256-GCM) with your key
4. ✅ Creates truenas_admin user with proper permissions
5. ✅ Configures SSH security hardening
6. ✅ Sets up SMB shares (WindowsBackup, Veeam, Development, Home)
7. ✅ Configures automatic snapshots (hourly, daily, weekly)
8. ✅ Sets up firewall (UFW) with proper rules
9. ✅ Configures SMART monitoring and monthly ZFS scrubs
10. ✅ Applies ZFS tuning for 8GB RAM (4GB ARC)
11. ✅ Performance optimizations (network buffers, BBR congestion control)
12. ✅ Reduces VM memory from 16GB to 8GB

---

## ⚡ Run This Command Now

Open PowerShell as Administrator and run:

```powershell
cd D:\workspace\True_Nas\windows-scripts
.\DEPLOY-BABY-NAS-CONFIG.ps1
```

---

## 📋 What Will Happen

1. **Script uploads configuration** to Baby NAS (172.21.203.18)
2. **You'll be prompted** to identify your disks by their ID
3. **Configuration runs automatically** (5-10 minutes)
4. **VM memory reduced** to 8GB
5. **Done!** Baby NAS fully configured

---

## 🔍 During Execution

When the script runs on Baby NAS, you'll see:

```
Available disk IDs:
ata-WDC_WD60EFRX-68MYMN1_WD-WX12345678 -> sda (6TB)
ata-WDC_WD60EFRX-68MYMN1_WD-WX12345679 -> sdb (6TB)
ata-WDC_WD60EFRX-68MYMN1_WD-WX12345680 -> sdc (6TB)
ata-Samsung_SSD_860_EVO_250GB_S3Z9NB0M123456L -> sdd (256GB)
ata-Samsung_SSD_860_EVO_250GB_S3Z9NB0M123457L -> sde (256GB)
```

**You'll enter the disk identifiers** when prompted:
- Enter first 6TB HDD: `ata-WDC_WD60EFRX-68MYMN1_WD-WX12345678`
- Enter second 6TB HDD: `ata-WDC_WD60EFRX-68MYMN1_WD-WX12345679`
- Enter third 6TB HDD: `ata-WDC_WD60EFRX-68MYMN1_WD-WX12345680`
- Enter SLOG SSD: `ata-Samsung_SSD_860_EVO_250GB_S3Z9NB0M123456L`
- Enter L2ARC SSD: `ata-Samsung_SSD_860_EVO_250GB_S3Z9NB0M123457L`

---

## ✅ After Completion

Test SMB connectivity:

```powershell
# Map WindowsBackup share
net use W: \\172.21.203.18\WindowsBackup /user:truenas_admin "uppercut%$##"

# Test access
dir W:\

# Map Veeam share
net use V: \\172.21.203.18\Veeam /user:truenas_admin "uppercut%$##"

# Map Development share
net use D: \\172.21.203.18\Development /user:truenas_admin "uppercut%$##"
```

---

## 🎯 Next Steps After This

Once Baby NAS is configured, run these next:

### 1. Set Up Replication to Main NAS
```powershell
.\3-setup-replication.ps1 -BabyNasIP "172.21.203.18"
```

### 2. Deploy Veeam Backup
```powershell
cd veeam
.\0-DEPLOY-VEEAM-COMPLETE.ps1
```

### 3. Configure Development Environment
```powershell
# Deploy Gitea, n8n, and development tools
.\deploy-development-environment.ps1
```

---

## 🔧 Configuration Details

### Datasets Created:
```
tank/windows-backups (encrypted)
  ├── c-drive (500GB quota)
  ├── d-workspace (2TB quota)
  └── wsl (500GB quota)

tank/veeam (encrypted, 3TB quota, 1M recordsize)

tank/development (encrypted)
  ├── git-repos
  ├── web-projects
  └── android-projects (1TB quota)

tank/home (encrypted)
  └── truenas_admin
```

### SMB Shares:
- `\\172.21.203.18\WindowsBackup` → `/mnt/tank/windows-backups`
- `\\172.21.203.18\Veeam` → `/mnt/tank/veeam`
- `\\172.21.203.18\Development` → `/mnt/tank/development`
- `\\172.21.203.18\Home` → `/mnt/tank/home/truenas_admin`

### Snapshots:
- **Hourly**: 24 snapshots
- **Daily**: 7 snapshots
- **Weekly**: 4 snapshots
- **Monthly**: 3 snapshots

### Security:
- Firewall (UFW) enabled
- SSH hardened (key auth preferred, 3 max auth tries)
- SMB3 with encryption
- Root login via SSH disabled (use truenas_admin with sudo)

---

## 🚨 Important Notes

1. **Disk Selection**: Make sure you select the correct disks! Wrong selection = data loss
2. **Encryption Key**: The key `Paid0930Time06641723%$##` will be stored in `/root/.zfs_encryption_key`
3. **Backup the Key**: After setup, backup this file somewhere safe!
4. **Memory Change**: VM will restart during memory reduction to 8GB

---

## 🆘 If Something Goes Wrong

### Script Fails
```powershell
# Check the error message
# You can manually SSH to debug:
ssh admin@172.21.203.18
# Then check: /root/configure-baby-nas.sh
```

### Can't Connect
```powershell
# Verify VM is running
Get-VM "TrueNAS-BabyNAS"

# Test network
Test-Connection 172.21.203.18

# Check SSH is enabled in Web UI
# https://172.21.203.18 → System → Services → SSH
```

### Pool Already Exists
If you run this twice, the script will ask if you want to destroy and recreate the pool.
**WARNING**: Destroying the pool deletes ALL data!

---

## 📞 Manual Alternative

If you prefer to run commands manually:

```bash
# SSH to Baby NAS
ssh admin@172.21.203.18

# Copy the script content
# Run the configuration script
bash /root/configure-baby-nas.sh
```

---

## ⏱️ Estimated Time

- Script upload: 10 seconds
- Disk identification: 2 minutes (you entering disk IDs)
- Pool creation: 2 minutes
- Dataset creation: 1 minute
- User/security setup: 2 minutes
- Service configuration: 3 minutes
- **Total: ~10 minutes**

---

## 🎉 Ready?

```powershell
cd D:\workspace\True_Nas\windows-scripts
.\DEPLOY-BABY-NAS-CONFIG.ps1
```

Let's configure that Baby NAS! 🚀
