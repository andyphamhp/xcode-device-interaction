#!/bin/zsh
# Usage: syn.sh "<command or empty>" [shot-name]
# Env: XMCP_SESSION (session key), XMCP_SHOTS (folder for named screenshots), XMCP_APP (bundle id to bring forward, optional)
DIR=${0:A:h}
SESSION=${XMCP_SESSION:?set XMCP_SESSION to the session key}
SHOTS=${XMCP_SHOTS:-${TMPDIR:-/tmp}/xmcp-shots}
CMD="$1"
NAME="$2"
ARGS=$(python3 -I -c "
import json,sys,os
a={'interactSessionKey':sys.argv[1]}
if sys.argv[2]: a['interactionCommand']=sys.argv[2]
if os.environ.get('XMCP_APP'): a['activationBundleId']=os.environ['XMCP_APP']
print(json.dumps(a))" "$SESSION" "$CMD")
OUT=$(python3 -I $DIR/xmcp.py DeviceInteractionSynthesize "$ARGS" | head -1)
H=$(echo "$OUT" | python3 -I -c "import json,sys;print(json.load(sys.stdin).get('hierarchyPath',''))" 2>/dev/null)
P=$(echo "$OUT" | python3 -I -c "import json,sys;print(json.load(sys.stdin).get('screenshotPath',''))" 2>/dev/null)
if [ -z "$H" ]; then echo "$OUT"; exit 1; fi
mkdir -p $SHOTS
cp "$P" $SHOTS/last.png
if [ -n "$NAME" ]; then cp "$P" $SHOTS/$NAME.png; echo "shot: $SHOTS/$NAME.png"; fi
cat "$H"
