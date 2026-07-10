#!/bin/bash

# DateTime - displays date and time together

CURRENT_TIME="$(python3 - <<'PY'
from datetime import datetime
print(datetime.now().strftime("%a %d %b %H:%M"))
PY
)"

sketchybar --set "$NAME" label="$CURRENT_TIME"
