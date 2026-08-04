# NightForge Session Handoff — TEMPLATE (SANITIZED)

> **Handoff policy:** Session handoffs live in `docs/archive/` as sanitized
> templates. This repository is **PUBLIC** — NEVER commit actual operational
> data: running process names, keybinds, file paths, hostnames, IPs, or
> credentials. Redact with `[REDACTED - operator-specific]` or generic
> placeholders. Keep the structure, strip the specifics.

## Previous Session (YYYY-MM-DD)

[Short summary of what was accomplished — no operational specifics.]

## Current State

### Running Processes

- `[REDACTED - operator-specific: shell/daemon processes]`

### Keybinds

| Key | Action |
|-----|--------|
| `[REDACTED - operator-specific]` | `[REDACTED - operator-specific]` |

### Key Files Changed

```
[REDACTED - operator-specific: config paths]
```

## Remaining Issues (Priority Order)

1. [Issue description — no paths, keybinds, or process names]
2. [Issue description]
3. …

## Key Decisions Recap

| Decision | Rationale |
|----------|-----------|
| [Decision] | [Rationale] |

## Commands to Verify Everything

```bash
# Generic verification commands only — no operator-specific targets.
# Example shape:
#   <process-manager> status
#   <config-validator> validate
```

## Template Rules

- Copy this file for a new handoff; fill placeholders with GENERIC descriptions.
- Never paste real paths, process names, keybinds, or credentials.
- If a detail would help a future operator but is sensitive, write
  `[REDACTED - operator-specific]` instead.
- Delete or rotate handoffs once superseded.
