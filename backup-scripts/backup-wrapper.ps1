# backup-wrapper.ps1
# Wrapper script that retrieves RESTIC_PASSWORD from 1Password and calls the main backup script
# Used by scheduled task to ensure password is available

$ErrorActionPreference = "Stop"

# Ensure Restic is in PATH for this session
$env:Path = "C:\Tools\restic;$env:Path"

# Retrieve password from 1Password CLI
try {
    $env:RESTIC_PASSWORD = & op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal

    if ([string]::IsNullOrEmpty($env:RESTIC_PASSWORD)) {
        throw "Failed to retrieve password from 1Password"
    }
} catch {
    Write-Error "ERROR: Could not retrieve Restic password from 1Password: $_"
    exit 1
}

# Call the main backup script
& "$PSScriptRoot\backup-baby-nas.ps1"

exit $LASTEXITCODE
