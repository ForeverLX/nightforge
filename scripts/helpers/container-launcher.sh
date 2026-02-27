#!/bin/bash
# Container Launcher - Interactive Menu with Engagement Selection

# First, select container
CONTAINER=$(cat << 'EOF' | fuzzel --dmenu --prompt "Container:" --width 60
🌐 Web (Recon & OSINT)
🔍 RE (Reverse Engineering)
🏢 AD (Active Directory)
🛠️  Toolbox (Base Utilities)
EOF
)

[ -z "$CONTAINER" ] && exit 0

# If Web/AD selected, prompt for engagement directory
if [[ "$CONTAINER" =~ "Web" ]] || [[ "$CONTAINER" =~ "AD" ]]; then
    # Get list of engagement directories
    ENGAGEMENTS=$(find ~/engage -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort)
    
    if [ -z "$ENGAGEMENTS" ]; then
        # No engagements, just use ~/engage
        ENGAGEMENT_DIR="$HOME/engage"
    else
        # Let user pick engagement
        SELECTED=$(echo "$ENGAGEMENTS" | fuzzel --dmenu --prompt "Engagement:" --width 60)
        
        if [ -z "$SELECTED" ]; then
            exit 0
        fi
        
        ENGAGEMENT_DIR="$HOME/engage/$SELECTED"
    fi
else
    # For RE/Toolbox, use current directory or home
    ENGAGEMENT_DIR="$PWD"
fi

# Launch container in selected directory
case "$CONTAINER" in
    *"Web"*)
        ghostty -e bash -c "cd '$ENGAGEMENT_DIR' && ~/Github/offsec-workstation/modules/container/scripts/container.sh run web; exec bash"
        ;;
    *"RE"*)
        ghostty -e bash -c "cd '$ENGAGEMENT_DIR' && ~/Github/offsec-workstation/modules/container/scripts/container.sh run re; exec bash"
        ;;
    *"AD"*)
        ghostty -e bash -c "cd '$ENGAGEMENT_DIR' && ~/Github/offsec-workstation/modules/container/scripts/container.sh run ad; exec bash"
        ;;
    *"Toolbox"*)
        ghostty -e bash -c "cd '$ENGAGEMENT_DIR' && ~/Github/offsec-workstation/modules/container/scripts/container.sh run toolbox; exec bash"
        ;;
esac
