#!/usr/bin/env python3
"""
TrueNAS SCALE API Setup and Management Script
This script helps configure and test TrueNAS API access from Windows
"""

import os
import sys
import json
import requests
import getpass
from pathlib import Path
from typing import Optional, Dict, Any

# Disable SSL warnings for self-signed certificates
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class TrueNASAPI:
    """TrueNAS SCALE API Client"""

    def __init__(self, host: str, api_key: Optional[str] = None, verify_ssl: bool = False):
        self.host = host.rstrip('/')
        self.api_key = api_key
        self.verify_ssl = verify_ssl
        self.base_url = f"https://{self.host}/api/v2.0"

    def _get_headers(self) -> Dict[str, str]:
        """Get request headers with authentication"""
        headers = {
            "Content-Type": "application/json"
        }
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers

    def test_connection(self) -> bool:
        """Test API connection"""
        try:
            response = requests.get(
                f"{self.base_url}/system/info",
                headers=self._get_headers(),
                verify=self.verify_ssl,
                timeout=10
            )
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"Connection test failed: {e}")
            return False

    def get_system_info(self) -> Optional[Dict[str, Any]]:
        """Get system information"""
        try:
            response = requests.get(
                f"{self.base_url}/system/info",
                headers=self._get_headers(),
                verify=self.verify_ssl
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Failed to get system info: {e}")
            return None

    def get_pools(self) -> Optional[list]:
        """Get all storage pools"""
        try:
            response = requests.get(
                f"{self.base_url}/pool",
                headers=self._get_headers(),
                verify=self.verify_ssl
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Failed to get pools: {e}")
            return None

    def get_datasets(self, pool_name: str = None) -> Optional[list]:
        """Get all datasets"""
        try:
            response = requests.get(
                f"{self.base_url}/pool/dataset",
                headers=self._get_headers(),
                verify=self.verify_ssl
            )
            response.raise_for_status()
            datasets = response.json()

            if pool_name:
                datasets = [d for d in datasets if d['name'].startswith(pool_name)]

            return datasets
        except Exception as e:
            print(f"Failed to get datasets: {e}")
            return None

    def get_smb_shares(self) -> Optional[list]:
        """Get all SMB shares"""
        try:
            response = requests.get(
                f"{self.base_url}/sharing/smb",
                headers=self._get_headers(),
                verify=self.verify_ssl
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Failed to get SMB shares: {e}")
            return None

    def get_disk_info(self) -> Optional[list]:
        """Get disk information"""
        try:
            response = requests.get(
                f"{self.base_url}/disk",
                headers=self._get_headers(),
                verify=self.verify_ssl
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Failed to get disk info: {e}")
            return None

    def create_api_key(self, username: str, password: str, key_name: str = "windows-automation") -> Optional[str]:
        """Create a new API key"""
        try:
            # First, authenticate to get a session
            auth_response = requests.post(
                f"{self.base_url}/auth/login",
                json={"username": username, "password": password},
                verify=self.verify_ssl
            )
            auth_response.raise_for_status()

            # Use the session to create API key
            headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {auth_response.json()['token']}"
            }

            key_response = requests.post(
                f"{self.base_url}/api_key",
                headers=headers,
                json={"name": key_name},
                verify=self.verify_ssl
            )
            key_response.raise_for_status()

            return key_response.json()['key']
        except Exception as e:
            print(f"Failed to create API key: {e}")
            return None


def save_config(config: Dict[str, Any], config_path: Path):
    """Save configuration to file"""
    config_path.parent.mkdir(parents=True, exist_ok=True)
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"✓ Configuration saved to: {config_path}")


def load_config(config_path: Path) -> Optional[Dict[str, Any]]:
    """Load configuration from file"""
    if config_path.exists():
        with open(config_path, 'r') as f:
            return json.load(f)
    return None


def display_system_status(api: TrueNASAPI):
    """Display comprehensive system status"""
    print("\n" + "="*60)
    print("  TrueNAS SCALE System Status")
    print("="*60 + "\n")

    # System Info
    sys_info = api.get_system_info()
    if sys_info:
        print("System Information:")
        print(f"  Hostname: {sys_info.get('hostname', 'N/A')}")
        print(f"  Version: {sys_info.get('version', 'N/A')}")
        print(f"  Uptime: {sys_info.get('uptime_seconds', 0) / 3600:.1f} hours")
        print(f"  Model: {sys_info.get('system_product', 'N/A')}")
        print()

    # Storage Pools
    pools = api.get_pools()
    if pools:
        print("Storage Pools:")
        for pool in pools:
            status = pool.get('status', 'UNKNOWN')
            status_icon = "✓" if status == "ONLINE" else "✗"
            size_gb = pool.get('size', 0) / (1024**3)
            used_gb = pool.get('allocated', 0) / (1024**3)
            free_gb = size_gb - used_gb
            usage_pct = (used_gb / size_gb * 100) if size_gb > 0 else 0

            print(f"  {status_icon} {pool['name']}")
            print(f"      Status: {status}")
            print(f"      Size: {size_gb:.1f} GB")
            print(f"      Used: {used_gb:.1f} GB ({usage_pct:.1f}%)")
            print(f"      Free: {free_gb:.1f} GB")
            print(f"      Health: {pool.get('healthy', 'Unknown')}")
            print()

    # Datasets
    datasets = api.get_datasets()
    if datasets:
        print(f"Datasets: {len(datasets)} total")
        for ds in datasets[:5]:  # Show first 5
            used_gb = ds.get('used', {}).get('parsed', 0) / (1024**3)
            available_gb = ds.get('available', {}).get('parsed', 0) / (1024**3)
            compression = ds.get('compression', {}).get('value', 'N/A')
            print(f"  • {ds['name']}")
            print(f"      Used: {used_gb:.2f} GB, Available: {available_gb:.2f} GB")
            print(f"      Compression: {compression}")
        if len(datasets) > 5:
            print(f"  ... and {len(datasets) - 5} more")
        print()

    # SMB Shares
    shares = api.get_smb_shares()
    if shares:
        print(f"SMB Shares: {len(shares)} configured")
        for share in shares:
            enabled_icon = "✓" if share.get('enabled') else "✗"
            print(f"  {enabled_icon} {share.get('name', 'N/A')}")
            print(f"      Path: {share.get('path', 'N/A')}")
            print(f"      Description: {share.get('comment', 'N/A')}")
        print()

    # Disks
    disks = api.get_disk_info()
    if disks:
        print(f"Disks: {len(disks)} total")
        for disk in disks:
            size_gb = disk.get('size', 0) / (1024**3)
            disk_type = disk.get('type', 'UNKNOWN')
            print(f"  • {disk.get('name', 'N/A')} ({disk.get('model', 'N/A')})")
            print(f"      Size: {size_gb:.1f} GB, Type: {disk_type}")
            print(f"      Serial: {disk.get('serial', 'N/A')}")
        print()


def interactive_setup():
    """Interactive setup wizard"""
    print("\n" + "="*60)
    print("  TrueNAS API Configuration Wizard")
    print("="*60 + "\n")

    # Get TrueNAS connection details
    truenas_ip = input("Enter TrueNAS IP address: ").strip()
    username = input("Enter username [jdmal]: ").strip() or "jdmal"
    password = getpass.getpass("Enter password: ")

    print("\n[1/3] Testing connection...")
    api = TrueNASAPI(truenas_ip)

    # Try to create API key using credentials
    print("[2/3] Creating API key...")
    print("\nNote: If this fails, create an API key manually:")
    print("  1. Log into TrueNAS Web UI")
    print("  2. Go to: Credentials → API Keys")
    print("  3. Click 'Add'")
    print("  4. Name: 'windows-automation'")
    print("  5. Copy the generated key")
    print()

    api_key = api.create_api_key(username, password, "windows-automation")

    if not api_key:
        print("Automatic API key creation failed.")
        api_key = input("Paste your API key from the Web UI: ").strip()

    if not api_key:
        print("✗ No API key provided. Setup incomplete.")
        return

    # Test API key
    api.api_key = api_key
    print("[3/3] Testing API key...")
    if api.test_connection():
        print("✓ API key is valid!")

        # Save configuration
        config_dir = Path.home() / ".truenas"
        config_path = config_dir / "config.json"

        config = {
            "host": truenas_ip,
            "api_key": api_key,
            "username": username,
            "verify_ssl": False
        }

        save_config(config, config_path)

        # Display system status
        display_system_status(api)

        print("\n" + "="*60)
        print("  Setup Complete!")
        print("="*60)
        print(f"\nConfiguration saved to: {config_path}")
        print("\nYou can now use the TrueNAS API programmatically:")
        print("  python truenas-api-setup.py --status")
        print("  python truenas-api-setup.py --pools")
        print("  python truenas-api-setup.py --shares")
        print()

    else:
        print("✗ API key test failed. Please check your configuration.")


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description="TrueNAS API Setup and Management")
    parser.add_argument("--setup", action="store_true", help="Run interactive setup")
    parser.add_argument("--status", action="store_true", help="Display system status")
    parser.add_argument("--pools", action="store_true", help="List storage pools")
    parser.add_argument("--shares", action="store_true", help="List SMB shares")
    parser.add_argument("--datasets", action="store_true", help="List datasets")
    parser.add_argument("--config", type=str, help="Path to config file")

    args = parser.parse_args()

    # Determine config path
    if args.config:
        config_path = Path(args.config)
    else:
        config_path = Path.home() / ".truenas" / "config.json"

    # Run setup if requested or no config exists
    if args.setup or not config_path.exists():
        interactive_setup()
        return

    # Load existing configuration
    config = load_config(config_path)
    if not config:
        print("No configuration found. Run with --setup first.")
        return

    # Create API client
    api = TrueNASAPI(
        config["host"],
        config["api_key"],
        config.get("verify_ssl", False)
    )

    # Execute requested action
    if args.status:
        display_system_status(api)

    elif args.pools:
        pools = api.get_pools()
        if pools:
            print(json.dumps(pools, indent=2))

    elif args.shares:
        shares = api.get_smb_shares()
        if shares:
            print(json.dumps(shares, indent=2))

    elif args.datasets:
        datasets = api.get_datasets()
        if datasets:
            print(json.dumps(datasets, indent=2))

    else:
        # Default: show status
        display_system_status(api)


if __name__ == "__main__":
    main()
