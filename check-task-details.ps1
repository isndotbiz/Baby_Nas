# Check task details
param([string]$TaskName = "BabyNAS-Workspace-Sync")

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
$info = Get-ScheduledTaskInfo -TaskName $TaskName

Write-Host "`n=== Task: $TaskName ===" -ForegroundColor Cyan
Write-Host "`nGeneral:"
Write-Host "  State: $($task.State)"
Write-Host "  Last Run: $($info.LastRunTime)"
Write-Host "  Next Run: $($info.NextRunTime)"
Write-Host "  Last Result: $($info.LastTaskResult)"

Write-Host "`nAction:"
foreach ($action in $task.Actions) {
    Write-Host "  Execute: $($action.Execute)"
    Write-Host "  Arguments: $($action.Arguments)"
    Write-Host "  Working Dir: $($action.WorkingDirectory)"
}

Write-Host "`nTrigger(s):"
foreach ($trigger in $task.Triggers) {
    Write-Host "  Type: $($trigger.GetType().Name)"
    if ($trigger.Repetition.Interval) {
        Write-Host "  Interval: $($trigger.Repetition.Interval)"
    }
    if ($trigger.StartBoundary) {
        Write-Host "  Start: $($trigger.StartBoundary)"
    }
}

Write-Host "`nPrincipal:"
Write-Host "  User: $($task.Principal.UserId)"
Write-Host "  Run Level: $($task.Principal.RunLevel)"
