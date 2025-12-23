param(
    [string]$TaskName = "hafs-game-watch"
)

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Output "Task not found: $TaskName"
    exit 1
}

$info = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Output "Task: $TaskName"
Write-Output "State: $($info.State)"
Write-Output "Last Run: $($info.LastRunTime)"
Write-Output "Last Result: $($info.LastTaskResult)"
