# List all custom scheduled tasks
Get-ScheduledTask | Where-Object {
    $_.TaskPath -eq '\' -and
    ($_.TaskName -like '*Baby*' -or
     $_.TaskName -like '*Workspace*' -or
     $_.TaskName -like '*Restic*' -or
     $_.TaskName -like '*TrueNAS*')
} | Select-Object TaskName, State | Sort-Object TaskName | Format-Table -AutoSize
