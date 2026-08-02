# Security Policy

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

## Network Posture

- `harnessd` binds **127.0.0.1:9191** only — no remote access
- Go daemon is stdlib-only with zero external network calls
- CORS middleware allows local development origins only (`GET`, `OPTIONS`)

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

## Known Security Considerations

- `dotfiles/` contains personal workstation configuration — review before
  sharing externally
- Deployed dotfiles (`dotfiles/matugen/`) reflect live desktop state and are
  operator-owned
