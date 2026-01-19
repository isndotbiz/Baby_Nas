#!/usr/bin/env python3
"""Simple Vaultwarden connectivity test"""

import os
import json
import requests
from dotenv import load_dotenv

print("=" * 70)
print("VAULTWARDEN CREDENTIAL MANAGER - CONNECTION TEST")
print("=" * 70)
print()

# Load environment
env_file = '.env.local'
if os.path.exists(env_file):
    load_dotenv(env_file)
    print(f"[1] Loaded environment from: {env_file}")
else:
    print(f"[!] Warning: {env_file} not found, using system environment")

print()

# Get credentials
vault_url = os.getenv('VAULTWARDEN_URL', 'https://vault.isn.biz').rstrip('/')
client_id = os.getenv('VAULTWARDEN_CLIENT_ID')
client_secret = os.getenv('VAULTWARDEN_CLIENT_SECRET')
grant_type = os.getenv('VAULTWARDEN_GRANT_TYPE', 'client_credentials')
scope = os.getenv('VAULTWARDEN_SCOPE', 'api.organization')

print("[2] Configuration:")
print(f"    Vault URL: {vault_url}")
print(f"    Client ID: {client_id[:40]}..." if client_id else "    Client ID: NOT SET")
print(f"    Grant Type: {grant_type}")
print(f"    Scope: {scope}")
print()

if not all([client_id, client_secret, vault_url]):
    print("[!] ERROR: Missing required environment variables")
    print("    Set VAULTWARDEN_CLIENT_ID and VAULTWARDEN_CLIENT_SECRET in .env.local")
    exit(1)

# Test authentication
print("[3] Testing OAuth 2.0 authentication...")
try:
    auth_url = f"{vault_url}/identity/connect/token"
    payload = {
        'grant_type': grant_type,
        'scope': scope,
        'client_id': client_id,
        'client_secret': client_secret,
        'device_identifier': 'claude-code-credential-manager',
        'device_name': 'Claude Code Credential Manager'
    }

    response = requests.post(auth_url, data=payload, verify=True, timeout=10)
    response.raise_for_status()

    token_data = response.json()
    access_token = token_data.get('access_token')

    if access_token:
        print("    SUCCESS - Authenticated with Vaultwarden")
        print(f"    Token: {access_token[:50]}...")
        print()
    else:
        print("    FAILED - No access token received")
        exit(1)

except requests.exceptions.RequestException as e:
    print(f"    FAILED - {e}")
    exit(1)

# List credentials
print("[4] Retrieving credentials list...")
try:
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }

    vault_api_url = f"{vault_url}/api/ciphers"
    response = requests.get(vault_api_url, headers=headers, verify=True, timeout=10)
    response.raise_for_status()

    ciphers = response.json().get('data', [])

    if ciphers:
        print(f"    SUCCESS - Found {len(ciphers)} credential entries:")
        for cipher in ciphers:
            print(f"       - {cipher.get('name')} (Type: {cipher.get('type')})")
        print()
    else:
        print("    INFO - Vault is empty (no entries yet)")
        print()

except requests.exceptions.RequestException as e:
    print(f"    FAILED - {e}")
    exit(1)

print("=" * 70)
print("RESULT: SUCCESS - Vaultwarden is accessible and authenticated!")
print("=" * 70)
print()
print("Next steps:")
print("  1. Run setup script to populate credentials:")
print("     .\\setup-vaultwarden-credentials.ps1")
print()
print("  2. Retrieve credentials:")
print("     python vaultwarden-credential-manager.py get 'BabyNAS-SMB'")
print()
