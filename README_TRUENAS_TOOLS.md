# TrueNAS API Automation Tools

Complete Python toolkit for managing TrueNAS SCALE from Windows.

## Quick Start

### 1. Install (One Command)
```batch
START_HERE.bat
```

This will:
- Check Python installation
- Install dependencies
- Configure API access
- Test the installation

### 2. Use

```bash
# Launch dashboard
python truenas-dashboard.py

# Check system health
python truenas-manager.py health system

# List pools
python truenas-manager.py pool list

# Create snapshot
python truenas-snapshot-manager.py create tank/important --recursive

# Monitor replication
python truenas-replication-manager.py monitor
```

## What's Included

### Management Tools
- **truenas-manager.py** - Comprehensive CLI for pools, datasets, snapshots, replication, SMB, users, health
- **truenas-dashboard.py** - Real-time monitoring dashboard with auto-refresh
- **truenas-snapshot-manager.py** - Advanced snapshot operations with retention policies
- **truenas-replication-manager.py** - Replication control with monitoring and retry
- **truenas-api-examples.py** - 12 interactive code examples

### Total: 39+ commands, 3,249 lines of code

## Documentation

- **TRUENAS_API_TOOLS_README.md** - Complete guide (600+ lines)
- **QUICK_REFERENCE.md** - Command cheat sheet
- **TRUENAS_TOOLS_INDEX.md** - Complete index
- **IMPLEMENTATION_SUMMARY.md** - What was created

## Features

- Complete TrueNAS control via API
- Real-time monitoring dashboard
- Advanced snapshot management with retention policies
- Replication monitoring with automatic retry
- SMB share management
- Health monitoring and alerting
- Bulk operations with dry-run mode
- Rich terminal UI with color coding
- Comprehensive error handling
- Safety confirmations for destructive operations

## Requirements

- Python 3.8+
- TrueNAS SCALE with API access
- Windows 10/11

## Installation

### Manual Installation
```bash
# Install dependencies
pip install -r requirements.txt

# Configure API access
python truenas-api-setup.py --setup

# Test installation
python test-truenas-tools.py
```

### Automated Installation
```batch
START_HERE.bat
```

## Common Commands

```bash
# System
python truenas-manager.py health system
python truenas-manager.py health alerts

# Pools
python truenas-manager.py pool list
python truenas-manager.py pool check-capacity --threshold 80

# Snapshots
python truenas-snapshot-manager.py list
python truenas-snapshot-manager.py create tank/data --recursive
python truenas-snapshot-manager.py retention tank/data --hourly 24 --daily 7 --weekly 4 --monthly 12

# Replication
python truenas-replication-manager.py list
python truenas-replication-manager.py run 1 --wait
python truenas-replication-manager.py retry-failed

# Dashboard
python truenas-dashboard.py
```

## Documentation Quick Links

| Document | Purpose |
|----------|---------|
| README_TRUENAS_TOOLS.md | This file - quick overview |
| TRUENAS_API_TOOLS_README.md | Complete documentation |
| QUICK_REFERENCE.md | Command reference |
| TRUENAS_TOOLS_INDEX.md | Complete index |
| IMPLEMENTATION_SUMMARY.md | Implementation details |

## Files Overview

### Core Tools (5 files)
- truenas-manager.py (754 lines) - Main management CLI
- truenas-dashboard.py (441 lines) - Monitoring dashboard
- truenas-snapshot-manager.py (514 lines) - Snapshot operations
- truenas-replication-manager.py (619 lines) - Replication control
- truenas-api-examples.py (663 lines) - Code examples

### Setup & Testing (3 files)
- truenas-api-setup.py - Initial configuration
- test-truenas-tools.py (258 lines) - Installation validation
- START_HERE.bat - Automated setup script

### Configuration (1 file)
- requirements.txt - Python dependencies

### Documentation (4 files)
- TRUENAS_API_TOOLS_README.md - Complete guide
- QUICK_REFERENCE.md - Command reference
- TRUENAS_TOOLS_INDEX.md - Complete index
- IMPLEMENTATION_SUMMARY.md - Implementation details

## Support

- Read the documentation in TRUENAS_API_TOOLS_README.md
- Try the examples: `python truenas-api-examples.py`
- Test installation: `python test-truenas-tools.py`
- Get command help: `python <tool>.py --help`

## License

Tools provided as-is for TrueNAS SCALE management.

## Version

v1.0 - Created December 10, 2024
