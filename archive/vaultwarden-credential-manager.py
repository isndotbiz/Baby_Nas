#!/usr/bin/env python3
"""
Vaultwarden Credential Manager
Manages BabyNAS credentials stored in Vaultwarden vault
Authenticates via OAuth 2.0 Client Credentials flow
"""

import os
import json
import requests
import sys
from pathlib import Path
from dotenv import load_dotenv
from typing import Dict, Optional, Any
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class VaultwardenCredentialManager:
    """Manage credentials stored in Vaultwarden"""

    def __init__(self, env_file: str = '.env.local'):
        """Initialize with environment variables"""
        load_dotenv(env_file)

        self.vault_url = os.getenv('VAULTWARDEN_URL', 'https://vault.isn.biz').rstrip('/')
        self.client_id = os.getenv('VAULTWARDEN_CLIENT_ID')
        self.client_secret = os.getenv('VAULTWARDEN_CLIENT_SECRET')
        self.grant_type = os.getenv('VAULTWARDEN_GRANT_TYPE', 'client_credentials')
        self.scope = os.getenv('VAULTWARDEN_SCOPE', 'api.organization')
        self.fingerprint = os.getenv('VAULTWARDEN_FINGERPRINT', '')

        self.access_token = None
        self.token_type = None

        if not all([self.client_id, self.client_secret, self.vault_url]):
            raise ValueError("Missing required Vaultwarden credentials in .env.local")

        logger.info(f"Initialized Vaultwarden manager for {self.vault_url}")

    def authenticate(self) -> bool:
        """Authenticate with Vaultwarden using OAuth 2.0 Client Credentials"""
        try:
            auth_url = f"{self.vault_url}/identity/connect/token"

            payload = {
                'grant_type': self.grant_type,
                'scope': self.scope,
                'client_id': self.client_id,
                'client_secret': self.client_secret,
                'device_identifier': 'claude-code-credential-manager',
                'device_name': 'Claude Code Credential Manager',
                'device_type': '7'  # Application type device
            }

            logger.info(f"Authenticating with Vaultwarden at {auth_url}")
            response = requests.post(auth_url, data=payload, verify=True)
            response.raise_for_status()

            token_data = response.json()
            self.access_token = token_data.get('access_token')
            self.token_type = token_data.get('token_type', 'Bearer')

            if self.access_token:
                logger.info("Successfully authenticated with Vaultwarden")
                return True
            else:
                logger.error("No access token received from Vaultwarden")
                return False

        except requests.exceptions.RequestException as e:
            logger.error(f"Authentication failed: {e}")
            return False

    def get_headers(self) -> Dict[str, str]:
        """Get authorization headers for API requests"""
        return {
            'Authorization': f'{self.token_type} {self.access_token}',
            'Content-Type': 'application/json'
        }

    def create_credential_entry(self, name: str, credentials: Dict[str, str]) -> Optional[str]:
        """
        Create a credential entry in Vaultwarden

        Args:
            name: Credential entry name (e.g., 'BabyNAS-SMB')
            credentials: Dict of credential key-value pairs

        Returns:
            Entry ID if successful, None otherwise
        """
        if not self.access_token:
            if not self.authenticate():
                return None

        try:
            # Create a note-type secret with all credentials
            vault_url = f"{self.vault_url}/api/ciphers"

            # Format credentials as JSON string for storage
            cred_json = json.dumps(credentials, indent=2)

            payload = {
                'type': 2,  # SecureNote type
                'name': name,
                'notes': cred_json,
                'secureNote': {
                    'type': 0  # Generic note
                },
                'organizationId': self.client_id.split('.')[-1]  # Extract org ID from client_id
            }

            logger.info(f"Creating credential entry: {name}")
            response = requests.post(
                vault_url,
                headers=self.get_headers(),
                json=payload,
                verify=True
            )
            response.raise_for_status()

            entry_data = response.json()
            entry_id = entry_data.get('id')
            logger.info(f"Created credential entry {name} with ID: {entry_id}")
            return entry_id

        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to create credential entry: {e}")
            return None

    def get_credential_entry(self, entry_name: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve a credential entry from Vaultwarden

        Args:
            entry_name: Name of the credential entry to retrieve

        Returns:
            Credential dict if found, None otherwise
        """
        if not self.access_token:
            if not self.authenticate():
                return None

        try:
            # List all ciphers
            vault_url = f"{self.vault_url}/api/ciphers"

            logger.info(f"Searching for credential entry: {entry_name}")
            response = requests.get(
                vault_url,
                headers=self.get_headers(),
                verify=True
            )
            response.raise_for_status()

            ciphers = response.json().get('data', [])

            for cipher in ciphers:
                if cipher.get('name') == entry_name:
                    # Parse credentials from notes
                    notes = cipher.get('notes', '{}')
                    try:
                        credentials = json.loads(notes)
                    except json.JSONDecodeError:
                        credentials = {'raw_notes': notes}

                    logger.info(f"Found credential entry: {entry_name}")
                    return {
                        'id': cipher.get('id'),
                        'name': cipher.get('name'),
                        'credentials': credentials,
                        'created_date': cipher.get('creationDate'),
                        'modified_date': cipher.get('revisionDate')
                    }

            logger.warning(f"Credential entry not found: {entry_name}")
            return None

        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to retrieve credential entry: {e}")
            return None

    def update_credential_entry(self, entry_id: str, credentials: Dict[str, str]) -> bool:
        """
        Update an existing credential entry

        Args:
            entry_id: ID of the entry to update
            credentials: Updated credential dict

        Returns:
            True if successful, False otherwise
        """
        if not self.access_token:
            if not self.authenticate():
                return False

        try:
            vault_url = f"{self.vault_url}/api/ciphers/{entry_id}"
            cred_json = json.dumps(credentials, indent=2)

            payload = {
                'notes': cred_json
            }

            logger.info(f"Updating credential entry: {entry_id}")
            response = requests.put(
                vault_url,
                headers=self.get_headers(),
                json=payload,
                verify=True
            )
            response.raise_for_status()

            logger.info(f"Successfully updated credential entry: {entry_id}")
            return True

        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to update credential entry: {e}")
            return False

    def delete_credential_entry(self, entry_id: str) -> bool:
        """
        Delete a credential entry from Vaultwarden

        Args:
            entry_id: ID of the entry to delete

        Returns:
            True if successful, False otherwise
        """
        if not self.access_token:
            if not self.authenticate():
                return False

        try:
            vault_url = f"{self.vault_url}/api/ciphers/{entry_id}"

            logger.info(f"Deleting credential entry: {entry_id}")
            response = requests.delete(
                vault_url,
                headers=self.get_headers(),
                verify=True
            )
            response.raise_for_status()

            logger.info(f"Successfully deleted credential entry: {entry_id}")
            return True

        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to delete credential entry: {e}")
            return False

    def list_credential_entries(self) -> Optional[list]:
        """List all credential entries in the vault"""
        if not self.access_token:
            if not self.authenticate():
                return None

        try:
            vault_url = f"{self.vault_url}/api/ciphers"

            response = requests.get(
                vault_url,
                headers=self.get_headers(),
                verify=True
            )
            response.raise_for_status()

            ciphers = response.json().get('data', [])
            entries = []

            for cipher in ciphers:
                entries.append({
                    'id': cipher.get('id'),
                    'name': cipher.get('name'),
                    'type': cipher.get('type'),
                    'created': cipher.get('creationDate'),
                    'modified': cipher.get('revisionDate')
                })

            logger.info(f"Found {len(entries)} credential entries")
            return entries

        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to list credential entries: {e}")
            return None


def main():
    """CLI interface for credential management"""
    # Fix encoding for Windows console
    if sys.platform == 'win32':
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')

    if len(sys.argv) < 2:
        print("Usage: python vaultwarden-credential-manager.py <command> [args]")
        print("\nCommands:")
        print("  create <name>      - Create a new credential entry")
        print("  get <name>         - Retrieve a credential entry")
        print("  update <id>        - Update a credential entry")
        print("  delete <id>        - Delete a credential entry")
        print("  list               - List all credential entries")
        print("  test               - Test Vaultwarden connection")
        sys.exit(1)

    command = sys.argv[1]

    try:
        manager = VaultwardenCredentialManager()

        if command == 'test':
            if manager.authenticate():
                print("[OK] Successfully authenticated with Vaultwarden")
                entries = manager.list_credential_entries()
                if entries:
                    print(f"[OK] Found {len(entries)} credential entries:")
                    for entry in entries:
                        print(f"  - {entry['name']} (ID: {entry['id']})")
                else:
                    print("[OK] Vault is accessible but empty")
            else:
                print("[FAIL] Failed to authenticate with Vaultwarden")
                sys.exit(1)

        elif command == 'list':
            entries = manager.list_credential_entries()
            if entries:
                print(json.dumps(entries, indent=2))
            else:
                print("No entries found")

        elif command == 'get' and len(sys.argv) > 2:
            entry_name = sys.argv[2]
            entry = manager.get_credential_entry(entry_name)
            if entry:
                print(json.dumps(entry, indent=2))
            else:
                print(f"Entry '{entry_name}' not found")
                sys.exit(1)

        elif command == 'create' and len(sys.argv) > 2:
            entry_name = sys.argv[2]
            print(f"Creating credential entry: {entry_name}")
            print("Enter credentials (JSON format). Press Ctrl+D (Unix) or Ctrl+Z (Windows) when done:")

            cred_input = sys.stdin.read()
            try:
                credentials = json.loads(cred_input)
                entry_id = manager.create_credential_entry(entry_name, credentials)
                if entry_id:
                    print(f"✓ Created entry with ID: {entry_id}")
                else:
                    print("✗ Failed to create entry")
                    sys.exit(1)
            except json.JSONDecodeError:
                print("✗ Invalid JSON format")
                sys.exit(1)

        else:
            print(f"Unknown command: {command}")
            sys.exit(1)

    except Exception as e:
        logger.error(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
