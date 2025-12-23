param(
    [Parameter(Mandatory = $true)][string]$DatasetPath,
    [Parameter(Mandatory = $true)][string]$ModelName,
    [string]$TrainingRoot = $env:HAFS_WINDOWS_TRAINING,
    [string]$CodeRoot = $env:HAFS_WINDOWS_CODE_DIR,
    [string]$PluginRoot = $env:HAFS_WINDOWS_PLUGIN_DIR,
    [string]$PythonExe = $env:HAFS_WINDOWS_PYTHON
)

if (-not $TrainingRoot) { $TrainingRoot = "D:/hafs_training" }
if (-not $CodeRoot) { $CodeRoot = "C:/hafs" }
if (-not $PluginRoot) { $PluginRoot = "C:/hafs_scawful" }
if (-not $PythonExe) { $PythonExe = Join-Path $CodeRoot ".venv/Scripts/python.exe" }

$logDir = Join-Path $TrainingRoot "logs"
$controlDir = Join-Path $TrainingRoot "control"
$null = New-Item -ItemType Directory -Force -Path $logDir, $controlDir

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logDir "training_${ModelName}_${timestamp}.log"
$errFile = Join-Path $logDir "training_${ModelName}_${timestamp}.err.log"
$pidFile = Join-Path $controlDir "training_${ModelName}.pid"

$env:HAFS_SCAWFUL_ROOT = $PluginRoot
$env:PYTHONPATH = "$CodeRoot/src;$PluginRoot"
$env:PYTHONUNBUFFERED = "1"
$env:HAFS_DATASET_PATH = $DatasetPath
$env:HAFS_MODEL_NAME = $ModelName
$env:HAFS_MODEL_OUTPUT_DIR = "$TrainingRoot/models/$ModelName"
$env:HAFS_TRAINING_CONTROL_DIR = $controlDir

Set-Content -Path $logFile -Value "Starting training at $(Get-Date -Format s)"
Set-Content -Path $errFile -Value ""

$arguments = @("-u", "-m", "hafs_scawful.scripts.train_model_windows", $DatasetPath)
$proc = Start-Process -FilePath $PythonExe -ArgumentList $arguments -RedirectStandardOutput $logFile -RedirectStandardError $errFile -WorkingDirectory $CodeRoot -NoNewWindow -PassThru
Set-Content -Path $pidFile -Value $proc.Id

Write-Output "PID:$($proc.Id)"
Write-Output "LOG:$logFile"
Write-Output "ERR:$errFile"
