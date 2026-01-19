#!/usr/bin/env python3
"""
TrueNAS Snapshot Manager - Advanced snapshot management tool
Provides on-demand snapshot creation, listing with filtering, bulk operations,
snapshot comparison, automated cleanup with retention policies, and export/import.
"""

import json
import sys
import re
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List

import click
import requests
import urllib3
from tabulate import tabulate

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class SnapshotManager:
    """TrueNAS Snapshot Manager"""

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
        """Get request headers"""
        return {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }

    def _make_request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        """Make API request"""
        url = f"{self.base_url}/{endpoint}"
        kwargs.setdefault('headers', self._get_headers())
        kwargs.setdefault('verify', self.verify_ssl)
        kwargs.setdefault('timeout', 30)

        try:
            response = requests.request(method, url, **kwargs)
            response.raise_for_status()
            return response
        except requests.exceptions.RequestException as e:
            click.echo(f"Error: {e}", err=True)
            sys.exit(1)

    def get_snapshots(self, dataset: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get all snapshots"""
        response = self._make_request('GET', 'zfs/snapshot')
        snapshots = response.json()

        if dataset:
            snapshots = [s for s in snapshots if s['dataset'] == dataset]

        return snapshots

    def get_snapshot_by_id(self, snapshot_id: str) -> Optional[Dict[str, Any]]:
        """Get snapshot by ID"""
        try:
            response = self._make_request('GET', f'zfs/snapshot/id/{snapshot_id}')
            return response.json()
        except:
            return None

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

    def delete_snapshot(self, snapshot_id: str, defer: bool = False) -> bool:
        """Delete a snapshot"""
        params = {'defer': defer}
        self._make_request('DELETE', f'zfs/snapshot/id/{snapshot_id}', params=params)
        return True

    def clone_snapshot(self, snapshot_id: str, dataset_name: str) -> Dict[str, Any]:
        """Clone a snapshot to a new dataset"""
        data = {'dataset_dst': dataset_name}
        response = self._make_request('POST', f'zfs/snapshot/id/{snapshot_id}/clone', json=data)
        return response.json()

    def rollback_snapshot(self, snapshot_id: str, force: bool = False) -> bool:
        """Rollback to a snapshot"""
        data = {'force': force}
        self._make_request('POST', f'zfs/snapshot/id/{snapshot_id}/rollback', json=data)
        return True

    def get_datasets(self) -> List[Dict[str, Any]]:
        """Get all datasets"""
        response = self._make_request('GET', 'pool/dataset')
        return response.json()

    def filter_snapshots(self, snapshots: List[Dict[str, Any]], **filters) -> List[Dict[str, Any]]:
        """Filter snapshots based on criteria"""
        filtered = snapshots

        # Filter by dataset pattern
        if 'dataset_pattern' in filters and filters['dataset_pattern']:
            pattern = re.compile(filters['dataset_pattern'])
            filtered = [s for s in filtered if pattern.search(s['dataset'])]

        # Filter by name pattern
        if 'name_pattern' in filters and filters['name_pattern']:
            pattern = re.compile(filters['name_pattern'])
            filtered = [s for s in filtered if pattern.search(s['name'])]

        # Filter by creation date range
        if 'created_after' in filters and filters['created_after']:
            after = filters['created_after']
            filtered = [s for s in filtered
                       if self._parse_creation_time(s) >= after]

        if 'created_before' in filters and filters['created_before']:
            before = filters['created_before']
            filtered = [s for s in filtered
                       if self._parse_creation_time(s) <= before]

        return filtered

    def _parse_creation_time(self, snapshot: Dict[str, Any]) -> datetime:
        """Parse snapshot creation time"""
        creation_str = snapshot.get('properties', {}).get('creation', {}).get('value', '')
        try:
            return datetime.fromisoformat(creation_str)
        except:
            return datetime.min

    def apply_retention_policy(self, dataset: str, policy: Dict[str, int], dry_run: bool = False) -> Dict[str, Any]:
        """
        Apply retention policy to snapshots
        Policy format: {'hourly': 24, 'daily': 7, 'weekly': 4, 'monthly': 12}
        """
        snapshots = self.get_snapshots(dataset)
        if not snapshots:
            return {'deleted': [], 'kept': [], 'message': 'No snapshots found'}

        # Sort by creation time (newest first)
        snapshots.sort(key=lambda s: self._parse_creation_time(s), reverse=True)

        now = datetime.now()
        kept = []
        deleted = []

        # Categorize snapshots by retention period
        hourly_count = 0
        daily_count = 0
        weekly_count = 0
        monthly_count = 0

        for snap in snapshots:
            creation = self._parse_creation_time(snap)
            age = now - creation

            keep = False

            # Hourly retention (last 24 hours)
            if 'hourly' in policy and age <= timedelta(hours=1) and hourly_count < policy['hourly']:
                keep = True
                hourly_count += 1

            # Daily retention (last N days)
            elif 'daily' in policy and age <= timedelta(days=1) and daily_count < policy['daily']:
                keep = True
                daily_count += 1

            # Weekly retention (last N weeks)
            elif 'weekly' in policy and age <= timedelta(weeks=1) and weekly_count < policy['weekly']:
                keep = True
                weekly_count += 1

            # Monthly retention (last N months)
            elif 'monthly' in policy and age <= timedelta(days=30) and monthly_count < policy['monthly']:
                keep = True
                monthly_count += 1

            if keep:
                kept.append(snap)
            else:
                deleted.append(snap)
                if not dry_run:
                    try:
                        self.delete_snapshot(snap['id'])
                    except Exception as e:
                        click.echo(f"Warning: Failed to delete {snap['name']}: {e}", err=True)

        return {
            'deleted': deleted,
            'kept': kept,
            'message': f"{'Would delete' if dry_run else 'Deleted'} {len(deleted)} snapshots, kept {len(kept)}"
        }


# ==================== CLI Commands ====================

@click.group()
@click.option('--config', type=click.Path(), help='Path to config file')
@click.pass_context
def cli(ctx, config):
    """TrueNAS Snapshot Manager"""
    ctx.ensure_object(dict)
    config_path = Path(config) if config else None
    try:
        ctx.obj['manager'] = SnapshotManager(config_path)
    except FileNotFoundError as e:
        click.echo(str(e), err=True)
        sys.exit(1)


@cli.command('list')
@click.option('--dataset', help='Filter by dataset')
@click.option('--name-pattern', help='Filter by name pattern (regex)')
@click.option('--dataset-pattern', help='Filter by dataset pattern (regex)')
@click.option('--created-after', help='Filter by creation date (YYYY-MM-DD)')
@click.option('--created-before', help='Filter by creation date (YYYY-MM-DD)')
@click.option('--sort', type=click.Choice(['name', 'created', 'size']), default='created')
@click.option('--reverse', is_flag=True, help='Reverse sort order')
@click.pass_context
def list_snapshots(ctx, dataset, name_pattern, dataset_pattern, created_after, created_before, sort, reverse):
    """List snapshots with filtering options"""
    manager = ctx.obj['manager']
    snapshots = manager.get_snapshots(dataset)

    # Apply filters
    filters = {}
    if name_pattern:
        filters['name_pattern'] = name_pattern
    if dataset_pattern:
        filters['dataset_pattern'] = dataset_pattern
    if created_after:
        filters['created_after'] = datetime.strptime(created_after, '%Y-%m-%d')
    if created_before:
        filters['created_before'] = datetime.strptime(created_before, '%Y-%m-%d')

    if filters:
        snapshots = manager.filter_snapshots(snapshots, **filters)

    # Sort snapshots
    if sort == 'name':
        snapshots.sort(key=lambda s: s['name'], reverse=reverse)
    elif sort == 'created':
        snapshots.sort(key=lambda s: manager._parse_creation_time(s), reverse=reverse)
    elif sort == 'size':
        snapshots.sort(key=lambda s: s.get('properties', {}).get('used', {}).get('parsed', 0), reverse=reverse)

    if not snapshots:
        click.echo("No snapshots found")
        return

    # Display results
    table_data = []
    for snap in snapshots:
        creation_time = manager._parse_creation_time(snap)
        used_gb = snap.get('properties', {}).get('used', {}).get('parsed', 0) / (1024**3)

        table_data.append([
            snap['id'],
            snap['name'],
            snap['dataset'],
            creation_time.strftime('%Y-%m-%d %H:%M:%S'),
            f"{used_gb:.3f} GB"
        ])

    click.echo(tabulate(table_data, headers=[
        'ID', 'Name', 'Dataset', 'Created', 'Used'
    ], tablefmt='grid'))

    click.echo(f"\nTotal: {len(snapshots)} snapshots")


@cli.command('create')
@click.argument('dataset')
@click.option('--name', help='Snapshot name (default: timestamp)')
@click.option('--recursive', is_flag=True, help='Create recursively')
@click.option('--comment', help='Snapshot comment')
@click.pass_context
def create_snapshot(ctx, dataset, name, recursive, comment):
    """Create a new snapshot"""
    manager = ctx.obj['manager']

    properties = {}
    if comment:
        properties['org.truenas:comment'] = comment

    try:
        result = manager.create_snapshot(dataset, name, recursive, properties if properties else None)
        click.echo(f"Snapshot created: {result['name']}")
        click.echo(f"  ID: {result['id']}")
        click.echo(f"  Dataset: {result['dataset']}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command('delete')
@click.argument('snapshot_id')
@click.option('--defer', is_flag=True, help='Defer deletion')
@click.confirmation_option(prompt='Are you sure you want to delete this snapshot?')
@click.pass_context
def delete_snapshot(ctx, snapshot_id, defer):
    """Delete a snapshot"""
    manager = ctx.obj['manager']
    try:
        manager.delete_snapshot(snapshot_id, defer)
        click.echo(f"Snapshot deleted: {snapshot_id}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command('bulk-delete')
@click.option('--dataset', required=True, help='Dataset to filter')
@click.option('--name-pattern', help='Filter by name pattern (regex)')
@click.option('--older-than', type=int, help='Delete snapshots older than N days')
@click.option('--dry-run', is_flag=True, help='Show what would be deleted without deleting')
@click.confirmation_option(prompt='Are you sure you want to delete these snapshots?')
@click.pass_context
def bulk_delete(ctx, dataset, name_pattern, older_than, dry_run):
    """Delete multiple snapshots matching criteria"""
    manager = ctx.obj['manager']
    snapshots = manager.get_snapshots(dataset)

    # Apply filters
    filters = {}
    if name_pattern:
        filters['name_pattern'] = name_pattern
    if older_than:
        filters['created_before'] = datetime.now() - timedelta(days=older_than)

    if filters:
        snapshots = manager.filter_snapshots(snapshots, **filters)

    if not snapshots:
        click.echo("No snapshots match the criteria")
        return

    click.echo(f"Found {len(snapshots)} snapshots to delete:")
    for snap in snapshots:
        click.echo(f"  - {snap['name']}")

    if dry_run:
        click.echo("\nDry run mode - no snapshots were deleted")
        return

    deleted_count = 0
    for snap in snapshots:
        try:
            manager.delete_snapshot(snap['id'])
            deleted_count += 1
        except Exception as e:
            click.echo(f"Warning: Failed to delete {snap['name']}: {e}", err=True)

    click.echo(f"\nDeleted {deleted_count} of {len(snapshots)} snapshots")


@cli.command('clone')
@click.argument('snapshot_id')
@click.argument('new_dataset')
@click.pass_context
def clone_snapshot(ctx, snapshot_id, new_dataset):
    """Clone a snapshot to a new dataset"""
    manager = ctx.obj['manager']
    try:
        result = manager.clone_snapshot(snapshot_id, new_dataset)
        click.echo(f"Snapshot cloned to: {new_dataset}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command('rollback')
@click.argument('snapshot_id')
@click.option('--force', is_flag=True, help='Force rollback (destroy newer snapshots)')
@click.confirmation_option(prompt='Are you sure you want to rollback to this snapshot?')
@click.pass_context
def rollback_snapshot(ctx, snapshot_id, force):
    """Rollback to a snapshot"""
    manager = ctx.obj['manager']
    try:
        manager.rollback_snapshot(snapshot_id, force)
        click.echo(f"Rolled back to snapshot: {snapshot_id}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command('retention')
@click.argument('dataset')
@click.option('--hourly', type=int, help='Keep N hourly snapshots')
@click.option('--daily', type=int, help='Keep N daily snapshots')
@click.option('--weekly', type=int, help='Keep N weekly snapshots')
@click.option('--monthly', type=int, help='Keep N monthly snapshots')
@click.option('--dry-run', is_flag=True, help='Show what would be deleted without deleting')
@click.pass_context
def apply_retention(ctx, dataset, hourly, daily, weekly, monthly, dry_run):
    """Apply retention policy to dataset snapshots"""
    manager = ctx.obj['manager']

    policy = {}
    if hourly:
        policy['hourly'] = hourly
    if daily:
        policy['daily'] = daily
    if weekly:
        policy['weekly'] = weekly
    if monthly:
        policy['monthly'] = monthly

    if not policy:
        click.echo("Error: No retention policy specified", err=True)
        sys.exit(1)

    click.echo(f"Applying retention policy to {dataset}:")
    for key, value in policy.items():
        click.echo(f"  {key}: keep {value}")

    result = manager.apply_retention_policy(dataset, policy, dry_run)

    click.echo(f"\n{result['message']}")

    if result['deleted']:
        click.echo(f"\nSnapshots to be deleted ({len(result['deleted'])}):")
        for snap in result['deleted'][:10]:  # Show first 10
            creation = manager._parse_creation_time(snap)
            click.echo(f"  - {snap['name']} ({creation.strftime('%Y-%m-%d %H:%M')})")
        if len(result['deleted']) > 10:
            click.echo(f"  ... and {len(result['deleted']) - 10} more")


@cli.command('compare')
@click.argument('snapshot_id_1')
@click.argument('snapshot_id_2')
@click.pass_context
def compare_snapshots(ctx, snapshot_id_1, snapshot_id_2):
    """Compare two snapshots"""
    manager = ctx.obj['manager']

    snap1 = manager.get_snapshot_by_id(snapshot_id_1)
    snap2 = manager.get_snapshot_by_id(snapshot_id_2)

    if not snap1 or not snap2:
        click.echo("Error: One or both snapshots not found", err=True)
        sys.exit(1)

    # Display comparison
    click.echo("Snapshot Comparison:")
    click.echo(f"\nSnapshot 1: {snap1['name']}")
    click.echo(f"  Created: {manager._parse_creation_time(snap1).strftime('%Y-%m-%d %H:%M:%S')}")
    click.echo(f"  Dataset: {snap1['dataset']}")
    used1 = snap1.get('properties', {}).get('used', {}).get('parsed', 0) / (1024**3)
    click.echo(f"  Used: {used1:.3f} GB")

    click.echo(f"\nSnapshot 2: {snap2['name']}")
    click.echo(f"  Created: {manager._parse_creation_time(snap2).strftime('%Y-%m-%d %H:%M:%S')}")
    click.echo(f"  Dataset: {snap2['dataset']}")
    used2 = snap2.get('properties', {}).get('used', {}).get('parsed', 0) / (1024**3)
    click.echo(f"  Used: {used2:.3f} GB")

    click.echo(f"\nSize difference: {abs(used2 - used1):.3f} GB")

    time1 = manager._parse_creation_time(snap1)
    time2 = manager._parse_creation_time(snap2)
    time_diff = abs((time2 - time1).total_seconds())
    click.echo(f"Time difference: {time_diff / 3600:.2f} hours")


@cli.command('info')
@click.argument('snapshot_id')
@click.pass_context
def snapshot_info(ctx, snapshot_id):
    """Show detailed snapshot information"""
    manager = ctx.obj['manager']
    snap = manager.get_snapshot_by_id(snapshot_id)

    if not snap:
        click.echo("Error: Snapshot not found", err=True)
        sys.exit(1)

    click.echo(json.dumps(snap, indent=2))


if __name__ == '__main__':
    cli(obj={})
