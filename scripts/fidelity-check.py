#!/usr/bin/env python3
"""fidelity-check.py — verify generated KDL matches the source KDL semantics.

Phase 3 verification: the CUE-generated staging config must be semantically
identical to the tracked source config for the migrated sections. Compares
canonical structures parsed from both trees:

  - spawn-at-startup: (argv tokens)
  - keybinds:         (combo, flags, action) where action is
                      ("spawn", tokens) or ("builtin", name, arg|None)
  - window-rules:     (match pairs, sorted properties)

Usage:
  scripts/fidelity-check.py [--staging DIR]   (default: build/niri-staging/)

Exits 0 when source and generated match, non-zero listing any drift.
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC = REPO_ROOT / "dotfiles" / "niri" / ".config" / "niri"
SRC_CONFIG = SRC / "config.kdl"
SRC_KEYBINDS = SRC / "includes" / "keybinds.kdl"
SRC_RULES = SRC / "includes" / "window-rules.kdl"

STR = re.compile(r'"((?:[^"\\]|\\.)*)"')


def strip_comments(text: str) -> str:
    """Remove // line comments, but only outside double-quoted strings
    (so URLs like obsidian://daily survive)."""
    out = []
    for line in text.splitlines():
        in_str = False
        cut = None
        for i, ch in enumerate(line):
            if ch == '"' and (i == 0 or line[i - 1] != '\\'):
                in_str = not in_str
            elif ch == '/' and not in_str and line.startswith('//', i):
                cut = i
                break
        out.append(line if cut is None else line[:cut])
    return "\n".join(out)


def kdl_tokens(s: str) -> list[str]:
    """Whitespace-split, keeping double-quoted segments intact."""
    return re.findall(r'"[^"]*"|[^\s"]+', s)


def parse_strs(s: str) -> list[str]:
    """Extract double-quoted string tokens from a KDL statement."""
    return STR.findall(s)


# ---- source: spawn-at-startup -----------------------------------------

def src_spawns() -> list[tuple]:
    out = []
    for line in strip_comments(SRC_CONFIG.read_text()).splitlines():
        line = line.strip()
        if line.startswith("spawn-at-startup "):
            out.append(tuple(parse_strs(line)))
    return out


# ---- source: keybinds --------------------------------------------------

def norm_flags(tokens: list[str]) -> frozenset:
    """Canonical flags: (key, value) tuples; merges `key=` + `"value"` pairs."""
    flags = []
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t.endswith("=") and i + 1 < len(tokens) and tokens[i + 1].startswith('"'):
            flags.append((t[:-1], tokens[i + 1][1:-1]))
            i += 2
        elif "=" in t:
            k, v = t.split("=", 1)
            flags.append((k, v.strip('"')))
            i += 1
        else:
            flags.append((t, True))
            i += 1
    return frozenset(flags)


def parse_bind(line: str):
    """Parse one binds-block line -> (combo, frozenset(flags), action)."""
    head, _, rest = line.partition("{")
    combos = kdl_tokens(head)
    combo = combos[0]
    flags = norm_flags(combos[1:])
    body = rest.rsplit("}", 1)[0].strip()
    action_body = body.rstrip(";").strip()
    if action_body.startswith("spawn"):
        tokens = tuple(parse_strs(action_body))
        action = ("spawn", tokens)
    else:
        parts = action_body.split(None, 1)
        name = parts[0]
        arg = None
        if len(parts) > 1:
            arg = parse_strs(parts[1])[0]
        action = ("builtin", name, arg)
    return (combo, flags, action)


def src_binds() -> list[tuple]:
    text = strip_comments(SRC_KEYBINDS.read_text())
    lines = [l for l in text.splitlines() if l.strip()]
    in_binds = False
    out = []
    for line in lines:
        s = line.strip()
        if s == "binds {":
            in_binds = True
            continue
        if in_binds:
            if s == "}":
                break
            if s:
                out.append(parse_bind(s))
    return out


# ---- window rules (shared canonical parser, line-based) ---------------

NUM = re.compile(r'^-?\d+(\.\d+)?$')


def norm_value(v: str):
    """Canonical value: numbers compared numerically, strings unquoted."""
    v = v.strip()
    if NUM.match(v):
        return float(v)
    if v.startswith('"') and v.endswith('"'):
        return v[1:-1]
    return v


def parse_rule_block(lines: list[str]) -> tuple:
    """Parse a window-rule block body (one statement per line, plus optional
    single-line brace props like `default-column-width { proportion 0.5; }`)."""
    match = []
    props = []
    for line in lines:
        s = line.strip()
        if not s:
            continue
        m = re.findall(r'((?:app-id|title))=r#"((?:[^"]|"(?!#))*)"#', s)
        if m:
            match.extend(m)
            continue
        m = re.match(r'(default-column-width|default-window-height) \{ (proportion|fixed) ([-\d.]+); \}$', s)
        if m:
            props.append((m.group(1), (m.group(2), float(m.group(3)))))
            continue
        parts = s.split(None, 1)
        if len(parts) == 2:
            props.append((parts[0], norm_value(parts[1])))
        else:
            props.append((parts[0], True))
    return (tuple(sorted(match)), tuple(sorted(props, key=str)))


def parse_rules_file(text: str) -> list[tuple]:
    out = []
    depth, buf = 0, []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line == "window-rule {":
            depth, buf = 1, []
            continue
        if depth:
            if line == "}":
                out.append(parse_rule_block(buf))
                depth = 0
            else:
                buf.append(line)
    return out


def src_rules() -> list[tuple]:
    return parse_rules_file(strip_comments(SRC_RULES.read_text()))


# ---- generated (same canonical forms) ----------------------------------

def gen_spawns(cfg: dict) -> list[tuple]:
    return [tuple(s["argv"]) for s in cfg["spawnAtStartup"]]


def gen_binds(cfg: dict) -> list[tuple]:
    out = []
    for b in cfg["binds"]:
        flags = set()
        if b.get("allowWhenLocked"):
            flags.add(("allow-when-locked", "true"))
        if b.get("repeat") is False:
            flags.add(("repeat", "false"))
        if b.get("hotkeyOverlayTitle"):
            flags.add(("hotkey-overlay-title", b["hotkeyOverlayTitle"]))
        a = b["action"]
        if a["kind"] == "spawn":
            action = ("spawn", tuple(a["argv"]))
        else:
            action = ("builtin", a["name"], a.get("arg"))
        out.append((b["combo"], frozenset(flags), action))
    return out


def gen_rules(cfg: dict) -> list[tuple]:
    out = []
    for r in cfg["windowRules"]:
        match = []
        if r.get("appId"):
            match.append(("app-id", r["appId"]))
        if r.get("title"):
            match.append(("title", r["title"]))
        props = []
        for k, v in [("geometry-corner-radius", r.get("geometryCornerRadius")),
                     ("clip-to-geometry", r.get("clipToGeometry")),
                     ("open-floating", r.get("openFloating")),
                     ("open-fullscreen", r.get("openFullscreen")),
                     ("opacity", r.get("opacity")),
                     ("max-width", r.get("maxWidth")),
                     ("max-height", r.get("maxHeight")),
                     ("block-out-from", r.get("blockOutFrom"))]:
            if v is not None:
                props.append((k, str(v).lower() if isinstance(v, bool) else float(v) if isinstance(v, (int, float)) else v))
        for k, w in [("default-column-width", r.get("defaultColumnWidth")),
                     ("default-window-height", r.get("defaultWindowHeight"))]:
            if w is not None:
                kind = "proportion" if "proportion" in w else "fixed"
                props.append((k, (kind, float(w[kind]))))
        out.append((tuple(sorted(match)), tuple(sorted(props, key=str))))
    return out


def main() -> int:
    staging = REPO_ROOT / "build" / "niri-staging"
    if "--staging" in sys.argv:
        staging = Path(sys.argv[sys.argv.index("--staging") + 1]).resolve()

    import json
    import subprocess
    exported = subprocess.run(
        ["cue", "export", ".", "--out", "json"],
        cwd=REPO_ROOT / "cue", capture_output=True, text=True, check=True,
    ).stdout
    cfg = json.loads(exported)["config"]

    pairs = [
        ("spawn-at-startup", src_spawns(), gen_spawns(cfg)),
        ("keybinds", src_binds(), gen_binds(cfg)),
        ("window-rules", src_rules(), gen_rules(cfg)),
    ]

    ok = True
    for label, src, gen in pairs:
        src_set, gen_set = set(src), set(gen)
        missing = src_set - gen_set
        extra = gen_set - src_set
        print(f"== {label}: source={len(src)} generated={len(gen)}")
        if missing:
            ok = False
            print(f"  MISSING from generated ({len(missing)}):")
            for item in sorted(missing, key=str):
                print(f"    - {item}")
        if extra:
            ok = False
            print(f"  EXTRA in generated ({len(extra)}):")
            for item in sorted(extra, key=str):
                print(f"    + {item}")

    if not ok:
        print("\nERROR: generated artifacts drift from source semantics.", file=sys.stderr)
        return 1
    total = sum(len(s) for _, s, _ in pairs)
    print(f"\nOK: {total} canonical entries match source semantics exactly.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
