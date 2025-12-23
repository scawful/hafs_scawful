# Agent Instructions (hafs_scawful)

This repo contains user-specific training workflows, domain generators, and Windows GPU automation.

## Scope Rules
- Keep user-specific scripts, datasets, and Windows/GPU workflows here.
- Use env vars (for example: `HAFS_WINDOWS_HOST`, `HAFS_WINDOWS_USER`, `HAFS_WINDOWS_TRAINING`) instead of hardcoding.
- If a change is generic or affects shared runtime behavior, update `~/Code/hafs` instead.

## Host Inventory
- Windows GPU host: `medical-mechanica` (`starw`, admin: `Administrator`)
- Plugin root (Windows): `C:/hafs_scawful`
- Training root (Windows): `D:/hafs_training`
- Python (Windows): `D:/pytorch_env/Scripts/python.exe`
- FanControl configs: `C:/Program Files (x86)/FanControl/Configurations`
- Pause flag: `D:/hafs_training/control/pause.flag`
- WSL: Ubuntu (use `scripts/wsl_ssh.sh`)

## Common Aliases (macOS shell)
- `win-status` / `win-hw` / `win-gpu-status`
- `win-mode <gaming|training|balanced|overnight|away>` (power + GPU cap + fan profile)
- `win-services` / `win-services-fix` (check/start sshd + tailscale)
- `win-update-harden [start end]` (avoid auto restarts + set active hours)
- `win-update-restore` (remove update policies)
- `win-power <gaming|training|balanced|high|power_saver>`
- `win-fan <profile>` (curve-quiet/balanced/performance/gaming/training/overnight/away)
- `win-watch-install <process_names>` (auto pause + GPU limit)
- `win-pause` / `win-resume`
- `win-telemetry-install [interval]` (background GPU/CPU logger)
- `win-telemetry-status` / `win-telemetry-remove`
- `win-watch-conn [interval]` (Mac watchdog for mounts + SSH)
- `win-watch-conn-install [interval]` (LaunchAgent installer)
- `win-watch-conn-remove` (LaunchAgent removal)
- `win-training-plan` (create + activate no-sleep training plan)

## Primary Docs
- Host summary: `docs/MEDICAL_MECHANICA_SETUP_SUMMARY.md`
- Remote control plan: `docs/infrastructure/remote_control_plan.md`
- Windows setup guide: `docs/infrastructure/windows_setup.md`

## Notes
- PSU wattage cannot be detected via standard Windows tools.
- Prefer PowerShell scripts in `scripts/windows` over ad-hoc commands.
