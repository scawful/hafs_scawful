#!/bin/bash
# Run a PowerShell command on the Windows host using an encoded payload.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

REMOTE_HOST="${HAFS_WINDOWS_HOST:-medical-mechanica}"
REMOTE_USER="${HAFS_WINDOWS_USER:-starw}"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <PowerShell command>"
  exit 1
fi

PS_SCRIPT="$*"
PS_B64=$(printf "%s" "$PS_SCRIPT" | iconv -t UTF-16LE | base64 | tr -d '\n')

ssh "${REMOTE_USER}@${REMOTE_HOST}" "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${PS_B64}"
