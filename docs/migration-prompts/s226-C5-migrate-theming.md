# Task S226-C5: Migrate Theming matugen → Aether

**Phase:** C (Config Migration)
**Model:** Spark-X2.5-4B (code generation, architecture)
**Harness:** Pi (interactive — large file, may need iteration)
**Estimated context:** ~20K tokens
**Priority:** 2 (critical for visual correctness)

---

## Background

`scripts/matugen-sync.sh` (410 lines) is the core theming pipeline. It:
1. Calls `matugen image <wallpaper>` to generate Material You colors
2. Exports colors to `/tmp/matugen/colors.json`
3. Transforms colors to Catppuccin-like format for quickshell → `/tmp/qs_colors.json`
4. Writes Niri border colors → `~/.config/niri/includes/colors.kdl`
5. Writes Fuzzel launcher colors → `~/.config/fuzzel/colors.ini`
6. Writes Firefox theme → `~/.mozilla/firefox/*/chrome/userChrome.css`
7. Appends Ghostty colors → `~/.config/ghostty/config`
8. Appends Starship colors → `~/.config/starship.toml`
9. Injects Fastfetch colors → `~/.config/fastfetch/config.jsonc`
10. Copies generated configs for: kitty, rofi, GTK, Neovim, Qt5ct, Qt6ct, Qt style, cava, swayosd, mako, hyprlock, waybar, btop
11. Exports env vars → `~/.config/environment.d/98-matugen.conf`

**Aether** is Omarchy's theming system. It uses `omarchy theme set <wallpaper>` to extract colors from an image. The colors are available via Omarchy's theme API or via a generated colors file.

The goal: rewrite `matugen-sync.sh` as `aether-sync.sh` that uses Aether's color extraction but produces the same output targets (Ghostty, Starship, Firefox, Waybar, etc.).

## Input: matugen-sync.sh (410 lines — full content included)

```bash
#!/bin/bash
# matugen-sync.sh - Wallpaper to theme pipeline for NightForge
# Generates colors from wallpaper, exports env vars, syncs all configs
# Usage: ./matugen-sync.sh [wallpaper_path]
# Matugen v4 syntax: matugen image <path> | matugen color hex <hex>

set -euo pipefail

# === CONFIGURATION ===
WALLPAPER="${1:-}"
FALLBACK_COLOR="${MATUGEN_FALLBACK:-#1a1b26}"
MATUGEN_BIN="/usr/sbin/matugen"
CONFIG_PATH="$HOME/.config/matugen/config.toml"
TMP_DIR="/tmp/matugen"
ENV_FILE="$HOME/.config/environment.d/98-matugen.conf"
BACKUP_DIR="$HOME/.local/share/matugen/backups"

log_info()  { echo "[+] $*"; }
log_warn()  { echo "[!] $*"; }
log_error() { echo "[-] $*"; }

check_matugen() {
    if [[ ! -x "$MATUGEN_BIN" ]]; then
        log_error "matugen not found at $MATUGEN_BIN"
        exit 1
    fi
}

run_matugen() {
    local source="$1"
    mkdir -p "$TMP_DIR"
    if [[ -f "$source" ]]; then
        log_info "Generating theme from wallpaper: $source"
        "$MATUGEN_BIN" image "$source" --source-color-index 0
    else
        log_warn "No wallpaper found, using fallback color: $FALLBACK_COLOR"
        "$MATUGEN_BIN" color hex "$FALLBACK_COLOR"
    fi
}

backup_existing() {
    local file="$1"
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup
        backup="$BACKUP_DIR/$(basename "$file").$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $(basename "$file")"
    fi
}

copy_generated() {
    local generated="$1"
    local target="$2"
    local description="${3:-$(basename "$target")}"
    if [[ ! -f "$generated" ]]; then
        log_warn "$description not generated, skipping"
        return
    fi
    mkdir -p "$(dirname "$target")"
    if [[ -L "$target" ]]; then
        rm "$target"
    fi
    backup_existing "$target"
    cp "$generated" "$target"
    log_info "Updated $description"
}

append_ghostty_colors() {
    local ghostty_config="$HOME/.config/ghostty/config"
    local generated="$TMP_DIR/ghostty-colors.conf"
    if [[ ! -f "$generated" ]]; then
        log_warn "ghostty colors not generated, skipping"
        return
    fi
    mkdir -p "$(dirname "$ghostty_config")"
    if [[ -f "$ghostty_config" ]]; then
        local tmp_ghostty
        tmp_ghostty="$(mktemp)"
        awk '/^# === Matugen Colors BEGIN ===$/{skip=1;next} /^# === Matugen Colors END ===$/{skip=0;next} !skip{print}' "$ghostty_config" > "$tmp_ghostty"
        mv "$tmp_ghostty" "$ghostty_config"
    fi
    {
        echo ""
        echo "# === Matugen Colors BEGIN ==="
        cat "$generated"
        echo "# === Matugen Colors END ==="
    } >> "$ghostty_config"
    log_info "Updated ghostty config"
}

append_starship_colors() {
    # (similar to ghostty — appends starship.toml block)
}

inject_fastfetch_colors() {
    # (Python script to merge colors into fastfetch config)
}

export_env_vars() {
    # (jq to parse colors.json → environment.d env vars)
}

# === MAIN ===
check_matugen
check_config || true

# Resolve wallpaper path
if [[ -z "$WALLPAPER" ]]; then
    WALLPAPER="${HOME}/.cache/current_wallpaper"
    if [[ -f "$WALLPAPER" ]]; then
        WALLPAPER=$(cat "$WALLPAPER")
    else
        WALLPAPER=""
    fi
fi

run_matugen "$WALLPAPER"

# --- Quickshell Colors ---
# Transform matugen output → Catppuccin-like format for QML
jq -r '...' "$TMP_DIR/colors.json" > /tmp/qs_colors.json

# --- Niri Window Border Colors --- (REMOVE — no Hyprland equivalent)
# --- Fuzzel Launcher Colors ---
# --- Firefox Browser Theme ---
# --- Core outputs --- (kitty, rofi, gtk, nvim, qt5ct, qt6ct, cava, swayosd, mako, hyprlock, waybar, btop)
# --- Export env vars ---
```

The full script (410 lines) handles 15+ output targets. Each target reads from `$TMP_DIR/colors.json` which matugen generates with this schema:

```json
{
  "colors": {
    "primary": "#cba6f7",
    "surface": "#1e1e2e",
    "onSurface": "#cdd6f4",
    "outline": "#6c7086",
    "surfaceVariant": "#313244",
    "error": "#f38ba8",
    "secondary": "#89b4fa",
    "tertiary": "#fab387"
  }
}
```

## Aether Theming API

Aether is Omarchy's theming system. Key commands:

```bash
# Generate theme from wallpaper
omarchy theme set <wallpaper_path> -m dark

# List available themes
omarchy theme list

# Get current colors as JSON
omarchy theme get-colors

# Colors are written to:
#   ~/.cache/omarchy/colors.json  (Aether's color file)
#   ~/.config/environment.d/99-omarchy-theme.conf  (env vars)
```

Aether's colors.json schema (different from matugen):
```json
{
  "dark": {
    "primary": "#cdd6f4",
    "secondary": "#bac8f7",
    "tertiary": "#a6e3a1",
    "background": "#1e1e2e",
    "surface": "#313141",
    "surface_dim": "#181824",
    "on_surface": "#cdd6f4",
    "on_surface_variant": "#a6adc8",
    "outline": "#6c7086",
    "error": "#f38ba8",
    "error_container": "#f38ba8",
    ...
  },
  "light": { ... }
}
```

Aether also provides a Lua API for Omarchy shell theming.

## Migration Requirements

1. **Replace** `matugen image` with `omarchy theme set`
2. **Replace** `$TMP_DIR/colors.json` reading with Aether's color source (`~/.cache/omarchy/colors.json`)
3. **Map** matugen color names → Aether color names:
   - `primary` → `secondary` (Aether scheme is reversed)
   - `surface` → `background`
   - `onSurface` → `on_surface`
   - `outline` → `outline`
   - `surfaceVariant` → `surface_dim` / `surface`
   - `error` → `error`
   - `secondary` → `secondary`
   - `tertiary` → `tertiary`

4. **Remove** Niri-specific outputs (Niri border colors, colors.kdl)
5. **Replace** quickshell colors transform with Waybar-compatible format
6. **Keep** all other outputs: ghostty, starship, firefox, fuzzel, rofi, gtk, nvim, qt5ct/qt6ct, cava, swayosd, mako, hyprlock, waybar, btop, fastfetch

## Expected Output

Create `scripts/aether-sync.sh` (new file) that:

1. Takes a wallpaper path as argument (or reads from `~/.cache/current_wallpaper`)
2. Calls `omarchy theme set <wallpaper> -m dark` to generate theme
3. Reads colors from `~/.cache/omarchy/colors.json`
4. Generates all the same output targets as matugen-sync.sh, but with:
   - Color field mapping from Aether → matugen-compatible names
   - Niri colors.kdl generation REMOVED
   - Quickshell color transform → Waybar-compatible format
5. Exports env vars to `~/.config/environment.d/99-omarchy-theme.conf` (replacing 98-matugen.conf)
6. Has same logging functions (log_info, log_warn, log_error)
7. Has same backup_existing and copy_generated helpers

Also update:
- Rename references from "matugen" to "aether" in env var names where appropriate
- Update the script to be called from Hyprland autostart (Task C4)

## Acceptance Criteria

- `aether-sync.sh` is a drop-in replacement for `matugen-sync.sh`
- Uses `omarchy theme set` instead of `matugen image`
- Reads Aether colors from `~/.cache/omarchy/colors.json`
- All 15+ output targets maintained (minus Niri colors.kdl)
- Color name mapping is correct (matugen field → Aether field)
- `bash -n aether-sync.sh` passes syntax check
- Logging and error handling match the original pattern
- Env file path updated to `99-omarchy-theme.conf`

## Rollback

Keep the original `matugen-sync.sh` intact. Create `aether-sync.sh` as a new file.