# sync-now.ps1
# Quick on-demand sync of D:\workspace to Baby NAS
# Run this script manually when you want an immediate sync

[CmdletBinding()]
param(
    [switch]$Mirror,    # Enable mirror mode (deletes files on NAS not in source)
    [switch]$DryRun,    # Preview what would be synced without making changes
    [switch]$Help
)

if ($Help) {
    Write-Host @"

Workspace Sync to Baby NAS
==========================

Usage: .\sync-now.ps1 [-Mirror] [-DryRun] [-Help]

Parameters:
  -Mirror   Enable mirror mode. This will DELETE files on the NAS
            that don't exist in D:\workspace. Use with caution!

  -DryRun   Preview mode. Shows what would be copied without
            actually copying anything.

  -Help     Show this help message.

Examples:
  .\sync-now.ps1              # Regular copy sync (safe, preserves NAS extras)
  .\sync-now.ps1 -DryRun      # Preview what would be synced
  .\sync-now.ps1 -Mirror      # Full mirror sync (deletes extras on NAS)

Source:      D:\workspace
Destination: W:\ (\\10.0.0.88\workspace)

Excluded directories:
  node_modules, .git, __pycache__, .venv, venv, .next, dist, build, .cache

"@
    exit 0
}

# Build arguments
$syncArgs = @{}
if ($Mirror) { $syncArgs['Mirror'] = $true }
if ($DryRun) { $syncArgs['DryRun'] = $true }

# Get the directory where this script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Run the main sync script
& "$scriptDir\sync-workspace-to-nas.ps1" @syncArgs
