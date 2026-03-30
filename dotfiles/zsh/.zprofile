# SSH agent key loading — load homelab key if agent is running and key not loaded
if systemctl --user is-active ssh-agent.service >/dev/null 2>&1; then
    ssh-add -l >/dev/null 2>&1 || ssh-add ~/.ssh/homelab-id_ed25519 2>/dev/null
fi
