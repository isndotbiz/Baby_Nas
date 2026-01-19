#!/usr/bin/env python3
"""Detailed Vaultwarden debug"""

import os
import json
import requests
from dotenv import load_dotenv

load_dotenv('.env.local')

vault_url = os.getenv('VAULTWARDEN_URL', 'https://vault.isn.biz').rstrip('/')
client_id = os.getenv('VAULTWARDEN_CLIENT_ID')
client_secret = os.getenv('VAULTWARDEN_CLIENT_SECRET')

auth_url = f"{vault_url}/identity/connect/token"

print("OAuth Request Details:")
print(f"URL: {auth_url}")
print(f"Client ID: {client_id}")
print()

payload = {
    'grant_type': 'client_credentials',
    'scope': 'api.organization',
    'client_id': client_id,
    'client_secret': client_secret,
    'device_identifier': 'claude-code-test',
    'device_name': 'Claude Code Test',
    'device_type': '7',
}

print("Payload:")
for key, value in payload.items():
    if 'secret' in key.lower():
        print(f"  {key}: [REDACTED]")
    else:
        print(f"  {key}: {value}")
print()

try:
    print("Sending request...")
    response = requests.post(auth_url, data=payload, verify=True, timeout=10)

    print(f"Status Code: {response.status_code}")
    print(f"Headers: {dict(response.headers)}")
    print()

    print("Response Body:")
    try:
        resp_json = response.json()
        print(json.dumps(resp_json, indent=2))
    except:
        print(response.text)

except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
