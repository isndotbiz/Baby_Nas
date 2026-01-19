# Vaultwarden Manual Credential Setup

Due to Vaultwarden OAuth API limitations, credentials need to be created manually through the web interface.

## Access Vaultwarden

1. **Open Browser**: https://vault.isn.biz
2. **Login**: Use your Vaultwarden account credentials
3. **Select Organization**: Choose "BABY_NAS" organization

## Create Credential Entries

### 1. BabyNAS-SMB

**Type**: Secure Note

```
Name: BabyNAS-SMB

Notes:
{
  "ip": "192.168.215.2",
  "hostname": "baby.isn.biz",
  "protocol": "smb",
  "shares": ["backups", "veeam", "wsl-backups", "phone", "media"],
  "username": "jdmal",
  "description": "BabyNAS SMB file shares for backup storage"
}
```

### 2. BabyNAS-API

**Type**: Secure Note

```
Name: BabyNAS-API

Notes:
{
  "ip": "192.168.215.2",
  "hostname": "baby.isn.biz",
  "api_url": "http://192.168.215.2/api/v2.0",
  "api_key": "1-VkZdCiOTla5o0cs2lDBocRiTS14RIGDPchTiSVg2Hflt1AcmBzYzJiBuJLkOTI9A",
  "root_password": "74108520",
  "description": "BabyNAS TrueNAS REST API credentials"
}
```

### 3. BabyNAS-SSH

**Type**: Secure Note

```
Name: BabyNAS-SSH

Notes:
{
  "hostname": "baby.isn.biz",
  "ip": "192.168.215.2",
  "ssh_user": "jdmal",
  "ssh_key_path": "~/.ssh/id_ed25519",
  "ssh_port": 22,
  "description": "BabyNAS SSH key authentication for jdmal user"
}
```

### 4. ZFS-Replication

**Type**: Secure Note

```
Name: ZFS-Replication

Notes:
{
  "source_host": "192.168.215.2",
  "source_user": "root",
  "target_host": "10.0.0.89",
  "target_user": "baby-nas",
  "ssh_key_path": "D:\\workspace\\Baby_Nas\\keys\\baby-nas-replication",
  "ssh_pubkey": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwjIxc7vunMCVBfIGsOXr1xwQ9mLLTLA58ztyd5gUSC baby-nas-replication",
  "datasets": ["tank/backups", "tank/veeam", "tank/wsl-backups", "tank/media", "tank/phone"],
  "schedule": "daily",
  "description": "BabyNAS to Main NAS ZFS replication credentials"
}
```

### 5. StoragePool-Config

**Type**: Secure Note

```
Name: StoragePool-Config

Notes:
{
  "pool_name": "tank",
  "pool_type": "RAIDZ1",
  "data_vdevs": ["/dev/disk/by-id/ata-HDD1", "/dev/disk/by-id/ata-HDD2", "/dev/disk/by-id/ata-HDD3"],
  "slog_vdev": "250GB SSD",
  "l2arc_vdev": "256GB SSD",
  "compression": "lz4",
  "recordsize": "1M",
  "description": "BabyNAS ZFS pool configuration"
}
```

## Verify Entries Created

After creating all entries, verify they're accessible:

```bash
python vaultwarden-credential-manager.py list
```

Expected output:
```
[OK] Found 5 credential entries:
  - BabyNAS-SMB (Type: 2)
  - BabyNAS-API (Type: 2)
  - BabyNAS-SSH (Type: 2)
  - ZFS-Replication (Type: 2)
  - StoragePool-Config (Type: 2)
```

## Retrieve Credentials

Once created in Vaultwarden, retrieve them programmatically:

```bash
python vaultwarden-credential-manager.py get "BabyNAS-SMB"
python vaultwarden-credential-manager.py get "BabyNAS-API"
python vaultwarden-credential-manager.py get "BabyNAS-SSH"
```

## Why Manual Setup?

The Vaultwarden OAuth 2.0 Client Credentials flow has limitations:
- ✓ Authentication works (401 Unauthorized was fixed)
- ✓ Can list ciphers with proper scope
- ✗ Cannot create/update ciphers via API with organization scope

The manual web UI approach is more reliable and allows you to:
- Verify entries are stored correctly
- Test access immediately
- Ensure proper organization assignment
- Control exactly how data is formatted

This is a one-time setup. After creation, all retrieval is fully automated via the Python script.
