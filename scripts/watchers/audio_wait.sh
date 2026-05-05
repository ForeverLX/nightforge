#!/bin/bash
# Blocks until audio sink changes, then exits
pactl subscribe 2>/dev/null | grep --line-buffered "Event 'change' on sink" | head -1
