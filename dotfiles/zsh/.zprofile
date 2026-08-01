# shellcheck disable=SC2148
# SSH agent key loading — load homelab key if agent is running and key not loaded
if systemctl --user is-active ssh-agent.service >/dev/null 2>&1; then
    ssh-add ~/.ssh/homelab-id_ed25519 2>/dev/null
fi

# ========== POST-LLMTRIM OVERRIDES (must come AFTER the llmtrim block) ==========
# Add Bitwarden + GitLawb to NO_PROXY so bws/gitlawb don't tunnel through llmtrim.
# llmtrim setup rewrites its own block on re-run; this block re-merges our additions
# so future re-installs don't silently break bws.
export NO_PROXY="api.bitwarden.com,vault.bitwarden.com,vault.bitwarden.eu,node.gitlawb.com,api.gitlawb.com,localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,fd00::/8,*.local"
export no_proxy="$NO_PROXY"

# >>> llmtrim >>>
if command -v llmtrim >/dev/null 2>&1 && llmtrim _alive 2>/dev/null; then
    export HTTPS_PROXY="http://127.0.0.1:43117"
    export HTTP_PROXY="http://127.0.0.1:43117"
    export NO_PROXY="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,fd00::/8,*.local"
    export no_proxy="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,fd00::/8,*.local"
    export NODE_EXTRA_CA_CERTS="/home/ForeverLX/.llmtrim/ca.pem"
    export SSL_CERT_FILE="/home/ForeverLX/.llmtrim/ca-bundle.pem"
    export CURL_CA_BUNDLE="/home/ForeverLX/.llmtrim/ca-bundle.pem"
fi
# <<< llmtrim <<<
