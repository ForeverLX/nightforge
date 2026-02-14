# offsec-workstation zsh drop-in
# Sourced from ~/.zshrc — keep this file safe and additive.

# Core daily workflow aliases
alias v="nvim"
alias ls="eza"

# Set nvim as text editor
export EDITOR=nvim
export VISUAL=nvim

# Yazi: exit into the last directory you visited
function y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  cwd="$(cat -- "$tmp" 2>/dev/null || true)"
  [[ -n "$cwd" && -d "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# Fuzzy file picker with preview
# Requires: bat, rg, fzf
alias ff='rg --files | fzf --preview "bat --style=numbers --color=always {}"'

# zoxide (smart directory jumping)
eval "$(zoxide init zsh)"

# Standard line-editing keybindings (Home/End, Ctrl-Left/Right)
# Works in most terminals; harmless if a sequence isn't emitted by a terminal.
bindkey -e

# Home/End (common sequences)
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[7~' beginning-of-line
bindkey '^[[8~' end-of-line

# Ctrl-Left / Ctrl-Right (common sequences)
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[5D' backward-word
bindkey '^[[5C' forward-word

