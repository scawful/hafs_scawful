#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLUGIN_CONFIG="${PLUGIN_CONFIG:-$SOURCE_DIR/config.toml}"

if [ -f "$PLUGIN_CONFIG" ]; then
  eval "$(
    PLUGIN_CONFIG="$PLUGIN_CONFIG" python3 - <<'PY'
import os
import shlex
import tomllib
from pathlib import Path

path = Path(os.environ["PLUGIN_CONFIG"])
with path.open("rb") as handle:
    data = tomllib.load(handle)

sync = data.get("sync", {})
mapping = {
    "halext_host": "CONFIG_HALEXT_HOST",
    "halext_dir": "CONFIG_HALEXT_DIR",
    "halext_mount": "CONFIG_HALEXT_MOUNT",
    "windows_host": "CONFIG_WINDOWS_HOST",
    "windows_dir": "CONFIG_WINDOWS_DIR",
    "windows_mount_c": "CONFIG_WINDOWS_MOUNT_C",
    "sync_items": "CONFIG_SYNC_ITEMS",
    "sync_all": "CONFIG_SYNC_ALL",
    "use_mounts": "CONFIG_USE_MOUNTS",
}

for key, out in mapping.items():
    if key not in sync:
        continue
    value = sync[key]
    if isinstance(value, bool):
        value = "1" if value else "0"
    elif isinstance(value, list):
        value = ",".join(str(item) for item in value)
    print(f'{out}={shlex.quote(str(value))}')
PY
  )"
fi

HALEXT_HOST="${HALEXT_HOST:-${CONFIG_HALEXT_HOST:-halext-server}}"
HALEXT_DIR="${HALEXT_DIR:-${CONFIG_HALEXT_DIR:-/home/halext/hafs_scawful}}"

WINDOWS_HOST="${WINDOWS_HOST:-${CONFIG_WINDOWS_HOST:-medical-mechanica}}"
WINDOWS_DIR="${WINDOWS_DIR:-${CONFIG_WINDOWS_DIR:-C:/hafs_scawful}}"

HALEXT_MOUNT="${HALEXT_MOUNT:-${CONFIG_HALEXT_MOUNT:-/Users/scawful/Mounts/halext}}"
WINDOWS_MOUNT_C="${WINDOWS_MOUNT_C:-${CONFIG_WINDOWS_MOUNT_C:-/Users/scawful/Mounts/mm-c}}"

SYNC_ALL="${SYNC_ALL:-${CONFIG_SYNC_ALL:-0}}"
SYNC_ITEMS="${SYNC_ITEMS:-${CONFIG_SYNC_ITEMS:-config,docs,config.toml,aliases.sh}}"
DRY_RUN="${DRY_RUN:-0}"
USE_MOUNTS="${USE_MOUNTS:-${CONFIG_USE_MOUNTS:-1}}"

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
