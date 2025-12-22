#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HALEXT_HOST="${HALEXT_HOST:-halext-server}"
HALEXT_DIR="${HALEXT_DIR:-/home/halext/hafs_scawful}"

WINDOWS_HOST="${WINDOWS_HOST:-medical-mechanica}"
WINDOWS_DIR="${WINDOWS_DIR:-C:/hafs_scawful}"

HALEXT_MOUNT="${HALEXT_MOUNT:-/Users/scawful/Mounts/halext}"
WINDOWS_MOUNT_C="${WINDOWS_MOUNT_C:-/Users/scawful/Mounts/mm-c}"

SYNC_ALL="${SYNC_ALL:-0}"
SYNC_ITEMS="${SYNC_ITEMS:-config,docs}"
DRY_RUN="${DRY_RUN:-0}"
USE_MOUNTS="${USE_MOUNTS:-1}"

IFS=',' read -r -a items <<< "$SYNC_ITEMS"
if [ "$SYNC_ALL" = "1" ]; then
  items+=("scripts")
fi

if [ "$USE_MOUNTS" != "1" ]; then
  if ! command -v ssh >/dev/null; then
    echo "Error: ssh not found"
    exit 1
  fi
fi


if [ "$USE_MOUNTS" = "1" ] && [ -d "$HALEXT_MOUNT" ]; then
  DEST="$HALEXT_MOUNT/hafs_scawful"
  echo "==> Syncing to halext mount: $DEST"
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY RUN: would create $DEST and copy items: ${items[*]}"
  else
    mkdir -p "$DEST"
    for item in "${items[@]}"; do
      cp -R "$SOURCE_DIR/$item" "$DEST/"
    done
  fi
else
  echo "==> Syncing to halext-server: $HALEXT_HOST:$HALEXT_DIR"
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY RUN: would create $HALEXT_DIR and scp items: ${items[*]}"
  else
    ssh "$HALEXT_HOST" "mkdir -p '$HALEXT_DIR'"
    for item in "${items[@]}"; do
      scp -r "$SOURCE_DIR/$item" "$HALEXT_HOST:$HALEXT_DIR/"
    done
  fi
fi

if [ "$USE_MOUNTS" = "1" ] && [ -d "$WINDOWS_MOUNT_C" ]; then
  DEST="$WINDOWS_MOUNT_C/hafs_scawful"
  echo "==> Syncing to Windows mount: $DEST"
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY RUN: would create $DEST and copy items: ${items[*]}"
  else
    mkdir -p "$DEST"
    for item in "${items[@]}"; do
      cp -R "$SOURCE_DIR/$item" "$DEST/"
    done
  fi
else
  echo "==> Syncing to Windows host: $WINDOWS_HOST:$WINDOWS_DIR"
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY RUN: would create $WINDOWS_DIR and scp items: ${items[*]}"
  else
    ssh "$WINDOWS_HOST" "powershell -Command \"New-Item -ItemType Directory -Force -Path '$WINDOWS_DIR' | Out-Null\""
    for item in "${items[@]}"; do
      scp -r "$SOURCE_DIR/$item" "$WINDOWS_HOST:$WINDOWS_DIR/"
    done
  fi
fi

echo "Done."
