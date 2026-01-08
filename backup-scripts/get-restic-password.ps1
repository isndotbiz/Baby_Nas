# get-restic-password.ps1
# Helper script to retrieve Restic password from 1Password CLI
# Returns the password or exits with error

$ErrorActionPreference = "Stop"

try {
    $password = & op item get "BabyNAS Restic Backup" --vault "TrueNAS Infrastructure" --fields password --reveal 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "1Password CLI returned error code $LASTEXITCODE"
    }

    if ([string]::IsNullOrEmpty($password)) {
        throw "Retrieved password is empty"
    }

    # Return password to caller
    return $password

} catch {
    Write-Error "ERROR: Could not retrieve Restic password from 1Password: $_"
    Write-Error "Make sure 1Password CLI is installed and you are signed in: 'op account list'"
    exit 1
}
