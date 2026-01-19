#!/usr/bin/env python3
"""
TrueNAS Replication Manager - Advanced replication control tool
Provides manual replication triggering, monitoring, pause/resume, bandwidth throttling,
replication history/statistics, and automatic retry on failure.
"""

import json
import sys
import time
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List

import click
import requests
import urllib3
from tabulate import tabulate
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
from rich.table import Table
from rich import box

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class ReplicationManager:
    """TrueNAS Replication Manager"""

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
        self.console = Console()

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

    def get_replication_tasks(self) -> List[Dict[str, Any]]:
        """Get all replication tasks"""
        response = self._make_request('GET', 'replication')
        return response.json()

    def get_replication_task(self, task_id: int) -> Optional[Dict[str, Any]]:
        """Get specific replication task"""
        try:
            response = self._make_request('GET', f'replication/id/{task_id}')
            return response.json()
        except:
            return None

    def run_replication_task(self, task_id: int) -> Dict[str, Any]:
        """Manually trigger a replication task"""
        response = self._make_request('POST', f'replication/id/{task_id}/run')
        return response.json()

    def update_replication_task(self, task_id: int, data: Dict[str, Any]) -> Dict[str, Any]:
        """Update replication task settings"""
        response = self._make_request('PUT', f'replication/id/{task_id}', json=data)
        return response.json()

    def enable_replication_task(self, task_id: int) -> Dict[str, Any]:
        """Enable a replication task"""
        return self.update_replication_task(task_id, {'enabled': True})

    def disable_replication_task(self, task_id: int) -> Dict[str, Any]:
        """Disable a replication task"""
        return self.update_replication_task(task_id, {'enabled': False})

    def set_bandwidth_limit(self, task_id: int, limit_kbps: Optional[int] = None) -> Dict[str, Any]:
        """Set bandwidth limit for replication task"""
        data = {'speed_limit': limit_kbps} if limit_kbps else {'speed_limit': None}
        return self.update_replication_task(task_id, data)

    def get_replication_state(self, task_id: int) -> Dict[str, Any]:
        """Get current state of replication task"""
        task = self.get_replication_task(task_id)
        if not task:
            return {}

        state = task.get('state', {})
        return {
            'id': task['id'],
            'name': task.get('name', 'N/A'),
            'enabled': task.get('enabled', False),
            'state': state.get('state', 'UNKNOWN'),
            'datetime': state.get('datetime'),
            'last_snapshot': state.get('last_snapshot'),
            'job': task.get('job', {})
        }

    def wait_for_replication(self, task_id: int, timeout: int = 3600, check_interval: int = 5) -> bool:
        """Wait for replication task to complete"""
        start_time = time.time()

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            console=self.console
        ) as progress:
            task = progress.add_task(f"Waiting for replication task {task_id}...", total=None)

            while time.time() - start_time < timeout:
                state = self.get_replication_state(task_id)
                current_state = state.get('state', 'UNKNOWN')

                if current_state == 'SUCCESS':
                    progress.update(task, description=f"Replication completed successfully")
                    return True
                elif current_state in ['ERROR', 'FAILED']:
                    progress.update(task, description=f"Replication failed")
                    return False
                elif current_state == 'RUNNING':
                    progress.update(task, description=f"Replication in progress...")
                else:
                    progress.update(task, description=f"State: {current_state}")

                time.sleep(check_interval)

        return False

    def retry_failed_replications(self, max_retries: int = 3, retry_delay: int = 60) -> Dict[str, Any]:
        """Retry all failed replication tasks"""
        tasks = self.get_replication_tasks()
        failed_tasks = [t for t in tasks if t.get('state', {}).get('state') == 'ERROR']

        results = {
            'total_failed': len(failed_tasks),
            'retried': [],
            'succeeded': [],
            'still_failed': []
        }

        for task in failed_tasks:
            task_id = task['id']
            task_name = task.get('name', f'Task {task_id}')

            click.echo(f"\nRetrying failed task: {task_name}")

            for attempt in range(max_retries):
                try:
                    click.echo(f"  Attempt {attempt + 1}/{max_retries}...")
                    self.run_replication_task(task_id)

                    # Wait for completion
                    if self.wait_for_replication(task_id, timeout=600):
                        click.echo(f"  Success!")
                        results['succeeded'].append(task_name)
                        results['retried'].append(task_name)
                        break
                    else:
                        click.echo(f"  Failed")
                        if attempt < max_retries - 1:
                            click.echo(f"  Waiting {retry_delay}s before retry...")
                            time.sleep(retry_delay)
                except Exception as e:
                    click.echo(f"  Error: {e}")
                    if attempt < max_retries - 1:
                        time.sleep(retry_delay)
            else:
                # All retries failed
                results['still_failed'].append(task_name)
                results['retried'].append(task_name)

        return results

    def get_replication_history(self, task_id: Optional[int] = None, days: int = 7) -> List[Dict[str, Any]]:
        """Get replication history from jobs"""
        # Get all jobs for replication tasks
        response = self._make_request('GET', 'core/get_jobs')
        jobs = response.json()

        # Filter replication jobs
        replication_jobs = [j for j in jobs if j.get('method') == 'replication.run']

        # Filter by task_id if provided
        if task_id is not None:
            replication_jobs = [j for j in replication_jobs
                              if j.get('arguments', [{}])[0] == task_id]

        # Filter by date
        cutoff = datetime.now() - timedelta(days=days)
        filtered_jobs = []
        for job in replication_jobs:
            time_started = job.get('time_started')
            if time_started:
                try:
                    job_time = datetime.fromisoformat(time_started.get('$date', ''))
                    if job_time >= cutoff:
                        filtered_jobs.append(job)
                except:
                    pass

        return filtered_jobs

    def get_replication_statistics(self, task_id: Optional[int] = None) -> Dict[str, Any]:
        """Get replication statistics"""
        tasks = self.get_replication_tasks()

        if task_id is not None:
            tasks = [t for t in tasks if t['id'] == task_id]

        stats = {
            'total_tasks': len(tasks),
            'enabled': 0,
            'disabled': 0,
            'running': 0,
            'success': 0,
            'error': 0,
            'never_run': 0,
            'last_24h': 0
        }

        now = datetime.now()
        for task in tasks:
            if task.get('enabled'):
                stats['enabled'] += 1
            else:
                stats['disabled'] += 1

            state = task.get('state', {}).get('state', 'UNKNOWN')
            if state == 'RUNNING':
                stats['running'] += 1
            elif state == 'SUCCESS':
                stats['success'] += 1
            elif state in ['ERROR', 'FAILED']:
                stats['error'] += 1

            last_run = task.get('state', {}).get('datetime')
            if not last_run:
                stats['never_run'] += 1
            else:
                try:
                    last_run_time = datetime.fromisoformat(last_run)
                    if now - last_run_time <= timedelta(hours=24):
                        stats['last_24h'] += 1
                except:
                    pass

        return stats


# ==================== CLI Commands ====================

@click.group()
@click.option('--config', type=click.Path(), help='Path to config file')
@click.pass_context
def cli(ctx, config):
    """TrueNAS Replication Manager"""
    ctx.ensure_object(dict)
    config_path = Path(config) if config else None
    try:
        ctx.obj['manager'] = ReplicationManager(config_path)
    except FileNotFoundError as e:
        click.echo(str(e), err=True)
        sys.exit(1)


@cli.command('list')
@click.option('--enabled-only', is_flag=True, help='Show only enabled tasks')
@click.option('--failed-only', is_flag=True, help='Show only failed tasks')
@click.pass_context
def list_tasks(ctx, enabled_only, failed_only):
    """List replication tasks"""
    manager = ctx.obj['manager']
    tasks = manager.get_replication_tasks()

    # Apply filters
    if enabled_only:
        tasks = [t for t in tasks if t.get('enabled')]
    if failed_only:
        tasks = [t for t in tasks if t.get('state', {}).get('state') in ['ERROR', 'FAILED']]

    table_data = []
    for task in tasks:
        state = task.get('state', {})
        last_run = state.get('datetime', 'Never')
        if last_run != 'Never':
            try:
                dt = datetime.fromisoformat(last_run)
                last_run = dt.strftime('%Y-%m-%d %H:%M')
            except:
                pass

        current_state = state.get('state', 'UNKNOWN')
        # Color indicators
        if current_state == 'SUCCESS':
            state_icon = '✓'
        elif current_state in ['ERROR', 'FAILED']:
            state_icon = '✗'
        elif current_state == 'RUNNING':
            state_icon = '⟳'
        else:
            state_icon = '○'

        table_data.append([
            task['id'],
            task.get('name', 'N/A'),
            'Yes' if task.get('enabled') else 'No',
            f"{state_icon} {current_state}",
            last_run,
            ', '.join(task.get('source_datasets', [])),
            task.get('target_dataset', 'N/A')
        ])

    click.echo(tabulate(table_data, headers=[
        'ID', 'Name', 'Enabled', 'State', 'Last Run', 'Source', 'Target'
    ], tablefmt='grid'))

    click.echo(f"\nTotal: {len(tasks)} tasks")


@cli.command('status')
@click.argument('task_id', type=int)
@click.pass_context
def task_status(ctx, task_id):
    """Show detailed status of a replication task"""
    manager = ctx.obj['manager']
    task = manager.get_replication_task(task_id)

    if not task:
        click.echo(f"Error: Task {task_id} not found", err=True)
        sys.exit(1)

    click.echo(f"Replication Task: {task.get('name', 'N/A')}")
    click.echo(f"  ID: {task['id']}")
    click.echo(f"  Enabled: {'Yes' if task.get('enabled') else 'No'}")
    click.echo(f"  Direction: {task.get('direction', 'N/A')}")
    click.echo(f"  Transport: {task.get('transport', 'N/A')}")
    click.echo(f"  Source Datasets: {', '.join(task.get('source_datasets', []))}")
    click.echo(f"  Target Dataset: {task.get('target_dataset', 'N/A')}")
    click.echo(f"  Recursive: {'Yes' if task.get('recursive') else 'No'}")

    state = task.get('state', {})
    click.echo(f"\nState:")
    click.echo(f"  Status: {state.get('state', 'UNKNOWN')}")
    click.echo(f"  Last Run: {state.get('datetime', 'Never')}")
    click.echo(f"  Last Snapshot: {state.get('last_snapshot', 'N/A')}")

    if task.get('speed_limit'):
        click.echo(f"\nBandwidth Limit: {task['speed_limit']} KB/s")

    schedule = task.get('schedule')
    if schedule:
        click.echo(f"\nSchedule:")
        click.echo(f"  {json.dumps(schedule, indent=2)}")


@cli.command('run')
@click.argument('task_id', type=int)
@click.option('--wait', is_flag=True, help='Wait for completion')
@click.option('--timeout', type=int, default=3600, help='Timeout in seconds')
@click.pass_context
def run_task(ctx, task_id, wait, timeout):
    """Manually run a replication task"""
    manager = ctx.obj['manager']

    try:
        click.echo(f"Starting replication task {task_id}...")
        result = manager.run_replication_task(task_id)
        click.echo(f"Task started (Job ID: {result})")

        if wait:
            click.echo("\nWaiting for completion...")
            success = manager.wait_for_replication(task_id, timeout=timeout)
            if success:
                click.echo("Replication completed successfully")
            else:
                click.echo("Replication failed or timed out")
                sys.exit(1)
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command('enable')
@click.argument('task_id', type=int)
@click.pass_context
def enable_task(ctx, task_id):
    """Enable a replication task"""
    manager = ctx.obj['manager']
    try:
        manager.enable_replication_task(task_id)
        click.echo(f"Replication task {task_id} enabled")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command('disable')
@click.argument('task_id', type=int)
@click.pass_context
def disable_task(ctx, task_id):
    """Disable (pause) a replication task"""
    manager = ctx.obj['manager']
    try:
        manager.disable_replication_task(task_id)
        click.echo(f"Replication task {task_id} disabled")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command('bandwidth')
@click.argument('task_id', type=int)
@click.option('--limit', type=int, help='Bandwidth limit in KB/s (0 or omit for unlimited)')
@click.pass_context
def set_bandwidth(ctx, task_id, limit):
    """Set bandwidth throttling for a replication task"""
    manager = ctx.obj['manager']
    try:
        limit_kbps = limit if limit and limit > 0 else None
        manager.set_bandwidth_limit(task_id, limit_kbps)

        if limit_kbps:
            click.echo(f"Bandwidth limit set to {limit_kbps} KB/s ({limit_kbps / 1024:.2f} MB/s)")
        else:
            click.echo("Bandwidth limit removed (unlimited)")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


@cli.command('retry-failed')
@click.option('--max-retries', type=int, default=3, help='Maximum retry attempts')
@click.option('--delay', type=int, default=60, help='Delay between retries in seconds')
@click.pass_context
def retry_failed(ctx, max_retries, delay):
    """Retry all failed replication tasks"""
    manager = ctx.obj['manager']

    click.echo("Checking for failed replication tasks...")
    results = manager.retry_failed_replications(max_retries=max_retries, retry_delay=delay)

    click.echo(f"\n{'='*60}")
    click.echo("Retry Results:")
    click.echo(f"{'='*60}")
    click.echo(f"Total failed tasks: {results['total_failed']}")
    click.echo(f"Tasks retried: {len(results['retried'])}")
    click.echo(f"Succeeded: {len(results['succeeded'])}")
    click.echo(f"Still failed: {len(results['still_failed'])}")

    if results['succeeded']:
        click.echo("\nSuccessfully recovered:")
        for task in results['succeeded']:
            click.echo(f"  ✓ {task}")

    if results['still_failed']:
        click.echo("\nStill failed:")
        for task in results['still_failed']:
            click.echo(f"  ✗ {task}")


@cli.command('history')
@click.option('--task-id', type=int, help='Filter by task ID')
@click.option('--days', type=int, default=7, help='Number of days to show')
@click.pass_context
def show_history(ctx, task_id, days):
    """Show replication history"""
    manager = ctx.obj['manager']
    history = manager.get_replication_history(task_id=task_id, days=days)

    if not history:
        click.echo("No replication history found")
        return

    table_data = []
    for job in history:
        job_id = job.get('id')
        task_arg = job.get('arguments', [None])[0]
        state = job.get('state', 'UNKNOWN')

        time_started = job.get('time_started', {}).get('$date', 'N/A')
        time_finished = job.get('time_finished', {}).get('$date', 'N/A')

        try:
            if time_started != 'N/A':
                time_started = datetime.fromisoformat(time_started).strftime('%Y-%m-%d %H:%M')
            if time_finished != 'N/A':
                time_finished = datetime.fromisoformat(time_finished).strftime('%Y-%m-%d %H:%M')
        except:
            pass

        table_data.append([
            job_id,
            task_arg,
            state,
            time_started,
            time_finished
        ])

    click.echo(tabulate(table_data, headers=[
        'Job ID', 'Task ID', 'State', 'Started', 'Finished'
    ], tablefmt='grid'))

    click.echo(f"\nTotal: {len(history)} jobs in last {days} days")


@cli.command('stats')
@click.option('--task-id', type=int, help='Show stats for specific task')
@click.pass_context
def show_statistics(ctx, task_id):
    """Show replication statistics"""
    manager = ctx.obj['manager']
    stats = manager.get_replication_statistics(task_id=task_id)

    click.echo("Replication Statistics:")
    click.echo(f"  Total Tasks: {stats['total_tasks']}")
    click.echo(f"  Enabled: {stats['enabled']}")
    click.echo(f"  Disabled: {stats['disabled']}")
    click.echo(f"\nCurrent State:")
    click.echo(f"  Running: {stats['running']}")
    click.echo(f"  Success: {stats['success']}")
    click.echo(f"  Error: {stats['error']}")
    click.echo(f"  Never Run: {stats['never_run']}")
    click.echo(f"\nActivity:")
    click.echo(f"  Replications in last 24h: {stats['last_24h']}")


@cli.command('monitor')
@click.option('--refresh', type=int, default=5, help='Refresh interval in seconds')
@click.pass_context
def monitor_tasks(ctx, refresh):
    """Monitor replication tasks in real-time"""
    manager = ctx.obj['manager']

    try:
        while True:
            # Clear screen
            click.clear()

            # Get current tasks
            tasks = manager.get_replication_tasks()

            # Display header
            click.echo("="*80)
            click.echo(f"TrueNAS Replication Monitor - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            click.echo("="*80)

            # Display tasks
            table_data = []
            for task in tasks:
                state = task.get('state', {})
                current_state = state.get('state', 'UNKNOWN')

                # Status icon
                if current_state == 'SUCCESS':
                    state_icon = '✓'
                elif current_state in ['ERROR', 'FAILED']:
                    state_icon = '✗'
                elif current_state == 'RUNNING':
                    state_icon = '⟳'
                else:
                    state_icon = '○'

                last_run = state.get('datetime', 'Never')
                if last_run != 'Never':
                    try:
                        dt = datetime.fromisoformat(last_run)
                        last_run = dt.strftime('%H:%M:%S')
                    except:
                        pass

                table_data.append([
                    task['id'],
                    task.get('name', 'N/A')[:25],
                    'On' if task.get('enabled') else 'Off',
                    f"{state_icon} {current_state}",
                    last_run
                ])

            click.echo(tabulate(table_data, headers=[
                'ID', 'Name', 'Status', 'State', 'Last Run'
            ], tablefmt='simple'))

            click.echo(f"\nRefreshing every {refresh} seconds... (Press Ctrl+C to exit)")

            time.sleep(refresh)

    except KeyboardInterrupt:
        click.echo("\nMonitoring stopped")


if __name__ == '__main__':
    cli(obj={})
