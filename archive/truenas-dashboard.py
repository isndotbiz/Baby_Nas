#!/usr/bin/env python3
"""
TrueNAS Dashboard - Real-time monitoring dashboard
Provides a rich TUI showing pool status, dataset usage, replication lag,
network throughput, service status, and recent snapshots.
"""

import json
import sys
import time
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any, List

import requests
import urllib3
from rich.console import Console
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.progress import Progress, BarColumn, TextColumn
from rich.text import Text
from rich import box

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class TrueNASDashboard:
    """TrueNAS Real-time Dashboard"""

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
        """Get request headers with authentication"""
        return {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }

    def _make_request(self, endpoint: str) -> Optional[Any]:
        """Make API request with error handling"""
        url = f"{self.base_url}/{endpoint}"
        try:
            response = requests.get(
                url,
                headers=self._get_headers(),
                verify=self.verify_ssl,
                timeout=5
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            return None

    def get_system_info(self) -> Dict[str, Any]:
        """Get system information"""
        return self._make_request('system/info') or {}

    def get_pools(self) -> List[Dict[str, Any]]:
        """Get pool information"""
        return self._make_request('pool') or []

    def get_datasets(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get top datasets by usage"""
        datasets = self._make_request('pool/dataset') or []
        # Sort by used space
        datasets.sort(key=lambda d: d.get('used', {}).get('parsed', 0), reverse=True)
        return datasets[:limit]

    def get_snapshots(self, limit: int = 5) -> List[Dict[str, Any]]:
        """Get recent snapshots"""
        snapshots = self._make_request('zfs/snapshot') or []
        # Sort by creation time (most recent first)
        snapshots.sort(
            key=lambda s: s.get('properties', {}).get('creation', {}).get('value', ''),
            reverse=True
        )
        return snapshots[:limit]

    def get_replication_tasks(self) -> List[Dict[str, Any]]:
        """Get replication task status"""
        return self._make_request('replication') or []

    def get_services(self) -> List[Dict[str, Any]]:
        """Get service status"""
        return self._make_request('service') or []

    def get_network_stats(self) -> Dict[str, Any]:
        """Get network statistics"""
        return self._make_request('reporting/netdata') or {}

    def get_alerts(self) -> List[Dict[str, Any]]:
        """Get active alerts"""
        return self._make_request('alert/list') or []

    def create_header(self) -> Panel:
        """Create dashboard header"""
        sys_info = self.get_system_info()
        hostname = sys_info.get('hostname', 'Unknown')
        version = sys_info.get('version', 'Unknown')
        uptime_hours = sys_info.get('uptime_seconds', 0) / 3600

        header_text = Text()
        header_text.append("TrueNAS SCALE Dashboard", style="bold cyan")
        header_text.append(f"\n{hostname}", style="bold white")
        header_text.append(f" | Version: {version}", style="dim")
        header_text.append(f" | Uptime: {uptime_hours:.1f}h", style="dim")
        header_text.append(f" | Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", style="dim")

        return Panel(header_text, box=box.DOUBLE, style="cyan")

    def create_pool_panel(self) -> Panel:
        """Create storage pool panel"""
        pools = self.get_pools()

        table = Table(box=box.SIMPLE, show_header=True, header_style="bold magenta")
        table.add_column("Pool", style="cyan")
        table.add_column("Status", style="green")
        table.add_column("Size", justify="right")
        table.add_column("Used", justify="right")
        table.add_column("Free", justify="right")
        table.add_column("Usage", justify="right")

        for pool in pools:
            size_gb = pool.get('size', 0) / (1024**3)
            allocated_gb = pool.get('allocated', 0) / (1024**3)
            free_gb = size_gb - allocated_gb
            usage_pct = (allocated_gb / size_gb * 100) if size_gb > 0 else 0

            # Color code usage percentage
            if usage_pct >= 90:
                usage_style = "red bold"
            elif usage_pct >= 80:
                usage_style = "yellow"
            else:
                usage_style = "green"

            status = pool.get('status', 'UNKNOWN')
            status_style = "green" if status == "ONLINE" else "red"

            table.add_row(
                pool['name'],
                Text(status, style=status_style),
                f"{size_gb:.1f} GB",
                f"{allocated_gb:.1f} GB",
                f"{free_gb:.1f} GB",
                Text(f"{usage_pct:.1f}%", style=usage_style)
            )

        return Panel(table, title="Storage Pools", border_style="magenta")

    def create_dataset_panel(self) -> Panel:
        """Create dataset usage panel"""
        datasets = self.get_datasets(limit=8)

        table = Table(box=box.SIMPLE, show_header=True, header_style="bold yellow")
        table.add_column("Dataset", style="cyan", no_wrap=True)
        table.add_column("Used", justify="right")
        table.add_column("Available", justify="right")
        table.add_column("Compression", justify="center")

        for ds in datasets:
            used_gb = ds.get('used', {}).get('parsed', 0) / (1024**3)
            available_gb = ds.get('available', {}).get('parsed', 0) / (1024**3)
            compression = ds.get('compression', {}).get('value', 'N/A')

            # Truncate long dataset names
            name = ds['name']
            if len(name) > 30:
                name = "..." + name[-27:]

            table.add_row(
                name,
                f"{used_gb:.2f} GB",
                f"{available_gb:.2f} GB",
                compression
            )

        return Panel(table, title="Top Datasets by Usage", border_style="yellow")

    def create_snapshot_panel(self) -> Panel:
        """Create recent snapshots panel"""
        snapshots = self.get_snapshots(limit=6)

        table = Table(box=box.SIMPLE, show_header=True, header_style="bold blue")
        table.add_column("Snapshot", style="cyan", no_wrap=True)
        table.add_column("Created", justify="right")
        table.add_column("Used", justify="right")

        for snap in snapshots:
            creation_str = snap.get('properties', {}).get('creation', {}).get('value', '')
            try:
                creation_time = datetime.fromisoformat(creation_str)
                created = creation_time.strftime('%Y-%m-%d %H:%M')
            except:
                created = 'Unknown'

            used_gb = snap.get('properties', {}).get('used', {}).get('parsed', 0) / (1024**3)

            # Truncate long snapshot names
            name = snap['name']
            if len(name) > 35:
                name = "..." + name[-32:]

            table.add_row(
                name,
                created,
                f"{used_gb:.2f} GB"
            )

        return Panel(table, title="Recent Snapshots", border_style="blue")

    def create_replication_panel(self) -> Panel:
        """Create replication status panel"""
        tasks = self.get_replication_tasks()

        table = Table(box=box.SIMPLE, show_header=True, header_style="bold green")
        table.add_column("Name", style="cyan")
        table.add_column("State", justify="center")
        table.add_column("Last Run", justify="right")

        for task in tasks[:6]:  # Show max 6 tasks
            name = task.get('name', 'N/A')
            state = task.get('state', {}).get('state', 'UNKNOWN')
            last_run = task.get('state', {}).get('datetime', 'Never')

            # Color code state
            if state == 'SUCCESS':
                state_style = "green"
            elif state == 'RUNNING':
                state_style = "yellow"
            elif state == 'ERROR':
                state_style = "red"
            else:
                state_style = "dim"

            # Format last run time
            if last_run != 'Never':
                try:
                    dt = datetime.fromisoformat(last_run)
                    last_run = dt.strftime('%m-%d %H:%M')
                except:
                    pass

            table.add_row(
                name[:30],
                Text(state, style=state_style),
                last_run
            )

        if not tasks:
            table.add_row("No replication tasks", "", "")

        return Panel(table, title="Replication Status", border_style="green")

    def create_service_panel(self) -> Panel:
        """Create service status panel"""
        services = self.get_services()

        # Filter to show only important services
        important_services = ['smb', 'nfs', 'ssh', 'wireguard', 'cifs']
        services = [s for s in services if s.get('service') in important_services]

        table = Table(box=box.SIMPLE, show_header=True, header_style="bold white")
        table.add_column("Service", style="cyan")
        table.add_column("State", justify="center")
        table.add_column("Startup", justify="center")

        for svc in services:
            service_name = svc.get('service', 'N/A').upper()
            state = svc.get('state', 'UNKNOWN')
            enabled = svc.get('enable', False)

            # Color code state
            if state == 'RUNNING':
                state_style = "green"
                state_text = "Running"
            else:
                state_style = "red"
                state_text = "Stopped"

            startup = "Enabled" if enabled else "Disabled"
            startup_style = "green" if enabled else "dim"

            table.add_row(
                service_name,
                Text(state_text, style=state_style),
                Text(startup, style=startup_style)
            )

        return Panel(table, title="Service Status", border_style="white")

    def create_alerts_panel(self) -> Panel:
        """Create alerts panel"""
        alerts = self.get_alerts()

        table = Table(box=box.SIMPLE, show_header=True, header_style="bold red")
        table.add_column("Level", style="red", width=8)
        table.add_column("Message", style="white")

        if not alerts:
            table.add_row("INFO", Text("No active alerts", style="green"))
        else:
            for alert in alerts[:5]:  # Show max 5 alerts
                level = alert.get('level', 'INFO')
                message = alert.get('formatted', 'N/A')

                # Color code alert level
                if level == 'CRITICAL':
                    level_style = "red bold"
                elif level == 'WARNING':
                    level_style = "yellow"
                else:
                    level_style = "dim"

                # Truncate long messages
                if len(message) > 60:
                    message = message[:57] + "..."

                table.add_row(
                    Text(level, style=level_style),
                    message
                )

        return Panel(table, title="System Alerts", border_style="red")

    def create_layout(self) -> Layout:
        """Create dashboard layout"""
        layout = Layout()

        # Main layout structure
        layout.split_column(
            Layout(name="header", size=5),
            Layout(name="body"),
            Layout(name="footer", size=3)
        )

        # Body layout
        layout["body"].split_row(
            Layout(name="left"),
            Layout(name="right")
        )

        # Left column
        layout["left"].split_column(
            Layout(name="pools"),
            Layout(name="datasets")
        )

        # Right column
        layout["right"].split_column(
            Layout(name="top_right"),
            Layout(name="bottom_right")
        )

        layout["top_right"].split_row(
            Layout(name="replication"),
            Layout(name="services")
        )

        layout["bottom_right"].split_column(
            Layout(name="snapshots"),
            Layout(name="alerts")
        )

        return layout

    def update_layout(self, layout: Layout):
        """Update layout with fresh data"""
        layout["header"].update(self.create_header())
        layout["pools"].update(self.create_pool_panel())
        layout["datasets"].update(self.create_dataset_panel())
        layout["snapshots"].update(self.create_snapshot_panel())
        layout["replication"].update(self.create_replication_panel())
        layout["services"].update(self.create_service_panel())
        layout["alerts"].update(self.create_alerts_panel())

        # Footer
        footer_text = Text()
        footer_text.append("Press ", style="dim")
        footer_text.append("Ctrl+C", style="bold red")
        footer_text.append(" to exit | Auto-refresh every 5 seconds", style="dim")
        layout["footer"].update(Panel(footer_text, style="dim"))

    def run(self, refresh_interval: int = 5):
        """Run the dashboard"""
        layout = self.create_layout()

        try:
            with Live(layout, console=self.console, screen=True, refresh_per_second=1):
                while True:
                    self.update_layout(layout)
                    time.sleep(refresh_interval)
        except KeyboardInterrupt:
            self.console.print("\n[yellow]Dashboard stopped by user[/yellow]")


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description="TrueNAS Real-time Dashboard")
    parser.add_argument('--config', type=str, help='Path to config file')
    parser.add_argument('--refresh', type=int, default=5, help='Refresh interval in seconds')

    args = parser.parse_args()

    config_path = Path(args.config) if args.config else None

    try:
        dashboard = TrueNASDashboard(config_path)
        dashboard.run(refresh_interval=args.refresh)
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
