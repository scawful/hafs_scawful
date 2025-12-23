#!/bin/bash
# Remove the Windows SSH/mount watchdog LaunchAgent.

set -euo pipefail

PLIST_PATH="$HOME/Library/LaunchAgents/com.hafs.watch-windows.plist"

if [ -f "$PLIST_PATH" ]; then
  launchctl bootout "gui/${UID}" "$PLIST_PATH" >/dev/null 2>&1 || true
  rm -f "$PLIST_PATH"
  echo "Removed LaunchAgent: $PLIST_PATH"
else
  echo "LaunchAgent not found: $PLIST_PATH"
fi
