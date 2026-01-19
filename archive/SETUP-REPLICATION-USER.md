# Setup Replication User on Main NAS (10.0.0.89)

## ❓ Do You Need to Setup a Local Admin?

**Answer: You need to create the `baby-nas` replication user on Main NAS.**

This user is what BabyNAS will use to push replication data to Main NAS via SSH.

---

## 🚀 Step-by-Step Setup

### Option A: Via TrueNAS Web UI (Easiest)

**1. Open Main NAS Web UI**
- URL: `https://10.0.0.89`
- Login with admin credentials

**2. Create the baby-nas User**
- Path: System → Users → Add User
- Fill in:
  ```
  Username:                baby-nas
  Full Name:               BabyNAS Replication User
  Email:                   (optional)
  Disable Password Login:  ✓ CHECKED
  Samba Authentication:    ☐ unchecked
  Locked Account:          ☐ unchecked
  Permitted sudo commands: (leave blank)
  SSH Public Key:          (leave blank for now, add below)
  ```
- Click: **Save**

**3. Add SSH Public Key to baby-nas User**
- Path: System → Users → baby-nas → Edit
- Find: **SSH Public Key** field
- Paste the key from BabyNAS (see below how to get it)
- Click: **Save**

---

### Getting SSH Public Key from BabyNAS

Run this command on your Windows machine (with SSH access to BabyNAS):

```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.31.246.136 "cat ~/.ssh/id_ed25519.pub"
```

**Expected output looks like:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx root@babynas
```

Copy the **entire line** and paste it into the SSH Public Key field on Main NAS.

---

### Grant Permissions to baby-nas User

Once the user is created, grant ZFS permissions via SSH:

```bash
# SSH into Main NAS as admin user
ssh -i ~/.ssh/truenas_jdmal jdmal@10.0.0.89

# Then run these commands (may need sudo):
sudo zfs allow -u baby-nas create,receive,rollback,destroy,mount tank/rag-system
sudo zfs allow -u baby-nas create,receive,rollback,destroy,mount tank
```

Or via TrueNAS Web UI:
- Path: Storage → Pools → tank → Permissions → Add Permission
- User: baby-nas
- Permissions:
  - ✓ create
  - ✓ receive
  - ✓ rollback
  - ✓ destroy
  - ✓ mount

---

## ✅ Verify Setup

Test SSH connection from BabyNAS:

```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.31.246.136 `
  "ssh baby-nas@10.0.0.89 'zfs list tank/rag-system'"
```

**Expected output:**
```
NAME             USED  AVAIL  REFER  MOUNTPOINT
tank/rag-system  12K   7.5T   12K   /mnt/tank/rag-system
```

If successful, replication is ready!

---

## 🔐 Security Notes

- **baby-nas user has NO password** (SSH key only) ✓ Secure
- **No sudo access** (cannot access full system) ✓ Secure
- **Limited ZFS permissions** (only tank/rag-system dataset) ✓ Secure
- **SSH public key only** (no private key shared) ✓ Secure

---

## What If baby-nas Already Exists?

If the user already exists:

1. Check if SSH key is set:
   - System → Users → baby-nas → Edit
   - See if SSH Public Key field has content

2. If SSH key is NOT set:
   - Get key from BabyNAS (see above)
   - Add it to the baby-nas user

3. Verify permissions:
   - Try test command above
   - If "Permission denied", grant ZFS permissions (see above)

---

## Troubleshooting

### "Permission denied" when trying to receive replicated data
**Solution:** Grant ZFS permissions
```bash
sudo zfs allow -u baby-nas create,receive,rollback,destroy,mount tank/rag-system
```

### "SSH public key not set" error
**Solution:** Add SSH key from BabyNAS
1. Get key: `ssh root@172.31.246.136 "cat ~/.ssh/id_ed25519.pub"`
2. Paste into: System → Users → baby-nas → SSH Public Key

### "Cannot connect to 10.0.0.89"
**Solution:** Check network
```powershell
Test-Connection -ComputerName 10.0.0.89
Test-NetConnection -ComputerName 10.0.0.89 -Port 22
```

### "tank/rag-system dataset doesn't exist"
**Solution:** Create it on Main NAS
- Path: Storage → Pools → Tank → Add Dataset
- Name: rag-system
- Click: **Create**

---

## Summary

Before starting replication:

- [ ] baby-nas user created on Main NAS
- [ ] SSH public key added to baby-nas user
- [ ] ZFS permissions granted to baby-nas
- [ ] tank/rag-system dataset exists on Main NAS
- [ ] SSH connection test successful

Once all are checked, proceed with TrueNAS replication task setup.
