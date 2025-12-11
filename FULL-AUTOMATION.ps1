#Requires -RunAsAdministrator
###############################################################################
# FULL AUTOMATION - Complete Baby NAS Setup Orchestration
#
# This script automates the entire Baby NAS configuration pipeline:
#   1. SSH connectivity testing
#   2. Configuration script upload and execution
#   3. SSH key setup (Baby NAS + Main NAS)
#   4. DNS configuration (3 options)
#   5. Comprehensive testing
#   6. Replication setup to Main NAS
#   7. Complete logging and error handling
#
# Author: Automated Baby NAS Setup
# Version: 1.0
###############################################################################

param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$MainNasIP = "10.0.0.89",
    [string]$Username = "truenas_admin",
    [string]$Password = "uppercut%`$##",
    [string]$AdminUsername = "admin",
    [switch]$UnattendedMode,
    [switch]$SkipReplication,
    [switch]$SkipTests
)

$ErrorActionPreference = "Continue"  # Continue on errors to allow retries

###############################################################################
# CONFIGURATION
###############################################################################
$SCRIPT_VERSION = "1.0"
$START_TIME = Get-Date
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$LOG_DIR = "D:\workspace\True_Nas\logs"
$LOG_FILE = "$LOG_DIR\full-automation-$TIMESTAMP.log"
$WORKSPACE_DIR = "D:\workspace\True_Nas"
$SCRIPTS_DIR = "$WORKSPACE_DIR\windows-scripts"
$TRUENAS_SCRIPTS_DIR = "$WORKSPACE_DIR\truenas-scripts"

# DNS Options
$DNS_OPTIONS = @{
    "1" = @{
        Name = "Cloudflare (1.1.1.1, 1.0.0.1)"
        Primary = "1.1.1.1"
        Secondary = "1.0.0.1"
    }
    "2" = @{
        Name = "Google (8.8.8.8, 8.8.4.4)"
        Primary = "8.8.8.8"
        Secondary = "8.8.4.4"
    }
    "3" = @{
        Name = "Quad9 (9.9.9.9, 149.112.112.112)"
        Primary = "9.9.9.9"
        Secondary = "149.112.112.112"
    }
}

# Colors and formatting
$ColorScheme = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Progress = "Magenta"
    Title = "White"
}

###############################################################################
# LOGGING FUNCTIONS
###############################################################################
function Initialize-Logging {
    if (-not (Test-Path $LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    }

    $header = @"
================================================================================
FULL AUTOMATION LOG
================================================================================
Script Version: $SCRIPT_VERSION
Start Time: $START_TIME
Baby NAS IP: $BabyNasIP
Main NAS IP: $MainNasIP
Username: $Username
Unattended Mode: $UnattendedMode
Skip Replication: $SkipReplication
Skip Tests: $SkipTests
================================================================================

"@
    Add-Content -Path $LOG_FILE -Value $header
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "PROGRESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    Add-Content -Path $LOG_FILE -Value $logMessage

    # Write to console with color
    $color = switch ($Level) {
        "SUCCESS" { $ColorScheme.Success }
        "ERROR" { $ColorScheme.Error }
        "WARNING" { $ColorScheme.Warning }
        "PROGRESS" { $ColorScheme.Progress }
        default { $ColorScheme.Info }
    }

    $symbol = switch ($Level) {
        "SUCCESS" { "✓" }
        "ERROR" { "✗" }
        "WARNING" { "⚠" }
        "PROGRESS" { "►" }
        default { "•" }
    }

    Write-Host "  $symbol $Message" -ForegroundColor $color
}

function Write-StepHeader {
    param([string]$StepNumber, [string]$Title)

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor $ColorScheme.Title
    Write-Host "  STEP ${StepNumber}: $Title" -ForegroundColor $ColorScheme.Title
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor $ColorScheme.Title
    Write-Host ""

    Write-Log -Message "STEP ${StepNumber}: $Title" -Level "PROGRESS"
}

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                                   ║" -ForegroundColor Cyan
    Write-Host "║           BABY NAS FULL AUTOMATION ORCHESTRATION                  ║" -ForegroundColor Cyan
    Write-Host "║                                                                   ║" -ForegroundColor Cyan
    Write-Host "║           Complete Setup from Start to Finish                     ║" -ForegroundColor Cyan
    Write-Host "║                                                                   ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Version: $SCRIPT_VERSION" -ForegroundColor Gray
    Write-Host "  Log File: $LOG_FILE" -ForegroundColor Gray
    Write-Host ""
}

###############################################################################
# RETRY LOGIC
###############################################################################
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$OperationName,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 5
    )

    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            Write-Log -Message "$OperationName (Attempt $attempt/$MaxRetries)" -Level "INFO"
            & $ScriptBlock
            Write-Log -Message "$OperationName succeeded" -Level "SUCCESS"
            return $true
        } catch {
            if ($attempt -eq $MaxRetries) {
                Write-Log -Message "$OperationName failed after $MaxRetries attempts: $($_.Exception.Message)" -Level "ERROR"
                return $false
            }
            Write-Log -Message "$OperationName failed (attempt $attempt): $($_.Exception.Message). Retrying in $DelaySeconds seconds..." -Level "WARNING"
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

###############################################################################
# CONNECTIVITY TESTS
###############################################################################
function Test-BabyNasConnectivity {
    Write-StepHeader "1" "Testing Connectivity to Baby NAS"

    # Ping test
    Write-Log -Message "Testing network connectivity (ping)..." -Level "INFO"
    if (Test-Connection -ComputerName $BabyNasIP -Count 3 -Quiet) {
        Write-Log -Message "Baby NAS is reachable at $BabyNasIP" -Level "SUCCESS"
    } else {
        Write-Log -Message "Cannot reach Baby NAS at $BabyNasIP" -Level "ERROR"
        throw "Baby NAS connectivity test failed"
    }

    # SSH port test
    Write-Log -Message "Testing SSH port 22..." -Level "INFO"
    $tcpTest = Test-NetConnection -ComputerName $BabyNasIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($tcpTest) {
        Write-Log -Message "SSH service is accessible on port 22" -Level "SUCCESS"
    } else {
        Write-Log -Message "SSH service not accessible. Please enable SSH in TrueNAS Web UI" -Level "ERROR"
        Write-Host ""
        Write-Host "  To enable SSH:" -ForegroundColor Yellow
        Write-Host "    1. Open https://$BabyNasIP" -ForegroundColor White
        Write-Host "    2. Go to System Settings → Services" -ForegroundColor White
        Write-Host "    3. Find SSH service and click Start" -ForegroundColor White
        Write-Host ""
        throw "SSH service not accessible"
    }

    # Test SSH authentication
    Write-Log -Message "Testing SSH authentication..." -Level "INFO"
    $sshTest = echo "y" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 "${AdminUsername}@${BabyNasIP}" "echo 'SSH OK'" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "SSH authentication successful" -Level "SUCCESS"
    } else {
        Write-Log -Message "SSH authentication failed. Check credentials." -Level "ERROR"
        throw "SSH authentication failed"
    }
}

###############################################################################
# UPLOAD AND EXECUTE CONFIGURATION
###############################################################################
function Invoke-BabyNasConfiguration {
    Write-StepHeader "2" "Uploading and Executing Configuration Script"

    $localScript = "$TRUENAS_SCRIPTS_DIR\configure-baby-nas-complete.sh"
    $remoteScript = "/root/configure-baby-nas.sh"

    # Verify local script exists
    if (-not (Test-Path $localScript)) {
        Write-Log -Message "Configuration script not found: $localScript" -Level "ERROR"
        throw "Configuration script missing"
    }
    Write-Log -Message "Found configuration script: $localScript" -Level "SUCCESS"

    # Upload script
    Write-Log -Message "Uploading configuration script to Baby NAS..." -Level "INFO"
    $uploadResult = Invoke-WithRetry -OperationName "Upload configuration script" -ScriptBlock {
        echo "y" | scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$localScript" "${AdminUsername}@${BabyNasIP}:${remoteScript}" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "SCP upload failed" }
    }

    if (-not $uploadResult) {
        throw "Failed to upload configuration script"
    }

    # Make executable
    Write-Log -Message "Making script executable..." -Level "INFO"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${AdminUsername}@${BabyNasIP}" "chmod +x $remoteScript" 2>&1 | Out-Null

    # Execute script
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "  ║  The configuration script will now run on Baby NAS.           ║" -ForegroundColor Yellow
    Write-Host "  ║  You may be prompted for disk selections.                     ║" -ForegroundColor Yellow
    Write-Host "  ║  Follow the on-screen prompts.                                ║" -ForegroundColor Yellow
    Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""

    if (-not $UnattendedMode) {
        $confirm = Read-Host "  Ready to execute configuration script? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Log -Message "Configuration execution cancelled by user" -Level "WARNING"
            throw "User cancelled configuration"
        }
    }

    Write-Log -Message "Executing configuration script on Baby NAS..." -Level "INFO"
    Write-Host ""
    Write-Host "  ═══ Baby NAS Configuration Output ═══" -ForegroundColor Cyan
    Write-Host ""

    # Run interactively
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t "${AdminUsername}@${BabyNasIP}" "bash $remoteScript"

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Log -Message "Configuration script completed successfully" -Level "SUCCESS"
    } else {
        Write-Host ""
        Write-Log -Message "Configuration script exited with code: $LASTEXITCODE" -Level "WARNING"

        if (-not $UnattendedMode) {
            $continue = Read-Host "  Continue with remaining steps? (yes/no)"
            if ($continue -ne "yes") {
                throw "Configuration script failed, user chose to abort"
            }
        }
    }
}

###############################################################################
# SSH KEY SETUP
###############################################################################
function Initialize-SSHKeys {
    Write-StepHeader "3" "Setting Up SSH Keys"

    $sshDir = "$env:USERPROFILE\.ssh"
    $babyNasKeyPath = "$sshDir\id_babynas"
    $mainNasKeyPath = "$sshDir\id_mainnas"

    # Create .ssh directory
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        Write-Log -Message "Created SSH directory: $sshDir" -Level "SUCCESS"
    }

    # Set proper permissions
    $acl = Get-Acl $sshDir
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
    )
    $acl.AddAccessRule($rule)
    Set-Acl -Path $sshDir -AclObject $acl

    # Generate Baby NAS key
    if (-not (Test-Path $babyNasKeyPath)) {
        Write-Log -Message "Generating SSH key for Baby NAS..." -Level "INFO"
        ssh-keygen -t ed25519 -f $babyNasKeyPath -N '""' -C "windows@baby-nas" -q
        Write-Log -Message "Baby NAS SSH key generated" -Level "SUCCESS"
    } else {
        Write-Log -Message "Baby NAS SSH key already exists" -Level "INFO"
    }

    # Generate Main NAS key
    if (-not (Test-Path $mainNasKeyPath)) {
        Write-Log -Message "Generating SSH key for Main NAS..." -Level "INFO"
        ssh-keygen -t ed25519 -f $mainNasKeyPath -N '""' -C "windows@main-nas" -q
        Write-Log -Message "Main NAS SSH key generated" -Level "SUCCESS"
    } else {
        Write-Log -Message "Main NAS SSH key already exists" -Level "INFO"
    }

    # Deploy key to Baby NAS
    Write-Log -Message "Deploying key to Baby NAS..." -Level "INFO"
    $babyPubKey = Get-Content "${babyNasKeyPath}.pub"

    $sshCommand = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '$babyPubKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo 'Key added successfully'
"@

    $result = echo "y" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${BabyNasIP}" "$sshCommand" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "SSH key deployed to Baby NAS" -Level "SUCCESS"
    } else {
        Write-Log -Message "Failed to deploy SSH key to Baby NAS: $result" -Level "WARNING"
    }

    # Deploy key to Main NAS (if reachable)
    if (-not $SkipReplication) {
        if (Test-Connection -ComputerName $MainNasIP -Count 2 -Quiet) {
            Write-Log -Message "Deploying key to Main NAS..." -Level "INFO"
            $mainPubKey = Get-Content "${mainNasKeyPath}.pub"

            $sshCommand = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '$mainPubKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo 'Key added successfully'
"@

            $result = echo "y" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@${MainNasIP}" "$sshCommand" 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "SSH key deployed to Main NAS" -Level "SUCCESS"
            } else {
                Write-Log -Message "Failed to deploy SSH key to Main NAS (will skip replication)" -Level "WARNING"
            }
        } else {
            Write-Log -Message "Main NAS not reachable at $MainNasIP (skipping key deployment)" -Level "WARNING"
        }
    }

    # Create SSH config
    Write-Log -Message "Creating SSH config file..." -Level "INFO"
    $sshConfigPath = "$sshDir\config"

    $configContent = @"

# Baby NAS (Local Hyper-V VM)
Host babynas baby baby.isn.biz
    HostName $BabyNasIP
    User $Username
    IdentityFile $babyNasKeyPath
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Main NAS (Remote Server)
Host mainnas main true.isn.biz
    HostName $MainNasIP
    User root
    IdentityFile $mainNasKeyPath
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
"@

    if (Test-Path $sshConfigPath) {
        Add-Content -Path $sshConfigPath -Value $configContent
    } else {
        Set-Content -Path $sshConfigPath -Value $configContent.TrimStart()
    }

    Write-Log -Message "SSH config file updated" -Level "SUCCESS"

    # Test connections
    Write-Log -Message "Testing SSH connection to Baby NAS..." -Level "INFO"
    $testResult = ssh babynas "hostname" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "SSH connection to Baby NAS successful: $testResult" -Level "SUCCESS"
    } else {
        Write-Log -Message "SSH connection to Baby NAS failed" -Level "WARNING"
    }
}

###############################################################################
# DNS CONFIGURATION
###############################################################################
function Set-DNSConfiguration {
    Write-StepHeader "4" "Configuring DNS Servers"

    if ($UnattendedMode) {
        $dnsChoice = "1"  # Default to Cloudflare in unattended mode
        Write-Log -Message "Unattended mode: Using Cloudflare DNS" -Level "INFO"
    } else {
        Write-Host "  Select DNS servers:" -ForegroundColor Cyan
        Write-Host ""
        foreach ($key in $DNS_OPTIONS.Keys | Sort-Object) {
            Write-Host "    [$key] $($DNS_OPTIONS[$key].Name)" -ForegroundColor White
        }
        Write-Host ""

        do {
            $dnsChoice = Read-Host "  Enter choice (1-3)"
        } while (-not $DNS_OPTIONS.ContainsKey($dnsChoice))
    }

    $selectedDNS = $DNS_OPTIONS[$dnsChoice]
    Write-Log -Message "Selected DNS: $($selectedDNS.Name)" -Level "INFO"

    # Configure DNS on Baby NAS
    $dnsScript = @"
# Configure DNS servers
echo 'nameserver $($selectedDNS.Primary)' > /etc/resolv.conf
echo 'nameserver $($selectedDNS.Secondary)' >> /etc/resolv.conf

# Make it persistent (for Debian-based systems)
if [ -f /etc/network/interfaces ]; then
    if ! grep -q 'dns-nameservers' /etc/network/interfaces; then
        echo '    dns-nameservers $($selectedDNS.Primary) $($selectedDNS.Secondary)' >> /etc/network/interfaces
    fi
fi

# Test DNS resolution
if nslookup google.com > /dev/null 2>&1; then
    echo 'DNS resolution working'
else
    echo 'DNS resolution test failed'
    exit 1
fi
"@

    Write-Log -Message "Configuring DNS on Baby NAS..." -Level "INFO"
    $result = $dnsScript | ssh babynas "bash" 2>&1

    if ($LASTEXITCODE -eq 0 -and $result -match "DNS resolution working") {
        Write-Log -Message "DNS configured successfully on Baby NAS" -Level "SUCCESS"
        Write-Log -Message "Primary DNS: $($selectedDNS.Primary)" -Level "INFO"
        Write-Log -Message "Secondary DNS: $($selectedDNS.Secondary)" -Level "INFO"
    } else {
        Write-Log -Message "DNS configuration may have issues: $result" -Level "WARNING"
    }
}

###############################################################################
# COMPREHENSIVE TESTING
###############################################################################
function Invoke-ComprehensiveTesting {
    Write-StepHeader "5" "Running Comprehensive Tests"

    if ($SkipTests) {
        Write-Log -Message "Skipping tests (--SkipTests flag set)" -Level "WARNING"
        return
    }

    $testScript = "$SCRIPTS_DIR\test-baby-nas-complete.ps1"

    if (-not (Test-Path $testScript)) {
        Write-Log -Message "Test script not found: $testScript" -Level "WARNING"
        return
    }

    Write-Log -Message "Executing comprehensive test suite..." -Level "INFO"
    Write-Host ""

    & $testScript -BabyNasIP $BabyNasIP -Username $Username -Password $Password

    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "Comprehensive testing completed" -Level "SUCCESS"
    } else {
        Write-Log -Message "Some tests failed (review output above)" -Level "WARNING"
    }
}

###############################################################################
# REPLICATION SETUP
###############################################################################
function Initialize-ReplicationToMainNAS {
    Write-StepHeader "6" "Setting Up Replication to Main NAS"

    if ($SkipReplication) {
        Write-Log -Message "Skipping replication setup (--SkipReplication flag set)" -Level "WARNING"
        return
    }

    # Test Main NAS connectivity
    if (-not (Test-Connection -ComputerName $MainNasIP -Count 2 -Quiet)) {
        Write-Log -Message "Main NAS not reachable at $MainNasIP. Skipping replication setup." -Level "WARNING"
        Write-Log -Message "You can run replication setup later: .\3-setup-replication.ps1" -Level "INFO"
        return
    }

    Write-Log -Message "Main NAS is reachable" -Level "SUCCESS"

    $replicationScript = "$SCRIPTS_DIR\3-setup-replication.ps1"

    if (-not (Test-Path $replicationScript)) {
        Write-Log -Message "Replication script not found: $replicationScript" -Level "WARNING"
        return
    }

    if ($UnattendedMode) {
        Write-Log -Message "Skipping replication setup in unattended mode (requires interaction)" -Level "WARNING"
        Write-Log -Message "Run manually: .\3-setup-replication.ps1 -BabyNasIP $BabyNasIP" -Level "INFO"
        return
    }

    Write-Host ""
    $confirm = Read-Host "  Setup replication to Main NAS now? (yes/no)"

    if ($confirm -eq "yes") {
        Write-Log -Message "Starting replication setup..." -Level "INFO"
        Write-Host ""

        & $replicationScript -BabyNasIP $BabyNasIP -MainNasIP $MainNasIP

        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message "Replication setup completed" -Level "SUCCESS"
        } else {
            Write-Log -Message "Replication setup encountered issues" -Level "WARNING"
        }
    } else {
        Write-Log -Message "Replication setup skipped by user" -Level "INFO"
        Write-Log -Message "Run manually: .\3-setup-replication.ps1 -BabyNasIP $BabyNasIP" -Level "INFO"
    }
}

###############################################################################
# VM OPTIMIZATION
###############################################################################
function Optimize-VMConfiguration {
    Write-StepHeader "7" "Optimizing VM Configuration"

    $VMName = "TrueNAS-BabyNAS"
    $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

    if (-not $vm) {
        Write-Log -Message "VM $VMName not found (skipping optimization)" -Level "WARNING"
        return
    }

    $currentRAM = $vm.MemoryStartup / 1GB
    Write-Log -Message "Current VM RAM: ${currentRAM}GB" -Level "INFO"

    if ($currentRAM -gt 8) {
        Write-Log -Message "Reducing VM memory to 8GB for optimal backup workload..." -Level "INFO"

        # Stop VM
        Write-Log -Message "Stopping VM..." -Level "INFO"
        Stop-VM -Name $VMName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5

        # Change memory
        Set-VMMemory -VMName $VMName -StartupBytes 8GB -MinimumBytes 4GB -MaximumBytes 8GB
        Write-Log -Message "VM memory set to 8GB" -Level "SUCCESS"

        # Restart VM
        Write-Log -Message "Restarting VM..." -Level "INFO"
        Start-VM -Name $VMName
        Start-Sleep -Seconds 15

        # Wait for SSH
        $retries = 0
        $maxRetries = 20
        while ($retries -lt $maxRetries) {
            if (Test-NetConnection -ComputerName $BabyNasIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet) {
                Write-Log -Message "VM restarted and online" -Level "SUCCESS"
                break
            }
            Start-Sleep -Seconds 3
            $retries++
        }

        if ($retries -eq $maxRetries) {
            Write-Log -Message "VM took longer than expected to come online" -Level "WARNING"
        }
    } else {
        Write-Log -Message "VM already at optimal memory configuration (8GB)" -Level "SUCCESS"
    }
}

###############################################################################
# FINAL SUMMARY
###############################################################################
function Show-CompletionSummary {
    $END_TIME = Get-Date
    $DURATION = $END_TIME - $START_TIME

    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                                   ║" -ForegroundColor Green
    Write-Host "║           BABY NAS AUTOMATION COMPLETE!                           ║" -ForegroundColor Green
    Write-Host "║                                                                   ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    Write-Host "  Execution Summary:" -ForegroundColor Cyan
    Write-Host "    Start Time: $START_TIME" -ForegroundColor White
    Write-Host "    End Time:   $END_TIME" -ForegroundColor White
    Write-Host "    Duration:   $($DURATION.Hours)h $($DURATION.Minutes)m $($DURATION.Seconds)s" -ForegroundColor White
    Write-Host ""

    Write-Host "  Baby NAS Configuration:" -ForegroundColor Cyan
    Write-Host "    IP Address:  $BabyNasIP" -ForegroundColor White
    Write-Host "    Username:    $Username" -ForegroundColor White
    Write-Host "    Pool:        tank (RAIDZ1 + SLOG + L2ARC)" -ForegroundColor White
    Write-Host "    Capacity:    ~12TB usable" -ForegroundColor White
    Write-Host "    Encryption:  AES-256-GCM" -ForegroundColor White
    Write-Host "    RAM:         8GB (4GB ARC)" -ForegroundColor White
    Write-Host ""

    Write-Host "  Access Information:" -ForegroundColor Cyan
    Write-Host "    SSH:         ssh babynas" -ForegroundColor White
    Write-Host "    Web UI:      https://$BabyNasIP" -ForegroundColor White
    Write-Host "    SMB Share:   \\$BabyNasIP\WindowsBackup" -ForegroundColor White
    Write-Host ""

    Write-Host "  Quick Commands:" -ForegroundColor Yellow
    Write-Host "    Test SMB:    net use W: \\$BabyNasIP\WindowsBackup /user:$Username `"$Password`"" -ForegroundColor White
    Write-Host "    Pool Status: ssh babynas 'zpool status tank'" -ForegroundColor White
    Write-Host "    Datasets:    ssh babynas 'zfs list -r tank'" -ForegroundColor White
    Write-Host ""

    Write-Host "  Next Steps:" -ForegroundColor Yellow
    Write-Host "    1. Verify SMB shares are accessible from Windows" -ForegroundColor White
    Write-Host "    2. Set up Veeam backup jobs: .\veeam\0-DEPLOY-VEEAM-COMPLETE.ps1" -ForegroundColor White
    Write-Host "    3. Configure development environment" -ForegroundColor White
    Write-Host "    4. Schedule regular backups" -ForegroundColor White
    Write-Host ""

    Write-Host "  Log File:" -ForegroundColor Cyan
    Write-Host "    $LOG_FILE" -ForegroundColor White
    Write-Host ""

    Write-Log -Message "Automation completed successfully" -Level "SUCCESS"
    Write-Log -Message "Total duration: $($DURATION.Hours)h $($DURATION.Minutes)m $($DURATION.Seconds)s" -Level "INFO"
}

###############################################################################
# MAIN EXECUTION
###############################################################################
try {
    Write-Banner
    Initialize-Logging

    Write-Log -Message "Starting Baby NAS Full Automation" -Level "PROGRESS"
    Write-Log -Message "Script Version: $SCRIPT_VERSION" -Level "INFO"

    # Pre-flight checks
    if (-not (Test-Path $WORKSPACE_DIR)) {
        Write-Log -Message "Workspace directory not found: $WORKSPACE_DIR" -Level "ERROR"
        exit 1
    }

    # Execute orchestration steps
    Test-BabyNasConnectivity
    Invoke-BabyNasConfiguration
    Initialize-SSHKeys
    Set-DNSConfiguration
    Invoke-ComprehensiveTesting
    Initialize-ReplicationToMainNAS
    Optimize-VMConfiguration

    # Show completion summary
    Show-CompletionSummary

    exit 0

} catch {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                                                                   ║" -ForegroundColor Red
    Write-Host "║           AUTOMATION FAILED                                       ║" -ForegroundColor Red
    Write-Host "║                                                                   ║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Log -Message "Automation failed: $($_.Exception.Message)" -Level "ERROR"
    Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"

    Write-Host "  Check log file for details: $LOG_FILE" -ForegroundColor Yellow
    Write-Host ""

    exit 1
}
