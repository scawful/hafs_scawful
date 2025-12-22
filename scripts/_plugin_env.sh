#!/bin/bash
# Load hAFS plugin environment variables for standalone scripts.

HAFS_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAFS_PLUGIN_CONFIG="${HAFS_PLUGIN_CONFIG:-$HAFS_PLUGIN_DIR/config.toml}"

if [ -f "$HAFS_PLUGIN_CONFIG" ]; then
  eval "$(
    HAFS_PLUGIN_CONFIG="$HAFS_PLUGIN_CONFIG" python3 - <<'PY'
import os
import shlex
import tomllib
from pathlib import Path

path = Path(os.environ["HAFS_PLUGIN_CONFIG"])
with path.open("rb") as handle:
    data = tomllib.load(handle)

env = data.get("env", {})
for key, value in env.items():
    if value is None:
        continue
    print(f'export {key}={shlex.quote(str(value))}')
PY
  )"
fi
