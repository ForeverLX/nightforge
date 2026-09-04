# Task S226-B1: Research & Document Omarchy + Aether Defaults

**Phase:** B (Omarchy Setup)
**Model:** Spark-X2.5-4B (reasoning, architecture)
**Harness:** Pi (interactive — research task)
**Estimated context:** ~4K tokens
**Priority:** 1 (provides reference for all migration tasks)

---

## Background

The NightForge migration targets Omarchy (Hyprland-based) and Aether (theming). Before port configs, we need to understand what Omarchy provides out of the box and how Aether's theming works. The local system already has Omarchy installed (see `~/.config/hypr/` bootstrap from `/usr/share/omarchy`).

## Instructions

### Step 1: Check installation status
```bash
yay -Q omarchy 2>/dev/null; echo "---"
yay -Q aether 2>/dev/null; echo "---"
ls /usr/share/omarchy/default/hypr/ 2>/dev/null; echo "---"
which omarchy 2>/dev/null; echo "---"
which aether 2>/dev/null; echo "---"
```

### Step 2: Inventory Omarchy defaults
Inspect what Omarchy provides:

1. **Hyprland bootstrap config** at `/usr/share/omarchy/default/hypr/`:
   - List all files and describe what each does
   - Extract the default keybindings (from the bootstrap)
   - Note any Omarchy-specific APIs (e.g., `o.bind()`, `hl.config()`, `hl.exec()`)

2. **Bar configuration**:
   - Check if Waybar is preconfigured by Omarchy
   - Location: `~/.config/waybar/` or `/usr/share/omarchy/default/waybar/`
   - Note available modules and styling approach

3. **Application launcher**:
   - Check if `wofi` is configured (replaces fuzzel?)
   - Location of wofi config

4. **Notification daemon**:
   - Check if `mako` is preconfigured
   - Location: `~/.config/mako/`

5. **Lock screen**:
   - Check if `hyprlock` is preconfigured
   - Location: `~/.config/hyprlock/`

6. **Screen capture**:
   - Check if `grim` / `slurp` / `satty` are available
   - Note how screenshots are taken in Omarchy defaults

### Step 3: Inventory Aether theming
1. Run `omarchy theme list` to see available themes
2. Run `omarchy theme get-colors` to see the color output format
3. Check `~/.cache/omarchy/colors.json` if it exists
4. Check `~/.config/environment.d/` for Aether env vars
5. Document the Aether color schema (field names, format)

### Step 4: Document overlap with NightForge
Compare what Omarchy provides natively vs. what NightForge has:

| NightForge Component | Omarchy Provides? | Compatible? | Notes |
|---------------------|-----------------|-------------|-------|
| Waybar | Yes/No | Yes/No | Does NightForge need custom Waybar config? |
| Fuzzel | Yes/No (wofi?) | Yes/No | Omarchy may use wofi instead |
| SwayOSD | Yes/No | Yes/No | Already used in keybindings |
| Hyprlock | Yes/No | Yes/No | Already have hyprlock.conf in matugen |
| MPD | ? | ? | Already have mpd.service |
| Podman | ? | ? | Already have podman-restart.service |

## Expected Output

Create `~/Projects/nightforge/docs/migration-prompts/s226-B1-omarchy-reference.md` with:

1. **Installation status**: omarchy, aether — installed or not
2. **Omarchy defaults inventory**: file listing + descriptions
3. **Omarchy Lua API reference**: `o.bind()`, `hl.config()`, `hl.exec()`, etc.
4. **Aether theming API**: available commands + color schema
5. **Overlap analysis**: what NightForge needs vs. what Omarchy provides
6. **Key decisions for migration**:
   - Use Omarchy's default Waybar config or provide custom config?
   - Use Omarchy's wofi or keep fuzzel?
   - Does Aether handle all the color output targets that matugen-sync.sh did?

## Acceptance Criteria

- Installation status verified for omarchy + aether
- Omarchy bootstrap config files inventoried (at least 5 files listed)
- Omarchy Lua API reference documented (at least 5 API functions)
- Aether theming API documented (commands + color schema)
- Overlap table completed with all 7 NightForge components
- Key migration decisions documented with rationale

## Rollback

No changes made — research/documentation only.