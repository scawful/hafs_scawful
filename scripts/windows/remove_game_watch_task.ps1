param(
    [string]$TaskName = "hafs-game-watch"
)

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Output "Removed task: $TaskName"
} else {
    Write-Output "Task not found: $TaskName"
}
