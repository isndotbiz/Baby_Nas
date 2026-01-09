# sync-wrapper.ps1
# Wrapper script for scheduled task execution
# Handles SMB credential retrieval from 1Password if needed

[CmdletBinding()]
param(
    [switch]$Mirror,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$logPath = "D:\workspace\Baby_Nas\backup-scripts\logs"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Ensure log directory exists
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

function Write-WrapperLog {
    param([string]$Message)
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [WRAPPER] $Message"
    Write-Host $entry
    Add-Content -Path "$logPath\sync_wrapper_$timestamp.log" -Value $entry
}

try {
    Write-WrapperLog "Sync wrapper starting..."

    # Check if NAS is reachable before doing anything
    $nasIP = "10.0.0.88"
    Write-WrapperLog "Testing connectivity to Baby NAS ($nasIP)..."

    $pingResult = Test-Connection -ComputerName $nasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $pingResult) {
        Write-WrapperLog "WARNING: Baby NAS not responding to ping. Attempting sync anyway..."
    } else {
        Write-WrapperLog "Baby NAS is reachable."
    }

    # Check if W: drive is accessible, if not try to mount with credentials from 1Password
    if (-not (Test-Path "W:\")) {
        Write-WrapperLog "W: drive not accessible. Attempting to mount with SMB credentials..."

        # Try to get SMB credentials from 1Password
        try {
            $smbUser = & op item get "Baby NAS - SMB User" --vault "TrueNAS Infrastructure" --fields username --reveal 2>$null
            $smbPass = & op item get "Baby NAS - SMB User" --vault "TrueNAS Infrastructure" --fields password --reveal 2>$null

            if (-not [string]::IsNullOrEmpty($smbUser) -and -not [string]::IsNullOrEmpty($smbPass)) {
                Write-WrapperLog "Retrieved credentials from 1Password. Mounting W: drive..."

                # Remove any stale connection first
                net use W: /delete /y 2>$null

                # Mount with credentials
                $mountResult = net use W: "\\10.0.0.88\workspace" /user:$smbUser $smbPass /persistent:yes 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-WrapperLog "Successfully mounted W: drive."
                } else {
                    Write-WrapperLog "Mount command returned: $mountResult"
                }
            } else {
                Write-WrapperLog "Could not retrieve SMB credentials from 1Password."
            }
        } catch {
            Write-WrapperLog "1Password CLI not available or credentials not found: $($_.Exception.Message)"
            Write-WrapperLog "Continuing without credential retrieval. Drive may already be mapped."
        }
    } else {
        Write-WrapperLog "W: drive is accessible."
    }

    # Build arguments for main sync script
    $syncArgs = @()
    if ($Mirror) {
        $syncArgs += "-Mirror"
    }
    if ($Force) {
        $syncArgs += "-Force"
    }

    # Call the main sync script
    Write-WrapperLog "Calling main sync script..."
    $scriptPath = Join-Path $PSScriptRoot "sync-workspace-to-nas.ps1"

    if ($syncArgs.Count -gt 0) {
        & $scriptPath @syncArgs
    } else {
        & $scriptPath
    }

    $syncExitCode = $LASTEXITCODE
    Write-WrapperLog "Sync script completed with exit code: $syncExitCode"

    exit $syncExitCode

} catch {
    Write-WrapperLog "ERROR: $($_.Exception.Message)"
    exit 1
}
