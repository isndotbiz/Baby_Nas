#Requires -RunAsAdministrator

$logFile = "D:\workspace\Baby_Nas\vm-startup-log.txt"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $Message -ForegroundColor $Color
}

# Clear previous log
"" | Set-Content -Path $logFile

Write-Log "" "Cyan"
Write-Log "=== Baby NAS VM Startup ===" "Cyan"
Write-Log "" "Cyan"

# Try to find the VM by different possible names
$possibleNames = @("TrueNAS-BabyNAS", "BabyNAS", "Baby-NAS", "TrueNAS")
$vm = $null
$vmName = $null

Write-Log "Searching for Baby NAS VM..." "Yellow"
foreach ($name in $possibleNames) {
    try {
        $testVm = Get-VM -Name $name -ErrorAction SilentlyContinue
        if ($testVm) {
            $vm = $testVm
            $vmName = $name
            Write-Log "  Found VM: $vmName" "Green"
            break
        }
    } catch {
        continue
    }
}

if (-not $vm) {
    Write-Log "  No Baby NAS VM found. Listing all VMs:" "Red"
    Write-Log "" "White"
    $allVMs = Get-VM | Select-Object Name, State, Status, Uptime
    foreach ($v in $allVMs) {
        Write-Log "  - $($v.Name) | State: $($v.State) | Status: $($v.Status)" "White"
    }
    exit 1
}

Write-Log "" "White"
Write-Log "=== VM Details ===" "Cyan"
Write-Log "  Name:         $($vm.Name)" "White"
Write-Log "  State:        $($vm.State)" $(if ($vm.State -eq "Running") { "Green" } else { "Yellow" })
Write-Log "  Status:       $($vm.Status)" "White"
Write-Log "  CPU Usage:    $($vm.CPUUsage)%" "White"
Write-Log "  Memory:       $([math]::Round($vm.MemoryAssigned / 1GB, 2)) GB" "White"
if ($vm.State -eq "Running") {
    Write-Log "  Uptime:       $($vm.Uptime)" "Gray"
}

Write-Log "" "White"

# Start VM if not running
if ($vm.State -ne "Running") {
    Write-Log "Starting VM..." "Yellow"
    try {
        Start-VM -Name $vmName -ErrorAction Stop
        Write-Log "  VM start command sent successfully" "Green"
        Write-Log "" "White"
        Write-Log "Waiting for VM to initialize (10 seconds)..." "Yellow"
        Start-Sleep -Seconds 10
    } catch {
        Write-Log "  Error starting VM: $($_.Exception.Message)" "Red"
        exit 2
    }
}

# Get network adapter info to find IP
Write-Log "Checking network connectivity..." "Yellow"
$networkAdapter = Get-VMNetworkAdapter -VMName $vmName
Write-Log "  Network Adapter: $($networkAdapter.SwitchName)" "Gray"

# Try common IP addresses for Baby NAS
$possibleIPs = @("172.21.203.18", "10.0.0.99", "192.168.1.99")
$connectedIP = $null

foreach ($ip in $possibleIPs) {
    Write-Log "  Testing $ip..." "Gray"
    $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        Write-Log "    Result: ONLINE" "Green"
        $connectedIP = $ip
        break
    } else {
        Write-Log "    Result: No response" "DarkGray"
    }
}

Write-Log "" "White"
if ($connectedIP) {
    Write-Log "=== SUCCESS ===" "Green"
    Write-Log "  VM Name:      $vmName" "White"
    Write-Log "  Status:       Running" "Green"
    Write-Log "  IP Address:   $connectedIP" "Green"
    Write-Log "" "White"
    Write-Log "Baby NAS is ready!" "Green"
    Write-Log "" "White"
    Write-Log "Log saved to: $logFile" "Gray"
    exit 0
} else {
    Write-Log "=== PARTIAL SUCCESS ===" "Yellow"
    Write-Log "  VM Name:      $vmName" "White"
    Write-Log "  Status:       $($vm.State)" "Yellow"
    Write-Log "  Network:      Not yet responding" "Yellow"
    Write-Log "" "White"
    Write-Log "The VM is starting but network is not ready yet." "Yellow"
    Write-Log "This is normal - TrueNAS may take 1-2 minutes to fully boot." "Gray"
    Write-Log "" "White"
    Write-Log "Log saved to: $logFile" "Gray"
    exit 0
}
