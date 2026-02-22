#!/bin/bash
# Zellij Container Launcher
# Usage: zellij-launch <profile> <layout>
# Example: zellij-launch web recon

set -euo pipefail

PROFILE="${1:-}"
LAYOUT="${2:-}"
WORK_DIR="${3:-$PWD}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONTAINER_SCRIPT="$REPO_ROOT/modules/container/scripts/container.sh"
LAYOUT_DIR="$HOME/.config/zellij/layouts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $(basename "$0") <profile> <layout> [work_dir]

Launch a Zellij session with an offsec container profile.

Profiles:
  web      - Web/OSINT reconnaissance container
  re       - Reverse engineering & exploit dev
  ad       - Active Directory assessment
  toolbox  - Base container with core tools

Layouts:
  recon    - Reconnaissance & intelligence gathering
  exploit  - Active exploitation workspace
  ad       - Active Directory assessment
  web      - Web application testing

Examples:
  $(basename "$0") web recon
  $(basename "$0") re exploit
  $(basename "$0") ad ad /path/to/engagement
  $(basename "$0") toolbox recon

Environment:
  WORK_DIR - Directory to mount in container (default: \$PWD)
EOF
    exit 1
}

# Validate inputs
if [[ -z "$PROFILE" ]] || [[ -z "$LAYOUT" ]]; then
    usage
fi

# Validate profile
case "$PROFILE" in
    web|re|ad|toolbox)
        ;;
    *)
        echo -e "${RED}Error: Invalid profile '$PROFILE'${NC}"
        echo "Valid profiles: web, re, ad, toolbox"
        exit 1
        ;;
esac

# Validate layout exists
LAYOUT_FILE="$LAYOUT_DIR/${LAYOUT}.kdl"
if [[ ! -f "$LAYOUT_FILE" ]]; then
    echo -e "${RED}Error: Layout file not found: $LAYOUT_FILE${NC}"
    echo "Available layouts:"
    ls -1 "$LAYOUT_DIR"/*.kdl 2>/dev/null | xargs -n1 basename -s .kdl || echo "  (none)"
    exit 1
fi

# Check if container image exists
IMAGE="localhost/offsec-${PROFILE}:0.1.0"
if ! podman image exists "$IMAGE"; then
    echo -e "${RED}Error: Container image not found: $IMAGE${NC}"
    echo "Build it first: $CONTAINER_SCRIPT build $PROFILE"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Zellij Container Launcher${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}Profile:${NC}  $PROFILE"
echo -e "${GREEN}Layout:${NC}   $LAYOUT"
echo -e "${GREEN}Workdir:${NC}  $WORK_DIR"
echo -e "${GREEN}Image:${NC}    $IMAGE"
echo ""

# Create session name
SESSION_NAME="offsec-${PROFILE}-$(date +%Y%m%d-%H%M%S)"

# Start container in background
echo -e "${YELLOW}Starting container...${NC}"
CONTAINER_ID=$(podman run -d \
    --name "$SESSION_NAME" \
    -v "$WORK_DIR:/work:z" \
    -w /work \
    --cap-add=NET_RAW \
    --cap-add=NET_ADMIN \
    --hostname "offsec-${PROFILE}" \
    "$IMAGE" \
    sleep infinity)

echo -e "${GREEN}✓ Container started: ${CONTAINER_ID:0:12}${NC}"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up container...${NC}"
    podman stop "$SESSION_NAME" >/dev/null 2>&1 || true
    podman rm "$SESSION_NAME" >/dev/null 2>&1 || true
    echo -e "${GREEN}✓ Container removed${NC}"
}

trap cleanup EXIT INT TERM

# Launch Zellij with container exec
echo -e "${YELLOW}Launching Zellij session...${NC}"
echo -e "${BLUE}Press Ctrl+g to lock/unlock, Ctrl+q to quit${NC}"
echo ""

# Give container a moment to be ready
sleep 1

# Copy layout to container work dir for reference
podman cp "$LAYOUT_FILE" "$SESSION_NAME:/work/.zellij-layout.kdl" 2>/dev/null || true

# Launch Zellij on HOST, executing commands in container
echo -e "${BLUE}Launching Zellij on host with container execution...${NC}"

# Create a wrapper script that execs into container
WRAPPER_SCRIPT=$(mktemp)
cat > "$WRAPPER_SCRIPT" << 'WRAPPER_EOF'
#!/bin/bash
exec podman exec -it \
    -e TERM=xterm-256color \
    CONTAINER_NAME_PLACEHOLDER \
    bash -l -c "cd /work && exec bash"
WRAPPER_EOF

# Replace placeholder with actual container name
sed -i "s/CONTAINER_NAME_PLACEHOLDER/$SESSION_NAME/" "$WRAPPER_SCRIPT"
chmod +x "$WRAPPER_SCRIPT"

# Launch Zellij with the wrapper as the command
zellij \
    --layout "$LAYOUT_FILE" \
    options --default-shell "$WRAPPER_SCRIPT"

# Cleanup wrapper
rm -f "$WRAPPER_SCRIPT"
