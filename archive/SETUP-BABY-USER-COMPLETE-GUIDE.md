# Complete Setup: 'baby' User + Network Configuration

## Overview

This setup creates a professional backup infrastructure with:
- ✅ Dedicated 'baby' user (SSH key-only, no password)
- ✅ BabyNAS on same subnet as Main NAS (10.0.0.0/24)
- ✅ Encrypted datasets owned by 'baby'
- ✅ Firewall hardening
- ✅ Email: baby@isn.biz
- ✅ SSH key authentication only

## Network Summary

| Device | IP Address | Role |
|--------|------------|------|
| Gateway | 10.0.0.1 | Network gateway |
| Main NAS | 10.0.0.89 | Bare metal replication target |
| BabyNAS | 10.0.0.99 | Hyper-V VM (TrueNAS SCALE) |
| Current BabyNAS | 192.168.215.2 | Old IP (before reconfiguration) |

---

## 4-Step Setup Process

### STEP 1: Create 'baby' User with SSH Key-Only Access (15 minutes)

```powershell
# Run on your Windows machine in PowerShell:
cd D:\workspace\Baby_Nas
.\setup-baby-user-complete.ps1
```

**What this does:**
1. Generates SSH key pair locally: `~/.ssh/baby-isn-biz`
2. Creates 'baby' user on BabyNAS (UID 2999, email: baby@isn.biz)
3. Installs public key on BabyNAS
4. Disables password authentication
5. Grants 'baby' full permissions on encrypted datasets
6. Tests SSH key access
7. Configures Windows firewall rules

**Output will show:**
```
[✓] 'baby' user created on BabyNAS
[✓] SSH key pair generated locally
[✓] Public key installed on BabyNAS
[✓] Permissions granted to encrypted datasets
[✓] Password authentication disabled
[✓] SSH key-only access enabled
[✓] Firewall rules configured

Private Key: C:\Users\[YOU]\.ssh\baby-isn-biz
```

---

### STEP 2: Update Network Configuration (20 minutes)

**Goal**: Put BabyNAS on same 10.0.0.0/24 subnet as Main NAS

#### 2A: Check Your Current Network

```powershell
# Find your host's IP and subnet
ipconfig /all

# Your network:
# IPv4 Address:        10.0.0.x (your host IP)
# Subnet Mask:         255.255.255.0
# Default Gateway:     10.0.0.1
```

#### 2B: Reconfigure Hyper-V Virtual Switch

1. **Open Hyper-V Manager**
   - Right-click → Virtual Switch Manager
   - Select your virtual switch (likely "External")
   - Properties → External network → Choose your physical NIC
   - Apply

2. **Update BabyNAS VM Network Settings**
   - Right-click BabyNAS VM → Settings
   - Network Adapter → Choose "External" switch
   - Apply and restart VM

#### 2C: Configure BabyNAS Static IP

SSH as root and configure network:

```bash
ssh root@192.168.215.2

# List network connections
nmcli con show

# Modify connection to use 10.0.0.99
nmcli con mod "Wired connection 1" ipv4.method manual
nmcli con mod "Wired connection 1" ipv4.addresses 10.0.0.99/24
nmcli con mod "Wired connection 1" ipv4.gateway 10.0.0.1
nmcli con mod "Wired connection 1" ipv4.dns 10.0.0.1
nmcli con up "Wired connection 1"

# Verify new IP
ip addr show
hostname -I
```

**Expected output:**
```
10.0.0.99
```

#### 2D: IP Forwarding (Optional)

Since BabyNAS (10.0.0.99) and Main NAS (10.0.0.89) are on the same subnet,
no special routing is needed. They can communicate directly.

If you need BabyNAS to act as a gateway for other subnets in the future:

```bash
# Still SSH'd into BabyNAS (optional)
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

#### 2E: Windows Routing (Not Required)

Since all devices are on 10.0.0.0/24, no special routes are needed.
Your Windows host can reach both NAS systems directly:
- BabyNAS: 10.0.0.99
- Main NAS: 10.0.0.89

---

### STEP 3: Update All Connection Strings (10 minutes)

Update everywhere BabyNAS IP appears:

```bash
# OLD → NEW

# SSH
ssh baby@192.168.215.2                          # OLD
ssh -i ~/.ssh/baby-isn-biz baby@10.0.0.99       # NEW

# SMB Shares
\\192.168.215.2\backups_encrypted               # OLD
\\10.0.0.99\backups_encrypted                   # NEW

# TrueNAS Web UI
http://192.168.215.2                            # OLD
http://10.0.0.99                                # NEW

# DNS (optional)
baby.isn.biz → 10.0.0.99
```

**Update these locations:**
1. TrueNAS → Data Protection → Replication (change target IP)
2. Windows network shares (reconnect with new IP)
3. Firewall rules (if custom rules exist)
4. SSH config (~/.ssh/config)
5. Any scripts/automation

---

### STEP 4: Test Everything (10 minutes)

```powershell
# Test from Windows

# 1. Ping BabyNAS (new IP)
ping 10.0.0.99
# Expected: Reply from 10.0.0.99

# 2. SSH as baby user with key
ssh -i $HOME\.ssh\baby-isn-biz baby@10.0.0.99
# Should connect without password prompt

# 3. Inside SSH, verify access to encrypted datasets
zfs list -o name,encryption,encrypted | grep _encrypted
# Should show all 6 encrypted datasets

# 4. Test SMB access
net use Z: \\10.0.0.99\backups_encrypted /user:baby

# 5. Ping Main NAS (same subnet - direct access)
ping 10.0.0.89
# Should reach 10.0.0.89 directly (same subnet)

# 6. SSH to Main NAS directly
ssh root@10.0.0.89
# Or via jump host if preferred:
ssh -J baby@10.0.0.99 root@10.0.0.89
```

**All tests should pass ✅**

---

## Configuration Reference

### SSH Setup

**Create ~/.ssh/config for easy access:**

```
Host babynas
    HostName 10.0.0.99
    User baby
    IdentityFile ~/.ssh/baby-isn-biz
    IdentitiesOnly yes

Host main-nas
    HostName 10.0.0.89
    User root
```

**Then just use:**
```bash
ssh babynas
ssh main-nas
```

### Firewall Rules (Windows)

Created automatically by script:
- Allow inbound from 10.0.0.0/24 (NAS subnet - both BabyNAS and Main NAS)

### Network Diagram

```
Your Windows Host (10.0.0.x)
         │
         │ 10.0.0.0/24 subnet
         │
    ┌────┴────┬────────────┐
    │         │            │
    ▼         ▼            ▼
Gateway   BabyNAS      Main NAS
10.0.0.1  10.0.0.99    10.0.0.89
          (Hyper-V)    (Bare Metal)
```

---

## User Details

### 'baby' User

| Property | Value |
|----------|-------|
| **Username** | baby |
| **UID** | 2999 |
| **Email** | baby@isn.biz |
| **Home** | /home/baby |
| **Shell** | /bin/bash |
| **Password** | Locked (disabled) |
| **SSH Auth** | Key-only (public key in ~/.ssh/authorized_keys) |
| **Permissions** | Full control of encrypted datasets |

### SSH Key

| Item | Value |
|------|-------|
| **Type** | Ed25519 (secure, modern) |
| **Private Key** | ~/.ssh/baby-isn-biz |
| **Public Key** | ~/.ssh/baby-isn-biz.pub |
| **Passphrase** | None (no password needed) |
| **Installed On** | BabyNAS ~/.ssh/authorized_keys |

---

## Security Features

✅ **No Password**: 'baby' user has password locked (`passwd -l baby`)
✅ **SSH Key-Only**: Only Ed25519 key can authenticate
✅ **No Root**: Uses 'baby' service account (principle of least privilege)
✅ **Encrypted Datasets**: AES-256-GCM encryption on all backup data
✅ **Same Subnet**: Direct routing, no NAT vulnerabilities
✅ **Firewall Rules**: Restricted by subnet, no open ports to internet
✅ **Email**: Identified as baby@isn.biz for logging

---

## Next Steps After Setup

### 1. Verify Encryption Still Works
```bash
ssh -i ~/.ssh/baby-isn-biz baby@10.0.0.99

# Check encrypted datasets
zfs list -o name,encryption,encrypted | grep _encrypted

# Should show:
# tank/backups_encrypted         on          yes
# tank/veeam_encrypted           on          yes
# tank/wsl-backups_encrypted     on          yes
# tank/media_encrypted           on          yes
# tank/phone_encrypted           on          yes
# tank/home_encrypted            on          yes
```

### 2. Test Replication
```bash
# From Main NAS
zfs list -r tank

# Should show:
# - Local tank datasets
# - Replicated tank/backups_encrypted (from BabyNAS)
# etc.
```

### 3. Set Up Tailscale VPN (for internet access)

```powershell
# After baby user is ready:
.\SETUP-TAILSCALE-QUICK.ps1

# This will enable remote access via VPN
```

### 4. Update Automation Scripts

Any scripts using old IP or jdmal user:
```bash
# OLD
ssh jdmal@192.168.215.2

# NEW
ssh -i ~/.ssh/baby-isn-biz baby@10.0.0.99
```

---

## Troubleshooting

### Can\'t SSH as baby user

```bash
# Check SSH key permissions
ls -la ~/.ssh/baby-isn-biz
# Should show: -rw------- (600)

# Verify public key on BabyNAS
ssh -i ~/.ssh/baby-isn-biz baby@10.0.0.99 "cat ~/.ssh/authorized_keys"

# Check SSH config on BabyNAS
ssh root@10.0.0.99 "grep -A 5 'Match User baby' /etc/ssh/sshd_config"
```

### Can\'t reach new IP (10.0.0.99)

```powershell
# Check if BabyNAS has new IP
ping 10.0.0.99

# Check Hyper-V adapter settings
Get-NetAdapter | Where Name -match "Hyper-V"

# SSH to old IP and check/restart network
ssh root@192.168.215.2 "nmcli con down 'Wired connection 1' && nmcli con up 'Wired connection 1'"
```

### Can\'t reach Main NAS (10.0.0.89)

```powershell
# Since both are on same subnet, no routing needed
# Just ping directly
ping 10.0.0.89

# Check Windows can see the subnet
ipconfig /all

# Verify both NAS are on same subnet
ping 10.0.0.99  # BabyNAS
ping 10.0.0.89  # Main NAS
```

---

## Summary

| Component | Status | Details |
|-----------|--------|---------|
| **User 'baby'** | ✅ Ready | SSH key-only, locked password |
| **SSH Keys** | ✅ Ready | Ed25519, private ~/.ssh/baby-isn-biz |
| **Encrypted Datasets** | ✅ Ready | 6 datasets, owned by baby user |
| **Network Subnet** | 🟡 Pending | BabyNAS 10.0.0.99 on same subnet as Main NAS |
| **Routing** | ✅ Not Needed | All devices on 10.0.0.0/24 - direct access |
| **Firewall** | ✅ Ready | Windows rules for 10.0.0.0/24 |
| **Tailscale VPN** | 🟡 Optional | For internet access |

---

## You Now Have

✅ Professional backup infrastructure
✅ Secure service account (baby user)
✅ SSH key-only authentication
✅ Same-subnet direct access (10.0.0.0/24)
✅ Encrypted backup datasets
✅ Firewall hardening
✅ Direct access to both BabyNAS (10.0.0.99) and Main NAS (10.0.0.89)

Ready for production!