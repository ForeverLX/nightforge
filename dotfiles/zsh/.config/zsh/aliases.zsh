# ========== MODERN COMMAND REPLACEMENTS ==========
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias lta='eza --tree -a --level=2 --icons'

alias cat='bat --paging=never'
alias catp='bat'

alias grep='rg'
alias grepi='rg -i'

alias find='fd'

alias du='ncdu'

alias top='htop'

# ========== SAFETY ALIASES ==========
# Choose one: interactive rm or trash
alias rm='rm -i'                     # interactive deletion
# alias rm='trash-put'                # uncomment if you install trash-cli

alias cp='cp -i'
alias mv='mv -i'

# ========== OFFENSIVE SECURITY & ENGAGEMENT ==========
alias engage='cd ~/engage/current'
alias loot='cd ~/engage/current/loot'
alias recon='cd ~/engage/current/recon'
alias notes='cd ~/engage/current/notes'

# Container management
alias ctb='~/Github/nightforge/modules/container/scripts/container.sh'
alias cad='ctb run ad'
alias cre='ctb run re'
alias cweb='ctb run web'
alias ctool='ctb run toolbox'
alias cls='podman ps'
alias clsa='podman ps -a'
alias cstop='podman stop $(podman ps -q) 2>/dev/null || true'
alias crm='podman rm $(podman ps -aq) 2>/dev/null || true'

# MITRE log viewer (from current directory)
alias mitre='cat mitre.log 2>/dev/null | column -t -s " "'

# Network tools
alias myip='curl -s ifconfig.me'
alias ports='sudo ss -tulpn'
alias scan='nmap -T4 -sV'                     # your standard scan
alias scan-quick='nmap -T4 -F -sV'             # fast scan (top 100 ports)
alias scan-full='nmap -T4 -p- -sV'              # all ports
alias scan-deep='nmap -T4 -A -p-'                # aggressive all ports

# Git shortcuts
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'

# Tmux shortcuts
alias ts='~/Github/nightforge/scripts/tmux-session.sh'
alias ta='tmux attach -t'
alias tl='tmux list-sessions'
alias tn='tmux new-session -s'

# Engagement initialization
alias new-engagement='~/Github/nightforge/scripts/engagement/init-engagement.sh'

# System update
alias update='sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && sudo pacman -Syu'

# ========== NAVIGATION SHORTCUTS ==========
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'
