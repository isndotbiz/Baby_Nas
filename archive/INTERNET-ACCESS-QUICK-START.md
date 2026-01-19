# Quick Start: Internet Access to Encrypted Datasets

## 🚀 5-Minute Setup (Tailscale VPN)

### What You'll Get
- ✅ Access encrypted backups from **anywhere in the world**
- ✅ **Secure VPN tunnel** (military-grade encryption)
- ✅ Works on **any device** (Windows, Mac, phone, tablet)
- ✅ No port forwarding needed
- ✅ **Completely free** for personal use

---

## Step 1: Create Free Tailscale Account (2 minutes)

```
1. Go to: https://tailscale.com/signup
2. Sign up with your email (free forever)
3. Write down your email/password
```

---

## Step 2: Install Tailscale on BabyNAS (2 minutes)

**Option A: Automated Script**
```powershell
cd D:\workspace\Baby_Nas
.\SETUP-TAILSCALE-QUICK.ps1
```

**Option B: Manual SSH**
```bash
ssh root@192.168.215.2
# Password: 74108520

# Then run:
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

When you run `tailscale up`, you'll get a login link:
```
To authenticate, visit:
  https://login.tailscale.com/a/abc123def456
```

---

## Step 3: Authenticate Tailscale

1. Copy the login URL from the SSH output
2. Open it in your browser
3. Sign in with your **Tailscale account** (from Step 1)
4. BabyNAS will appear in your Tailscale dashboard

**Get your Tailscale IP:**
```bash
# Still in SSH:
tailscale ip -4

# Returns something like:
# 100.64.x.x
```

**Write this down!** You'll use it to access datasets.

---

## Step 4: Install Tailscale on Windows (2 minutes)

1. Download: https://tailscale.com/download/windows
2. Install and launch
3. Sign in with **SAME email** as BabyNAS
4. You're connected! 🎉

---

## Step 5: Access Your Encrypted Datasets

Now you can access backups from **anywhere**:

### Via Web UI (TrueNAS Dashboard)
```
https://100.64.x.x
```

### Via File Explorer (SMB Mount)
```
\\100.64.x.x\backups_encrypted

Username: jdmal
Password: (jdmal's password)
```

### Via SSH Terminal
```
ssh jdmal@100.64.x.x
cd /mnt/tank/backups_encrypted
ls -la
```

---

## Example: Remote Backup Access

**Scenario**: You're traveling and need to access a backup file

```powershell
# On your laptop with Tailscale running:

# Mount backup share
net use Z: \\100.64.x.x\backups_encrypted /user:jdmal

# Access file
cd Z:\
Get-ChildItem | Select-Object Name, LastWriteTime

# Find and copy file
copy Z:\important-file.zip C:\Downloads\
```

**That's it!** You're accessing encrypted backups over VPN from anywhere. 🌍

---

## Security Features

| Feature | Status |
|---------|--------|
| **Encryption** | ✅ AES-256-GCM (datasets) + TLS (Tailscale) |
| **Authentication** | ✅ Tailscale account required |
| **Internet Exposure** | ✅ None (VPN only, no open ports) |
| **jdmal Access Control** | ✅ User-level permissions enforced |
| **Device Management** | ✅ Revoke access anytime from Tailscale console |

---

## Optional: Add Cloud Backup

Want an off-site disaster recovery backup too?

```bash
# 1. Create Backblaze B2 account (free tier available)
# https://www.backblaze.com/b2

# 2. On BabyNAS, set up daily replication
# Data Protection → Replication → Add Backup
# Target: Backblaze B2
# Dataset: tank/backups_encrypted
# Schedule: Daily

# Cost: ~$6/month for 1TB
```

---

## Troubleshooting

### "Can't connect to 100.64.x.x"
- ✅ Make sure Tailscale is running on both machines
- ✅ Both signed in with SAME account
- ✅ Wait 30 seconds for VPN to establish

### "Authentication failed"
- ✅ Verify jdmal password is correct
- ✅ Check jdmal user exists: `ssh root@192.168.215.2`
- ✅ Then: `getent passwd jdmal`

### "SMB mount failed"
- ✅ Make sure SMB shares exist on BabyNAS
- ✅ Verify via local network first: `\\192.168.215.2\backups_encrypted`
- ✅ Then try via Tailscale IP

---

## Commands Reference

### On BabyNAS
```bash
# Check Tailscale status
tailscale status

# Get Tailscale IP
tailscale ip -4

# See connected devices
tailscale bugreport

# Disconnect Tailscale
tailscale down

# Reconnect Tailscale
tailscale up
```

### On Windows (PowerShell)
```powershell
# Check Tailscale is connected
Get-Service -Name Tailscale

# Ping BabyNAS via Tailscale
ping 100.64.x.x

# SSH to BabyNAS
ssh jdmal@100.64.x.x

# Mount SMB share
net use Z: \\100.64.x.x\backups_encrypted /user:jdmal /persistent:yes

# Disconnect SMB share
net use Z: /delete
```

---

## Cost

| Component | Cost |
|-----------|------|
| **Tailscale VPN** | 🟢 Free |
| **BabyNAS hosting** | 🟢 Free (your hardware) |
| **Cloud backup (optional)** | 🟡 ~$6/month (Backblaze B2) |
| **Total** | **$0-6/month** |

---

## Next Steps

1. ✅ Create Tailscale account
2. ✅ Run `SETUP-TAILSCALE-QUICK.ps1`
3. ✅ Authenticate on both machines
4. ✅ Test access to encrypted datasets
5. 🟡 (Optional) Set up cloud backup

---

## What You've Accomplished

| Feature | Status |
|---------|--------|
| **Encrypted backups** | ✅ 6 encrypted datasets |
| **jdmal owner** | ✅ Full dataset control |
| **Local access** | ✅ SMB, SSH, Web UI |
| **Remote VPN access** | ✅ Tailscale (this step) |
| **Off-site backup** | 🟡 Optional (B2, AWS, etc.) |
| **Disaster recovery** | ✅ Replication to Main NAS + Cloud |

---

## You're Done! 🎉

Your encrypted backup infrastructure is now:
- ✅ **Secure**: AES-256-GCM encryption + VPN
- ✅ **Accessible**: From anywhere, any device
- ✅ **Redundant**: Local + optional cloud backup
- ✅ **Manageable**: Controlled by jdmal user
- ✅ **Free**: No ongoing costs for VPN

**Enjoy secure remote access to your backups!** 🌐🔐
