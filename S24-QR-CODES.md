# S24 Quick Setup - Scan These QR Codes

## 📱 Step 1: Install Tailscale

**Scan this QR code to open Tailscale in Play Store:**

```
https://play.google.com/store/apps/details?id=com.tailscale.ipn
```

**Or search "Tailscale" in Play Store**

---

## 🔐 Step 2: Login to Tailscale

Open Tailscale app and login with:

**Email:** `jdmallin25x40@gmail.com`

**Or scan to visit Tailscale login:**

```
https://login.tailscale.com
```

---

## 📂 Step 3: Install File Manager

**Recommended: Solid Explorer**

Scan to install:
```
https://play.google.com/store/apps/details?id=pl.solidexplorer2
```

**Alternative: FolderSync (for auto-backup)**

Scan to install:
```
https://play.google.com/store/apps/details?id=dk.tacit.android.foldersync.lite
```

---

## 🔌 Step 4: SMB Connection Details

**Copy these into your file manager app:**

```
Server: 100.95.3.18
Username: smbuser
Password: YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe
Path: /phone-backups/samsung-s24
```

**Baby NAS via Tailscale:**
```
smb://100.95.3.18/phone-backups/samsung-s24
```

---

## ✅ Quick Test

After setup, test the connection:

1. **Open Tailscale** - Should show "Connected"
2. **Check devices** - Should see "baby" in device list
3. **Open file manager** - Should see Baby NAS storage
4. **Browse to** `/phone-backups/samsung-s24`

---

## 🎯 Auto-Backup Setup (FolderSync)

### Add Account in FolderSync:
```
Type: SMB
Name: Baby NAS
Server: 100.95.3.18
Username: smbuser
Password: YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe
Folder: /phone-backups/samsung-s24
```

### Create Folder Pair:
```
Local: DCIM/Camera
Remote: Baby NAS → /photos
Sync: To remote folder
When: Charging + WiFi only
```

---

## 🌐 Access From Other Devices

### Windows:
```
\\100.95.3.18\phone-backups\samsung-s24
```

### Mac:
```
smb://100.95.3.18/phone-backups/samsung-s24
```

### Web Browser:
```
http://100.95.3.18
Login: truenas_admin / Tigeruppercut1913!
```

---

## 💾 Storage Info

**Your Quota:** 500GB
**Current Usage:** ~1MB (empty)
**Available Shares:**
- `/phone-backups/samsung-s24` - Your backups
- `/workspace` - General files
- `/staging` - Downloads

---

## 📞 Need Help?

**Can't connect?**
1. Check Tailscale is connected and showing "baby" device
2. Verify password is exact (copy from this guide)
3. Try hostname instead: `baby.tailfef21a.ts.net`

**Slow uploads?**
- Normal when remote (Tailscale tunnel)
- Set to sync only on WiFi + charging
- Much faster when home on same network (use 10.0.0.88)

---

**Print this page or save screenshot for easy reference!**

## 🔑 Credentials at a Glance

| What | Value |
|------|-------|
| **Tailscale Login** | jdmallin25x40@gmail.com |
| **Baby NAS IP** | 100.95.3.18 |
| **SMB Username** | smbuser |
| **SMB Password** | YICcA3DO62p4LCmsI0gfYookyhTplp1wygicQEXe |
| **Your Folder** | /phone-backups/samsung-s24 |
| **Quota** | 500GB |
