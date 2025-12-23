#!/bin/bash

HAFS_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAFS_PLUGIN_CONFIG="${HAFS_PLUGIN_CONFIG:-$HAFS_PLUGIN_DIR/config.toml}"
export HAFS_PLUGIN_CONFIG

_hafs_load_env() {
  if [ ! -f "$HAFS_PLUGIN_CONFIG" ]; then
    return 0
  fi

  local exports
  exports="$(
    HAFS_PLUGIN_CONFIG="$HAFS_PLUGIN_CONFIG" python3 - <<'PY'
import os
import shlex
import tomllib
from pathlib import Path

path = Path(os.environ["HAFS_PLUGIN_CONFIG"])
with path.open("rb") as handle:
    data = tomllib.load(handle)

env = data.get("env", {})
for key, value in env.items():
    if value is None:
        continue
    print(f'export {key}={shlex.quote(str(value))}')
PY
  )"

  if [ -n "$exports" ]; then
    eval "$exports"
  fi
}

_hafs_load_env

_hafs_root() {
  echo "${HAFS_ROOT:-$HOME/Code/hafs}"
}

_hafs_context() {
  echo "${HAFS_CONTEXT:-$HOME/.context}"
}

_hafs_python() {
  local root="$(_hafs_root)"
  local python_bin="${HAFS_VENV:-$root/.venv}/bin/python"
  if [ -x "$python_bin" ]; then
    echo "$python_bin"
  else
    echo "python3"
  fi
}

hafs-cli() {
  if command -v hafs >/dev/null 2>&1; then
    hafs "$@"
    return
  fi

  local root="$(_hafs_root)"
  PYTHONPATH="$root/src" "$(_hafs_python)" -m cli.main "$@"
}

hafs-tui() {
  local root="$(_hafs_root)"
  PYTHONPATH="$root/src" "$(_hafs_python)" -m tui.app
}

cdhafs() {
  cd "$(_hafs_root)" || return 1
}

cdtraining() {
  cd "$(_hafs_root)/src/agents/training" || return 1
}

cdlsp() {
  cd "$(_hafs_root)/src/editors" || return 1
}

cdctx() {
  cd "$(_hafs_context)" || return 1
}

cdoos() {
  cd ~/Code/Oracle-of-Secrets || return 1
}

cdyaze() {
  cd ~/Code/yaze || return 1
}

cdusdasm() {
  cd ~/Code/usdasm || return 1
}

hafsenv() {
  local venv="${HAFS_VENV:-$(_hafs_root)/.venv}"
  if [ -f "$venv/bin/activate" ]; then
    # shellcheck disable=SC1090
    source "$venv/bin/activate"
    return 0
  fi
  echo "Missing venv at: $venv"
  return 1
}

hafs-presubmit() {
  local root="$(_hafs_root)"
  "$root/scripts/presubmit_training.sh"
}

hafs-sync() {
  local root="$(_hafs_root)"
  "$root/scripts/sync_training_to_windows.sh"
}

hafs-commit-sync() {
  local root="$(_hafs_root)"
  (cd "$root" && "$root/scripts/presubmit_training.sh") || return 1
  (cd "$root" && git status)
  local msg
  read -r -p "Commit message: " msg
  if [ -z "$msg" ]; then
    echo "Commit message required."
    return 1
  fi
  (cd "$root" && git add . && git commit -m "$msg" && git push) || return 1
  "$root/scripts/sync_training_to_windows.sh"
}

hafs-train-dev() {
  local root="$(_hafs_root)"
  (cd "$root" && "$root/scripts/presubmit_training.sh") || return 1
  (cd "$root" && git status)
  local answer
  read -r -p "Commit and sync now? [y/N] " answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    hafs-commit-sync
  else
    echo "Skipped commit/sync. Run hafs-commit-sync when ready."
  fi
}

hafs-test-imports() {
  local root="$(_hafs_root)"
  local python_bin="${HAFS_VENV:-$root/.venv}/bin/python"
  if [ ! -x "$python_bin" ]; then
    python_bin="python3"
  fi
  PYTHONPATH="$root/src" "$python_bin" - <<'PY'
import importlib
import sys

importlib.import_module("agents")
print("Imports OK.")
PY
}

hafs-training-status() {
  local context="$(_hafs_context)"
  ls -t "$context/training/datasets" 2>/dev/null | head -n 10
}

hafs-latest-dataset() {
  local context="$(_hafs_context)"
  ls -td "$context/training/datasets"/* 2>/dev/null | head -n 1
}

hafs-analyze-rejected() {
  local dataset="$1"
  if [ -z "$dataset" ]; then
    echo "Usage: hafs-analyze-rejected <dataset-path>"
    return 1
  fi
  local root="$(_hafs_root)"
  local python_bin="${HAFS_VENV:-$root/.venv}/bin/python"
  if [ ! -x "$python_bin" ]; then
    python_bin="python3"
  fi
  PYTHONPATH="$root/src" "$python_bin" "$root/scripts/analyze_rejected_samples.py" "$dataset"
}

hafs-analyze-latest() {
  local dataset
  dataset="$(hafs-latest-dataset)"
  if [ -z "$dataset" ]; then
    echo "No datasets found."
    return 1
  fi
  hafs-analyze-rejected "$dataset"
}

hafs-check-mounts() {
  local mounts=(
    "${HAFS_MOUNT_MMC:-$HOME/Mounts/mm-c}"
    "${HAFS_MOUNT_MMD:-$HOME/Mounts/mm-d}"
    "${HAFS_MOUNT_MME:-$HOME/Mounts/mm-e}"
  )
  local ok=0
  for mount in "${mounts[@]}"; do
    if [ -d "$mount" ]; then
      echo "OK: $mount"
    else
      echo "Missing: $mount"
      ok=1
    fi
  done
  return "$ok"
}

hafs-check-windows() {
  local host="${HAFS_WINDOWS_HOST:-medical-mechanica}"
  ssh "$host" "echo ok"
}

hafs-windows-status() {
  local host="${HAFS_WINDOWS_HOST:-medical-mechanica}"
  ssh "$host" "hostname"
  ssh "$host" "powershell -Command \"Get-Date; Get-ChildItem -Path C:\\ | Select-Object -First 5\""
}

hafs-gpu() {
  local host="${HAFS_WINDOWS_HOST:-medical-mechanica}"
  ssh "$host" "nvidia-smi"
}

win-ps() {
  local script="$HAFS_PLUGIN_DIR/scripts/win_ps.sh"
  if [ ! -x "$script" ]; then
    echo "Missing: $script"
    return 1
  fi
  "$script" "$@"
}

win-wsl() {
  local script="$HAFS_PLUGIN_DIR/scripts/wsl_ssh.sh"
  if [ ! -x "$script" ]; then
    echo "Missing: $script"
    return 1
  fi
  "$script" "$@"
}

win-status() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/system_status.ps1'"
}

win-procs() {
  local query="${*:-}"
  if [ -z "$query" ]; then
    echo "Usage: win-procs <name|pattern>"
    return 1
  fi
  win-ps "& 'C:/hafs_scawful/scripts/windows/process_list.ps1' -Contains '${query}'"
}

win-gpu-status() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/nvidia_status.ps1'"
}

win-hw() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/hardware_report.ps1'"
}

win-mode() {
  local mode="${1:-}"
  if [ -z "$mode" ]; then
    echo "Usage: win-mode <gaming|training|balanced|overnight|away>"
    return 1
  fi
  win-ps "& 'C:/hafs_scawful/scripts/windows/apply_energy_mode.ps1' -Mode ${mode}"
}

win-services() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/ensure_services.ps1'"
}

win-services-fix() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/ensure_services.ps1' -Fix"
}

win-update-harden() {
  local start="${1:-8}"
  local end="${2:-23}"
  win-ps "& 'C:/hafs_scawful/scripts/windows/harden_windows_updates.ps1' -Apply -ActiveHoursStart ${start} -ActiveHoursEnd ${end}"
}

win-update-restore() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/harden_windows_updates.ps1' -Revert"
}

win-power() {
  local mode="${1:-}"
  if [ -z "$mode" ]; then
    echo "Usage: win-power <gaming|training|balanced|high|power_saver>"
    return 1
  fi
  win-ps "& 'C:/hafs_scawful/scripts/windows/set_power_profile.ps1' -Mode ${mode}"
}

win-pause() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/pause_training.ps1'"
}

win-resume() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/resume_training.ps1'"
}

win-watch() {
  local processes="${1:-${HAFS_GAME_PROCESS_NAMES:-}}"
  if [ -z "$processes" ]; then
    echo "Usage: win-watch <process_names>"
    echo "Set HAFS_GAME_PROCESS_NAMES for default (comma or semicolon separated)."
    return 1
  fi
  win-ps "& 'C:/hafs_scawful/scripts/windows/watch_game_mode.ps1' -ProcessNames '${processes}' -Mode both -ApplyGpuLimits -GpuPower 150"
}

win-watch-install() {
  local processes="${1:-${HAFS_GAME_PROCESS_NAMES:-}}"
  if [ -z "$processes" ]; then
    echo "Usage: win-watch-install <process_names>"
    echo "Set HAFS_GAME_PROCESS_NAMES for default (comma or semicolon separated)."
    return 1
  fi
  win-ps "& 'C:/hafs_scawful/scripts/windows/install_game_watch_task.ps1' -ProcessNames '${processes}' -ApplyGpuLimits -GpuPower 150"
}

win-watch-remove() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/remove_game_watch_task.ps1'"
}

win-watch-status() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/watch_task_status.ps1'"
}

win-fan-status() {
  win-ps "& 'C:/hafs_scawful/scripts/windows/fancontrol_status.ps1'"
}

win-fan() {
  local profile="${1:-}"
  if [ -z "$profile" ]; then
    echo "Usage: win-fan <profile>"
    return 1
  fi
  win-ps "& 'C:/hafs_scawful/scripts/windows/fancontrol_switch.ps1' -Profile ${profile}"
}

hafs-logs() {
  local context="$(_hafs_context)"
  tail -n 100 "$context/logs/"*.log 2>/dev/null
}

hafs-lsp-status() {
  local root="$(_hafs_root)"
  "$root/scripts/hafs_lsp_control.sh" status
}

hafs-lsp-enable() {
  local root="$(_hafs_root)"
  "$root/scripts/hafs_lsp_control.sh" enable
}

hafs-lsp-disable() {
  local root="$(_hafs_root)"
  "$root/scripts/hafs_lsp_control.sh" disable
}

hafs-lsp-manual() {
  local root="$(_hafs_root)"
  "$root/scripts/hafs_lsp_control.sh" strategy manual_trigger
}

hpsync() {
  "$HAFS_PLUGIN_DIR/scripts/publish_plugin_configs.sh"
}

hmsg() {
  "$HAFS_PLUGIN_DIR/scripts/notify_agent_message.py" "$@"
}

hc() { hafs-cli chat; }
hshell() { hafs-cli chat; }
ht() { hafs-cli training status; }
htw() { hafs-cli training status --watch; }
htl() { hafs-cli training logs --follow; }
hn() { hafs-cli nodes status; }
hnl() { hafs-cli nodes list; }
hsvc() { hafs-cli services list; }
hstart() { hafs-cli services start "$@"; }
hstop() { hafs-cli services stop "$@"; }
hrestart() { hafs-cli services restart "$@"; }
hlog() { hafs-cli services logs "$@"; }
horun() { hafs-cli orchestrate run "$@"; }
htui() { hafs-tui; }

syshelp() {
  if command -v syshelp >/dev/null 2>&1; then
    command syshelp "$@"
    return
  fi
  if command -v syshub >/dev/null 2>&1; then
    command syshub "$@"
    return
  fi
  local bin="$HOME/Code/syshelp/build/syshelp"
  if [ -x "$bin" ]; then
    "$bin" "$@"
    return
  fi
  local legacy="$HOME/Code/syshub/build/syshub"
  if [ -x "$legacy" ]; then
    "$legacy" "$@"
    return
  fi
  echo "syshelp not found (build it in ~/Code/syshelp)."
  return 1
}

syshub() { syshelp "$@"; }

hafs-help() {
  cat <<'EOF'
Core:
  cdhafs, cdtraining, cdlsp, cdctx, cdoos, cdyaze, cdusdasm, hafsenv
CLI:
  hafs-cli, hafs-tui, hc, hshell, ht, htw, htl, hn, hnl, hsvc
Services:
  hstart, hstop, hrestart, hlog, horun, htui
Workflow:
  hafs-presubmit, hafs-sync, hafs-commit-sync, hafs-train-dev, hafs-test-imports
Training:
  hafs-training-status, hafs-latest-dataset, hafs-analyze-latest, hafs-analyze-rejected
Windows:
  hafs-check-windows, hafs-windows-status, hafs-gpu, win-ps, win-wsl, win-status
  win-procs, win-gpu-status, win-hw, win-mode, win-services, win-services-fix
  win-update-harden, win-update-restore, win-power, win-pause, win-resume, win-watch
  win-watch-install, win-watch-remove, win-watch-status, win-fan, win-fan-status
Mounts/Logs:
  hafs-check-mounts, hafs-logs
LSP:
  hafs-lsp-status, hafs-lsp-enable, hafs-lsp-disable, hafs-lsp-manual
Syshelp:
  syshelp
Plugin:
  hpsync, hmsg
EOF
}
