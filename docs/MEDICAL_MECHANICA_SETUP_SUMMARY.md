# Medical Mechanica Setup Summary

## Host Overview
- Hostname: `medical-mechanica`
- Primary user: `starw` (admin: `Administrator`)
- OS: Windows 10/11 Pro 64-bit (exact build in `win-hw`)

## Hardware (current)
- CPU: AMD Ryzen 7 5800XT (8c/16t)
- GPU: MSI GeForce RTX 5060 Ti 16 GB
- RAM: 32 GB DDR4
- Motherboard: ASUS X570 TUF Gaming Plus WiFi
- Cooling: AIO + 3 top fans + 3 front/side fans + 1 rear exhaust
- Bottom intake: empty (no fans installed)
- PSU: unknown (not detectable via Windows tools)

## Key Paths
- Plugin root: `C:/hafs_scawful`
- Training root: `D:/hafs_training`
- Pause flag: `D:/hafs_training/control/pause.flag`
- Windows Python: `D:/pytorch_env/Scripts/python.exe`
- FanControl configs: `C:/Program Files (x86)/FanControl/Configurations`
- WSL: Ubuntu (use `scripts/wsl_ssh.sh`)

## Core Scripts (PowerShell)
- `scripts/windows/system_status.ps1` (training + system status)
- `scripts/windows/hardware_report.ps1` (hardware inventory)
- `scripts/windows/start_training.ps1` (launch training job + logs)
- `scripts/windows/start_campaign.ps1` (dataset generation)
- `scripts/windows/pause_training.ps1` / `resume_training.ps1`
- `scripts/windows/watch_game_mode.ps1` (auto pause + GPU cap)
- `scripts/windows/set_gpu_limit.ps1` (power/clock caps)
- `scripts/windows/set_power_profile.ps1` (power plan)
- `scripts/windows/fancontrol_switch.ps1` (profile switch)
- `scripts/windows/fancontrol_status.ps1` (FanControl status)

## Fan Profiles
Switch with `win-fan <profile>`:
- `curve-quiet`, `curve-balanced`, `curve-performance`
- `curve-gaming`, `curve-training`
- `curve-overnight`, `curve-away`

## Energy Modes
One command applies fan + power plan + GPU cap:
- `win-mode gaming` (curve-gaming + high performance + 170W cap)
- `win-mode training` (curve-training + balanced + 150W cap)
- `win-mode balanced` (curve-balanced + balanced + 140W cap)
- `win-mode overnight` (curve-overnight + power saver + 110W cap)
- `win-mode away` (curve-away + power saver + 90W cap)

## Scheduled Tasks
- `hafs-game-watch`: watches for game processes and applies pause + GPU limit

## Quick Commands (macOS shell)
- `win-hw` (hardware report)
- `win-status` (training + system status)
- `win-gpu-status` (GPU telemetry)
- `win-power power_saver` (energy saving)
- `win-fan curve-gaming` (swap fan curves)
- `win-mode away` (one-shot energy mode)
- `win-services` (check sshd + tailscale)

## Notes
- PSU wattage is not reported by standard Windows APIs.
- Prefer `scripts/windows/*` over ad-hoc commands for repeatability.
