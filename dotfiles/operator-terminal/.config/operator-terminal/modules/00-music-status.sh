#!/usr/bin/env bash
MPD_HOST="/run/user/1002/mpd/socket"
STATUS=$(mpc --host "$MPD_HOST" status 2>/dev/null)
CURRENT=$(mpc --host "$MPD_HOST" current 2>/dev/null)

if [[ -z "$CURRENT" ]]; then
    echo "[♪] MPD: stopped"
else
    STATE=$(echo "$STATUS" | grep -oP '\[\K[^\]]+')
    ELAPSED=$(echo "$STATUS" | grep -oP '\d+:\d+(?=/)' | head -1)
    TOTAL=$(echo "$STATUS" | grep -oP '(?<=/)\d+:\d+' | head -1)
    echo "[🎧] Now: ${CURRENT} (${STATE} ${ELAPSED}/${TOTAL})"
fi
