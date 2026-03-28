#!/bin/bash
# Keybind cheat sheet with matugen theming

CHEATSHEET="/tmp/niri-keybinds.html"

# Try to extract matugen colors
MATUGEN_CSS="$HOME/.config/matugen/colors.css"

if [[ -f "$MATUGEN_CSS" ]]; then
    BG=$(grep -oP '(?<=background: )#[0-9a-fA-F]{6}' "$MATUGEN_CSS" | head -1 || echo "#1e1e2e")
    FG=$(grep -oP '(?<=foreground: )#[0-9a-fA-F]{6}' "$MATUGEN_CSS" | head -1 || echo "#cdd6f4")
    ACCENT=$(grep -oP '(?<=primary: )#[0-9a-fA-F]{6}' "$MATUGEN_CSS" | head -1 || echo "#f38ba8")
else
    # Fallback
    BG="#1e1e2e"
    FG="#cdd6f4"
    ACCENT="#f38ba8"
fi

cat > "$CHEATSHEET" << HTML
<!DOCTYPE html>
<html>
<head>
    <title>Niri Keybinds - offsec-workstation</title>
    <style>
        body {
            font-family: 'JetBrains Mono', 'Fira Code', monospace;
            background: ${BG};
            color: ${FG};
            padding: 20px;
            max-width: 1200px;
            margin: 0 auto;
        }
        h1 { color: ${ACCENT}; border-bottom: 2px solid ${ACCENT}; }
        h2 { color: ${ACCENT}; margin-top: 30px; opacity: 0.8; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        th {
            background: rgba(255,255,255,0.05);
            color: ${ACCENT};
        }
        .keybind {
            background: rgba(255,255,255,0.1);
            padding: 4px 8px;
            border-radius: 4px;
            font-weight: bold;
            color: ${ACCENT};
        }
        .dt-inspired {
            background: rgba(255,255,255,0.05);
            padding: 8px;
            margin: 10px 0;
            border-left: 4px solid ${ACCENT};
            font-style: italic;
        }
    </style>
</head>
<body>
    <h1>🎯 offsec-workstation Keybind Reference</h1>
    <p><em>Niri 25.11 + DMS - DT-Inspired Smart Navigation</em></p>

    <div class="dt-inspired">
        <strong>DT-Style Smart Navigation:</strong> Mod+J/K moves focus down/up. If no window exists, switches workspace instead!
    </div>

    <h2>🧭 Smart Navigation (DT-Inspired)</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th><th>Behavior</th></tr>
        <tr>
            <td><span class="keybind">Mod+H/L</span></td>
            <td>Navigate columns</td>
            <td>Move focus left/right</td>
        </tr>
        <tr>
            <td><span class="keybind">Mod+J</span></td>
            <td>Focus down OR workspace down</td>
            <td>If window below: focus it. Else: switch workspace</td>
        </tr>
        <tr>
            <td><span class="keybind">Mod+K</span></td>
            <td>Focus up OR workspace up</td>
            <td>If window above: focus it. Else: switch workspace</td>
        </tr>
        <tr>
            <td><span class="keybind">Mod+U/I</span></td>
            <td>Cycle workspaces</td>
            <td>Previous/Next workspace</td>
        </tr>
    </table>

    <h2>🚀 Smart Movement (DT-Inspired)</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="keybind">Mod+Shift+H/L</span></td><td>Move column left/right</td></tr>
        <tr><td><span class="keybind">Mod+Shift+J</span></td><td>Move down OR to workspace down</td></tr>
        <tr><td><span class="keybind">Mod+Shift+K</span></td><td>Move up OR to workspace up</td></tr>
        <tr><td><span class="keybind">Mod+Shift+Left/Right</span></td><td>Move to adjacent monitor</td></tr>
    </table>

    <h2>📸 Screenshots</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th><th>Usage</th></tr>
        <tr><td><span class="keybind">Mod+S</span></td><td>Area → Edit → Save</td><td>80% - Primary</td></tr>
        <tr><td><span class="keybind">Mod+Shift+S</span></td><td>Area → Clipboard</td><td>15% - Quick share</td></tr>
        <tr><td><span class="keybind">Mod+Shift+R</span></td><td>Rename last screenshot</td><td>After capture</td></tr>
    </table>

    <h2>📓 Obsidian</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="keybind">Mod+Shift+D</span></td><td>Daily note</td></tr>
        <tr><td><span class="keybind">Mod+Shift+O</span></td><td>Search vault</td></tr>
        <tr><td><span class="keybind">Mod+O</span></td><td>Open CRTO vault</td></tr>
    </table>

    <h2>🪟 Window Management</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="keybind">Mod+Q</span></td><td>Close window</td></tr>
        <tr><td><span class="keybind">Mod+Space</span></td><td>Toggle overview</td></tr>
        <tr><td><span class="keybind">Mod+Shift+Space</span></td><td>Float window</td></tr>
        <tr><td><span class="keybind">Mod+G</span></td><td>Toggle float</td></tr>
        <tr><td><span class="keybind">Mod+Ctrl+H/J/K/L</span></td><td>Resize window</td></tr>
    </table>

    <h2>🚀 Applications</h2>
    <table>
        <tr><th>Keybind</th><th>Application</th></tr>
        <tr><td><span class="keybind">Mod+Return</span></td><td>Terminal (Ghostty)</td></tr>
        <tr><td><span class="keybind">Mod+D</span></td><td>Launcher (DMS)</td></tr>
        <tr><td><span class="keybind">Mod+B</span></td><td>Browser (Brave)</td></tr>
        <tr><td><span class="keybind">Mod+F</span></td><td>File Manager (Yazi)</td></tr>
        <tr><td><span class="keybind">Mod+T</span></td><td>Tmux Session Picker</td></tr>
    </table>

    <h2>🔢 Workspaces</h2>
    <table>
        <tr><td><span class="keybind">Mod+1-5</span></td><td>Focus workspace 1-5</td></tr>
        <tr><td><span class="keybind">Mod+Shift+1-5</span></td><td>Move to workspace</td></tr>
    </table>

    <p style="margin-top: 40px; text-align: center; opacity: 0.5;">
        <em>offsec-workstation v0.5.0 | Themed by matugen</em>
    </p>
</body>
</html>
HTML

xdg-open "$CHEATSHEET"
