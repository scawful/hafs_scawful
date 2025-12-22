#!/bin/bash
# Sync hafs + hafs_scawful to the Windows training mount.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

HAFS_ROOT="${HAFS_ROOT:-$HOME/Code/hafs}"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

export HAFS_SCAWFUL_ROOT="$PLUGIN_ROOT"
export HAFS_WINDOWS_MOUNT="${HAFS_MOUNT_MMD:-$HOME/Mounts/mm-d}"
export HAFS_WINDOWS_TRAINING_MOUNT="${HAFS_TRAINING_MOUNT:-$HAFS_WINDOWS_MOUNT/hafs_training}"

if [ ! -x "$HAFS_ROOT/scripts/sync_to_windows.sh" ]; then
  echo "Missing core sync script: $HAFS_ROOT/scripts/sync_to_windows.sh"
  exit 1
fi

"$HAFS_ROOT/scripts/sync_to_windows.sh" "${1:-all}"
