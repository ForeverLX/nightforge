# === MODERN COMMAND REPLACEMENTS ===
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias lta='eza --tree -a --level=2 --icons'

alias cat='bat --paging=never'
alias catp='bat'

alias top='htop'

# === SAFETY ALIASES ===
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# === WIREGUARD ===
alias wgup='sudo resolvconf -u && sudo wg-quick up wg0'
alias wgdown='sudo wg-quick down wg0'
alias wgstat='sudo wg show'
alias mesh='sudo wg show && echo "---" && ping -c 1 -W 1 10.0.0.1 && ping -c 1 -W 1 10.0.0.4 && ping -c 1 -W 1 10.0.0.5'

# === NFTABLES ===
alias nftstat='sudo nft list ruleset'
alias nftreload='sudo nft -f /etc/nftables.conf'

# === AUR (paru) ===
alias aur='paru -S'
alias aurinfo='paru -Si'

# === GIT ===
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'

# === TMUX ===
alias ts='~/Github/nightforge/scripts/tmux-session.sh'
alias ta='tmux attach -t'
alias tl='tmux list-sessions'
alias tn='tmux new-session -s'

# === AGENT OBSERVER (AgentsView) — decommissioned 2026-08-08 (archived) ===
# av / av-serve / av-usage / av-stop + agent-budget removed with agentsview

# === AGENT WRAPPERS (bws run -- for secret injection) ===

# === HERMES ===
# hermes launcher already wraps bws in ~/.local/bin/hermes
alias h='hermes'

# === VAULT & OPS NAVIGATION ===
alias vault='cd ~/Documents/cr1ms0n-vault'
alias ops='cd ~/Documents/cr1ms0n-ops'
alias research='cd ~/Github/security-research'

# === STOW ===
alias stow='stow --dir ~/Github/nightforge/dotfiles --target ~'

# === SYSTEM UPDATE ===
alias update='cr1ms0n-update'

# === NAVIGATION ===
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'
