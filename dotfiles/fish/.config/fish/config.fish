# NightForge fish config
# Minimal, ops-focused — no desktop-environment branding

# === PATH ===
fish_add_path ~/.local/bin
fish_add_path ~/Github/nightforge/scripts

# === ENV ===
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx PAGER less
set -gx LESS "-R --mouse"
set -gx FZF_DEFAULT_OPTS "--height 40% --layout=reverse --border"

# === ALIASES ===
alias .. "cd .."
alias ... "cd ../.."
alias ll "ls -la"
alias la "ls -A"
alias l "ls -CF"
alias grep "grep --color=auto"
alias fgrep "fgrep --color=auto"
alias egrep "egrep --color=auto"

# NightForge ops aliases
alias nf "cd ~/Github/nightforge"
alias nfi "cd ~/Github/nightforge && nvim"
alias pods "podman ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'"
alias podlogs "podman logs -f"
alias wgup "sudo wg-quick up wg0"
alias wgdown "sudo wg-quick down wg0"
alias wgstat "wg show"

# === FUNCTIONS ===

# Quick engagement context viewer
function engagement
    cat ~/.config/nightforge/engagement-context.json 2>/dev/null || echo "No active engagement"
end

# Performance mode toggle
function perf
    set mode $argv[1]
    if test -z "$mode"
        cat ~/.config/nightforge/performance-mode 2>/dev/null || echo "normal"
    else
        echo $mode > ~/.config/nightforge/performance-mode
        echo "Performance mode: $mode"
    end
end

# MPD now-playing
function np
    mpc status
end

# Fastfetch wrapper
function ff
    fastfetch --config ~/.config/fastfetch/config.jsonc
end

# === KEY BINDINGS ===
# None by default — keep it minimal

# === STARTUP ===
# Starship prompt
if type -q starship
    starship init fish | source
end

# Direnv
if type -q direnv
    direnv hook fish | source
end

# Greeting
function fish_greeting
    echo "NightForge operator shell ready."
end
