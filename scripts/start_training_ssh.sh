#!/bin/bash
# Start model training on Windows over SSH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

REMOTE_HOST="${HAFS_WINDOWS_HOST:-medical-mechanica}"
REMOTE_USER="${HAFS_WINDOWS_USER:-starw}"
REMOTE_CODE_DIR="${HAFS_WINDOWS_CODE_DIR:-C:/hafs}"
WINDOWS_PLUGIN_DIR="${HAFS_WINDOWS_PLUGIN_DIR:-C:/hafs_scawful}"
TRAINING_ROOT="${HAFS_WINDOWS_TRAINING:-D:/hafs_training}"

DATASET_PATH="${1:-}"
MODEL_NAME="${2:-}"

if [ -z "$DATASET_PATH" ] || [ -z "$MODEL_NAME" ]; then
  echo "Usage: $0 <dataset_path> <model_name>"
  echo "Example: $0 D:/hafs_training/datasets/alttp_asm_24k oracle-rauru-assembler"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${TRAINING_ROOT}/logs/training_${MODEL_NAME}_${TS}.log"
ERR_FILE="${TRAINING_ROOT}/logs/training_${MODEL_NAME}_${TS}.err.log"

PS_SCRIPT=$(cat <<PS
\$env:HAFS_SCAWFUL_ROOT='${WINDOWS_PLUGIN_DIR}';
\$env:PYTHONPATH='${REMOTE_CODE_DIR}/src;${WINDOWS_PLUGIN_DIR}/..';
\$env:HAFS_DATASET_PATH='${DATASET_PATH}';
\$env:HAFS_MODEL_NAME='${MODEL_NAME}';
\$env:HAFS_MODEL_OUTPUT_DIR='${TRAINING_ROOT}/models/${MODEL_NAME}';
Start-Process -FilePath '${REMOTE_CODE_DIR}/.venv/Scripts/python.exe' -ArgumentList '-m','hafs_scawful.scripts.train_model_windows','${DATASET_PATH}' -RedirectStandardOutput '${LOG_FILE}' -RedirectStandardError '${ERR_FILE}' -WorkingDirectory '${REMOTE_CODE_DIR}' -NoNewWindow;
Write-Output 'LOG:${LOG_FILE}'
Write-Output 'ERR:${ERR_FILE}'
PS
)
PS_SCRIPT="${PS_SCRIPT//$'\n'/; }"

ssh "${REMOTE_USER}@${REMOTE_HOST}" "powershell -NoProfile -Command \"${PS_SCRIPT}\""
