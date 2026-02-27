#!/bin/bash
# Keyboard Shortcuts Menu - Executable
# Shows visual reference and can execute shortcuts

SELECTION=$(cat << 'EOF' | fuzzel --dmenu --prompt "Shortcuts:" --width 100
🚀 Launch Terminal (Super+Return)
🌐 Launch Browser (Super+B)
📝 Launch Obsidian (Super+N)
📁 File Manager (Super+E)
🐳 Container Launcher (Super+C)
📊 System Monitor (Super+Shift+S)
🔍 Application Launcher (Super+D)
📸 Screenshot (Print)
🔒 Lock Screen
♻️  Reload Sway Config
❌ Kill Window (Super+Shift+Q)
🔲 Toggle Fullscreen (Super+F)
🪟  Toggle Floating (Super+Shift+Space)
📋 Show All Shortcuts (View Only)
EOF
)

case "$SELECTION" in
    *"Launch Terminal"*)
        swaymsg 'workspace 2: Terminal; exec ghostty'
        ;;
    *"Launch Browser"*)
        brave-browser &
        ;;
    *"Launch Obsidian"*)
        obsidian &
        ;;
    *"File Manager"*)
        ghostty -e yazi &
        ;;
    *"Container Launcher"*)
        ~/Github/offsec-workstation/scripts/helpers/container-launcher.sh
        ;;
    *"System Monitor"*)
        ghostty -e htop &
        ;;
    *"Application Launcher"*)
        fuzzel --prompt "Launch:"
        ;;
    *"Screenshot"*)
        flameshot gui -c
        ;;
    *"Lock Screen"*)
        swaylock -f -i /home/paradigm/Personal/WallPapers/DoSomethingGreat-unsplash.jpg
        ;;
    *"Reload Sway"*)
        swaymsg reload
        ;;
    *"Kill Window"*)
        swaymsg kill
        ;;
    *"Toggle Fullscreen"*)
        swaymsg fullscreen toggle
        ;;
    *"Toggle Floating"*)
        swaymsg floating toggle
        ;;
    *"Show All Shortcuts"*)
        # Display full reference
        cat << 'SHORTCUTS' | fuzzel --dmenu --prompt "All Shortcuts:" --width 100
=== SWAY KEYBOARD SHORTCUTS ===

SYSTEM
  Super + Shift + Q       Kill focused window
  Super + Shift + C       Reload Sway config
  Super + Shift + E       Exit Sway

APPLICATIONS
  Super + Return          Terminal (Ghostty)
  Super + D               Application launcher
  Super + B               Browser (Brave)
  Super + N               Notes (Obsidian)
  Super + E               File manager (Yazi)
  Super + C               Container launcher
  Super + Shift + S       System monitor (htop)

WINDOWS
  Super + H/J/K/L         Focus window (vim-style)
  Super + Shift + H/J/K/L Move window
  Super + Shift + B       Split horizontal
  Super + V               Split vertical
  Super + F               Toggle fullscreen
  Super + Shift + Space   Toggle floating
  Super + Space           Toggle focus floating/tiling

WORKSPACES
  Super + 1-5             Switch to workspace 1-5
  Super + Shift + 1-5     Move window to workspace 1-5

LAYOUTS
  Super + S               Stacking layout
  Super + W               Tabbed layout
  Super + T               Toggle split layout
  Super + A               Focus parent

RESIZE MODE
  Super + R               Enter resize mode
    H/J/K/L               Resize (in resize mode)
    Esc/Return            Exit resize mode

SCREENSHOTS
  Print                   Screenshot region
  Shift + Print           Screenshot screen
  Super + Print           Screenshot full

AUDIO
  Volume Up/Down          Adjust volume
  Mute                    Toggle mute
  Mic Mute                Toggle microphone

BRIGHTNESS
  Brightness Up/Down      Adjust brightness

UTILITIES
  Super + /               This shortcuts menu
  Super + Shift + /       Command cheatsheet
  Super + P               Productivity menu
  Super + Shift + W       Wallpaper picker
SHORTCUTS
        ;;
esac

