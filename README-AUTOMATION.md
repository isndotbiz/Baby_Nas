# BabyNAS Automation Suite - Complete Implementation

**Status:** ✅ All automation scripts created, tested, and committed to GitHub

---

## 📦 What Was Created

### 7 New PowerShell Automation Scripts

| Script | Purpose | Duration | Difficulty |
|--------|---------|----------|------------|
| **MASTER-SETUP.ps1** | Complete end-to-end automation | 5-10 min | ⭐ Easy |
| **setup-wizard.ps1** | Interactive step-by-step guide | 10-15 min | ⭐ Easy |
| **diagnose-baby-nas.ps1** | Connectivity testing & troubleshooting | 1-2 min | ⭐⭐ Medium |
| **create-api-key-ssh.ps1** | Auto-generate TrueNAS API key | 30 sec | ⭐⭐ Medium |
| **setup-z-drive-mapping.ps1** | Mount BabyNAS as Z: drive | 1 min | ⭐ Easy |
| **reduce-vm-ram.ps1** | Optimize VM memory | 1 min | ⭐⭐ Medium |
| **commit-to-github.ps1** | Safe GitHub sync | 2-3 min | ⭐ Easy |

### 3 New Documentation Files

- **SETUP-QUICKSTART.md** - Quick start guide with 3 setup options
- **CONFIGURATION_GUIDE.md** - Complete configuration reference
- **NEXT-STEPS.md** - Detailed execution steps and troubleshooting

### 5 Configuration Files (Updated/Created)

- **.env** - Fixed IP to 172.21.203.18, added domain names ✓
- **.env.local** - Fixed formatting, RAG system credentials ✓
- **.env.staging** - Testing environment config ✓
- **.env.production** - Production settings ✓
- **monitoring-config.json** - Updated with correct IP ✓

---

## 🎯 How to Use

### The 3-Tier Approach

#### 🟢 **Tier 1: Full Automation (Recommended)**
```powershell
.\MASTER-SETUP.ps1
```
**What it does:**
- Runs all steps automatically
- Tests each stage
- Creates detailed logs
- Handles all setup in one go

**Best for:** Most users who want everything done

---

#### 🟡 **Tier 2: Interactive Wizard**
```powershell
.\setup-wizard.ps1
```
**What it does:**
- Step-by-step guided experience
- Prompts for choices at each step
- Allows verification between steps
- Can skip or repeat individual steps

**Best for:** First-time users, learning process

---

#### 🔵 **Tier 3: Individual Scripts**
```powershell
# Run in order:
.\diagnose-baby-nas.ps1
.\create-api-key-ssh.ps1
.\setup-z-drive-mapping.ps1
.\reduce-vm-ram.ps1
.\commit-to-github.ps1
```

**What it does:**
- Complete control over each step
- Can run parts individually
- Easy to troubleshoot specific components

**Best for:** Power users, troubleshooting, selective setup

---

## 🚀 Quick Start (2 Minutes)

### For the Impatient:
```powershell
cd D:\workspace\Baby_Nas
.\MASTER-SETUP.ps1
```

**That's it!** The script will:
1. Test connectivity to BabyNAS (172.21.203.18)
2. Generate API key automatically
3. Map Z: drive
4. Reduce VM RAM to 8192 MB
5. Verify everything works
6. Commit to GitHub
7. Show completion summary

---

## 📋 What Each Script Does

### 1. diagnose-baby-nas.ps1
**Purpose:** Comprehensive connectivity testing

**Tests:**
- ✓ VM is running and responsive
- ✓ Network ping (ICMP)
- ✓ SSH access (port 22)
- ✓ Web UI (port 443)
- ✓ SMB/CIFS (port 445)
- ✓ DNS resolution for domain names

**Usage:**
```powershell
# Standard diagnostics
.\diagnose-baby-nas.ps1

# With auto-fix for common issues
.\diagnose-baby-nas.ps1 -Fix

# Verbose output for debugging
.\diagnose-baby-nas.ps1 -Verbose

# Skip detailed checks
.\diagnose-baby-nas.ps1 -SkipDiagnostics
```

**Output:**
```
=== HYPER-V VM STATUS ===
  ✓ VM Found: Baby-NAS
  ✓ State: Running
  ✓ Memory: 16384 MB

=== NETWORK CONNECTIVITY ===
  ✓ Ping successful (average: 2ms)
  ✓ Port 22 (SSH) - OPEN
  ✓ Port 443 (HTTPS) - OPEN
  ✓ Port 445 (SMB) - OPEN

[... more detailed results ...]
```

---

### 2. create-api-key-ssh.ps1
**Purpose:** Generate TrueNAS API key and auto-update .env

**Features:**
- ✓ Automatic SSH connection
- ✓ Creates API key on TrueNAS
- ✓ Automatically updates .env file
- ✓ Falls back to manual method if SSH fails

**Usage:**
```powershell
# Automatic with .env update
.\create-api-key-ssh.ps1

# Manual specification of parameters
.\create-api-key-ssh.ps1 -BabyNasIP "172.21.203.18" `
  -ApiKeyName "Baby-Nas-Automation"

# Disable auto-update if .env is read-only
.\create-api-key-ssh.ps1 -AutoUpdate $false
```

**Output:**
```
=== TrueNAS API Key Generation via SSH ===

1. Testing SSH connectivity to 172.21.203.18...
   ✓ SSH connection successful

2. Creating API key 'Baby-Nas-Automation'...
   ✓ API key created

3. Updating .env file...
   ✓ .env file updated with API key!
```

---

### 3. setup-z-drive-mapping.ps1
**Purpose:** Mount BabyNAS dataset as Windows Z: drive

**Features:**
- ✓ Maps network drive with credentials
- ✓ Makes mapping persistent (survives reboot)
- ✓ Tests access immediately
- ✓ Shows directory listing

**Usage:**
```powershell
# Standard setup with prompts
.\setup-z-drive-mapping.ps1

# Specify dataset name
.\setup-z-drive-mapping.ps1 -DatasetShareName "backups"

# Persistent mapping
.\setup-z-drive-mapping.ps1 -Persistent $true

# Remove mapping later
net use Z: /delete
```

**Verification:**
```powershell
# Access the mapped drive
dir Z:\
Get-ChildItem Z:\
# Should show contents of the BabyNAS dataset
```

---

### 4. reduce-vm-ram.ps1
**Purpose:** Optimize VM memory to 8192 MB

**Features:**
- ✓ Requires administrator privileges
- ✓ Safely shuts down VM if running
- ✓ Reduces RAM allocation
- ✓ Verifies the change

**Usage:**
```powershell
# ⚠️ Run as Administrator first!
# Right-click PowerShell → Run as Administrator

# Standard reduction to 8192 MB
.\reduce-vm-ram.ps1

# Custom memory amount
.\reduce-vm-ram.ps1 -NewMemoryMB 12288

# Force shutdown without prompting
.\reduce-vm-ram.ps1 -Force
```

**Verification:**
```powershell
Get-VM "Baby-NAS" | Select-Object Name, @{N="RAM (MB)";E={[int]($_.MemoryAssigned/1MB)}}
# Should show: 8192 MB
```

---

### 5. commit-to-github.ps1
**Purpose:** Safely commit changes to GitHub (protects .env files)

**Features:**
- ✓ Shows what will be committed
- ✓ Protects .env files (never commits)
- ✓ Protects logs and sensitive data
- ✓ Commits safe files (scripts, docs, templates)

**Usage:**
```powershell
# Preview what will be committed
git status

# Standard commit
.\commit-to-github.ps1

# Commit and push to GitHub
.\commit-to-github.ps1 -Push

# Custom commit message
.\commit-to-github.ps1 -CommitMessage "Add new backup features"
```

**Protected Files:**
```
Never committed:
  - .env (production credentials)
  - .env.local (machine-specific)
  - .env.staging (staging credentials)
  - .env.production (production credentials)
  - C:\Logs\ (runtime logs)
  - agent-logs/ (execution output)
```

---

### 6. setup-wizard.ps1
**Purpose:** Interactive step-by-step setup guide

**Features:**
- ✓ Menu-driven interface
- ✓ Prerequisites checking
- ✓ Step-by-step verification
- ✓ Choose which components to setup

**Usage:**
```powershell
# Interactive mode
.\setup-wizard.ps1

# Verbose output
.\setup-wizard.ps1 -Verbose

# Skip diagnostics
.\setup-wizard.ps1 -SkipDiagnostics
```

**Flow:**
```
1. Check prerequisites
2. Run diagnostics (optional)
3. Generate API key (choose method)
4. Setup Z: drive (yes/no)
5. Adjust VM memory (choose target)
6. Commit to GitHub (choose action)
7. Final verification
8. Show next steps
```

---

### 7. MASTER-SETUP.ps1
**Purpose:** Complete end-to-end automation (all scripts in sequence)

**Features:**
- ✓ Runs all steps automatically
- ✓ Detailed logging to C:\Logs\
- ✓ Test and verify at each stage
- ✓ Handles errors gracefully
- ✓ Provides comprehensive summary

**Usage:**
```powershell
# Standard execution
.\MASTER-SETUP.ps1

# Interactive mode (confirm before each major step)
.\MASTER-SETUP.ps1 -Interactive

# Test without making changes
.\MASTER-SETUP.ps1 -DryRun

# With verbose debugging
.\MASTER-SETUP.ps1 -Verbose

# Skip diagnostics
.\MASTER-SETUP.ps1 -SkipDiagnostics

# Custom GitHub handling
.\MASTER-SETUP.ps1 -NoGitPush  # Commit but don't push
```

**Flow:**
```
1. System Prerequisites Check
2. BabyNAS Diagnostics & Auto-Fix
3. TrueNAS API Key Generation
4. Z: Drive Mapping Setup
5. VM Memory Optimization
6. Configuration Verification
7. GitHub Commit & Sync
8. Final System Verification
9. Completion Summary
```

**Log Output:**
```
C:\Logs\MASTER-SETUP-20250101-143022.log

Contains:
- Each step executed
- Success/failure status
- Error messages with timestamps
- Performance metrics
- Final summary
```

---

## 🎯 Configuration Changes

### IP Addresses & Domains

```
Before:
  TRUENAS_IP=172.31.69.40  ❌ (Wrong IP)
  BABY_NAS_HOSTNAME=baby.isn.biz

After:
  TRUENAS_IP=172.21.203.18  ✓ (Correct IP)
  BABY_NAS_HOSTNAME=babynas.isndotbiz.com  ✓ (Correct domain)
  BABY_NAS_PUBLIC_ENDPOINT=babynas.isndotbiz.com  ✓ (Public access)
```

### File Corrections

```
.env:
  ✓ Fixed IP address to 172.21.203.18
  ✓ Added domain name configuration
  ✓ Added public endpoints

.env.local:
  ✓ Fixed line breaks (was all on one line)
  ✓ Added comments and structure
  ✓ Added local machine-specific paths

monitoring-config.json:
  ✓ Updated Baby NAS IP to 172.21.203.18
  ✓ Added hostname field
  ✓ Added domain name support
```

---

## ✅ Verification Checklist

After running any setup script, verify:

```powershell
# 1. Check configuration files
Test-Path D:\workspace\Baby_Nas\.env
Test-Path D:\workspace\Baby_Nas\.env.local
Test-Path D:\workspace\Baby_Nas\monitoring-config.json

# 2. Verify connectivity
Test-Connection -ComputerName 172.21.203.18 -Count 2
Test-NetConnection -ComputerName 172.21.203.18 -Port 22
Test-NetConnection -ComputerName 172.21.203.18 -Port 443

# 3. Check API key is configured
(Get-Content D:\workspace\Baby_Nas\.env) -match "TRUENAS_API_KEY=" -and
  -not ((Get-Content D:\workspace\Baby_Nas\.env) -match "TRUENAS_API_KEY=$")

# 4. Check Z: drive
Test-Path Z:\

# 5. Check VM memory
Get-VM "Baby-NAS" | Select Name, @{N="RAM (GB)";E={[int]($_.MemoryAssigned/1GB)}}
# Should show: 8 GB

# 6. Check git status
git status --short
```

---

## 📊 Quick Reference Table

| Task | Script | Command | Time |
|------|--------|---------|------|
| Run everything | MASTER-SETUP.ps1 | `.\MASTER-SETUP.ps1` | 5-10m |
| Interactive setup | setup-wizard.ps1 | `.\setup-wizard.ps1` | 10-15m |
| Test connectivity | diagnose-baby-nas.ps1 | `.\diagnose-baby-nas.ps1` | 1-2m |
| Generate API key | create-api-key-ssh.ps1 | `.\create-api-key-ssh.ps1` | 30s |
| Setup Z: drive | setup-z-drive-mapping.ps1 | `.\setup-z-drive-mapping.ps1` | 1m |
| Reduce VM RAM | reduce-vm-ram.ps1 | `.\reduce-vm-ram.ps1` | 1m |
| Commit to GitHub | commit-to-github.ps1 | `.\commit-to-github.ps1` | 2-3m |

---

## 🔧 Troubleshooting

### VM Not Running
```powershell
Get-VM "Baby-NAS" | Start-VM
# Wait 30 seconds
.\diagnose-baby-nas.ps1
```

### Cannot Connect via SSH
```powershell
# Check SSH key exists
Test-Path "$env:USERPROFILE\.ssh\id_ed25519"

# Try manual connection
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.21.203.18
```

### API Key Generation Failed
```powershell
# Try with more diagnostics
.\create-api-key-ssh.ps1 -Verbose

# Or generate manually via Web UI
# Open: https://172.21.203.18/ui/system/api-keys
```

### Z: Drive Mapping Failed
```powershell
# Check credentials are correct
# Try manual mapping:
net use Z: \\172.21.203.18\backups /user:root password
```

---

## 📚 Documentation Files

All included in repository:

1. **README-AUTOMATION.md** (this file)
   - Overview of automation system
   - How to use each script
   - Verification checklist

2. **SETUP-QUICKSTART.md**
   - Quick start guide
   - 3 setup options
   - Troubleshooting

3. **CONFIGURATION_GUIDE.md**
   - Configuration file reference
   - Security best practices
   - Maintenance procedures

4. **NEXT-STEPS.md**
   - Detailed next steps
   - Script descriptions
   - Performance notes

---

## 🎓 Learning Path

### Beginner
1. Read SETUP-QUICKSTART.md
2. Run `.\MASTER-SETUP.ps1`
3. Follow the prompts

### Intermediate
1. Read CONFIGURATION_GUIDE.md
2. Run `.\setup-wizard.ps1`
3. Make custom choices at each step

### Advanced
1. Read all documentation
2. Run individual scripts
3. Customize parameters for your environment

---

## 📞 Support

### Check Logs
```powershell
Get-Content C:\Logs\MASTER-SETUP-*.log | Tail -50
```

### Run Diagnostics
```powershell
.\diagnose-baby-nas.ps1 -Verbose
```

### Manual Testing
```powershell
# Test each component
Test-Connection -ComputerName 172.21.203.18 -Count 3
Test-NetConnection -ComputerName 172.21.203.18 -Port 22 -Verbose
Test-NetConnection -ComputerName 172.21.203.18 -Port 443 -Verbose
```

---

## ✨ Summary

You now have a complete, production-ready automation system for BabyNAS that:

✅ Automates the entire setup process
✅ Protects sensitive credentials (never commits .env files)
✅ Provides detailed diagnostics and troubleshooting
✅ Works in multiple modes (automatic, interactive, manual)
✅ Creates comprehensive logs for support
✅ Safely syncs to GitHub
✅ Supports all configuration options (IP, domains, hostnames)

**Ready to deploy?** Run: `.\MASTER-SETUP.ps1`

Good luck! 🚀
