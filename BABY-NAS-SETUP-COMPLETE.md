# Baby NAS Setup Complete

## System Configuration

**Baby NAS VM:**
- IP: 10.0.0.88
- Hostname: baby.isn.biz
- TrueNAS SCALE 25.04.2.6

**Storage Pool (tank):**
- Data vdev: RAIDZ1 (3x 6TB Toshiba HDWE160)
- Special vdev: Mirror (2x 256GB Samsung 850 SSD)
- Usable capacity: ~10.8 TB
- Status: ONLINE

**Datasets:**
- tank/workspace - Workspace sync
- tank/models - AI model archive
- tank/staging - Downloads and temp
- tank/backups - General backups

**SMB Shares:**
- \\10.0.0.88\workspace
- \\10.0.0.88\models
- \\10.0.0.88\staging
- \\10.0.0.88\backups

## Credentials

**TrueNAS Web UI / API:**
- Username: truenas_admin
- Password: Tigeruppercut1913!
- API Key: 1-S5JxuIyBrQdvqWlvQpiKreHvdtsoXjOMTxsJ0SEqyck4U1X3fm9NVagSPUBkl6Gi

**SMB User:**
- Username: smbuser
- Password: SmbPass2024!

**SSH:**
- Host: 10.0.0.88
- User: truenas_admin
- Password: Tigeruppercut1913!

## Windows SMB Fix Required

There are stale network drive mappings from the old Baby NAS that need to be removed.
Run the following commands **as Administrator**:

```powershell
# Remove old stale mappings
net use M: /delete /y
net use P: /delete /y
net use V: /delete /y
net use W: /delete /y
net use Z: /delete /y

# Enable insecure guest auth (may be needed)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f

# Restart the workstation service
net stop workstation /y
net start workstation

# Map new drives
net use W: \\10.0.0.88\workspace /user:smbuser "SmbPass2024!" /persistent:yes
net use M: \\10.0.0.88\models /user:smbuser "SmbPass2024!" /persistent:yes
net use S: \\10.0.0.88\staging /user:smbuser "SmbPass2024!" /persistent:yes
net use B: \\10.0.0.88\backups /user:smbuser "SmbPass2024!" /persistent:yes
```

## Manual Verification

1. Open TrueNAS Web UI: http://10.0.0.88
2. Login with truenas_admin
3. Go to Storage > Pools to verify tank is ONLINE
4. Go to Shares > SMB to verify all 4 shares are enabled

## Network Drive Letter Assignments

| Drive | Share | Purpose |
|-------|-------|---------|
| W: | workspace | Workspace sync |
| M: | models | AI model archive |
| S: | staging | Downloads/temp |
| B: | backups | General backups |

## Next Steps

1. Run the Windows fix commands above (as Administrator)
2. Verify SMB shares are accessible
3. Set up snapshot automation in TrueNAS
4. Configure ZFS replication to Main NAS (10.0.0.89)

## Files Created

- D:\VM\BabyNAS\ - VM files
- D:\workspace\Baby_Nas\Create-BabyNAS-VM.ps1 - VM creation script
- D:\workspace\Baby_Nas\.env.example - Environment template
