# verify-backup-health.ps1
# Check backup integrity and show statistics

param(
    [string]$RepoPath = "D:\backups\baby_nas_restic"
)

# Ensure Restic is in PATH for this session
$env:Path = "C:\Tools\restic;$env:Path"

Write-Host "=== Backup Health Check ===" -ForegroundColor Cyan

# Retrieve password from 1Password
Write-Host "Retrieving password from 1Password..." -ForegroundColor Yellow
try {
    $env:RESTIC_PASSWORD = & op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal
    if ([string]::IsNullOrEmpty($env:RESTIC_PASSWORD)) {
        throw "Failed to retrieve password from 1Password"
    }
} catch {
    Write-Error "ERROR: Could not retrieve password from 1Password: $_"
    exit 1
}

# List snapshots
Write-Host "`nRecent snapshots:" -ForegroundColor Yellow
& restic snapshots --repo $RepoPath --last 10 --tag automated

# Check repository integrity
Write-Host "`nVerifying repository integrity..." -ForegroundColor Yellow
& restic check --repo $RepoPath

# Show storage statistics
Write-Host "`nStorage statistics:" -ForegroundColor Yellow
& restic stats --repo $RepoPath --mode restore-size

Write-Host "`n=== Health Check Complete ===" -ForegroundColor Green
