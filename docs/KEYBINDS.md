# Keybind Contract (Operator Cheat Sheet)

This workstation uses a two-layer model:
- **tmux** = session/workspace control
- **neovim** = editing + project navigation
- **shell** = fast entrypoints (aliases/functions)

## tmux (prefix = Ctrl+a)
- `Ctrl+a |` : split pane (left/right)
- `Ctrl+a -` : split pane (top/bottom)
- `Ctrl+a h/j/k/l` : move between panes
- `Ctrl+a H/J/K/L` : resize panes (repeatable)
- `Ctrl+a [` : enter copy mode (vi)
- Copy mode: `Space` select, `y` yank → system clipboard (wl-copy)
- `Ctrl+a r` : reload tmux config

## Neovim (leader = Space)
- `Space f f` : find files (fd)
- `Space f g` : live grep (rg)
- `Space f b` : buffers

## Shell (zsh drop-in: offsec.zsh)
- `v` : open Neovim
- `y` : open yazi; on exit, shell cwd follows yazi
- `ff` : fuzzy pick file w/ preview (rg → fzf → bat)
