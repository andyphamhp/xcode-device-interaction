#!/bin/zsh
# Created by Andy
# Usage: scroll.sh <down|up> [fast|slow] [x] [shot-name]
#   down = show content further down (finger moves up); up = show content above.
#   fast = flick with momentum (many rows); slow = drag, moves about 500 pt with no momentum (default).
# Points assume a 402x874 screen (6.3" iPhone); x defaults to the middle of the screen.
DIR=${0:A:h}
DIRECTION="$1"; SPEED=${2:-slow}; X=${3:-201}; NAME="$4"
if [ "$DIRECTION" = "down" ]; then FROM=750; TO=250
elif [ "$DIRECTION" = "up" ]; then FROM=250; TO=750
else echo "usage: scroll.sh <down|up> [fast|slow] [x] [shot-name]"; exit 1; fi
if [ "$SPEED" = "fast" ]; then CMD="mt [$X $FROM] 0.15 [$X $TO] 0.05"
else CMD="mt [$X $FROM] 0.6 [$X $TO] 0.5"; fi
$DIR/syn.sh "$CMD" >/dev/null
$DIR/syn.sh "w 0.8" $NAME
