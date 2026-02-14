#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  toolbox.sh [--help] [command...]

Examples:
  ./modules/container/scripts/toolbox.sh
  ./modules/container/scripts/toolbox.sh zsh -l
  IMG=localhost/offsec-toolbox:0.1.0 ./modules/container/scripts/toolbox.sh
  LOOT_MODE=ro ./modules/container/scripts/toolbox.sh

Env:
  IMG        Image to run (default: localhost/offsec-toolbox:0.1.0)
  LOOT_MODE  rw|ro (default: rw)
  NET_MODE   Rootless network backend (default: pasta)

Notes:
  - Mounts the workstation directory contract into /work/*
  - Default command is: zsh -l
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

IMG="${IMG:-localhost/offsec-toolbox:0.1.0}"

ENGAGE="${HOME}/engage"
LOOT="${HOME}/loot"
NOTES="${HOME}/notes"
EXPLOITDEV="${HOME}/exploitdev"
PROJECTS="${HOME}/projects"
LOOT_MODE="${LOOT_MODE:-rw}"     # rw | ro
NET_MODE="${NET_MODE:-pasta}"    # matches your podman info (rootlessNetworkCmd: pasta)

die(){ echo "[!] $*" >&2; exit 1; }

for d in "$ENGAGE" "$LOOT" "$NOTES" "$EXPLOITDEV" "$PROJECTS"; do
  [[ -d "$d" ]] || die "Missing directory: $d"
done

case "$LOOT_MODE" in
  ro|rw) ;;
  *) die "Invalid LOOT_MODE=$LOOT_MODE (use rw or ro)" ;;
esac

# Default command (IMPORTANT: array, not a single string)
CMD=(bash -l)
if [[ $# -gt 0 ]]; then
  CMD=("$@")
fi

exec podman run --rm -it \
  --name offsec-toolbox \
  --network "$NET_MODE" \
  --userns=keep-id \
  -e TERM="$TERM" \
  -e COLORTERM="${COLORTERM:-truecolor}" \
  -v "${ENGAGE}:/work/engage:rw" \
  -v "${LOOT}:/work/loot:${LOOT_MODE}" \
  -v "${NOTES}:/work/notes:rw" \
  -v "${EXPLOITDEV}:/work/exploitdev:rw" \
  -v "${PROJECTS}:/work/projects:rw" \
  -w /work \
  "$IMG" \
  "${CMD[@]}"

