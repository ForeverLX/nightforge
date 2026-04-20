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

## Model Mappings
- **plan**: openrouter/deepseek/deepseek-v3.2 (reasoning)
- **build**: openrouter/mistralai/codestral-2508 (execution)
- **review**: openrouter/nvidia/nemotron-3-super-120b-a12b:free (agentic)
- **commit**: openrouter/google/gemini-2.5-flash (qa/ci)

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

## Output Rules (All Agents)
- Output diffs only unless prose explanation is explicitly requested
- Limit explanations to 3 bullets maximum
- Never summarize what you just did — the diff is the summary
- Prefer single atomic commits over batched multi-concern commits
- Format code output as fenced blocks with language tag always

## Token Constraints
- Maximum 32K tokens input context per call
- If context approaches limit, summarize prior tool outputs before continuing
- Do not re-read files already in context — reference by filename only

## OPSEC Rules (All Agents)
- Never write credentials, API keys, or tokens to any file
- Never commit files in ~/.ssh/, /etc/wireguard/, or /etc/nftables.conf
- Always confirm before any destructive bash operation
- Redact IP addresses in the 10.0.0.0/24 and 192.168.1.0/24 ranges from any output intended for external submission
