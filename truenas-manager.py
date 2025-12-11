#!/usr/bin/env python3
"""
TrueNAS Manager - Comprehensive management tool for TrueNAS SCALE
Provides CLI interface for common operations including pool management,
datasets, snapshots, replication, SMB shares, and health monitoring.
"""

import os
import sys
import json
import click
import requests
from pathlib import Path
from typing import Optional, Dict, Any, List
from datetime import datetime
from tabulate import tabulate
import urllib3

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class TrueNASManager:
    """TrueNAS SCALE Management Client"""

    def __init__(self, config_path: Optional[Path] = None):
        if config_path is None:
            config_path = Path.home() / ".truenas" / "config.json"

        if not config_path.exists():
            raise FileNotFoundError(
                f"Configuration not found at {config_path}\n"
                "Run 'python truenas-api-setup.py --setup' first"
            )

        with open(config_path, 'r') as f:
            self.config = json.load(f)

        self.host = self.config['host']
        self.api_key = self.config['api_key']
        self.verify_ssl = self.config.get('verify_ssl', False)
        self.base_url = f"https://{self.host}/api/v2.0"

    def _get_headers(self) -> Dict[str, str]:
        """Get request headers with authentication"""
        return {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }

    def _make_request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        """Make API request with error handling"""
        url = f"{self.base_url}/{endpoint}"
        kwargs.setdefault('headers', self._get_headers())
        kwargs.setdefault('verify', self.verify_ssl)
        kwargs.setdefault('timeout', 30)

        try:
            response = requests.request(method, url, **kwargs)
            response.raise_for_status()
            return response
        except requests.exceptions.RequestException as e:
            click.echo(f"Error: API request failed: {e}", err=True)
            sys.exit(1)

    # ==================== Pool Management ====================

    def get_pools(self) -> List[Dict[str, Any]]:
        """Get all storage pools"""
        response = self._make_request('GET', 'pool')
        return response.json()

    def get_pool_status(self, pool_name: str) -> Dict[str, Any]:
        """Get detailed pool status"""
        pools = self.get_pools()
        for pool in pools:
            if pool['name'] == pool_name:
                return pool
        raise ValueError(f"Pool '{pool_name}' not found")

    def check_pool_capacity(self, threshold: int = 80) -> List[Dict[str, Any]]:
        """Check pools for capacity alerts"""
        pools = self.get_pools()
        alerts = []

        for pool in pools:
            size = pool.get('size', 0)
            allocated = pool.get('allocated', 0)
            if size > 0:
                usage_pct = (allocated / size) * 100
                if usage_pct >= threshold:
                    alerts.append({
                        'pool': pool['name'],
                        'usage_pct': usage_pct,
                        'used_gb': allocated / (1024**3),
                        'total_gb': size / (1024**3),
                        'status': pool.get('status', 'UNKNOWN')
                    })

        return alerts

    # ==================== Dataset Management ====================

    def get_datasets(self, pool_name: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get all datasets, optionally filtered by pool"""
        response = self._make_request('GET', 'pool/dataset')
        datasets = response.json()

        if pool_name:
            datasets = [d for d in datasets if d['name'].startswith(pool_name)]

        return datasets

    def create_dataset(self, path: str, properties: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Create a new dataset"""
        data = {'name': path}
        if properties:
            data.update(properties)

        response = self._make_request('POST', 'pool/dataset', json=data)
        return response.json()

    def delete_dataset(self, dataset_id: str, recursive: bool = False) -> bool:
        """Delete a dataset"""
        params = {'recursive': recursive}
        self._make_request('DELETE', f'pool/dataset/id/{dataset_id}', params=params)
        return True

    def set_dataset_properties(self, dataset_id: str, properties: Dict[str, Any]) -> Dict[str, Any]:
        """Set dataset properties"""
        response = self._make_request('PUT', f'pool/dataset/id/{dataset_id}', json=properties)
        return response.json()

    # ==================== Snapshot Management ====================

    def get_snapshots(self, dataset: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get all snapshots, optionally filtered by dataset"""
        response = self._make_request('GET', 'zfs/snapshot')
        snapshots = response.json()

        if dataset:
            snapshots = [s for s in snapshots if s['dataset'] == dataset]

        return snapshots

    def create_snapshot(self, dataset: str, name: Optional[str] = None,
                       recursive: bool = False, properties: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Create a snapshot"""
        if name is None:
            name = datetime.now().strftime('%Y%m%d-%H%M%S')

        data = {
            'dataset': dataset,
            'name': name,
            'recursive': recursive
        }
        if properties:
            data['properties'] = properties

        response = self._make_request('POST', 'zfs/snapshot', json=data)
        return response.json()

    def delete_snapshot(self, snapshot_id: str) -> bool:
        """Delete a snapshot"""
        self._make_request('DELETE', f'zfs/snapshot/id/{snapshot_id}')
        return True

    def rollback_snapshot(self, snapshot_id: str) -> bool:
        """Rollback to a snapshot"""
        data = {'force': False}
        self._make_request('POST', f'zfs/snapshot/id/{snapshot_id}/rollback', json=data)
        return True

    # ==================== Replication Management ====================

    def get_replication_tasks(self) -> List[Dict[str, Any]]:
        """Get all replication tasks"""
        response = self._make_request('GET', 'replication')
        return response.json()

    def get_replication_status(self) -> List[Dict[str, Any]]:
        """Get replication task status"""
        tasks = self.get_replication_tasks()
        status_list = []

        for task in tasks:
            status_list.append({
                'id': task['id'],
                'name': task.get('name', 'N/A'),
                'enabled': task.get('enabled', False),
                'state': task.get('state', {}).get('state', 'UNKNOWN'),
                'last_run': task.get('state', {}).get('datetime'),
                'source': task.get('source_datasets', []),
                'target': task.get('target_dataset', 'N/A')
            })

        return status_list

    def run_replication_task(self, task_id: int) -> Dict[str, Any]:
        """Manually trigger a replication task"""
        response = self._make_request('POST', f'replication/id/{task_id}/run')
        return response.json()

    # ==================== SMB Share Management ====================

    def get_smb_shares(self) -> List[Dict[str, Any]]:
        """Get all SMB shares"""
        response = self._make_request('GET', 'sharing/smb')
        return response.json()

    def create_smb_share(self, path: str, name: str, **kwargs) -> Dict[str, Any]:
        """Create a new SMB share"""
        data = {
            'path': path,
            'name': name,
            **kwargs
        }
        response = self._make_request('POST', 'sharing/smb', json=data)
        return response.json()

    def delete_smb_share(self, share_id: int) -> bool:
        """Delete an SMB share"""
        self._make_request('DELETE', f'sharing/smb/id/{share_id}')
        return True

    def update_smb_share(self, share_id: int, properties: Dict[str, Any]) -> Dict[str, Any]:
        """Update SMB share properties"""
        response = self._make_request('PUT', f'sharing/smb/id/{share_id}', json=properties)
        return response.json()

    # ==================== User Management ====================

    def get_users(self) -> List[Dict[str, Any]]:
        """Get all users"""
        response = self._make_request('GET', 'user')
        return response.json()

    def create_user(self, username: str, full_name: str, password: str, **kwargs) -> Dict[str, Any]:
        """Create a new user"""
        data = {
            'username': username,
            'full_name': full_name,
            'password': password,
            **kwargs
        }
        response = self._make_request('POST', 'user', json=data)
        return response.json()

    def delete_user(self, user_id: int) -> bool:
        """Delete a user"""
        self._make_request('DELETE', f'user/id/{user_id}')
        return True

    # ==================== Health Monitoring ====================

    def get_system_info(self) -> Dict[str, Any]:
        """Get system information"""
        response = self._make_request('GET', 'system/info')
        return response.json()

    def get_alerts(self) -> List[Dict[str, Any]]:
        """Get system alerts"""
        response = self._make_request('GET', 'alert/list')
        return response.json()

    def get_disk_info(self) -> List[Dict[str, Any]]:
        """Get disk information"""
        response = self._make_request('GET', 'disk')
        return response.json()

    def get_services(self) -> List[Dict[str, Any]]:
        """Get service status"""
        response = self._make_request('GET', 'service')
        return response.json()


# ==================== CLI Commands ====================

@click.group()
@click.option('--config', type=click.Path(), help='Path to config file')
@click.pass_context
def cli(ctx, config):
    """TrueNAS Manager - Comprehensive management tool"""
    ctx.ensure_object(dict)
    config_path = Path(config) if config else None
    try:
        ctx.obj['manager'] = TrueNASManager(config_path)
    except FileNotFoundError as e:
        click.echo(str(e), err=True)
        sys.exit(1)


# ==================== Pool Commands ====================

@cli.group()
def pool():
    """Pool management commands"""
    pass


@pool.command('list')
@click.pass_context
def pool_list(ctx):
    """List all storage pools"""
    manager = ctx.obj['manager']
    pools = manager.get_pools()

    table_data = []
    for p in pools:
        size_gb = p.get('size', 0) / (1024**3)
        allocated_gb = p.get('allocated', 0) / (1024**3)
        free_gb = size_gb - allocated_gb
        usage_pct = (allocated_gb / size_gb * 100) if size_gb > 0 else 0

        table_data.append([
            p['name'],
            p.get('status', 'UNKNOWN'),
            f"{size_gb:.1f} GB",
            f"{allocated_gb:.1f} GB",
            f"{free_gb:.1f} GB",
            f"{usage_pct:.1f}%",
            'Yes' if p.get('healthy') else 'No'
        ])

    click.echo(tabulate(table_data, headers=[
        'Pool', 'Status', 'Size', 'Used', 'Free', 'Usage', 'Healthy'
    ], tablefmt='grid'))


@pool.command('status')
@click.argument('pool_name')
@click.pass_context
def pool_status(ctx, pool_name):
    """Get detailed pool status"""
    manager = ctx.obj['manager']
    try:
        pool = manager.get_pool_status(pool_name)
        click.echo(json.dumps(pool, indent=2))
    except ValueError as e:
        click.echo(str(e), err=True)
        sys.exit(1)


@pool.command('check-capacity')
@click.option('--threshold', default=80, help='Alert threshold percentage')
@click.pass_context
def pool_check_capacity(ctx, threshold):
    """Check pools for capacity alerts"""
    manager = ctx.obj['manager']
    alerts = manager.check_pool_capacity(threshold)

    if not alerts:
        click.echo(f"All pools are below {threshold}% capacity")
        return

    click.echo(f"Warning: {len(alerts)} pool(s) above {threshold}% capacity:")
    table_data = []
    for alert in alerts:
        table_data.append([
            alert['pool'],
            f"{alert['usage_pct']:.1f}%",
            f"{alert['used_gb']:.1f} GB",
            f"{alert['total_gb']:.1f} GB",
            alert['status']
        ])

    click.echo(tabulate(table_data, headers=[
        'Pool', 'Usage', 'Used', 'Total', 'Status'
    ], tablefmt='grid'))


# ==================== Dataset Commands ====================

@cli.group()
def dataset():
    """Dataset management commands"""
    pass


@dataset.command('list')
@click.option('--pool', help='Filter by pool name')
@click.pass_context
def dataset_list(ctx, pool):
    """List all datasets"""
    manager = ctx.obj['manager']
    datasets = manager.get_datasets(pool)

    table_data = []
    for ds in datasets:
        used_gb = ds.get('used', {}).get('parsed', 0) / (1024**3)
        available_gb = ds.get('available', {}).get('parsed', 0) / (1024**3)
        compression = ds.get('compression', {}).get('value', 'N/A')

        table_data.append([
            ds['name'],
            f"{used_gb:.2f} GB",
            f"{available_gb:.2f} GB",
            compression,
            ds.get('type', 'N/A')
        ])

    click.echo(tabulate(table_data, headers=[
        'Dataset', 'Used', 'Available', 'Compression', 'Type'
    ], tablefmt='grid'))


@dataset.command('create')
@click.argument('path')
@click.option('--compression', default='lz4', help='Compression algorithm')
@click.option('--quota', help='Quota (e.g., 100G)')
@click.pass_context
def dataset_create(ctx, path, compression, quota):
    """Create a new dataset"""
    manager = ctx.obj['manager']
    properties = {'compression': compression}
    if quota:
        properties['quota'] = quota

    try:
        result = manager.create_dataset(path, properties)
        click.echo(f"Dataset created: {result['name']}")
    except Exception as e:
        click.echo(f"Error creating dataset: {e}", err=True)
        sys.exit(1)


@dataset.command('delete')
@click.argument('dataset_id')
@click.option('--recursive', is_flag=True, help='Delete recursively')
@click.confirmation_option(prompt='Are you sure you want to delete this dataset?')
@click.pass_context
def dataset_delete(ctx, dataset_id, recursive):
    """Delete a dataset"""
    manager = ctx.obj['manager']
    try:
        manager.delete_dataset(dataset_id, recursive)
        click.echo(f"Dataset deleted: {dataset_id}")
    except Exception as e:
        click.echo(f"Error deleting dataset: {e}", err=True)
        sys.exit(1)


# ==================== Snapshot Commands ====================

@cli.group()
def snapshot():
    """Snapshot management commands"""
    pass


@snapshot.command('list')
@click.option('--dataset', help='Filter by dataset')
@click.pass_context
def snapshot_list(ctx, dataset):
    """List all snapshots"""
    manager = ctx.obj['manager']
    snapshots = manager.get_snapshots(dataset)

    table_data = []
    for snap in snapshots:
        creation_time = datetime.fromisoformat(snap.get('properties', {}).get('creation', {}).get('value', ''))
        used_gb = snap.get('properties', {}).get('used', {}).get('parsed', 0) / (1024**3)

        table_data.append([
            snap['name'],
            snap.get('dataset', 'N/A'),
            creation_time.strftime('%Y-%m-%d %H:%M:%S'),
            f"{used_gb:.2f} GB"
        ])

    click.echo(tabulate(table_data, headers=[
        'Snapshot', 'Dataset', 'Created', 'Used'
    ], tablefmt='grid'))


@snapshot.command('create')
@click.argument('dataset')
@click.option('--name', help='Snapshot name (default: timestamp)')
@click.option('--recursive', is_flag=True, help='Create recursively')
@click.pass_context
def snapshot_create(ctx, dataset, name, recursive):
    """Create a snapshot"""
    manager = ctx.obj['manager']
    try:
        result = manager.create_snapshot(dataset, name, recursive)
        click.echo(f"Snapshot created: {result['name']}")
    except Exception as e:
        click.echo(f"Error creating snapshot: {e}", err=True)
        sys.exit(1)


@snapshot.command('delete')
@click.argument('snapshot_id')
@click.confirmation_option(prompt='Are you sure you want to delete this snapshot?')
@click.pass_context
def snapshot_delete(ctx, snapshot_id):
    """Delete a snapshot"""
    manager = ctx.obj['manager']
    try:
        manager.delete_snapshot(snapshot_id)
        click.echo(f"Snapshot deleted: {snapshot_id}")
    except Exception as e:
        click.echo(f"Error deleting snapshot: {e}", err=True)
        sys.exit(1)


@snapshot.command('rollback')
@click.argument('snapshot_id')
@click.confirmation_option(prompt='Are you sure you want to rollback to this snapshot?')
@click.pass_context
def snapshot_rollback(ctx, snapshot_id):
    """Rollback to a snapshot"""
    manager = ctx.obj['manager']
    try:
        manager.rollback_snapshot(snapshot_id)
        click.echo(f"Rolled back to snapshot: {snapshot_id}")
    except Exception as e:
        click.echo(f"Error rolling back snapshot: {e}", err=True)
        sys.exit(1)


# ==================== Replication Commands ====================

@cli.group()
def replication():
    """Replication management commands"""
    pass


@replication.command('list')
@click.pass_context
def replication_list(ctx):
    """List replication tasks"""
    manager = ctx.obj['manager']
    tasks = manager.get_replication_status()

    table_data = []
    for task in tasks:
        table_data.append([
            task['id'],
            task['name'],
            'Enabled' if task['enabled'] else 'Disabled',
            task['state'],
            task['last_run'] or 'Never',
            ', '.join(task['source']),
            task['target']
        ])

    click.echo(tabulate(table_data, headers=[
        'ID', 'Name', 'Status', 'State', 'Last Run', 'Source', 'Target'
    ], tablefmt='grid'))


@replication.command('run')
@click.argument('task_id', type=int)
@click.pass_context
def replication_run(ctx, task_id):
    """Manually run a replication task"""
    manager = ctx.obj['manager']
    try:
        result = manager.run_replication_task(task_id)
        click.echo(f"Replication task {task_id} started")
    except Exception as e:
        click.echo(f"Error running replication task: {e}", err=True)
        sys.exit(1)


# ==================== SMB Share Commands ====================

@cli.group()
def smb():
    """SMB share management commands"""
    pass


@smb.command('list')
@click.pass_context
def smb_list(ctx):
    """List SMB shares"""
    manager = ctx.obj['manager']
    shares = manager.get_smb_shares()

    table_data = []
    for share in shares:
        table_data.append([
            share.get('id'),
            share.get('name'),
            share.get('path'),
            'Enabled' if share.get('enabled') else 'Disabled',
            share.get('comment', '')
        ])

    click.echo(tabulate(table_data, headers=[
        'ID', 'Name', 'Path', 'Status', 'Description'
    ], tablefmt='grid'))


@smb.command('create')
@click.argument('path')
@click.argument('name')
@click.option('--comment', help='Share description')
@click.pass_context
def smb_create(ctx, path, name, comment):
    """Create a new SMB share"""
    manager = ctx.obj['manager']
    try:
        kwargs = {}
        if comment:
            kwargs['comment'] = comment
        result = manager.create_smb_share(path, name, **kwargs)
        click.echo(f"SMB share created: {result['name']}")
    except Exception as e:
        click.echo(f"Error creating SMB share: {e}", err=True)
        sys.exit(1)


@smb.command('delete')
@click.argument('share_id', type=int)
@click.confirmation_option(prompt='Are you sure you want to delete this share?')
@click.pass_context
def smb_delete(ctx, share_id):
    """Delete an SMB share"""
    manager = ctx.obj['manager']
    try:
        manager.delete_smb_share(share_id)
        click.echo(f"SMB share deleted: {share_id}")
    except Exception as e:
        click.echo(f"Error deleting SMB share: {e}", err=True)
        sys.exit(1)


# ==================== User Commands ====================

@cli.group()
def user():
    """User management commands"""
    pass


@user.command('list')
@click.pass_context
def user_list(ctx):
    """List all users"""
    manager = ctx.obj['manager']
    users = manager.get_users()

    table_data = []
    for u in users:
        table_data.append([
            u.get('id'),
            u.get('username'),
            u.get('full_name', ''),
            u.get('uid'),
            u.get('group', {}).get('bsdgrp_group', 'N/A'),
            'Yes' if u.get('smb') else 'No'
        ])

    click.echo(tabulate(table_data, headers=[
        'ID', 'Username', 'Full Name', 'UID', 'Primary Group', 'SMB'
    ], tablefmt='grid'))


# ==================== Health Commands ====================

@cli.group()
def health():
    """System health monitoring commands"""
    pass


@health.command('system')
@click.pass_context
def health_system(ctx):
    """Show system information"""
    manager = ctx.obj['manager']
    info = manager.get_system_info()

    click.echo("System Information:")
    click.echo(f"  Hostname: {info.get('hostname')}")
    click.echo(f"  Version: {info.get('version')}")
    click.echo(f"  Uptime: {info.get('uptime_seconds', 0) / 3600:.1f} hours")
    click.echo(f"  Model: {info.get('system_product', 'N/A')}")
    click.echo(f"  CPU: {info.get('system_manufacturer', 'N/A')}")


@health.command('alerts')
@click.pass_context
def health_alerts(ctx):
    """Show system alerts"""
    manager = ctx.obj['manager']
    alerts = manager.get_alerts()

    if not alerts:
        click.echo("No active alerts")
        return

    table_data = []
    for alert in alerts:
        table_data.append([
            alert.get('level', 'INFO'),
            alert.get('klass', 'N/A'),
            alert.get('formatted', 'N/A')
        ])

    click.echo(tabulate(table_data, headers=[
        'Level', 'Type', 'Message'
    ], tablefmt='grid'))


@health.command('services')
@click.pass_context
def health_services(ctx):
    """Show service status"""
    manager = ctx.obj['manager']
    services = manager.get_services()

    table_data = []
    for svc in services:
        table_data.append([
            svc.get('service'),
            'Running' if svc.get('state') == 'RUNNING' else 'Stopped',
            'Enabled' if svc.get('enable') else 'Disabled'
        ])

    click.echo(tabulate(table_data, headers=[
        'Service', 'State', 'Startup'
    ], tablefmt='grid'))


@health.command('disks')
@click.pass_context
def health_disks(ctx):
    """Show disk information"""
    manager = ctx.obj['manager']
    disks = manager.get_disk_info()

    table_data = []
    for disk in disks:
        size_gb = disk.get('size', 0) / (1024**3)
        table_data.append([
            disk.get('name'),
            disk.get('model', 'N/A'),
            f"{size_gb:.1f} GB",
            disk.get('type', 'UNKNOWN'),
            disk.get('serial', 'N/A')
        ])

    click.echo(tabulate(table_data, headers=[
        'Device', 'Model', 'Size', 'Type', 'Serial'
    ], tablefmt='grid'))


if __name__ == '__main__':
    cli(obj={})
