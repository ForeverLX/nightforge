# Task S226-C8: Migrate Niri-Dependent Scripts to Hyprland IPC

**Phase:** C (Config Migration)
**Model:** Spark-X2.5-4B (code generation, IPC porting)
**Harness:** Pi (interactive)
**Estimated context:** ~12K tokens
**Priority:** 2

---

## Background

Several scripts use `niri msg` IPC commands that must be ported to `hyprctl dispatch` (Hyprland's IPC). The scripts are:

1. `scripts/focus-or-spawn.sh` (122 lines) — uses `niri msg --json windows`, `niri msg action focus-window`, `niri msg action move-window-to-workspace`
2. `scripts/niri-outputs/main.go` (164 lines) — uses `niri msg outputs`, generates Niri config blocks
3. `dotfiles/quickshell/.config/quickshell/scripts/workspaces.sh` (20 lines) — uses `niri msg --json workspaces`, `niri msg --json active-workspace`

Additionally, `dotfiles/niri/.config/niri/scripts/focus-or-spawn.sh` is a duplicate that's stowed to `~/.config/niri/scripts/` — this is the one actually used by keybindings.

Note: `dotfiles/niri/.config/niri/scripts/focus-or-spawn.sh` does NOT exist in the repo — the one at `scripts/focus-or-spawn.sh` is the source. Let me verify:

Actually from the grep results, the keybindings call `~/.config/niri/scripts/focus-or-spawn.sh` but the actual script is at `scripts/focus-or-spawn.sh`. It appears to be symlinked or copied during deploy.

## Input: scripts/focus-or-spawn.sh (122 lines — full)

Key Niri-specific sections:

```bash
# Line 68: Verify Niri is running
if ! pgrep -x niri >/dev/null 2>&1; then
    die "Niri is not running"
fi

# Line 75: Get windows JSON
WINDOWS_JSON=$(niri msg --json windows 2>/dev/null) || die "Failed to query niri windows"

# Line 78-80: Find matching windows
MATCHING_IDS=$(echo "$WINDOWS_JSON" | jq -r --arg app_id "$APP_ID" '
    [.[] | select(.app_id | contains($app_id)) | .id] | if length > 0 then .[] else empty end
')

# Line 97: Focus window
niri msg action focus-window --id "$FIRST_ID" || die "Failed to focus window $FIRST_ID"

# Line 110: Re-query windows
NEW_WINDOWS_JSON=$(niri msg --json windows 2>/dev/null) || die "Failed to query niri windows"

# Line 116: Move to scratch workspace
niri msg action move-window-to-workspace --id "$NEW_ID" "scratch" || log "Failed to move window to scratch workspace"
```

## Hyprland IPC Equivalent

Hyprland uses `hyprctl` or `hyprland` socket for IPC:

```bash
# Check if Hyprland is running
pgrep -x hyprland >/dev/null 2>&1

# Get windows (JSON format)
hyprctl clients -j

# Focus a window by address
hyprctl dispatch focuswindow "address:0x123456"

# Focus workspace
hyprctl dispatch workspace "1"

# Move window to workspace
hyprctl dispatch movetoworkspace "1, address:0x123456"

# Move window to scratch (workspace 10)
hyprctl dispatch movetoworkspace "10"

# Toggle floating
hyprctl dispatch togglefloating

# Get active workspace
hyprctl activeworkspace -j

# Get monitors
hyprctl monitors -j
```

## Input: scripts/niri-outputs/main.go (164 lines — key sections)

```go
// Line 30: Calls niri msg outputs
raw, err := exec.Command("niri", "msg", "outputs").Output()

// Line 39: Parse output name
re := regexp.MustCompile(`Output "(.+)"`)
m := re.FindStringSubmatch(line)

// Line 154-161: Generate Niri config block
cfg := fmt.Sprintf(`output "%s" {
    mode "%s@%s"
    scale %s
    position x=0 y=0
    transform "normal"
}`, o.Name, o.BestMode, o.BestRate, o.ScaleRec)
o.NiriConfig = cfg
```

Hyprland equivalent:
```go
// Get monitors as JSON
hyprctl monitors -j

// Or use the raw output
// Generate Hyprland monitor config:
monitor=DP-1,2560x1440@144,0x0,1.25
```

## Input: dotfiles/quickshell/.config/quickshell/scripts/workspaces.sh (20 lines — full)

```bash
#!/bin/bash
# Niri workspace daemon
if ! command -v niri &>/dev/null || ! niri msg --json workspaces &>/dev/null; then
    echo '[]'
    exit 0
fi

active=$(niri msg --json active-workspace 2>/dev/null | jq '.id' 2>/dev/null)
if [ -z "$active" ] || [ "$active" = "null" ]; then
    active=-1
fi

niri msg --json workspaces 2>/dev/null | \
    jq --argjson active "$active" \
    '[.[] | {id: .id, name: (.name | tostring), active: (.id == $active), occupied: (.windows > 0)}]' 2>/dev/null || \
    echo '[]'
```

Hyprland equivalent:
```bash
#!/bin/bash
# Hyprland workspace daemon
hyprctl workspaces -j | jq --argjson active "$(hyprctl activeworkspace -j | jq '.id // -1')" \
    '[.[] | {id: .id, name: .name, active: (.id == $active), occupied: (.windows | length > 0)}]'
```

## Migration Tasks

### Task 1: Port focus-or-spawn.sh → hypr-focus-or-spawn.sh

Changes:
1. `pgrep -x niri` → `pgrep -x hyprland`
2. `niri msg --json windows` → `hyprctl clients -j`
3. Niri window IDs are integers; Hyprland uses `address:0x1234` — rewrite jq to use `address` instead of `id`
4. `niri msg action focus-window --id` → `hyprctl dispatch focuswindow "address:..."`
5. `niri msg action move-window-to-workspace --id ... "scratch"` → `hyprctl dispatch movetoworkspace 10` (use workspace 10 as scratch)
6. The `--app-id` matching uses `.app_id` which is available in Hyprland's `hyprctl clients -j` as `.class` or `.title`

### Task 2: Port niri-outputs/main.go → hypr-outputs/main.go

Changes:
1. `exec.Command("niri", "msg", "outputs")` → `exec.Command("hyprctl", "monitors", "-j")`
2. Parse JSON from `hyprctl monitors -j` (much easier than parsing text output)
3. Generate Hyprland monitor config line: `monitor=NAME,RES@RATE,POS,SCALE`
4. Keep the same JSON output format (Name, CurrentMode, etc.) but update field mapping

### Task 3: Port workspaces.sh → hypr-workspaces.sh

Changes:
1. Replace all `niri msg --json` calls with `hyprctl ... -j`
2. Map workspaces JSON format:
   - Niri: `.id`, `.name`, `.windows` (int)
   - Hyprland: `.id`, `.name`, `.windows` (array — need `length`)
3. Map active workspace from `hyprctl activeworkspace -j`

## Expected Output

1. **`scripts/hypr-focus-or-spawn.sh`** — new script, ported from focus-or-spawn.sh, uses hyprctl
2. **`scripts/hypr-outputs/main.go`** — new Go program, ported from niri-outputs/main.go
3. **`dotfiles/quickshell/.config/quickshell/scripts/hypr-workspaces.sh`** — new script, ported from workspaces.sh
4. Update `dotfiles/niri/.config/niri/includes/keybinds.kdl` reference: the keybindings that call `focus-or-spawn.sh` should be updated to call `hypr-focus-or-spawn.sh` instead (this is handled in Task C1's bindings.lua, but note the script path here)
5. Update `dotfiles/niri/.config/niri/config.kdl`: replace `~/.local/bin/matugen-sync.sh` with `aether-sync.sh` (handled in Task C5)

## Acceptance Criteria

- `hypr-focus-or-spawn.sh` uses `hyprctl` instead of `niri msg`
- `hypr-outputs/main.go` uses `hyprctl monitors -j` instead of `niri msg outputs`
- `hypr-workspaces.sh` uses `hyprctl workspaces -j` instead of `niri msg --json workspaces`
- All scripts pass `bash -n` syntax check
- Go program compiles: `go build ./scripts/hypr-outputs/`
- No `niri msg` calls remain in any of the 3 files
- `pgrep -x niri` replaced with `pgrep -x hyprland`

## Rollback

```bash
git checkout -- scripts/focus-or-spawn.sh scripts/niri-outputs/ dotfiles/quickshell/.config/quickshell/scripts/workspaces.sh
```