# Make Encrypted Datasets Available to the Internet

## Overview

Your encrypted datasets are currently only accessible within your local network. Here are secure options to access them from the internet:

---

## Option 1: VPN Access (Most Secure) ⭐ RECOMMENDED

**How it works**: Connect to your home network via VPN from anywhere, then access backups as if you're local.

### Setup Steps

#### 1A: Using WireGuard VPN (Easiest)

On BabyNAS:
```bash
# SSH into root@192.168.215.2
ssh root@192.168.215.2

# Enable WireGuard on TrueNAS
# Via Web UI: System Settings → Services → WireGuard

# Generate VPN keys
wg genkey | tee privatekey | wg pubkey > publickey

# Configure WireGuard interface and peers
# Each remote user gets their own key pair
```

On your Windows machine:
```powershell
# Install WireGuard from https://www.wireguard.com/
# Import VPN config from BabyNAS
# Connect to VPN
# Access SMB shares at \\192.168.215.2\backups_encrypted
```

**Pros:**
- ✅ Very secure (military-grade encryption)
- ✅ Fast (UDP-based)
- ✅ Works on all devices (Windows, Mac, iPhone, Android)
- ✅ No need to expose services to internet
- ✅ Full access to all datasets

**Cons:**
- ⚠️ Requires VPN client on each device
- ⚠️ Need to manage VPN keys

#### 1B: Using Tailscale VPN (Easiest Setup)

Even simpler than WireGuard:

```bash
# On BabyNAS
# Download Tailscale for TrueNAS
# Or via SSH: curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate with your account
# Tailscale gives you a private IP

# Now access from anywhere:
# ssh jdmal@100.x.x.x (or whatever Tailscale IP)
# or mount SMB via Tailscale IP
```

**Pros:**
- ✅ Simplest setup (just sign in to account)
- ✅ Works through any firewall/NAT
- ✅ No port forwarding needed
- ✅ Automatic encryption and key management
- ✅ Works on all devices

**Cons:**
- ⚠️ Requires Tailscale account
- ⚠️ External service (Tailscale Inc. manages)

**Cost**: Free tier covers most users

---

## Option 2: SSH/SFTP Remote Access (Good for File Transfer)

**How it works**: Access encrypted datasets via SSH/SFTP from anywhere on the internet.

### Setup

```bash
# 1. Configure SSH on BabyNAS
# Via Web UI: System Settings → Services → SSH
# Port: 22 (or change to non-standard like 2222)

# 2. Set up SSH key authentication (already done!)
# Your Ed25519 key is at: D:\workspace\Baby_Nas\keys\baby-nas_rag-system

# 3. Forward port on your router
# Router settings → Port Forwarding
# Forward port 2222 (external) → 22 (internal) to 192.168.215.2

# 4. From anywhere, access via:
ssh -p 2222 jdmal@your-public-ip
```

**Access datasets:**
```bash
ssh -p 2222 jdmal@your-public-ip
cd /mnt/tank/backups_encrypted
ls -la
```

**Pros:**
- ✅ Secure (SSH encryption)
- ✅ Simple port forwarding
- ✅ Works from command line/terminal
- ✅ SFTP for file transfers

**Cons:**
- ❌ **Not recommended** - Exposes SSH to internet
- ⚠️ Need strong authentication
- ⚠️ Vulnerable to brute force attacks
- ⚠️ Requires firewall rules

**⚠️ Security Note**: Don't use password auth. Use SSH keys only!

---

## Option 3: Cloud Replication (Recommended for Off-Site Backup)

**How it works**: Replicate encrypted datasets to cloud storage (AWS, Azure, Backblaze B2, etc.)

### Setup with Backblaze B2 (Cheapest)

```bash
# 1. Create Backblaze B2 account
# https://www.backblaze.com/b2/cloud-storage.html

# 2. Get B2 credentials:
# - Application Key ID
# - Application Key

# 3. On BabyNAS, configure replication
# Via Web UI: Data Protection → Replication
# Target: Backblaze B2 bucket
# Dataset: tank/backups_encrypted
# Schedule: Daily

# 4. Or via SSH:
# Install b2 CLI and sync datasets
b2 account-info
b2 sync --compareVersions modTime /mnt/tank/backups_encrypted b2://bucket-name/backups_encrypted
```

**Alternative Services:**
- **AWS S3**: Enterprise-grade, ~$0.023/GB/month
- **Azure Blob**: Microsoft ecosystem
- **Backblaze B2**: Cheapest, ~$0.006/GB/month
- **Wasabi**: $6/TB/month
- **Google Cloud Storage**: ~$0.020/GB/month

**Pros:**
- ✅ Off-site backup (disaster recovery)
- ✅ Encrypted datasets stay encrypted
- ✅ Automatic scheduled replication
- ✅ Works over public internet (safe)
- ✅ Cheap cloud storage

**Cons:**
- ⚠️ Cloud provider has access (encrypted at rest mitigates)
- ⚠️ Monthly cloud storage costs ($5-50/month depending on size)
- ⚠️ Slower than local network

**Cost for 1TB/month**: ~$6-10 (Backblaze B2 cheapest)

---

## Option 4: Expose TrueNAS Web UI (Limited Use)

**How it works**: Access TrueNAS administration from the internet.

### Setup

```bash
# Via Web UI: System Settings → General
# GUI: https (recommended)
# Port: 443 or custom (e.g., 8443)

# Router: Port forward 8443 → 443 to 192.168.215.2

# Access from anywhere:
# https://your-public-ip:8443
```

**Pros:**
- ✅ Full web interface access
- ✅ Manage backups remotely

**Cons:**
- ❌ **Not recommended** - Exposes admin panel to internet
- ⚠️ Vulnerable to attacks
- ⚠️ Risk of unauthorized access

---

## Option 5: Reverse Proxy with HTTPS (Advanced)

**How it works**: Expose specific services (SMB, SFTP) through reverse proxy with auth.

### Example with Nginx

```nginx
# On a proxy server:
server {
    listen 443 ssl;
    server_name backups.yourdomain.com;

    ssl_certificate /etc/ssl/cert.pem;
    ssl_certificate_key /etc/ssl/key.pem;

    # Proxy SFTP-like access
    location / {
        proxy_pass sftp://192.168.215.2:22;
        proxy_ssl_verify off;
    }
}
```

**Pros:**
- ✅ Professional setup
- ✅ Custom domain
- ✅ HTTPS/TLS encryption
- ✅ Authentication layer

**Cons:**
- ❌ Complex to configure
- ⚠️ Requires separate proxy server
- ⚠️ Not ideal for SMB/CIFS

---

## My Recommendation

### For Remote Access (Recommended)
**Use Option 1: Tailscale VPN** ⭐

```powershell
# 1. On BabyNAS, install Tailscale
# Via Web UI or SSH

# 2. Authenticate with Tailscale account

# 3. From anywhere:
# - Access TrueNAS web UI via Tailscale IP
# - Mount SMB shares via Tailscale IP
# - SSH into jdmal@[tailscale-ip]
```

**Why:**
- ✅ Simplest setup
- ✅ Most secure (no internet exposure)
- ✅ Works everywhere (even behind NAT)
- ✅ Free for personal use
- ✅ Encrypted by default

### For Off-Site Disaster Recovery (Recommended)
**Use Option 3: Cloud Replication** ⭐

```bash
# Daily replication to Backblaze B2
# Cost: ~$6-10/month for 1TB
# Ensures recovery if local system fails
```

---

## Complete Internet-Ready Architecture

### Recommended Setup

```
Your Windows Machine (anywhere in world)
    ↓
Tailscale VPN (encrypted tunnel)
    ↓
Home Network (secure VPN entry point)
    ↓
Baby NAS (192.168.215.2)
    ├─ Web UI accessible via Tailscale
    ├─ SMB shares accessible via Tailscale
    ├─ SSH/SFTP accessible via Tailscale
    └─ ZFS snapshots continue
    ↓
Main NAS (10.0.0.89) - Local replication
    ↓
Backblaze B2 Cloud - Off-site backup
    (encrypted datasets replicated daily)
```

---

## Step-by-Step: Make Datasets Internet-Accessible

### Step 1: Install Tailscale on BabyNAS

```bash
# SSH into BabyNAS
ssh root@192.168.215.2

# Download and install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate
tailscale up

# Get your Tailscale IP
tailscale ip -4
# Returns something like: 100.x.x.x
```

### Step 2: Connect from Windows

```powershell
# 1. Download Tailscale: https://tailscale.com/download
# 2. Install and run
# 3. Sign in with same account as BabyNAS
# 4. You'll automatically connect to the VPN

# Test connection:
ping 100.x.x.x  # Should work
```

### Step 3: Access Datasets Remotely

```powershell
# Via Web UI:
https://100.x.x.x  # TrueNAS dashboard

# Via SMB:
net use Z: \\100.x.x.x\backups_encrypted /user:jdmal

# Via SSH:
ssh jdmal@100.x.x.x
```

### Step 4: Set Up Cloud Backup (Optional)

```bash
# Create Backblaze B2 account
# https://www.backblaze.com/b2

# On BabyNAS:
# Data Protection → Replication
# Add cloud replication target
# Replicate tank/backups_encrypted daily to B2
```

---

## Security Checklist

- ✅ Use VPN for remote access (not direct internet exposure)
- ✅ SSH keys only (no passwords)
- ✅ Datasets are encrypted (AES-256-GCM)
- ✅ jdmal user has limited permissions
- ✅ Firewall rules prevent unauthorized access
- ✅ Cloud backups are encrypted

---

## Cost Comparison

| Method | Cost | Speed | Security | Setup Time |
|--------|------|-------|----------|-----------|
| Tailscale VPN | Free | Fast | ⭐⭐⭐ | 10 min |
| WireGuard VPN | Free | Fast | ⭐⭐⭐ | 30 min |
| SSH Port Forward | Free | Medium | ⭐⭐ | 15 min |
| Backblaze B2 | $6-10/mo | Medium | ⭐⭐⭐ | 20 min |
| AWS S3 | $20-50/mo | Medium | ⭐⭐⭐ | 30 min |

---

## Next Steps

### Immediate (5 minutes)
1. Decide: Do you want remote access, cloud backup, or both?
2. Create Tailscale account (free): https://tailscale.com

### Short term (15-30 minutes)
1. Install Tailscale on BabyNAS
2. Install Tailscale on Windows machine
3. Test remote access to datasets

### Optional (20 minutes)
1. Set up Backblaze B2 account
2. Configure daily replication to cloud
3. Verify cloud backups working

---

## Questions

- **Q: Is this secure?** Yes, encrypted datasets over VPN is very secure
- **Q: Can others access my backups?** No, unless you share Tailscale access
- **Q: What if router needs restart?** Tailscale reconnects automatically
- **Q: Can I revoke access?** Yes, remove user from Tailscale account
- **Q: Cost?** Tailscale is free for personal use, B2 is ~$6/TB/month

---

## Summary

**Recommended: Use Tailscale VPN**

✅ Simplest setup (5-10 minutes)
✅ Most secure (no internet exposure)
✅ Free for personal use
✅ Works from anywhere
✅ Complete backup access

Then optionally add Backblaze B2 for off-site disaster recovery.

Ready to set this up? Let me know which approach you want! 🌐
