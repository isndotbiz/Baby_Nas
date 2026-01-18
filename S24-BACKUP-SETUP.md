# Samsung S24 Backup to Baby NAS - Quick Setup

## 📱 What You'll Get

- **Automatic photo/video backup** to Baby NAS
- **Access from anywhere** via Tailscale VPN
- **Dedicated folder:** `/mnt/tank/phone-backups/samsung-s24` (500GB quota)
- **Secure encrypted connection**

## 🚀 Quick Setup (5 Minutes)

### Step 1: Install Tailscale on Your S24

1. **Open Play Store** on your S24
2. **Search for:** "Tailscale"
3. **Install** the Tailscale app
4. **Open** Tailscale app

### Step 2: Connect to Tailscale

**Option A: Scan QR Code (Easiest)**

Open the Tailscale app and scan this QR code:

```
┌─────────────────────────────────────────────┐
│  Scan this with Tailscale app on your S24  │
│                                             │
│  Or visit: https://login.tailscale.com     │
│  Login with: jdmallin25x40@gmail.com       │
└─────────────────────────────────────────────┘
```

**Option B: Manual Login**

1. Open Tailscale app
2. Tap **Sign in**
3. Login with: `jdmallin25x40@gmail.com`
4. Authorize the device

**After login, your S24 will have Tailscale IP:** `100.103.5.63` (or new IP if changed)

### Step 3: Install SMB/CIFS File Manager

**Recommended App: Solid Explorer** (Free with trial, $2.99)

1. **Open Play Store**
2. **Search for:** "Solid Explorer"
3. **Install** and open

**Alternative Apps:**
- **FolderSync** (best for auto-sync)
- **X-plore File Manager** (free, built-in SMB)
- **Total Commander** with LAN plugin

### Step 4: Connect to Baby NAS

**In Solid Explorer (or your chosen app):**

1. Tap **☰** (menu) → **Storage** → **+** (Add Storage)
2. Select **LAN / SMB**
3. Enter connection details:

```
Name: Baby NAS - S24 Backup
Server: 100.95.3.18
Username: smbuser
Password: YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe
Path: /phone-backups/samsung-s24
```

4. Tap **Connect**

### Step 5: Set Up Auto-Backup (FolderSync Method)

**If using FolderSync app (recommended for automation):**

1. **Install FolderSync** from Play Store
2. Open FolderSync
3. **Add Account:**
   - Type: **SMB**
   - Name: `Baby NAS`
   - Server: `100.95.3.18`
   - Username: `smbuser`
   - Password: `YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe`
   - Remote folder: `/phone-backups/samsung-s24`

4. **Create Folder Pair:**
   - Local folder: `DCIM/Camera` (your photos)
   - Remote folder: Baby NAS account → `/photos`
   - Sync type: **To remote folder**
   - Schedule: **When charging + WiFi** (saves battery/data)

5. **Enable Sync**

## 📋 Connection Details Quick Reference

### Baby NAS via Tailscale
- **IP Address:** `100.95.3.18`
- **Hostname (MagicDNS):** `baby.tailfef21a.ts.net`
- **Your backup folder:** `/phone-backups/samsung-s24`

### SMB Credentials
- **Username:** `smbuser`
- **Password:** `YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe`

### Available Shares via SMB
| Share Path | Purpose | Quota |
|------------|---------|-------|
| `/phone-backups/samsung-s24` | Your S24 backups | 500GB |
| `/workspace` | General workspace | 11TB |
| `/staging` | Downloads/temp | 11TB |

## 🔧 Manual Backup (Anytime)

### Using Solid Explorer:
1. Open **Solid Explorer**
2. Connect to **Baby NAS** storage
3. Navigate to local **DCIM/Camera**
4. **Select** photos/videos
5. **Copy** to Baby NAS `/samsung-s24/photos/`

### Using Any File Manager:
1. Navigate to `smb://100.95.3.18/phone-backups/samsung-s24`
2. Drag and drop files

## 📸 What to Backup

**Recommended folders to backup:**
- **DCIM/Camera** - Photos and videos
- **DCIM/Screenshots** - Screenshots
- **WhatsApp/Media** - WhatsApp images/videos
- **Download** - Downloaded files
- **Documents** - Important documents

## 🌐 Access Your Backups

### From Windows Desktop:
```
\\100.95.3.18\phone-backups\samsung-s24
```

### From MacBook:
```
smb://100.95.3.18/phone-backups/samsung-s24
```

### From Baby NAS directly:
```
ssh truenas_admin@100.95.3.18
cd /mnt/tank/phone-backups/samsung-s24
ls -la
```

## ⚙️ Advanced: Automatic Photo Sync Apps

### Option 1: Syncthing (Best for real-time sync)
1. Install **Syncthing** on S24 and Baby NAS
2. Configure folder pairing
3. Syncs automatically in background

### Option 2: FolderSync (Scheduled sync)
- Already described above
- Pro version ($3.99) removes ads and adds features

### Option 3: Nextcloud (Full cloud solution)
- Install Nextcloud on Baby NAS (Docker)
- Install Nextcloud app on S24
- Auto-upload photos like Google Photos

## 🛠️ Troubleshooting

### Can't Connect to Baby NAS

**Check Tailscale connection:**
1. Open Tailscale app on S24
2. Make sure it shows **Connected**
3. Check your Tailscale IP appears in the list

**Test connection:**
- Use **Network Analyzer** app from Play Store
- Ping `100.95.3.18`
- Should respond if Tailscale is connected

### SMB Connection Fails

**Check credentials:**
- Username: `smbuser` (lowercase, no spaces)
- Password: Copy exactly from this guide
- Server: `100.95.3.18` (Tailscale IP, not local IP)

**Try alternative:**
- Use MagicDNS hostname: `baby.tailfef21a.ts.net`
- Some apps work better with hostname than IP

### Slow Upload Speed

**This is normal when remote:**
- Tailscale encrypted tunnel = slower than local WiFi
- **Solution:** Enable "sync only when on WiFi" in FolderSync
- Or wait until you're home on local network

**When home (same network):**
- Phone can use local IP: `10.0.0.88`
- Much faster (no Tailscale tunnel)

## 💡 Pro Tips

### 1. Save Battery
- Set FolderSync to sync only when **charging**
- Use WiFi-only mode to save mobile data

### 2. Organize Your Backups
Create subfolders:
```
/samsung-s24/
  ├── photos/
  ├── videos/
  ├── screenshots/
  ├── whatsapp/
  └── documents/
```

### 3. Local Network Speed Boost
Add a second connection profile in your file manager:
- Name: `Baby NAS (Home)`
- Server: `10.0.0.88` (local IP, faster when home)
- Same credentials

Use local connection when home for faster transfers!

### 4. Automatic Switching
Some apps like FolderSync can auto-detect and use local connection when available, falling back to Tailscale when remote.

## 🔐 Security Notes

- ✅ All connections encrypted via Tailscale
- ✅ No port forwarding or public exposure
- ✅ Only your devices can access via Tailscale
- ✅ SMB credentials stored securely on phone

## 📊 Storage Quota

Your S24 backup folder has **500GB quota**:
```bash
# Check usage via SSH to Baby NAS:
ssh truenas_admin@100.95.3.18
df -h /mnt/tank/phone-backups/samsung-s24
```

Need more space? Contact admin to increase quota.

## 🎯 Quick Start Summary

1. **Install Tailscale** → Connect with your Google account
2. **Install Solid Explorer or FolderSync**
3. **Add SMB connection** → Use `100.95.3.18` + credentials
4. **Set up auto-sync** (optional)
5. **Done!** Your photos backup automatically

---

**Questions or Issues?**
- Check Tailscale is connected
- Verify credentials are correct
- Test ping to `100.95.3.18` using Network Analyzer app

**Last Updated:** 2026-01-18
**Your Tailscale IP:** 100.103.5.63 (may change if device re-added)
