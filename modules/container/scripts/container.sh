#!/bin/bash
# Container Management Script - Enhanced UX
# Location: modules/container/scripts/container.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORK_DIR="${WORK_DIR:-$PWD}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $(basename "$0") <command> <profile> [options]

Commands:
    build <profile>    Build a container profile
    run <profile>      Run a container interactively
    exec <profile>     Execute command in running container
    list               List all built images
    clean              Remove old/dangling images

Profiles:
    toolbox    Base container with core utilities
    web        Web reconnaissance and OSINT
    re         Reverse engineering and exploit development
    ad         Active Directory assessment

Examples:
    $(basename "$0") build web
    $(basename "$0") run web
    $(basename "$0") list
EOF
    exit 1
}

check_engagement_dir() {
    local current_dir="$PWD"
    
    # Check if we're in an engagement directory
    if [[ "$current_dir" =~ /engage/[^/]+$ ]]; then
        return 0  # We're in an engagement dir
    fi
    
    # Check if we have engagement structure
    if [[ -d "c2" ]] || [[ -d "recon" ]] || [[ -d "exploit" ]]; then
        return 0  # Looks like engagement dir
    fi
    
    return 1  # Not an engagement dir
}

check_permissions() {
    local dir="$1"
    local perms=$(stat -c "%a" "$dir" 2>/dev/null || echo "000")
    
    if [[ "$perms" == "777" ]]; then
        return 0
    fi
    
    return 1
}

warn_not_in_engagement() {
    echo -e "${YELLOW}⚠️  Warning: You're not in an engagement directory${NC}"
    echo -e "${BLUE}Current directory:${NC} $PWD"
    echo ""
    echo -e "${YELLOW}The container will mount:${NC} $PWD → /work"
    echo ""
    echo -e "${BLUE}Recommendations:${NC}"
    echo "  1. cd ~/engage/<engagement-name>"
    echo "  2. chmod 777 ."
    echo "  3. Run this command again"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
}

warn_permissions() {
    local dir="$1"
    local perms=$(stat -c "%a" "$dir")
    
    echo -e "${YELLOW}⚠️  Warning: Directory permissions are $perms (not 777)${NC}"
    echo -e "${BLUE}Directory:${NC} $dir"
    echo ""
    echo -e "${YELLOW}You may encounter permission errors in the container.${NC}"
    echo ""
    echo -e "${BLUE}Fix with:${NC} chmod 777 $dir"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
}

build() {
    local PROFILE="$1"
    local IMAGE="localhost/offsec-${PROFILE}:0.1.0"
    local DATE_TAG="localhost/offsec-${PROFILE}:$(date +%Y%m%d)"
    local CONTAINERFILE="$REPO_ROOT/modules/container/${PROFILE}/Containerfile"

    if [[ ! -f "$CONTAINERFILE" ]]; then
        echo -e "${RED}[ERROR]${NC} Containerfile not found: $CONTAINERFILE"
        exit 1
    fi

    echo -e "${BLUE}[*]${NC} Building ${PROFILE} container (${IMAGE})..."
    
    if podman build \
        -f "$CONTAINERFILE" \
        -t "$IMAGE" \
        -t "$DATE_TAG" \
        "$REPO_ROOT"; then
        echo -e "${GREEN}[*]${NC} Successfully built ${PROFILE} (${IMAGE})"
        echo -e "${GREEN}[*]${NC} Date-tagged as: ${DATE_TAG}"
    else
        echo -e "${RED}[ERROR]${NC} Build failed for ${PROFILE}"
        exit 1
    fi
}

run() {
    local PROFILE="$1"
    local IMAGE="localhost/offsec-${PROFILE}:0.1.0"

    if ! podman image exists "$IMAGE"; then
        echo -e "${RED}[ERROR]${NC} Image not found: $IMAGE"
        echo "Build it first: $0 build $PROFILE"
        exit 1
    fi

    # Check if we're in an engagement directory
    if ! check_engagement_dir; then
        warn_not_in_engagement
    fi
    
    # Check permissions
    if ! check_permissions "$WORK_DIR"; then
        warn_permissions "$WORK_DIR"
    fi
    
    echo -e "${BLUE}[*]${NC} Running ${PROFILE} container..."
    echo -e "${BLUE}[*]${NC} Mounting: $WORK_DIR → /work"
    
    # Run container
    podman run -it --rm \
        -v "$WORK_DIR:/work:z" \
        -w /work \
        --cap-add=NET_RAW \
        --cap-add=NET_ADMIN \
        --hostname "offsec-${PROFILE}" \
        "$IMAGE" \
        bash -l
}

list() {
    echo -e "${BLUE}[*]${NC} Built profile images:"
    podman images | grep -E "offsec-(toolbox|web|re|ad)" | sort -k1,1 -k2,2
}

clean() {
    echo -e "${YELLOW}[*]${NC} Cleaning up old images..."
    
    # Remove dangling images
    podman image prune -f
    
    echo -e "${GREEN}[*]${NC} Cleanup complete"
}

# Main
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
    build)
        PROFILE="${1:-}"
        [[ -z "$PROFILE" ]] && usage
        build "$PROFILE"
        ;;
    run)
        PROFILE="${1:-}"
        [[ -z "$PROFILE" ]] && usage
        run "$PROFILE"
        ;;
    list)
        list
        ;;
    clean)
        clean
        ;;
    *)
        usage
        ;;
esac
