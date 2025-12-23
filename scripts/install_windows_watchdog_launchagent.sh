#!/bin/bash
# Install a LaunchAgent to keep the Windows SSH/mount watchdog running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_PATH="$HOME/Library/LaunchAgents/com.hafs.watch-windows.plist"
INTERVAL="${1:-60}"
WATCH_SCRIPT="$SCRIPT_DIR/watch_windows_connections.sh"

if [ ! -x "$WATCH_SCRIPT" ]; then
  echo "Missing watchdog script: $WATCH_SCRIPT"
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"

cat >"$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.hafs.watch-windows</string>
  <key>ProgramArguments</key>
  <array>
    <string>${WATCH_SCRIPT}</string>
    <string>${INTERVAL}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/hafs-watch-windows.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/hafs-watch-windows.err</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/${UID}" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "gui/${UID}" "$PLIST_PATH"
launchctl enable "gui/${UID}/com.hafs.watch-windows"

echo "Installed LaunchAgent: $PLIST_PATH"
