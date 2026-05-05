# NightForge v2 — Session Handoff

## Previous Session (2026-05-04)
Complete full-stack rebuild from scratch. 100+ tool calls, 7 subagent phases, ~500 files modified.

## Current State

### Running Processes
- `quickshell` (shell.qml — widget overlay, StackView, IPC)
- `quickshell -p TopBar.qml` (per-screen bar with system info, media, workspace pills)
- `cliphist-daemon.sh` (clipboard history via wl-paste --watch)
- `wallpaper-rotate.timer` (15 min wallpaper rotation via awww)
- `cava` (FIFO pipe at `/tmp/mpd_fifo` for music widget equalizer)

### Keybinds
| Key | Action |
|-----|--------|
| `Mod+Shift+C` | Open settings |
| `Mod+M` | Open music widget |
| `Mod+Shift+N` | Open network |
| `Mod+Shift+W` | Open wallpaper picker |
| `Mod+Shift+M` | Open monitor |
| `Escape` | Close widget / Cancel fuzzel |
| `Mod+A` | Toggle audio sink (HDMI ↔ Analog) |
| `Mod+D` | Open fuzzel (app launcher) |
| `Mod+Alt+L` | Lock screen |
| `Mod+V` | Clipboard picker |
| **Center pill click** | Open ghostty + btop |

### Key Files Changed
```
~/.config/quickshell/shell.qml              — Entry: StackView overlay + IPC + services
~/.config/quickshell/TopBar.qml             — Ilyamiro bar (1567 lines)
~/.config/quickshell/WindowRegistry.js      — All widget layouts + dashboard entry
~/.config/quickshell/scripts/qs_manager.sh  — IPC router (colon-separated)
~/.config/quickshell/scripts/lock-screen.sh — gtklock with wallpaper background
~/.config/quickshell/scripts/matugen-sync.sh — Theme pipeline (niri/firefox/fuzzel/ghostty)
~/.config/quickshell/modules/widgets/DashboardWidget.qml — Calendar+clock+sysinfo (676 lines)
~/.config/niri/includes/window-rules.kdl    — Popup/PiP/Electron rules
~/.config/niri/includes/keybinds.kdl        — Audio switch, widget shortcuts
~/.config/niri/includes/colors.kdl          — Auto-generated border colors
~/.config/zshrc                            — Zinit + NightForge aliases
~/.config/starship.toml                     — Operator prompt
~/.config/tmux/tmux.conf                    — C-Space prefix, resurrect/continuum
~/.config/ghostty/config                    — Keybind hierarchy + performance
~/.config/pipewire/pipewire.conf.d/clock-settings.conf
~/.config/wireplumber/wireplumber.conf.d/  — Analog audio force
~/.mozilla/firefox/*/user.js               — Betterfox + NightForge overrides
~/.mozilla/firefox/*/chrome/userChrome.css — Compact dark theme
/etc/firefox/policies.json                 — Force-installed extensions
```

## Remaining Issues (Priority Order)

### 1. GitHub Repo — Micro-commits
The `~/Github/nightforge` repo needs to be updated with all v2 changes. Commit structure:
```bash
# Per-area commits
01-feat-quickshell-ilyamiro-port.md        # shell.qml, TopBar.qml, widgets, WindowRegistry
02-feat-niri-config-enhancement.md         # window-rules, keybinds, colors.kdl
03-feat-zsh-zinit-migration.md             # .zshrc, aliases
04-feat-nvim-lazyvim-setup.md             # init.lua, plugins/
05-feat-firefox-betterfox-hardening.md     # user.js, policies, userChrome.css
06-feat-starship-ghostty-tmux-stack.md     # terminal configs
07-feat-pipewire-audio-setup.md            # wireplumber, pipewire configs
08-feat-matugen-theme-pipeline.md          # matugen-sync.sh with niri/firefox/fuzzel
09-feat-clipboard-lockscreen-utils.md      # cliphist, lock-screen, audio-switch
10-fix-various-bugs.md                     # qs_manager colon fix, brace fixes, fuzzel escape
```

### 2. Zed Install & Config
```bash
sudo pacman -S zed
# ~/.config/zed/settings.json
# {"vim_mode": true, ...}
```
Hybrid approach: Neovim for daily dev/scripting, Zed for agent-assisted codebase navigation.

### 3. Firefox Policies.json
Already done (`/etc/firefox/policies.json`). Verify with:
```bash
cat /etc/firefox/policies.json
```

### 4. Help Menu Content (GuidePopup.qml)
The guide popup (`~/.config/quickshell/guide/GuidePopup.qml`) still has placeholder content. Full rewrite needed for NightForge-specific documentation.

### 5. Network Widget Hub-and-Bubble
Improve visual layout to match ilyamiro's hub-and-bubble design.

### 6. Dashboard Widget
Currently exists at `modules/widgets/DashboardWidget.qml` but not wired. Clicking the bar opens `ghostty -e btop` instead. Decide: wire the widget or keep terminal-based btop.

### 7. Screenshots / Screen Recordings
Collect for GitHub repo. Every widget, the bar, lock screen, terminal workflows.

### 8. Clean Up Scripts
Audit `scripts/` directory for: dead code, wrong paths, ilyamiro remnants, duplicate files.

### 9. Wallpaper Directories
User has both `~/Pictures/wallpapers/` and `~/Personal/WallPapers/`. Deduplicate.

## Key Decisions Recap
| Decision | Rationale |
|----------|-----------|
| Betterfox > arkenfox | Less breakage for OSINT/research |
| Zinit > OMZ/antidote | Fastest startup |
| LazyVim > NvChad/AstroNvim | Most modular, matugen-friendly |
| Ghostty > Warp | Lighter, no redundant AI layer |
| Extra/cava > AUR forks | Official repo, reproducible |
| Single Firefox profile + containers | Multi-profile deferred |
| cliphist > greenclip/copyq | Wayland-native |
| Two-process Quickshell | ilyamiro pattern (overlay + bar) |

## Commands to Verify Everything
```bash
# Check quickshell is running
pgrep -a quickshell
# Test widgets
echo "music" > /tmp/qs_widget_state
sleep 2
echo "close" > /tmp/qs_widget_state
echo "network" > /tmp/qs_widget_state
sleep 2
echo "close" > /tmp/qs_widget_state
# Check niri config
niri validate
# Check audio
speaker-test -c 2 -l 1
# Check clipboard
echo "test" | wl-copy
cliphist list | head -3
# Check lock screen
gtklock --version
# Check Firefox config
cat ~/.mozilla/firefox/p6098aut.default-release/user.js | grep "Betterfox\|NIGHTFORGE"
```
