# Verify scheduled backup tasks
Write-Host "`n=== Scheduled Task Verification ===" -ForegroundColor Cyan

$taskNames = @(
    "Workspace-Restic-Backup",
    "Workspace-NAS-Sync",
    "BabyNAS-Workspace-Sync",
    "BabyNAS-Restic-Backup",
    "TrueNAS Daily Backup",
    "TrueNAS Weekly Backup"
)

foreach ($taskName in $taskNames) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        $info = Get-ScheduledTaskInfo -TaskName $taskName
        Write-Host "`n[$taskName]" -ForegroundColor Green
        Write-Host "  State: $($task.State)"
        Write-Host "  Last Run: $($info.LastRunTime)"
        Write-Host "  Next Run: $($info.NextRunTime)"
        Write-Host "  Last Result: $($info.LastTaskResult)"

        # Show trigger details
        if ($task.Triggers.Count -gt 0) {
            $trigger = $task.Triggers[0]
            if ($trigger.Repetition.Interval) {
                Write-Host "  Schedule: Every $($trigger.Repetition.Interval)"
            } else {
                Write-Host "  Schedule: $($trigger.GetType().Name)"
            }
        }
    } else {
        Write-Host "`n[$taskName]" -ForegroundColor Red
        Write-Host "  Status: NOT FOUND"
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$foundTasks = @()
foreach ($taskName in $taskNames) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) { $foundTasks += $taskName }
}
Write-Host "Found $($foundTasks.Count) of $($taskNames.Count) tasks"
if ($foundTasks.Count -gt 0) {
    Write-Host "Active tasks: $($foundTasks -join ', ')"
}
