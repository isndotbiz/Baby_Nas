<#
.SYNOPSIS
Configure automated snapshots on Baby NAS

.DESCRIPTION
Sets up hourly, daily, and weekly snapshots with retention policies on the tank pool.
Uses truenas-snapshot-manager.py for configuration.

Snapshot schedule:
  - Hourly: Every hour, keep last 24
  - Daily: At 3:00 AM, keep last 7
  - Weekly: Every Sunday 4:00 AM, keep last 4

.PARAMETER Schedule
  Configure snapshot schedule (Setup, View, or Delete)

.EXAMPLE
  # Setup snapshots
  .\setup-snapshots.ps1

  # View current snapshots
  .\setup-snapshots.ps1 -Schedule View

  # Remove snapshot tasks
  .\setup-snapshots.ps1 -Schedule Delete

.NOTES
  Requires: truenas-snapshot-manager.py, Python 3.7+
  Credentials: Expects .env file with TrueNAS API key
#>

param(
    [ValidateSet("Setup", "View", "Delete")]
    [string]$Schedule = "Setup"
)

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Baby NAS Snapshot Configuration                      ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$pythonTool = "D:\workspace\Baby_Nas\truenas-snapshot-manager.py"

if (-not (Test-Path $pythonTool)) {
    Write-Host "ERROR: truenas-snapshot-manager.py not found" -ForegroundColor Red
    Write-Host "Expected: $pythonTool" -ForegroundColor Yellow
    exit 1
}

Write-Host "Snapshot Configuration Tool" -ForegroundColor Yellow
Write-Host ""

switch ($Schedule) {
    "Setup" {
        Write-Host "=== Setting Up Snapshot Schedule ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Snapshot Plan:" -ForegroundColor Yellow
        Write-Host "  ✓ Hourly snapshots (every hour, keep 24)" -ForegroundColor White
        Write-Host "    Purpose: Quick recovery from recent issues" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  ✓ Daily snapshots (3:00 AM, keep 7 days)" -ForegroundColor White
        Write-Host "    Purpose: Daily recovery points, one week retention" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  ✓ Weekly snapshots (Sunday 4:00 AM, keep 4 weeks)" -ForegroundColor White
        Write-Host "    Purpose: Monthly archives, long-term retention" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Executing snapshot configuration..." -ForegroundColor Cyan
        Write-Host ""

        # Run Python tool to set up snapshots
        try {
            # Hourly
            Write-Host "Creating hourly snapshot task..." -ForegroundColor Yellow
            python $pythonTool create-schedule tank hourly --frequency hourly --retention 24

            # Daily
            Write-Host "Creating daily snapshot task..." -ForegroundColor Yellow
            python $pythonTool create-schedule tank daily --frequency daily --time "03:00" --retention 7

            # Weekly
            Write-Host "Creating weekly snapshot task..." -ForegroundColor Yellow
            python $pythonTool create-schedule tank weekly --frequency weekly --day-of-week Sunday --time "04:00" --retention 4

            Write-Host ""
            Write-Host "✓ Snapshots configured successfully" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: Failed to configure snapshots" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    "View" {
        Write-Host "=== Current Snapshot Configuration ===" -ForegroundColor Cyan
        Write-Host ""

        try {
            python $pythonTool list-schedules
        } catch {
            Write-Host "ERROR: Failed to retrieve snapshots" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    "Delete" {
        Write-Host "=== Remove Snapshot Configuration ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "WARNING: This will remove all automated snapshots!" -ForegroundColor Yellow
        Write-Host ""

        $confirm = Read-Host "Type 'DELETE' to confirm"

        if ($confirm -eq "DELETE") {
            try {
                python $pythonTool delete-schedule --all
                Write-Host ""
                Write-Host "✓ Snapshot schedules removed" -ForegroundColor Green
            } catch {
                Write-Host "ERROR: Failed to remove schedules" -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor Red
            }
        } else {
            Write-Host "Cancelled" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Additional snapshot commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "List all snapshots:" -ForegroundColor White
Write-Host "  python truenas-snapshot-manager.py list tank" -ForegroundColor Gray
Write-Host ""
Write-Host "Create manual snapshot:" -ForegroundColor White
Write-Host "  python truenas-snapshot-manager.py snapshot tank manual-snapshot-name" -ForegroundColor Gray
Write-Host ""
Write-Host "Delete specific snapshot:" -ForegroundColor White
Write-Host "  python truenas-snapshot-manager.py delete tank snapshot-name" -ForegroundColor Gray
Write-Host ""
