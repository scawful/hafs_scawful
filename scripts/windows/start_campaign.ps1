param(
    [string]$Target = "34500",
    [bool]$Resume = $true,
    [bool]$Export = $true,
    [bool]$Pilot = $false,
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
$logFile = Join-Path $logDir "campaign_${Target}_${timestamp}.log"
$errFile = Join-Path $logDir "campaign_${Target}_${timestamp}.err.log"
$pidFile = Join-Path $controlDir "campaign_${Target}.pid"

$env:HAFS_SCAWFUL_ROOT = $PluginRoot
$env:PYTHONPATH = "$CodeRoot/src;$PluginRoot"
$env:PYTHONUNBUFFERED = "1"
$env:TRAINING_OUTPUT_DIR = "$TrainingRoot/datasets"
$env:TRAINING_CHECKPOINT_DIR = "$TrainingRoot/checkpoints"
$env:TRAINING_LOG_DIR = "$TrainingRoot/logs"

Set-Content -Path $logFile -Value "Starting campaign at $(Get-Date -Format s)"
Set-Content -Path $errFile -Value ""

$arguments = @("-u", "-m", "hafs_scawful.scripts.training.generate_campaign", "--target", $Target)
if ($Resume) { $arguments += "--resume" }
if ($Export) { $arguments += "--export" }
if ($Pilot) { $arguments += "--pilot" }

$proc = Start-Process -FilePath $PythonExe -ArgumentList $arguments -RedirectStandardOutput $logFile -RedirectStandardError $errFile -WorkingDirectory $CodeRoot -NoNewWindow -PassThru
Set-Content -Path $pidFile -Value $proc.Id

Write-Output "PID:$($proc.Id)"
Write-Output "LOG:$logFile"
Write-Output "ERR:$errFile"
