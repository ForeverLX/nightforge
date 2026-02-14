#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  toolbox-engage.sh <engagement-name> [--runtime podman|docker] [--image IMAGE]

Defaults:
  --runtime podman
  --image   ghcr.io/foreverlx/offsec-toolbox:dev   (EXAMPLE - you will build/pin later)

Mounts (explicit):
  ~/engage/<name>      -> /work/engage
  ~/loot/<name>        -> /work/loot
  ~/notes/<name>       -> /work/notes
  ~/exploitdev/<name>  -> /work/exploitdev

USAGE
}

[[ $# -ge 1 ]] || { usage; exit 1; }
NAME="$1"; shift

RUNTIME="podman"
IMAGE="ghcr.io/foreverlx/offsec-toolbox:dev"  # EXAMPLE - verify/pin later

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime) RUNTIME="$2"; shift 2 ;;
    --image) IMAGE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

E="$HOME/engage/$NAME"
L="$HOME/loot/$NAME"
N="$HOME/notes/$NAME"
X="$HOME/exploitdev/$NAME"

mkdir -p "$E" "$L" "$N" "$X"
chmod 700 "$L" || true

exec "$RUNTIME" run --rm -it \
  -v "$E:/work/engage:Z" \
  -v "$L:/work/loot:Z" \
  -v "$N:/work/notes:Z" \
  -v "$X:/work/exploitdev:Z" \
  -w /work/engage \
  "$IMAGE"

