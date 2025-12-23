#!/bin/bash
# Start dataset generation campaign on Windows over SSH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

REMOTE_HOST="${HAFS_WINDOWS_HOST:-medical-mechanica}"
REMOTE_USER="${HAFS_WINDOWS_USER:-starw}"
REMOTE_CODE_DIR="${HAFS_WINDOWS_CODE_DIR:-C:/hafs}"
WINDOWS_PLUGIN_DIR="${HAFS_WINDOWS_PLUGIN_DIR:-C:/hafs_scawful}"
TRAINING_ROOT="${HAFS_WINDOWS_TRAINING:-D:/hafs_training}"
PYTHON_EXE="${HAFS_WINDOWS_PYTHON:-${REMOTE_CODE_DIR}/.venv/Scripts/python.exe}"

TARGET="${1:-34500}"
RESUME="${RESUME:-true}"
EXPORT="${EXPORT:-true}"
PILOT="${PILOT:-false}"

if [ "$RESUME" = "true" ]; then
  RESUME_FLAG="\$true"
else
  RESUME_FLAG="\$false"
fi

if [ "$EXPORT" = "true" ]; then
  EXPORT_FLAG="\$true"
else
  EXPORT_FLAG="\$false"
fi

if [ "$PILOT" = "true" ]; then
  PILOT_FLAG="\$true"
else
  PILOT_FLAG="\$false"
fi

PS_SCRIPT=$(cat <<PS
& '${WINDOWS_PLUGIN_DIR}/scripts/windows/start_campaign.ps1' -Target '${TARGET}' -Resume:${RESUME_FLAG} -Export:${EXPORT_FLAG} -Pilot:${PILOT_FLAG} -TrainingRoot '${TRAINING_ROOT}' -CodeRoot '${REMOTE_CODE_DIR}' -PluginRoot '${WINDOWS_PLUGIN_DIR}' -PythonExe '${PYTHON_EXE}'
PS
)
PS_SCRIPT="${PS_SCRIPT//$'\n'/; }"
PS_B64=$(printf "%s" "$PS_SCRIPT" | iconv -t UTF-16LE | base64 | tr -d '\n')

ssh "${REMOTE_USER}@${REMOTE_HOST}" "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${PS_B64}"
