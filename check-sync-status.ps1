# Check if sync is still running
Write-Host "`n=== Sync Status Check ===" -ForegroundColor Cyan

# Check for running robocopy processes
$robocopy = Get-Process -Name robocopy -ErrorAction SilentlyContinue
if ($robocopy) {
    Write-Host "`nRobocopy is RUNNING:" -ForegroundColor Yellow
    $robocopy | Select-Object Id, CPU, StartTime | Format-Table
} else {
    Write-Host "`nRobocopy: Not running" -ForegroundColor Green
}

# Check Baby NAS storage
Write-Host "`nBaby NAS Storage:" -ForegroundColor Cyan
$result = ssh babynas "/usr/sbin/zfs list -o name,used,avail tank/workspace" 2>&1
Write-Host $result

# Check latest sync log
Write-Host "`nLatest Sync Logs:" -ForegroundColor Cyan
$latestLogs = Get-ChildItem "D:\workspace\Baby_Nas\backup-scripts\logs\sync_*.log" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 3

foreach ($log in $latestLogs) {
    $lastWrite = $log.LastWriteTime
    $size = [math]::Round($log.Length / 1KB, 1)
    $ago = (Get-Date) - $lastWrite
    Write-Host "  $($log.Name) - ${size}KB - $([math]::Round($ago.TotalMinutes, 1)) min ago"

    # Check if it has completion message
    $hasCompletion = Select-String -Path $log.FullName -Pattern "Workspace Sync Completed" -Quiet
    if ($hasCompletion) {
        Write-Host "    [OK] Completed" -ForegroundColor Green
    } else {
        Write-Host "    [!] Incomplete or running" -ForegroundColor Yellow
    }
}
