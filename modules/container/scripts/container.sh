#!/bin/bash
# Unified container orchestration script
# Usage: ./container.sh [ACTION] [PROFILE]
#
# Actions:
#   build [profile]     - Build a specific profile (toolbox|ad|re|web)
#   build-all           - Build all profiles in dependency order
#   run [profile]       - Run a specific profile container
#   clean               - Remove dangling/unused images
#   export [profile]    - Export profile to tar archive
#   import [file]       - Import profile from tar archive
#   list                - List all built profile images
#
# Examples:
#   ./container.sh build toolbox
#   ./container.sh build-all
#   ./container.sh run ad
#   ./container.sh export ad
#   ./container.sh clean

set -euo pipefail

VERSION="0.1.0"
DATE_TAG=$(date +%Y%m%d)

# Map profile to folder and tag
declare -A FOLDERS=(
  ["toolbox"]="toolbox"
  ["ad"]="ad"
  ["re"]="re"
  ["web"]="web"
)

declare -A TAGS=(
  ["toolbox"]="localhost/offsec-toolbox:${VERSION}"
  ["ad"]="localhost/offsec-ad:${VERSION}"
  ["re"]="localhost/offsec-re:${VERSION}"
  ["web"]="localhost/offsec-web:${VERSION}"
)

# Define build order (toolbox must be first)
BUILD_ORDER=("toolbox" "ad" "re" "web")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[*]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Verify required directories for container mounts
verify_directories() {
  local dirs=("$HOME/engage" "$HOME/loot" "$HOME/notes" "$HOME/exploitdev" "$HOME/projects")
  local missing=()
  
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      missing+=("$dir")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "Missing directories (will be created on first run):"
    for dir in "${missing[@]}"; do
      echo "  - $dir"
    done
  fi
}

# Build a single profile
build_profile() {
  local profile=$1
  local folder=${FOLDERS[$profile]:?Unknown profile $profile}
  local tag=${TAGS[$profile]:?Unknown profile $profile}
  
  log_info "Building $profile container ($tag)..."
  
  if ! podman build -t "$tag" \
    -t "localhost/offsec-${profile}:${DATE_TAG}" \
    -f "modules/container/$folder/Containerfile" \
    .; then
    log_error "Build failed for $profile"
    return 1
  fi
  
  log_info "Successfully built $profile ($tag)"
  log_info "Date-tagged as: localhost/offsec-${profile}:${DATE_TAG}"
}

# Build all profiles in correct order
build_all() {
  log_info "Building all profiles in dependency order..."
  
  for profile in "${BUILD_ORDER[@]}"; do
    build_profile "$profile" || {
      log_error "Build pipeline failed at $profile"
      return 1
    }
  done
  
  log_info "All profiles built successfully!"
}

# Run a container with proper mounts
run_profile() {
  local profile=$1
  local tag=${TAGS[$profile]:?Unknown profile $profile}
  
  log_info "Running $profile container..."
  verify_directories
  
  # Standard mounts (explicit and narrow)
  local mounts=(
    "-v" "$HOME/engage:/engage:Z"
    "-v" "$HOME/loot:/loot:Z"
    "-v" "$HOME/notes:/notes:Z"
    "-v" "$HOME/exploitdev:/exploitdev:Z"
    "-v" "$HOME/projects:/projects:Z"
  )
  
  podman run --rm -it "${mounts[@]}" "$tag"
}

# Clean unused images
clean_images() {
  log_info "Cleaning dangling and unused images..."
  
  # Remove dangling images
  podman image prune -f
  
  # List offsec images for manual cleanup if needed
  log_info "Current offsec images:"
  podman images | grep -E "offsec-|REPOSITORY" || log_warn "No offsec images found"
}

# Export profile to tar archive
export_profile() {
  local profile=$1
  local tag=${TAGS[$profile]:?Unknown profile $profile}
  local output_file="offsec-${profile}-${VERSION}-${DATE_TAG}.tar"
  
  log_info "Exporting $profile to $output_file..."
  
  if ! podman save -o "$output_file" "$tag"; then
    log_error "Export failed for $profile"
    return 1
  fi
  
  log_info "Exported to: $output_file"
  log_info "Size: $(du -h "$output_file" | cut -f1)"
}

# Import profile from tar archive
import_profile() {
  local archive=$1
  
  if [[ ! -f "$archive" ]]; then
    log_error "Archive not found: $archive"
    return 1
  fi
  
  log_info "Importing from $archive..."
  
  if ! podman load -i "$archive"; then
    log_error "Import failed"
    return 1
  fi
  
  log_info "Successfully imported image(s)"
}

# List all built profiles
list_profiles() {
  log_info "Built profile images:"
  podman images | grep -E "offsec-|REPOSITORY" || log_warn "No offsec images found"
}

# Main command dispatcher
ACTION=${1:-}
PROFILE=${2:-}

case $ACTION in
  build)
    if [[ -z "$PROFILE" ]]; then
      log_error "Usage: $0 build [toolbox|ad|re|web]"
      exit 1
    fi
    build_profile "$PROFILE"
    ;;
    
  build-all)
    build_all
    ;;
    
  run)
    if [[ -z "$PROFILE" ]]; then
      log_error "Usage: $0 run [toolbox|ad|re|web]"
      exit 1
    fi
    run_profile "$PROFILE"
    ;;
    
  clean)
    clean_images
    ;;
    
  export)
    if [[ -z "$PROFILE" ]]; then
      log_error "Usage: $0 export [toolbox|ad|re|web]"
      exit 1
    fi
    export_profile "$PROFILE"
    ;;
    
  import)
    if [[ -z "$PROFILE" ]]; then
      log_error "Usage: $0 import [archive.tar]"
      exit 1
    fi
    import_profile "$PROFILE"
    ;;
    
  list)
    list_profiles
    ;;
    
  *)
    echo "Usage: $0 [ACTION] [PROFILE]"
    echo ""
    echo "Actions:"
    echo "  build [profile]     - Build a specific profile (toolbox|ad|re|web)"
    echo "  build-all           - Build all profiles in dependency order"
    echo "  run [profile]       - Run a specific profile container"
    echo "  clean               - Remove dangling/unused images"
    echo "  export [profile]    - Export profile to tar archive"
    echo "  import [file]       - Import profile from tar archive"
    echo "  list                - List all built profile images"
    echo ""
    echo "Examples:"
    echo "  $0 build toolbox"
    echo "  $0 build-all"
    echo "  $0 run ad"
    echo "  $0 export ad"
    echo "  $0 clean"
    exit 1
    ;;
esac
