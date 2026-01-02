# Next Steps - BabyNAS Setup and Configuration

## Current Status

✅ **Completed:**
- Configuration files created (.env, .env.local, .env.staging, .env.production)
- Domain name setup (babynas.isndotbiz.com)
- Monitoring config updated with domain support
- New automation scripts created
- .gitignore updated for security

⏳ **In Progress:**
- BabyNAS connectivity troubleshooting
- TrueNAS API key generation
- Z: drive mapping setup
- VM RAM reduction to 8192 MB
- GitHub commit and sync

## New Scripts Created

### 1. create-api-key-ssh.ps1
**Purpose:** Generate TrueNAS API key using SSH connection

```powershell
# Usage:
.\create-api-key-ssh.ps1

# Or with custom parameters:
.\create-api-key-ssh.ps1 -BabyNasIP "172.21.203.18" -ApiKeyName "Baby-Nas-Automation"
```

**What it does:**
- Tests SSH connectivity to BabyNAS
- Creates API key directly via SSH (no manual web UI needed)
- Returns the API key to paste in .env file
- Falls back to manual web UI instructions if SSH fails

**Output:**
```
✓ SSH connection successful
✓ API key created successfully!
API Key: <64-character-hex-string>
```

### 2. setup-z-drive-mapping.ps1
**Purpose:** Mount BabyNAS datasets as Z: drive on Windows

```powershell
# Usage:
.\setup-z-drive-mapping.ps1

# Or with specific dataset:
.\setup-z-drive-mapping.ps1 -DatasetShareName "backups"

# Persistent mapping (survives reboot):
.\setup-z-drive-mapping.ps1 -Persistent $true
```

**What it does:**
- Maps SMB share from BabyNAS to Z: drive
- Makes mapping persistent across reboots
- Tests access and shows directory listing
- Provides removal instructions if needed

**After Setup:**
```
Z:\ drive is now accessible from Windows Explorer or PowerShell
- Access files directly: Z:\file.txt
- List contents: dir Z:\
- Remove later: net use Z: /delete
```

### 3. reduce-vm-ram.ps1
**Purpose:** Reduce BabyNAS VM memory allocation to 8192 MB

```powershell
# Requires Administrator privileges!
# Usage:
.\reduce-vm-ram.ps1

# With auto-shutdown:
.\reduce-vm-ram.ps1 -Force
```

**What it does:**
- Finds the BabyNAS Hyper-V VM
- Safely shuts down VM if running
- Reduces RAM allocation from current to 8192 MB
- Verifies the change

**Requirements:**
- Must run PowerShell as Administrator
- VM must be stopped before RAM change

### 4. commit-to-github.ps1
**Purpose:** Safely commit changes to GitHub (protects sensitive files)

```powershell
# Usage:
.\commit-to-github.ps1

# With auto-push to GitHub:
.\commit-to-github.ps1 -Push

# Custom commit message:
.\commit-to-github.ps1 -CommitMessage "Update BabyNAS configuration and scripts"
```

**What it does:**
- Shows git status before committing
- Stages only safe files (scripts, docs, templates)
- **Protects** .env files (never commits credentials)
- Creates commit with descriptive message
- Optionally pushes to GitHub

**Protected Files (NOT committed):**
- .env (production)
- .env.local (machine-specific)
- .env.staging (staging)
- .env.production (production)
- C:\Logs\ (runtime logs)
- agent-logs/ (execution output)

## Step-by-Step Instructions

### Phase 1: Troubleshooting BabyNAS Connectivity

Run this PowerShell command to diagnose connectivity:

```powershell
Write-Host "=== BabyNAS Troubleshooting ===" -ForegroundColor Cyan
Write-Host ""

# Check VM Status
Write-Host "1. Checking Hyper-V VM Status..." -ForegroundColor Yellow
Get-VM | Where-Object {$_.Name -like '*baby*' -or $_.Name -like '*truenas*'} |
  Select-Object Name, State, @{N="RAM (MB)";E={[int]($_.MemoryAssigned/1MB)}} | Format-Table

# Check Network Connectivity
Write-Host "2. Testing network connectivity..." -ForegroundColor Yellow
Test-Connection -ComputerName 172.21.203.18 -Count 2

# Check SSH (port 22)
Write-Host "3. Checking SSH port..." -ForegroundColor Yellow
Test-NetConnection -ComputerName 172.21.203.18 -Port 22 -InformationLevel Detailed

# Check Web UI (port 443)
Write-Host "4. Checking Web UI port..." -ForegroundColor Yellow
Test-NetConnection -ComputerName 172.21.203.18 -Port 443 -InformationLevel Detailed
```

**Expected Results:**
```
Name                 State        RAM (MB)
----                 -----        --------
Baby-NAS or similar  Running      16384 (or current)

Ping: Reply from 172.21.203.18 bytes=32...
SSH: TcpTestSucceeded: True
Web UI: TcpTestSucceeded: True
```

**If connectivity fails:**
1. Check Hyper-V VM is running: `Start-VM -Name "Baby-NAS"`
2. Verify correct network switch is assigned
3. Check firewall rules allow ping/SSH/HTTPS
4. Try direct access: `ping -a 172.21.203.18`

### Phase 2: Create API Key

Once connectivity confirmed:

```powershell
# Option A: Automatic via SSH (recommended)
.\create-api-key-ssh.ps1

# Option B: Manual via Web UI
# 1. Open https://172.21.203.18
# 2. Login with root credentials from .env
# 3. System → API Keys → Add
# 4. Copy the key and paste in .env file
```

### Phase 3: Setup Z: Drive Mapping

After confirming network connectivity:

```powershell
# Create the mapping
.\setup-z-drive-mapping.ps1

# When prompted, enter BabyNAS root password from .env file

# Verify it works:
dir Z:\
```

### Phase 4: Reduce VM RAM to 8192 MB

```powershell
# IMPORTANT: Run PowerShell as Administrator

# Reduce RAM
.\reduce-vm-ram.ps1

# When prompted, confirm shutdown
# When complete, start the VM again:
Start-VM -Name "Baby-NAS"
```

### Phase 5: Commit to GitHub

```powershell
# Preview what will be committed:
git status

# Run the commit script:
.\commit-to-github.ps1

# When prompted, type "yes" to confirm
# When asked about push, type "yes" to upload to GitHub
```

## Configuration Files Reference

### .env (Production)
Primary configuration file with all credentials and settings.

**Key values already set:**
- `TRUENAS_IP=172.21.203.18` ✓
- `TRUENAS_USERNAME=root` ✓
- `TRUENAS_PASSWORD=***` ✓
- `TRUENAS_API_KEY=` ← **TODO: Add after generation**
- `BABY_NAS_HOSTNAME=babynas.isndotbiz.com` ✓

### .env.local (Machine-Specific)
For local/machine-specific overrides and secrets.

**Contains:**
- RAG system credentials
- SSH key paths
- Local backup staging paths

### .env.staging (Testing)
Non-production testing environment with shorter retention.

### .env.production (Production)
Explicit production settings with full retention policies.

## Domain Configuration

**Your Setup:**
- Domain: `isndotbiz.com`
- BabyNAS hostname: `babynas.isndotbiz.com` (points to 172.21.203.18)
- VPN endpoint: `vpn.isndotbiz.com`

**Config Updated:**
```json
{
  "BABY_NAS_HOSTNAME": "babynas.isndotbiz.com",
  "BABY_NAS_PUBLIC_ENDPOINT": "babynas.isndotbiz.com",
  "babyNAS.hostname": "babynas.isndotbiz.com"
}
```

## Troubleshooting Common Issues

### SSH Connection Fails
**Problem:** Script can't connect via SSH

**Solution:**
1. Check SSH key exists: `Test-Path $env:USERPROFILE\.ssh\id_ed25519`
2. Add SSH public key to BabyNAS: `ssh root@172.21.203.18 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" < your_key.pub`
3. Try manual SSH: `ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@172.21.203.18`

### API Key Generation Fails
**Problem:** Cannot create API key via SSH

**Solution:**
1. Use manual web UI method (link provided in script output)
2. Or use TrueNAS REST API directly with password authentication
3. API key should be 64+ character hex string

### Z: Drive Mapping Fails
**Problem:** Cannot access Z: drive after mapping

**Solution:**
1. Check credentials are correct: Username=`root`, Password from .env
2. Verify SMB/CIFS is enabled on BabyNAS
3. Check share exists: System → Shares → Windows Share (SMB)
4. Try manual mapping: `net use Z: \\172.21.203.18\backups /user:root password`

### RAM Reduction Fails
**Problem:** "Requires administrator" error

**Solution:**
1. Right-click PowerShell → Run as Administrator
2. Then run: `.\reduce-vm-ram.ps1 -Force`

## Performance Notes

**After RAM Reduction (8192 MB):**
- BabyNAS VM will use less host memory
- May impact performance with large backups
- Can still handle 100+ GB datasets
- Suitable for testing and non-critical use

**Revert if needed:**
```powershell
# Increase back to 16 GB
Set-VMMemory -VMName "Baby-NAS" -StartupBytes (16*1024*1024*1024)
```

## Next: Running Automation

Once everything is set up:

```powershell
# Test connectivity:
.\quick-connectivity-check.ps1

# Full system check:
.\CHECK-SYSTEM-STATE.ps1

# Run automated backup setup:
.\FULL-AUTOMATION.ps1

# Monitor in real-time:
.\monitor-baby-nas.ps1
```

## Questions or Issues?

Check these resources:
1. CONFIGURATION_GUIDE.md - Configuration details
2. CLAUDE.md - Project architecture
3. Logs in C:\Logs\ - PowerShell script logs
4. TrueNAS Web UI → System → Logs → Services

---

**Created:** 2025-01-01
**Updated Scripts:** create-api-key-ssh.ps1, setup-z-drive-mapping.ps1, reduce-vm-ram.ps1, commit-to-github.ps1
