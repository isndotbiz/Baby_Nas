#Requires -RunAsAdministrator

Write-Host ""
Write-Host "=== Baby NAS VM Startup ===" -ForegroundColor Cyan
Write-Host ""

# Try to find the VM by different possible names
$possibleNames = @("TrueNAS-BabyNAS", "BabyNAS", "Baby-NAS", "TrueNAS")
$vm = $null
$vmName = $null

Write-Host "Searching for Baby NAS VM..." -ForegroundColor Yellow
foreach ($name in $possibleNames) {
    try {
        $testVm = Get-VM -Name $name -ErrorAction SilentlyContinue
        if ($testVm) {
            $vm = $testVm
            $vmName = $name
            Write-Host "  Found VM: $vmName" -ForegroundColor Green
            break
        }
    } catch {
        continue
    }
}

if (-not $vm) {
    Write-Host "  No Baby NAS VM found. Listing all VMs:" -ForegroundColor Red
    Write-Host ""
    Get-VM | Select-Object Name, State, Status, Uptime | Format-Table -AutoSize
    exit 1
}

Write-Host ""
Write-Host "=== VM Details ===" -ForegroundColor Cyan
Write-Host "  Name:         $($vm.Name)" -ForegroundColor White
Write-Host "  State:        $($vm.State)" -ForegroundColor $(if ($vm.State -eq "Running") { "Green" } else { "Yellow" })
Write-Host "  Status:       $($vm.Status)" -ForegroundColor White
Write-Host "  CPU Usage:    $($vm.CPUUsage)%" -ForegroundColor White
Write-Host "  Memory:       $([math]::Round($vm.MemoryAssigned / 1GB, 2)) GB" -ForegroundColor White
if ($vm.State -eq "Running") {
    Write-Host "  Uptime:       $($vm.Uptime)" -ForegroundColor Gray
}

Write-Host ""

# Start VM if not running
if ($vm.State -ne "Running") {
    Write-Host "Starting VM..." -ForegroundColor Yellow
    try {
        Start-VM -Name $vmName -ErrorAction Stop
        Write-Host "  VM start command sent successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "Waiting for VM to initialize (10 seconds)..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    } catch {
        Write-Host "  Error starting VM: $($_.Exception.Message)" -ForegroundColor Red
        exit 2
    }
}

# Get network adapter info to find IP
Write-Host "Checking network connectivity..." -ForegroundColor Yellow
$networkAdapter = Get-VMNetworkAdapter -VMName $vmName
Write-Host "  Network Adapter: $($networkAdapter.SwitchName)" -ForegroundColor Gray

# Try common IP addresses for Baby NAS
$possibleIPs = @("172.21.203.18", "10.0.0.99", "192.168.1.99")
$connectedIP = $null

foreach ($ip in $possibleIPs) {
    Write-Host "  Testing $ip..." -ForegroundColor Gray -NoNewline
    $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        Write-Host " ONLINE" -ForegroundColor Green
        $connectedIP = $ip
        break
    } else {
        Write-Host " No response" -ForegroundColor DarkGray
    }
}

Write-Host ""
if ($connectedIP) {
    Write-Host "=== SUCCESS ===" -ForegroundColor Green
    Write-Host "  VM Name:      $vmName" -ForegroundColor White
    Write-Host "  Status:       Running" -ForegroundColor Green
    Write-Host "  IP Address:   $connectedIP" -ForegroundColor Green
    Write-Host ""
    Write-Host "Baby NAS is ready!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== PARTIAL SUCCESS ===" -ForegroundColor Yellow
    Write-Host "  VM Name:      $vmName" -ForegroundColor White
    Write-Host "  Status:       $($vm.State)" -ForegroundColor Yellow
    Write-Host "  Network:      Not yet responding" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The VM is starting but network is not ready yet." -ForegroundColor Yellow
    Write-Host "This is normal - TrueNAS may take 1-2 minutes to fully boot." -ForegroundColor Gray
    Write-Host ""
    Write-Host "You can:" -ForegroundColor White
    Write-Host "  - Wait a minute and run this script again" -ForegroundColor Gray
    Write-Host "  - Open VM console to watch boot progress" -ForegroundColor Gray
    exit 0
}
