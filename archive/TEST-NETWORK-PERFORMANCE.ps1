###############################################################################
# Network Performance Testing for Baby NAS
# Tests SMB throughput, latency, and replication performance
###############################################################################

param(
    [string]$BabyNasIP = "",
    [string]$MainNasIP = "10.0.0.89",
    [int]$TestSizeMB = 100,
    [switch]$QuickTest,
    [switch]$SkipReplicationTest
)

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "      Baby NAS Network Performance Test                       " -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# Create results directory
$resultsDir = "C:\Logs\network-tests"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultsFile = "$resultsDir\network-test-$timestamp.json"

$results = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    BabyNasIP = ""
    MainNasIP = $MainNasIP
    TestSizeMB = $TestSizeMB
    Tests = @{}
}

# Load configuration
$configPath = "$PSScriptRoot\monitoring-config.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        if ([string]::IsNullOrEmpty($BabyNasIP)) {
            $BabyNasIP = $config.babyNAS.ip
        }
    } catch {
        Write-Host "Warning: Could not load config" -ForegroundColor Yellow
    }
}

if ([string]::IsNullOrEmpty($BabyNasIP)) { $BabyNasIP = "172.21.203.18" }
$results.BabyNasIP = $BabyNasIP

if ($QuickTest) { $TestSizeMB = 10 }

Write-Host "Configuration:" -ForegroundColor White
Write-Host "  Baby NAS: $BabyNasIP" -ForegroundColor Gray
Write-Host "  Main NAS: $MainNasIP" -ForegroundColor Gray
Write-Host "  Test Size: $TestSizeMB MB" -ForegroundColor Gray
Write-Host ""

###############################################################################
# Test 1: Network Latency
###############################################################################
Write-Host "[1/6] Testing Network Latency" -ForegroundColor Cyan
Write-Host "-----------------------------" -ForegroundColor Gray

$targets = @(
    @{Name="Baby NAS"; IP=$BabyNasIP},
    @{Name="Main NAS"; IP=$MainNasIP}
)

$latencyResults = @{}

foreach ($target in $targets) {
    Write-Host "  Pinging $($target.Name) ($($target.IP))..." -ForegroundColor White

    $pingResults = Test-Connection -ComputerName $target.IP -Count 10 -ErrorAction SilentlyContinue

    if ($pingResults) {
        $avgLatency = ($pingResults | Measure-Object -Property ResponseTime -Average).Average
        $minLatency = ($pingResults | Measure-Object -Property ResponseTime -Minimum).Minimum
        $maxLatency = ($pingResults | Measure-Object -Property ResponseTime -Maximum).Maximum
        $packetLoss = ((10 - $pingResults.Count) / 10) * 100

        Write-Host "    Avg: $([math]::Round($avgLatency, 2)) ms | Min: $minLatency ms | Max: $maxLatency ms | Loss: $packetLoss%" -ForegroundColor $(if($avgLatency -lt 5){"Green"}elseif($avgLatency -lt 20){"Yellow"}else{"Red"})

        $latencyResults[$target.Name] = @{
            IP = $target.IP
            AvgLatency = [math]::Round($avgLatency, 2)
            MinLatency = $minLatency
            MaxLatency = $maxLatency
            PacketLoss = $packetLoss
            Status = "OK"
        }
    } else {
        Write-Host "    FAILED: Host unreachable" -ForegroundColor Red
        $latencyResults[$target.Name] = @{
            IP = $target.IP
            Status = "UNREACHABLE"
        }
    }
}

$results.Tests.Latency = $latencyResults

###############################################################################
# Test 2: SMB Port Connectivity
###############################################################################
Write-Host ""
Write-Host "[2/6] Testing SMB Port Connectivity" -ForegroundColor Cyan
Write-Host "------------------------------------" -ForegroundColor Gray

$portResults = @{}

foreach ($target in $targets) {
    Write-Host "  Testing $($target.Name)..." -ForegroundColor White

    $ports = @(
        @{Port=445; Name="SMB"},
        @{Port=22; Name="SSH"},
        @{Port=443; Name="HTTPS"}
    )

    $targetPorts = @{}

    foreach ($port in $ports) {
        $test = Test-NetConnection -ComputerName $target.IP -Port $port.Port -WarningAction SilentlyContinue
        $status = if ($test.TcpTestSucceeded) { "OPEN" } else { "CLOSED" }
        $color = if ($test.TcpTestSucceeded) { "Green" } else { "Red" }

        Write-Host "    $($port.Name) ($($port.Port)): $status" -ForegroundColor $color
        $targetPorts[$port.Name] = @{
            Port = $port.Port
            Status = $status
        }
    }

    $portResults[$target.Name] = $targetPorts
}

$results.Tests.Ports = $portResults

###############################################################################
# Test 3: SMB Connection Details
###############################################################################
Write-Host ""
Write-Host "[3/6] SMB Connection Analysis" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor Gray

$smbResults = @{}

# Check current connections
$connections = Get-SmbConnection -ErrorAction SilentlyContinue

if ($connections) {
    Write-Host "  Active SMB Connections:" -ForegroundColor White
    foreach ($conn in $connections) {
        $dialect = $conn.Dialect
        $dialectRating = switch -Regex ($dialect) {
            "3\.1\.1" { "Excellent (SMB 3.1.1)" }
            "3\.0[2]?" { "Good (SMB 3.0)" }
            "2\.1" { "Acceptable (SMB 2.1)" }
            default { "Consider upgrade" }
        }
        Write-Host "    $($conn.ServerName): $dialect - $dialectRating" -ForegroundColor $(if($dialect -match "3\."){"Green"}else{"Yellow"})

        $smbResults[$conn.ServerName] = @{
            ShareName = $conn.ShareName
            Dialect = $dialect
            NumOpens = $conn.NumOpens
        }
    }
} else {
    Write-Host "  No active SMB connections" -ForegroundColor Yellow
    Write-Host "  Attempting to connect to Baby NAS..." -ForegroundColor White

    # Try to establish connection
    $testShare = "\\$BabyNasIP\IPC$"
    $netResult = net use $testShare 2>&1 | Out-String

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Connected successfully" -ForegroundColor Green
        net use $testShare /delete /yes 2>&1 | Out-Null

        # Re-check connection details
        $connections = Get-SmbConnection -ErrorAction SilentlyContinue
        if ($connections) {
            foreach ($conn in $connections) {
                $smbResults[$conn.ServerName] = @{
                    Dialect = $conn.Dialect
                }
            }
        }
    } else {
        Write-Host "    Connection failed - credentials may be required" -ForegroundColor Yellow
    }
}

$results.Tests.SMBConnections = $smbResults

# SMB Client Configuration
Write-Host ""
Write-Host "  SMB Client Configuration:" -ForegroundColor White
$smbConfig = Get-SmbClientConfiguration
$configItems = @(
    @{Name="EnableLargeMtu"; Value=$smbConfig.EnableLargeMtu; Optimal=$true},
    @{Name="EnableMultiChannel"; Value=$smbConfig.EnableMultiChannel; Optimal=$true},
    @{Name="EnableBandwidthThrottling"; Value=$smbConfig.EnableBandwidthThrottling; Optimal=$false}
)

$smbClientConfig = @{}
foreach ($item in $configItems) {
    $status = if ($item.Value -eq $item.Optimal) { "[OK]" } else { "[SUBOPTIMAL]" }
    $color = if ($item.Value -eq $item.Optimal) { "Green" } else { "Yellow" }
    Write-Host "    $status $($item.Name): $($item.Value)" -ForegroundColor $color
    $smbClientConfig[$item.Name] = $item.Value
}

$results.Tests.SMBClientConfig = $smbClientConfig

###############################################################################
# Test 4: SMB Write Speed
###############################################################################
Write-Host ""
Write-Host "[4/6] SMB Write Speed Test ($TestSizeMB MB)" -ForegroundColor Cyan
Write-Host "--------------------------------------------" -ForegroundColor Gray

$writeResults = @{}

# Try common share paths
$testShares = @(
    "\\$BabyNasIP\WindowsBackup",
    "\\$BabyNasIP\Veeam",
    "\\$BabyNasIP\backups"
)

$testShare = $null
foreach ($share in $testShares) {
    if (Test-Path $share -ErrorAction SilentlyContinue) {
        $testShare = $share
        break
    }
}

if ($testShare) {
    Write-Host "  Testing write to: $testShare" -ForegroundColor White

    $testFile = "$testShare\speedtest-$timestamp.bin"
    $testSizeBytes = $TestSizeMB * 1MB

    # Generate test data
    Write-Host "  Generating $TestSizeMB MB test data..." -ForegroundColor Gray
    $buffer = New-Object byte[] $testSizeBytes
    (New-Object Random).NextBytes($buffer)

    # Write test
    Write-Host "  Writing..." -ForegroundColor White
    $writeStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        [System.IO.File]::WriteAllBytes($testFile, $buffer)
        $writeStopwatch.Stop()

        $writeSpeedMBps = $TestSizeMB / $writeStopwatch.Elapsed.TotalSeconds
        Write-Host "    Write Speed: $([math]::Round($writeSpeedMBps, 2)) MB/s" -ForegroundColor $(if($writeSpeedMBps -gt 50){"Green"}elseif($writeSpeedMBps -gt 20){"Yellow"}else{"Red"})

        $writeResults.WriteMBps = [math]::Round($writeSpeedMBps, 2)
        $writeResults.WriteTimeSeconds = [math]::Round($writeStopwatch.Elapsed.TotalSeconds, 2)
        $writeResults.Status = "OK"

        # Read test
        Write-Host "  Reading..." -ForegroundColor White
        $readStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $readBuffer = [System.IO.File]::ReadAllBytes($testFile)
        $readStopwatch.Stop()

        $readSpeedMBps = $TestSizeMB / $readStopwatch.Elapsed.TotalSeconds
        Write-Host "    Read Speed: $([math]::Round($readSpeedMBps, 2)) MB/s" -ForegroundColor $(if($readSpeedMBps -gt 50){"Green"}elseif($readSpeedMBps -gt 20){"Yellow"}else{"Red"})

        $writeResults.ReadMBps = [math]::Round($readSpeedMBps, 2)
        $writeResults.ReadTimeSeconds = [math]::Round($readStopwatch.Elapsed.TotalSeconds, 2)

        # Cleanup
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Write-Host "    Test file cleaned up" -ForegroundColor Gray

    } catch {
        Write-Host "    FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $writeResults.Status = "FAILED"
        $writeResults.Error = $_.Exception.Message
    }
} else {
    Write-Host "  No accessible SMB share found for testing" -ForegroundColor Yellow
    Write-Host "  Ensure shares are mounted or accessible" -ForegroundColor Yellow
    $writeResults.Status = "NO_SHARE"
}

$results.Tests.SMBSpeed = $writeResults

###############################################################################
# Test 5: MTU Path Discovery
###############################################################################
Write-Host ""
Write-Host "[5/6] MTU Path Discovery" -ForegroundColor Cyan
Write-Host "------------------------" -ForegroundColor Gray

$mtuResults = @{}

foreach ($target in $targets) {
    Write-Host "  Testing MTU to $($target.Name)..." -ForegroundColor White

    # Test standard MTU (1500)
    $standardMTU = 1472  # 1500 - 28 (IP + ICMP headers)
    $pingResult = ping -f -l $standardMTU -n 1 $target.IP 2>&1 | Out-String

    if ($pingResult -match "Reply from") {
        Write-Host "    Standard MTU (1500): OK" -ForegroundColor Green
        $mtuResults[$target.Name] = @{
            StandardMTU = "OK"
        }

        # Test jumbo frames (9000)
        $jumboMTU = 8972  # 9000 - 28
        $jumboResult = ping -f -l $jumboMTU -n 1 $target.IP 2>&1 | Out-String

        if ($jumboResult -match "Reply from") {
            Write-Host "    Jumbo Frames (9000): Supported" -ForegroundColor Green
            $mtuResults[$target.Name].JumboFrames = "SUPPORTED"
        } else {
            Write-Host "    Jumbo Frames (9000): Not supported" -ForegroundColor Yellow
            $mtuResults[$target.Name].JumboFrames = "NOT_SUPPORTED"
        }
    } else {
        Write-Host "    MTU test failed (fragmentation required)" -ForegroundColor Yellow
        $mtuResults[$target.Name] = @{
            StandardMTU = "FRAGMENTED"
        }
    }
}

$results.Tests.MTU = $mtuResults

###############################################################################
# Test 6: SSH Replication Performance (if applicable)
###############################################################################
Write-Host ""
Write-Host "[6/6] SSH Replication Performance" -ForegroundColor Cyan
Write-Host "----------------------------------" -ForegroundColor Gray

$sshResults = @{}

if ($SkipReplicationTest) {
    Write-Host "  Skipped (use without -SkipReplicationTest to enable)" -ForegroundColor Yellow
    $sshResults.Status = "SKIPPED"
} else {
    $sshKeyPath = "$env:USERPROFILE\.ssh\id_babynas"

    if (Test-Path $sshKeyPath) {
        Write-Host "  Testing SSH throughput to Baby NAS..." -ForegroundColor White

        # Test SSH connection and cipher negotiation
        $sshTest = ssh -v -o ConnectTimeout=10 -i $sshKeyPath "root@$BabyNasIP" "echo 'SSH OK'; uname -a" 2>&1 | Out-String

        if ($sshTest -match "SSH OK") {
            Write-Host "    SSH connection: OK" -ForegroundColor Green

            # Extract cipher information
            if ($sshTest -match "cipher: (.+?),") {
                $cipher = $matches[1]
                Write-Host "    Cipher: $cipher" -ForegroundColor White
                $sshResults.Cipher = $cipher
            }

            $sshResults.Status = "OK"
        } else {
            Write-Host "    SSH connection: FAILED" -ForegroundColor Red
            $sshResults.Status = "FAILED"
        }
    } else {
        Write-Host "  SSH key not found: $sshKeyPath" -ForegroundColor Yellow
        Write-Host "  Run setup-ssh-keys-complete.ps1 to configure" -ForegroundColor Yellow
        $sshResults.Status = "NO_KEY"
    }
}

$results.Tests.SSH = $sshResults

###############################################################################
# Summary
###############################################################################
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "      Network Performance Test Summary                        " -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""

# Calculate overall score
$score = 0
$maxScore = 100

# Latency scoring (max 20 points)
if ($results.Tests.Latency["Baby NAS"].Status -eq "OK") {
    $latency = $results.Tests.Latency["Baby NAS"].AvgLatency
    if ($latency -lt 1) { $score += 20 }
    elseif ($latency -lt 5) { $score += 15 }
    elseif ($latency -lt 10) { $score += 10 }
    elseif ($latency -lt 20) { $score += 5 }
}

# Port connectivity (max 20 points)
if ($results.Tests.Ports["Baby NAS"]["SMB"].Status -eq "OPEN") { $score += 10 }
if ($results.Tests.Ports["Baby NAS"]["SSH"].Status -eq "OPEN") { $score += 10 }

# SMB speed (max 40 points)
if ($results.Tests.SMBSpeed.Status -eq "OK") {
    $writeSpeed = $results.Tests.SMBSpeed.WriteMBps
    if ($writeSpeed -gt 100) { $score += 40 }
    elseif ($writeSpeed -gt 50) { $score += 30 }
    elseif ($writeSpeed -gt 20) { $score += 20 }
    elseif ($writeSpeed -gt 10) { $score += 10 }
}

# SMB config (max 20 points)
if ($results.Tests.SMBClientConfig.EnableLargeMtu) { $score += 7 }
if ($results.Tests.SMBClientConfig.EnableMultiChannel) { $score += 7 }
if (-not $results.Tests.SMBClientConfig.EnableBandwidthThrottling) { $score += 6 }

$scorePercent = [math]::Round(($score / $maxScore) * 100)
$scoreColor = if ($scorePercent -ge 80) { "Green" } elseif ($scorePercent -ge 60) { "Yellow" } else { "Red" }

Write-Host "Performance Score: $scorePercent/100" -ForegroundColor $scoreColor
Write-Host ""

# Display key metrics
Write-Host "Key Metrics:" -ForegroundColor White
Write-Host "  Latency to Baby NAS: $($results.Tests.Latency["Baby NAS"].AvgLatency) ms" -ForegroundColor Gray

if ($results.Tests.SMBSpeed.Status -eq "OK") {
    Write-Host "  SMB Write Speed: $($results.Tests.SMBSpeed.WriteMBps) MB/s" -ForegroundColor Gray
    Write-Host "  SMB Read Speed: $($results.Tests.SMBSpeed.ReadMBps) MB/s" -ForegroundColor Gray
}

Write-Host ""

# Recommendations
Write-Host "Recommendations:" -ForegroundColor Yellow

if ($results.Tests.Latency["Baby NAS"].AvgLatency -gt 5) {
    Write-Host "  - High latency detected. Check network path and congestion." -ForegroundColor Gray
}

if (-not $results.Tests.SMBClientConfig.EnableLargeMtu) {
    Write-Host "  - Enable Large MTU: Set-SmbClientConfiguration -EnableLargeMtu `$true -Force" -ForegroundColor Gray
}

if (-not $results.Tests.SMBClientConfig.EnableMultiChannel) {
    Write-Host "  - Enable Multichannel: Set-SmbClientConfiguration -EnableMultiChannel `$true -Force" -ForegroundColor Gray
}

if ($results.Tests.SMBClientConfig.EnableBandwidthThrottling) {
    Write-Host "  - Disable throttling: Set-SmbClientConfiguration -EnableBandwidthThrottling `$false -Force" -ForegroundColor Gray
}

if ($results.Tests.SMBSpeed.Status -eq "OK" -and $results.Tests.SMBSpeed.WriteMBps -lt 50) {
    Write-Host "  - Consider running OPTIMIZE-SMB-CLIENT.ps1 for better performance" -ForegroundColor Gray
    Write-Host "  - Apply TrueNAS SMB tuning with APPLY-TRUENAS-SMB-TUNING.ps1" -ForegroundColor Gray
}

Write-Host ""

# Save results
$results | ConvertTo-Json -Depth 5 | Out-File $resultsFile -Encoding UTF8
Write-Host "Results saved to: $resultsFile" -ForegroundColor Cyan
Write-Host ""
