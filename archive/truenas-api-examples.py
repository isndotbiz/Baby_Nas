#!/usr/bin/env python3
"""
TrueNAS API Examples - Code examples and best practices
Demonstrates common tasks with well-documented code and best practices.
"""

import json
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List

import requests
import urllib3

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class TrueNASAPIClient:
    """
    TrueNAS API Client - Base class for API interactions

    Example usage:
        client = TrueNASAPIClient.from_config()
        pools = client.get('pool')
        print(json.dumps(pools, indent=2))
    """

    def __init__(self, host: str, api_key: str, verify_ssl: bool = False):
        """
        Initialize API client

        Args:
            host: TrueNAS host IP or hostname
            api_key: API key for authentication
            verify_ssl: Whether to verify SSL certificates (default: False for self-signed)
        """
        self.host = host
        self.api_key = api_key
        self.verify_ssl = verify_ssl
        self.base_url = f"https://{host}/api/v2.0"

    @classmethod
    def from_config(cls, config_path: Optional[Path] = None) -> 'TrueNASAPIClient':
        """
        Create client from config file

        Args:
            config_path: Path to config file (default: ~/.truenas/config.json)

        Returns:
            TrueNASAPIClient instance
        """
        if config_path is None:
            config_path = Path.home() / ".truenas" / "config.json"

        with open(config_path, 'r') as f:
            config = json.load(f)

        return cls(
            host=config['host'],
            api_key=config['api_key'],
            verify_ssl=config.get('verify_ssl', False)
        )

    def _get_headers(self) -> Dict[str, str]:
        """Get request headers with authentication"""
        return {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }

    def get(self, endpoint: str, **kwargs) -> Any:
        """
        Make GET request

        Args:
            endpoint: API endpoint (without /api/v2.0 prefix)
            **kwargs: Additional arguments for requests.get()

        Returns:
            JSON response data
        """
        url = f"{self.base_url}/{endpoint}"
        response = requests.get(
            url,
            headers=self._get_headers(),
            verify=self.verify_ssl,
            **kwargs
        )
        response.raise_for_status()
        return response.json()

    def post(self, endpoint: str, data: Optional[Dict[str, Any]] = None, **kwargs) -> Any:
        """
        Make POST request

        Args:
            endpoint: API endpoint
            data: JSON data to send
            **kwargs: Additional arguments for requests.post()

        Returns:
            JSON response data
        """
        url = f"{self.base_url}/{endpoint}"
        response = requests.post(
            url,
            headers=self._get_headers(),
            json=data,
            verify=self.verify_ssl,
            **kwargs
        )
        response.raise_for_status()
        return response.json()

    def put(self, endpoint: str, data: Optional[Dict[str, Any]] = None, **kwargs) -> Any:
        """Make PUT request"""
        url = f"{self.base_url}/{endpoint}"
        response = requests.put(
            url,
            headers=self._get_headers(),
            json=data,
            verify=self.verify_ssl,
            **kwargs
        )
        response.raise_for_status()
        return response.json()

    def delete(self, endpoint: str, **kwargs) -> Any:
        """Make DELETE request"""
        url = f"{self.base_url}/{endpoint}"
        response = requests.delete(
            url,
            headers=self._get_headers(),
            verify=self.verify_ssl,
            **kwargs
        )
        response.raise_for_status()
        return response.json() if response.content else None


# ==================== Example Functions ====================


def example_1_get_system_info():
    """
    Example 1: Get system information

    Demonstrates basic API query to retrieve system details.
    """
    print("\n" + "="*60)
    print("Example 1: Get System Information")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Get system info
    sys_info = client.get('system/info')

    print(f"Hostname: {sys_info['hostname']}")
    print(f"Version: {sys_info['version']}")
    print(f"Uptime: {sys_info['uptime_seconds'] / 3600:.1f} hours")
    print(f"Model: {sys_info.get('system_product', 'N/A')}")
    print(f"Memory: {sys_info.get('physmem', 0) / (1024**3):.1f} GB")


def example_2_list_pools_and_usage():
    """
    Example 2: List storage pools and their usage

    Demonstrates iterating over pools and calculating usage percentages.
    """
    print("\n" + "="*60)
    print("Example 2: List Storage Pools and Usage")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Get all pools
    pools = client.get('pool')

    for pool in pools:
        name = pool['name']
        size_gb = pool['size'] / (1024**3)
        allocated_gb = pool['allocated'] / (1024**3)
        usage_pct = (allocated_gb / size_gb * 100) if size_gb > 0 else 0

        print(f"\nPool: {name}")
        print(f"  Status: {pool['status']}")
        print(f"  Size: {size_gb:.1f} GB")
        print(f"  Used: {allocated_gb:.1f} GB ({usage_pct:.1f}%)")
        print(f"  Health: {pool.get('healthy', 'Unknown')}")


def example_3_create_dataset():
    """
    Example 3: Create a new dataset

    Demonstrates creating a dataset with specific properties.
    """
    print("\n" + "="*60)
    print("Example 3: Create Dataset")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Define dataset
    dataset_path = "tank/example-dataset"  # Change to your pool name

    # Dataset properties
    dataset_config = {
        'name': dataset_path,
        'type': 'FILESYSTEM',
        'compression': 'LZ4',
        'atime': 'off',  # Disable access time updates for better performance
        'quota': None,  # No quota limit
        'recordsize': '128K',  # Good for general use
        'comments': 'Created via API example'
    }

    print(f"Creating dataset: {dataset_path}")
    print(f"Configuration: {json.dumps(dataset_config, indent=2)}")

    # Uncomment to actually create the dataset
    # result = client.post('pool/dataset', dataset_config)
    # print(f"Created: {result['name']}")

    print("\nNote: Uncomment the code to actually create the dataset")


def example_4_create_snapshot():
    """
    Example 4: Create snapshots with timestamps

    Demonstrates creating named snapshots with custom naming scheme.
    """
    print("\n" + "="*60)
    print("Example 4: Create Snapshot")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Snapshot configuration
    dataset = "tank/important-data"  # Change to your dataset
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    snapshot_name = f"backup-{timestamp}"

    snapshot_config = {
        'dataset': dataset,
        'name': snapshot_name,
        'recursive': True,  # Include child datasets
        'properties': {
            'org.truenas:comment': 'Automated backup snapshot'
        }
    }

    print(f"Creating snapshot: {dataset}@{snapshot_name}")
    print(f"Configuration: {json.dumps(snapshot_config, indent=2)}")

    # Uncomment to actually create snapshot
    # result = client.post('zfs/snapshot', snapshot_config)
    # print(f"Created: {result['name']}")

    print("\nNote: Uncomment the code to actually create the snapshot")


def example_5_list_recent_snapshots():
    """
    Example 5: List recent snapshots

    Demonstrates filtering and sorting snapshots.
    """
    print("\n" + "="*60)
    print("Example 5: List Recent Snapshots")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Get all snapshots
    snapshots = client.get('zfs/snapshot')

    # Sort by creation time (newest first)
    snapshots.sort(
        key=lambda s: s.get('properties', {}).get('creation', {}).get('value', ''),
        reverse=True
    )

    # Show top 10
    print(f"\nMost recent 10 snapshots:")
    for i, snap in enumerate(snapshots[:10], 1):
        creation_str = snap.get('properties', {}).get('creation', {}).get('value', '')
        try:
            creation_time = datetime.fromisoformat(creation_str)
            created = creation_time.strftime('%Y-%m-%d %H:%M:%S')
        except:
            created = 'Unknown'

        used_gb = snap.get('properties', {}).get('used', {}).get('parsed', 0) / (1024**3)

        print(f"{i}. {snap['name']}")
        print(f"   Created: {created}, Used: {used_gb:.3f} GB")


def example_6_cleanup_old_snapshots():
    """
    Example 6: Clean up old snapshots

    Demonstrates implementing a retention policy to delete old snapshots.
    """
    print("\n" + "="*60)
    print("Example 6: Cleanup Old Snapshots")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Configuration
    dataset = "tank/data"  # Change to your dataset
    retention_days = 30

    print(f"Finding snapshots older than {retention_days} days for dataset: {dataset}")

    # Get snapshots for dataset
    all_snapshots = client.get('zfs/snapshot')
    dataset_snapshots = [s for s in all_snapshots if s['dataset'] == dataset]

    # Calculate cutoff date
    cutoff_date = datetime.now() - timedelta(days=retention_days)

    # Find old snapshots
    old_snapshots = []
    for snap in dataset_snapshots:
        creation_str = snap.get('properties', {}).get('creation', {}).get('value', '')
        try:
            creation_time = datetime.fromisoformat(creation_str)
            if creation_time < cutoff_date:
                old_snapshots.append(snap)
        except:
            pass

    print(f"\nFound {len(old_snapshots)} snapshots older than {retention_days} days")

    if old_snapshots:
        print("\nSnapshots to delete:")
        for snap in old_snapshots[:5]:  # Show first 5
            print(f"  - {snap['name']}")
        if len(old_snapshots) > 5:
            print(f"  ... and {len(old_snapshots) - 5} more")

    # Uncomment to actually delete
    # for snap in old_snapshots:
    #     client.delete(f"zfs/snapshot/id/{snap['id']}")
    #     print(f"Deleted: {snap['name']}")

    print("\nNote: Uncomment the code to actually delete snapshots")


def example_7_create_smb_share():
    """
    Example 7: Create SMB share

    Demonstrates creating an SMB share with proper permissions.
    """
    print("\n" + "="*60)
    print("Example 7: Create SMB Share")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # SMB share configuration
    share_config = {
        'path': '/mnt/tank/shared',  # Change to your path
        'name': 'SharedFolder',
        'comment': 'Shared folder created via API',
        'enabled': True,
        'guestok': False,  # Require authentication
        'browsable': True,
        'recyclebin': False,
        'hostsallow': [],  # Empty = allow all
        'hostsdeny': [],
        'aapl_name_mangling': False,
        'abe': False,  # Access Based Share Enumeration
        'acl': True,
        'ro': False,  # Read-only
        'streams': True,
        'timemachine': False,
        'vuid': '',
        'shadowcopy': True,
        'fsrvp': False
    }

    print(f"SMB Share Configuration:")
    print(json.dumps(share_config, indent=2))

    # Uncomment to create share
    # result = client.post('sharing/smb', share_config)
    # print(f"\nCreated share: {result['name']}")

    print("\nNote: Uncomment the code to actually create the share")


def example_8_monitor_replication():
    """
    Example 8: Monitor replication tasks

    Demonstrates checking replication status and handling errors.
    """
    print("\n" + "="*60)
    print("Example 8: Monitor Replication Tasks")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Get all replication tasks
    tasks = client.get('replication')

    print(f"\nTotal replication tasks: {len(tasks)}")

    # Categorize by state
    running = []
    success = []
    error = []
    never_run = []

    for task in tasks:
        state = task.get('state', {}).get('state', 'UNKNOWN')
        if state == 'RUNNING':
            running.append(task)
        elif state == 'SUCCESS':
            success.append(task)
        elif state in ['ERROR', 'FAILED']:
            error.append(task)
        elif not task.get('state', {}).get('datetime'):
            never_run.append(task)

    print(f"  Running: {len(running)}")
    print(f"  Success: {len(success)}")
    print(f"  Error: {len(error)}")
    print(f"  Never run: {len(never_run)}")

    if error:
        print("\nFailed tasks:")
        for task in error:
            print(f"  - {task.get('name', 'N/A')} (ID: {task['id']})")
            print(f"    Last run: {task.get('state', {}).get('datetime', 'Unknown')}")


def example_9_disk_health_check():
    """
    Example 9: Check disk health

    Demonstrates querying disk information and S.M.A.R.T. status.
    """
    print("\n" + "="*60)
    print("Example 9: Disk Health Check")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Get all disks
    disks = client.get('disk')

    print(f"\nTotal disks: {len(disks)}")

    for disk in disks:
        name = disk.get('name', 'N/A')
        model = disk.get('model', 'N/A')
        size_gb = disk.get('size', 0) / (1024**3)
        disk_type = disk.get('type', 'UNKNOWN')

        print(f"\nDisk: {name}")
        print(f"  Model: {model}")
        print(f"  Size: {size_gb:.1f} GB")
        print(f"  Type: {disk_type}")
        print(f"  Serial: {disk.get('serial', 'N/A')}")

        # Get SMART status if available
        # Note: This requires additional API call per disk
        # try:
        #     smart = client.get(f'disk/smart_attributes/{name}')
        #     print(f"  SMART Status: Available")
        # except:
        #     print(f"  SMART Status: Not available")


def example_10_backup_configuration():
    """
    Example 10: Backup TrueNAS configuration

    Demonstrates downloading system configuration for backup.
    """
    print("\n" + "="*60)
    print("Example 10: Backup Configuration")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Generate config backup
    # Note: This returns a download URL or configuration data
    print("Generating configuration backup...")

    # The actual endpoint and method may vary
    # This is a simplified example

    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    backup_filename = f"truenas-config-{timestamp}.db"

    print(f"Configuration would be saved to: {backup_filename}")
    print("\nNote: Refer to TrueNAS API documentation for exact backup endpoint")

    # Example of what the code might look like:
    # config_data = client.post('config/save')
    # with open(backup_filename, 'wb') as f:
    #     f.write(config_data)
    # print(f"Configuration backed up to {backup_filename}")


def example_11_service_management():
    """
    Example 11: Service management

    Demonstrates checking and controlling TrueNAS services.
    """
    print("\n" + "="*60)
    print("Example 11: Service Management")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Get all services
    services = client.get('service')

    # Filter important services
    important_services = ['smb', 'nfs', 'ssh', 'wireguard']

    print("\nImportant Services:")
    for svc in services:
        if svc.get('service') in important_services:
            name = svc.get('service', 'N/A').upper()
            state = svc.get('state', 'UNKNOWN')
            enabled = svc.get('enable', False)

            status_icon = "✓" if state == "RUNNING" else "✗"
            startup = "Enabled" if enabled else "Disabled"

            print(f"  {status_icon} {name}: {state} (Startup: {startup})")

    # Example: Start/stop a service (commented out for safety)
    # service_name = 'smb'
    # client.post(f'service/start', {'service': service_name})
    # print(f"Started {service_name}")


def example_12_alert_monitoring():
    """
    Example 12: Monitor system alerts

    Demonstrates retrieving and filtering system alerts.
    """
    print("\n" + "="*60)
    print("Example 12: System Alert Monitoring")
    print("="*60)

    client = TrueNASAPIClient.from_config()

    # Get active alerts
    alerts = client.get('alert/list')

    if not alerts:
        print("\nNo active alerts - system is healthy!")
        return

    print(f"\nActive alerts: {len(alerts)}")

    # Categorize by level
    critical = [a for a in alerts if a.get('level') == 'CRITICAL']
    warning = [a for a in alerts if a.get('level') == 'WARNING']
    info = [a for a in alerts if a.get('level') == 'INFO']

    if critical:
        print(f"\nCRITICAL alerts ({len(critical)}):")
        for alert in critical:
            print(f"  ✗ {alert.get('formatted', 'N/A')}")

    if warning:
        print(f"\nWARNING alerts ({len(warning)}):")
        for alert in warning:
            print(f"  ⚠ {alert.get('formatted', 'N/A')}")

    if info:
        print(f"\nINFO alerts ({len(info)}):")
        for alert in info[:5]:  # Show first 5
            print(f"  ℹ {alert.get('formatted', 'N/A')}")


# ==================== Main Menu ====================


def main():
    """Main menu for running examples"""
    examples = [
        ("Get System Information", example_1_get_system_info),
        ("List Pools and Usage", example_2_list_pools_and_usage),
        ("Create Dataset", example_3_create_dataset),
        ("Create Snapshot", example_4_create_snapshot),
        ("List Recent Snapshots", example_5_list_recent_snapshots),
        ("Cleanup Old Snapshots", example_6_cleanup_old_snapshots),
        ("Create SMB Share", example_7_create_smb_share),
        ("Monitor Replication", example_8_monitor_replication),
        ("Disk Health Check", example_9_disk_health_check),
        ("Backup Configuration", example_10_backup_configuration),
        ("Service Management", example_11_service_management),
        ("Alert Monitoring", example_12_alert_monitoring),
    ]

    print("\n" + "="*60)
    print("  TrueNAS API Examples")
    print("="*60)
    print("\nAvailable examples:")

    for i, (name, _) in enumerate(examples, 1):
        print(f"  {i}. {name}")

    print("\n  0. Run all examples")
    print("  q. Quit")

    while True:
        choice = input("\nSelect example (1-12, 0 for all, q to quit): ").strip()

        if choice.lower() == 'q':
            print("Goodbye!")
            break
        elif choice == '0':
            for name, func in examples:
                try:
                    func()
                except Exception as e:
                    print(f"Error in {name}: {e}")
            break
        elif choice.isdigit() and 1 <= int(choice) <= len(examples):
            try:
                _, func = examples[int(choice) - 1]
                func()
            except Exception as e:
                print(f"Error: {e}")
        else:
            print("Invalid choice")


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(0)
    except FileNotFoundError as e:
        print(f"\nError: {e}", file=sys.stderr)
        print("\nRun 'python truenas-api-setup.py --setup' first to configure API access")
        sys.exit(1)
    except Exception as e:
        print(f"\nUnexpected error: {e}", file=sys.stderr)
        sys.exit(1)
