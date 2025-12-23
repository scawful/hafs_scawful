#!/bin/bash
# Run a WSL command on the Windows host over SSH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

REMOTE_HOST="${HAFS_WINDOWS_HOST:-medical-mechanica}"
REMOTE_USER="${HAFS_WINDOWS_USER:-starw}"
WSL_DISTRO="${HAFS_WSL_DISTRO:-Ubuntu}"
WSL_USER="${HAFS_WSL_USER:-}"

if [ -z "${1:-}" ]; then
  if [ -n "$WSL_USER" ]; then
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "wsl -d \"$WSL_DISTRO\" -u \"$WSL_USER\" -- bash -l"
  else
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "wsl -d \"$WSL_DISTRO\" -- bash -l"
  fi
  exit 0
fi

CMD="$*"
printf -v CMD_ESC '%q' "$CMD"

if [ -n "$WSL_USER" ]; then
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "wsl -d \"$WSL_DISTRO\" -u \"$WSL_USER\" -- bash -lc $CMD_ESC"
else
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "wsl -d \"$WSL_DISTRO\" -- bash -lc $CMD_ESC"
fi
