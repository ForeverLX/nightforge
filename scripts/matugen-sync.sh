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

# === FUNCTIONS ===
log_info()  { echo "[+] $*"; }
log_warn()  { echo "[!] $*"; }
log_error() { echo "[-] $*"; }

check_matugen() {
    if [[ ! -x "$MATUGEN_BIN" ]]; then
        log_error "matugen not found at $MATUGEN_BIN"
        exit 1
    fi
}

check_config() {
    if [[ ! -f "$CONFIG_PATH" ]]; then
        log_warn "matugen config not found at $CONFIG_PATH"
        log_warn "Run: stow -d ~/nightforge/dotfiles matugen"
        return 1
    fi
    return 0
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
        local backup="$BACKUP_DIR/$(basename "$file").$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $(basename "$file")"
    fi
}

# Generic copy helper with null-safe fallback
copy_generated() {
    local generated="$1"
    local target="$2"
    local description="${3:-$(basename "$target")}"

    if [[ ! -f "$generated" ]]; then
        log_warn "$description not generated, skipping"
        return
    fi

    mkdir -p "$(dirname "$target")"

    # If target is a symlink, remove it so we don't overwrite the source
    if [[ -L "$target" ]]; then
        rm "$target"
    fi

    backup_existing "$target"
    cp "$generated" "$target"
    log_info "Updated $description"
}

# Append ghostty colors as a block
append_ghostty_colors() {
    local ghostty_config="$HOME/.config/ghostty/config"
    local generated="$TMP_DIR/ghostty-colors.conf"

    if [[ ! -f "$generated" ]]; then
        log_warn "ghostty colors not generated, skipping"
        return
    fi

    mkdir -p "$(dirname "$ghostty_config")"

    # Remove old matugen block if present
    if [[ -f "$ghostty_config" ]]; then
        local tmp_ghostty
        tmp_ghostty="$(mktemp)"
        awk '/^# === Matugen Colors BEGIN ===$/{skip=1;next} /^# === Matugen Colors END ===$/{skip=0;next} !skip{print}' "$ghostty_config" > "$tmp_ghostty"
        mv "$tmp_ghostty" "$ghostty_config"
    fi

    # Append new block
    {
        echo ""
        echo "# === Matugen Colors BEGIN ==="
        cat "$generated"
        echo "# === Matugen Colors END ==="
    } >> "$ghostty_config"

    log_info "Updated ghostty config"
}

# Append starship colors as a block (preserves base config)
append_starship_colors() {
    local starship_config="$HOME/.config/starship.toml"
    local generated="$TMP_DIR/starship-colors.toml"

    if [[ ! -f "$generated" ]]; then
        log_warn "starship colors not generated, skipping"
        return
    fi

    mkdir -p "$(dirname "$starship_config")"

    # Remove old matugen block if present
    if [[ -f "$starship_config" ]]; then
        local tmp_starship
        tmp_starship="$(mktemp)"
        awk '/^# === Matugen Colors BEGIN ===$/{skip=1;next} /^# === Matugen Colors END ===$/{skip=0;next} !skip{print}' "$starship_config" > "$tmp_starship"
        mv "$tmp_starship" "$starship_config"
    fi

    # Append new block
    {
        echo ""
        echo "# === Matugen Colors BEGIN ==="
        cat "$generated"
        echo "# === Matugen Colors END ==="
    } >> "$starship_config"

    log_info "Updated starship config"
}

# Inject fastfetch colors into user's config.jsonc (preserves dice art and other settings)
inject_fastfetch_colors() {
    local config="$HOME/.config/fastfetch/config.jsonc"
    local generated="$TMP_DIR/fastfetch-config.jsonc"

    if [[ ! -f "$generated" ]]; then
        log_warn "fastfetch colors not generated, skipping"
        return
    fi

    mkdir -p "$(dirname "$config")"

    if [[ ! -f "$config" ]]; then
        cp "$generated" "$config"
        log_info "Created fastfetch config"
        return
    fi

    python3 -c "
import json, re

with open('$generated') as f:
    colors = json.load(f)

with open('$config') as f:
    content = f.read()

# Strip JSONC comments for parsing
clean = re.sub(r'//.*', '', content)
clean = re.sub(r'/\*.*?\*/', '', clean, flags=re.DOTALL)
data = json.loads(clean)

# Merge colors
if 'logo' not in data:
    data['logo'] = {}
if 'display' not in data:
    data['display'] = {}

data['logo']['color'] = colors.get('logo', {}).get('color', {})
data['display']['color'] = colors.get('display', {}).get('color', {})

with open('$config', 'w') as f:
    json.dump(data, f, indent=4)
"

    log_info "Updated fastfetch config"
}

export_env_vars() {
    local colors_json="$TMP_DIR/colors.json"

    if [[ ! -f "$colors_json" ]]; then
        log_warn "nightforge-colors.json not generated, skipping env export"
        return
    fi

    # Null-safe jq parsing: if key missing, outputs empty string
    local primary surface on_surface outline surface_variant error secondary tertiary
    primary=$(jq -r '.colors.primary // empty' "$colors_json" 2>/dev/null || true)
    surface=$(jq -r '.colors.surface // empty' "$colors_json" 2>/dev/null || true)
    on_surface=$(jq -r '.colors.onSurface // empty' "$colors_json" 2>/dev/null || true)
    outline=$(jq -r '.colors.outline // empty' "$colors_json" 2>/dev/null || true)
    surface_variant=$(jq -r '.colors.surfaceVariant // empty' "$colors_json" 2>/dev/null || true)
    error=$(jq -r '.colors.error // empty' "$colors_json" 2>/dev/null || true)
    secondary=$(jq -r '.colors.secondary // empty' "$colors_json" 2>/dev/null || true)
    tertiary=$(jq -r '.colors.tertiary // empty' "$colors_json" 2>/dev/null || true)

    mkdir -p "$(dirname "$ENV_FILE")"
    backup_existing "$ENV_FILE"

    {
        echo "# Matugen colors — generated $(date +%Y-%m-%d_%H:%M:%S)"
        echo "MATUGEN_COLORS=$TMP_DIR/colors.json"
        echo "MATUGEN_QS_COLORS=/tmp/qs_colors.json"
        [[ -n "$primary" ]] && echo "MATUGEN_PRIMARY=$primary"
        [[ -n "$surface" ]] && echo "MATUGEN_SURFACE=$surface"
        [[ -n "$on_surface" ]] && echo "MATUGEN_ON_SURFACE=$on_surface"
        [[ -n "$outline" ]] && echo "MATUGEN_OUTLINE=$outline"
        [[ -n "$surface_variant" ]] && echo "MATUGEN_SURFACE_VARIANT=$surface_variant"
        [[ -n "$error" ]] && echo "MATUGEN_ERROR=$error"
        [[ -n "$secondary" ]] && echo "MATUGEN_SECONDARY=$secondary"
        [[ -n "$tertiary" ]] && echo "MATUGEN_TERTIARY=$tertiary"
    } > "$ENV_FILE"

    log_info "Exported colors to $ENV_FILE"
}

reload_quickshell() {
    if pgrep -x quickshell &>/dev/null; then
        pkill -x quickshell && sleep 0.5 && quickshell &
        log_info "Restarted Quickshell"
    else
        log_warn "Quickshell not running, skipping reload"
    fi
}

# === MAIN ===
check_matugen
check_config || true  # warn but don't exit

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

# qs_colors.json is now at /tmp/qs_colors.json (direct output from matugen)

# --- Core outputs ---
append_ghostty_colors
copy_generated "$TMP_DIR/rofi-theme.rasi" "$HOME/.config/rofi/matugen-theme.rasi" "rofi theme"
copy_generated "$TMP_DIR/gtk-colors.css" "$HOME/.cache/matugen/colors-gtk.css" "gtk colors"

# --- Terminal / Editor ---
copy_generated "$TMP_DIR/nvim-colors.lua" "$HOME/.config/nvim/lua/matugen-theme.lua" "neovim colors"

# --- Qt theming ---
copy_generated "$TMP_DIR/qt5ct-colors.conf" "$HOME/.config/qt5ct/colors/matugen.conf" "qt5ct colors"
copy_generated "$TMP_DIR/qt6ct-colors.conf" "$HOME/.config/qt6ct/colors/matugen.conf" "qt6ct colors"
copy_generated "$TMP_DIR/qt5-style.qss" "$HOME/.config/qt5ct/qss/matugen-style.qss" "qt5 style"
copy_generated "$TMP_DIR/qt6-style.qss" "$HOME/.config/qt6ct/qss/matugen-style.qss" "qt6 style"

# --- System UI ---
copy_generated "$TMP_DIR/cava-colors.ini" "$HOME/.config/cava/colors" "cava colors"
copy_generated "$TMP_DIR/swayosd-style.css" "$HOME/.config/swayosd/style.css" "swayosd style"
copy_generated "$TMP_DIR/mako.config" "$HOME/.config/mako/config" "mako config"
copy_generated "$TMP_DIR/hyprlock.conf" "$HOME/.config/hyprlock/hyprlock.conf" "hyprlock config"

# --- Shell / Prompt ---
copy_generated "$TMP_DIR/btop-colors.theme" "$HOME/.config/btop/themes/nightforge.theme" "btop theme"
if [[ -f "$HOME/.config/btop/btop.conf" ]]; then
    sed -i 's/^color_theme = .*/color_theme = "nightforge"/' "$HOME/.config/btop/btop.conf"
    log_info "Set btop color_theme to nightforge"
fi
append_starship_colors
inject_fastfetch_colors

export_env_vars
reload_quickshell

log_info "Matugen sync complete"
