# Baby NAS MacBook Quick Start Guide

## 🚀 One-Time Setup (5 minutes)

### Step 1: Download the Scripts

```bash
# Clone the repo
cd ~/Documents
git clone https://github.com/isndotbiz/Baby_Nas.git
cd Baby_Nas

# Make scripts executable
chmod +x macbook-*.sh
```

### Step 2: Set Up Custom Domains (Optional but Recommended)

This lets you use friendly names like `baby.isn.biz` instead of `100.95.3.18`:

```bash
sudo ./macbook-setup-custom-domains.sh
```

**What this does:**
- Adds entries to `/etc/hosts` for custom domains
- Creates hostnames: `baby.isn.biz`, `workspace.isn.biz`, `timemachine.isn.biz`, etc.
- Backs up your current `/etc/hosts` file first

**Test it:**
```bash
ping baby.isn.biz
# Should respond from 100.95.3.18
```

### Step 3: Mount Baby NAS Shares

```bash
./macbook-mount-nas.sh
```

**First time only:** You'll be prompted for the SMB password once. Enter:
```
Password: YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe
```

Choose "Yes" when asked to save to Keychain. Future mounts will be automatic!

**What this does:**
- Mounts all shares to `~/NAS/` directory
- Shares: workspace, models, staging, backups
- Uses custom domains if configured, otherwise Tailscale DNS

### Step 4: Access Your Files

```bash
# Open in Finder
open ~/NAS/workspace

# Or use command line
cd ~/NAS/workspace
ls -la
```

## 📋 Daily Usage

### Mount Shares

```bash
cd ~/Documents/Baby_Nas
./macbook-mount-nas.sh
```

Shares will be available at:
- `~/NAS/workspace`
- `~/NAS/models`
- `~/NAS/staging`
- `~/NAS/backups`

### Unmount Shares

```bash
cd ~/Documents/Baby_Nas
./macbook-unmount-nas.sh
```

## ⏰ Time Machine Setup

### Create Time Machine Share on Baby NAS (One-Time)

**Option A: Via Web UI**
1. Open http://100.95.3.18 or http://baby.isn.biz
2. Login: `truenas_admin` / `Tigeruppercut1913!`
3. Go to **Shares → SMB**
4. Click **Add**
   - Name: `timemachine`
   - Path: `/mnt/tank/timemachine`
   - Purpose: **Time Machine**
5. Enable **Time Machine** toggle
6. Save

**Option B: Via SSH**
```bash
# SSH to Baby NAS
ssh truenas_admin@baby.isn.biz
# Password: Tigeruppercut1913!

# Create dataset
sudo zfs create tank/timemachine
sudo zfs set quota=2T tank/timemachine  # Adjust size as needed

# Create SMB share via TrueNAS web UI (easier than CLI)
```

### Configure Time Machine on MacBook

**Option 1: Using Custom Domain (if configured)**
```bash
sudo tmutil setdestination smb://smbuser:YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe@timemachine.isn.biz/timemachine
```

**Option 2: Using Tailscale IP**
```bash
sudo tmutil setdestination smb://smbuser:YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe@100.95.3.18/timemachine
```

**Option 3: Via System Preferences (macOS Ventura+)**
1. Open **System Settings** → **General** → **Time Machine**
2. Click **Select Backup Disk**
3. Click **Set Up Disk** → **Connect to Server**
4. Enter: `smb://timemachine.isn.biz/timemachine` or `smb://100.95.3.18/timemachine`
5. Username: `smbuser`
6. Password: `YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe`

### Verify Time Machine

```bash
# Check Time Machine destination
tmutil destinationinfo

# Start backup immediately
tmutil startbackup

# Check status
tmutil status
```

## 🌐 Available Hostnames

After running the custom domains setup, you can use any of these:

| Hostname | Purpose | Example |
|----------|---------|---------|
| `baby.isn.biz` | General access | `ssh truenas_admin@baby.isn.biz` |
| `workspace.isn.biz` | Workspace share | `smb://workspace.isn.biz/workspace` |
| `models.isn.biz` | Models share | `smb://models.isn.biz/models` |
| `staging.isn.biz` | Staging share | `smb://staging.isn.biz/staging` |
| `backups.isn.biz` | Backups share | `smb://backups.isn.biz/backups` |
| `timemachine.isn.biz` | Time Machine | `smb://timemachine.isn.biz/timemachine` |

**Tailscale MagicDNS (works without custom setup):**
- `baby.tailfef21a.ts.net`

**Tailscale IP (always works):**
- `100.95.3.18`

## 🔑 Credentials Quick Reference

### SMB Shares (Mounting Drives)
- **Username:** `smbuser`
- **Password:** `YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe`

### SSH Access
- **Username:** `truenas_admin`
- **Password:** `Tigeruppercut1913!`

### TrueNAS Web UI
- **URL:** http://baby.isn.biz or http://100.95.3.18
- **Username:** `truenas_admin`
- **Password:** `Tigeruppercut1913!`

## 🛠️ Troubleshooting

### Can't Reach Baby NAS

```bash
# Check Tailscale connection
tailscale status

# Check if Baby NAS is online
ping baby.isn.biz
# or
ping 100.95.3.18

# Restart Tailscale if needed
sudo tailscale down
sudo tailscale up
```

### Mount Fails

```bash
# Unmount all first
./macbook-unmount-nas.sh

# Try mounting again
./macbook-mount-nas.sh

# If still fails, mount manually to see error
mkdir -p ~/NAS/workspace
mount_smbfs //smbuser@baby.isn.biz/workspace ~/NAS/workspace
```

### Custom Domains Not Working

```bash
# Check if entries are in /etc/hosts
cat /etc/hosts | grep baby

# Re-run setup if needed
sudo ./macbook-setup-custom-domains.sh

# Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Time Machine Backup Slow

Time Machine over Tailscale works but is slower than local network. This is normal. For faster backups:

1. Connect to local network (same WiFi as Baby NAS)
2. Time Machine will automatically use local connection (10.0.0.88) when available
3. When remote, it falls back to Tailscale (slower but still works)

## 📚 Scripts Reference

| Script | Purpose |
|--------|---------|
| `macbook-setup-custom-domains.sh` | Set up *.isn.biz hostnames (run once) |
| `macbook-mount-nas.sh` | Mount all Baby NAS shares |
| `macbook-unmount-nas.sh` | Unmount all Baby NAS shares |

## 💡 Pro Tips

### Auto-Mount on Login

Create a Launch Agent to mount shares automatically:

```bash
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.isn.babynas.mount.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.isn.babynas.mount</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/YOUR_USERNAME/Documents/Baby_Nas/macbook-mount-nas.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>300</integer>
</dict>
</plist>
EOF

# Replace YOUR_USERNAME with your actual username
sed -i '' "s/YOUR_USERNAME/$USER/g" ~/Library/LaunchAgents/com.isn.babynas.mount.plist

# Load the launch agent
launchctl load ~/Library/LaunchAgents/com.isn.babynas.mount.plist
```

### SSH Config

Add to `~/.ssh/config` for easy SSH access:

```
Host babynas baby
    HostName baby.isn.biz
    User truenas_admin
```

Then just use:
```bash
ssh babynas
```

### Finder Sidebar

Drag `~/NAS` to Finder sidebar for quick access!

## 🎯 Summary

1. **Setup once:** Run custom domains script
2. **Daily use:** Run mount script when you need access
3. **Time Machine:** Set up once, backups run automatically
4. **Works anywhere:** Home or remote, Tailscale handles it

---

**Questions?** Check the full guide: `MACBOOK-SETUP.md`
