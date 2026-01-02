# BabyNAS Setup - Quick Start Guide

## 🚀 Quick Start Options

Choose based on your preference:

### Option 1: Full Automated Setup (Recommended)
**For:** Users who want everything done automatically
```powershell
.\MASTER-SETUP.ps1
```
- Runs all setup steps sequentially
- Tests everything at each stage
- Creates detailed log file
- Full control and flexibility

**Expected Duration:** 5-10 minutes

---

### Option 2: Interactive Wizard
**For:** Users who want to make choices at each step
```powershell
.\setup-wizard.ps1
```
- Step-by-step guided experience
- Choose which components to setup
- Pause and verify before proceeding
- Recommended for first-time setup

**Expected Duration:** 10-15 minutes

---

### Option 3: Individual Scripts
**For:** Power users who prefer granular control
```powershell
# Step 1: Diagnose connectivity
.\diagnose-baby-nas.ps1

# Step 2: Generate API key
.\create-api-key-ssh.ps1

# Step 3: Map Z: drive
.\setup-z-drive-mapping.ps1

# Step 4: Reduce VM RAM (admin required)
.\reduce-vm-ram.ps1

# Step 5: Commit to GitHub
.\commit-to-github.ps1
```

**Expected Duration:** 15-20 minutes

---

## 📋 Prerequisites

Before starting, make sure:

- ✓ PowerShell 5.0 or newer
- ✓ Git is installed and configured
- ✓ BabyNAS Hyper-V VM (should be running)
- ✓ Network connectivity to 172.21.203.18
- ✓ Administrator privileges (for some scripts)
- ✓ SSH key in `$env:USERPROFILE\.ssh\id_ed25519` (for API key generation)

### Check Prerequisites
```powershell
# Verify PowerShell version
$PSVersionTable.PSVersion

# Verify Git
git --version

# Verify SSH key
Test-Path "$env:USERPROFILE\.ssh\id_ed25519"
```

---

## 🎯 Step-by-Step: Full Automated Setup

### Step 1: Open PowerShell
```powershell
# On Windows 10/11:
# Click Start → PowerShell (normal user, not admin yet)
cd D:\workspace\Baby_Nas
```

### Step 2: Run Master Setup
```powershell
# First time? Try this to see what will happen:
.\MASTER-SETUP.ps1 -Interactive

# Or for full automation:
.\MASTER-SETUP.ps1

# To test without making changes:
.\MASTER-SETUP.ps1 -DryRun
```

### Step 3: The Setup Will:

1. **Check Prerequisites**
   - Verify PowerShell, Git, Hyper-V
   - Shows any missing dependencies

2. **Run Diagnostics** (Optional)
   - Tests ping to 172.21.203.18
   - Checks SSH port 22
   - Tests Web UI port 443
   - Auto-fixes common issues

3. **Generate API Key**
   - Connects via SSH
   - Creates API key on TrueNAS
   - Automatically updates `.env` file
   - (Falls back to manual method if SSH fails)

4. **Setup Z: Drive**
   - Maps BabyNAS dataset as Z: drive
   - Makes it persistent across reboots
   - Tests access immediately

5. **Reduce VM RAM** (Requires Admin)
   - Shuts down VM if running
   - Reduces memory to 8192 MB
   - Restarts VM

6. **Verify Configuration**
   - Checks all config files exist
   - Validates API key is set
   - Confirms domain names configured

7. **Commit to GitHub**
   - Shows files being committed
   - Protects `.env` files (never committed)
   - Optionally pushes to GitHub

8. **Final Verification**
   - Tests connectivity again
   - Confirms Z: drive access
   - Shows completion summary

### Step 4: View Results
```powershell
# Check the log file for details
Get-Content "C:\Logs\MASTER-SETUP-*.log" | Out-Host

# Verify configuration
cat .\CONFIGURATION_GUIDE.md
```

---

## 📊 What Gets Set Up

### Configuration Files
| File | Purpose | Status |
|------|---------|--------|
| `.env` | Main configuration | ✓ Updated with correct IP |
| `.env.local` | Local machine-specific | ✓ Created |
| `.env.staging` | Testing environment | ✓ Created |
| `.env.production` | Production environment | ✓ Created |
| `monitoring-config.json` | Monitoring thresholds | ✓ Updated |

### Network Configuration
| Setting | Value | Purpose |
|---------|-------|---------|
| Baby NAS IP | 172.21.203.18 | Hyper-V VM address |
| Baby NAS Hostname | babynas.isndotbiz.com | Domain name (public) |
| Main NAS IP | 10.0.0.89 | Replication target |
| Web UI URL | https://172.21.203.18 | TrueNAS dashboard |

### Scripts Created
| Script | Purpose |
|--------|---------|
| `diagnose-baby-nas.ps1` | Comprehensive connectivity testing |
| `create-api-key-ssh.ps1` | Auto-generate TrueNAS API key |
| `setup-z-drive-mapping.ps1` | Mount dataset as Z: drive |
| `reduce-vm-ram.ps1` | Optimize VM memory |
| `commit-to-github.ps1` | Safe GitHub sync |
| `setup-wizard.ps1` | Interactive setup guide |
| `MASTER-SETUP.ps1` | Automated end-to-end setup |

---

## 🔍 Troubleshooting

### Issue: "VM Not Running"
```powershell
# Start the VM manually
Start-VM -Name "Baby-NAS"

# Then run diagnostics
.\diagnose-baby-nas.ps1
```

### Issue: "Cannot Ping 172.21.203.18"
```powershell
# Check Hyper-V VM exists
Get-VM | Where-Object {$_.Name -like '*baby*'} | Format-Table

# Verify network connectivity
Test-Connection -ComputerName 172.21.203.18 -Count 3 -Verbose
```

### Issue: "SSH Connection Failed"
```powershell
# Check SSH key exists
Test-Path "$env:USERPROFILE\.ssh\id_ed25519"

# Try manual SSH test
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.21.203.18 "echo 'Test'"

# Check if you need to add key to authorized_keys
# (may need to do this from web UI or console first)
```

### Issue: "API Key Generation Failed"
- Method 1: Run script again with more verbose output
  ```powershell
  .\create-api-key-ssh.ps1 -Verbose
  ```
- Method 2: Generate manually via web UI
  1. Open: https://172.21.203.18
  2. Login with root credentials
  3. System → API Keys → Add
  4. Copy the key
  5. Edit `.env` and paste it

### Issue: "Z: Drive Mapping Failed"
```powershell
# Try manual mapping with correct credentials
$cred = Get-Credential
New-PSDrive -Name Z -PSProvider FileSystem `
  -Root "\\172.21.203.18\backups" -Credential $cred -Scope Global
```

### Issue: "Administrator Required"
- Reduce VM RAM and other admin tasks need elevated privileges
- Right-click PowerShell → Run as Administrator
- Then navigate to directory and run script again

---

## ✅ Verification Checklist

After setup completes, verify everything:

```powershell
# 1. Check configuration files exist
Test-Path D:\workspace\Baby_Nas\.env
Test-Path D:\workspace\Baby_Nas\.env.local
Test-Path D:\workspace\Baby_Nas\monitoring-config.json

# 2. Verify API key is configured
Select-String -Path D:\workspace\Baby_Nas\.env "TRUENAS_API_KEY"

# 3. Test connectivity
Test-Connection -ComputerName 172.21.203.18 -Count 2

# 4. Check Z: drive
Get-ChildItem Z:\ -ErrorAction SilentlyContinue

# 5. Check VM memory
Get-VM "Baby-NAS" | Select Name, @{N="RAM (GB)"; E={[int]($_.MemoryAssigned/1GB)}}

# 6. Check git status
git status

# 7. Check logs
Get-Content C:\Logs\MASTER-SETUP-*.log | Tail -20
```

---

## 🎓 Learning Resources

Understand what's happening:

1. **Configuration Guide**
   ```powershell
   cat .\CONFIGURATION_GUIDE.md
   ```

2. **Setup Documentation**
   ```powershell
   cat .\NEXT-STEPS.md
   ```

3. **Project Architecture**
   ```powershell
   cat .\CLAUDE.md
   ```

4. **Individual Script Help**
   ```powershell
   # Scripts have detailed help comments
   Get-Content .\MASTER-SETUP.ps1 -TotalCount 30
   ```

---

## 🚀 After Setup Complete

### Run These Checks
```powershell
# 1. Quick connectivity verification
.\quick-connectivity-check.ps1

# 2. Full system diagnostics
.\CHECK-SYSTEM-STATE.ps1

# 3. Backup verification
.\backup-verification.ps1
```

### Deploy Backup Automation
```powershell
# Deploy all backup systems (Veeam, Phone, Time Machine)
.\AUTOMATED-BACKUP-SETUP.ps1

# Or setup individual systems:
.\DEPLOY-VEEAM-COMPLETE.ps1
.\DEPLOY-PHONE-BACKUPS-WINDOWS.ps1
```

### Monitor in Real-Time
```powershell
# Live 30-second refresh dashboard
.\monitor-baby-nas.ps1

# Or web dashboard
.\BACKUP-MONITORING-DASHBOARD.ps1
# Then open: http://localhost:8888
```

---

## 📞 Need Help?

### Common Commands
```powershell
# View recent logs
Get-ChildItem C:\Logs\ -Filter "*.log" | Sort LastWriteTime -Desc | Select -First 5

# Test specific connectivity
Test-NetConnection -ComputerName 172.21.203.18 -Port 22 -InformationLevel Detailed
Test-NetConnection -ComputerName 172.21.203.18 -Port 443 -InformationLevel Detailed

# Check system resources
Get-VM "Baby-NAS" | Format-Table Name, State, MemoryAssigned, ProcessorCount

# Verify shares
net view \\172.21.203.18 /all

# Check git remote
git remote -v
```

### Documentation
- See `CONFIGURATION_GUIDE.md` for all configuration details
- See `NEXT-STEPS.md` for detailed next steps after setup
- See `CLAUDE.md` for architecture and design overview

---

## 💡 Pro Tips

1. **Run in Screen Session** (for long-running operations)
   ```powershell
   # If using Windows Terminal, you can spawn in new tab
   # Or save session for later review
   ```

2. **Save Logs for Support**
   ```powershell
   # Keep the MASTER-SETUP log for troubleshooting
   Get-Content C:\Logs\MASTER-SETUP-*.log > support_logs.txt
   ```

3. **Rerun Specific Steps**
   ```powershell
   # Run just diagnostics
   .\diagnose-baby-nas.ps1 -Fix

   # Run just API key generation
   .\create-api-key-ssh.ps1

   # Run just GitHub commit
   .\commit-to-github.ps1 -Push
   ```

4. **Dry Run First** (for safety)
   ```powershell
   # See what would happen without making changes
   .\MASTER-SETUP.ps1 -DryRun
   ```

5. **Verbose Output** (for debugging)
   ```powershell
   .\MASTER-SETUP.ps1 -Verbose
   ```

---

## 📝 Summary

You now have complete automation for BabyNAS setup! Choose your preferred method:

- **Fully Automated:** `.\MASTER-SETUP.ps1`
- **Interactive:** `.\setup-wizard.ps1`
- **Manual:** Run individual scripts

All scripts protect sensitive files and never commit credentials to GitHub.

Happy backing up! 🎉
