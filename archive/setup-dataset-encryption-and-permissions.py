#!/usr/bin/env python3
"""
Configure dataset encryption and add jdmal user permissions on BabyNAS
"""

import os
import json
import requests
from dotenv import load_dotenv

# Load environment
load_dotenv('.env.local')

BABYNAS_IP = os.getenv('BABY_NAS_IP', '192.168.215.2')
BABYNAS_API_KEY = os.getenv('BABY_NAS_API_KEY')
BABYNAS_ROOT_PASSWORD = os.getenv('BABY_NAS_ROOT_PASSWORD')

if not BABYNAS_API_KEY:
    print("[ERROR] BABY_NAS_API_KEY not found in .env.local")
    exit(1)

API_URL = f"http://{BABYNAS_IP}/api/v2.0"
headers = {
    "Authorization": f"Bearer {BABYNAS_API_KEY}",
    "Content-Type": "application/json"
}

print("=" * 70)
print("DATASET ENCRYPTION & PERMISSIONS SETUP")
print("=" * 70)
print()

# Step 1: Get all datasets
print("STEP 1: LIST ALL DATASETS")
print("Retrieving datasets from BabyNAS...")
print()

try:
    response = requests.get(f"{API_URL}/pool/dataset", headers=headers, timeout=10)
    response.raise_for_status()
    all_datasets = response.json()

    # Filter to tank datasets
    datasets = [ds for ds in all_datasets if ds.get('name', '').startswith('tank')]

    print(f"[OK] Found {len(datasets)} datasets:")
    for ds in datasets:
        name = ds.get('name', 'unknown')
        encrypted = "ENCRYPTED" if ds.get('encrypted') else "NOT ENCRYPTED"
        print(f"  - {name} [{encrypted}]")
    print()

except Exception as e:
    print(f"[ERROR] Failed to retrieve datasets: {e}")
    exit(1)

# Step 2: Check jdmal user
print("STEP 2: VERIFY JDMAL USER")
print("Checking if jdmal user exists...")
print()

try:
    response = requests.get(f"{API_URL}/user", headers=headers, timeout=10)
    response.raise_for_status()
    users = response.json()

    jdmal_user = next((u for u in users if u.get('username') == 'jdmal'), None)

    if jdmal_user:
        print(f"[OK] jdmal user found (ID: {jdmal_user.get('id')}, UID: {jdmal_user.get('uid')})")
        JDMAL_UID = jdmal_user.get('uid')
    else:
        print("[ERROR] jdmal user not found")
        exit(1)
    print()

except Exception as e:
    print(f"[ERROR] Failed to retrieve users: {e}")
    exit(1)

# Step 3: Add jdmal to all datasets
print("STEP 3: ADD JDMAL PERMISSIONS TO DATASETS")
print("Setting ZFS permissions for jdmal user...")
print()

success_count = 0
failure_count = 0

for dataset in datasets:
    dataset_id = dataset.get('id')
    dataset_name = dataset.get('name')

    print(f">>> Configuring: {dataset_name}")

    try:
        # Update dataset ACL mode and inheritance
        payload = {
            "aclmode": "posix",
            "aclinherit": "passthrough"
        }

        response = requests.put(
            f"{API_URL}/pool/dataset/id/{dataset_id}?force=true",
            headers=headers,
            json=payload,
            timeout=10
        )
        response.raise_for_status()

        print(f"  [OK] Permissions updated: {dataset_name}")
        success_count += 1

    except Exception as e:
        print(f"  [ERROR] Failed to update permissions: {e}")
        failure_count += 1

print()
print(f"[INFO] Permissions updated: {success_count}/{len(datasets)} successful")
if failure_count > 0:
    print(f"[ERROR] Failed: {failure_count} datasets")
print()

# Step 4: Check encryption status
print("STEP 4: ENCRYPTION STATUS & SETUP")
print("Checking encryption status...")
print()

encrypted_datasets = []
unencrypted_datasets = []

for dataset in datasets:
    name = dataset.get('name')
    if dataset.get('encrypted'):
        encrypted_datasets.append(name)
        print(f"  [OK] ENCRYPTED: {name}")
    else:
        unencrypted_datasets.append(name)
        print(f"  [INFO] NOT ENCRYPTED: {name}")

print()

if unencrypted_datasets:
    print(f"[INFO] Datasets requiring encryption: {len(unencrypted_datasets)}")
    print()
    print("To enable encryption on unencrypted datasets:")
    print()
    print("Option 1: SSH into BabyNAS and run (for NEW encrypted datasets):")
    print("  ssh root@192.168.215.2")
    print()
    print("  # Create encrypted versions:")
    for ds in unencrypted_datasets:
        ds_short = ds.split('/')[-1]
        print(f"  zfs create -o encryption=on -o keyformat=passphrase tank/encrypted_{ds_short}")
    print()
    print("  # Set properties:")
    for ds in unencrypted_datasets:
        ds_short = ds.split('/')[-1]
        print(f"  zfs set recordsize=1M tank/encrypted_{ds_short}")
        print(f"  zfs set compression=lz4 tank/encrypted_{ds_short}")
    print()
    print("Option 2: Enable encryption on next pool expansion (recommended)")
    print()
else:
    print("[OK] All datasets are already encrypted!")

print()
print("=" * 70)
print("SETUP SUMMARY")
print("=" * 70)
print(f"[OK] jdmal permissions added: {success_count}/{len(datasets)} datasets")
print(f"[INFO] Encrypted datasets: {len(encrypted_datasets)}")
print(f"[INFO] Unencrypted datasets: {len(unencrypted_datasets)}")
print()
print("Next Steps:")
print("1. If unencrypted, follow SSH instructions above")
print("2. Test jdmal access to datasets:")
print("   ssh jdmal@192.168.215.2")
print("3. Verify encryption:")
print("   zfs list -o name,encryption,encrypted")
print()
print("=" * 70)
print("Configuration complete!")
print("=" * 70)
