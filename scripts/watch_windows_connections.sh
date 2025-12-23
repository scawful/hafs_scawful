#!/bin/bash
# Watch Windows SSH connectivity and SMB mounts; remount if needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/_plugin_env.sh"

HOST="${HAFS_WINDOWS_HOST:-medical-mechanica}"
USER="${HAFS_WINDOWS_USER:-starw}"
INTERVAL="${1:-60}"
CHECK_SSH=1
CHECK_MOUNTS=1

if [ "${2:-}" = "--ssh-only" ]; then
  CHECK_MOUNTS=0
fi
if [ "${2:-}" = "--mounts-only" ]; then
  CHECK_SSH=0
fi

mounts=()
if [ -n "${HAFS_MOUNT_MMC:-}" ]; then
  mounts+=("$HAFS_MOUNT_MMC")
fi
if [ -n "${HAFS_MOUNT_MMD:-}" ]; then
  mounts+=("$HAFS_MOUNT_MMD")
fi
if [ -n "${HAFS_MOUNT_MME:-}" ]; then
  mounts+=("$HAFS_MOUNT_MME")
fi

echo "Watching Windows host: ${USER}@${HOST} (interval ${INTERVAL}s)"
if [ "${#mounts[@]}" -gt 0 ]; then
  echo "Mounts: ${mounts[*]}"
fi

while true; do
  if [ "$CHECK_SSH" -eq 1 ]; then
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "${USER}@${HOST}" "echo ok" >/dev/null 2>&1; then
      echo "$(date '+%F %T') SSH: ok"
    else
      echo "$(date '+%F %T') SSH: down"
    fi
  fi

  if [ "$CHECK_MOUNTS" -eq 1 ] && [ "${#mounts[@]}" -gt 0 ]; then
    missing=0
    for mnt in "${mounts[@]}"; do
      if command -v rg >/dev/null 2>&1; then
        if mount | rg -F "on ${mnt}" >/dev/null 2>&1; then
          :
        else
          missing=1
          echo "$(date '+%F %T') Mount missing: ${mnt}"
        fi
      else
        if mount | grep -F "on ${mnt}" >/dev/null 2>&1; then
          :
        else
          missing=1
          echo "$(date '+%F %T') Mount missing: ${mnt}"
        fi
      fi
    done

    if [ "$missing" -eq 1 ]; then
      echo "$(date '+%F %T') Attempting remount..."
      "$SCRIPT_DIR/mount_windows.sh" mount || true
    fi
  fi

  sleep "$INTERVAL"
done
