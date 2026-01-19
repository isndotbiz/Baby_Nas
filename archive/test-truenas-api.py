#!/usr/bin/env python3
"""
Test TrueNAS API Connection
Verifies that API key and SSH are working
"""

import requests
import urllib3
import os
import subprocess

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Load from .env
def load_env():
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    config = {}

    if not os.path.exists(env_path):
        print("[ERROR] .env file not found!")
        return None

    with open(env_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                config[key.strip()] = value.strip()

    return config

def test_api(config):
    """Test API connection with API key"""
    print("\n[1] Testing TrueNAS API Connection...")

    ip = config.get('TRUENAS_IP')
    api_key = config.get('TRUENAS_API_KEY')

    if not api_key:
        print("    [WARN] No API key found in .env file")
        print("    Please create one via Web UI: System -> API Keys")
        return False

    url = f"https://{ip}/api/v2.0/system/info"
    headers = {"Authorization": f"Bearer {api_key}"}

    try:
        response = requests.get(url, headers=headers, verify=False, timeout=10)

        if response.status_code == 200:
            info = response.json()
            print(f"    [OK] Connected to TrueNAS!")
            print(f"    Version: {info.get('version', 'Unknown')}")
            print(f"    Hostname: {info.get('hostname', 'Unknown')}")
            print(f"    Uptime: {info.get('uptime_seconds', 0) / 3600:.1f} hours")
            return True
        else:
            print(f"    [ERROR] API returned: {response.status_code}")
            print(f"    Response: {response.text[:200]}")
            return False

    except Exception as e:
        print(f"    [ERROR] {e}")
        return False

def test_ssh(config):
    """Test SSH connection"""
    print("\n[2] Testing SSH Connection...")

    ip = config.get('TRUENAS_IP')
    username = config.get('TRUENAS_USERNAME', 'root')
    password = config.get('TRUENAS_PASSWORD')

    try:
        # Test if SSH port is open
        result = subprocess.run(
            ['powershell', '-Command',
             f'Test-NetConnection -ComputerName {ip} -Port 22 -InformationLevel Quiet'],
            capture_output=True,
            text=True,
            timeout=10
        )

        if 'True' in result.stdout:
            print(f"    [OK] SSH port 22 is open")
            print(f"    You can connect with: ssh {username}@{ip}")
            return True
        else:
            print(f"    [ERROR] SSH port 22 is closed or filtered")
            print(f"    Enable SSH in Web UI: System -> Services -> SSH")
            return False

    except Exception as e:
        print(f"    [ERROR] {e}")
        return False

def test_web_ui(config):
    """Test Web UI access"""
    print("\n[3] Testing Web UI Access...")

    ip = config.get('TRUENAS_IP')

    try:
        response = requests.get(f"https://{ip}", verify=False, timeout=10)

        if response.status_code == 200:
            print(f"    [OK] Web UI is accessible at: https://{ip}")
            return True
        else:
            print(f"    [WARN] Web UI returned: {response.status_code}")
            return False

    except Exception as e:
        print(f"    [ERROR] {e}")
        return False

def check_config(config):
    """Check .env configuration"""
    print("\n[0] Checking Configuration...")

    required = ['TRUENAS_IP', 'TRUENAS_USERNAME', 'TRUENAS_PASSWORD']
    optional = ['TRUENAS_API_KEY']

    all_good = True

    for key in required:
        if key in config and config[key]:
            print(f"    [OK] {key}: {config[key]}")
        else:
            print(f"    [ERROR] {key}: NOT SET")
            all_good = False

    for key in optional:
        if key in config and config[key]:
            # Mask API key for security
            masked = config[key][:10] + '...' if len(config[key]) > 10 else config[key]
            print(f"    [OK] {key}: {masked}")
        else:
            print(f"    [WARN] {key}: NOT SET (optional but recommended)")

    return all_good

def main():
    print("=" * 60)
    print("TrueNAS Connection Test")
    print("=" * 60)

    config = load_env()

    if not config:
        print("\n[ERROR] Could not load .env file")
        print("Make sure D:\\workspace\\Baby_Nas\\.env exists")
        return

    # Check configuration
    if not check_config(config):
        print("\n[ERROR] Configuration incomplete!")
        print("Please update your .env file with required values")
        return

    # Run tests
    web_ui_ok = test_web_ui(config)
    ssh_ok = test_ssh(config)
    api_ok = test_api(config)

    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    print(f"  Web UI:  {'[OK]' if web_ui_ok else '[FAIL]'}")
    print(f"  SSH:     {'[OK]' if ssh_ok else '[FAIL]'}")
    print(f"  API:     {'[OK]' if api_ok else '[FAIL]'}")

    if web_ui_ok and ssh_ok and api_ok:
        print("\n[OK] All tests passed! Baby NAS is ready!")
        print("\nNext steps:")
        print("  1. Run: .\\setup-ssh-keys-complete.ps1")
        print("  2. Run: .\\setup-snapshots-auto.ps1")
        print("  3. Run: .\\backup-workspace.ps1")
    else:
        print("\n[WARN] Some tests failed. Please check the output above.")
        print("\nMissing setup:")
        if not ssh_ok:
            print("  - Enable SSH in Web UI (System -> Services)")
        if not api_ok:
            print("  - Create API key in Web UI (System -> API Keys)")
            print("  - Add API key to .env file")

    print("=" * 60)

if __name__ == "__main__":
    main()
