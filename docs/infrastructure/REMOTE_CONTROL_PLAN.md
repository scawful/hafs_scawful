# Remote Control Plan (Fans, Power, Training Pause)

## Goals
- Remotely lower thermals/noise when gaming.
- Pause/resume training without killing progress.
- Keep controls auditable and reversible.

## Baseline Setup
1. Ensure SSH access for both standard user and admin.
   - Default: `starw@medical-mechanica`
   - Admin for elevated tasks: `Administrator@medical-mechanica`
2. Install monitoring tools on Windows:
   - GPU: `nvidia-smi` (already with drivers)
   - CPU/RAM: Windows Performance Counters
   - Fans: `FanControl` (recommended) or `LibreHardwareMonitor`

## Phase 1: Power + Priority Controls (Low Risk)
### GPU power/clock control
- Power limit (temporary):
  - `nvidia-smi -pl 150` (set target watts)
  - `nvidia-smi --lock-gpu-clocks=1200,1200`
- Restore defaults:
  - `nvidia-smi -pl 0`
  - `nvidia-smi --reset-gpu-clocks`

### CPU power plan
- Switch power plans:
  - `powercfg /list`
  - `powercfg /setactive <GUID>`
- Define two plans:
  - **Gaming**: High performance
  - **Training**: Balanced (or custom)

### Process priority
- Lower training priority when gaming:
  - `Get-Process python | ForEach-Object { $_.PriorityClass = "BelowNormal" }`
- Restore:
  - `Get-Process python | ForEach-Object { $_.PriorityClass = "Normal" }`

## Phase 2: Pause/Resume Training (No Data Loss)
### Option A: Suspend process (fast)
- Use Sysinternals `pssuspend`:
  - `pssuspend -accepteula -nobanner python`
  - `pssuspend -r python`

### Option B: Soft pause via flag file
- Add a lightweight pause hook in training loop (recommended):
  - Check for `D:/hafs_training/control/pause.flag`
  - If present, sleep + save checkpoint
- Resume by deleting the flag

## Phase 3: Fan Control (Higher Risk)
- Use `FanControl` profiles with a CLI trigger:
  - Create profiles: `quiet.json` and `performance.json`
  - Switch with a small PowerShell wrapper script
- Alternative: `LibreHardwareMonitor` + custom script

## Proposed Scripts (Plugin)
Implemented:
- `scripts/windows/start_training.ps1` (launch training with logs + pid file)
- `scripts/windows/start_campaign.ps1` (launch generation campaign with logs + pid file)
- `scripts/windows/pause_training.ps1` (create pause flag)
- `scripts/windows/resume_training.ps1` (remove pause flag)
- `scripts/windows/watch_game_mode.ps1` (auto pause/priority while games run)
- `scripts/windows/set_gpu_limit.ps1` (apply/reset GPU power/clock limits)

Pending:
- `scripts/windows/set_power_profile.ps1`
  - Inputs: `--mode training|gaming`
- `scripts/windows/set_gpu_limit.ps1`
  - Inputs: `--power 150`, `--clock 1200`

Usage (examples):
- `powershell -ExecutionPolicy Bypass -File C:/hafs_scawful/scripts/windows/start_training.ps1 -DatasetPath D:/hafs_training/datasets/euclid_asm_v1 -ModelName euclid-asm-qwen25-coder-1.5b-20251222`
- `powershell -ExecutionPolicy Bypass -File C:/hafs_scawful/scripts/windows/pause_training.ps1`
- `powershell -ExecutionPolicy Bypass -File C:/hafs_scawful/scripts/windows/watch_game_mode.ps1 -ProcessNames GameProcessName -Mode both -ApplyGpuLimits -GpuPower 150`
- Set default game processes via `HAFS_GAME_PROCESS_NAMES` (comma or semicolon separated).

## Safety Notes
- Do not force fan curves below safe thresholds.
- Always record current settings before changes.
- For GPU settings, validate with `nvidia-smi -q -d POWER`.

## Next Actions
1. Decide between `pssuspend` vs flag-file pause.
2. Choose fan tool (`FanControl` vs `LibreHardwareMonitor`).
3. Implement the PowerShell scripts in `scripts/windows/`.
