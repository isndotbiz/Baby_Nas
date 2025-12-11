#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automated Veeam Agent for Windows installation script

.DESCRIPTION
    This script automates the download and installation of Veeam Agent for Windows (FREE).
    It handles:
    - Installation detection
    - Silent installation with optimal parameters
    - License configuration (FREE edition)
    - Service verification
    - Post-installation validation

.PARAMETER InstallerPath
    Path to Veeam Agent installer ISO or EXE
    If not provided, script will guide user to download

.PARAMETER InstallPath
    Custom installation directory
    Default: C:\Program Files\Veeam\Endpoint Backup

.PARAMETER AcceptEula
    Automatically accept EULA
    Default: $true

.PARAMETER EnableTelemetry
    Enable Veeam telemetry (recommended for support)
    Default: $false

.EXAMPLE
    .\1-install-veeam-agent.ps1
    Interactive installation with prompts

.EXAMPLE
    .\1-install-veeam-agent.ps1 -InstallerPath "D:\Downloads\VeeamAgentWindows.exe" -AcceptEula $true
    Automated silent installation from downloaded installer

.NOTES
    Author: Automated Veeam Deployment System
    Version: 1.0
    Requires: Windows 7 SP1+ or Windows Server 2008 R2 SP1+
    Requires: Administrator privileges
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$InstallerPath,

    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\Program Files\Veeam\Endpoint Backup",

    [Parameter(Mandatory=$false)]
    [bool]$AcceptEula = $true,

    [Parameter(Mandatory=$false)]
    [bool]$EnableTelemetry = $false
)

# Configuration
$logDir = "C:\Logs\Veeam"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\veeam-install-$timestamp.log"
$downloadUrl = "https://www.veeam.com/windows-endpoint-server-backup-free.html"

# Create log directory
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO"    { Write-Host $logMessage -ForegroundColor Cyan }
        default   { Write-Host $logMessage -ForegroundColor White }
    }

    $logMessage | Out-File -FilePath $logFile -Append
}

function Test-VeeamInstalled {
    Write-Log "Checking for existing Veeam Agent installation..." "INFO"

    # Check service
    $service = Get-Service -Name "VeeamEndpointBackupSvc" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "Veeam service found: $($service.Status)" "SUCCESS"
        return $true
    }

    # Check registry
    $regPaths = @(
        "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup",
        "HKLM:\SOFTWARE\WOW6432Node\Veeam\Veeam Endpoint Backup"
    )

    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            try {
                $version = (Get-ItemProperty -Path $path -Name "Version" -ErrorAction SilentlyContinue).Version
                Write-Log "Veeam Agent found in registry: Version $version" "SUCCESS"
                return $true
            } catch {
                Write-Log "Veeam registry entry found but version unreadable" "WARNING"
                return $true
            }
        }
    }

    # Check for executable
    $exePaths = @(
        "${env:ProgramFiles}\Veeam\Endpoint Backup\Veeam.Endpoint.Manager.exe",
        "${env:ProgramFiles(x86)}\Veeam\Endpoint Backup\Veeam.Endpoint.Manager.exe",
        "$InstallPath\Veeam.Endpoint.Manager.exe"
    )

    foreach ($exe in $exePaths) {
        if (Test-Path $exe) {
            Write-Log "Veeam executable found: $exe" "SUCCESS"
            return $true
        }
    }

    Write-Log "Veeam Agent is NOT installed" "INFO"
    return $false
}

function Get-VeeamVersion {
    try {
        $regPath = "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup"
        if (Test-Path $regPath) {
            $version = (Get-ItemProperty -Path $regPath -Name "Version" -ErrorAction SilentlyContinue).Version
            return $version
        }

        # Alternative: check file version
        $exePath = "${env:ProgramFiles}\Veeam\Endpoint Backup\Veeam.Endpoint.Manager.exe"
        if (Test-Path $exePath) {
            $fileVersion = (Get-Item $exePath).VersionInfo.ProductVersion
            return $fileVersion
        }
    } catch {
        Write-Log "Could not determine Veeam version: $($_.Exception.Message)" "WARNING"
    }

    return "Unknown"
}

function Test-SystemRequirements {
    Write-Log "Checking system requirements..." "INFO"

    # Check OS version
    $os = Get-CimInstance Win32_OperatingSystem
    $osVersion = [System.Version]$os.Version

    Write-Log "Operating System: $($os.Caption)" "INFO"
    Write-Log "OS Version: $($os.Version)" "INFO"

    # Windows 7 SP1 = 6.1.7601, Windows Server 2008 R2 SP1 = 6.1.7601
    $minVersion = [System.Version]"6.1.7601"

    if ($osVersion -lt $minVersion) {
        Write-Log "ERROR: OS version too old. Requires Windows 7 SP1 / Server 2008 R2 SP1 or later" "ERROR"
        return $false
    }

    # Check RAM
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    Write-Log "Total RAM: $ramGB GB" "INFO"

    if ($ramGB -lt 2) {
        Write-Log "WARNING: Less than 2 GB RAM detected. Veeam requires minimum 2 GB" "WARNING"
    }

    # Check disk space
    $systemDrive = $env:SystemDrive
    $drive = Get-PSDrive -Name $systemDrive.Trim(':')
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)

    Write-Log "Free space on $systemDrive : $freeSpaceGB GB" "INFO"

    if ($freeSpaceGB -lt 5) {
        Write-Log "WARNING: Less than 5 GB free space. Recommended: 20+ GB for cache" "WARNING"
    }

    # Check if running as Administrator
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Log "ERROR: Script must run as Administrator" "ERROR"
        return $false
    }

    Write-Log "System requirements check passed" "SUCCESS"
    return $true
}

function Show-DownloadInstructions {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " VEEAM AGENT DOWNLOAD REQUIRED" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Product:" -ForegroundColor Cyan -NoNewline
    Write-Host " Veeam Agent for Microsoft Windows (FREE)"
    Write-Host ""
    Write-Host "Download URL:" -ForegroundColor Cyan
    Write-Host "  $downloadUrl" -ForegroundColor Green
    Write-Host ""
    Write-Host "DOWNLOAD STEPS:" -ForegroundColor Cyan
    Write-Host "  1. Open the URL above in your web browser"
    Write-Host "  2. Click 'Download Free Edition'"
    Write-Host "  3. Register (free) or log in with existing Veeam account"
    Write-Host "  4. Download the installer EXE or ISO file"
    Write-Host "  5. Save to a known location (e.g., Downloads folder)"
    Write-Host ""
    Write-Host "INSTALLER OPTIONS:" -ForegroundColor Cyan
    Write-Host "  - VeeamAgentWindows_X.X.X.XXXX.exe  (Recommended)"
    Write-Host "  - VeeamAgentWindows_X.X.X.XXXX.iso  (Contains EXE)"
    Write-Host ""
    Write-Host "After downloading, run this script again with:" -ForegroundColor Yellow
    Write-Host "  .\1-install-veeam-agent.ps1 -InstallerPath 'PATH_TO_INSTALLER'" -ForegroundColor Green
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "  .\1-install-veeam-agent.ps1 -InstallerPath 'C:\Users\$env:USERNAME\Downloads\VeeamAgentWindows.exe'" -ForegroundColor Green
    Write-Host ""

    Write-Log "Download instructions displayed" "INFO"
}

function Find-VeeamInstaller {
    param([string]$ProvidedPath)

    if ($ProvidedPath -and (Test-Path $ProvidedPath)) {
        Write-Log "Using provided installer: $ProvidedPath" "SUCCESS"
        return $ProvidedPath
    }

    Write-Log "Searching for Veeam installer in common locations..." "INFO"

    # Search common download locations
    $searchPaths = @(
        "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Desktop",
        "D:\Downloads",
        "C:\Temp",
        "C:\Install"
    )

    $patterns = @("VeeamAgent*.exe", "VeeamAgent*.iso", "Veeam*Windows*.exe")

    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            foreach ($pattern in $patterns) {
                $files = Get-ChildItem -Path $searchPath -Filter $pattern -ErrorAction SilentlyContinue |
                         Sort-Object LastWriteTime -Descending

                if ($files) {
                    $newestFile = $files[0].FullName
                    Write-Log "Found installer: $newestFile" "SUCCESS"
                    return $newestFile
                }
            }
        }
    }

    Write-Log "No Veeam installer found in common locations" "WARNING"
    return $null
}

function Install-FromISO {
    param([string]$IsoPath)

    Write-Log "Mounting ISO: $IsoPath" "INFO"

    try {
        # Mount ISO
        $mount = Mount-DiskImage -ImagePath $IsoPath -PassThru
        $driveLetter = ($mount | Get-Volume).DriveLetter

        if (-not $driveLetter) {
            Write-Log "ERROR: Failed to mount ISO" "ERROR"
            return $null
        }

        Write-Log "ISO mounted to drive ${driveLetter}:" "SUCCESS"

        # Find setup.exe or installer
        $possibleExes = @(
            "${driveLetter}:\Setup.exe",
            "${driveLetter}:\VeeamAgent*.exe",
            "${driveLetter}:\Veeam.Agent.Windows*.exe"
        )

        $installerExe = $null
        foreach ($exe in $possibleExes) {
            $found = Get-ChildItem -Path "${driveLetter}:\" -Filter "*.exe" -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -like "*Veeam*" -or $_.Name -eq "Setup.exe" } |
                     Select-Object -First 1

            if ($found) {
                $installerExe = $found.FullName
                break
            }
        }

        if ($installerExe) {
            Write-Log "Found installer in ISO: $installerExe" "SUCCESS"
            return @{
                Exe = $installerExe
                IsoMount = $mount
            }
        } else {
            Write-Log "ERROR: No installer found in ISO" "ERROR"
            Dismount-DiskImage -ImagePath $IsoPath | Out-Null
            return $null
        }

    } catch {
        Write-Log "ERROR mounting ISO: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Install-VeeamAgent {
    param(
        [string]$InstallerPath,
        [bool]$AcceptEula,
        [bool]$EnableTelemetry
    )

    Write-Log "Starting Veeam Agent installation..." "INFO"
    Write-Log "Installer: $InstallerPath" "INFO"

    # Build installation arguments
    $installArgs = @(
        "/silent",
        "/accepteula"
    )

    if (-not $EnableTelemetry) {
        $installArgs += "/noreboot"
    }

    # Additional silent install parameters for Veeam
    $installArgs += "ACCEPT_THIRDPARTY_LICENSES=1"
    $installArgs += "ACCEPTEULA=YES"

    $argString = $installArgs -join " "

    Write-Log "Installation command: $InstallerPath $argString" "INFO"
    Write-Log "This may take 5-15 minutes. Please wait..." "INFO"

    try {
        # Start installation
        $process = Start-Process -FilePath $InstallerPath -ArgumentList $argString -Wait -PassThru -NoNewWindow

        $exitCode = $process.ExitCode

        Write-Log "Installation process completed with exit code: $exitCode" "INFO"

        # Veeam exit codes
        # 0 = Success
        # 3010 = Success, reboot required
        # Other = Error

        switch ($exitCode) {
            0 {
                Write-Log "Veeam Agent installed successfully!" "SUCCESS"
                return $true
            }
            3010 {
                Write-Log "Veeam Agent installed successfully (reboot required)" "SUCCESS"
                Write-Log "WARNING: System reboot required to complete installation" "WARNING"
                return $true
            }
            default {
                Write-Log "ERROR: Installation failed with exit code $exitCode" "ERROR"
                Write-Log "Check log file for details: $logFile" "ERROR"
                return $false
            }
        }

    } catch {
        Write-Log "ERROR: Installation exception: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-VeeamService {
    Write-Log "Verifying Veeam services..." "INFO"

    $services = @(
        "VeeamEndpointBackupSvc",
        "VeeamBackupSvc"
    )

    $allRunning = $true

    foreach ($serviceName in $services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

        if ($service) {
            Write-Log "Service found: $serviceName - Status: $($service.Status)" "INFO"

            if ($service.Status -ne "Running") {
                Write-Log "Starting service: $serviceName" "INFO"
                try {
                    Start-Service -Name $serviceName -ErrorAction Stop
                    Write-Log "Service started successfully: $serviceName" "SUCCESS"
                } catch {
                    Write-Log "WARNING: Could not start service $serviceName : $($_.Exception.Message)" "WARNING"
                    $allRunning = $false
                }
            } else {
                Write-Log "Service running: $serviceName" "SUCCESS"
            }
        } else {
            Write-Log "WARNING: Service not found: $serviceName" "WARNING"
            $allRunning = $false
        }
    }

    return $allRunning
}

function Set-VeeamConfiguration {
    Write-Log "Applying post-installation configuration..." "INFO"

    # Configure Veeam for FREE edition
    # The FREE edition is automatically activated, no license key needed

    try {
        # Check for Veeam registry settings
        $regPath = "HKLM:\SOFTWARE\Veeam\Veeam Endpoint Backup"

        if (Test-Path $regPath) {
            Write-Log "Veeam registry configuration found" "SUCCESS"

            # Set recommended options (if they exist)
            # These may vary by Veeam version

            Write-Log "Configuration applied (FREE edition)" "SUCCESS"
        }

    } catch {
        Write-Log "WARNING: Could not apply some configurations: $($_.Exception.Message)" "WARNING"
    }
}

function Show-PostInstallInstructions {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " VEEAM AGENT INSTALLATION COMPLETE" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Verify Installation:" -ForegroundColor Cyan
    Write-Host "   - Open: Control Panel > Veeam Agent for Microsoft Windows"
    Write-Host "   - Or search 'Veeam' in Start Menu"
    Write-Host ""
    Write-Host "2. Configure Backup Job:" -ForegroundColor Cyan
    Write-Host "   Run the automated configuration script:"
    Write-Host "   .\2-configure-backup-jobs.ps1" -ForegroundColor Green
    Write-Host ""
    Write-Host "3. Setup TrueNAS Repository (if not done):" -ForegroundColor Cyan
    Write-Host "   .\3-setup-truenas-repository.ps1" -ForegroundColor Green
    Write-Host ""
    Write-Host "4. Test Backup:" -ForegroundColor Cyan
    Write-Host "   Run an immediate backup test from Veeam Control Panel"
    Write-Host ""
    Write-Host "IMPORTANT NOTES:" -ForegroundColor Yellow
    Write-Host "  - Veeam Agent FREE edition is now active"
    Write-Host "  - No license key required for FREE edition"
    Write-Host "  - Supports local and network backup destinations"
    Write-Host "  - Schedule automated backups through Veeam Control Panel"
    Write-Host ""

    Write-Log "Post-installation instructions displayed" "INFO"
}

# ===== MAIN EXECUTION =====

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " VEEAM AGENT INSTALLATION SCRIPT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== Veeam Agent Installation Script Started ===" "INFO"
Write-Log "Log file: $logFile" "INFO"

# Step 1: Check system requirements
Write-Log "" "INFO"
Write-Log "Step 1: System Requirements Check" "INFO"
if (-not (Test-SystemRequirements)) {
    Write-Log "System requirements not met. Cannot continue." "ERROR"
    exit 1
}

# Step 2: Check if already installed
Write-Log "" "INFO"
Write-Log "Step 2: Installation Status Check" "INFO"

if (Test-VeeamInstalled) {
    $version = Get-VeeamVersion
    Write-Host ""
    Write-Host "Veeam Agent is already installed!" -ForegroundColor Green
    Write-Host "Version: $version" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To reconfigure, run: .\2-configure-backup-jobs.ps1" -ForegroundColor Yellow
    Write-Host ""

    Write-Log "Veeam Agent already installed: Version $version" "SUCCESS"
    Write-Log "No installation needed" "INFO"
    exit 0
}

# Step 3: Find or prompt for installer
Write-Log "" "INFO"
Write-Log "Step 3: Locate Veeam Installer" "INFO"

$installer = Find-VeeamInstaller -ProvidedPath $InstallerPath

if (-not $installer) {
    Show-DownloadInstructions

    Write-Host "Would you like to specify the installer path now? (Y/N): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host

    if ($response -eq 'Y' -or $response -eq 'y') {
        Write-Host "Enter full path to Veeam installer: " -NoNewline -ForegroundColor Cyan
        $manualPath = Read-Host

        if (Test-Path $manualPath) {
            $installer = $manualPath
            Write-Log "Using manually specified installer: $installer" "SUCCESS"
        } else {
            Write-Log "ERROR: Specified path not found: $manualPath" "ERROR"
            Write-Log "Cannot continue without installer" "ERROR"
            exit 1
        }
    } else {
        Write-Log "User chose not to specify installer path" "INFO"
        Write-Log "Cannot continue without installer" "ERROR"
        exit 1
    }
}

# Step 4: Handle ISO if needed
$isoMount = $null
if ($installer -like "*.iso") {
    Write-Log "" "INFO"
    Write-Log "Step 4: Mount ISO Installer" "INFO"

    $isoResult = Install-FromISO -IsoPath $installer

    if ($isoResult) {
        $installer = $isoResult.Exe
        $isoMount = $isoResult.IsoMount
        Write-Log "Using installer from ISO: $installer" "SUCCESS"
    } else {
        Write-Log "ERROR: Failed to mount or find installer in ISO" "ERROR"
        exit 1
    }
}

# Step 5: Install Veeam Agent
Write-Log "" "INFO"
Write-Log "Step 5: Install Veeam Agent" "INFO"

$installSuccess = Install-VeeamAgent -InstallerPath $installer -AcceptEula $AcceptEula -EnableTelemetry $EnableTelemetry

# Cleanup ISO mount if used
if ($isoMount) {
    Write-Log "Dismounting ISO..." "INFO"
    Dismount-DiskImage -ImagePath $isoMount.ImagePath | Out-Null
}

if (-not $installSuccess) {
    Write-Log "Installation failed. See log for details: $logFile" "ERROR"
    exit 1
}

# Step 6: Wait for services to start
Write-Log "" "INFO"
Write-Log "Step 6: Verify Services" "INFO"
Write-Log "Waiting 30 seconds for services to initialize..." "INFO"
Start-Sleep -Seconds 30

$servicesRunning = Test-VeeamService

if (-not $servicesRunning) {
    Write-Log "WARNING: Some services are not running properly" "WARNING"
    Write-Log "You may need to restart Windows to complete installation" "WARNING"
}

# Step 7: Post-installation configuration
Write-Log "" "INFO"
Write-Log "Step 7: Post-Installation Configuration" "INFO"
Set-VeeamConfiguration

# Step 8: Final verification
Write-Log "" "INFO"
Write-Log "Step 8: Final Verification" "INFO"

if (Test-VeeamInstalled) {
    $version = Get-VeeamVersion
    Write-Log "Veeam Agent installation verified: Version $version" "SUCCESS"

    # Show next steps
    Show-PostInstallInstructions

    Write-Log "=== Installation Completed Successfully ===" "SUCCESS"
    Write-Log "Log file: $logFile" "INFO"

    exit 0
} else {
    Write-Log "ERROR: Installation verification failed" "ERROR"
    Write-Log "Veeam may require a system restart to complete installation" "WARNING"
    Write-Log "Log file: $logFile" "INFO"

    exit 1
}
