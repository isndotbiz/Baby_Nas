# Create Vaultwarden Entries - Step by Step

Since the OAuth API cannot create ciphers, use this simple method:

## Step 1: Open Vaultwarden Web UI

```
https://vault.isn.biz
```

## Step 2: Login
- Email: Your Vaultwarden account email
- Password: Your Vaultwarden password

## Step 3: Select Organization
- Click on "BABY_NAS" organization in the vault selector

## Step 4: Create Entry 1 - BabyNAS-SMB

Click "+ New Item" → "Secure Note"

**Title**: `BabyNAS-SMB`

**Notes** (paste this JSON):
```json
{
  "ip": "192.168.215.2",
  "hostname": "baby.isn.biz",
  "protocol": "smb",
  "shares": ["backups", "veeam", "wsl-backups", "phone", "media"],
  "username": "jdmal",
  "description": "BabyNAS SMB file shares for backup storage"
}
```

Click "Save"

---

## Step 5: Create Entry 2 - BabyNAS-API

Click "+ New Item" → "Secure Note"

**Title**: `BabyNAS-API`

**Notes** (paste this JSON):
```json
{
  "ip": "192.168.215.2",
  "hostname": "baby.isn.biz",
  "api_url": "http://192.168.215.2/api/v2.0",
  "api_key": "1-VkZdCiOTla5o0cs2lDBocRiTS14RIGDPchTiSVg2Hflt1AcmBzYzJiBuJLkOTI9A",
  "root_password": "74108520",
  "description": "BabyNAS TrueNAS REST API credentials"
}
```

Click "Save"

---

## Step 6: Create Entry 3 - BabyNAS-SSH

Click "+ New Item" → "Secure Note"

**Title**: `BabyNAS-SSH`

**Notes** (paste this JSON):
```json
{
  "hostname": "baby.isn.biz",
  "ip": "192.168.215.2",
  "ssh_user": "jdmal",
  "ssh_key_path": "~/.ssh/id_ed25519",
  "ssh_port": 22,
  "description": "BabyNAS SSH key authentication for jdmal user"
}
```

Click "Save"

---

## Step 7: Create Entry 4 - ZFS-Replication

Click "+ New Item" → "Secure Note"

**Title**: `ZFS-Replication`

**Notes** (paste this JSON):
```json
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

Click "Save"

---

## Step 8: Create Entry 5 - StoragePool-Config

Click "+ New Item" → "Secure Note"

**Title**: `StoragePool-Config`

**Notes** (paste this JSON):
```json
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

Click "Save"

---

## Step 9: Verify All Entries Created

You should now see 5 items in your BABY_NAS vault:
- ✅ BabyNAS-SMB
- ✅ BabyNAS-API
- ✅ BabyNAS-SSH
- ✅ ZFS-Replication
- ✅ StoragePool-Config

---

## Step 10: Test Retrieval from CLI

After creating all entries, verify they work:

```bash
python vaultwarden-credential-manager.py list
```

You should see all 5 items listed.

```bash
python vaultwarden-credential-manager.py get "BabyNAS-SMB"
```

Should return the full credential entry.

---

## Time Required
- 5 minutes to create all 5 entries manually
- 1 minute to verify from CLI

**Total: ~6 minutes**

---

## Done!

Once verified, you have:
✅ Vaultwarden: 5 credential entries created and accessible
✅ 1Password: Set up locally (see separate instructions)
✅ Both systems: Ready to use and share with team
