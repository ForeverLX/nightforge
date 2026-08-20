# PATH for non-interactive SSH sessions (zsh reads .zshenv always).
# Moshi app over SSH runs `moshi-hook ...` — needs ~/.local/bin.
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"

# --- Omarchy (S213 cherry-pick migration) ---
# omarchy-* scripts in ~/.local/bin are symlinks into the clone and resolve
# their assets/defaults relative to $OMARCHY_PATH. Hyprland gets this via
# `env =` in hyprland.conf; interactive/SSH shells need it here too.
export OMARCHY_PATH="$HOME/omarchy-user"
