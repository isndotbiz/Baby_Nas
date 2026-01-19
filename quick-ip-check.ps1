#Requires -RunAsAdministrator

Write-Host "=== Baby NAS Quick IP Check ===" -ForegroundColor Cyan
Write-Host ""

# Check VM status
$vm = Get-VM -Name "BabyNAS" -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Host "ERROR: VM 'BabyNAS' not found" -ForegroundColor Red
    exit 1
}

Write-Host "VM Name:   $($vm.Name)" -ForegroundColor White
Write-Host "State:     $($vm.State)" -ForegroundColor $(if ($vm.State -eq "Running") { "Green" } else { "Yellow" })
Write-Host "Uptime:    $($vm.Uptime)" -ForegroundColor Gray
Write-Host ""

# Check Hyper-V reported IP
$netAdapter = Get-VMNetworkAdapter -VMName "BabyNAS"
Write-Host "Network Switch: $($netAdapter.SwitchName)" -ForegroundColor Gray
Write-Host ""

if ($netAdapter.IPAddresses) {
    Write-Host "Hyper-V Reported IPs:" -ForegroundColor Yellow
    $netAdapter.IPAddresses | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White

        if ($_ -notmatch ":") {
            # Test this IP
            Write-Host "  Testing..." -NoNewline -ForegroundColor Gray
            $ping = Test-Connection -ComputerName $_ -Count 1 -Quiet -ErrorAction SilentlyContinue
            if ($ping) {
                Write-Host " ONLINE" -ForegroundColor Green
                Write-Host ""
                Write-Host "=== SUCCESS ===" -ForegroundColor Green
                Write-Host "IP: $_" -ForegroundColor White
                Write-Host "Web UI: https://$_" -ForegroundColor Cyan
                exit 0
            } else {
                Write-Host " No response" -ForegroundColor Red
            }
        }
    }
    Write-Host ""
}

# Try common IPs from documentation
Write-Host "Trying documented IPs..." -ForegroundColor Yellow
$commonIPs = @(
    "172.21.203.18",
    "10.0.0.99",
    "192.168.137.1",
    "172.23.128.1"
)

foreach ($ip in $commonIPs) {
    Write-Host "  $ip..." -NoNewline -ForegroundColor Gray
    $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        Write-Host " ONLINE" -ForegroundColor Green

        # Test for HTTPS
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connect = $tcpClient.BeginConnect($ip, 443, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(1000, $false)

            if ($wait) {
                $tcpClient.EndConnect($connect)
                Write-Host "    Has HTTPS - This is Baby NAS!" -ForegroundColor Green
                Write-Host ""
                Write-Host "=== SUCCESS ===" -ForegroundColor Green
                Write-Host "IP: $ip" -ForegroundColor White
                Write-Host "Web UI: https://$ip" -ForegroundColor Cyan
                $tcpClient.Close()

                # Save to file
                $ip | Out-File "D:\workspace\Baby_Nas\baby-nas-ip.txt" -Encoding UTF8
                exit 0
            }
            $tcpClient.Close()
        } catch {}
    } else {
        Write-Host " Not responding" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "=== IP NOT FOUND ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "The VM is running but network is not accessible yet." -ForegroundColor Yellow
Write-Host "This can happen if:" -ForegroundColor Gray
Write-Host "  - TrueNAS is still booting (wait 1-2 minutes)" -ForegroundColor Gray
Write-Host "  - Integration services not installed" -ForegroundColor Gray
Write-Host "  - Network configuration issue" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Wait 2 minutes and run this script again" -ForegroundColor Gray
Write-Host "  2. Open VM console: vmconnect.exe localhost BabyNAS" -ForegroundColor Gray
Write-Host "  3. Check IP in TrueNAS console with: ip addr show" -ForegroundColor Gray
Write-Host ""
