#!/bin/bash
# Battery state fetch script
# Outputs JSON with main battery and peripheral battery info

main_pct=""
main_status="Unknown"
main_exists=false

# Main battery (typically BAT0 or BAT1)
for bat in /sys/class/power_supply/BAT*; do
    if [ -d "$bat" ]; then
        main_exists=true
        main_pct=$(cat "$bat/capacity" 2>/dev/null || echo "0")
        main_status=$(cat "$bat/status" 2>/dev/null || echo "Unknown")
        break
    fi
done

# Check if we're on AC power (no battery at all)
on_ac=false
if ! $main_exists; then
    main_pct=100
    main_status="Charging"
    on_ac=true
fi

# Peripheral batteries (hidpp_*, mouse, keyboard, etc.)
peripherals_json="["
first=true
for periph in /sys/class/power_supply/hidpp_* /sys/class/power_supply/ps_*; do
    if [ -d "$periph" ]; then
        name=$(basename "$periph")
        pct=$(cat "$periph/capacity" 2>/dev/null || echo "0")
        [ "$first" = false ] && peripherals_json+=", "
        peripherals_json+="{\"name\": \"$name\", \"pct\": $pct}"
        first=false
    fi
done
peripherals_json+="]"

# Also check for other battery types
for other in /sys/class/power_supply/*/capacity; do
    dir=$(dirname "$other")
    name=$(basename "$dir")
    # Skip main batteries already handled
    [[ "$name" =~ ^BAT ]] && continue
    [[ "$name" =~ ^hidpp_ ]] && continue
    [[ "$name" =~ ^ps_ ]] && continue
    # Skip non-battery devices
    type=$(cat "$dir/type" 2>/dev/null || echo "")
    [ "$type" != "Battery" ] && continue

    pct=$(cat "$other" 2>/dev/null || echo "0")
    [ "$first" = false ] && peripherals_json+=", "
    peripherals_json+="{\"name\": \"$name\", \"pct\": $pct}"
    first=false
done
peripherals_json+="]"

if $on_ac; then
    cat <<JSON
{"main": {"pct": $main_pct, "status": "AC"}, "peripherals": $peripherals_json}
JSON
else
    cat <<JSON
{"main": {"pct": $main_pct, "status": "$main_status"}, "peripherals": $peripherals_json}
JSON
fi
