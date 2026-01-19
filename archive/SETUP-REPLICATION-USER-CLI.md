# Setup baby-nas User via TrueNAS CLI or Linux Shell

Choose the method that works best for you:

---

## 🖥️ Option 1: TrueNAS Web UI Shell

**Fastest & Easiest**

1. Open: `https://10.0.0.89`
2. Path: System → Shell
3. Copy & paste commands below

---

## 🐧 Option 2: SSH into Main NAS (Linux Shell)

**Most Direct**

```powershell
# From Windows, SSH into Main NAS
ssh -i ~/.ssh/truenas_jdmal jdmal@10.0.0.89

# Then copy/paste commands below
```

---

## ⚡ Quick Commands (Copy & Paste)

### Create baby-nas User

```bash
# Create the user with no login shell
pw useradd -n baby-nas -d /nonexistent -s /usr/sbin/nologin -m

# Create SSH directory
mkdir -p /home/baby-nas/.ssh
chmod 700 /home/baby-nas/.ssh
```

### Add SSH Public Key

**First, get the key from BabyNAS:**

On your Windows machine:
```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.31.246.136 "cat ~/.ssh/id_ed25519.pub"
```

**Then, on Main NAS (paste the key):**

```bash
# Replace PASTE_KEY_HERE with the actual SSH key
cat > /home/baby-nas/.ssh/authorized_keys << 'EOF'
PASTE_KEY_HERE
EOF

chmod 600 /home/baby-nas/.ssh/authorized_keys
chown -R baby-nas:baby-nas /home/baby-nas/.ssh
```

**Example:**
```bash
cat > /home/baby-nas/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxx root@babynas
EOF

chmod 600 /home/baby-nas/.ssh/authorized_keys
chown -R baby-nas:baby-nas /home/baby-nas/.ssh
```

### Grant ZFS Permissions

```bash
# Give baby-nas permission to receive replicated snapshots
zfs allow -u baby-nas create,receive,rollback,destroy,mount tank/rag-system

# Verify permissions were set
zfs allow tank/rag-system | grep baby-nas
```

### Verify Everything Works

```bash
# Test SSH connection as baby-nas
ssh -i /home/baby-nas/.ssh/id_ed25519 baby-nas@localhost "zfs list tank/rag-system"

# Should output:
# NAME             USED  AVAIL  REFER  MOUNTPOINT
# tank/rag-system   12K   7.5T   12K   /mnt/tank/rag-system
```

---

## 🌐 Network Configuration (If Needed)

### Do You Need to Configure Network?

**Quick Check:**
```bash
# Test connectivity FROM BabyNAS TO Main NAS
ssh -i ~/.ssh/id_ed25519 root@172.31.246.136 "ping -c 1 10.0.0.89"

# If this works, network is fine. If not, configure below.
```

### Configure Static IP (If Network Issues)

If you need to configure network settings:

**Option A: TrueNAS Web UI**
- Path: System → Network → Interfaces
- Edit interface
- Configure IP, gateway, DNS

**Option B: CLI**

```bash
# View current network config
ifconfig

# View routing table
netstat -rn

# Add static route (example)
route add -net 10.0.0.0/24 10.0.0.1

# Make persistent (edit /etc/rc.conf or via TrueNAS)
```

### Configure Static Routes (If Needed)

**Via TrueNAS Web UI:**
- Path: System → Network → Static Routes
- Add Route
  - Destination: 10.0.0.0/24
  - Gateway: (your gateway IP)
  - Metric: 1

**Via CLI:**

```bash
# View routes
netstat -rn

# Add route temporarily
route add -net 10.0.0.0/24 10.0.0.1

# View route to specific host
traceroute 172.31.246.136
```

---

## 📋 Step-by-Step: Complete Setup via CLI

### Step 1: Create User and SSH Key

```bash
# SSH into Main NAS
ssh -i ~/.ssh/truenas_jdmal jdmal@10.0.0.89

# Create user
pw useradd -n baby-nas -d /nonexistent -s /usr/sbin/nologin -m
mkdir -p /home/baby-nas/.ssh
chmod 700 /home/baby-nas/.ssh
```

### Step 2: Add SSH Public Key

```bash
# Paste the key you got from BabyNAS
cat > /home/baby-nas/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx root@babynas
EOF

chmod 600 /home/baby-nas/.ssh/authorized_keys
chown -R baby-nas:baby-nas /home/baby-nas/.ssh
```

### Step 3: Grant ZFS Permissions

```bash
zfs allow -u baby-nas create,receive,rollback,destroy,mount tank/rag-system
zfs allow tank/rag-system | grep baby-nas
```

### Step 4: Verify Setup

```bash
# Test from Main NAS
ssh baby-nas@localhost "zfs list tank"

# Test SSH works
ssh -i /home/baby-nas/.ssh/id_ed25519 baby-nas@localhost "whoami"
# Should output: baby-nas
```

### Step 5: Test Replication Connection

From BabyNAS, test the connection:
```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.31.246.136 `
  "ssh baby-nas@10.0.0.89 'zfs list tank/rag-system'"
```

**Expected output:**
```
NAME             USED  AVAIL  REFER  MOUNTPOINT
tank/rag-system  12K   7.5T   12K   /mnt/tank/rag-system
```

---

## ✅ Verification Checklist

After running the commands above:

```bash
# 1. User exists
id baby-nas
# Should output: uid=1001(baby-nas) gid=1001(baby-nas) groups=1001(baby-nas)

# 2. SSH key is set
ls -la /home/baby-nas/.ssh/authorized_keys
# Should output: -rw------- baby-nas baby-nas

# 3. ZFS permissions are set
zfs allow tank/rag-system | grep baby-nas
# Should show: create,destroy,mount,receive,rollback

# 4. Can receive data
zfs recv -n tank/rag-system < /dev/null
# Should complete without error (test mode)
```

---

## 🐛 Troubleshooting

### "User already exists"
```bash
# Check if user exists
pw usershow baby-nas

# Delete and recreate if needed
pw userdel baby-nas
rmdir /home/baby-nas
# Then run create commands again
```

### "Permission denied" on ZFS operations
```bash
# Check current permissions
zfs allow tank/rag-system

# Re-add permissions
zfs allow -u baby-nas create,receive,rollback,destroy,mount tank/rag-system
```

### "SSH key not working"
```bash
# Check file permissions
ls -la /home/baby-nas/.ssh/authorized_keys
# Should be: -rw------- (600)

# Fix if needed
chmod 600 /home/baby-nas/.ssh/authorized_keys
chown baby-nas:baby-nas /home/baby-nas/.ssh/authorized_keys
```

### "Cannot connect to 10.0.0.89"
```bash
# Check routing
netstat -rn | grep 10.0.0

# Check firewall
pf -vv | grep "pass in"

# Test connectivity
ping 10.0.0.89

# Test SSH port
telnet 10.0.0.89 22
```

---

## 🚀 Quick Start Command Sets

### Copy-Paste All Commands at Once

```bash
#!/bin/bash
# Run on Main NAS as root or with sudo

# Create user
pw useradd -n baby-nas -d /nonexistent -s /usr/sbin/nologin -m
mkdir -p /home/baby-nas/.ssh
chmod 700 /home/baby-nas/.ssh

# Add SSH key (replace with actual key)
cat > /home/baby-nas/.ssh/authorized_keys << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx root@babynas
EOF

chmod 600 /home/baby-nas/.ssh/authorized_keys
chown -R baby-nas:baby-nas /home/baby-nas/.ssh

# Grant permissions
zfs allow -u baby-nas create,receive,rollback,destroy,mount tank/rag-system

# Verify
echo "=== User ===" && id baby-nas
echo "=== SSH Key ===" && ls -la /home/baby-nas/.ssh/authorized_keys
echo "=== Permissions ===" && zfs allow tank/rag-system | grep baby-nas
```

---

## 📌 Summary

**Choose ONE method:**

| Method | Time | Skill Level | Use When |
|--------|------|-------------|----------|
| **Web UI** | 5 min | Easy | You prefer UI |
| **TrueNAS Shell** | 3 min | Medium | You're in TrueNAS |
| **SSH CLI** | 2 min | Hard | You're comfortable with CLI |

**All methods accomplish the same result.**

Once complete, proceed to create snapshot/replication tasks in TrueNAS Web UI.
