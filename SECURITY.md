# Security Policy

## Repository Visibility

**This repository is PUBLIC.** Everything committed to `main` is visible to
anyone with access to the remote. Treat committed content as public:

- No credentials, API keys, tokens, or secrets — ever
- No operational data: running process names, keybinds, file paths,
  hostnames, internal IPs, or engagement details
- Redact anything operator-specific with `[REDACTED - operator-specific]`

## Supported Versions

Rolling-release operator workstation configuration. No versioned releases —
security fixes are applied to the `main` branch.

## Reporting a Vulnerability

For operational security reasons, **do not file public issues** for security
vulnerabilities.

- **GitHub Issues**: tag with the `security` label for low-sensitivity items
- **Direct message**: for sensitive disclosures, reach out via GitHub to
  CR1MS0N-Operator

## OPSEC Commitments

- No hardcoded credentials, API keys, or tokens in this repository
- Secrets use environment-variable references or placeholder values
- `.gitignore` blocks secret-bearing files (`*.env`, `.env.*`) and build
  artifacts (`harnessd`, `nightforged`, `*.tar`, `target/`)
- Internal IP ranges (10.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12) appear only
  in documentation examples
- Session handoffs (`docs/archive/`) are sanitized templates only — never
  commit operational data in handoff notes

## Known Token Exposure (2026-08-01)

The local `forgejo` remote URL in `.git/config` previously contained an
embedded credential token. Remediation completed:

- Token removed from the remote URL (now `http://localhost:3000/...`)
- No occurrence of the token remains in `.git/config`
- **Action required by operator:** rotate the token at the forgejo instance —
  it was exposed in local config and may exist in shell history/backups

## Network Posture

- `harnessd` binds **127.0.0.1:9191** only — no remote access
- Go daemon makes zero external network calls (only `go-chi/chi/v5` + stdlib)
- CORS middleware allows local development origins only (`GET`, `OPTIONS`)
- Observability stack services bind loopback only (31744–31750, see
  `10-layer-stack/README.md`) — **not started automatically**; operator
  populates `.env` secrets before first run

## Container Security

- All container profiles run rootless via Podman (`--userns=keep-id`)
- Builds use host networking for package downloads; runtime uses bridge
  networking with minimal capabilities (`NET_RAW`, `NET_ADMIN`)
- Engagement directories are mounted read-write; application-level isolation
  is the operator's responsibility

## Secure Development

- CI enforces `go build` + `go vet`, shellcheck, and `bash -n` syntax checks
- Removed components (`session-tracker`, `dashboard-ctl`, `.claude/`, …) are
  gitignored to prevent accidental reintroduction
- Scripts avoid `eval`/command injection patterns; secrets stay out of
  command lines

## OPSEC Guidelines for Documentation

- Docs must describe the environment generically; never name real running
  processes, bind keybinds, or quote live config paths
- Use the sanitized templates in `docs/archive/` for any handoff content
- If a doc needs to reference something sensitive, write
  `[REDACTED - operator-specific]` and keep the detail out of the repo

## Known Security Considerations

- `dotfiles/` contains personal workstation configuration — review before
  sharing externally
- Deployed dotfiles (`dotfiles/matugen/`) reflect live desktop state and are
  operator-owned
- `data/` contains operator telemetry — never commit new entries
