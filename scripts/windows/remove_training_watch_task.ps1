param(
    [string]$TaskName = "hafs-training-watch"
)

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Output "Removed task: $TaskName"
    exit 0
}

Write-Output "Task not found: $TaskName"
