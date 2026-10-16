#!/bin/zsh
# Usage: type.sh "<text>"   — sets the text of the focused field (tap it first) and fires textDidChange.
# Env: XMCP_APP (bundle id of the app under test, required).
APP=${XMCP_APP:?set XMCP_APP to the app bundle id}
TEXT="$1"
PID=$(xcrun simctl spawn booted launchctl list 2>/dev/null | awk -v a="$APP" '$3 ~ a {print $1}' | head -1)
[ -z "$PID" ] || [ "$PID" = "-" ] && { echo "app $APP is not running"; exit 1; }
ESCAPED=$(printf '%s' "$TEXT" | sed 's/\\/\\\\/g; s/"/\\"/g')
FR='[[[UIApplication sharedApplication] keyWindow] performSelector:@selector(firstResponder)]'
OUT=$(xcrun lldb -p "$PID" -b \
  -o "expr -l objc -- (void)[(UITextField *)$FR setText:@\"$ESCAPED\"]" \
  -o "expr -l objc -- (void)[[NSNotificationCenter defaultCenter] postNotificationName:@\"UITextFieldTextDidChangeNotification\" object:$FR]" \
  -o detach 2>&1)
if echo "$OUT" | grep -q "already being debugged"; then
  echo "pid $PID is under Xcode's debugger: relaunch with 'xcrun simctl terminate booted $APP; xcrun simctl launch booted $APP'"; exit 1
fi
echo "$OUT" | grep -E "^error" | head -3
echo "typed into pid $PID"
