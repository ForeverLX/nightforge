# Azrael Security — Global Agent Rules

## Commands
```bash
# Search — NightForge only (find is aliased to fd)
rg <pattern> <path>

# NixOS changes — Tairn only
nixos-rebuild switch   # MUST run after every configuration.nix change
```

## Stack
- Languages: C, Go (Rust deferred to Q4 review)
- Go: MUST use absolute paths — relative paths cause invocation-dir drift
- All Tairn config: MUST go in configuration.nix, never imperative changes

## Infrastructure
Cerberus   10.0.0.1  edge node, Podman rootless Quadlets
NightForge 10.0.0.3  operator workstation, all code written here
Tairn      10.0.0.4  NixOS, Mythic C2, WireGuard-only access
Hermes     10.0.0.5  Alpine redirector, disposable

## Git
- Commit messages: multi-line, bullet breakdown explaining why not what
- Branch policy: MUST use review/* prefix — operator reviews before merge to main
- NEVER add Co-Authored-By trailers

## NEVER
- Write outside the scoped project directory
- Modify ~/.ssh, /etc/wireguard, or WireGuard keys without explicit instruction
- Commit tokens, keys, passwords, or credentials
- Push directly to main
- Generate code the operator should be writing themselves (write-first rule applies to skill work)
