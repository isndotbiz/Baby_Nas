#Requires -RunAsAdministrator

$VMName = "BabyNAS"
$logFile = "D:\workspace\Baby_Nas\vm-ip-log.txt"

"=== Baby NAS IP Detection ===" | Out-File -FilePath $logFile
"Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logFile -Append
"" | Out-File -FilePath $logFile -Append

# Get VM status
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

if (-not $vm) {
    "ERROR: VM '$VMName' not found" | Out-File -FilePath $logFile -Append
    Write-Host "ERROR: VM not found"
    exit 1
}

"VM Name: $($vm.Name)" | Out-File -FilePath $logFile -Append
"VM State: $($vm.State)" | Out-File -FilePath $logFile -Append
"VM Status: $($vm.Status)" | Out-File -FilePath $logFile -Append
"VM Uptime: $($vm.Uptime)" | Out-File -FilePath $logFile -Append
"" | Out-File -FilePath $logFile -Append

# Get network adapter
$netAdapter = Get-VMNetworkAdapter -VMName $VMName

"Network Adapter:" | Out-File -FilePath $logFile -Append
"  Switch: $($netAdapter.SwitchName)" | Out-File -FilePath $logFile -Append
"  MAC: $($netAdapter.MacAddress)" | Out-File -FilePath $logFile -Append
"  Status: $($netAdapter.Status)" | Out-File -FilePath $logFile -Append
"" | Out-File -FilePath $logFile -Append

# Check for IP addresses from Hyper-V
if ($netAdapter.IPAddresses -and $netAdapter.IPAddresses.Count -gt 0) {
    "IP Addresses detected by Hyper-V:" | Out-File -FilePath $logFile -Append
    $netAdapter.IPAddresses | ForEach-Object {
        "  $_" | Out-File -FilePath $logFile -Append
    }

    # Get IPv4 only (filter out IPv6)
    $ipv4 = $netAdapter.IPAddresses | Where-Object { $_ -notmatch ":" } | Select-Object -First 1

    if ($ipv4) {
        "" | Out-File -FilePath $logFile -Append
        "=== PRIMARY IP ADDRESS ===" | Out-File -FilePath $logFile -Append
        "IP: $ipv4" | Out-File -FilePath $logFile -Append
        "" | Out-File -FilePath $logFile -Append

        # Test connectivity
        "Testing connectivity..." | Out-File -FilePath $logFile -Append
        $ping = Test-Connection -ComputerName $ipv4 -Count 2 -ErrorAction SilentlyContinue

        if ($ping) {
            "Status: ONLINE" | Out-File -FilePath $logFile -Append
            "Average Response Time: $([math]::Round(($ping | Measure-Object -Property ResponseTime -Average).Average, 2)) ms" | Out-File -FilePath $logFile -Append
            "" | Out-File -FilePath $logFile -Append
            "=== SUCCESS ===" | Out-File -FilePath $logFile -Append
            "Baby NAS is accessible at: $ipv4" | Out-File -FilePath $logFile -Append
            "Web UI: https://$ipv4" | Out-File -FilePath $logFile -Append
            "SSH: ssh root@$ipv4" | Out-File -FilePath $logFile -Append

            Write-Host "SUCCESS: Baby NAS is online at $ipv4"
        } else {
            "Status: VM running but not responding to ping" | Out-File -FilePath $logFile -Append
            "This may be normal if TrueNAS is still booting" | Out-File -FilePath $logFile -Append
            Write-Host "WARNING: VM running but IP $ipv4 not responding"
        }
    }
} else {
    "No IP addresses detected by Hyper-V integration services" | Out-File -FilePath $logFile -Append
    "This is normal if:" | Out-File -FilePath $logFile -Append
    "  - VM is still booting" | Out-File -FilePath $logFile -Append
    "  - Guest integration services not installed/running" | Out-File -FilePath $logFile -Append
    "  - Network adapter not configured" | Out-File -FilePath $logFile -Append
    Write-Host "WARNING: No IP detected yet"
}

"" | Out-File -FilePath $logFile -Append
"Log saved to: $logFile" | Out-File -FilePath $logFile -Append

Write-Host "Log file: $logFile"
