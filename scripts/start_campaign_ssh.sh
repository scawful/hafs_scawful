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

TARGET="${1:-34500}"
RESUME="${RESUME:-true}"
EXPORT="${EXPORT:-true}"
PILOT="${PILOT:-false}"

TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${TRAINING_ROOT}/logs/campaign_${TARGET}_${TS}.log"
ERR_FILE="${TRAINING_ROOT}/logs/campaign_${TARGET}_${TS}.err.log"

ARG_LIST="'-m','hafs_scawful.scripts.training.generate_campaign','--target','${TARGET}'"
if [ "$RESUME" = "true" ]; then
  ARG_LIST="${ARG_LIST},'--resume'"
fi
if [ "$EXPORT" = "true" ]; then
  ARG_LIST="${ARG_LIST},'--export'"
fi
if [ "$PILOT" = "true" ]; then
  ARG_LIST="${ARG_LIST},'--pilot'"
fi

PS_SCRIPT=$(cat <<PS
\$env:HAFS_SCAWFUL_ROOT='${WINDOWS_PLUGIN_DIR}';
\$env:PYTHONPATH='${REMOTE_CODE_DIR}/src;${WINDOWS_PLUGIN_DIR}/..';
\$env:TRAINING_OUTPUT_DIR='${TRAINING_ROOT}/datasets';
\$env:TRAINING_CHECKPOINT_DIR='${TRAINING_ROOT}/checkpoints';
\$env:TRAINING_LOG_DIR='${TRAINING_ROOT}/logs';
Start-Process -FilePath '${REMOTE_CODE_DIR}/.venv/Scripts/python.exe' -ArgumentList ${ARG_LIST} -RedirectStandardOutput '${LOG_FILE}' -RedirectStandardError '${ERR_FILE}' -WorkingDirectory '${REMOTE_CODE_DIR}' -NoNewWindow;
Write-Output 'LOG:${LOG_FILE}'
Write-Output 'ERR:${ERR_FILE}'
PS
)
PS_SCRIPT="${PS_SCRIPT//$'\n'/; }"

ssh "${REMOTE_USER}@${REMOTE_HOST}" "powershell -NoProfile -Command \"${PS_SCRIPT}\""
