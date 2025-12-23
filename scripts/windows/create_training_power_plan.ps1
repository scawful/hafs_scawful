param(
    [string]$PlanName = "hAFS Training",
    [string]$BaseName = "Balanced",
    [int]$MonitorTimeoutAc = 20,
    [int]$MonitorTimeoutDc = 10,
    [switch]$Activate
)

function Get-PowerPlanGuid {
    param([string]$Name)
    $plans = powercfg /list
    $match = $plans | Select-String -Pattern $Name | Select-Object -First 1
    if (-not $match) {
        return $null
    }
    if ($match.Line -match '([A-F0-9-]{36})') {
        return $matches[1]
    }
    return $null
}

$existingGuid = Get-PowerPlanGuid -Name $PlanName
if (-not $existingGuid) {
    $baseGuid = Get-PowerPlanGuid -Name $BaseName
    if (-not $baseGuid) {
        Write-Error "Base power plan '$BaseName' not found."
        powercfg /list
        exit 1
    }

    $dup = powercfg /duplicatescheme $baseGuid
    if ($dup -match '([A-F0-9-]{36})') {
        $existingGuid = $matches[1]
        powercfg /changename $existingGuid $PlanName "No sleep/hibernate during training"
    } else {
        Write-Error "Failed to duplicate base plan."
        exit 1
    }
}

# Disable sleep/hibernate for the plan.
powercfg /setacvalueindex $existingGuid SUB_SLEEP STANDBYIDLE 0
powercfg /setdcvalueindex $existingGuid SUB_SLEEP STANDBYIDLE 0
powercfg /setacvalueindex $existingGuid SUB_SLEEP HIBERNATEIDLE 0
powercfg /setdcvalueindex $existingGuid SUB_SLEEP HIBERNATEIDLE 0

# Optionally turn off the monitor after a bit.
if ($MonitorTimeoutAc -ge 0) {
    powercfg /setacvalueindex $existingGuid SUB_VIDEO VIDEOIDLE $MonitorTimeoutAc
}
if ($MonitorTimeoutDc -ge 0) {
    powercfg /setdcvalueindex $existingGuid SUB_VIDEO VIDEOIDLE $MonitorTimeoutDc
}

if ($Activate) {
    powercfg /setactive $existingGuid | Out-Null
}

Write-Output "Training power plan ready: $PlanName ($existingGuid)"
