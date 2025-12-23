# Load-EnvFile.ps1
# Helper function to load environment variables from .env file
# Usage: . .\Load-EnvFile.ps1

function Load-EnvFile {
    param(
        [string]$EnvFilePath = ".\.env"
    )

    if (-not (Test-Path $EnvFilePath)) {
        Write-Warning ".env file not found at: $EnvFilePath"
        Write-Warning "Please copy .env.example to .env and configure your credentials"
        return $false
    }

    Write-Verbose "Loading environment variables from: $EnvFilePath"

    Get-Content $EnvFilePath | ForEach-Object {
        $line = $_.Trim()

        # Skip empty lines and comments
        if ($line -eq '' -or $line.StartsWith('#')) {
            return
        }

        # Parse key=value
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Remove quotes if present
            $value = $value -replace '^["'']|["'']$', ''

            # Set environment variable
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
            Write-Verbose "Set environment variable: $key"
        }
    }

    return $true
}

function Get-EnvVariable {
    param(
        [string]$Name,
        [string]$Default = $null
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")

    if ([string]::IsNullOrEmpty($value)) {
        if ($null -ne $Default) {
            return $Default
        }
        Write-Warning "Environment variable '$Name' is not set"
        return $null
    }

    return $value
}

# Auto-load .env if this script is dot-sourced
if ($MyInvocation.InvocationName -eq '.') {
    $envPath = Join-Path $PSScriptRoot ".env"
    Load-EnvFile -EnvFilePath $envPath
}
