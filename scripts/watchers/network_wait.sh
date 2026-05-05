#!/bin/bash
# Blocks until network manager reports a change
nmcli monitor 2>/dev/null | grep --line-buffered -E "(connecting|connected|disconnected)" | head -1
