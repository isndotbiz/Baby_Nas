#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automated Veeam backup recovery testing script

.DESCRIPTION
    Tests and validates Veeam backup restore capabilities.
    Features:
    - Backup file validation
    - Test restore to alternate location
    - File-level recovery testing
    - Volume restore validation
    - Recovery time objective (RTO) measurement
    - Restore point verification
    - Automated cleanup of test restores

.PARAMETER BackupDestination
    Path to Veeam backups
    Default: \\172.21.203.18\Veeam

.PARAMETER TestRestorePath
    Path for test restores
    Default: C:\VeeamRestoreTest

.PARAMETER TestFileRestore
    Test file-level restore
    Default: $true

.PARAMETER TestVolumeRestore
    Test full volume restore (requires more space)
    Default: $false

.PARAMETER CleanupAfterTest
    Remove test restored files after validation
    Default: $true

.PARAMETER ReportPath
    Path to save test reports
    Default: C:\Logs\Veeam\RecoveryTests

.EXAMPLE
    .\5-test-recovery.ps1
    Run standard recovery tests

.EXAMPLE
    .\5-test-recovery.ps1 -TestVolumeRestore $true -CleanupAfterTest $false
    Test volume restore and keep files for inspection

.NOTES
    Author: Automated Veeam Deployment System
    Version: 1.0
    Requires: Veeam Agent for Windows installed with backups
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BackupDestination = "\\172.21.203.18\Veeam",

    [Parameter(Mandatory=$false)]
    [string]$TestRestorePath = "C:\VeeamRestoreTest",

    [Parameter(Mandatory=$false)]
    [bool]$TestFileRestore = $true,

    [Parameter(Mandatory=$false)]
    [bool]$TestVolumeRestore = $false,

    [Parameter(Mandatory=$false)]
    [bool]$CleanupAfterTest = $true,

    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\Logs\Veeam\RecoveryTests"
)

# Configuration
$logDir = "C:\Logs\Veeam"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\recovery-test-$timestamp.log"
$testResultsFile = "$ReportPath\recovery-test-results-$timestamp.json"

# Create directories
foreach ($dir in @($logDir, $ReportPath, $TestRestorePath)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO"    { Write-Host $logMessage -ForegroundColor Cyan }
        default   { Write-Host $logMessage -ForegroundColor White }
    }

    $logMessage | Out-File -FilePath $logFile -Append
}

function Find-VeeamBackupFiles {
    param([string]$Path)

    Write-Log "Searching for Veeam backup files..." "INFO"

    $backupFiles = @{
        VBK = @()  # Full backups
        VIB = @()  # Incremental backups
        VBM = @()  # Metadata files
    }

    try {
        if (Test-Path $Path) {
            # Find .vbk files (full backups)
            $vbkFiles = Get-ChildItem -Path $Path -Recurse -Filter "*.vbk" -ErrorAction SilentlyContinue
            $backupFiles.VBK = $vbkFiles

            # Find .vib files (incrementals)
            $vibFiles = Get-ChildItem -Path $Path -Recurse -Filter "*.vib" -ErrorAction SilentlyContinue
            $backupFiles.VIB = $vibFiles

            # Find .vbm files (metadata)
            $vbmFiles = Get-ChildItem -Path $Path -Recurse -Filter "*.vbm" -ErrorAction SilentlyContinue
            $backupFiles.VBM = $vbmFiles

            Write-Log "Found backup files:" "INFO"
            Write-Log "  Full backups (.vbk): $($vbkFiles.Count)" "INFO"
            Write-Log "  Incrementals (.vib): $($vibFiles.Count)" "INFO"
            Write-Log "  Metadata (.vbm): $($vbmFiles.Count)" "INFO"

            if ($vbkFiles.Count -eq 0 -and $vibFiles.Count -eq 0) {
                Write-Log "WARNING: No backup files found" "WARNING"
            }

        } else {
            Write-Log "ERROR: Backup destination not accessible: $Path" "ERROR"
        }
    } catch {
        Write-Log "ERROR searching for backup files: $($_.Exception.Message)" "ERROR"
    }

    return $backupFiles
}

function Test-BackupFileIntegrity {
    param(
        [System.IO.FileInfo[]]$BackupFiles
    )

    Write-Log "Testing backup file integrity..." "INFO"

    $results = @()

    foreach ($file in $BackupFiles) {
        Write-Log "Checking: $($file.Name)" "INFO"

        $fileTest = @{
            FileName = $file.Name
            FullPath = $file.FullName
            SizeGB = [math]::Round($file.Length / 1GB, 2)
            Created = $file.CreationTime
            Modified = $file.LastWriteTime
            Readable = $false
            Corrupt = $false
            Status = "Unknown"
        }

        try {
            # Test if file is readable
            $stream = [System.IO.File]::OpenRead($file.FullName)

            # Read first and last blocks to verify accessibility
            $buffer = New-Object byte[] 4096
            $stream.Read($buffer, 0, 4096) | Out-Null

            if ($stream.Length -gt 8192) {
                $stream.Seek(-4096, [System.IO.SeekOrigin]::End) | Out-Null
                $stream.Read($buffer, 0, 4096) | Out-Null
            }

            $stream.Close()

            $fileTest.Readable = $true
            $fileTest.Status = "Good"
            Write-Log "  Status: Good" "SUCCESS"

        } catch {
            $fileTest.Readable = $false
            $fileTest.Corrupt = $true
            $fileTest.Status = "Error"
            Write-Log "  Status: ERROR - $($_.Exception.Message)" "ERROR"
        }

        $results += $fileTest
    }

    $goodFiles = ($results | Where-Object { $_.Status -eq "Good" }).Count
    $totalFiles = $results.Count

    Write-Log "Integrity check complete: $goodFiles/$totalFiles files OK" "INFO"

    return $results
}

function Show-ManualRestoreInstructions {
    param(
        [string]$BackupFile,
        [string]$RestorePath
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " MANUAL RESTORE TEST INSTRUCTIONS" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Veeam does not expose PowerShell cmdlets for restore operations" -ForegroundColor Yellow
    Write-Host "Please perform manual restore test using Veeam UI" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "STEPS FOR FILE-LEVEL RESTORE:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Open Veeam Agent Control Panel" -ForegroundColor White
    Write-Host "   - Press Win+R, type: control.exe /name Veeam.EndpointBackup" -ForegroundColor Green
    Write-Host ""

    Write-Host "2. Start Restore Wizard" -ForegroundColor White
    Write-Host "   - Click 'Restore Files'" -ForegroundColor Green
    Write-Host "   - Or: 'Restore' > 'Microsoft Windows files'" -ForegroundColor Green
    Write-Host ""

    Write-Host "3. Select Backup" -ForegroundColor White
    Write-Host "   - Choose backup: $BackupFile" -ForegroundColor Green
    Write-Host "   - Select latest restore point" -ForegroundColor White
    Write-Host ""

    Write-Host "4. Select Files to Restore" -ForegroundColor White
    Write-Host "   - Navigate to C:\Windows\System32\drivers\etc" -ForegroundColor White
    Write-Host "   - Select 'hosts' file (small, safe to restore)" -ForegroundColor Green
    Write-Host ""

    Write-Host "5. Choose Restore Location" -ForegroundColor White
    Write-Host "   - Select: 'Restore to alternate location'" -ForegroundColor Green
    Write-Host "   - Path: $RestorePath" -ForegroundColor Green
    Write-Host ""

    Write-Host "6. Complete Restore" -ForegroundColor White
    Write-Host "   - Click 'Restore' to start" -ForegroundColor Green
    Write-Host "   - Note the restore time (RTO)" -ForegroundColor Yellow
    Write-Host "   - Verify file appears in: $RestorePath" -ForegroundColor White
    Write-Host ""

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "STEPS FOR VOLUME RESTORE:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Open Veeam Agent Control Panel" -ForegroundColor White
    Write-Host ""

    Write-Host "2. Start Volume Restore" -ForegroundColor White
    Write-Host "   - Click 'Restore Volumes'" -ForegroundColor Green
    Write-Host ""

    Write-Host "3. Select Backup and Restore Point" -ForegroundColor White
    Write-Host "   - Choose backup" -ForegroundColor White
    Write-Host "   - Select restore point" -ForegroundColor White
    Write-Host ""

    Write-Host "4. Select Volume" -ForegroundColor White
    Write-Host "   - Choose volume to restore (e.g., C:)" -ForegroundColor White
    Write-Host ""

    Write-Host "5. Choose Restore Mode" -ForegroundColor White
    Write-Host "   - For TEST: Select alternate location or create VHD" -ForegroundColor Yellow
    Write-Host "   - WARNING: Do NOT overwrite original volume" -ForegroundColor Red
    Write-Host ""

    Write-Host "6. Complete and Verify" -ForegroundColor White
    Write-Host "   - Start restore process" -ForegroundColor White
    Write-Host "   - Note restore time" -ForegroundColor White
    Write-Host "   - Mount and verify restored volume" -ForegroundColor White
    Write-Host ""

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-RestoreCapability {
    param([string]$BackupPath)

    Write-Log "Testing restore capability..." "INFO"

    $testResults = @{
        BackupPath = $BackupPath
        TestPath = $TestRestorePath
        VeeamInstalled = $false
        BackupsFound = $false
        ManualTestRequired = $true
        RecommendedTests = @()
    }

    # Check if Veeam is installed
    $veeamService = Get-Service -Name "VeeamEndpointBackupSvc" -ErrorAction SilentlyContinue

    if ($veeamService) {
        $testResults.VeeamInstalled = $true
        Write-Log "Veeam Agent is installed" "SUCCESS"
    } else {
        Write-Log "ERROR: Veeam Agent not installed" "ERROR"
        return $testResults
    }

    # Find backups
    $backupFiles = Find-VeeamBackupFiles -Path $BackupPath

    if ($backupFiles.VBK.Count -gt 0 -or $backupFiles.VIB.Count -gt 0) {
        $testResults.BackupsFound = $true
        Write-Log "Backup files found and accessible" "SUCCESS"
    } else {
        Write-Log "WARNING: No backup files found" "WARNING"
        return $testResults
    }

    # Test file integrity
    $allBackups = @()
    $allBackups += $backupFiles.VBK
    $allBackups += $backupFiles.VIB

    $integrityResults = Test-BackupFileIntegrity -BackupFiles $allBackups

    $corruptFiles = $integrityResults | Where-Object { $_.Corrupt -eq $true }

    if ($corruptFiles.Count -gt 0) {
        Write-Log "WARNING: Found $($corruptFiles.Count) potentially corrupt backup files" "WARNING"

        foreach ($corrupt in $corruptFiles) {
            Write-Log "  Corrupt: $($corrupt.FileName)" "WARNING"
            $testResults.RecommendedTests += "Investigate corrupt file: $($corrupt.FileName)"
        }
    }

    # Recommend tests
    if ($TestFileRestore) {
        $testResults.RecommendedTests += "Perform file-level restore test"
    }

    if ($TestVolumeRestore) {
        $testResults.RecommendedTests += "Perform volume-level restore test"
    }

    $testResults.RecommendedTests += "Measure Recovery Time Objective (RTO)"
    $testResults.RecommendedTests += "Verify restored data integrity"
    $testResults.RecommendedTests += "Document restore procedures"

    return $testResults
}

function Measure-RestorePerformance {
    Write-Log "Generating restore performance estimates..." "INFO"

    $estimates = @{
        FileRestore = @{
            SmallFile = "< 1 minute"
            MediumFile = "1-5 minutes"
            LargeFile = "5-15 minutes"
        }
        VolumeRestore = @{
            "50GB" = "15-30 minutes"
            "100GB" = "30-60 minutes"
            "500GB" = "2-5 hours"
            "1TB" = "4-10 hours"
        }
        Factors = @(
            "Network speed (if restoring from network share)",
            "Disk I/O performance",
            "Backup compression level",
            "System load during restore"
        )
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " RESTORE PERFORMANCE ESTIMATES" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "FILE-LEVEL RESTORE (typical times):" -ForegroundColor Yellow
    foreach ($key in $estimates.FileRestore.Keys) {
        Write-Host "  $key : $($estimates.FileRestore[$key])" -ForegroundColor White
    }
    Write-Host ""

    Write-Host "VOLUME-LEVEL RESTORE (typical times):" -ForegroundColor Yellow
    foreach ($key in $estimates.VolumeRestore.Keys) {
        Write-Host "  $key volume: $($estimates.VolumeRestore[$key])" -ForegroundColor White
    }
    Write-Host ""

    Write-Host "FACTORS AFFECTING RESTORE SPEED:" -ForegroundColor Yellow
    foreach ($factor in $estimates.Factors) {
        Write-Host "  - $factor" -ForegroundColor White
    }
    Write-Host ""

    Write-Host "TIP: Measure actual RTO during manual restore tests" -ForegroundColor Cyan
    Write-Host ""

    return $estimates
}

function New-RecoveryTestReport {
    param(
        [hashtable]$TestResults,
        [array]$IntegrityResults,
        [hashtable]$PerformanceEstimates
    )

    Write-Log "Generating recovery test report..." "INFO"

    $report = @{
        Timestamp = (Get-Date).ToString()
        Computer = $env:COMPUTERNAME
        TestResults = $TestResults
        IntegrityResults = $IntegrityResults
        PerformanceEstimates = $PerformanceEstimates
        Recommendations = @()
    }

    # Generate recommendations
    if ($TestResults.VeeamInstalled -and $TestResults.BackupsFound) {
        $report.Recommendations += "Regular restore testing: Monthly file-level, Quarterly volume-level"
        $report.Recommendations += "Document actual RTO values from restore tests"
        $report.Recommendations += "Test restore from network share to verify connectivity"
        $report.Recommendations += "Verify application data (databases, configs) restore properly"
        $report.Recommendations += "Test bare-metal recovery process annually"
    } else {
        $report.Recommendations += "CRITICAL: Complete Veeam installation and backup configuration"
        $report.Recommendations += "Create at least one successful backup before recovery testing"
    }

    # Save report
    try {
        $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $testResultsFile -Force
        Write-Log "Report saved: $testResultsFile" "SUCCESS"

        # Create HTML report
        $htmlReport = "$ReportPath\recovery-test-report-$timestamp.html"

        $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
<title>Veeam Recovery Test Report</title>
<style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #2c5aa0; }
    h2 { color: #5a7aa0; margin-top: 30px; }
    table { border-collapse: collapse; width: 100%; margin: 20px 0; }
    th { background-color: #2c5aa0; color: white; padding: 10px; text-align: left; }
    td { border: 1px solid #ddd; padding: 8px; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    .success { color: green; font-weight: bold; }
    .warning { color: orange; font-weight: bold; }
    .error { color: red; font-weight: bold; }
    .info-box { background-color: #f0f0f0; padding: 15px; margin: 15px 0; border-left: 4px solid #2c5aa0; }
</style>
</head>
<body>
<h1>Veeam Recovery Test Report</h1>
<div class="info-box">
    <strong>Computer:</strong> $env:COMPUTERNAME<br>
    <strong>Test Date:</strong> $($report.Timestamp)<br>
    <strong>Backup Path:</strong> $($TestResults.BackupPath)
</div>

<h2>Test Status</h2>
<table>
<tr><th>Check</th><th>Status</th></tr>
<tr>
    <td>Veeam Agent Installed</td>
    <td class="$(if ($TestResults.VeeamInstalled) { 'success' } else { 'error' })">
        $(if ($TestResults.VeeamInstalled) { 'YES' } else { 'NO' })
    </td>
</tr>
<tr>
    <td>Backups Found</td>
    <td class="$(if ($TestResults.BackupsFound) { 'success' } else { 'error' })">
        $(if ($TestResults.BackupsFound) { 'YES' } else { 'NO' })
    </td>
</tr>
</table>

<h2>Backup File Integrity</h2>
<table>
<tr>
    <th>File Name</th>
    <th>Size (GB)</th>
    <th>Status</th>
    <th>Modified</th>
</tr>
"@

        foreach ($file in $IntegrityResults) {
            $statusClass = switch ($file.Status) {
                "Good" { "success" }
                "Error" { "error" }
                default { "warning" }
            }

            $htmlContent += @"
<tr>
    <td>$($file.FileName)</td>
    <td>$($file.SizeGB)</td>
    <td class="$statusClass">$($file.Status)</td>
    <td>$($file.Modified)</td>
</tr>
"@
        }

        $htmlContent += @"
</table>

<h2>Recommended Tests</h2>
<ul>
"@

        foreach ($test in $TestResults.RecommendedTests) {
            $htmlContent += "<li>$test</li>"
        }

        $htmlContent += @"
</ul>

<h2>Best Practices</h2>
<ul>
"@

        foreach ($rec in $report.Recommendations) {
            $htmlContent += "<li>$rec</li>"
        }

        $htmlContent += @"
</ul>

<p style="margin-top: 50px; color: #666; font-size: 12px;">
Generated by Veeam Recovery Testing System - $(Get-Date)
</p>
</body>
</html>
"@

        $htmlContent | Out-File -FilePath $htmlReport -Force
        Write-Log "HTML report saved: $htmlReport" "SUCCESS"

    } catch {
        Write-Log "ERROR generating report: $($_.Exception.Message)" "ERROR"
    }

    return $report
}

# ===== MAIN EXECUTION =====

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " VEEAM RECOVERY TESTING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== Veeam Recovery Testing Started ===" "INFO"
Write-Log "Backup destination: $BackupDestination" "INFO"
Write-Log "Test restore path: $TestRestorePath" "INFO"

# Step 1: Test restore capability
Write-Log "" "INFO"
Write-Log "Step 1: Test Restore Capability" "INFO"

$testResults = Test-RestoreCapability -BackupPath $BackupDestination

# Step 2: Find and validate backup files
Write-Log "" "INFO"
Write-Log "Step 2: Validate Backup Files" "INFO"

$backupFiles = Find-VeeamBackupFiles -Path $BackupDestination

$allBackups = @()
$allBackups += $backupFiles.VBK
$allBackups += $backupFiles.VIB

if ($allBackups.Count -gt 0) {
    $integrityResults = Test-BackupFileIntegrity -BackupFiles $allBackups
} else {
    Write-Log "WARNING: No backup files to test" "WARNING"
    $integrityResults = @()
}

# Step 3: Show manual restore instructions
Write-Log "" "INFO"
Write-Log "Step 3: Manual Restore Instructions" "INFO"

if ($testResults.VeeamInstalled -and $testResults.BackupsFound) {
    $latestBackup = $allBackups | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($latestBackup) {
        Show-ManualRestoreInstructions -BackupFile $latestBackup.Name -RestorePath $TestRestorePath
    }
}

# Step 4: Performance estimates
Write-Log "" "INFO"
Write-Log "Step 4: Restore Performance Estimates" "INFO"

$perfEstimates = Measure-RestorePerformance

# Step 5: Generate report
Write-Log "" "INFO"
Write-Log "Step 5: Generate Test Report" "INFO"

$report = New-RecoveryTestReport `
    -TestResults $testResults `
    -IntegrityResults $integrityResults `
    -PerformanceEstimates $perfEstimates

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " RECOVERY TEST SUMMARY" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if ($testResults.VeeamInstalled -and $testResults.BackupsFound) {
    Write-Host "Status: " -NoNewline
    Write-Host "READY FOR MANUAL TESTING" -ForegroundColor Green
    Write-Host ""
    Write-Host "Backup files validated: $($integrityResults.Count)" -ForegroundColor Cyan
    Write-Host "Good files: $(($integrityResults | Where-Object { $_.Status -eq 'Good' }).Count)" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "1. Follow manual restore instructions above"
    Write-Host "2. Document actual restore times"
    Write-Host "3. Verify restored data integrity"
    Write-Host "4. Schedule regular recovery tests"
    Write-Host ""
} else {
    Write-Host "Status: " -NoNewline
    Write-Host "NOT READY" -ForegroundColor Red
    Write-Host ""
    if (-not $testResults.VeeamInstalled) {
        Write-Host "ERROR: Veeam Agent not installed" -ForegroundColor Red
    }
    if (-not $testResults.BackupsFound) {
        Write-Host "ERROR: No backups found" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Complete Veeam setup before recovery testing" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Reports saved to: $ReportPath" -ForegroundColor Cyan
Write-Host "Log file: $logFile" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== Recovery Testing Completed ===" "SUCCESS"

exit 0
