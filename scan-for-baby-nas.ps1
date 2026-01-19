#Requires -RunAsAdministrator

$logFile = "D:\workspace\Baby_Nas\network-scan-log.txt"

function Write-Log {
    param([string]$Message)
    Add-Content -Path $logFile -Value $Message -Encoding UTF8
    Write-Host $Message
}

"" | Set-Content -Path $logFile -Encoding UTF8
Write-Log "=== Baby NAS Network Scanner ==="
Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Log ""

# Get VM info
$vm = Get-VM -Name "BabyNAS" -ErrorAction SilentlyContinue
if ($vm) {
    Write-Log "VM Status: $($vm.State) - $($vm.Status)"
    $netAdapter = Get-VMNetworkAdapter -VMName "BabyNAS"
    Write-Log "VM Switch: $($netAdapter.SwitchName)"
    Write-Log "VM MAC: $($netAdapter.MacAddress)"
    Write-Log ""
}

# Scan common IP ranges for Hyper-V
Write-Log "Scanning common Hyper-V IP ranges..."
Write-Log ""

$ranges = @(
    @{ Name = "172.21.x"; Base = "172.21.203"; Start = 1; End = 254 },
    @{ Name = "172.23.x"; Base = "172.23.128"; Start = 1; End = 254 },
    @{ Name = "192.168.137.x"; Base = "192.168.137"; Start = 1; End = 254 },
    @{ Name = "10.0.0.x"; Base = "10.0.0"; Start = 1; End = 254 }
)

$foundIPs = @()

foreach ($range in $ranges) {
    Write-Log "Scanning $($range.Name)..."

    for ($i = $range.Start; $i -le $range.End; $i++) {
        $testIP = "$($range.Base).$i"

        # Quick ping test
        $ping = Test-Connection -ComputerName $testIP -Count 1 -Quiet -ErrorAction SilentlyContinue -TimeoutSeconds 1

        if ($ping) {
            Write-Log "  Found: $testIP"

            # Test for HTTPS (TrueNAS web UI)
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $connect = $tcpClient.BeginConnect($testIP, 443, $null, $null)
                $wait = $connect.AsyncWaitHandle.WaitOne(500, $false)

                if ($wait) {
                    $tcpClient.EndConnect($connect)
                    Write-Log "    -> HAS HTTPS SERVICE (Likely TrueNAS!)"
                    $foundIPs += @{
                        IP = $testIP
                        HasHTTPS = $true
                    }
                } else {
                    $foundIPs += @{
                        IP = $testIP
                        HasHTTPS = $false
                    }
                }
                $tcpClient.Close()
            } catch {
                $foundIPs += @{
                    IP = $testIP
                    HasHTTPS = $false
                }
            }
        }
    }
}

Write-Log ""
Write-Log "=== SCAN RESULTS ==="

if ($foundIPs.Count -eq 0) {
    Write-Log "No active IPs found in scanned ranges"
    Write-Log ""
    Write-Log "Troubleshooting steps:"
    Write-Log "  1. Verify VM is running: Get-VM -Name BabyNAS"
    Write-Log "  2. Check VM console for IP: vmconnect.exe localhost BabyNAS"
    Write-Log "  3. Verify network switch is configured correctly"
} else {
    Write-Log "Found $($foundIPs.Count) active IP(s):"
    Write-Log ""

    $trueNAS = $foundIPs | Where-Object { $_.HasHTTPS -eq $true }

    if ($trueNAS) {
        Write-Log "=== BABY NAS FOUND ==="
        Write-Log "IP Address: $($trueNAS.IP)"
        Write-Log "Web UI: https://$($trueNAS.IP)"
        Write-Log "SSH: ssh root@$($trueNAS.IP)"
        Write-Log ""
        Write-Log "SUCCESS!"

        # Save IP to file
        $trueNAS.IP | Out-File "D:\workspace\Baby_Nas\baby-nas-ip.txt" -Encoding UTF8

        exit 0
    } else {
        Write-Log "Active IPs (no HTTPS service detected):"
        foreach ($ip in $foundIPs) {
            Write-Log "  $($ip.IP)"
        }
        Write-Log ""
        Write-Log "None appear to be TrueNAS (no HTTPS service on port 443)"
    }
}

Write-Log ""
Write-Log "Log saved to: $logFile"
