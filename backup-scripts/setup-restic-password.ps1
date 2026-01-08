# setup-restic-password.ps1
# Store Restic password in Windows Credential Manager (one-time)

param(
    [Parameter(Mandatory=$true)]
    [string]$Password
)

# Requires CredentialManager module
if (-not (Get-Module -ListAvailable -Name CredentialManager)) {
    Write-Host "Installing CredentialManager module..." -ForegroundColor Yellow
    Install-Module -Name CredentialManager -Force -Scope CurrentUser
}

Import-Module CredentialManager

# Store password
New-StoredCredential -Target "ResticBabyNAS" -UserName "restic" -Password $Password -Persist LocalMachine

Write-Host "Password stored in Credential Manager as 'ResticBabyNAS'" -ForegroundColor Green
Write-Host "Backup script will use this automatically." -ForegroundColor Green
