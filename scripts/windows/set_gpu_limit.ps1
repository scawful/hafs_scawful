param(
    [int]$Power,
    [string]$Clock,
    [switch]$Reset,
    [string]$NvidiaSmiPath = $env:HAFS_NVIDIA_SMI
)

if (-not $NvidiaSmiPath) { $NvidiaSmiPath = "nvidia-smi" }

function Invoke-NvidiaSmi {
    param([string]$Arguments)
    try {
        & $NvidiaSmiPath $Arguments | Out-String | Write-Output
        return $true
    } catch {
        Write-Error "Failed to run $NvidiaSmiPath $Arguments: $($_.Exception.Message)"
        return $false
    }
}

if ($Reset) {
    Invoke-NvidiaSmi "-pl 0" | Out-Null
    Invoke-NvidiaSmi "--reset-gpu-clocks" | Out-Null
    Write-Output "GPU limits reset."
    exit 0
}

if ($Power -gt 0) {
    Invoke-NvidiaSmi "-pl $Power" | Out-Null
    Write-Output "GPU power limit set to $Power W."
}

if ($Clock) {
    Invoke-NvidiaSmi "--lock-gpu-clocks=$Clock" | Out-Null
    Write-Output "GPU clocks locked to $Clock."
}

if (-not $Power -and -not $Clock) {
    Write-Output "No power/clock settings provided. Use -Power, -Clock, or -Reset."
}
