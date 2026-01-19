#!/usr/bin/env python3
"""Debug Vaultwarden authentication"""

import os
import json
import requests
from dotenv import load_dotenv

# Load environment
load_dotenv('.env.local')

vault_url = os.getenv('VAULTWARDEN_URL', 'https://vault.isn.biz').rstrip('/')
client_id = os.getenv('VAULTWARDEN_CLIENT_ID')
client_secret = os.getenv('VAULTWARDEN_CLIENT_SECRET')

print("Testing Vaultwarden OAuth endpoints...")
print()

# Test different endpoint paths
endpoints = [
    f"{vault_url}/identity/connect/token",
    f"{vault_url}/oauth/token",
    f"{vault_url}/api/oauth/token",
    f"{vault_url}/oauth2/token",
]

for endpoint in endpoints:
    print(f"Trying: {endpoint}")

    payload = {
        'grant_type': 'client_credentials',
        'scope': 'api.organization',
        'client_id': client_id,
        'client_secret': client_secret
    }

    try:
        response = requests.post(endpoint, data=payload, verify=True, timeout=5)
        print(f"  Status: {response.status_code}")

        if response.status_code == 200:
            print(f"  SUCCESS!")
            print(f"  Response: {response.json()}")
            break
        else:
            print(f"  Response: {response.text[:200]}")
    except Exception as e:
        print(f"  Error: {e}")

    print()
