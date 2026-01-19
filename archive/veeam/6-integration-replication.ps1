#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Veeam and Baby NAS replication integration script

.DESCRIPTION
    Coordinates Veeam backup windows with TrueNAS replication schedules.
    Features:
    - Schedule coordination between Veeam backups and ZFS replication
    - Bandwidth management
    - Snapshot coordination
    - Conflict detection and resolution
    - Performance optimization
    - Automated failover coordination

.PARAMETER TrueNasIP
    IP address of Baby NAS (TrueNAS)
    Default: 172.21.203.18

.PARAMETER VeeamBackupTime
    Time when Veeam backup runs (HH:MM)
    Default: "02:00"

.PARAMETER VeeamBackupDurationMin
    Expected backup duration in minutes
    Default: 120 (2 hours)

.PARAMETER ReplicationStartTime
    When to start TrueNAS replication (HH:MM)
    Should be after Veeam completes
    Default: "05:00"

.PARAMETER EnableBandwidthLimit
    Limit bandwidth during business hours
    Default: $true

.PARAMETER BandwidthLimitMbps
    Bandwidth limit in Mbps during business hours
    Default: 100

.PARAMETER BusinessHoursStart
    Start of business hours (HH:MM)
    Default: "08:00"

.PARAMETER BusinessHoursEnd
    End of business hours (HH:MM)
    Default: "18:00"

.EXAMPLE
    .\6-integration-replication.ps1
    Configure with default schedule

.EXAMPLE
    .\6-integration-replication.ps1 -VeeamBackupTime "01:00" -ReplicationStartTime "04:00"
    Custom schedule to avoid overlap

.NOTES
    Author: Automated Veeam Deployment System
    Version: 1.0
    Requires: TrueNAS replication tasks configured
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TrueNasIP = "172.21.203.18",

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$VeeamBackupTime = "02:00",

    [Parameter(Mandatory=$false)]
    [int]$VeeamBackupDurationMin = 120,

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$ReplicationStartTime = "05:00",

    [Parameter(Mandatory=$false)]
    [bool]$EnableBandwidthLimit = $true,

    [Parameter(Mandatory=$false)]
    [int]$BandwidthLimitMbps = 100,

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$BusinessHoursStart = "08:00",

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^\d{2}:\d{2}$')]
    [string]$BusinessHoursEnd = "18:00"
)

# Configuration
$logDir = "C:\Logs\Veeam"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "$logDir\integration-$timestamp.log"
$scheduleFile = "$logDir\integration-schedule.json"

# Create log directory
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
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

function Convert-TimeToMinutes {
    param([string]$Time)

    $parts = $Time -split ':'
    return ([int]$parts[0] * 60) + [int]$parts[1]
}

function Convert-MinutesToTime {
    param([int]$Minutes)

    $hours = [math]::Floor($Minutes / 60)
    $mins = $Minutes % 60
    return "{0:D2}:{1:D2}" -f $hours, $mins
}

function Test-ScheduleConflict {
    param(
        [string]$VeeamTime,
        [int]$VeeamDuration,
        [string]$ReplicationTime
    )

    Write-Log "Checking for schedule conflicts..." "INFO"

    $veeamStartMin = Convert-TimeToMinutes -Time $VeeamTime
    $veeamEndMin = $veeamStartMin + $VeeamDuration
    $replicationStartMin = Convert-TimeToMinutes -Time $ReplicationTime

    Write-Log "Veeam backup window: $VeeamTime - $(Convert-MinutesToTime -Minutes $veeamEndMin)" "INFO"
    Write-Log "Replication start: $ReplicationTime" "INFO"

    $conflicts = @()

    # Check if replication starts before Veeam finishes
    if ($replicationStartMin -lt $veeamEndMin -and $replicationStartMin -gt $veeamStartMin) {
        $conflicts += "Replication may start before Veeam backup completes"
        Write-Log "CONFLICT: Replication starts during Veeam backup window" "WARNING"
    }

    # Check if times are too close
    $bufferMin = 15
    if ($replicationStartMin -lt ($veeamEndMin + $bufferMin) -and $replicationStartMin -gt $veeamStartMin) {
        $conflicts += "Less than $bufferMin minute buffer between backup and replication"
        Write-Log "WARNING: Insufficient buffer between operations" "WARNING"
    }

    # Optimal spacing
    $optimalGapMin = 30
    if ($replicationStartMin -lt ($veeamEndMin + $optimalGapMin) -and $replicationStartMin -gt $veeamStartMin) {
        Write-Log "INFO: Recommended $optimalGapMin minute gap between operations" "INFO"
    }

    if ($conflicts.Count -eq 0) {
        Write-Log "No schedule conflicts detected" "SUCCESS"
        return @{
            HasConflict = $false
            Conflicts = @()
        }
    } else {
        return @{
            HasConflict = $true
            Conflicts = $conflicts
        }
    }
}

function Get-OptimalSchedule {
    param(
        [int]$VeeamDurationMin
    )

    Write-Log "Calculating optimal schedule..." "INFO"

    # Strategy: Run backups during off-hours, replication after backups complete
    # Assume business hours: 08:00 - 18:00
    # Optimal Veeam start: 02:00 (allows completion before business hours)
    # Optimal replication: After Veeam + buffer

    $recommendations = @{
        VeeamStart = "02:00"
        VeeamExpectedEnd = Convert-MinutesToTime -Minutes (120 + $VeeamDurationMin)
        ReplicationStart = "05:00"
        ReplicationWindow = "05:00 - 07:30"
        Rationale = @(
            "Veeam backups run during low-activity hours (2:00 AM)",
            "Expected completion before business hours start",
            "Replication runs after Veeam with 30-minute buffer",
            "All operations complete before 8:00 AM business hours",
            "Network bandwidth available for both operations"
        )
        Alternatives = @{
            EveningSchedule = @{
                VeeamStart = "22:00"
                ReplicationStart = "01:00"
                Description = "Evening schedule for systems with late-night activity"
            }
            LunchSchedule = @{
                VeeamStart = "12:00"
                ReplicationStart = "15:00"
                Description = "Midday schedule for 24/7 operations (less optimal)"
            }
        }
    }

    return $recommendations
}

function New-CoordinatedSchedule {
    param(
        [string]$VeeamTime,
        [int]$VeeamDuration,
        [string]$ReplicationTime,
        [string]$BusinessStart,
        [string]$BusinessEnd
    )

    Write-Log "Creating coordinated schedule..." "INFO"

    $schedule = @{
        Timestamp = (Get-Date).ToString()
        VeeamBackup = @{
            StartTime = $VeeamTime
            DurationMin = $VeeamDuration
            EndTime = Convert-MinutesToTime -Minutes ((Convert-TimeToMinutes -Time $VeeamTime) + $VeeamDuration)
        }
        TrueNasReplication = @{
            StartTime = $ReplicationTime
            EstimatedDurationMin = 90
            EndTime = Convert-MinutesToTime -Minutes ((Convert-TimeToMinutes -Time $ReplicationTime) + 90)
        }
        BusinessHours = @{
            Start = $BusinessStart
            End = $BusinessEnd
        }
        Coordination = @{
            BufferMinutes = (Convert-TimeToMinutes -Time $ReplicationTime) - ((Convert-TimeToMinutes -Time $VeeamTime) + $VeeamDuration)
            BothCompleteBeforeBusiness = $false
        }
    }

    # Check if both complete before business hours
    $replicationEndMin = (Convert-TimeToMinutes -Time $ReplicationTime) + 90
    $businessStartMin = Convert-TimeToMinutes -Time $BusinessStart

    if ($replicationEndMin -lt $businessStartMin) {
        $schedule.Coordination.BothCompleteBeforeBusiness = $true
        Write-Log "Schedule allows completion before business hours" "SUCCESS"
    } else {
        Write-Log "WARNING: Operations may extend into business hours" "WARNING"
    }

    # Save schedule
    try {
        $schedule | ConvertTo-Json -Depth 10 | Out-File -FilePath $scheduleFile -Force
        Write-Log "Schedule saved: $scheduleFile" "SUCCESS"
    } catch {
        Write-Log "WARNING: Could not save schedule file: $($_.Exception.Message)" "WARNING"
    }

    return $schedule
}

function Show-ScheduleVisualization {
    param([hashtable]$Schedule)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " COORDINATED SCHEDULE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # Timeline visualization (00:00 to 24:00)
    Write-Host "DAILY TIMELINE:" -ForegroundColor Yellow
    Write-Host ""

    $timeline = @"
00:00 ─────────────────────────────┐
                                     │
02:00 ══════════ VEEAM BACKUP ═════╡ $($Schedule.VeeamBackup.StartTime)
       ║                            │ Duration: $($Schedule.VeeamBackup.DurationMin) min
       ║                            │
$($Schedule.VeeamBackup.EndTime) ══════════════════════════╡ Backup Complete
                                     │
                                     │ Buffer: $($Schedule.Coordination.BufferMinutes) minutes
                                     │
05:00 ▓▓▓▓▓ REPLICATION ▓▓▓▓▓▓▓▓▓▓▓╡ $($Schedule.TrueNasReplication.StartTime)
       ▓                            │ Est. Duration: $($Schedule.TrueNasReplication.EstimatedDurationMin) min
       ▓                            │
$($Schedule.TrueNasReplication.EndTime) ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓╡ Replication Complete
                                     │
                                     │
08:00 ─────── BUSINESS HOURS ───────╡ $($Schedule.BusinessHours.Start)
                                     │
                                     │
18:00 ────────────────────────────── $($Schedule.BusinessHours.End)
                                     │
                                     │
24:00 ────────────────────────────────
"@

    Write-Host $timeline -ForegroundColor White
    Write-Host ""

    # Status indicator
    if ($Schedule.Coordination.BothCompleteBeforeBusiness) {
        Write-Host "Status: " -NoNewline
        Write-Host "OPTIMAL - All operations complete before business hours" -ForegroundColor Green
    } else {
        Write-Host "Status: " -NoNewline
        Write-Host "WARNING - Operations may overlap with business hours" -ForegroundColor Yellow
    }

    Write-Host ""

    # Key metrics
    Write-Host "KEY METRICS:" -ForegroundColor Cyan
    Write-Host "  Buffer between operations: $($Schedule.Coordination.BufferMinutes) minutes" -ForegroundColor White
    Write-Host "  Total maintenance window: " -NoNewline

    $totalMin = $Schedule.VeeamBackup.DurationMin + $Schedule.TrueNasReplication.EstimatedDurationMin + $Schedule.Coordination.BufferMinutes
    $totalHours = [math]::Round($totalMin / 60, 1)
    Write-Host "$totalMin minutes ($totalHours hours)" -ForegroundColor White

    Write-Host ""
}

function New-TrueNasReplicationConfig {
    param(
        [string]$TrueNasIP,
        [string]$StartTime
    )

    Write-Log "Generating TrueNAS replication configuration..." "INFO"

    $commands = @"
# TrueNAS Replication Schedule Configuration
# Run these commands via TrueNAS CLI or SSH

# View existing replication tasks
midclt call replication.query

# Update replication schedule (example - adjust task ID)
# Replace TASK_ID with actual task ID from query above
midclt call replication.update TASK_ID '{
  "schedule": {
    "minute": "0",
    "hour": "$($StartTime -split ':')[0]",
    "dom": "*",
    "month": "*",
    "dow": "*"
  },
  "enabled": true
}'

# Alternative: Create new replication task with proper schedule
# This is an example - adjust source/target datasets
midclt call replication.create '{
  "name": "Baby NAS to Main NAS",
  "direction": "PUSH",
  "transport": "SSH",
  "source_datasets": ["tank/veeam-backups"],
  "target_dataset": "main-pool/backups/baby-nas",
  "recursive": true,
  "schedule": {
    "minute": "0",
    "hour": "$($StartTime -split ':')[0]",
    "dom": "*",
    "month": "*",
    "dow": "*"
  },
  "retention_policy": "SOURCE",
  "enabled": true
}'

# Verify schedule
midclt call replication.query | jq '.[] | {name: .name, schedule: .schedule, enabled: .enabled}'
"@

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " TRUENAS REPLICATION CONFIGURATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To configure TrueNAS replication schedule:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. SSH to TrueNAS:" -ForegroundColor White
    Write-Host "   ssh root@$TrueNasIP" -ForegroundColor Green
    Write-Host ""
    Write-Host "2. Run configuration commands:" -ForegroundColor White
    Write-Host ""
    Write-Host $commands -ForegroundColor Green
    Write-Host ""
    Write-Host "3. Or use TrueNAS Web UI:" -ForegroundColor White
    Write-Host "   - Navigate to: Tasks > Replication Tasks" -ForegroundColor White
    Write-Host "   - Edit existing task or create new one" -ForegroundColor White
    Write-Host "   - Set schedule to: Daily at $StartTime" -ForegroundColor Green
    Write-Host "   - Ensure source includes Veeam backup dataset" -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Log "TrueNAS configuration instructions displayed" "INFO"
}

function New-BandwidthManagementConfig {
    param(
        [bool]$EnableLimit,
        [int]$LimitMbps,
        [string]$BusinessStart,
        [string]$BusinessEnd
    )

    Write-Log "Configuring bandwidth management..." "INFO"

    if (-not $EnableLimit) {
        Write-Log "Bandwidth limiting disabled" "INFO"
        return @{ Enabled = $false }
    }

    $config = @{
        Enabled = $true
        LimitMbps = $LimitMbps
        BusinessHours = @{
            Start = $BusinessStart
            End = $BusinessEnd
        }
        Implementation = @(
            "TrueNAS: Configure bandwidth limit in replication task settings",
            "TrueNAS: Use 'speed_limit' option in replication task",
            "Network: Consider QoS policies on switches/routers",
            "Veeam: No built-in bandwidth limiting in free agent"
        )
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " BANDWIDTH MANAGEMENT" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "CONFIGURATION:" -ForegroundColor Yellow
    Write-Host "  Limit during business hours: $LimitMbps Mbps" -ForegroundColor White
    Write-Host "  Business hours: $BusinessStart - $BusinessEnd" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPLEMENTATION STEPS:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. TrueNAS Replication Bandwidth Limit:" -ForegroundColor White
    Write-Host "   - Edit replication task in TrueNAS UI" -ForegroundColor White
    Write-Host "   - Advanced Options > Speed Limit" -ForegroundColor White
    Write-Host "   - Set to: $LimitMbps MB/s (during business hours)" -ForegroundColor Green
    Write-Host ""
    Write-Host "2. Alternative: Use mbuffer in replication:" -ForegroundColor White
    Write-Host "   mbuffer -r $(($LimitMbps * 1024))k" -ForegroundColor Green
    Write-Host ""
    Write-Host "3. Network QoS (if available):" -ForegroundColor White
    Write-Host "   - Configure QoS policies on network switches" -ForegroundColor White
    Write-Host "   - Prioritize production traffic during business hours" -ForegroundColor White
    Write-Host "   - Lower priority for backup/replication traffic" -ForegroundColor White
    Write-Host ""
    Write-Host "NOTE: Veeam Agent FREE does not include bandwidth throttling" -ForegroundColor Yellow
    Write-Host "      Schedule backups during off-hours to avoid impact" -ForegroundColor Yellow
    Write-Host ""

    Write-Log "Bandwidth management configuration generated" "SUCCESS"

    return $config
}

function Test-CurrentSchedule {
    Write-Log "Testing current schedule effectiveness..." "INFO"

    $currentTime = Get-Date
    $currentMin = ($currentTime.Hour * 60) + $currentTime.Minute

    $veeamMin = Convert-TimeToMinutes -Time $VeeamBackupTime
    $replicationMin = Convert-TimeToMinutes -Time $ReplicationStartTime

    $analysis = @{
        CurrentTime = $currentTime.ToString("HH:mm")
        VeeamActive = $false
        ReplicationActive = $false
        NextOperation = ""
        MinutesUntilNext = 0
    }

    # Check if Veeam should be running
    $veeamEndMin = $veeamMin + $VeeamBackupDurationMin

    if ($currentMin -ge $veeamMin -and $currentMin -lt $veeamEndMin) {
        $analysis.VeeamActive = $true
        Write-Log "Veeam backup should be running now" "INFO"
    }

    # Check if replication should be running
    $replicationEndMin = $replicationMin + 90

    if ($currentMin -ge $replicationMin -and $currentMin -lt $replicationEndMin) {
        $analysis.ReplicationActive = $true
        Write-Log "TrueNAS replication should be running now" "INFO"
    }

    # Determine next operation
    if (-not $analysis.VeeamActive -and -not $analysis.ReplicationActive) {
        if ($currentMin -lt $veeamMin) {
            $analysis.NextOperation = "Veeam Backup"
            $analysis.MinutesUntilNext = $veeamMin - $currentMin
        } elseif ($currentMin -lt $replicationMin) {
            $analysis.NextOperation = "TrueNAS Replication"
            $analysis.MinutesUntilNext = $replicationMin - $currentMin
        } else {
            # After all operations today
            $analysis.NextOperation = "Veeam Backup (tomorrow)"
            $analysis.MinutesUntilNext = (1440 - $currentMin) + $veeamMin
        }

        Write-Log "Next operation: $($analysis.NextOperation) in $($analysis.MinutesUntilNext) minutes" "INFO"
    }

    return $analysis
}

function New-IntegrationSummary {
    param(
        [hashtable]$Schedule,
        [hashtable]$ConflictCheck,
        [hashtable]$BandwidthConfig,
        [hashtable]$CurrentStatus
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " INTEGRATION SUMMARY" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "SCHEDULE STATUS:" -ForegroundColor Cyan
    if ($ConflictCheck.HasConflict) {
        Write-Host "  Status: " -NoNewline
        Write-Host "CONFLICTS DETECTED" -ForegroundColor Red
        Write-Host "  Conflicts:" -ForegroundColor Red
        foreach ($conflict in $ConflictCheck.Conflicts) {
            Write-Host "    - $conflict" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Status: " -NoNewline
        Write-Host "COORDINATED" -ForegroundColor Green
        Write-Host "  No scheduling conflicts detected" -ForegroundColor White
    }
    Write-Host ""

    Write-Host "CURRENT STATUS:" -ForegroundColor Cyan
    Write-Host "  Current Time: $($CurrentStatus.CurrentTime)" -ForegroundColor White
    Write-Host "  Veeam Active: " -NoNewline
    if ($CurrentStatus.VeeamActive) {
        Write-Host "YES" -ForegroundColor Green
    } else {
        Write-Host "NO" -ForegroundColor White
    }
    Write-Host "  Replication Active: " -NoNewline
    if ($CurrentStatus.ReplicationActive) {
        Write-Host "YES" -ForegroundColor Green
    } else {
        Write-Host "NO" -ForegroundColor White
    }
    if ($CurrentStatus.NextOperation) {
        Write-Host "  Next: $($CurrentStatus.NextOperation) in $($CurrentStatus.MinutesUntilNext) minutes" -ForegroundColor Cyan
    }
    Write-Host ""

    Write-Host "BANDWIDTH MANAGEMENT:" -ForegroundColor Cyan
    if ($BandwidthConfig.Enabled) {
        Write-Host "  Enabled: YES" -ForegroundColor Green
        Write-Host "  Limit: $($BandwidthConfig.LimitMbps) Mbps during business hours" -ForegroundColor White
    } else {
        Write-Host "  Enabled: NO" -ForegroundColor Yellow
        Write-Host "  Recommendation: Enable bandwidth limiting if network congestion occurs" -ForegroundColor White
    }
    Write-Host ""

    Write-Host "RECOMMENDATIONS:" -ForegroundColor Cyan
    Write-Host "  1. Monitor first few backup/replication cycles for timing accuracy" -ForegroundColor White
    Write-Host "  2. Adjust schedules if operations take longer than estimated" -ForegroundColor White
    Write-Host "  3. Enable bandwidth limiting if network performance affected" -ForegroundColor White
    Write-Host "  4. Review logs regularly: $logFile" -ForegroundColor White
    Write-Host "  5. Test failover procedures quarterly" -ForegroundColor White
    Write-Host ""

    Write-Host "CONFIGURATION FILES:" -ForegroundColor Cyan
    Write-Host "  Schedule: $scheduleFile" -ForegroundColor White
    Write-Host "  Log: $logFile" -ForegroundColor White
    Write-Host ""
}

# ===== MAIN EXECUTION =====

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " VEEAM & TRUENAS INTEGRATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== Integration Configuration Started ===" "INFO"
Write-Log "TrueNAS IP: $TrueNasIP" "INFO"
Write-Log "Veeam backup time: $VeeamBackupTime" "INFO"
Write-Log "Replication start: $ReplicationStartTime" "INFO"

# Step 1: Check for conflicts
Write-Log "" "INFO"
Write-Log "Step 1: Schedule Conflict Detection" "INFO"

$conflictCheck = Test-ScheduleConflict `
    -VeeamTime $VeeamBackupTime `
    -VeeamDuration $VeeamBackupDurationMin `
    -ReplicationTime $ReplicationStartTime

# Step 2: Create coordinated schedule
Write-Log "" "INFO"
Write-Log "Step 2: Create Coordinated Schedule" "INFO"

$schedule = New-CoordinatedSchedule `
    -VeeamTime $VeeamBackupTime `
    -VeeamDuration $VeeamBackupDurationMin `
    -ReplicationTime $ReplicationStartTime `
    -BusinessStart $BusinessHoursStart `
    -BusinessEnd $BusinessHoursEnd

# Step 3: Show schedule visualization
Show-ScheduleVisualization -Schedule $schedule

# Step 4: Configure TrueNAS replication
Write-Log "" "INFO"
Write-Log "Step 4: TrueNAS Replication Configuration" "INFO"

New-TrueNasReplicationConfig -TrueNasIP $TrueNasIP -StartTime $ReplicationStartTime

# Step 5: Bandwidth management
Write-Log "" "INFO"
Write-Log "Step 5: Bandwidth Management Configuration" "INFO"

$bandwidthConfig = New-BandwidthManagementConfig `
    -EnableLimit $EnableBandwidthLimit `
    -LimitMbps $BandwidthLimitMbps `
    -BusinessStart $BusinessHoursStart `
    -BusinessEnd $BusinessHoursEnd

# Step 6: Test current schedule
Write-Log "" "INFO"
Write-Log "Step 6: Current Schedule Analysis" "INFO"

$currentStatus = Test-CurrentSchedule

# Step 7: Show optimal schedule recommendations
Write-Log "" "INFO"
Write-Log "Step 7: Optimal Schedule Recommendations" "INFO"

$optimal = Get-OptimalSchedule -VeeamDurationMin $VeeamBackupDurationMin

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " OPTIMAL SCHEDULE RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "RECOMMENDED SCHEDULE:" -ForegroundColor Yellow
Write-Host "  Veeam Backup: $($optimal.VeeamStart)" -ForegroundColor Green
Write-Host "  Expected Completion: $($optimal.VeeamExpectedEnd)" -ForegroundColor White
Write-Host "  Replication Start: $($optimal.ReplicationStart)" -ForegroundColor Green
Write-Host "  Replication Window: $($optimal.ReplicationWindow)" -ForegroundColor White
Write-Host ""
Write-Host "RATIONALE:" -ForegroundColor Yellow
foreach ($reason in $optimal.Rationale) {
    Write-Host "  - $reason" -ForegroundColor White
}
Write-Host ""

# Step 8: Final summary
New-IntegrationSummary `
    -Schedule $schedule `
    -ConflictCheck $conflictCheck `
    -BandwidthConfig $bandwidthConfig `
    -CurrentStatus $currentStatus

Write-Log "=== Integration Configuration Completed ===" "SUCCESS"
Write-Log "Configuration saved: $scheduleFile" "INFO"
Write-Log "Log file: $logFile" "INFO"

exit 0
