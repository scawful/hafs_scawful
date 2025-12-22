#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HALEXT_HOST="${HALEXT_HOST:-halext-server}"
HALEXT_DIR="${HALEXT_DIR:-/home/halext/hafs_scawful}"

WINDOWS_HOST="${WINDOWS_HOST:-medical-mechanica}"
WINDOWS_DIR="${WINDOWS_DIR:-C:/hafs_scawful}"

SYNC_ALL="${SYNC_ALL:-0}"

items=("config" "docs")
if [ "$SYNC_ALL" = "1" ]; then
  items+=("scripts")
fi

if ! command -v ssh >/dev/null; then
  echo "Error: ssh not found"
  exit 1
fi

if ! command -v rsync >/dev/null; then
  echo "Error: rsync not found"
  exit 1
fi

echo "==> Syncing to halext-server: $HALEXT_HOST:$HALEXT_DIR"
ssh "$HALEXT_HOST" "mkdir -p '$HALEXT_DIR'"
for item in "${items[@]}"; do
  rsync -av "$SOURCE_DIR/$item" "$HALEXT_HOST:$HALEXT_DIR/"
done

echo "==> Syncing to Windows host: $WINDOWS_HOST:$WINDOWS_DIR"
ssh "$WINDOWS_HOST" "powershell -Command \"New-Item -ItemType Directory -Force -Path '$WINDOWS_DIR' | Out-Null\""
for item in "${items[@]}"; do
  scp -r "$SOURCE_DIR/$item" "$WINDOWS_HOST:$WINDOWS_DIR/"
done

echo "Done."
