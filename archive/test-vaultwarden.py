#!/usr/bin/env python3
"""Quick test of Vaultwarden connectivity"""

import os
import sys
import json
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

from vaultwarden_credential_manager import VaultwardenCredentialManager

def main():
    print("=" * 70)
    print("VAULTWARDEN CREDENTIAL MANAGER - CONNECTION TEST")
    print("=" * 70)
    print()

    try:
        # Initialize manager
        print("[1] Initializing Vaultwarden manager...")
        mgr = VaultwardenCredentialManager()
        print("    OK - Manager initialized")
        print()

        # Test authentication
        print("[2] Testing OAuth 2.0 authentication...")
        if mgr.authenticate():
            print("    OK - Successfully authenticated")
            print(f"    Access Token: {mgr.access_token[:50]}...")
            print()
        else:
            print("    FAILED - Could not authenticate")
            return False

        # List credentials
        print("[3] Retrieving credential list...")
        entries = mgr.list_credential_entries()
        if entries:
            print(f"    OK - Found {len(entries)} entries:")
            for entry in entries:
                print(f"       - {entry['name']} (ID: {entry['id'][:8]}...)")
            print()
        else:
            print("    EMPTY - No entries found (vault is empty)")
            print()

        # Test vault URL
        print("[4] Configuration Summary:")
        print(f"    Vault URL: {mgr.vault_url}")
        print(f"    Client ID: {mgr.client_id[:50]}...")
        print(f"    Fingerprint: {mgr.fingerprint}")
        print()

        print("=" * 70)
        print("RESULT: SUCCESS - Vaultwarden is accessible and authenticated")
        print("=" * 70)
        return True

    except Exception as e:
        print(f"    ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
