#!/usr/bin/env python3
"""Create Vaultwarden entries using admin token"""

import requests
import json
import os
from dotenv import load_dotenv

# Load environment
load_dotenv('D:\\workspace\\True_Nas\\.env.local')

vault_url = "https://vault.isn.biz"
admin_token = os.getenv('VAULTWARDEN_ADMIN_TOKEN')
org_id = "1a4d4b38-c293-4d05-aad1-f9a037483338"  # BABY_NAS org ID

if not admin_token:
    print("ERROR: VAULTWARDEN_ADMIN_TOKEN not found in .env.local")
    exit(1)

print(f"Using admin token: {admin_token[:30]}...")
print(f"Vault URL: {vault_url}")
print(f"Organization: {org_id}")
print()

# Credentials to create
credentials = [
    {
        "title": "BabyNAS-SMB",
        "notes": json.dumps({
            "ip": "192.168.215.2",
            "hostname": "baby.isn.biz",
            "protocol": "smb",
            "shares": ["backups", "veeam", "wsl-backups", "phone", "media"],
            "username": "jdmal",
            "description": "BabyNAS SMB file shares for backup storage"
        }, indent=2)
    },
    {
        "title": "BabyNAS-API",
        "notes": json.dumps({
            "ip": "192.168.215.2",
            "hostname": "baby.isn.biz",
            "api_url": "http://192.168.215.2/api/v2.0",
            "api_key": "1-VkZdCiOTla5o0cs2lDBocRiTS14RIGDPchTiSVg2Hflt1AcmBzYzJiBuJLkOTI9A",
            "root_password": "74108520",
            "description": "BabyNAS TrueNAS REST API credentials"
        }, indent=2)
    },
    {
        "title": "BabyNAS-SSH",
        "notes": json.dumps({
            "hostname": "baby.isn.biz",
            "ip": "192.168.215.2",
            "ssh_user": "jdmal",
            "ssh_key_path": "~/.ssh/id_ed25519",
            "ssh_port": 22,
            "description": "BabyNAS SSH key authentication for jdmal user"
        }, indent=2)
    },
    {
        "title": "ZFS-Replication",
        "notes": json.dumps({
            "source_host": "192.168.215.2",
            "source_user": "root",
            "target_host": "10.0.0.89",
            "target_user": "baby-nas",
            "ssh_key_path": "D:\\workspace\\Baby_Nas\\keys\\baby-nas-replication",
            "ssh_pubkey": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwjIxc7vunMCVBfIGsOXr1xwQ9mLLTLA58ztyd5gUSC baby-nas-replication",
            "datasets": ["tank/backups", "tank/veeam", "tank/wsl-backups", "tank/media", "tank/phone"],
            "schedule": "daily",
            "description": "BabyNAS to Main NAS ZFS replication credentials"
        }, indent=2)
    },
    {
        "title": "StoragePool-Config",
        "notes": json.dumps({
            "pool_name": "tank",
            "pool_type": "RAIDZ1",
            "data_vdevs": ["/dev/disk/by-id/ata-HDD1", "/dev/disk/by-id/ata-HDD2", "/dev/disk/by-id/ata-HDD3"],
            "slog_vdev": "250GB SSD",
            "l2arc_vdev": "256GB SSD",
            "compression": "lz4",
            "recordsize": "1M",
            "description": "BabyNAS ZFS pool configuration"
        }, indent=2)
    }
]

headers = {
    "Authorization": f"Bearer {admin_token}",
    "Content-Type": "application/json"
}

print("Creating vault entries...")
print()

created_count = 0
for cred in credentials:
    title = cred["title"]
    print(f"Creating: {title}...", end=" ")

    payload = {
        "type": 2,  # Secure Note
        "name": title,
        "notes": cred["notes"],
        "organizationId": org_id,
        "secureNote": {
            "type": 0  # Generic note
        }
    }

    try:
        response = requests.post(
            f"{vault_url}/api/ciphers",
            headers=headers,
            json=payload,
            verify=True
        )

        if response.status_code in [200, 201]:
            entry_id = response.json().get('id', 'unknown')
            print(f"OK (ID: {entry_id[:8]}...)")
            created_count += 1
        else:
            print(f"FAILED ({response.status_code})")
            print(f"  Response: {response.text[:200]}")

    except Exception as e:
        print(f"ERROR: {e}")

print()
print(f"Created: {created_count}/{len(credentials)} entries")
print()

if created_count == len(credentials):
    print("SUCCESS! All entries created!")
    print()
    print("Verify with:")
    print("  python vaultwarden-credential-manager.py list")
else:
    print(f"PARTIAL SUCCESS: {created_count} entries created, {len(credentials) - created_count} failed")
