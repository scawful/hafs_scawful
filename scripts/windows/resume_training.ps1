param(
    [string]$TrainingRoot = $env:HAFS_WINDOWS_TRAINING
)

if (-not $TrainingRoot) { $TrainingRoot = "D:/hafs_training" }

$controlDir = Join-Path $TrainingRoot "control"
$pauseFlag = Join-Path $controlDir "pause.flag"

Remove-Item -Path $pauseFlag -ErrorAction SilentlyContinue
Write-Output "RESUME:$pauseFlag"
