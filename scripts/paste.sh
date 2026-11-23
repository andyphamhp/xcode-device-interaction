#!/bin/zsh
# Created by Andy
# Usage: paste.sh "<text>" <x> <y> [shot-name]
# Real typing: puts <text> on the Mac + simulator clipboards, long-presses the field at (x, y),
# taps the app's own Paste menu item, then restores the Mac clipboard.
# Fires the field's real text-change events (UISearchBar filters, Save buttons appear) with no lldb.
# Env: XMCP_SESSION, XMCP_SHOTS, XMCP_APP (see syn.sh); XMCP_UDID (default: booted).
DIR=${0:A:h}
TEXT="$1"; X="$2"; Y="$3"; NAME="$4"
[ -z "$TEXT" ] || [ -z "$X" ] || [ -z "$Y" ] && { echo "usage: paste.sh <text> <x> <y> [shot-name]"; exit 1; }
UDID=${XMCP_UDID:-booted}
BACKUP=$(mktemp)
pbpaste > "$BACKUP"
printf '%s' "$TEXT" | pbcopy
printf '%s' "$TEXT" | xcrun simctl pbcopy "$UDID"
MENU=$($DIR/syn.sh "t $X $Y 1.0")
PASTE=$(echo "$MENU" | grep -E "MenuItem, .*label: 'Paste'" | head -1 | sed -E "s/.*hitPoint: \{([0-9.]+), ([0-9.]+)\}.*/\1 \2/")
if [ -z "$PASTE" ]; then
  pbcopy < "$BACKUP"; rm -f "$BACKUP"
  echo "no Paste menu item after long-press at $X $Y (wrong field, or menu not shown yet)"; exit 1
fi
$DIR/syn.sh "t $PASTE" >/dev/null
pbcopy < "$BACKUP"; rm -f "$BACKUP"
$DIR/syn.sh "w 0.8" $NAME
