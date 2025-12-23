param(
    [string]$TrainingRoot = $env:HAFS_WINDOWS_TRAINING
)

if (-not $TrainingRoot) { $TrainingRoot = "D:/hafs_training" }

$controlDir = Join-Path $TrainingRoot "control"
$pauseFlag = Join-Path $controlDir "pause.flag"
$null = New-Item -ItemType Directory -Force -Path $controlDir

Set-Content -Path $pauseFlag -Value "paused $(Get-Date -Format s)"
Write-Output "PAUSE:$pauseFlag"
