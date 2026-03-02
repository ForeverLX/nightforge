# offsec-workstation - Enhanced Zsh Configuration
# Fish-like UX with full POSIX compatibility

# ========== POWERLEVEL10K INSTANT PROMPT ==========
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ========== ZINIT PLUGIN MANAGER ==========
# Install zinit if not present
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# ========== THEME ==========
zinit ice depth=1; zinit light romkatv/powerlevel10k

# ========== PLUGINS (Fish-like features) ==========
# Autosuggestions (like Fish)
zinit light zsh-users/zsh-autosuggestions

# Syntax highlighting (like Fish)
zinit light zsh-users/zsh-syntax-highlighting

# Better completions
zinit light zsh-users/zsh-completions

# Auto-close brackets
zinit light hlissner/zsh-autopair

# Substring history search (like Fish)
zinit light zsh-users/zsh-history-substring-search

# ========== OPTIONS ==========
setopt AUTO_CD              # cd by typing directory name
setopt AUTO_PUSHD           # Make cd push old directory onto stack
setopt PUSHD_IGNORE_DUPS    # Don't push duplicate directories
setopt PUSHD_SILENT         # Don't print directory stack
setopt CORRECT              # Spelling correction
setopt EXTENDED_HISTORY     # Record timestamp in history
setopt HIST_IGNORE_ALL_DUPS # Remove older duplicate entries
setopt HIST_REDUCE_BLANKS   # Remove superfluous blanks
setopt INC_APPEND_HISTORY   # Write to history immediately
setopt SHARE_HISTORY        # Share history between sessions
setopt INTERACTIVE_COMMENTS # Allow comments in interactive mode

# ========== HISTORY ==========
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

# ========== COMPLETIONS ==========
autoload -Uz compinit
compinit

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Colored completion (like ls)
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ========== KEY BINDINGS ==========
# Vi mode
bindkey -v
export KEYTIMEOUT=1

# History search with arrow keys
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Ctrl+R for history search (like bash)
bindkey '^R' history-incremental-search-backward

# Accept autosuggestion with Ctrl+Space
bindkey '^ ' autosuggest-accept

# ========== ALIASES ==========
# Modern replacements
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias tree='eza --tree --icons'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git shortcuts
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'

# Container shortcuts
alias ctb='~/Github/offsec-workstation/modules/container/scripts/container.sh'
alias cad='ctb run ad'
alias cre='ctb run re'
alias cweb='ctb run web'
alias ctool='ctb run toolbox'

# Tmux shortcuts
alias ta='tmux attach -t'
alias tl='tmux list-sessions'
alias tn='tmux new-session -s'

# Niri shortcuts
alias niri-reload='niri msg action load-config-file'
alias niri-theme='~/.config/niri/scripts/theme-switch.sh'

# ========== ENVIRONMENT VARIABLES ==========
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'
export LESS='-R'

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# ========== OFFSEC-SPECIFIC ==========
# Engagement directory marker
export OFFSEC_ENGAGE_ROOT="$HOME/engage"

# Auto-activate engagement context if in engage directory
precmd() {
    if [[ $PWD == $OFFSEC_ENGAGE_ROOT/* ]]; then
        # Extract engagement name
        ENGAGEMENT=$(echo $PWD | sed "s|$OFFSEC_ENGAGE_ROOT/||" | cut -d'/' -f1)
        export OFFSEC_CURRENT_ENGAGEMENT="$ENGAGEMENT"
    else
        unset OFFSEC_CURRENT_ENGAGEMENT
    fi
}

# ========== CUSTOM FUNCTIONS ==========
# Quick container access
c() {
    case "$1" in
        ad|re|web|toolbox)
            ~/Github/offsec-workstation/modules/container/scripts/container.sh run "$1"
            ;;
        *)
            echo "Usage: c [ad|re|web|toolbox]"
            ;;
    esac
}

# Create and enter directory
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract archives
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz) tar xzf "$1" ;;
            *.bz2) bunzip2 "$1" ;;
            *.rar) unrar x "$1" ;;
            *.gz) gunzip "$1" ;;
            *.tar) tar xf "$1" ;;
            *.tbz2) tar xjf "$1" ;;
            *.tgz) tar xzf "$1" ;;
            *.zip) unzip "$1" ;;
            *.Z) uncompress "$1" ;;
            *.7z) 7z x "$1" ;;
            *) echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# ========== POWERLEVEL10K CONFIG ==========
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
