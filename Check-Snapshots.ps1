# Check-Snapshots.ps1
# Check ZFS snapshot status on Baby NAS
# Usage: .\Check-Snapshots.ps1 [-Detailed]

param(
    [switch]$Detailed,
    [string]$Dataset = "tank"
)

$Host.UI.RawUI.WindowTitle = "Baby NAS Snapshot Status"

Write-Host "`n=== Baby NAS Snapshot Status ===" -ForegroundColor Cyan
Write-Host "Host: babynas (10.0.0.88)" -ForegroundColor Gray
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# Check SSH connectivity
Write-Host "Checking connection..." -ForegroundColor Yellow
$testConnection = ssh babynas "echo OK" 2>&1
if ($testConnection -ne "OK") {
    Write-Host "ERROR: Cannot connect to babynas via SSH" -ForegroundColor Red
    Write-Host "Make sure SSH is configured in ~/.ssh/config" -ForegroundColor Gray
    exit 1
}

# Get snapshot tasks
Write-Host "`n--- Snapshot Tasks ---" -ForegroundColor Green
$tasksJson = ssh babynas "midclt call pool.snapshottask.query"
$tasks = $tasksJson | ConvertFrom-Json

if ($tasks.Count -eq 0) {
    Write-Host "No snapshot tasks configured!" -ForegroundColor Red
} else {
    foreach ($task in $tasks) {
        $status = if ($task.enabled) { "[ENABLED]" } else { "[DISABLED]" }
        $color = if ($task.enabled) { "Green" } else { "Yellow" }

        $schedule = switch -Regex ($task.schedule.hour) {
            "^\*$" { "Hourly" }
            "^0$" { "Daily" }
            default { "Custom" }
        }

        Write-Host ("  ID {0}: {1} - {2}, Keep {3} {4} {5}" -f `
            $task.id, `
            $task.dataset, `
            $schedule, `
            $task.lifetime_value, `
            $task.lifetime_unit, `
            $status) -ForegroundColor $color
    }
}

# Get current snapshots
Write-Host "`n--- Current Snapshots ---" -ForegroundColor Green
$snapshotsJson = ssh babynas "midclt call zfs.snapshot.query"
$allSnapshots = $snapshotsJson | ConvertFrom-Json
$snapshots = @($allSnapshots | Where-Object { $_.pool -eq $Dataset })

if ($snapshots.Count -eq 0) {
    Write-Host "  No snapshots found (tasks may not have run yet)" -ForegroundColor Yellow
} else {
    # Group by dataset
    $grouped = $snapshots | Group-Object { $_.dataset }

    foreach ($group in $grouped) {
        Write-Host "`n  $($group.Name):" -ForegroundColor Cyan
        $sorted = $group.Group | Sort-Object { $_.properties.creation.parsed.'$date' } -Descending

        if ($Detailed) {
            foreach ($snap in $sorted) {
                $creation = [DateTimeOffset]::FromUnixTimeMilliseconds($snap.properties.creation.parsed.'$date').LocalDateTime
                $used = $snap.properties.used.value
                Write-Host ("    {0} - {1} (Used: {2})" -f $snap.snapshot_name, $creation.ToString("yyyy-MM-dd HH:mm"), $used)
            }
        } else {
            # Show summary
            $hourly = @($sorted | Where-Object { $_.snapshot_name -like "hourly-*" })
            $daily = @($sorted | Where-Object { $_.snapshot_name -like "daily-*" })
            $manual = @($sorted | Where-Object { $_.snapshot_name -notlike "hourly-*" -and $_.snapshot_name -notlike "daily-*" })

            Write-Host "    Hourly: $($hourly.Count) snapshots" -ForegroundColor White
            if ($hourly.Count -gt 0) {
                $latest = $hourly[0]
                $creation = [DateTimeOffset]::FromUnixTimeMilliseconds($latest.properties.creation.parsed.'$date').LocalDateTime
                Write-Host "      Latest: $($latest.snapshot_name) ($($creation.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Gray
            }

            Write-Host "    Daily:  $($daily.Count) snapshots" -ForegroundColor White
            if ($daily.Count -gt 0) {
                $latest = $daily[0]
                $creation = [DateTimeOffset]::FromUnixTimeMilliseconds($latest.properties.creation.parsed.'$date').LocalDateTime
                Write-Host "      Latest: $($latest.snapshot_name) ($($creation.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Gray
            }

            if ($manual.Count -gt 0) {
                Write-Host "    Manual: $($manual.Count) snapshots" -ForegroundColor White
            }
        }
    }

    Write-Host "`n  Total: $($snapshots.Count) snapshots across all datasets" -ForegroundColor Cyan
}

# Check pool health
Write-Host "`n--- Pool Health ---" -ForegroundColor Green
$poolJson = ssh babynas "midclt call pool.query"
$pools = $poolJson | ConvertFrom-Json
$pool = $pools | Where-Object { $_.name -eq $Dataset } | Select-Object -First 1

if ($pool) {
    $healthColor = switch ($pool.status) {
        "ONLINE" { "Green" }
        "DEGRADED" { "Yellow" }
        default { "Red" }
    }
    Write-Host "  Pool: $($pool.name)" -ForegroundColor White
    Write-Host "  Status: $($pool.status)" -ForegroundColor $healthColor
    Write-Host "  Healthy: $($pool.healthy)" -ForegroundColor $(if ($pool.healthy) { "Green" } else { "Red" })

    # Show capacity
    $usedPct = [math]::Round(($pool.allocated / $pool.size) * 100, 1)
    $freeGB = [math]::Round($pool.free / 1GB, 1)
    Write-Host "  Capacity: $usedPct% used, $freeGB GB free" -ForegroundColor White
} else {
    Write-Host "  Pool '$Dataset' not found" -ForegroundColor Red
}

Write-Host "`n=== Check Complete ===" -ForegroundColor Cyan
Write-Host ""

# Usage hint
if (-not $Detailed) {
    Write-Host "Tip: Run with -Detailed for full snapshot list" -ForegroundColor Gray
}
