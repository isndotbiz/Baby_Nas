# Script 4: Backup Monitoring and Health Check
# Purpose: Monitor backup health and alert on issues
# Run as: User or Administrator
# Usage: .\4-monitor-backups.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$VeeamBackupPath = "X:\VeeamBackups",

    [Parameter(Mandatory=$false)]
    [string]$WSLBackupPath = "X:\WSLBackups",

    [Parameter(Mandatory=$false)]
    [string]$TrueNASIP = "10.0.0.89",

    [Parameter(Mandatory=$false)]
    [switch]$SendEmail,

    [Parameter(Mandatory=$false)]
    [string]$EmailTo = "admin@example.com"
)

$results = @()
$errors = @()
$warnings = @()

Write-Host "`n=== Backup Health Check ===" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

# Check 1: Veeam Local Backup
Write-Host "Checking Veeam local backups..." -ForegroundColor Yellow

if (Test-Path $VeeamBackupPath) {
    $latestBackup = Get-ChildItem $VeeamBackupPath -Recurse -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestBackup) {
        $hoursSinceBackup = ((Get-Date) - $latestBackup.LastWriteTime).TotalHours
        $daysOld = [math]::Round($hoursSinceBackup / 24, 1)

        $status = if ($hoursSinceBackup -lt 28) { "OK" }
                  elseif ($hoursSinceBackup -lt 48) { "WARNING" }
                  else { "ERROR" }

        $results += [PSCustomObject]@{
            Check = "Veeam Local Backup"
            Status = $status
            Details = "Last backup: $([math]::Round($hoursSinceBackup, 1)) hours ago ($daysOld days)"
            LastRun = $latestBackup.LastWriteTime
        }

        if ($status -eq "ERROR") {
            $errors += "Veeam backup is $([math]::Round($hoursSinceBackup, 1)) hours old (>48h)"
        } elseif ($status -eq "WARNING") {
            $warnings += "Veeam backup is $([math]::Round($hoursSinceBackup, 1)) hours old (>28h)"
        }

        Write-Host "  Last backup: $($latestBackup.LastWriteTime)" -ForegroundColor $(if($status -eq "OK"){"Green"}else{"Red"})
    } else {
        $results += [PSCustomObject]@{
            Check = "Veeam Local Backup"
            Status = "ERROR"
            Details = "No backup files found"
            LastRun = "Never"
        }
        $errors += "No Veeam backup files found in $VeeamBackupPath"
        Write-Host "  ERROR: No backup files found" -ForegroundColor Red
    }
} else {
    $results += [PSCustomObject]@{
        Check = "Veeam Local Backup"
        Status = "NOT CONFIGURED"
        Details = "Backup path does not exist: $VeeamBackupPath"
        LastRun = "N/A"
    }
    Write-Host "  Path not found: $VeeamBackupPath" -ForegroundColor Gray
}

# Check 2: WSL Backups
Write-Host "`nChecking WSL backups..." -ForegroundColor Yellow

if (Test-Path $WSLBackupPath) {
    $latestWSLBackup = Get-ChildItem $WSLBackupPath -Filter "*.tar" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestWSLBackup) {
        $daysSinceBackup = ((Get-Date) - $latestWSLBackup.LastWriteTime).TotalDays

        $status = if ($daysSinceBackup -lt 8) { "OK" }
                  elseif ($daysSinceBackup -lt 14) { "WARNING" }
                  else { "ERROR" }

        $results += [PSCustomObject]@{
            Check = "WSL Backup"
            Status = $status
            Details = "Last backup: $([math]::Round($daysSinceBackup, 1)) days ago"
            LastRun = $latestWSLBackup.LastWriteTime
        }

        if ($status -eq "ERROR") {
            $errors += "WSL backup is $([math]::Round($daysSinceBackup, 1)) days old (>14d)"
        } elseif ($status -eq "WARNING") {
            $warnings += "WSL backup is $([math]::Round($daysSinceBackup, 1)) days old (>7d)"
        }

        Write-Host "  Last backup: $($latestWSLBackup.LastWriteTime)" -ForegroundColor $(if($status -eq "OK"){"Green"}else{"Yellow"})
    } else {
        $results += [PSCustomObject]@{
            Check = "WSL Backup"
            Status = "WARNING"
            Details = "No WSL backup files found"
            LastRun = "Never"
        }
        Write-Host "  No WSL backups found" -ForegroundColor Gray
    }
} else {
    Write-Host "  WSL backup path not found (may not be configured)" -ForegroundColor Gray
}

# Check 3: Backup Drive Space
Write-Host "`nChecking backup drive space..." -ForegroundColor Yellow

$backupDrive = Get-Volume | Where-Object {
    $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\VeeamBackups")
} | Select-Object -First 1

if ($backupDrive) {
    $percentFree = ($backupDrive.SizeRemaining / $backupDrive.Size) * 100
    $freeGB = [math]::Round($backupDrive.SizeRemaining / 1GB, 2)
    $totalGB = [math]::Round($backupDrive.Size / 1GB, 2)

    $status = if ($percentFree -gt 20) { "OK" }
              elseif ($percentFree -gt 10) { "WARNING" }
              else { "CRITICAL" }

    $results += [PSCustomObject]@{
        Check = "Backup Drive Space"
        Status = $status
        Details = "$([math]::Round($percentFree, 1))% free ($freeGB GB of $totalGB GB)"
        LastRun = "N/A"
    }

    if ($status -eq "CRITICAL") {
        $errors += "Backup drive space critical: only $([math]::Round($percentFree, 1))% free"
    } elseif ($status -eq "WARNING") {
        $warnings += "Backup drive space low: $([math]::Round($percentFree, 1))% free"
    }

    Write-Host "  Free space: $freeGB GB ($([math]::Round($percentFree, 1))%)" -ForegroundColor $(if($status -eq "OK"){"Green"}elseif($status -eq "WARNING"){"Yellow"}else{"Red"})
} else {
    Write-Host "  Backup drive not found" -ForegroundColor Gray
}

# Check 4: TrueNAS Connectivity
Write-Host "`nChecking TrueNAS connectivity..." -ForegroundColor Yellow

$trueNASPing = Test-Connection -ComputerName $TrueNASIP -Count 2 -Quiet -ErrorAction SilentlyContinue

$results += [PSCustomObject]@{
    Check = "TrueNAS Network"
    Status = if ($trueNASPing) { "OK" } else { "ERROR" }
    Details = if ($trueNASPing) { "TrueNAS reachable at $TrueNASIP" } else { "Cannot reach TrueNAS at $TrueNASIP" }
    LastRun = "N/A"
}

if (-not $trueNASPing) {
    $errors += "Cannot reach TrueNAS at $TrueNASIP"
    Write-Host "  ERROR: Cannot reach $TrueNASIP" -ForegroundColor Red
} else {
    Write-Host "  TrueNAS is reachable" -ForegroundColor Green
}

# Check 5: Scheduled Tasks
Write-Host "`nChecking scheduled tasks..." -ForegroundColor Yellow

$backupTasks = Get-ScheduledTask | Where-Object {
    $_.TaskName -like "*Backup*" -or
    $_.TaskName -like "*WSL*" -or
    $_.TaskName -like "*Veeam*"
}

if ($backupTasks) {
    $enabledTasks = ($backupTasks | Where-Object { $_.State -eq 'Ready' }).Count
    $disabledTasks = ($backupTasks | Where-Object { $_.State -eq 'Disabled' }).Count

    $results += [PSCustomObject]@{
        Check = "Scheduled Tasks"
        Status = if ($disabledTasks -eq 0) { "OK" } else { "WARNING" }
        Details = "$enabledTasks enabled, $disabledTasks disabled"
        LastRun = "N/A"
    }

    if ($disabledTasks -gt 0) {
        $warnings += "$disabledTasks backup-related scheduled tasks are disabled"
    }

    Write-Host "  Enabled: $enabledTasks, Disabled: $disabledTasks" -ForegroundColor $(if($disabledTasks -eq 0){"Green"}else{"Yellow"})
} else {
    Write-Host "  No backup-related scheduled tasks found" -ForegroundColor Gray
}

# Display Results Summary
Write-Host "`n=== Health Check Summary ===" -ForegroundColor Cyan
$results | Format-Table -Property Check, Status, Details -AutoSize

# Display Errors
if ($errors.Count -gt 0) {
    Write-Host "`n=== ERRORS DETECTED ===" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
}

# Display Warnings
if ($warnings.Count -gt 0) {
    Write-Host "`n=== WARNINGS ===" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  - $warning" -ForegroundColor Yellow
    }
}

# Overall Status
$overallStatus = if ($errors.Count -gt 0) { "CRITICAL" }
                 elseif ($warnings.Count -gt 0) { "WARNING" }
                 else { "HEALTHY" }

Write-Host "`n=== Overall Status: $overallStatus ===" -ForegroundColor $(
    if($overallStatus -eq "HEALTHY"){"Green"}
    elseif($overallStatus -eq "WARNING"){"Yellow"}
    else{"Red"}
)

# Export to log file
$logFile = "C:\Logs\backup-health-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

$results | Export-Csv -Path $logFile -NoTypeInformation
Write-Host "`nHealth check log saved to: $logFile" -ForegroundColor Gray

# Email alert (if configured)
if ($SendEmail -and ($errors.Count -gt 0 -or $warnings.Count -gt 0)) {
    Write-Host "`nSending email alert to: $EmailTo" -ForegroundColor Yellow

    $emailBody = @"
Backup Health Check Alert
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Status: $overallStatus

ERRORS ($($errors.Count)):
$($errors | ForEach-Object { "- $_" } | Out-String)

WARNINGS ($($warnings.Count)):
$($warnings | ForEach-Object { "- $_" } | Out-String)

Full Report:
$($results | Format-Table -AutoSize | Out-String)
"@

    try {
        # NOTE: Configure SMTP settings before using
        # Send-MailMessage -To $EmailTo `
        #     -Subject "Backup Alert: $overallStatus" `
        #     -Body $emailBody `
        #     -SmtpServer "smtp.example.com" `
        #     -From "backups@example.com"

        Write-Host "  Email functionality not configured. Configure SMTP settings in script." -ForegroundColor Gray
    } catch {
        Write-Host "  Failed to send email: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n"

# Exit with status code
if ($errors.Count -gt 0) {
    exit 1
} elseif ($warnings.Count -gt 0) {
    exit 2
} else {
    exit 0
}
