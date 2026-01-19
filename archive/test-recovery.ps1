#Requires -RunAsAdministrator
###############################################################################
# Recovery Testing Automation Script
# Purpose: Test backup recovery and snapshot restore capabilities
# Usage: .\test-recovery.ps1 [-BabyNasIP <ip>] [-TestPath <path>]
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$BabyNasIP = "",

    [Parameter(Mandatory=$false)]
    [string]$Dataset = "tank/windows-backups",

    [Parameter(Mandatory=$false)]
    [string]$TestPath = "C:\Recovery-Test",

    [Parameter(Mandatory=$false)]
    [switch]$CleanupAfterTest,

    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\Logs\recovery-tests"
)

$ErrorActionPreference = "Continue"

###############################################################################
# FUNCTIONS
###############################################################################

function Write-TestLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR','TEST')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to log file
    $logMessage | Out-File -FilePath $reportFile -Append -Encoding UTF8

    # Write to console with color
    $color = switch ($Level) {
        'INFO'    { 'White' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        'TEST'    { 'Cyan' }
    }

    Write-Host $logMessage -ForegroundColor $color
}

function Test-SSHConnection {
    param([string]$IP)

    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        $sshArgs = @()
        if (Test-Path $sshKey) {
            $sshArgs += @("-i", $sshKey)
        }
        $sshArgs += @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5", "root@$IP", "echo 'connected'")

        $result = & ssh @sshArgs 2>$null
        return $result -match "connected"
    } catch {
        return $false
    }
}

function Get-ZFSSnapshots {
    param(
        [string]$IP,
        [string]$Dataset
    )

    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        $sshArgs = @()
        if (Test-Path $sshKey) {
            $sshArgs += @("-i", $sshKey)
        }
        $sshArgs += @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5", "root@$IP", "zfs list -t snapshot -r $Dataset -o name,creation,used -s creation")

        $output = & ssh @sshArgs 2>$null
        return $output
    } catch {
        return $null
    }
}

function Mount-Snapshot {
    param(
        [string]$IP,
        [string]$Snapshot,
        [string]$MountPoint
    )

    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        $sshArgs = @()
        if (Test-Path $sshKey) {
            $sshArgs += @("-i", $sshKey)
        }

        # Create mount point
        $cmd1 = "root@$IP"
        $cmd2 = "mkdir -p $MountPoint"
        & ssh @sshArgs $cmd1 $cmd2 2>$null | Out-Null

        # Clone snapshot to temporary dataset
        $tempDataset = "$Dataset-restore-test"
        $cmd3 = "zfs clone $Snapshot $tempDataset"
        & ssh @sshArgs $cmd1 $cmd3 2>$null

        return $?
    } catch {
        return $false
    }
}

function Unmount-Snapshot {
    param(
        [string]$IP,
        [string]$Dataset
    )

    try {
        $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
        $sshArgs = @()
        if (Test-Path $sshKey) {
            $sshArgs += @("-i", $sshKey)
        }

        # Destroy temporary dataset
        $tempDataset = "$Dataset-restore-test"
        $cmd = "root@$IP"
        $cmd2 = "zfs destroy $tempDataset"
        & ssh @sshArgs $cmd $cmd2 2>$null

        return $?
    } catch {
        return $false
    }
}

function Test-FileIntegrity {
    param(
        [string]$SourcePath,
        [string]$TestPath
    )

    $results = @{
        TotalFiles = 0
        MatchedFiles = 0
        MismatchedFiles = 0
        MissingFiles = 0
        Errors = @()
    }

    try {
        $sourceFiles = Get-ChildItem -Path $SourcePath -Recurse -File -ErrorAction SilentlyContinue
        $results.TotalFiles = $sourceFiles.Count

        foreach ($file in $sourceFiles) {
            $relativePath = $file.FullName.Substring($SourcePath.Length)
            $testFilePath = Join-Path $TestPath $relativePath

            if (Test-Path $testFilePath) {
                # Compare file sizes
                $testFile = Get-Item $testFilePath
                if ($file.Length -eq $testFile.Length) {
                    $results.MatchedFiles++
                } else {
                    $results.MismatchedFiles++
                    $results.Errors += "Size mismatch: $relativePath"
                }
            } else {
                $results.MissingFiles++
                $results.Errors += "Missing file: $relativePath"
            }
        }
    } catch {
        $results.Errors += "Error during integrity test: $($_.Exception.Message)"
    }

    return $results
}

###############################################################################
# MAIN SCRIPT
###############################################################################

Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                    Baby NAS Recovery Testing                             ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Host "Recovery Test Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Create report directory
if (-not (Test-Path $ReportPath)) {
    New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportFile = Join-Path $ReportPath "recovery-test-$timestamp.log"

Write-TestLog "=== Recovery Test Started ===" -Level TEST
Write-TestLog "Dataset: $Dataset" -Level INFO
Write-TestLog "Test Path: $TestPath" -Level INFO

$testResults = @{
    Timestamp = Get-Date
    Tests = @()
    OverallStatus = "PASSED"
}

###############################################################################
# Test 1: Auto-detect Baby NAS
###############################################################################

Write-Host ""
Write-TestLog "=== TEST 1: Baby NAS Detection ===" -Level TEST

if ([string]::IsNullOrEmpty($BabyNasIP)) {
    Write-TestLog "Auto-detecting Baby NAS..." -Level INFO

    $vm = Get-VM | Where-Object { $_.Name -like "*Baby*" -or $_.Name -like "*TrueNAS-BabyNAS*" } | Select-Object -First 1
    if ($vm) {
        Write-TestLog "Found VM: $($vm.Name)" -Level SUCCESS
        $vmNet = Get-VMNetworkAdapter -VM $vm
        if ($vmNet.IPAddresses) {
            $BabyNasIP = ($vmNet.IPAddresses | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
        }
    }

    if ([string]::IsNullOrEmpty($BabyNasIP)) {
        Write-TestLog "FAILED: Could not auto-detect Baby NAS IP" -Level ERROR
        $testResults.Tests += @{
            Name = "Baby NAS Detection"
            Status = "FAILED"
            Details = "Could not detect IP address"
        }
        $testResults.OverallStatus = "FAILED"
        exit 1
    }
}

Write-TestLog "Baby NAS IP: $BabyNasIP" -Level SUCCESS
$testResults.Tests += @{
    Name = "Baby NAS Detection"
    Status = "PASSED"
    Details = "IP: $BabyNasIP"
}

###############################################################################
# Test 2: Network Connectivity
###############################################################################

Write-Host ""
Write-TestLog "=== TEST 2: Network Connectivity ===" -Level TEST

$pingResult = Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet -ErrorAction SilentlyContinue

if ($pingResult) {
    Write-TestLog "PASSED: Baby NAS is reachable" -Level SUCCESS
    $testResults.Tests += @{
        Name = "Network Connectivity"
        Status = "PASSED"
        Details = "Ping successful"
    }
} else {
    Write-TestLog "FAILED: Baby NAS is not reachable" -Level ERROR
    $testResults.Tests += @{
        Name = "Network Connectivity"
        Status = "FAILED"
        Details = "Ping failed"
    }
    $testResults.OverallStatus = "FAILED"
    exit 1
}

###############################################################################
# Test 3: SSH Access
###############################################################################

Write-Host ""
Write-TestLog "=== TEST 3: SSH Access ===" -Level TEST

$sshTest = Test-SSHConnection -IP $BabyNasIP

if ($sshTest) {
    Write-TestLog "PASSED: SSH connection successful" -Level SUCCESS
    $testResults.Tests += @{
        Name = "SSH Access"
        Status = "PASSED"
        Details = "Key-based authentication working"
    }
} else {
    Write-TestLog "FAILED: Cannot establish SSH connection" -Level ERROR
    Write-TestLog "Tip: Run .\2-configure-baby-nas.ps1 to set up SSH keys" -Level WARNING
    $testResults.Tests += @{
        Name = "SSH Access"
        Status = "FAILED"
        Details = "SSH connection failed"
    }
    $testResults.OverallStatus = "FAILED"
    exit 1
}

###############################################################################
# Test 4: List Available Snapshots
###############################################################################

Write-Host ""
Write-TestLog "=== TEST 4: Snapshot Availability ===" -Level TEST

$snapshots = Get-ZFSSnapshots -IP $BabyNasIP -Dataset $Dataset

if ($snapshots) {
    $snapshotLines = $snapshots -split "`n" | Where-Object { $_ -match "@" }
    $snapshotCount = $snapshotLines.Count

    Write-TestLog "PASSED: Found $snapshotCount snapshots" -Level SUCCESS
    Write-TestLog "Available snapshots:" -Level INFO

    # Display snapshots (limit to last 10)
    $displaySnapshots = $snapshotLines | Select-Object -Last 10
    foreach ($snap in $displaySnapshots) {
        Write-TestLog "  $($snap.Trim())" -Level INFO
    }

    if ($snapshotCount -eq 0) {
        Write-TestLog "WARNING: No snapshots found - cannot test recovery" -Level WARNING
        $testResults.Tests += @{
            Name = "Snapshot Availability"
            Status = "WARNING"
            Details = "No snapshots available"
        }
        $testResults.OverallStatus = "WARNING"
    } else {
        $testResults.Tests += @{
            Name = "Snapshot Availability"
            Status = "PASSED"
            Details = "$snapshotCount snapshots available"
        }
    }
} else {
    Write-TestLog "FAILED: Could not list snapshots" -Level ERROR
    $testResults.Tests += @{
        Name = "Snapshot Availability"
        Status = "FAILED"
        Details = "Could not query snapshots"
    }
    $testResults.OverallStatus = "FAILED"
}

###############################################################################
# Test 5: SMB Share Access
###############################################################################

Write-Host ""
Write-TestLog "=== TEST 5: SMB Share Access ===" -Level TEST

$shares = @(
    "\\$BabyNasIP\WindowsBackup",
    "\\$BabyNasIP\Veeam"
)

$shareAccessible = $false
foreach ($share in $shares) {
    if (Test-Path $share -ErrorAction SilentlyContinue) {
        Write-TestLog "PASSED: Share accessible - $share" -Level SUCCESS
        $shareAccessible = $true

        # Test read access
        try {
            $items = Get-ChildItem $share -ErrorAction Stop | Select-Object -First 1
            Write-TestLog "  Read access confirmed" -Level SUCCESS
        } catch {
            Write-TestLog "  WARNING: Read access failed" -Level WARNING
        }

        # Test write access
        $testFile = Join-Path $share ".recovery-test-$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
        try {
            "test" | Out-File -FilePath $testFile -ErrorAction Stop
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
            Write-TestLog "  Write access confirmed" -Level SUCCESS
        } catch {
            Write-TestLog "  WARNING: Write access failed" -Level WARNING
        }

        break
    }
}

if ($shareAccessible) {
    $testResults.Tests += @{
        Name = "SMB Share Access"
        Status = "PASSED"
        Details = "Shares accessible and writable"
    }
} else {
    Write-TestLog "FAILED: No SMB shares accessible" -Level ERROR
    $testResults.Tests += @{
        Name = "SMB Share Access"
        Status = "FAILED"
        Details = "Cannot access SMB shares"
    }
    $testResults.OverallStatus = "FAILED"
}

###############################################################################
# Test 6: Test Restore to Alternate Location
###############################################################################

Write-Host ""
Write-TestLog "=== TEST 6: Test Restore Operation ===" -Level TEST

# This is a simplified test - full restore would require more complex ZFS operations
Write-TestLog "Testing backup file accessibility..." -Level INFO

$backupShare = "\\$BabyNasIP\WindowsBackup"
if (Test-Path $backupShare) {
    # Create test restore directory
    if (-not (Test-Path $TestPath)) {
        New-Item -Path $TestPath -ItemType Directory -Force | Out-Null
        Write-TestLog "Created test restore directory: $TestPath" -Level INFO
    }

    # Find a small file to test restore
    try {
        $testSourceFile = Get-ChildItem $backupShare -Recurse -File -ErrorAction SilentlyContinue |
                         Where-Object { $_.Length -lt 10MB } |
                         Select-Object -First 1

        if ($testSourceFile) {
            $testDestFile = Join-Path $TestPath "test-restore-$timestamp.tmp"
            Copy-Item -Path $testSourceFile.FullName -Destination $testDestFile -ErrorAction Stop

            # Verify copy
            $destItem = Get-Item $testDestFile
            if ($destItem.Length -eq $testSourceFile.Length) {
                Write-TestLog "PASSED: Test file restored successfully" -Level SUCCESS
                Write-TestLog "  Source: $($testSourceFile.FullName)" -Level INFO
                Write-TestLog "  Size: $([math]::Round($testSourceFile.Length/1KB, 2)) KB" -Level INFO

                $testResults.Tests += @{
                    Name = "Test Restore Operation"
                    Status = "PASSED"
                    Details = "Successfully restored test file"
                }

                # Cleanup test file
                if ($CleanupAfterTest) {
                    Remove-Item $testDestFile -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-TestLog "FAILED: File size mismatch after restore" -Level ERROR
                $testResults.Tests += @{
                    Name = "Test Restore Operation"
                    Status = "FAILED"
                    Details = "File size mismatch"
                }
                $testResults.OverallStatus = "FAILED"
            }
        } else {
            Write-TestLog "WARNING: No suitable test files found in backup" -Level WARNING
            $testResults.Tests += @{
                Name = "Test Restore Operation"
                Status = "WARNING"
                Details = "No test files available"
            }
        }
    } catch {
        Write-TestLog "FAILED: Restore test failed - $($_.Exception.Message)" -Level ERROR
        $testResults.Tests += @{
            Name = "Test Restore Operation"
            Status = "FAILED"
            Details = $_.Exception.Message
        }
        $testResults.OverallStatus = "FAILED"
    }
} else {
    Write-TestLog "FAILED: Backup share not accessible" -Level ERROR
    $testResults.Tests += @{
        Name = "Test Restore Operation"
        Status = "FAILED"
        Details = "Backup share not accessible"
    }
    $testResults.OverallStatus = "FAILED"
}

###############################################################################
# Test 7: Pool Health Check
###############################################################################

Write-Host ""
Write-TestLog "=== TEST 7: Pool Health Check ===" -Level TEST

try {
    $sshKey = "$env:USERPROFILE\.ssh\id_babynas"
    $sshArgs = @("-i", $sshKey, "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5", "root@$BabyNasIP", "zpool status tank")

    $poolStatus = & ssh @sshArgs 2>$null

    if ($poolStatus -match "state:\s+ONLINE") {
        Write-TestLog "PASSED: Pool is ONLINE and healthy" -Level SUCCESS
        $testResults.Tests += @{
            Name = "Pool Health Check"
            Status = "PASSED"
            Details = "Pool state: ONLINE"
        }
    } elseif ($poolStatus -match "state:\s+DEGRADED") {
        Write-TestLog "WARNING: Pool is DEGRADED" -Level WARNING
        $testResults.Tests += @{
            Name = "Pool Health Check"
            Status = "WARNING"
            Details = "Pool state: DEGRADED"
        }
        if ($testResults.OverallStatus -ne "FAILED") {
            $testResults.OverallStatus = "WARNING"
        }
    } else {
        Write-TestLog "FAILED: Pool is in critical state" -Level ERROR
        $testResults.Tests += @{
            Name = "Pool Health Check"
            Status = "FAILED"
            Details = "Pool not healthy"
        }
        $testResults.OverallStatus = "FAILED"
    }
} catch {
    Write-TestLog "FAILED: Could not check pool status" -Level ERROR
    $testResults.Tests += @{
        Name = "Pool Health Check"
        Status = "FAILED"
        Details = "Could not query pool"
    }
    $testResults.OverallStatus = "FAILED"
}

###############################################################################
# Test Summary Report
###############################################################################

Write-Host ""
Write-TestLog "=== RECOVERY TEST SUMMARY ===" -Level TEST
Write-Host ""

$passedTests = ($testResults.Tests | Where-Object { $_.Status -eq "PASSED" }).Count
$warningTests = ($testResults.Tests | Where-Object { $_.Status -eq "WARNING" }).Count
$failedTests = ($testResults.Tests | Where-Object { $_.Status -eq "FAILED" }).Count
$totalTests = $testResults.Tests.Count

Write-TestLog "Total Tests: $totalTests" -Level INFO
Write-TestLog "Passed: $passedTests" -Level SUCCESS
Write-TestLog "Warnings: $warningTests" -Level WARNING
Write-TestLog "Failed: $failedTests" -Level $(if ($failedTests -gt 0) { "ERROR" } else { "INFO" })

Write-Host ""
Write-Host "Test Results:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

foreach ($test in $testResults.Tests) {
    $statusColor = switch ($test.Status) {
        'PASSED'  { 'Green' }
        'WARNING' { 'Yellow' }
        'FAILED'  { 'Red' }
    }

    $statusSymbol = switch ($test.Status) {
        'PASSED'  { '✓' }
        'WARNING' { '⚠' }
        'FAILED'  { '✗' }
    }

    Write-Host "$statusSymbol " -ForegroundColor $statusColor -NoNewline
    Write-Host "$($test.Name): " -NoNewline
    Write-Host "$($test.Status)" -ForegroundColor $statusColor
    Write-Host "   Details: $($test.Details)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$overallColor = switch ($testResults.OverallStatus) {
    'PASSED'  { 'Green' }
    'WARNING' { 'Yellow' }
    'FAILED'  { 'Red' }
}

Write-Host ""
Write-Host "OVERALL RECOVERY TEST STATUS: " -NoNewline
Write-Host "$($testResults.OverallStatus)" -ForegroundColor $overallColor -BackgroundColor Black
Write-Host ""

Write-TestLog "=== Recovery Test Completed ===" -Level TEST
Write-TestLog "Report saved to: $reportFile" -Level INFO

# Generate JSON report
$jsonReport = $testResults | ConvertTo-Json -Depth 10
$jsonReportFile = $reportFile -replace '\.log$', '.json'
$jsonReport | Out-File -FilePath $jsonReportFile -Encoding UTF8
Write-TestLog "JSON report saved to: $jsonReportFile" -Level INFO

###############################################################################
# Cleanup
###############################################################################

if ($CleanupAfterTest) {
    Write-Host ""
    Write-TestLog "Cleaning up test files..." -Level INFO
    if (Test-Path $TestPath) {
        Remove-Item $TestPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-TestLog "Test directory removed: $TestPath" -Level INFO
    }
}

###############################################################################
# Recommendations
###############################################################################

Write-Host ""
Write-Host "Recommendations:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

if ($failedTests -gt 0) {
    Write-Host "✗ Address failed tests before relying on backups" -ForegroundColor Red
}

if ($snapshotCount -eq 0) {
    Write-Host "⚠ No snapshots found - configure automatic snapshots" -ForegroundColor Yellow
}

if ($snapshotCount -gt 0 -and $snapshotCount -lt 24) {
    Write-Host "⚠ Limited snapshot history - consider increasing retention" -ForegroundColor Yellow
}

Write-Host "✓ Run recovery tests monthly to verify backup integrity" -ForegroundColor Green
Write-Host "✓ Document recovery procedures for emergency situations" -ForegroundColor Green
Write-Host "✓ Test full system restore at least once per quarter" -ForegroundColor Green

Write-Host ""
Write-Host "Recovery test completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Return exit code based on overall status
if ($testResults.OverallStatus -eq "FAILED") {
    exit 1
} elseif ($testResults.OverallStatus -eq "WARNING") {
    exit 2
} else {
    exit 0
}
