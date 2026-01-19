# Network Configuration Guide

## 📊 Current Network Setup

Your system has:
- **Ethernet (10.0.0.100)** → Connected to Main NAS network (10.0.0.89)
- **BabyNAS VM (172.31.246.136)** → On separate Hyper-V virtual network
- **Issue:** BabyNAS is on different subnet, needs routing configuration

---

## 🔍 Problem Diagnosis

**Why SSH to BabyNAS fails:**
1. BabyNAS is on 172.31.246.x network (Hyper-V internal switch)
2. Your main system is on 10.0.0.x network
3. No route exists between these two networks
4. SSH connection times out

**Solution:** Configure routing between the networks OR use the domain name (babynas.isndotbiz.com) if DNS is set up.

---

## ✅ Quick Fix: Use Domain Name Instead

Since you mentioned wanting to use `babynas.isndotbiz.com` instead of IPs:

**Test DNS resolution first:**
```powershell
nslookup babynas.isndotbiz.com
```

If this resolves, modify the script to use the domain:
```powershell
$BabyNasIP = "babynas.isndotbiz.com"
```

---

## 🛠️ Option 1: Configure Static Route (Recommended)

Add a route from your system to the BabyNAS network:

### Windows Command Prompt (Run as Administrator):

```cmd
route add 172.31.246.0 mask 255.255.255.0 10.0.0.1 -p
```

This tells your system: "To reach 172.31.246.x, go through 10.0.0.1 (Main NAS)"

### PowerShell (Run as Administrator):

```powershell
New-NetRoute -DestinationPrefix "172.31.246.0/24" -NextHop "10.0.0.1" -PolicyStore PersistentStore
```

### Verify the route was added:

```powershell
Get-NetRoute | Where-Object {$_.DestinationPrefix -like "172.31.246*"}
```

---

## 🛠️ Option 2: Configure Hyper-V Virtual Switch

If BabyNAS is on a Hyper-V internal switch, you may need to configure that switch:

### Check Hyper-V Switches:

```powershell
Get-VMSwitch
```

Look for the switch that BabyNAS uses.

### If BabyNAS is on "Default Switch":

The Default Switch should bridge to your Ethernet connection automatically. Try:

```powershell
# Restart the Hyper-V host networking
net stop hns
net start hns
```

---

## 🛠️ Option 3: Configure Firewall Rules

If connectivity still fails, check Windows Firewall:

### Allow SSH through Firewall:

```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "Allow SSH to BabyNAS" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 22 -RemoteAddress "172.31.246.0/24"
```

---

## 🛠️ Option 4: Check BabyNAS Network Configuration

On BabyNAS itself, verify network settings:

1. Open BabyNAS Web UI: `https://172.31.246.136`
2. Go to: System → Network → Interfaces
3. Check:
   - IP Address: 172.31.246.136 ✓
   - Netmask: 255.255.255.0
   - Gateway: (should have one)
   - DNS Servers: (should have at least one)

4. If missing gateway, add:
   - Gateway: 172.31.246.1 (or the Hyper-V switch gateway)
   - DNS: 8.8.8.8 or your network DNS

---

## 🛠️ Option 5: Add Static Route on BabyNAS

If BabyNAS can't reach your system, configure its routing too:

1. Open BabyNAS Web UI: `https://172.31.246.136`
2. Go to: System → Network → Static Routes
3. Add Route:
   - Destination: 10.0.0.0/24
   - Gateway: 172.31.246.1
   - Metric: 1

---

## 🧪 Test Connectivity

After configuring, test the connection:

### From Windows PowerShell:

```powershell
# Test ping
ping 172.31.246.136

# Test SSH port
Test-NetConnection -ComputerName 172.31.246.136 -Port 22 -InformationLevel Detailed

# Try SSH connection
ssh -i $env:USERPROFILE\.ssh\id_ed25519 root@172.31.246.136
```

### Expected Results:

```
ping: Reply from 172.31.246.136: bytes=32 time=1ms TTL=64
Test-NetConnection: TCP test succeeded. Port 22 (SSH) is open.
```

---

## 🛠️ Option 6: Use VPN/Domain Access

If local routing is complex, use your configured domains:

1. **For BabyNAS:** `babynas.isndotbiz.com` (if external DNS works)
2. **For Main NAS:** `baremetal.isn.biz` (if external DNS works)

### Test DNS:

```powershell
nslookup babynas.isndotbiz.com
nslookup baremetal.isn.biz
```

If these resolve to your public IPs, you can use them in the configuration.

---

## 📋 Complete Network Configuration Checklist

- [ ] Route added: 172.31.246.0/24 → 10.0.0.1
- [ ] BabyNAS gateway configured (172.31.246.1)
- [ ] BabyNAS DNS servers set (8.8.8.8 or local)
- [ ] Firewall rules allow SSH outbound
- [ ] Ping BabyNAS successful
- [ ] SSH port 22 reachable
- [ ] SSH key authentication works
- [ ] DNS names resolve (if using domains)

---

## 🚀 After Network is Fixed

Once connectivity is established:

1. Run the setup script:
   ```powershell
   .\SETUP-BABY-NAS-USER.ps1
   ```

2. Create snapshot tasks (BabyNAS Web UI)

3. Create replication task (BabyNAS Web UI)

4. Monitor progress (Main NAS Web UI)

---

## 🆘 If Still Having Issues

1. **Check Hyper-V VM networking:**
   - Open Hyper-V Manager
   - Right-click VM → Settings → Network Adapter
   - Note which Virtual Switch it's connected to
   - Verify that switch is connected to your Ethernet adapter

2. **Check firewall logs:**
   ```powershell
   # View blocked connections
   Get-NetFirewallRule -Direction Outbound -Enabled $true | Get-NetFirewallPortFilter
   ```

3. **Trace route to BabyNAS:**
   ```powershell
   tracert 172.31.246.136
   ```

4. **Check Windows routing table:**
   ```powershell
   route print
   ```

5. **Verify SSH key permissions:**
   ```powershell
   icacls $env:USERPROFILE\.ssh\id_ed25519
   ```

---

## Summary

**Recommended Action:**
1. Add static route: `route add 172.31.246.0 mask 255.255.255.0 10.0.0.1 -p`
2. Test ping to 172.31.246.136
3. Test SSH: `ssh -i $env:USERPROFILE\.ssh\id_ed25519 root@172.31.246.136`
4. If successful, run `.\SETUP-BABY-NAS-USER.ps1`

If you continue having issues, provide output of:
- `route print`
- `ping 172.31.246.136`
- `Test-NetConnection -ComputerName 172.31.246.136 -Port 22 -InformationLevel Detailed`
