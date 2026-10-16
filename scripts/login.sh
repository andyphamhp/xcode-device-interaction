#!/bin/zsh
# Usage: login.sh — fills a login screen and taps the login button, then dismisses "Save Password?".
# Env: XMCP_SESSION, XMCP_SHOTS, XMCP_APP (same as syn.sh)
#      XMCP_LOGIN_EMAIL     account email (required)
#      XMCP_LOGIN_PASSWORD  password (required; never printed — e.g. export it from your keychain)
#      XMCP_LOGIN_EMAIL_FIELD / XMCP_LOGIN_PASSWORD_FIELD  placeholder texts (default Email / Password)
#      XMCP_LOGIN_BUTTON    button label (default Login)
DIR=${0:A:h}
EMAIL=${XMCP_LOGIN_EMAIL:?set XMCP_LOGIN_EMAIL}
PW=${XMCP_LOGIN_PASSWORD:?set XMCP_LOGIN_PASSWORD}
EMAIL_FIELD=${XMCP_LOGIN_EMAIL_FIELD:-Email}
PW_FIELD=${XMCP_LOGIN_PASSWORD_FIELD:-Password}
BUTTON=${XMCP_LOGIN_BUTTON:-Login}
HIER=$($DIR/syn.sh "")
point() { echo "$HIER" | grep -E "$1" | head -1 | sed -E 's/.*hitPoint: \{([0-9.]+), ([0-9.]+)\}.*/\1 \2/'; }
EMAIL_AT=$(point "TextField.*placeholderValue: '$EMAIL_FIELD'")
PW_AT=$(point "SecureTextField.*placeholderValue: '$PW_FIELD'")
LOGIN_AT=$(point "Button.*label: '$BUTTON'")
[ -z "$EMAIL_AT" ] || [ -z "$PW_AT" ] || [ -z "$LOGIN_AT" ] && { echo "login screen not found"; exit 1; }
$DIR/syn.sh "t $EMAIL_AT" >/dev/null; $DIR/type.sh "$EMAIL" >/dev/null
$DIR/syn.sh "t $PW_AT" >/dev/null; $DIR/type.sh "$PW" >/dev/null
unset PW
$DIR/syn.sh "t $LOGIN_AT" >/dev/null
AFTER=$($DIR/syn.sh "w 6")
NOTNOW=$(echo "$AFTER" | grep -E "Button.*label: 'Not Now'" | head -1 | sed -E 's/.*hitPoint: \{([0-9.]+), ([0-9.]+)\}.*/\1 \2/')
[ -n "$NOTNOW" ] && $DIR/syn.sh "t $NOTNOW" >/dev/null
echo "login submitted — capture with syn.sh \"\" to check the next screen"
