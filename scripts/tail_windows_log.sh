#!/bin/bash
# Tail latest Windows training log over SSH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

REMOTE_HOST="${HAFS_WINDOWS_HOST:-medical-mechanica}"
REMOTE_USER="${HAFS_WINDOWS_USER:-starw}"
TRAINING_ROOT="${HAFS_WINDOWS_TRAINING:-D:/hafs_training}"

TYPE="${1:-campaign}"
PATTERN="${2:-${TYPE}_*.log}"

PS_SCRIPT=$(cat <<PS
\$logDir='${TRAINING_ROOT}/logs';
\$pattern='${PATTERN}';
\$file=Get-ChildItem -Path \$logDir -Filter \$pattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1;
if (-not \$file) { Write-Error 'No logs found'; exit 1 };
Write-Output ('TAIL:' + \$file.FullName);
Get-Content -Path \$file.FullName -Tail 80 -Wait
PS
)
PS_SCRIPT="${PS_SCRIPT//$'\n'/; }"

ssh "${REMOTE_USER}@${REMOTE_HOST}" "powershell -NoProfile -Command \"${PS_SCRIPT}\""
