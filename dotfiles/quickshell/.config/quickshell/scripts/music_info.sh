#!/bin/bash
# Music info via MPRIS with album art color extraction
# Outputs JSON with player metadata

player="$(playerctl -l 2>/dev/null | head -1)"
if [ -z "$player" ]; then
    echo '{"playing": false}'
    exit 0
fi

status=$(timeout 2 playerctl -p "$player" status 2>/dev/null || echo "Stopped")
title=$(timeout 2 playerctl -p "$player" metadata title 2>/dev/null || echo "")
artist=$(timeout 2 playerctl -p "$player" metadata artist 2>/dev/null || echo "")
album=$(timeout 2 playerctl -p "$player" metadata album 2>/dev/null || echo "")
artUrl=$(timeout 2 playerctl -p "$player" metadata mpris:artUrl 2>/dev/null || echo "")

playing="false"
[ "$status" = "Playing" ] && playing="true"

# Extract dominant colors from album art using ImageMagick if available
colors_json="[]"
if [ "$playing" = "true" ] && [ -n "$artUrl" ] && command -v convert &>/dev/null; then
    # Create a hash of the art URL for caching
    artHash=$(echo "$artUrl" | md5sum | cut -d' ' -f1)
    cacheFile="/tmp/qs_music_colors_$artHash"

    if [ -f "$cacheFile" ]; then
        colors_json=$(cat "$cacheFile")
    else
        # Download art to temp file
        artTmp="/tmp/qs_art_$$.jpg"
        if [[ "$artUrl" =~ ^file:// ]]; then
            artPath="${artUrl#file://}"
            if [ -f "$artPath" ]; then
                colors_json=$(convert "$artPath" -resize 1x1\! -format '%[pixel:p{0,0}]' info:- 2>/dev/null | \
                    sed 's/.*(\(.*\)).*/["\1"]/' | \
                    sed 's/srgb/srgb/;s/"/\\"/g')
                if [ -z "$colors_json" ] || [ "$colors_json" = "[]" ]; then
                    # Get top 3 colors instead
                    colors_json=$(convert "$artPath" -colors 3 -format '%c' histogram:info:- 2>/dev/null | \
                        awk '{print $NF}' | sed 's/.*/#&/' | \
                        awk 'BEGIN{printf "["} {printf "%s\"%s\"", sep, $1; sep=","} END{printf "]"}')
                fi
                echo "$colors_json" > "$cacheFile"
            fi
        else
            # Remote URL - skip or use wget/curl
            colors_json='["#000000"]'
        fi
        rm -f "$artTmp"
    fi
fi

# Escape special characters for JSON
title_esc=$(echo "$title" | sed 's/"/\\"/g' | sed "s/\t/ /g" | tr -d '\n')
artist_esc=$(echo "$artist" | sed 's/"/\\"/g' | sed "s/\t/ /g" | tr -d '\n')
album_esc=$(echo "$album" | sed 's/"/\\"/g' | sed "s/\t/ /g" | tr -d '\n')
artUrl_esc=$(echo "$artUrl" | sed 's/"/\\"/g' | sed "s/\t/ /g" | tr -d '\n')

cat <<JSON
{"playing": $playing, "title": "$title_esc", "artist": "$artist_esc", "album": "$album_esc", "artUrl": "$artUrl_esc", "colors": $colors_json}
JSON
