# MacBook Remote Access Setup for Baby NAS

## Overview
Your Baby NAS is now accessible remotely via Tailscale. This guide covers testing and accessing your NAS from your MacBook when you're away from home.

## Baby NAS Connection Details

| Item | Value |
|------|-------|
| **Tailscale IP** | `100.95.3.18` |
| **Local IP** | `10.0.0.88` |
| **Hostname** | `baby.isn.biz` |
| **SSH User** | `truenas_admin` |
| **SMB User** | `smbuser` |

## Prerequisites

Tailscale is already installed on your MacBook (detected: `100.97.3.123`)

If you need to reinstall or update:
```bash
brew install tailscale
sudo tailscale up
```

## Testing Connection

### 1. Test Tailscale Connectivity

```bash
# Ping Baby NAS via Tailscale
ping -c 3 100.95.3.18

# Check Tailscale status
tailscale status
```

### 2. Test SSH Access

```bash
# SSH to Baby NAS via Tailscale (works from anywhere)
ssh truenas_admin@100.95.3.18

# Or use hostname if configured
ssh babynas
```

### 3. Test Subnet Routing

Since Baby NAS advertises the `10.0.0.0/24` route, you can access your entire home network remotely:

```bash
# Test access to your Windows desktop
ping -c 3 10.0.0.100

# Test access to your router
ping -c 3 10.0.0.1

# Access Baby NAS via local IP (even when remote!)
ping -c 3 10.0.0.88
```

## Accessing SMB Shares from MacBook

### Option 1: Via Finder (Recommended)

**When at home (local network):**
1. Press `Cmd + K` in Finder
2. Connect to: `smb://baby.isn.biz/workspace`
3. Username: `smbuser`
4. Password: (from 1Password: "Baby NAS - SMB User")

**When remote (via Tailscale):**
1. Press `Cmd + K` in Finder
2. Connect to: `smb://100.95.3.18/workspace`
3. Username: `smbuser`
4. Password: (from 1Password: "Baby NAS - SMB User")

### Option 2: Via Command Line

```bash
# List available shares
smbutil view //100.95.3.18

# Mount workspace share
mkdir -p ~/NAS/workspace
mount_smbfs //smbuser@100.95.3.18/workspace ~/NAS/workspace

# Mount other shares
mount_smbfs //smbuser@100.95.3.18/models ~/NAS/models
mount_smbfs //smbuser@100.95.3.18/staging ~/NAS/staging
mount_smbfs //smbuser@100.95.3.18/backups ~/NAS/backups
```

### Option 3: Auto-mount at Login

Create a mount script:

```bash
# Create mount script
cat > ~/mount-babynas.sh << 'EOF'
#!/bin/bash
# Mount Baby NAS shares via Tailscale

BABY_NAS_IP="100.95.3.18"
SMB_USER="smbuser"
MOUNT_BASE="$HOME/NAS"

# Create mount points
mkdir -p "$MOUNT_BASE"/{workspace,models,staging,backups}

# Mount shares (will prompt for password)
mount_smbfs "//$SMB_USER@$BABY_NAS_IP/workspace" "$MOUNT_BASE/workspace"
mount_smbfs "//$SMB_USER@$BABY_NAS_IP/models" "$MOUNT_BASE/models"
mount_smbfs "//$SMB_USER@$BABY_NAS_IP/staging" "$MOUNT_BASE/staging"
mount_smbfs "//$SMB_USER@$BABY_NAS_IP/backups" "$MOUNT_BASE/backups"

echo "Baby NAS shares mounted at $MOUNT_BASE"
EOF

chmod +x ~/mount-babynas.sh

# Run it
~/mount-babynas.sh
```

## Time Machine Backups (Optional)

If you want to backup your MacBook to Baby NAS:

### 1. Create Time Machine Share on Baby NAS

(Already exists if configured - check TrueNAS web UI)

### 2. Connect Time Machine on MacBook

```bash
# Via Tailscale (works remotely)
sudo tmutil setdestination smb://smbuser@100.95.3.18/timemachine

# Or via local IP (home only)
sudo tmutil setdestination smb://smbuser@baby.isn.biz/timemachine
```

**Note:** Time Machine over Tailscale will be slower than local network but works from anywhere.

## Troubleshooting

### Can't ping 100.95.3.18

```bash
# Check if Tailscale is running
tailscale status

# Restart Tailscale
sudo tailscale down
sudo tailscale up
```

### Can't access SMB shares

```bash
# Test if SMB is reachable
nc -zv 100.95.3.18 445

# If that fails, check Tailscale subnet routing is approved:
# Go to https://login.tailscale.com/admin/machines
# Find "baby" device → Edit route settings → Ensure 10.0.0.0/24 is approved
```

### Subnet routing not working

1. Go to https://login.tailscale.com/admin/machines
2. Find the "baby" device
3. Click **⋯** → **Edit route settings**
4. Ensure `10.0.0.0/24` is **approved**

## Security Notes

- Tailscale provides encrypted WireGuard VPN tunnels
- All traffic between your MacBook and Baby NAS is encrypted
- No port forwarding or public exposure required
- Subnet routing allows access to your entire home network securely

## Quick Reference Commands

```bash
# Check Tailscale status
tailscale status

# Get Baby NAS Tailscale IP
ping 100.95.3.18

# SSH to Baby NAS
ssh truenas_admin@100.95.3.18

# Mount workspace share
mount_smbfs //smbuser@100.95.3.18/workspace ~/NAS/workspace

# Unmount when done
umount ~/NAS/workspace
```

## What You Can Do Now

✅ Access Baby NAS from anywhere in the world
✅ Backup your MacBook to the NAS remotely
✅ Access files on workspace, models, staging, and backup shares
✅ Access your entire home network (10.0.0.x) through Baby NAS
✅ SSH into Baby NAS for management

## Next Steps

1. Test the connection from your MacBook
2. Set up automatic mounting if desired
3. Configure Time Machine backups
4. Add SSH config for easy access (optional - see below)

### Optional: SSH Config

Add to `~/.ssh/config` on MacBook:

```
Host babynas
    HostName 100.95.3.18
    User truenas_admin
    IdentityFile ~/.ssh/babynas
```

Then you can just run: `ssh babynas`

---

**Last Updated:** 2026-01-17
**Baby NAS Tailscale IP:** 100.95.3.18
**MacBook Tailscale IP:** 100.97.3.123
