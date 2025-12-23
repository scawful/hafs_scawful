param(
    [string]$Mode,
    [string]$Guid
)

if ($Guid) {
    powercfg /setactive $Guid
    Write-Output "Power plan set to $Guid"
    exit 0
}

if (-not $Mode) {
    Write-Output "Usage: set_power_profile.ps1 -Mode <gaming|training|balanced|high|power_saver>"
    powercfg /list
    exit 1
}

$targetName = switch ($Mode.ToLower()) {
    "gaming" { "High performance" }
    "high" { "High performance" }
    "training" { "Balanced" }
    "balanced" { "Balanced" }
    "power_saver" { "Power saver" }
    default { $Mode }
}

$plans = powercfg /list
$match = $plans | Select-String -Pattern $targetName | Select-Object -First 1
if (-not $match) {
    Write-Error "No power plan matching '$targetName' found."
    powercfg /list
    exit 1
}

if ($match.Line -match '([A-F0-9-]{36})') {
    $planGuid = $matches[1]
    powercfg /setactive $planGuid
    Write-Output "Power plan set to $targetName ($planGuid)"
} else {
    Write-Error "Failed to parse power plan GUID."
    powercfg /list
    exit 1
}
