#!/bin/bash
set -euo pipefail

PLUGIN_DIR="$HOME/.config/hafs/plugins"
TARGET="$PLUGIN_DIR/hafs_scawful"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PLUGIN_DIR"

if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
  echo "Error: $TARGET exists and is not a symlink."
  exit 1
fi

if [ -L "$TARGET" ]; then
  echo "Symlink already exists: $TARGET"
  exit 0
fi

ln -s "$SOURCE_DIR" "$TARGET"

echo "Installed hafs_scawful plugin at: $TARGET"
