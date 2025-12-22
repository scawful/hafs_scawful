#!/bin/bash
# SSH helper for Windows GPU host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

REMOTE_HOST="${HAFS_WINDOWS_HOST:-medical-mechanica}"
REMOTE_USER="${HAFS_WINDOWS_USER:-starw}"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 [--ps 'PowerShell command'] | [ssh args...]"
  exit 1
fi

if [ "$1" = "--ps" ]; then
  shift
  if [ "$#" -lt 1 ]; then
    echo "Usage: $0 --ps 'PowerShell command'"
    exit 1
  fi
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "powershell -NoProfile -Command \"$*\""
else
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "$@"
fi
