#Requires -RunAsAdministrator
###############################################################################
# Find Baby NAS VM IP Address
# Attempts multiple methods to locate the TrueNAS VM's IP
###############################################################################

$VMName = "TrueNAS-BabyNAS"

Write-Host "=== Finding Baby NAS IP Address ===" -ForegroundColor Cyan
Write-Host ""

# Method 1: Hyper-V Network Adapter
Write-Host "[1/4] Checking Hyper-V Network Adapter..." -ForegroundColor Yellow
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Host "✗ VM '$VMName' not found" -ForegroundColor Red
    exit 1
}

Write-Host "  VM State: $($vm.State)" -ForegroundColor Gray

if ($vm.State -ne "Running") {
    Write-Host "  ⚠ VM is not running" -ForegroundColor Yellow
    $start = Read-Host "  Start VM now? (yes/no)"
    if ($start -eq "yes") {
        Start-VM -Name $VMName
        Write-Host "  Waiting 30 seconds for boot..." -ForegroundColor Cyan
        Start-Sleep -Seconds 30
    } else {
        exit 0
    }
}

$netAdapter = Get-VMNetworkAdapter -VMName $VMName
if ($netAdapter.IPAddresses) {
    Write-Host "  ✓ Found IP addresses via Hyper-V:" -ForegroundColor Green
    $netAdapter.IPAddresses | ForEach-Object {
        Write-Host "    $_" -ForegroundColor White
    }
    $foundIP = $netAdapter.IPAddresses | Where-Object { $_ -notmatch ":" } | Select-Object -First 1
    if ($foundIP) {
        Write-Host ""
        Write-Host "✓ Baby NAS IP: $foundIP" -ForegroundColor Green
        Write-Host ""
        Write-Host "Connection Details:" -ForegroundColor Yellow
        Write-Host "  Web UI: https://$foundIP" -ForegroundColor Cyan
        Write-Host "  SSH: ssh root@$foundIP" -ForegroundColor Cyan
        Write-Host "  Password: uppercut%`$##" -ForegroundColor Cyan
        Write-Host ""

        # Save to file
        $foundIP | Out-File "D:\workspace\True_Nas\windows-scripts\baby-nas-ip.txt" -Encoding UTF8
        Write-Host "IP saved to: D:\workspace\True_Nas\windows-scripts\baby-nas-ip.txt" -ForegroundColor Gray

        $openUI = Read-Host "Open Web UI now? (yes/no)"
        if ($openUI -eq "yes") {
            Start-Process "https://$foundIP"
        }
        exit 0
    }
} else {
    Write-Host "  ✗ No IP addresses detected" -ForegroundColor Red
}

# Method 2: ARP Table Scan
Write-Host ""
Write-Host "[2/4] Scanning ARP table..." -ForegroundColor Yellow
$arpEntries = arp -a | Select-String "172\.|192\.|10\." | ForEach-Object { $_.ToString().Trim() }
Write-Host "  Found $($arpEntries.Count) local IPs" -ForegroundColor Gray

# Method 3: Network Scan (common Hyper-V ranges)
Write-Host ""
Write-Host "[3/4] Scanning common Hyper-V IP ranges..." -ForegroundColor Yellow
$ranges = @(
    "172.23.128.0/20",
    "172.21.192.0/20",
    "192.168.137.0/24"
)

$possibleIPs = @()

foreach ($range in $ranges) {
    Write-Host "  Scanning $range..." -ForegroundColor Gray
    $baseIP = $range.Split('/')[0]
    $octets = $baseIP.Split('.')

    # Scan first 50 IPs in range
    for ($i = 1; $i -le 50; $i++) {
        $testIP = "$($octets[0]).$($octets[1]).$($octets[2]).$i"
        $ping = Test-Connection -ComputerName $testIP -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ping) {
            Write-Host "    ✓ $testIP responds" -ForegroundColor Green
            $possibleIPs += $testIP
        }
    }
}

if ($possibleIPs.Count -gt 0) {
    Write-Host ""
    Write-Host "  Found $($possibleIPs.Count) responding IP(s):" -ForegroundColor Green
    $possibleIPs | ForEach-Object { Write-Host "    $_" -ForegroundColor White }

    Write-Host ""
    Write-Host "  Testing for TrueNAS..." -ForegroundColor Cyan

    foreach ($ip in $possibleIPs) {
        try {
            # Try HTTPS port 443 (TrueNAS web UI)
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($ip, 443, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(1000, $false)

            if ($wait) {
                $tcpClient.EndConnect($connect)
                Write-Host "    ✓ $ip has HTTPS service (likely TrueNAS)" -ForegroundColor Green

                Write-Host ""
                Write-Host "✓ Baby NAS IP: $ip" -ForegroundColor Green
                Write-Host ""
                Write-Host "Connection Details:" -ForegroundColor Yellow
                Write-Host "  Web UI: https://$ip" -ForegroundColor Cyan
                Write-Host "  SSH: ssh root@$ip" -ForegroundColor Cyan
                Write-Host "  Password: uppercut%`$##" -ForegroundColor Cyan
                Write-Host ""

                # Save to file
                $ip | Out-File "D:\workspace\True_Nas\windows-scripts\baby-nas-ip.txt" -Encoding UTF8
                Write-Host "IP saved to: D:\workspace\True_Nas\windows-scripts\baby-nas-ip.txt" -ForegroundColor Gray

                $openUI = Read-Host "Open Web UI now? (yes/no)"
                if ($openUI -eq "yes") {
                    Start-Process "https://$ip"
                }
                exit 0
            }
            $tcpClient.Close()
        } catch {
            # Silent fail, continue to next IP
        }
    }
}

# Method 4: Manual Entry
Write-Host ""
Write-Host "[4/4] Manual IP Entry" -ForegroundColor Yellow
Write-Host ""
Write-Host "Unable to automatically detect Baby NAS IP." -ForegroundColor Yellow
Write-Host ""
Write-Host "Please check the VM console to find the IP address:" -ForegroundColor Cyan
Write-Host "  1. Run: vmconnect.exe localhost $VMName" -ForegroundColor White
Write-Host "  2. Look for IP address on the TrueNAS console screen" -ForegroundColor White
Write-Host "  3. If at login prompt, login with: root / uppercut%`$##" -ForegroundColor White
Write-Host "  4. Check IP with: ip addr show" -ForegroundColor White
Write-Host ""

$openConsole = Read-Host "Open VM console now? (yes/no)"
if ($openConsole -eq "yes") {
    vmconnect.exe localhost $VMName
    Write-Host ""
    Write-Host "After viewing the console..." -ForegroundColor Yellow
}

Write-Host ""
$manualIP = Read-Host "Enter Baby NAS IP address (or press Enter to skip)"

if (-not [string]::IsNullOrWhiteSpace($manualIP)) {
    Write-Host ""
    Write-Host "Testing $manualIP..." -ForegroundColor Cyan

    if (Test-Connection -ComputerName $manualIP -Count 2 -Quiet) {
        Write-Host "✓ IP is reachable" -ForegroundColor Green

        # Save to file
        $manualIP | Out-File "D:\workspace\True_Nas\windows-scripts\baby-nas-ip.txt" -Encoding UTF8

        Write-Host ""
        Write-Host "Connection Details:" -ForegroundColor Yellow
        Write-Host "  Web UI: https://$manualIP" -ForegroundColor Cyan
        Write-Host "  SSH: ssh root@$manualIP" -ForegroundColor Cyan
        Write-Host "  Password: uppercut%`$##" -ForegroundColor Cyan
        Write-Host ""

        $openUI = Read-Host "Open Web UI now? (yes/no)"
        if ($openUI -eq "yes") {
            Start-Process "https://$manualIP"
        }
    } else {
        Write-Host "✗ Cannot reach $manualIP" -ForegroundColor Red
        Write-Host "  Please verify the IP is correct and try again" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Search Complete ===" -ForegroundColor Cyan
Write-Host ""
