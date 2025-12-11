#!/usr/bin/env python3
"""
Test script to validate TrueNAS API tools installation and configuration
Run this after setup to ensure everything is working correctly.
"""

import sys
import os
from pathlib import Path
import importlib.util

def check_color(text, status):
    """Add color to output"""
    colors = {
        'ok': '\033[92m',      # Green
        'fail': '\033[91m',    # Red
        'warning': '\033[93m', # Yellow
        'info': '\033[94m',    # Blue
        'end': '\033[0m'       # Reset
    }
    color = colors.get(status, colors['end'])
    return f"{color}{text}{colors['end']}"

def test_python_version():
    """Check Python version"""
    print("\n[1/6] Checking Python version...")
    version = sys.version_info
    if version.major == 3 and version.minor >= 8:
        print(check_color(f"  ✓ Python {version.major}.{version.minor}.{version.micro}", 'ok'))
        return True
    else:
        print(check_color(f"  ✗ Python {version.major}.{version.minor}.{version.micro} (need 3.8+)", 'fail'))
        return False

def test_dependencies():
    """Check required packages"""
    print("\n[2/6] Checking dependencies...")
    required = ['requests', 'urllib3', 'rich', 'click', 'tabulate', 'dateutil']
    missing = []

    for package in required:
        try:
            if package == 'dateutil':
                __import__('dateutil')
            else:
                __import__(package)
            print(check_color(f"  ✓ {package}", 'ok'))
        except ImportError:
            print(check_color(f"  ✗ {package} (missing)", 'fail'))
            missing.append(package)

    if missing:
        print(check_color(f"\n  Missing packages: {', '.join(missing)}", 'fail'))
        print(check_color("  Install with: pip install -r requirements.txt", 'info'))
        return False
    return True

def test_config_file():
    """Check configuration file"""
    print("\n[3/6] Checking configuration...")
    config_path = Path.home() / ".truenas" / "config.json"

    if not config_path.exists():
        print(check_color(f"  ✗ Config not found: {config_path}", 'fail'))
        print(check_color("  Run: python truenas-api-setup.py --setup", 'info'))
        return False

    print(check_color(f"  ✓ Config found: {config_path}", 'ok'))

    # Try to load and validate config
    try:
        import json
        with open(config_path, 'r') as f:
            config = json.load(f)

        required_keys = ['host', 'api_key']
        for key in required_keys:
            if key in config:
                print(check_color(f"  ✓ {key}: configured", 'ok'))
            else:
                print(check_color(f"  ✗ {key}: missing", 'fail'))
                return False
        return True
    except Exception as e:
        print(check_color(f"  ✗ Error reading config: {e}", 'fail'))
        return False

def test_api_connection():
    """Test API connection"""
    print("\n[4/6] Testing API connection...")

    try:
        import requests
        import json
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        config_path = Path.home() / ".truenas" / "config.json"
        with open(config_path, 'r') as f:
            config = json.load(f)

        url = f"https://{config['host']}/api/v2.0/system/info"
        headers = {
            "Authorization": f"Bearer {config['api_key']}",
            "Content-Type": "application/json"
        }

        response = requests.get(url, headers=headers, verify=False, timeout=10)
        response.raise_for_status()

        info = response.json()
        print(check_color(f"  ✓ Connected to {info.get('hostname', 'TrueNAS')}", 'ok'))
        print(check_color(f"  ✓ Version: {info.get('version', 'Unknown')}", 'ok'))
        return True
    except FileNotFoundError:
        print(check_color("  ✗ Config file not found", 'fail'))
        return False
    except requests.exceptions.ConnectionError:
        print(check_color(f"  ✗ Cannot connect to {config.get('host', 'TrueNAS')}", 'fail'))
        print(check_color("  Check if TrueNAS is running and accessible", 'warning'))
        return False
    except requests.exceptions.HTTPError as e:
        print(check_color(f"  ✗ API error: {e}", 'fail'))
        print(check_color("  Check if API key is valid", 'warning'))
        return False
    except Exception as e:
        print(check_color(f"  ✗ Connection failed: {e}", 'fail'))
        return False

def test_tools_exist():
    """Check if all tools exist"""
    print("\n[5/6] Checking tool files...")
    tools = [
        'truenas-api-setup.py',
        'truenas-manager.py',
        'truenas-dashboard.py',
        'truenas-snapshot-manager.py',
        'truenas-replication-manager.py',
        'truenas-api-examples.py'
    ]

    script_dir = Path(__file__).parent
    all_exist = True

    for tool in tools:
        tool_path = script_dir / tool
        if tool_path.exists():
            print(check_color(f"  ✓ {tool}", 'ok'))
        else:
            print(check_color(f"  ✗ {tool} (missing)", 'fail'))
            all_exist = False

    return all_exist

def test_tool_import():
    """Test if tools can be imported"""
    print("\n[6/6] Testing tool imports...")

    script_dir = Path(__file__).parent
    sys.path.insert(0, str(script_dir))

    tools = {
        'truenas-manager.py': 'TrueNASManager',
        'truenas-dashboard.py': 'TrueNASDashboard',
        'truenas-snapshot-manager.py': 'SnapshotManager',
        'truenas-replication-manager.py': 'ReplicationManager'
    }

    all_import = True
    for tool, class_name in tools.items():
        try:
            # Load module
            spec = importlib.util.spec_from_file_location(
                tool.replace('.py', '').replace('-', '_'),
                script_dir / tool
            )
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)

            # Check if class exists
            if hasattr(module, class_name):
                print(check_color(f"  ✓ {tool} ({class_name})", 'ok'))
            else:
                print(check_color(f"  ✗ {tool} (class {class_name} not found)", 'fail'))
                all_import = False
        except Exception as e:
            print(check_color(f"  ✗ {tool} (import error: {e})", 'fail'))
            all_import = False

    return all_import

def main():
    """Run all tests"""
    print("="*60)
    print("  TrueNAS API Tools - Installation Test")
    print("="*60)

    tests = [
        ("Python Version", test_python_version),
        ("Dependencies", test_dependencies),
        ("Configuration", test_config_file),
        ("API Connection", test_api_connection),
        ("Tool Files", test_tools_exist),
        ("Tool Imports", test_tool_import)
    ]

    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print(check_color(f"  ✗ Unexpected error: {e}", 'fail'))
            results.append((name, False))

    # Summary
    print("\n" + "="*60)
    print("  Test Summary")
    print("="*60)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for name, result in results:
        status = check_color("PASS", 'ok') if result else check_color("FAIL", 'fail')
        print(f"  {name}: {status}")

    print("\n" + "="*60)
    if passed == total:
        print(check_color(f"  ✓ All tests passed ({passed}/{total})", 'ok'))
        print("="*60)
        print("\nYou're ready to use the TrueNAS API tools!")
        print("\nNext steps:")
        print("  1. Try the dashboard: python truenas-dashboard.py")
        print("  2. List pools: python truenas-manager.py pool list")
        print("  3. View examples: python truenas-api-examples.py")
        return 0
    else:
        print(check_color(f"  ✗ {total - passed} test(s) failed ({passed}/{total} passed)", 'fail'))
        print("="*60)
        print("\nPlease fix the issues above before using the tools.")
        if not results[1][1]:  # Dependencies failed
            print("\nTo install dependencies:")
            print("  pip install -r requirements.txt")
        if not results[2][1]:  # Config failed
            print("\nTo configure TrueNAS API access:")
            print("  python truenas-api-setup.py --setup")
        return 1

if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        sys.exit(1)
