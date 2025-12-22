#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HALEXT_HOST="${HALEXT_HOST:-halext-server}"
HALEXT_DIR="${HALEXT_DIR:-/home/halext/hafs_scawful}"

WINDOWS_HOST="${WINDOWS_HOST:-medical-mechanica}"
WINDOWS_DIR="${WINDOWS_DIR:-C:/hafs_scawful}"

SYNC_ALL="${SYNC_ALL:-0}"
SYNC_ITEMS="${SYNC_ITEMS:-config,docs}"
DRY_RUN="${DRY_RUN:-0}"

IFS=',' read -r -a items <<< "$SYNC_ITEMS"
if [ "$SYNC_ALL" = "1" ]; then
  items+=("scripts")
fi

if ! command -v ssh >/dev/null; then
  echo "Error: ssh not found"
  exit 1
fi


echo "==> Syncing to halext-server: $HALEXT_HOST:$HALEXT_DIR"
if [ "$DRY_RUN" = "1" ]; then
  echo "DRY RUN: would create $HALEXT_DIR and scp items: ${items[*]}"
else
  ssh "$HALEXT_HOST" "mkdir -p '$HALEXT_DIR'"
  for item in "${items[@]}"; do
    scp -r "$SOURCE_DIR/$item" "$HALEXT_HOST:$HALEXT_DIR/"
  done
fi

echo "==> Syncing to Windows host: $WINDOWS_HOST:$WINDOWS_DIR"
if [ "$DRY_RUN" = "1" ]; then
  echo "DRY RUN: would create $WINDOWS_DIR and scp items: ${items[*]}"
else
  ssh "$WINDOWS_HOST" "powershell -Command \"New-Item -ItemType Directory -Force -Path '$WINDOWS_DIR' | Out-Null\""
  for item in "${items[@]}"; do
    scp -r "$SOURCE_DIR/$item" "$WINDOWS_HOST:$WINDOWS_DIR/"
  done
fi

echo "Done."
