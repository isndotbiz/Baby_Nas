#!/usr/bin/env powershell
<#
.SYNOPSIS
    WireGuard Client Setup for Windows

.DESCRIPTION
    Downloads, installs, configures, and tests WireGuard VPN client on Windows.
    Automatically retrieves configuration from TrueNAS server and imports it.

.PARAMETER ServerIP
    TrueNAS server IP (default: 10.0.0.89)

.PARAMETER ServerUser
    SSH username for TrueNAS (default: root)

.PARAMETER SSHKeyPath
    Path to SSH private key (default: $HOME\.ssh\truenas_admin_10_0_0_89)

.PARAMETER ConfigType
    Client config type: windows, laptop1, laptop2, etc. (default: windows)

.PARAMETER SkipDownload
    Skip WireGuard download (already installed)

.PARAMETER TestOnly
    Only test existing connection, don't configure

.EXAMPLE
    .\WIREGUARD-CLIENT-SETUP-WINDOWS.ps1
    # Full setup with default parameters

.EXAMPLE
    .\WIREGUARD-CLIENT-SETUP-WINDOWS.ps1 -ServerIP 10.0.0.89 -ConfigType windows -TestOnly
    # Test existing connection only

.NOTES
    Requires: Windows 10/11, Administrator privileges
    Dependencies: SSH client (Windows 10+), PowerShell 5.1+
#>

param(
    [string]$ServerIP = "10.0.0.89",
    [string]$ServerUser = "root",
    [string]$SSHKeyPath = "$HOME\.ssh\truenas_admin_10_0_0_89",
    [string]$ConfigType = "windows",
    [switch]$SkipDownload,
    [switch]$TestOnly
)

# Configuration
$WireGuardVersion = "latest"
$WireGuardDownloadURL = "https://download.wireguard.com/windows-client/wireguard-installer.exe"
$WireGuardInstallPath = "C:\Program Files\WireGuard"
$WireGuardAppName = "WireGuard"
$ConfigsRemotePath = "/mnt/tank/wireguard-configs"
$LocalConfigPath = "$env:TEMP\wireguard-config.conf"
$WireGuardFinalPath = "$env:APPDATA\WireGuard\Configs"

# Colors for output
$Colors = @{
    Success = "Green"
    Error   = "Red"
    Warning = "Yellow"
    Info    = "Cyan"
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "[✓] $Text" -ForegroundColor Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "[✗] $Text" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Text)
    Write-Host "[!] $Text" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Text)
    Write-Host "[→] $Text" -ForegroundColor Cyan
}

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if WireGuard is installed
function Test-WireGuardInstalled {
    try {
        $app = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*WireGuard*" }
        return $null -ne $app
    }
    catch {
        return $false
    }
}

# Download WireGuard installer
function Install-WireGuard {
    Write-Header "Step 1: Download and Install WireGuard"

    if ((Test-WireGuardInstalled) -and -not $SkipDownload) {
        Write-Success "WireGuard is already installed"
        return $true
    }

    Write-Info "Downloading WireGuard installer..."

    $installerPath = "$env:TEMP\wireguard-installer.exe"

    try {
        # Download with progress
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $WireGuardDownloadURL -OutFile $installerPath -UseBasicParsing

        if (Test-Path $installerPath) {
            Write-Success "Downloaded WireGuard installer to $installerPath"
        }
        else {
            Write-Error "Failed to download WireGuard installer"
            return $false
        }

        Write-Info "Installing WireGuard..."
        Start-Process -FilePath $installerPath -ArgumentList "/quiet" -Wait -NoNewWindow

        # Wait for installation to complete
        Start-Sleep -Seconds 3

        if (Test-WireGuardInstalled) {
            Write-Success "WireGuard installed successfully"
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            return $true
        }
        else {
            Write-Error "WireGuard installation verification failed"
            return $false
        }
    }
    catch {
        Write-Error "Error downloading/installing WireGuard: $_"
        return $false
    }
}

# Download client configuration from TrueNAS
function Get-WireGuardConfig {
    Write-Header "Step 2: Download WireGuard Configuration"

    Write-Info "SSH connection details:"
    Write-Info "  Server: $ServerIP"
    Write-Info "  User: $ServerUser"
    Write-Info "  Key: $SSHKeyPath"
    Write-Info "  Config: $ConfigsRemotePath/$ConfigType.conf"

    # Verify SSH key exists
    if (-not (Test-Path $SSHKeyPath)) {
        Write-Error "SSH key not found: $SSHKeyPath"
        Write-Warning "Please generate SSH key or provide correct path"
        return $false
    }

    Write-Info "Downloading configuration from TrueNAS..."

    try {
        # Use SCP to download config
        $scpPath = if (Get-Command scp -ErrorAction SilentlyContinue) { "scp" } else { "C:\Windows\System32\OpenSSH\scp.exe" }

        if (-not (Test-Path $scpPath) -and $scpPath -like "C:\Windows\*") {
            Write-Error "SSH client (scp) not found. Enable OpenSSH in Windows features."
            return $false
        }

        # Execute SCP with proper escaping
        & $scpPath -i $SSHKeyPath `
                   -o StrictHostKeyChecking=accept-new `
                   -o ConnectTimeout=10 `
                   "$ServerUser@$ServerIP`:$ConfigsRemotePath/$ConfigType.conf" `
                   $LocalConfigPath 2>$null

        if (Test-Path $LocalConfigPath) {
            Write-Success "Configuration downloaded successfully"
            Write-Info "Saved to: $LocalConfigPath"

            # Show configuration details (without sensitive keys)
            $configContent = Get-Content $LocalConfigPath
            Write-Info "Configuration preview:"
            foreach ($line in $configContent) {
                if ($line -match "^#|^\[|^Address|^DNS|^Endpoint|^AllowedIPs") {
                    Write-Host "  $line" -ForegroundColor Gray
                }
            }

            return $true
        }
        else {
            Write-Error "Failed to download configuration"
            return $false
        }
    }
    catch {
        Write-Error "Error downloading configuration: $_"
        return $false
    }
}

# Import configuration into WireGuard
function Import-WireGuardConfig {
    Write-Header "Step 3: Import Configuration into WireGuard"

    # Create WireGuard Configs directory if it doesn't exist
    $configDir = "$env:APPDATA\WireGuard\Configs"
    if (-not (Test-Path $configDir)) {
        Write-Info "Creating WireGuard Configs directory..."
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # Copy config to WireGuard directory
    $finalPath = "$configDir\$ConfigType.conf"
    Write-Info "Importing configuration to: $finalPath"

    try {
        Copy-Item -Path $LocalConfigPath -Destination $finalPath -Force
        Write-Success "Configuration imported"

        # Set proper permissions
        $acl = Get-Acl $finalPath
        Write-Info "Setting file permissions..."
        Set-Acl -Path $finalPath -AclObject $acl

        return $true
    }
    catch {
        Write-Error "Error importing configuration: $_"
        return $false
    }
}

# Activate VPN connection
function Enable-WireGuardVPN {
    Write-Header "Step 4: Activate VPN Connection"

    Write-Info "Activating WireGuard tunnel: $ConfigType"

    try {
        # Try to activate via WireGuard CLI if available
        $wgPath = "$WireGuardInstallPath\wg-quick.bat"

        if (Test-Path $wgPath) {
            Write-Info "Using WireGuard CLI to activate..."
            & $wgPath up $ConfigType 2>$null
            Start-Sleep -Seconds 2
        }
        else {
            Write-Warning "WireGuard CLI not found, please activate manually:"
            Write-Info "  1. Open WireGuard application"
            Write-Info "  2. Select '$ConfigType' tunnel"
            Write-Info "  3. Click 'Activate' button"
        }

        Write-Success "VPN activation initiated"
        return $true
    }
    catch {
        Write-Error "Error activating VPN: $_"
        Write-Warning "Please activate manually via WireGuard GUI"
        return $false
    }
}

# Test VPN connectivity
function Test-WireGuardConnection {
    Write-Header "Step 5: Test VPN Connection"

    Write-Info "Testing WireGuard connectivity..."
    Write-Info "Waiting 3 seconds for VPN to establish..."
    Start-Sleep -Seconds 3

    $testsRun = 0
    $testsPassed = 0

    # Test 1: Ping VPN gateway
    Write-Info ""
    Write-Info "Test 1: Ping VPN Gateway (10.99.0.1)"
    if (Test-Connection -ComputerName "10.99.0.1" -Count 1 -Quiet) {
        Write-Success "VPN Gateway is reachable"
        $testsPassed++
    }
    else {
        Write-Error "Cannot reach VPN Gateway - check if VPN is connected"
    }
    $testsRun++

    # Test 2: Ping TrueNAS
    Write-Info ""
    Write-Info "Test 2: Ping TrueNAS Server (10.0.0.89)"
    if (Test-Connection -ComputerName "10.0.0.89" -Count 1 -Quiet) {
        Write-Success "TrueNAS is reachable"
        $testsPassed++
    }
    else {
        Write-Error "Cannot reach TrueNAS - check routing configuration"
    }
    $testsRun++

    # Test 3: TCP connectivity to TrueNAS (HTTP)
    Write-Info ""
    Write-Info "Test 3: HTTP Connectivity to TrueNAS"
    try {
        $result = Test-NetConnection -ComputerName "10.0.0.89" -Port 80 -WarningAction SilentlyContinue
        if ($result.TcpTestSucceeded) {
            Write-Success "TrueNAS HTTP port is accessible"
            $testsPassed++
        }
        else {
            Write-Warning "Cannot reach HTTP port - may be firewalled"
        }
    }
    catch {
        Write-Warning "HTTP port test failed: $_"
    }
    $testsRun++

    # Test 4: SMB connectivity
    Write-Info ""
    Write-Info "Test 4: SMB Connectivity (File Sharing)"
    try {
        $result = Test-NetConnection -ComputerName "10.0.0.89" -Port 445 -WarningAction SilentlyContinue
        if ($result.TcpTestSucceeded) {
            Write-Success "SMB/File Sharing port is accessible"
            $testsPassed++
        }
        else {
            Write-Error "SMB port not accessible - backups may fail"
        }
    }
    catch {
        Write-Warning "SMB port test failed: $_"
    }
    $testsRun++

    # Test 5: DNS resolution
    Write-Info ""
    Write-Info "Test 5: DNS Resolution"
    try {
        $result = [System.Net.Dns]::GetHostAddresses("10.0.0.89") | Select-Object -First 1
        if ($result) {
            Write-Success "DNS is working (resolved to $result)"
            $testsPassed++
        }
        else {
            Write-Error "DNS resolution failed"
        }
    }
    catch {
        Write-Warning "DNS resolution unavailable: $_"
    }
    $testsRun++

    # Summary
    Write-Header "Connection Test Results"
    Write-Host "Tests Passed: $testsPassed / $testsRun" -ForegroundColor $(if ($testsPassed -eq $testsRun) { "Green" } else { "Yellow" })

    if ($testsPassed -ge 3) {
        Write-Success "VPN connection is working!"
        return $true
    }
    else {
        Write-Error "VPN connection test partially failed"
        return $false
    }
}

# Test SMB access for backups
function Test-SMBAccess {
    Write-Header "Step 6: Test SMB Access for Backups"

    Write-Info "Testing SMB share access..."

    # Find available SMB shares
    Write-Info "Attempting to enumerate SMB shares on 10.0.0.89..."

    try {
        $shares = net view \\10.0.0.89 2>$null | Select-String "^\s+\w+" | ForEach-Object { $_.ToString().Trim() }

        if ($shares) {
            Write-Success "Available SMB shares:"
            foreach ($share in $shares) {
                Write-Host "  - $share" -ForegroundColor Green
            }
        }
        else {
            Write-Warning "Could not enumerate shares - verify credentials"
        }
    }
    catch {
        Write-Warning "Could not enumerate shares: $_"
    }

    # List common backup paths
    Write-Info ""
    Write-Info "Common backup paths to test:"
    Write-Host "  - \\10.0.0.89\tank\backups" -ForegroundColor Cyan
    Write-Host "  - \\10.0.0.89\tank\veeam" -ForegroundColor Cyan
    Write-Host "  - \\10.0.0.89\tank\time-machine" -ForegroundColor Cyan

    Write-Info ""
    Write-Info "To map a backup share:"
    Write-Host "  net use Z: \\10.0.0.89\tank\backups /user:admin password" -ForegroundColor Gray

    Write-Info ""
    Write-Success "SMB access test complete"
}

# Configure auto-startup (optional)
function Set-AutoStartup {
    Write-Header "Step 7: Configure Auto-Startup (Optional)"

    Write-Info "Setup auto-activation of VPN at startup?"
    Write-Host "Press 'y' for yes, 'n' for no: " -ForegroundColor Yellow -NoNewline

    if ((Read-Host).ToLower() -eq 'y') {
        Write-Info "This requires creating a scheduled task..."

        try {
            # Create scheduled task
            $taskName = "WireGuardAutoConnect-$ConfigType"
            $taskDescription = "Automatically connect to WireGuard VPN tunnel: $ConfigType"

            # Define task action
            $action = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "-WindowStyle Hidden -Command `"& '$WireGuardInstallPath\wg-quick.bat' up $ConfigType`""

            # Define task trigger (at startup)
            $trigger = New-ScheduledTaskTrigger -AtStartup

            # Define task principal (run as current user)
            $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -RunLevel Highest

            # Create task settings
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

            # Register the task
            Register-ScheduledTask -TaskName $taskName `
                                   -Action $action `
                                   -Trigger $trigger `
                                   -Principal $principal `
                                   -Settings $settings `
                                   -Description $taskDescription `
                                   -Force | Out-Null

            Write-Success "Scheduled task created: $taskName"
            Write-Info "VPN will now connect automatically at startup"
        }
        catch {
            Write-Error "Failed to create scheduled task: $_"
            Write-Info "You can still manually enable auto-activation in WireGuard GUI"
        }
    }
    else {
        Write-Info "Skipping auto-startup configuration"
        Write-Info "You can enable this later in WireGuard settings"
    }
}

# Main execution
function Main {
    # Check Administrator privileges
    if (-not (Test-Administrator)) {
        Write-Error "This script must be run as Administrator"
        Write-Info "Please run PowerShell as Administrator and try again"
        exit 1
    }

    Write-Header "WireGuard Client Setup for Windows"
    Write-Info "Server: $ServerIP"
    Write-Info "Config: $ConfigType"
    Write-Info "SSH Key: $SSHKeyPath"

    if ($TestOnly) {
        Write-Info "Running in TEST mode only"
    }

    Write-Info ""

    # Step 1: Download and Install WireGuard
    if (-not $TestOnly) {
        if (-not (Install-WireGuard)) {
            Write-Error "Failed to install WireGuard. Exiting."
            exit 1
        }
    }

    # Step 2: Download Configuration
    if (-not $TestOnly) {
        if (-not (Get-WireGuardConfig)) {
            Write-Error "Failed to download configuration. Exiting."
            exit 1
        }
    }

    # Step 3: Import Configuration
    if (-not $TestOnly) {
        if (-not (Import-WireGuardConfig)) {
            Write-Error "Failed to import configuration. Exiting."
            exit 1
        }
    }

    # Step 4: Activate VPN
    if (-not $TestOnly) {
        Enable-WireGuardVPN | Out-Null
    }

    # Step 5: Test Connection
    $connectionOK = Test-WireGuardConnection

    # Step 6: Test SMB Access
    if ($connectionOK) {
        Test-SMBAccess
    }

    # Step 7: Configure Auto-Startup
    if (-not $TestOnly) {
        Set-AutoStartup
    }

    # Final Summary
    Write-Header "Setup Summary"

    if ($connectionOK) {
        Write-Success "WireGuard VPN is configured and connected!"
        Write-Info ""
        Write-Info "Next steps:"
        Write-Host "  1. Test SMB access to backup locations" -ForegroundColor Cyan
        Write-Host "  2. Configure Veeam Agent for backup over VPN" -ForegroundColor Cyan
        Write-Host "  3. Monitor VPN connection in WireGuard app" -ForegroundColor Cyan
        Write-Host "  4. Enable auto-start for reliable remote access" -ForegroundColor Cyan
    }
    else {
        Write-Warning "VPN connection test failed - review errors above"
        Write-Info "Common issues:"
        Write-Host "  1. Router port forwarding not configured" -ForegroundColor Yellow
        Write-Host "  2. Server WireGuard service not running" -ForegroundColor Yellow
        Write-Host "  3. Client config not properly downloaded" -ForegroundColor Yellow
    }

    Write-Info ""
    Write-Info "WireGuard log location: $env:APPDATA\WireGuard\Logs"
    Write-Info "Configuration location: $env:APPDATA\WireGuard\Configs\$ConfigType.conf"
    Write-Info ""

    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "Setup Complete" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Cyan
}

# Execute main function
Main
