# Baby NAS Full Automation Script

## Overview

`FULL-AUTOMATION.ps1` is a comprehensive orchestration script that automates the entire Baby NAS setup process from start to finish. It handles everything from initial connectivity testing through final replication setup.

## What It Does

This script automates the complete Baby NAS deployment pipeline:

1. **Connectivity Testing** - Verifies Baby NAS is reachable via network and SSH
2. **Configuration Deployment** - Uploads and executes the complete configuration script
3. **SSH Key Setup** - Generates and deploys SSH keys for Baby NAS and Main NAS
4. **DNS Configuration** - Configures DNS servers (Cloudflare, Google, or Quad9)
5. **Comprehensive Testing** - Runs full test suite to verify configuration
6. **Replication Setup** - Configures ZFS replication to Main NAS (10.0.0.89)
7. **VM Optimization** - Optimizes Hyper-V VM memory settings

## Prerequisites

- Administrator privileges on Windows host
- Baby NAS VM running and accessible at IP address
- SSH enabled on Baby NAS (System Settings → Services → SSH)
- OpenSSH client installed on Windows (or PuTTY)
- Main NAS accessible (for replication setup)

## Quick Start

### Basic Usage (Interactive Mode)

```powershell
cd D:\workspace\True_Nas\windows-scripts
.\FULL-AUTOMATION.ps1
```

This will run the full automation with prompts for user confirmation at key steps.

### Unattended Mode

```powershell
.\FULL-AUTOMATION.ps1 -UnattendedMode
```

Runs without prompts, using default values where applicable. Note: Some steps like disk selection still require interaction.

### Custom IP Addresses

```powershell
.\FULL-AUTOMATION.ps1 -BabyNasIP "192.168.1.100" -MainNasIP "192.168.1.200"
```

### Skip Optional Steps

```powershell
# Skip replication setup
.\FULL-AUTOMATION.ps1 -SkipReplication

# Skip comprehensive testing
.\FULL-AUTOMATION.ps1 -SkipTests

# Skip both
.\FULL-AUTOMATION.ps1 -SkipReplication -SkipTests
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `BabyNasIP` | String | `172.21.203.18` | IP address of Baby NAS |
| `MainNasIP` | String | `10.0.0.89` | IP address of Main NAS |
| `Username` | String | `truenas_admin` | TrueNAS admin username |
| `Password` | String | `uppercut%$##` | TrueNAS admin password |
| `AdminUsername` | String | `admin` | Initial admin username |
| `UnattendedMode` | Switch | False | Run without interactive prompts |
| `SkipReplication` | Switch | False | Skip replication setup |
| `SkipTests` | Switch | False | Skip comprehensive testing |

## DNS Options

The script offers three DNS server options:

1. **Cloudflare** (Default)
   - Primary: 1.1.1.1
   - Secondary: 1.0.0.1
   - Fast, privacy-focused

2. **Google**
   - Primary: 8.8.8.8
   - Secondary: 8.8.4.4
   - Reliable, widely used

3. **Quad9**
   - Primary: 9.9.9.9
   - Secondary: 149.112.112.112
   - Security-focused with malware blocking

## Execution Flow

```
┌─────────────────────────────────────┐
│ STEP 1: Test Connectivity          │
│  • Ping test                        │
│  • SSH port check                   │
│  • SSH authentication test          │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ STEP 2: Upload & Execute Config    │
│  • Upload configure-baby-nas.sh     │
│  • Execute on Baby NAS              │
│  • Create pool & datasets           │
│  • Configure users & security       │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ STEP 3: SSH Key Setup               │
│  • Generate Ed25519 keys            │
│  • Deploy to Baby NAS               │
│  • Deploy to Main NAS               │
│  • Create SSH config                │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ STEP 4: DNS Configuration           │
│  • Select DNS servers               │
│  • Configure on Baby NAS            │
│  • Test resolution                  │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ STEP 5: Comprehensive Testing       │
│  • VM and network tests             │
│  • SSH access tests                 │
│  • ZFS pool tests                   │
│  • Dataset tests                    │
│  • SMB share tests                  │
│  • Security tests                   │
│  • Performance tests                │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ STEP 6: Replication Setup           │
│  • Generate replication keys        │
│  • Configure Baby→Main replication  │
│  • Create replication scripts       │
│  • Schedule automatic replication   │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ STEP 7: VM Optimization             │
│  • Check VM memory                  │
│  • Reduce to 8GB if needed          │
│  • Restart VM                       │
│  • Verify SSH access                │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│ COMPLETION SUMMARY                  │
│  • Execution time                   │
│  • Configuration details            │
│  • Access information               │
│  • Next steps                       │
│  • Log file location                │
└─────────────────────────────────────┘
```

## Logging

All operations are logged to:
```
D:\workspace\True_Nas\logs\full-automation-YYYYMMDD-HHMMSS.log
```

The log file contains:
- Timestamp for each operation
- Success/failure status
- Error messages and stack traces
- Complete execution history

## Error Handling

The script includes:

- **Retry Logic** - Automatic retries for network operations (3 attempts with 5-second delays)
- **Graceful Failures** - Continues execution when non-critical steps fail
- **User Prompts** - Asks for confirmation before proceeding after errors
- **Comprehensive Logging** - All errors logged with stack traces
- **Rollback Support** - Can be re-run safely (idempotent operations)

## Common Issues and Solutions

### Issue: "Cannot reach Baby NAS"
**Solution:**
1. Verify VM is running: `Get-VM "TrueNAS-BabyNAS"`
2. Check VM network: Ensure it's on the correct virtual switch
3. Verify IP with: `.\get-vm-ip.ps1`

### Issue: "SSH service not accessible"
**Solution:**
1. Open TrueNAS Web UI: `https://172.21.203.18`
2. Navigate to: System Settings → Services
3. Find SSH and click Start
4. Re-run the automation script

### Issue: "SSH authentication failed"
**Solution:**
1. Verify password is correct
2. Check that admin account is enabled
3. Try manual SSH: `ssh admin@172.21.203.18`

### Issue: "Configuration script failed"
**Solution:**
1. Check the Baby NAS output for specific errors
2. Verify disks are available: `ssh admin@172.21.203.18 'lsblk'`
3. Run configuration manually if needed
4. Re-run automation with `-SkipConfiguration` (if implemented)

### Issue: "Main NAS not reachable"
**Solution:**
1. This is non-critical - replication will be skipped
2. Run replication setup later: `.\3-setup-replication.ps1`
3. Or re-run automation without `-SkipReplication`

### Issue: "Test failures"
**Solution:**
1. Review test output to identify specific failures
2. Most warnings are non-critical
3. Focus on fixing critical errors (pool status, SMB access)
4. Re-run tests: `.\test-baby-nas-complete.ps1`

## Post-Automation Steps

After successful automation:

1. **Verify SMB Access**
   ```powershell
   net use W: \\172.21.203.18\WindowsBackup /user:truenas_admin "uppercut%$##"
   ```

2. **Deploy Veeam Backups**
   ```powershell
   .\veeam\0-DEPLOY-VEEAM-COMPLETE.ps1
   ```

3. **Test Replication** (if configured)
   ```powershell
   ssh babynas '/root/replicate-to-main.sh'
   ssh babynas '/root/check-replication.sh'
   ```

4. **Schedule Windows Backups**
   ```powershell
   .\schedule-backup-tasks.ps1
   ```

## Manual Execution of Individual Steps

If you need to run steps individually:

```powershell
# Step 1: Connectivity test
Test-Connection -ComputerName 172.21.203.18 -Count 4

# Step 2: Deploy configuration
.\DEPLOY-BABY-NAS-CONFIG.ps1

# Step 3: Setup SSH keys
.\setup-ssh-keys-complete.ps1 -BabyNasIP "172.21.203.18" -MainNasIP "10.0.0.89"

# Step 4: DNS configuration (manual)
ssh babynas "echo 'nameserver 1.1.1.1' > /etc/resolv.conf"

# Step 5: Run tests
.\test-baby-nas-complete.ps1 -BabyNasIP "172.21.203.18"

# Step 6: Setup replication
.\3-setup-replication.ps1 -BabyNasIP "172.21.203.18"

# Step 7: VM optimization (manual)
Set-VMMemory -VMName "TrueNAS-BabyNAS" -StartupBytes 8GB
```

## Files Created by Automation

On **Windows Host**:
- `C:\Users\<user>\.ssh\id_babynas` - Baby NAS SSH private key
- `C:\Users\<user>\.ssh\id_babynas.pub` - Baby NAS SSH public key
- `C:\Users\<user>\.ssh\id_mainnas` - Main NAS SSH private key
- `C:\Users\<user>\.ssh\id_mainnas.pub` - Main NAS SSH public key
- `C:\Users\<user>\.ssh\config` - SSH configuration
- `D:\workspace\True_Nas\logs\full-automation-*.log` - Execution logs

On **Baby NAS**:
- `/root/configure-baby-nas.sh` - Configuration script
- `/root/replicate-to-main.sh` - Replication script
- `/root/check-replication.sh` - Replication monitoring
- `/root/create-snapshots.sh` - Snapshot automation
- `/root/.zfs_encryption_key` - ZFS encryption key
- `/root/.ssh/id_replication` - Replication SSH key
- `/etc/sanoid/sanoid.conf` - Snapshot configuration
- `/etc/samba/smb.conf` - Samba configuration
- `/var/log/replication.log` - Replication logs

## Security Considerations

The script handles sensitive data:
- **Passwords** are passed as parameters (avoid in scripts, use parameter prompts)
- **SSH Keys** are generated with proper permissions (700/600)
- **Encryption Keys** are stored securely on Baby NAS
- **Log Files** may contain sensitive information - review before sharing

**Recommendation**: After initial setup, change passwords and regenerate keys for production use.

## Performance Tips

- **First Run**: Takes 20-30 minutes depending on disk configuration
- **Subsequent Runs**: Skip completed steps with flags (2-5 minutes)
- **Unattended Mode**: Faster but less visible progress
- **Network Speed**: Affects upload/download times significantly

## Troubleshooting

Enable verbose logging:
```powershell
$VerbosePreference = "Continue"
.\FULL-AUTOMATION.ps1
```

Check individual component logs:
- Baby NAS logs: `ssh babynas 'journalctl -xe'`
- ZFS logs: `ssh babynas 'zpool status -v'`
- Samba logs: `ssh babynas 'tail -f /var/log/samba/log.smbd'`
- Replication logs: `ssh babynas 'tail -f /var/log/replication.log'`

## Support

For issues:
1. Check the log file in `D:\workspace\True_Nas\logs\`
2. Review error messages in the console output
3. Verify prerequisites are met
4. Try running individual steps manually
5. Check Baby NAS system logs

## Version History

- **v1.0** (2024-12-10)
  - Initial release
  - Complete automation pipeline
  - Comprehensive error handling
  - Retry logic for network operations
  - DNS configuration options
  - Replication setup
  - VM optimization

## Related Scripts

- `DEPLOY-BABY-NAS-CONFIG.ps1` - Configuration deployment only
- `setup-ssh-keys-complete.ps1` - SSH key setup only
- `test-baby-nas-complete.ps1` - Comprehensive testing only
- `3-setup-replication.ps1` - Replication setup only
- `veeam\0-DEPLOY-VEEAM-COMPLETE.ps1` - Veeam deployment

## License

Internal use only. Part of TrueNAS infrastructure automation toolkit.
