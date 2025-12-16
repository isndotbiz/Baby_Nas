# Baby NAS Headless Startup

Automatically start the TrueNAS-BabyNAS Hyper-V VM in headless mode (no console window) at system boot.

## Overview

These scripts provide three levels of control:

1. **Quick Start Menu** - Interactive menu for all operations
2. **Headless Startup** - Start VM in background without console window
3. **Task Scheduler Setup** - Auto-start VM at system boot

## Quick Start (Recommended)

### First Time Setup

Run this in PowerShell as Administrator:

```powershell
cd D:\workspace\Baby_Nas
.\quick-start-headless.ps1
```

This opens an interactive menu. Choose option **3** to:
- Start the VM immediately (headless)
- Setup auto-start on next boot

### After Setup

The VM will automatically start whenever you reboot Windows. No action needed!

## Commands Reference

### Start VM Now (Headless)

```powershell
.\start-baby-nas-headless.ps1
```

**What it does:**
- Checks if VM is already running
- Starts it if not
- Waits for network connectivity (default: 60 seconds)
- Returns exit code for automation

**Options:**
```powershell
# Don't wait for network (fire and forget)
.\start-baby-nas-headless.ps1 -NoWait

# Wait up to 2 minutes for network
.\start-baby-nas-headless.ps1 -MaxWaitSeconds 120

# Skip logging to file
.\start-baby-nas-headless.ps1 -NoLog
```

**Logs:**
- Location: `C:\Logs\start-baby-nas-headless-YYYY-MM-DD_HH-MM-SS.log`
- Contains: Startup progress, network status, errors

### Setup Auto-Start

```powershell
.\setup-baby-nas-auto-start.ps1
```

**What it does:**
- Creates a Windows Task Scheduler job
- Triggers at system startup
- Runs with SYSTEM privileges (highest level)
- VM starts automatically, in background

**Options:**
```powershell
# View existing task configuration
.\setup-baby-nas-auto-start.ps1 -Action View

# Remove the scheduled task
.\setup-baby-nas-auto-start.ps1 -Action Remove

# Create task but leave it disabled
.\setup-baby-nas-auto-start.ps1 -Disable
```

**Task Details:**
- Task name: `Start Baby NAS VM (Headless)`
- Trigger: System startup (before user logon)
- Runs as: NT AUTHORITY\SYSTEM
- Action: Starts `start-baby-nas-headless.ps1`

### Interactive Menu

```powershell
.\quick-start-headless.ps1
```

**Menu Options:**
1. Start VM now (headless)
2. Setup auto-start on boot
3. **Start + Setup auto-start** (recommended)
4. Check VM status
5. Open VM console (interactive window)
6. Disable auto-start
0. Exit

## How It Works

### Architecture

```
┌─────────────────────────────────────────┐
│ Windows System Boot                     │
└────────────┬────────────────────────────┘
             │
             ↓ (Task Scheduler trigger)
┌─────────────────────────────────────────┐
│ Windows Task Scheduler                  │
│ Task: "Start Baby NAS VM (Headless)"    │
│ User: SYSTEM (highest privileges)       │
│ Trigger: At startup                     │
└────────────┬────────────────────────────┘
             │
             ↓ (Execute)
┌─────────────────────────────────────────┐
│ start-baby-nas-headless.ps1             │
│ ✓ Check if TrueNAS-BabyNAS is running   │
│ ✓ Start VM if needed                    │
│ ✓ Wait for network (172.21.203.18)      │
│ ✓ Log progress to C:\Logs\              │
└────────────┬────────────────────────────┘
             │
             ↓ (After ~60 seconds)
┌─────────────────────────────────────────┐
│ Hyper-V VM Running (Headless)           │
│ TrueNAS-BabyNAS Online                  │
│ Ready for backups and monitoring        │
└─────────────────────────────────────────┘
```

### Execution Flow

```
1. System boots
   ↓
2. Task Scheduler detects startup trigger
   ↓
3. Runs: powershell.exe -File start-baby-nas-headless.ps1 -NoWait
   ↓
4. Check: Get-VM -Name "TrueNAS-BabyNAS"
   ↓
5. If Running → Already online, exit
   If Stopped → Start-VM "TrueNAS-BabyNAS"
   ↓
6. Wait for network: Test-Connection -ComputerName 172.21.203.18
   ↓
7. Log results to C:\Logs\start-baby-nas-headless-*.log
   ↓
8. Exit (script completes in ~60-90 seconds)
```

## Features

### ✓ Headless Mode
- No console window
- No user interaction required
- Runs in background during system startup

### ✓ Network Awareness
- Waits for VM to get IP address
- Tests connectivity to 172.21.203.18
- Retries every 3 seconds (configurable timeout)

### ✓ Error Handling
- Validates Administrator privileges
- Checks if VM exists before starting
- Logs all operations with timestamps
- Returns meaningful exit codes

### ✓ Flexible Scheduling
- Auto-start at system boot
- Auto-start at user logon (optional)
- Manual start whenever needed
- Can be disabled easily

### ✓ Comprehensive Logging
- Location: `C:\Logs\`
- Format: Text files with timestamps
- Contains: Progress, network status, errors

## Status and Monitoring

### Check Current VM Status

```powershell
Get-VM -Name "TrueNAS-BabyNAS" | Select-Object Name, State, Uptime
```

### Check Scheduled Task

```powershell
Get-ScheduledTask -TaskName "Start Baby NAS VM (Headless)" | Select-Object TaskName, State
```

### View Last Startup Log

```powershell
Get-ChildItem -Path "C:\Logs\" -Filter "start-baby-nas-headless*.log" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1 |
  Get-Content
```

### Monitor Auto-Start Task

```powershell
# View task details
.\setup-baby-nas-auto-start.ps1 -Action View

# View Task Scheduler GUI
taskmgr.exe
# Then: Task Scheduler → Task Scheduler Library → Find "Start Baby NAS VM (Headless)"
```

## Troubleshooting

### "VM is OFFLINE or unreachable"

**Possible causes:**
1. Hyper-V hasn't fully initialized the VM yet
2. Network configuration issue
3. VM is starting but not booted yet

**Solutions:**
```powershell
# Check VM state manually
Get-VM -Name "TrueNAS-BabyNAS"

# Try opening console to see boot status
.\open-vm-console.ps1

# Check last startup log
Get-Content "C:\Logs\start-baby-nas-headless*.log" -Tail 20

# Manually test network connectivity
ping 172.21.203.18
```

### "Permission denied" or "Access denied"

**Cause:** Script requires Administrator privileges

**Solution:**
1. Right-click PowerShell → "Run as Administrator"
2. Run the script again

### Task doesn't auto-start on system boot

**Possible causes:**
1. Task is disabled
2. Trigger not configured correctly
3. Script path has changed

**Solutions:**
```powershell
# Check if task is enabled
Get-ScheduledTask -TaskName "Start Baby NAS VM (Headless)" |
  Select-Object TaskName, State

# If disabled, enable it
Enable-ScheduledTask -TaskName "Start Baby NAS VM (Headless)"

# Recreate the task (fixes path issues)
.\setup-baby-nas-auto-start.ps1 -Action Remove
.\setup-baby-nas-auto-start.ps1 -Action Setup
```

### Script takes too long to run

The script waits up to 120 seconds for network connectivity by default. To skip waiting:

```powershell
.\start-baby-nas-headless.ps1 -NoWait
```

## Integration with Other Scripts

### With Backup Scripts

Once Baby NAS is running, these backup scripts can run:

```powershell
# These will work automatically if Baby NAS is online
.\backup-workspace.ps1
.\wsl-backup.ps1
.\VERIFY-ALL-BACKUPS.ps1
```

### With Monitoring

The monitoring dashboard will detect the running VM:

```powershell
.\monitor-baby-nas.ps1  # Real-time dashboard
```

### With Tests

Run tests after auto-start has completed:

```powershell
.\test-baby-nas-complete.ps1  # 7-part test suite
```

## Advanced Configuration

### Change Auto-Start Trigger

To trigger at **user logon** instead of system boot:

```powershell
# Remove old task
.\setup-baby-nas-auto-start.ps1 -Action Remove

# Create new task with logon trigger
$scriptPath = "D:\workspace\Baby_Nas\start-baby-nas-headless.ps1"
$action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
Register-ScheduledTask -TaskName "Start Baby NAS VM (Headless)" -InputObject $task -Force
```

### Use Custom IP Address

If Baby NAS has a different IP:

```powershell
.\start-baby-nas-headless.ps1 -ExpectedIP "192.168.1.100"
```

### Increase Network Wait Timeout

Wait up to 5 minutes for network connectivity:

```powershell
.\start-baby-nas-headless.ps1 -MaxWaitSeconds 300
```

### Run Without Logging

Skip file logging (logs still go to console):

```powershell
.\start-baby-nas-headless.ps1 -NoLog
```

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | VM is running and accessible |
| 1 | Permission error | Run as Administrator |
| 2 | VM not found | Check VM name: `Get-VM` |
| 3 | Start failed | Check Hyper-V status |

## Files Included

- **quick-start-headless.ps1** - Interactive menu (start here!)
- **start-baby-nas-headless.ps1** - Headless startup script
- **setup-baby-nas-auto-start.ps1** - Task Scheduler configuration
- **README-HEADLESS-STARTUP.md** - This file

## Examples

### Example 1: Quick Setup and Test

```powershell
# Run interactive menu
.\quick-start-headless.ps1

# Choose option 3 (Start + Setup auto-start)
# VM starts, auto-start is enabled
# Done! VM will restart automatically on reboot
```

### Example 2: Scheduled Backup After VM Start

Create a backup script that waits for Baby NAS:

```powershell
# backup-after-startup.ps1
# Wait for Baby NAS to be online
Write-Host "Waiting for Baby NAS..."
$maxRetries = 12  # 60 seconds with 5-sec intervals
$retry = 0
while ($retry -lt $maxRetries) {
    if (Test-Connection -ComputerName 172.21.203.18 -Quiet) {
        Write-Host "✓ Baby NAS is online!"
        break
    }
    $retry++
    Start-Sleep -Seconds 5
}

# Now run backups
.\backup-workspace.ps1
.\wsl-backup.ps1
```

Schedule this as a Windows Task:
```
Trigger: At startup, delay 2 minutes
Run: C:\Users\Jdmal\Documents\backup-after-startup.ps1
User: Your account (not SYSTEM)
```

### Example 3: Manual Start with Status Check

```powershell
# Start Baby NAS and watch the logs
.\start-baby-nas-headless.ps1
Write-Host "Checking logs..."
Get-ChildItem "C:\Logs\start-baby-nas-headless*.log" -Newest 1 | Get-Content -Tail 5
```

## Best Practices

1. **Run quick-start-headless.ps1 for setup** - It handles everything
2. **Check logs after first boot** - Verify network connectivity
3. **Test manual start before relying on auto-start** - Catch issues early
4. **Use -Action View to monitor the task** - See when it last ran
5. **Keep log files for troubleshooting** - They're in `C:\Logs\`

## Support and Logs

**Logs Location:** `C:\Logs\`

**Log Files:**
- `start-baby-nas-headless-YYYY-MM-DD_HH-MM-SS.log` - Startup operations
- `start-baby-nas-headless-YYYY-MM-DD_HH-MM-SS.log` - Each startup creates a new log

**Viewing Logs:**
```powershell
# View latest log
Get-ChildItem C:\Logs\start-baby-nas-headless*.log -Newest 1 | Get-Content

# Follow log in real-time (while starting)
Get-Content "C:\Logs\start-baby-nas-headless-*.log" -Wait -Tail 10
```

## Version Information

- **Created:** December 2025
- **Status:** Production Ready
- **Tested on:** Windows 10/11 with Hyper-V
- **Requirements:** Administrator privileges, Hyper-V feature enabled

---

**Need help?** See the TROUBLESHOOTING section above or check logs in `C:\Logs\`
