# Verify the tasks that were just created
Write-Host "`n=== Verifying Created Tasks ===" -ForegroundColor Cyan

$tasks = @("Workspace-Restic-Backup", "BabyNAS-Workspace-Sync")

foreach ($taskName in $tasks) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        $info = Get-ScheduledTaskInfo -TaskName $taskName
        Write-Host "`n[$taskName]" -ForegroundColor Green
        Write-Host "  State: $($task.State)"
        Write-Host "  Next Run: $($info.NextRunTime)"
        Write-Host "  Last Result: $($info.LastTaskResult)"
        if ($task.Triggers[0].Repetition.Interval) {
            Write-Host "  Interval: Every $($task.Triggers[0].Repetition.Interval)"
        }
        Write-Host "  Action: $($task.Actions[0].Execute) $($task.Actions[0].Arguments)"
    } else {
        Write-Host "`n[$taskName]" -ForegroundColor Red
        Write-Host "  Status: NOT FOUND"
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$foundCount = 0
foreach ($taskName in $tasks) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        $foundCount++
    }
}
Write-Host "Tasks created: $foundCount of $($tasks.Count)"

if ($foundCount -eq $tasks.Count) {
    Write-Host "`nSUCCESS: All tasks created!" -ForegroundColor Green
} else {
    Write-Host "`nWARNING: Some tasks missing" -ForegroundColor Yellow
}
