# NightForge Troubleshooting

## Quickshell

### "Too many open files" / Process crash
**Symptom:** Quickshell crashes with GLib-ERROR "Creating pipes for GWakeup: Too many open files"
**Root cause:** A Process element polling too frequently (every 1s) reading a non-existent file, or a watcher script referencing a wrong path
**Fix:**
```bash
# Check for leaking processes
lsof -p $(pgrep -x quickshell) | wc -l
# Common culprits: MatugenColors (polling), Scaler (settings watcher)
# Check for wrong script paths
grep -rn "/quickshell/quickshell/" ~/.config/quickshell/
```
**Prevention:** Set reasonable polling intervals (>2s), ensure all script paths exist

### Widget opens and immediately closes
**Symptom:** Widget flashes on screen then disappears
**Root cause:** IPC command processed twice — once by ipcWatcher (inotifywait) and once by ipcPoller (timer)
**Fix:** Disable one of the two IPC handlers. Current config uses poller only.

### "GlassPanel is not a type" error
**Symptom:** Widget fails to load, GlassPanel component not found
**Root cause:** Missing `qmldir` in `components/` directory — QML engine can't resolve the import
**Fix:** Create `components/qmldir` with:
```
GlassPanel 1.0 GlassPanel.qml
```

### "FolderListModel is not defined"
**Symptom:** Wallpaper picker grid doesn't load
**Root cause:** Quickshell blocks `Qt.labs.folderlistmodel` import
**Fix:** Replaced with Process-based scanner using `find` command + ListModel

### QML cache issues
**Symptom:** Changes to .qml files don't take effect after restart
**Fix:**
```bash
rm -rf ~/.cache/quickshell/qmlcache/
pkill quickshell
```

## Niri

### Blue border/tint on focused window
**Symptom:** Active window has a blue border or blue tint that won't go away
**Root cause:** Niri's built-in window decoration/focus indicator. Controlled by `border` setting but may still show even with `width 0`
**Check:**
```bash
niri validate
grep -A5 "border" ~/.config/niri/includes/compositor.kdl
cat ~/.config/niri/includes/colors.kdl
```
**Fix:** Set both to `width 0` with transparent colors. If still visible, it's Niri's hardcoded focus ring — not configurable.

### Config validation error: "unexpected node border"
**Symptom:** `niri validate` fails on `border` in colors.kdl
**Root cause:** `colors.kdl` has `border` at top level but it's inside `layout {}` in compositor.kdl
**Fix:** Wrap border in `layout { }`:
```kdl
layout {
    border {
        width 0
    }
}
```

## Audio

### No sound from speakers (ALC897 codec)
**Symptom:** Audio sink shows 100% volume, unmuted, but no sound
**Root cause:** ALC897 codec hardware jack detection — Headphone channel at 0% or analog profile not selected
**Diagnosis:**
```bash
~/audio-diag.sh
amixer | grep Headphone
cat /proc/asound/card0/codec#0 | grep "Pin Default" | grep "Line Out"
```
**Fix:**
```bash
# Check if Headphone is muted/zero
amixer set Headphone unmute
amixer set Headphone 87%
# Or use hdajackretask
sudo pacman -S alsa-tools
hdajackretask  # Override pin 0x14 to "Line Out"
```

### Browser audio not playing
**Symptom:** MPD audio works, Firefox/YouTube doesn't
**Check:**
```bash
pactl list sink-inputs | grep -E "application.name|sink:"
# Move Firefox to active sink
pactl move-sink-input <input-id> <sink-id>
```
**Fix:** Firefox may be routed to different sink. Set default:
```bash
wpctl set-default <sink-id>
```

## Firefox

### MPRIS not working (music widget doesn't show browser audio)
**Check:**
```bash
playerctl -l  # Should show firefox
```
**Fix:** Enable in about:config: `media.hardwaremediakeys.enabled = true`

### Firefox not using Wayland
**Check:**
```bash
grep -c "Wayland" ~/.mozilla/firefox/*.default-release/user.js
```
**Fix:** Use the Wayland wrapper:
```bash
~/.local/bin/firefox-wayland.sh
```
Or set env vars: `MOZ_ENABLE_WAYLAND=1 GDK_BACKEND=wayland`

## Environment

### Zsh startup slow (>100ms)
**Symptom:** Terminal takes noticeable time to start
**Diagnosis:**
```bash
time zsh -i -c exit
```
**Fix:** Check Zinit plugins for sync loading. Ensure autosuggestions and syntax-highlighting are turbo-loaded.
Current startup: ~0.08s on warmed cache (first run ~3s due to cmatrix splash).

### Starship not showing
**Symptom:** No prompt or default zsh prompt
**Fix:**
```bash
eval "$(starship init zsh)"
```
Should be in `~/.zshrc`.

## General

### "sudo: a terminal is required" error
**Symptom:** sudo commands in scripts fail
**Root cause:** Scripts running in non-interactive context
**Fix:** Prefer `sudo` commands that prompt via UI, or use `pkexec` for GUI dialogs. For automation, consider passwordless sudo for specific commands.

### CPU 0% in system info
**Symptom:** Bar shows CPU: 0%
**Root cause:** `top -bn1` output format differs across systems. The awk parsing uses `%Cpu` pattern and column 8 (idle).
**Fix:** Test locally:
```bash
top -bn1 | grep '%Cpu' | awk '{print int(100-$8)}'
```

### Clipboard history stale
**Symptom:** `Mod+V` shows old clipboard items
**Fix:** Ensure cliphist daemon is running:
```bash
systemctl --user status cliphist.service
# Restart if needed:
systemctl --user restart cliphist.service
```
