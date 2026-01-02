# Comprehensive BabyNAS Diagnostics and Troubleshooting
# Tests all connectivity, VM status, and provides detailed troubleshooting

param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$BabyNasHostname = "babynas.isndotbiz.com",
    [string]$MainNasIP = "10.0.0.89",
    [switch]$Fix = $false,
    [switch]$Verbose = $false
)

# Color scheme
$Colors = @{
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Info = "Cyan"
    Secondary = "Gray"
}

function Write-Status {
    param([string]$Message, [string]$Status, [string]$Color = "Gray")
    $statusSymbol = switch($Status) {
        "OK" { "✓" }
        "WARN" { "⚠" }
        "ERROR" { "✗" }
        "INFO" { "ℹ" }
        default { "→" }
    }
    Write-Host "  $statusSymbol $Message" -ForegroundColor $Color
}

function Test-VMStatus {
    Write-Host ""
    Write-Host "=== HYPER-V VM STATUS ===" -ForegroundColor $Colors.Info

    try {
        $vm = Get-VM | Where-Object {$_.Name -like '*baby*' -or $_.Name -like '*truenas*'} | Select-Object -First 1

        if ($vm) {
            Write-Status "VM Found: $($vm.Name)" "OK" $Colors.Success
            Write-Status "State: $($vm.State)" "INFO" $Colors.Info
            Write-Status "Memory: $([int]($vm.MemoryAssigned/1MB)) MB" "INFO" $Colors.Info
            Write-Status "Processors: $($vm.ProcessorCount)" "INFO" $Colors.Info

            if ($vm.State -ne "Running") {
                Write-Status "VM is not running!" "ERROR" $Colors.Error
                if ($Fix) {
                    Write-Host ""
                    Write-Host "Attempting to start VM..." -ForegroundColor $Colors.Warning
                    Start-VM -VM $vm -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                    Write-Status "VM started" "OK" $Colors.Success
                }
            }
        } else {
            Write-Status "No BabyNAS VM found" "ERROR" $Colors.Error
            Write-Host "    Available VMs:" -ForegroundColor $Colors.Secondary
            Get-VM | Select-Object Name, State | ForEach-Object { Write-Host "      - $($_.Name) ($($_.State))" }
        }
    } catch {
        Write-Status "Error checking VM: $($_.Exception.Message)" "ERROR" $Colors.Error
    }
}

function Test-Connectivity {
    Write-Host ""
    Write-Host "=== NETWORK CONNECTIVITY ===" -ForegroundColor $Colors.Info

    # Ping test
    Write-Host ""
    Write-Host "Ping Test ($BabyNasIP):" -ForegroundColor $Colors.Secondary
    try {
        $ping = Test-Connection -ComputerName $BabyNasIP -Count 2 -ErrorAction Stop
        if ($ping) {
            Write-Status "Ping successful" "OK" $Colors.Success
            Write-Host "    Average response: $([int]($ping.ResponseTime | Measure-Object -Average).Average)ms" -ForegroundColor $Colors.Secondary
        }
    } catch {
        Write-Status "Ping failed" "ERROR" $Colors.Error
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor $Colors.Secondary
    }

    # Port tests
    Write-Host ""
    Write-Host "Port Connectivity Tests:" -ForegroundColor $Colors.Secondary

    $ports = @(
        @{Port = 22; Service = "SSH"; Critical = $true}
        @{Port = 443; Service = "HTTPS (Web UI)"; Critical = $true}
        @{Port = 445; Service = "SMB/CIFS"; Critical = $false}
        @{Port = 80; Service = "HTTP"; Critical = $false}
    )

    foreach ($portTest in $ports) {
        $result = Test-NetConnection -ComputerName $BabyNasIP -Port $portTest.Port `
            -WarningAction SilentlyContinue -InformationLevel Quiet -ErrorAction SilentlyContinue

        if ($result -or ($? -and $LASTEXITCODE -eq 0)) {
            Write-Status "Port $($portTest.Port) ($($portTest.Service)) - OPEN" "OK" $Colors.Success
        } else {
            $color = if ($portTest.Critical) { $Colors.Error } else { $Colors.Warning }
            $status = if ($portTest.Critical) { "ERROR" } else { "WARN" }
            Write-Status "Port $($portTest.Port) ($($portTest.Service)) - CLOSED" $status $color
        }
    }
}

function Test-SSHAccess {
    Write-Host ""
    Write-Host "=== SSH ACCESS ===" -ForegroundColor $Colors.Info

    $sshKey = "$env:USERPROFILE\.ssh\id_ed25519"
    $sshKey2 = "$env:USERPROFILE\.ssh\id_babynas"

    # Check if SSH key exists
    Write-Host ""
    Write-Host "SSH Key Check:" -ForegroundColor $Colors.Secondary
    if (Test-Path $sshKey) {
        Write-Status "SSH key found: id_ed25519" "OK" $Colors.Success
    } elseif (Test-Path $sshKey2) {
        Write-Status "SSH key found: id_babynas" "OK" $Colors.Success
        $sshKey = $sshKey2
    } else {
        Write-Status "SSH key not found" "WARN" $Colors.Warning
        Write-Host "    Expected at: $sshKey" -ForegroundColor $Colors.Secondary
    }

    # Test SSH connection
    Write-Host ""
    Write-Host "SSH Connection Test:" -ForegroundColor $Colors.Secondary
    try {
        $sshTest = & ssh -i $sshKey -o StrictHostKeyChecking=no -o ConnectTimeout=5 `
            -o UserKnownHostsFile=/dev/null root@$BabyNasIP "echo 'SSH connection successful'" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Status "SSH connection successful" "OK" $Colors.Success
        } else {
            Write-Status "SSH connection failed" "ERROR" $Colors.Error
            Write-Host "    Error: $sshTest" -ForegroundColor $Colors.Secondary
        }
    } catch {
        Write-Status "SSH test error: $($_.Exception.Message)" "ERROR" $Colors.Error
    }
}

function Test-WebUI {
    Write-Host ""
    Write-Host "=== WEB UI (HTTPS) ===" -ForegroundColor $Colors.Info

    $url = "https://$BabyNasIP"

    Write-Host ""
    Write-Host "Web UI Access Test:" -ForegroundColor $Colors.Secondary

    try {
        # Ignore SSL certificate warnings for self-signed certs
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            Write-Status "Web UI accessible (HTTP $($response.StatusCode))" "OK" $Colors.Success
            Write-Host "    URL: $url" -ForegroundColor $Colors.Secondary
            Write-Host "    Open in browser to login" -ForegroundColor $Colors.Secondary
        }
    } catch {
        Write-Status "Web UI not accessible" "ERROR" $Colors.Error
        Write-Host "    URL: $url" -ForegroundColor $Colors.Secondary
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor $Colors.Secondary
    }
}

function Test-DNS {
    Write-Host ""
    Write-Host "=== DNS RESOLUTION ===" -ForegroundColor $Colors.Info

    Write-Host ""
    Write-Host "Hostname Resolution:" -ForegroundColor $Colors.Secondary

    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($BabyNasHostname) | Select-Object -First 1
        Write-Status "Resolved $BabyNasHostname to $resolved" "OK" $Colors.Success

        if ($resolved.IPAddressToString -eq $BabyNasIP) {
            Write-Status "DNS resolves to correct IP" "OK" $Colors.Success
        } else {
            Write-Status "DNS resolves to $($resolved.IPAddressToString), expected $BabyNasIP" "WARN" $Colors.Warning
        }
    } catch {
        Write-Status "DNS resolution failed for $BabyNasHostname" "WARN" $Colors.Warning
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor $Colors.Secondary
        Write-Host "    Using IP address instead" -ForegroundColor $Colors.Secondary
    }
}

function Test-FileSharing {
    Write-Host ""
    Write-Host "=== FILE SHARING (SMB) ===" -ForegroundColor $Colors.Info

    Write-Host ""
    Write-Host "SMB Share Test:" -ForegroundColor $Colors.Secondary

    try {
        $uncPath = "\\$BabyNasIP\backups"
        $shares = Get-SMBShare -Name "backups" -ErrorAction SilentlyContinue

        if ($shares) {
            Write-Status "SMB share 'backups' exists on this system" "OK" $Colors.Success
        } else {
            Write-Status "Cannot verify remote SMB shares without credentials" "WARN" $Colors.Warning
            Write-Host "    To test: net use \\$BabyNasIP\backups /user:root password" -ForegroundColor $Colors.Secondary
        }
    } catch {
        Write-Status "SMB test error" "WARN" $Colors.Warning
    }
}

function Show-Troubleshooting {
    Write-Host ""
    Write-Host "=== TROUBLESHOOTING GUIDE ===" -ForegroundColor $Colors.Info

    Write-Host ""
    Write-Host "Common Issues and Solutions:" -ForegroundColor $Colors.Secondary

    Write-Host ""
    Write-Host "1. VM Not Running:" -ForegroundColor $Colors.Warning
    Write-Host "   • Automatic fix: Re-run with -Fix flag" -ForegroundColor $Colors.Secondary
    Write-Host "   • Manual: Start-VM -Name 'Baby-NAS'" -ForegroundColor $Colors.Secondary

    Write-Host ""
    Write-Host "2. Cannot Ping 172.21.203.18:" -ForegroundColor $Colors.Warning
    Write-Host "   • Check VM is running and has network" -ForegroundColor $Colors.Secondary
    Write-Host "   • Check Hyper-V switch is configured" -ForegroundColor $Colors.Secondary
    Write-Host "   • Check Windows Firewall isn't blocking ICMP" -ForegroundColor $Colors.Secondary

    Write-Host ""
    Write-Host "3. SSH Connection Failed:" -ForegroundColor $Colors.Warning
    Write-Host "   • Check SSH key exists: Test-Path \$env:USERPROFILE\.ssh\id_ed25519" -ForegroundColor $Colors.Secondary
    Write-Host "   • Add SSH key to authorized_keys on TrueNAS" -ForegroundColor $Colors.Secondary
    Write-Host "   • Try manual: ssh -i ~/.ssh/id_ed25519 root@172.21.203.18" -ForegroundColor $Colors.Secondary

    Write-Host ""
    Write-Host "4. Web UI Not Accessible:" -ForegroundColor $Colors.Warning
    Write-Host "   • Check port 443 is open" -ForegroundColor $Colors.Secondary
    Write-Host "   • Check TrueNAS is fully booted" -ForegroundColor $Colors.Secondary
    Write-Host "   • Wait 30+ seconds after VM starts" -ForegroundColor $Colors.Secondary
    Write-Host "   • Accept self-signed certificate warning in browser" -ForegroundColor $Colors.Secondary
}

function Show-Summary {
    Write-Host ""
    Write-Host "=== SUMMARY ===" -ForegroundColor $Colors.Info

    # Quick status check
    $issues = @()

    try {
        $vm = Get-VM | Where-Object {$_.Name -like '*baby*'} | Select-Object -First 1
        if ($vm.State -ne "Running") { $issues += "VM not running" }
    } catch {}

    try {
        $ping = Test-Connection -ComputerName $BabyNasIP -Count 1 -ErrorAction Stop -Quiet
        if (-not $ping) { $issues += "Ping failed" }
    } catch { $issues += "Ping failed" }

    if ($issues.Count -eq 0) {
        Write-Host ""
        Write-Host "✓ All checks passed! BabyNAS is ready." -ForegroundColor $Colors.Success
        Write-Host ""
        Write-Host "Next step: Run API key generation script" -ForegroundColor $Colors.Info
        Write-Host "  .\create-api-key-ssh.ps1" -ForegroundColor $Colors.Secondary
    } else {
        Write-Host ""
        Write-Host "⚠ Issues detected:" -ForegroundColor $Colors.Warning
        $issues | ForEach-Object { Write-Host "  • $_" -ForegroundColor $Colors.Warning }
        Write-Host ""
        if ($Fix) {
            Write-Host "Run again with -Fix flag to auto-repair" -ForegroundColor $Colors.Info
        } else {
            Write-Host "Use -Fix flag to auto-repair common issues" -ForegroundColor $Colors.Info
            Write-Host "  .\diagnose-baby-nas.ps1 -Fix" -ForegroundColor $Colors.Secondary
        }
    }
}

# Main execution
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor $Colors.Info
Write-Host "║     BabyNAS Comprehensive Diagnostics & Troubleshooting    ║" -ForegroundColor $Colors.Info
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor $Colors.Info

Test-VMStatus
Test-Connectivity
Test-SSHAccess
Test-WebUI
Test-DNS
Test-FileSharing
Show-Troubleshooting
Show-Summary

Write-Host ""
