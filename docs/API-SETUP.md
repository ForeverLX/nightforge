# API Setup & Configuration Guide

**Version**: v0.5.0  
**Date**: February 2026

This guide covers API key setup for OSINT and reconnaissance tools used in the offsec-workstation environment.

---

## Overview

Many OSINT tools require API keys for full functionality. This guide shows how to:
1. Obtain API keys
2. Securely store them
3. Configure tools to use them
4. Rotate keys regularly

**Security Note**: Never commit API keys to git. Use environment variables or secure config files.

---

## API Key Storage

### Recommended Structure

```bash
# Create secure directory
mkdir -p ~/.config/offsec/api-keys
chmod 700 ~/.config/offsec/api-keys

# Store keys in .env file
cat > ~/.config/offsec/api-keys/.env << 'EOF'
# OSINT API Keys
# DO NOT COMMIT THIS FILE

# Shodan
export SHODAN_API_KEY="your_key_here"

# Censys
export CENSYS_API_ID="your_id_here"
export CENSYS_API_SECRET="your_secret_here"

# GreyNoise
export GREYNOISE_API_KEY="your_key_here"

# VirusTotal
export VT_API_KEY="your_key_here"

# SecurityTrails
export SECURITYTRAILS_API_KEY="your_key_here"

# Hunter.io
export HUNTER_API_KEY="your_key_here"
EOF

chmod 600 ~/.config/offsec/api-keys/.env
```

### Source in Shell

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# Load OSINT API keys if file exists
if [[ -f ~/.config/offsec/api-keys/.env ]]; then
    source ~/.config/offsec/api-keys/.env
fi
```

---

## Tool Configuration

### 1. Shodan

**Website**: https://www.shodan.io  
**Free Tier**: 100 queries/month, limited results

#### Setup

```bash
# Install CLI
pip install --user shodan

# Initialize with API key
shodan init $SHODAN_API_KEY

# Test
shodan info
```

#### Usage

```bash
# Search for services
shodan search "apache 2.4"

# Host lookup
shodan host 8.8.8.8

# Download search results
shodan download --limit 100 results.json.gz "apache"

# Parse results
shodan parse results.json.gz
```

#### Configuration File

Shodan stores config in `~/.shodan/api_key`

---

### 2. Censys

**Website**: https://censys.io  
**Free Tier**: 250 queries/month

#### Setup

```bash
# Install CLI
pip install --user censys

# Configure
censys config set

# Enter API ID and Secret when prompted
```

#### Usage

```bash
# Search hosts
censys search "services.service_name: HTTP"

# View host
censys view 8.8.8.8

# Certificates
censys search "parsed.subject.common_name: example.com" --index certificates
```

#### Configuration File

Censys stores config in `~/.config/censys/censys.cfg`

---

### 3. GreyNoise

**Website**: https://www.greynoise.io  
**Free Tier**: Community edition (limited data)

#### Setup

```bash
# Install CLI
pip install --user greynoise

# Configure
greynoise setup --api-key $GREYNOISE_API_KEY

# Test
greynoise account
```

#### Usage

```bash
# Check if IP is internet noise
greynoise ip 1.1.1.1

# Quick lookup
greynoise quick 8.8.8.8

# RIOT lookup (common business services)
greynoise riot 8.8.8.8
```

---

### 4. ProjectDiscovery Tools

**Website**: https://cloud.projectdiscovery.io  
**Free Tier**: Limited scans

ProjectDiscovery tools (nuclei, subfinder, httpx) can use cloud API for enhanced results.

#### Setup

```bash
# Create config directory
mkdir -p ~/.config/projectdiscovery

# Create config file
cat > ~/.config/projectdiscovery/provider-config.yaml << 'EOF'
projectdiscovery:
  - provider: projectdiscovery
    api_key: $PDCP_API_KEY
EOF

# Set API key
export PDCP_API_KEY="your_key_here"
```

#### Usage

```bash
# Nuclei with cloud templates
nuclei -u https://example.com -cloud

# Subfinder with API enrichment
subfinder -d example.com -all

# httpx with enhanced detection
httpx -l urls.txt -tech-detect
```

---

### 5. VirusTotal

**Website**: https://www.virustotal.com  
**Free Tier**: 500 requests/day, 4 requests/minute

#### Setup

```bash
# Install vt-cli
go install github.com/VirusTotal/vt-cli/vt@latest

# Configure
vt init --apikey $VT_API_KEY
```

#### Usage

```bash
# Scan URL
vt url https://example.com

# Scan file
vt file scan malware.exe

# Domain report
vt domain example.com

# IP address
vt ip 8.8.8.8
```

---

### 6. SecurityTrails

**Website**: https://securitytrails.com  
**Free Tier**: 50 queries/month

#### Setup

```bash
# No official CLI, use API directly
# Store API key in environment
export SECURITYTRAILS_API_KEY="your_key_here"
```

#### Usage (curl)

```bash
# Domain details
curl -H "APIKEY: $SECURITYTRAILS_API_KEY" \
  https://api.securitytrails.com/v1/domain/example.com

# Subdomains
curl -H "APIKEY: $SECURITYTRAILS_API_KEY" \
  https://api.securitytrails.com/v1/domain/example.com/subdomains

# DNS history
curl -H "APIKEY: $SECURITYTRAILS_API_KEY" \
  https://api.securitytrails.com/v1/history/example.com/dns/a
```

---

### 7. Hunter.io

**Website**: https://hunter.io  
**Free Tier**: 25 searches/month

#### Setup

```bash
# No official CLI, use API directly
export HUNTER_API_KEY="your_key_here"
```

#### Usage (curl)

```bash
# Domain search (find emails)
curl "https://api.hunter.io/v2/domain-search?domain=example.com&api_key=$HUNTER_API_KEY"

# Email verifier
curl "https://api.hunter.io/v2/email-verifier?email=test@example.com&api_key=$HUNTER_API_KEY"
```

---

## Container Integration

### Passing API Keys to Containers

**Method 1: Environment variables** (Recommended)

```bash
# Run container with API keys
podman run -it --rm \
  -e SHODAN_API_KEY="$SHODAN_API_KEY" \
  -e CENSYS_API_ID="$CENSYS_API_ID" \
  -e CENSYS_API_SECRET="$CENSYS_API_SECRET" \
  -v $PWD:/work \
  localhost/offsec-web:0.5.0
```

**Method 2: Mount config directory**

```bash
# Mount API config directory (read-only)
podman run -it --rm \
  -v ~/.config/offsec/api-keys:/home/operator/.api-keys:ro,z \
  -v $PWD:/work \
  localhost/offsec-web:0.5.0

# Inside container, source the keys
source /home/operator/.api-keys/.env
```

**Method 3: Config files**

```bash
# Mount individual config directories
podman run -it --rm \
  -v ~/.shodan:/home/operator/.shodan:ro,z \
  -v ~/.config/censys:/home/operator/.config/censys:ro,z \
  -v $PWD:/work \
  localhost/offsec-web:0.5.0
```

---

## Security Best Practices

### 1. Key Rotation

Rotate API keys every 90 days:

```bash
# Backup old keys
cp ~/.config/offsec/api-keys/.env ~/.config/offsec/api-keys/.env.old

# Update with new keys
nvim ~/.config/offsec/api-keys/.env

# Test new keys
shodan info
censys account
```

### 2. Rate Limiting

Respect API rate limits to avoid bans:

```bash
# Add delays between requests
for ip in $(cat ips.txt); do
    shodan host $ip
    sleep 2  # Wait 2 seconds between requests
done
```

### 3. Key Permissions

Ensure API key files have strict permissions:

```bash
# Check permissions
ls -la ~/.config/offsec/api-keys/

# Fix if needed
chmod 700 ~/.config/offsec/api-keys
chmod 600 ~/.config/offsec/api-keys/.env
```

### 4. Never Commit Keys

Add to `.gitignore`:

```bash
# In your engagement directory
cat >> .gitignore << 'EOF'
# API Keys
.env
api-keys/
*.key
*_api_key*
EOF
```

### 5. Use Read-Only Mounts

When mounting config to containers, always use `:ro` flag:

```bash
-v ~/.config/offsec:/config:ro,z
```

---

## Troubleshooting

### API Key Not Working

```bash
# Verify key is set
echo $SHODAN_API_KEY

# Re-source environment
source ~/.zshrc

# Check tool config
shodan info  # Should show account details
```

### Rate Limit Exceeded

```bash
# Check remaining quota
shodan info | grep "Query Credits"
censys account | grep "query_limit"

# Wait or upgrade plan
```

### Container Can't Access Keys

```bash
# Verify mount
podman run --rm \
  -v ~/.config/offsec/api-keys:/keys:ro,z \
  localhost/offsec-web:0.5.0 \
  ls -la /keys

# Check SELinux labels
ls -Z ~/.config/offsec/api-keys
```

---

## API Key Checklist

Use this checklist when setting up a new workstation:

- [ ] Create `~/.config/offsec/api-keys/` directory
- [ ] Set permissions: `chmod 700`
- [ ] Create `.env` file with all keys
- [ ] Set permissions: `chmod 600 .env`
- [ ] Source in shell config (`~/.zshrc`)
- [ ] Test each tool (shodan, censys, etc.)
- [ ] Add `.env` to `.gitignore`
- [ ] Document key rotation date
- [ ] Configure container mounts
- [ ] Verify keys work in containers

---

## Free Tier Limits Summary

| Service | Free Queries | Rate Limit | Notes |
|---------|--------------|------------|-------|
| Shodan | 100/month | No strict limit | Limited result details |
| Censys | 250/month | 1.0 req/sec | Full data access |
| GreyNoise | Community | 50/day | Limited historical data |
| VirusTotal | 500/day | 4/min | Public API only |
| SecurityTrails | 50/month | No strict limit | Basic data |
| Hunter.io | 25/month | No strict limit | Email discovery |
| ProjectDiscovery | Limited scans | Varies | Cloud features |

---

## Related Documentation

- [OSINT Workflow](OSINT-WORKFLOW.md)
- [Recon Pipeline Usage](../scripts/recon/README.md)
- [Container Guide](CONTAINER.md)
- [Zellij Workflows](ZELLIJ-WORKFLOWS.md)
