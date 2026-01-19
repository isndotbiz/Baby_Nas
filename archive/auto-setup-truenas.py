#!/usr/bin/env python3
"""
Automated TrueNAS Setup Script
Enables SSH and creates API key using REST API
"""

import requests
import json
import sys
import urllib3
from getpass import getpass

# Disable SSL warnings for self-signed certs
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class TrueNASSetup:
    def __init__(self, host, username, password):
        self.base_url = f"https://{host}/api/v2.0"
        self.username = username
        self.password = password
        self.session = requests.Session()
        self.session.verify = False  # Skip SSL verification for self-signed cert
        self.session.auth = (username, password)

    def test_connection(self):
        """Test if we can connect to TrueNAS"""
        try:
            response = self.session.get(f"{self.base_url}/system/info")
            if response.status_code == 200:
                info = response.json()
                print(f"[OK] Connected to TrueNAS!")
                print(f"   Version: {info.get('version', 'Unknown')}")
                print(f"   Hostname: {info.get('hostname', 'Unknown')}")
                return True
            else:
                print(f"[ERROR] Connection failed: HTTP {response.status_code}")
                print(f"   Response: {response.text}")
                return False
        except requests.exceptions.ConnectionError as e:
            print(f"[ERROR] Cannot connect to TrueNAS: {e}")
            return False
        except Exception as e:
            print(f"[ERROR] Error: {e}")
            return False

    def enable_ssh(self):
        """Enable SSH service"""
        print("\n[SETUP] Enabling SSH service...")

        # First, get current SSH config
        try:
            response = self.session.get(f"{self.base_url}/service/id/ssh")
            if response.status_code == 200:
                current_config = response.json()
                print(f"   Current SSH state: {current_config.get('state', 'Unknown')}")

            # Update SSH configuration
            ssh_config = {
                "tcpport": 22,
                "passwordauth": True,
                "tcpfwd": True,
                "rootlogin": True
            }

            response = self.session.put(
                f"{self.base_url}/ssh",
                json=ssh_config
            )

            if response.status_code == 200:
                print("   [OK] SSH configuration updated")
            else:
                print(f"   [WARN] SSH config update: HTTP {response.status_code}")
                print(f"   Response: {response.text}")

            # Start SSH service
            response = self.session.post(
                f"{self.base_url}/service/start",
                json={"service": "ssh"}
            )

            if response.status_code == 200:
                print("   [OK] SSH service started!")
                return True
            else:
                print(f"   [WARN] SSH start: HTTP {response.status_code}")
                print(f"   Response: {response.text}")

                # Try to enable and start
                response = self.session.put(
                    f"{self.base_url}/service/id/ssh",
                    json={"enable": True}
                )
                if response.status_code == 200:
                    print("   [OK] SSH service enabled!")
                    return True

        except Exception as e:
            print(f"   [ERROR] Error enabling SSH: {e}")
            return False

        return False

    def create_api_key(self, key_name="windows-automation"):
        """Create API key for automation"""
        print(f"\n[KEY] Creating API key '{key_name}'...")

        try:
            # Check if key already exists
            response = self.session.get(f"{self.base_url}/api_key")
            if response.status_code == 200:
                existing_keys = response.json()
                for key in existing_keys:
                    if key.get('name') == key_name:
                        print(f"   [WARN] API key '{key_name}' already exists")
                        print(f"   Key ID: {key.get('id')}")
                        return None

            # Create new API key
            response = self.session.post(
                f"{self.base_url}/api_key",
                json={"name": key_name}
            )

            if response.status_code == 200:
                result = response.json()
                api_key = result.get('key')
                print(f"   [OK] API key created successfully!")
                print(f"\n   [WARN] SAVE THIS KEY - You won't see it again!")
                print(f"   API Key: {api_key}")
                print(f"\n   Add this to your .env file:")
                print(f"   TRUENAS_API_KEY={api_key}")
                return api_key
            else:
                print(f"   [ERROR] Failed to create API key: HTTP {response.status_code}")
                print(f"   Response: {response.text}")
                return None

        except Exception as e:
            print(f"   [ERROR] Error creating API key: {e}")
            return None

    def change_root_password(self, new_password):
        """Change root user password"""
        print("\n[PASSWORD] Changing root password...")

        try:
            # Get root user ID
            response = self.session.get(f"{self.base_url}/user?username=root")
            if response.status_code != 200:
                print(f"   [ERROR] Cannot find root user: HTTP {response.status_code}")
                return False

            users = response.json()
            if not users:
                print("   [ERROR] Root user not found")
                return False

            root_user = users[0]
            user_id = root_user['id']

            # Update password
            response = self.session.put(
                f"{self.base_url}/user/id/{user_id}",
                json={"password": new_password}
            )

            if response.status_code == 200:
                print("   [OK] Root password changed successfully!")
                print("   [WARN] Update your .env file with the new password")
                return True
            else:
                print(f"   [ERROR] Failed to change password: HTTP {response.status_code}")
                print(f"   Response: {response.text}")
                return False

        except Exception as e:
            print(f"   [ERROR] Error changing password: {e}")
            return False


def main():
    print("=" * 60)
    print("TrueNAS Automated Setup")
    print("=" * 60)

    # Get credentials
    host = "172.31.69.40"
    username = "root"
    old_password = "uppercut%$##"
    new_password = "n=I-PT:x>FU!}gjMPN/AM[D8"

    print(f"\nTarget: https://{host}")
    print(f"Username: {username}")
    print(f"Using password from environment...")

    # Initialize setup
    setup = TrueNASSetup(host, username, old_password)

    # Test connection
    if not setup.test_connection():
        print("\n[ERROR] Cannot connect to TrueNAS. Please check:")
        print("   1. Is the VM running?")
        print("   2. Is the IP address correct?")
        print("   3. Is the password correct?")
        sys.exit(1)

    # Enable SSH
    setup.enable_ssh()

    # Change password
    change_pw = input("\n[WARN] Change root password? (yes/no): ")
    if change_pw.lower() == 'yes':
        setup.change_root_password(new_password)
        print("\n[WARN] Password changed! Reconnecting with new password...")
        setup = TrueNASSetup(host, username, new_password)

    # Create API key
    create_key = input("\n[WARN] Create API key? (yes/no): ")
    if create_key.lower() == 'yes':
        api_key = setup.create_api_key()

        if api_key:
            # Save to file for easy copying
            with open("D:\\workspace\\Baby_Nas\\api-key.txt", "w") as f:
                f.write(f"TRUENAS_API_KEY={api_key}\n")
            print(f"\n   [FILE] API key also saved to: D:\\workspace\\Baby_Nas\\api-key.txt")

    print("\n" + "=" * 60)
    print("[OK] Setup Complete!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Update .env file with new credentials")
    print("2. Test SSH: ssh root@172.31.69.40")
    print("3. Run: .\\setup-ssh-keys-complete.ps1")
    print("4. Run: .\\test-baby-nas-complete.ps1")


if __name__ == "__main__":
    main()
