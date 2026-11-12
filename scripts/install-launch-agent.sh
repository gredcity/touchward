#!/bin/bash
# Supervise the app through LaunchServices so it keeps its own TCC identity.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/appconfig.sh

AGENT_PATH="$HOME/Library/LaunchAgents/${BUNDLE_ID}.plist"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
export TOUCHWARD_AGENT_PATH="$AGENT_PATH"
export TOUCHWARD_APP_PATH="/Applications/${APP_NAME}.app"
export TOUCHWARD_BUNDLE_ID="$BUNDLE_ID"
# Preserve the existing display mapping; do not guess another monitor during updates.
/usr/bin/python3 - <<'PY'
import os, plistlib
path = os.environ['TOUCHWARD_AGENT_PATH']
arguments = ['/usr/bin/open', '--wait-apps', '--env',
             'TOUCHWARD_DISPLAY_ID=1', '-a', os.environ['TOUCHWARD_APP_PATH']]
if os.path.exists(path):
    with open(path, 'rb') as f:
        old = plistlib.load(f)
    for argument in old.get('ProgramArguments', []):
        if argument.startswith('TOUCHWARD_DISPLAY_ID='):
            arguments[3] = argument
            break
log = os.path.expanduser('~/Library/Logs/Touchward-startup.log')
with open(path, 'wb') as f:
    plistlib.dump({
        'Label': os.environ['TOUCHWARD_BUNDLE_ID'],
        'LimitLoadToSessionType': 'Aqua', 'ProcessType': 'Interactive',
        'ProgramArguments': arguments, 'RunAtLoad': True,
        'KeepAlive': True, 'ThrottleInterval': 10,
        'StandardOutPath': log, 'StandardErrorPath': log,
    }, f)
PY
launchctl bootout "gui/$(id -u)/${BUNDLE_ID}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT_PATH"
echo "✓ Login and automatic recovery enabled for ${APP_NAME}"
