# BabyNAS: Network Subnet Configuration

## Overview

Put BabyNAS VM on the same 10.0.0.0/24 subnet as Main NAS for direct access.

---

## Current Network Setup

```
Your Windows Host (10.0.0.x)
  ↓ (Hyper-V virtual network)
BabyNAS VM (192.168.215.2) ← Isolated virtual network
  ↓ (Replication)
Main NAS (10.0.0.89)
```

**Problem**: BabyNAS is on a separate Hyper-V virtual network (192.168.215.0/24)

**Solution**: Move BabyNAS to 10.0.0.0/24 subnet - same as Main NAS and your host

---

## Network Architecture (After Setup)

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

**Benefit**: All devices on same subnet - no routing needed!

---

## Step 1: Configure Hyper-V Virtual Network

### Option A: Modify Existing Virtual Network (Recommended)

```powershell
# Open Hyper-V Manager
# Right-click Hyper-V → Virtual Switch Manager

# Find your virtual switch (likely "External" or "Internal")
# Delete it or reconfigure it to use:
#   - External network adapter (your actual NIC)
#   - Use static IP instead of DHCP

# Your new setup:
# Virtual Switch: External Network
#   ↓
# Connected to your physical NIC
#   ↓
# Your host and BabyNAS on same subnet
```

### Option B: Create New Virtual Switch

```powershell
# Open Hyper-V Manager → Virtual Switch Manager

# Create new switch:
# Name: BabyNAS-Network
# Type: External
# External Network: Your physical network adapter
# Enable: VLAN tagging (optional)
```

---

## Step 2: Configure BabyNAS VM Network

### 1. Reconfigure VM Network Adapter

On BabyNAS:

```bash
ssh root@192.168.215.2

# List current network configuration
ip addr show
nmcli con show
```

### 2. Set Static IP on 10.0.0.0/24 Subnet

```bash
# Your network: 10.0.0.0/24
# Gateway: 10.0.0.1
# Main NAS: 10.0.0.89
# BabyNAS: 10.0.0.99 (new)

# On BabyNAS (via SSH):
nmcli con mod "Wired connection 1" ipv4.addresses 10.0.0.99/24
nmcli con mod "Wired connection 1" ipv4.gateway 10.0.0.1
nmcli con mod "Wired connection 1" ipv4.dns 10.0.0.1
nmcli con mod "Wired connection 1" ipv4.method manual
nmcli con up "Wired connection 1"
```

### 3. Verify New IP

```bash
ip addr show
hostname -I

# Should show: 10.0.0.99
```

---

## Step 3: Windows Routing (Not Required)

Since all devices are on the same 10.0.0.0/24 subnet, **no special routing is needed**.

Your Windows host can reach both NAS systems directly:
- BabyNAS: 10.0.0.99
- Main NAS: 10.0.0.89

```powershell
# Verify connectivity (no route configuration needed)
ping 10.0.0.99  # BabyNAS
ping 10.0.0.89  # Main NAS

# Both should reply directly
```

---

## Step 4: IP Forwarding (Optional)

Since all devices are on the same subnet, IP forwarding is not required.

If you need BabyNAS to route to other subnets in the future:

```bash
ssh root@10.0.0.99

# Enable IP forwarding (optional)
sysctl -w net.ipv4.ip_forward=1

# Make persistent
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

---

## Step 5: Update Firewall Rules

### Windows Firewall

```powershell
# Allow NAS subnet traffic (covers both BabyNAS and Main NAS)
New-NetFirewallRule -DisplayName "Allow NAS Subnet" `
    -Direction Inbound `
    -RemoteAddress 10.0.0.0/24 `
    -Action Allow `
    -Description "Allow traffic from NAS subnet (BabyNAS 10.0.0.99, Main NAS 10.0.0.89)"
```

### BabyNAS Firewall (TrueNAS)

```bash
# Via Web UI:
# System Settings → Network → Firewall

# Allow:
#   - SSH (port 22) from 10.0.0.0/24
#   - SMB (port 445) from 10.0.0.0/24
#   - HTTPS (port 443) from 10.0.0.0/24
```

---

## Step 6: Update Connection URLs

Update all references from old IP to new IP:

| Component | Old | New |
|-----------|-----|-----|
| BabyNAS Web UI | http://192.168.215.2 | http://10.0.0.99 |
| BabyNAS SSH | ssh root@192.168.215.2 | ssh baby@10.0.0.99 |
| SMB Shares | \\192.168.215.2\backups_encrypted | \\10.0.0.99\backups_encrypted |
| Replication | 192.168.215.2 → 10.0.0.89 | 10.0.0.99 → 10.0.0.89 |

---

## Step 7: Update DNS Records

If using DNS (baby.isn.biz):

```bash
# Update DNS A record
baby.isn.biz → 10.0.0.99

# Verify
nslookup baby.isn.biz
ping baby.isn.biz

# Should resolve to 10.0.0.99
```

---

## Step 8: Test Connectivity

```powershell
# Test from Windows

# 1. Ping BabyNAS
ping 10.0.0.99

# 2. SSH to BabyNAS
ssh -i ~/.ssh/baby-isn-biz baby@10.0.0.99

# 3. Access SMB shares
net use Z: \\10.0.0.99\backups_encrypted /user:baby

# 4. Ping Main NAS (same subnet - direct)
ping 10.0.0.89

# 5. SSH to Main NAS directly
ssh root@10.0.0.89
```

---

## Complete Network Diagram (After Setup)

```
┌───────────────────────────────────────────────────────────┐
│                  Your Network (10.0.0.0/24)               │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│  │ Windows Host │   │  BabyNAS VM  │   │   Main NAS   │  │
│  │   10.0.0.x   │   │  10.0.0.99   │   │  10.0.0.89   │  │
│  │              │   │  (Hyper-V)   │   │ (Bare Metal) │  │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘  │
│         │                  │                  │          │
│         └──────────────────┴──────────────────┘          │
│                            │                              │
│                       All on same                         │
│                     10.0.0.0/24 subnet                    │
│                            │                              │
│                     ┌──────┴──────┐                       │
│                     │   Gateway   │                       │
│                     │  10.0.0.1   │                       │
│                     └─────────────┘                       │
│                                                           │
└───────────────────────────────────────────────────────────┘

Direct access between all devices - no routing required!
```

---

## Network Security Benefits

✅ **SSH Key-Only**: baby user has no password
✅ **Same Subnet**: Direct access, no NAT overhead
✅ **Firewall Rules**: Restricted access by subnet
✅ **Routing**: Main NAS reachable via BabyNAS
✅ **No Port Forwarding**: Internal network only
✅ **Encrypted Datasets**: Data encrypted at rest

---

## Configuration Summary

| Item | Before | After |
|------|--------|-------|
| BabyNAS IP | 192.168.215.2 | 10.0.0.99 |
| Subnet | Virtual network (192.168.215.0/24) | Same as Main NAS (10.0.0.0/24) |
| User | jdmal | baby |
| Auth | Password | SSH key only |
| Access | VM-isolated | Direct (same subnet) |
| Routing | Required | Not needed |

---

## Troubleshooting

### Can't reach 10.0.0.99 (BabyNAS)

```powershell
# Verify BabyNAS is on the network
ping 10.0.0.99

# Check Hyper-V adapter is using External switch
Get-NetAdapter | Where Name -match "Hyper-V"

# SSH to old IP and reconfigure
ssh root@192.168.215.2 "hostname -I"
```

### Can't reach 10.0.0.89 (Main NAS)

```powershell
# Since both are on same subnet, just ping directly
ping 10.0.0.89

# Check your Windows IP is on same subnet
ipconfig /all
# Should show 10.0.0.x
```

### SSH key auth not working

```bash
# Verify key permissions
ls -la ~/.ssh/baby-isn-biz
# Should be 600

# Check BabyNAS authorized_keys
ssh -i ~/.ssh/baby-isn-biz baby@10.0.0.99 "cat ~/.ssh/authorized_keys"
```

---

## Next Steps

1. ✅ Create 'baby' user with SSH key-only access
2. ✅ Configure network subnet (this guide)
3. ✅ Update firewall rules
4. ✅ Test connectivity to BabyNAS and Main NAS
5. ✅ Update all connection strings to new IPs
6. ✅ Verify replication still works
7. ✅ Set up Tailscale VPN for internet access

---

## Quick Reference

```bash
# SSH to BabyNAS as baby user
ssh -i ~/.ssh/baby-isn-biz baby@10.0.0.99

# Access SMB shares
\\10.0.0.99\backups_encrypted

# Check if replication still works
zfs list -r tank

# SSH to Main NAS
ssh root@10.0.0.89
```

---

This setup gives you:
- ✅ Secure SSH key-only access
- ✅ Direct network connectivity (same subnet)
- ✅ Encrypted datasets owned by 'baby' user
- ✅ No routing needed - all devices on 10.0.0.0/24
- ✅ Professional backup infrastructure
