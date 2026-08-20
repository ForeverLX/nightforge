#!/usr/bin/env bash
# Gather operations data for Settings
echo "NET=$(ip -4 addr show | awk '/inet /{print $2}' | head -1)"
echo "WG=$(ip link show wg0 2>/dev/null | grep -q UP && echo Connected || echo Disconnected)"
echo "DNS=$(resolvectl status 2>/dev/null | grep 'DNS Servers' | awk '{print $NF}' | head -1 || echo '--')"
echo "CT=$(podman ps -q 2>/dev/null | wc -l)"
echo "VM=$(virsh list --state-running --name 2>/dev/null | grep -c . || echo 0)"
echo "UP=$(awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); print d"d "h"h "m"m"}' /proc/uptime 2>/dev/null || echo '--')"
