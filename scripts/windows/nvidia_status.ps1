param(
    [switch]$Watch,
    [int]$IntervalSeconds = 2
)

if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
    Write-Error "nvidia-smi not available."
    exit 1
}

function Show-Status {
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits
}

if ($Watch) {
    while ($true) {
        Show-Status
        Start-Sleep -Seconds $IntervalSeconds
    }
} else {
    Show-Status
}
