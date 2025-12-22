#!/bin/bash
# Mount or unmount Windows SMB shares for training.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

ACTION="${1:-mount}"
MOUNT_CMD="${HAFS_MOUNT_COMMAND:-mount-remotes}"
TARGET="${HAFS_MOUNT_TARGET:-mm}"

if command -v "$MOUNT_CMD" >/dev/null 2>&1; then
  if [ "$ACTION" = "unmount" ]; then
    "$MOUNT_CMD" "unmount-$TARGET"
  else
    "$MOUNT_CMD" "$TARGET"
  fi
  exit 0
fi

echo "No mount helper found (expected: mount-remotes)."
echo "Set HAFS_MOUNT_COMMAND or install mount-remotes."
exit 1
