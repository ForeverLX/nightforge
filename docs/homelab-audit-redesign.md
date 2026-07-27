# Homelab Virtualized Infrastructure Audit & Redesign

**Date:** 2026-06-29  
**Operator:** CR1MS0N  
**Repo:** /home/ForeverLX/Github/nightforge  
**Host:** NightForge (Arch Linux, i3-10105F, 31GB RAM, RTX 3070)

---

## 1. Current-State Topology Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      INTERNET / CLOUD                           │
│  (Tailscale DERP relays, WireGuard peers, ngrok tunnels)        │
└──────────┬──────────────────────┬──────────────────────┬────────┘
           │                      │                      │
    ┌──────▼──────┐       ┌──────▼──────┐        ┌─────▼──────┐
    │   ROUTER    │       │  Tailscale  │        │  WireGuard  │
    │ 192.168.1.1 │       │   Overlay   │        │  10.0.0.0/24│
    │  (DHCP/DNS) │       │100.x.x.x/24 │        │  (mesh VPN) │
    └──────┬──────┘       └──────┬──────┘        └──────┬──────┘
           │                     │                      │
    ┌──────▼─────────────────────▼──────────────────────▼──────────┐
    │                     NIGHTFORGE                               │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │  LAN: 192.168.1.145/24                               │   │
    │  │  WG:  10.0.0.3/24                                    │   │
    │  │  TS:  100.100.242.70/32                              │   │
    │  │  CPU: i3-10105F (4C/8T, VT-x)                       │   │
    │  │  RAM: 31.2 GiB (4.7 used / 26 avail)                │   │
    │  │  GPU: RTX 3070                                       │   │
    │  │  Disk: 45GB root (74%) + 412GB home (65%, LUKS)     │   │
    │  │  Docker: v29.6.1, overlay2, Swarm: INACTIVE         │   │
    │  └──────────────────────────────────────────────────────┘   │
    │                                                              │
    │  ┌─── Docker: mythic_default (172.19.0.0/16) ──────────┐   │
    │  │  mythic_nginx:7443  (C2 frontend)                    │   │
    │  │  mythic_server:17000-17010                           │   │
    │  │  mythic_graphql:8080  mythic_react:4444              │   │
    │  │  mythic_postgres:5432  mythic_rabbitmq:5672          │   │
    │  │  mythic_jupyter:8890  mythic_documentation:8090      │   │
    │  └──────────────────────────────────────────────────────┘   │
    │                                                              │
    │  ┌─── Docker: ghostwriter_sys_default (172.18.0.0/16) ──┐   │
    │  │  ghostwriter_sys-nginx-1:80         [RESTARTING]     │   │
    │  │  ghostwriter_sys-django-1:8000      [UNHEALTHY]      │   │
    │  │  ghostwriter_sys-queue-1            [UNHEALTHY]      │   │
    │  │  ghostwriter_sys-graphql_engine-1                    │   │
    │  │  ghostwriter_sys-postgres-1  ghostwriter_sys-redis-1 │   │
    │  │  ghostwriter_sys-collab-server-1                     │   │
    │  └──────────────────────────────────────────────────────┘   │
    │                                                              │
    │  ┌─── Docker: freellmapi_default (172.21.0.0/16) ──────┐   │
    │  │  freellmapi:3111  (Free LLM API, healthy)            │   │
    │  └──────────────────────────────────────────────────────┘   │
    │                                                              │
    │  Services: sshd, fail2ban, tailscaled, beszel-agent, mpd    │
    └──────────────────────────────────────────────────────────────┘
           │                   │                    │
    ┌──────▼──────┐   ┌───────▼───────┐   ┌───────▼──────┐
    │  CERBERUS   │   │    TAIRN      │   │    HERMES    │
    │  (ARM CB)   │   │  (ARM CB)     │   │ (Alpine)     │
    │  10.0.0.1   │   │  10.0.0.4     │   │  10.0.0.5    │
    │  TS offline │   │  "always-on"  │   │ "redirector" │
    │  [OFFLINE]  │   │  (unknown)    │   │  (unknown)   │
    │  95 days    │   │               │   │              │
    └─────────────┘   └───────────────┘   └──────────────┘
                          │
                    ┌─────▼──────┐
                    │  UNKNOWN   │
                    │ 192.168.1. │
                    │   224      │
                    └────────────┘

   Tailscale nodes:
     NightForge (100.100.242.70)  ● active
     Cerberus   (100.86.163.55)   ○ offline 95d
     iPhone-SE  (---)             ○ offline 67d
     ng3fpg     (---)             ○ offline 11d

   WireGuard subnet: 10.0.0.0/24
     NightForge: 10.0.0.3  ● in use
     Cerberus:   10.0.0.1  ○ known via SSH config (may be stale)
     Tairn:      10.0.0.4  ○ known via memory only
     Hermes:     10.0.0.5  ○ Alpine redirector
     .2, .6-.254:          unaccounted
```

---

## 2. Identified Gaps & Inefficiencies

### CRITICAL

| #  | Issue | Impact | Severity |
|----|-------|--------|----------|
| G1 | **Single point of failure** — all 16 containers on NightForge only | Any crash/reboot = total service loss | CRITICAL |
| G2 | **Ghostwriter containers unhealthy** — nginx restarting, django+queue unhealthy | Reporting/ops tool broken or degraded | CRITICAL |
| G3 | **Cerberus offline 95 days** — ARM Chromebook underutilized | Hardware investment wasted; no HA node | CRITICAL |
| G4 | **No backup for critical C2 data** — Mythic Postgres, Ghostwriter Postgres | Data loss on disk failure | CRITICAL |
| G5 | **Root disk 74% full** (45GB root, 12GB free) | Risk of system lock-up, Docker operations constrained | CRITICAL |

### HIGH

| #  | Issue | Impact |
|----|-------|--------|
| G6 | **WireGuard config unmanaged** — wg0 active but no config files, wg tool missing | Fragile; cannot automate restoration |
| G7 | **No orchestration** — Docker Swarm inactive, no K8s, no Nomad | No multi-host scheduling, no rolling updates |
| G8 | **SSH config malformed** — duplicate/overlapping HostName directives | Cannot reliably SSH to remote nodes |
| G9 | **Tairn status unknown** — described as "always-on" but no verification | Asset ambiguity; redundant or missing |

### MEDIUM

| #  | Issue | Impact |
|----|-------|--------|
| G10 | **Hermes (Alpine) underutilized** — unknown role, only known as "redirector" | Proxy/reverse-proxy capacity sits idle |
| G11 | **No monitoring/alerting** — Beszel agent only (single-node) | No visibility into remote nodes or cloud |
| G12 | **Docker volumes local only** — all data on single NVMe | No data portability or live migration |
| G13 | **Fragmented networking** — 3 overlays (WG, TS, Docker) with no unification | Complexity escalates for multi-node orchestration |
| G14 | **No centralized logging** — Docker json-file driver on each container | Hard to debug Ghostwriter failures |
| G15 | **No CI/CD or GitOps** — configs manual, no deploy automation | Config drift risk |

### LOW

| #  | Issue | Impact |
|----|-------|--------|
| G16 | **ng3fpg Tailscale node offline 11d** — unknown device, possibly abandoned | Undocumented asset |
| G17 | **Unknown LAN host at 192.168.1.224** — not in any config | Undocumented asset |
| G18 | **No backup/restore drill** — no tested recovery procedure | Recovery time unbounded |

---

## 3. Redesigned Hybrid Homelab Architecture

### Design Principles

1. **Red-Team Infrastructure First** — C2 (Mythic), reporting (Ghostwriter), recon tools must be resilient
2. **ARM as First-Class Citizen** — Cerberus/Tairn ARM nodes for stateless and worker roles
3. **$25/mo Total Budget** — Free tier + cheap VPS strategically
4. **Lightweight Orchestration** — K3s recommended (not full K8s overkill)
5. **Hybrid (Local + Cloud)** — Keep sensitive data local, burst to cloud for compute/redundancy

### Orchestration Decision Matrix

| Platform | Complexity | RAM Overhead | ARM64 | Learning Curve | Best For |
|----------|-----------|-------------|-------|---------------|----------|
| **Docker Swarm** | Low | ~100MB | Native | Low | Quick multi-host Docker — dead-end skillset |
| **K3s** | Medium | ~500MB | Native | Medium-High | Full K8s API, GitOps, CRDs — transferable skills |
| **Nomad** | Medium | ~200MB | Requires agent | Medium | Mixed workloads (binaries + containers) |
| **Docker Compose** | Low | 0 | Native | Low | Single-node only — NOT suitable beyond one host |

### Recommendation: K3s

**Why K3s over alternatives:**

| Factor | K3s | Docker Swarm | Nomad |
|--------|-----|-------------|-------|
| ARM64 native | ✅ Built-in | ✅ | ⚠️ Agent build required |
| K8s API compatible | ✅ Full | ❌ | ❌ |
| GitOps (ArgoCD/Flux) | ✅ Native | ❌ | ✅ Consul required |
| Community & jobs | ✅ Largest | Shrinking | Niche |
| Built-in ingress | ✅ Traefik | ❌ Manual | ❌ Manual |
| Cert-manager | ✅ | ❌ | ❌ |
| Learning transfer | ✅ Cloud jobs | ❌ Dead end | ⚠️ Niche |
| Multi-cloud | ✅ CNI plugins | ❌ | ⚠️ Consul required |

K3s is the clear winner for a security operator wanting to "practice deploying homelab in the cloud" — the skills transfer directly to production Kubernetes environments.

### Target Architecture

```
                              ┌─────────────────────────────────────┐
                              │        CLOUD TIER ($0-6/mo)         │
                              │  ┌─────────────────────────────┐   │
                              │  │  Oracle Cloud (Always Free)  │   │
                              │  │  4 ARM OCPU, 24GB RAM       │   │
                              │  │  200GB block, 10TB egress   │   │
                              │  │  $0/mo                      │   │
                              │  │  K3s agent                  │   │
                              │  │  Ghostwriter standby replica │   │
                              │  │  DB backup destination       │   │
                              │  └─────────────────────────────┘   │
                              │  ┌─────────────────────────────┐   │
                              │  │  Hetzner CX23 (~$4/mo)      │   │
                              │  │  2 vCPU, 4GB, 40GB NVMe     │   │
                              │  │  Public reverse proxy        │   │
                              │  │  Tailscale funnel            │   │
                              │  │  WireGuard hub               │   │
                              │  └─────────────────────────────┘   │
                              └──────────┬──────────────────────────┘
                                         │
                      WireGuard (10.0.0.0/24) + Tailscale overlay
                                         │
    ┌────────────────────────────────────┼────────────────────────────┐
    │                   LOCAL TIER       │                            │
    │                                    │                            │
    │  ┌────── NIGHTFORGE (x86_64) ────────────────┐                 │
    │  │  ROLE: Management + GPU Workload + C2     │                 │
    │  │  Mythic C2 (payload generation)           │                 │
    │  │  FreeLLM API (GPU — RTX 3070)             │                 │
    │  │  Hermes Agent orchestrator                │                 │
    │  │  K3s agent (compute node)                 │                 │
    │  │  Local Docker for GPU-bound containers    │                 │
    │  └────────────────────────────────────────────┘                 │
    │                                    │                            │
    │  ┌────── CERBERUS (ARM64) ───────────────────┐                 │
    │  │  ROLE: K3s Control Plane + Worker         │                 │
    │  │  Ghostwriter (web + django)               │ ← MIGRATE HERE  │
    │  │  Prometheus + Grafana                     │                 │
    │  │  Pi-hole secondary DNS                    │                 │
    │  │  Uptime Kuma / healthchecks               │                 │
    │  │  Container registry cache                 │                 │
    │  └────────────────────────────────────────────┘                 │
    │                                    │                            │
    │  ┌────── TAIRN (ARM64) ──────────────────────┐                 │
    │  │  ROLE: Worker Node + Infrastructure       │                 │
    │  │  K3s agent (compute node)                  │                 │
    │  │  Grafana Loki / log aggregation            │                 │
    │  │  Redis / cache cluster                     │                 │
    │  │  GitOps runner (ArgoCD)                    │                 │
    │  └────────────────────────────────────────────┘                 │
    │                                    │                            │
    │  ┌────── HERMES (Alpine) ────────────────────┐                 │
    │  │  ROLE: Edge Router + Reverse Proxy        │                 │
    │  │  Caddy/Nginx reverse proxy                │                 │
    │  │  Tailscale funnel / serve                 │                 │
    │  │  WireGuard concentrator                   │                 │
    │  │  Fail2ban + CrowdSec                      │                 │
    │  │  Let's Encrypt auto-TLS                   │                 │
    │  └────────────────────────────────────────────┘                 │
    └─────────────────────────────────────────────────────────────────┘
```

### Cloud Options Within $25/mo Budget

| Provider | Specs | Cost | Best For |
|----------|-------|------|----------|
| Oracle Cloud (Always Free) | 4 ARM OCPU, 24GB RAM, 200GB, 10TB egress | **$0/mo** | Primary cloud node; K3s agent + Ghostwriter standby |
| Hetzner CX23 | 2 vCPU (x86), 4GB RAM, 40GB NVMe, 20TB | **~$4/mo** | Public proxy, WireGuard hub, Tailscale exit |
| Hetzner CAX11 | 2 vCPU (ARM), 4GB RAM, 40GB NVMe, 20TB | **~$6/mo** | ARM-native cloud node matching Cerberus arch |
| OVH VPS-1 | 1 vCPU, 2GB RAM, 20GB, unmetered | **~$4.50/mo** | Jumphox or monitoring |
| AWS Free Tier (t2.micro) | 1 vCPU (burstable), 1GB RAM, 30GB EBS | **$0/mo (12mo)** | Learning AWS specifically |

**Recommended allocation:** Oracle Cloud ($0) + Hetzner CX23 ($4/mo) = **$4/mo total**. Leaves $21 for testing/gaming/upgrades.

---

## 4. Cerberus (ARM Chromebook) — Specific Recommendations

### Current State

- Arch Linux ARM
- SSH address: 10.0.0.1 (WireGuard) — may be stale
- Tailscale: 100.86.163.55, offline **95 days** (last seen ~Mar 25, 2026)
- Role: unknown/unused

### Why It's Been Offline (Diagnosis)

1. Tailscale daemon may have been removed or config lost during rolling updates
2. WireGuard config on Cerberus may have changed or WG IP reassigned
3. Device may have been physically powered off or on battery save
4. Arch Linux ARM rolling updates could have broken systemd services
5. The SSH config entry (10.0.0.1) may reference an old IP that no longer matches

### Recovery Checklist

```bash
# 1. Basic connectivity test
ping -c 3 10.0.0.1
# If that fails, scan LAN:
nmap -sn 192.168.1.0/24 | grep -B2 "Chromebook\|ARM\|22/tcp"

# 2. SSH via WireGuard (if ping succeeds)
ssh 10.0.0.1

# 3. Once connected, restore Tailscale
sudo pacman -S tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up --ssh

# 4. Install K3s
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
```

### Roles Cerberus Can Serve

| Priority | Role | Rationale | Resources Needed |
|----------|------|-----------|-----------------|
| **P1** | **K3s Control Plane** | ARM64 native, lightweight K8s server | 1GB RAM, 10GB disk |
| **P1** | **Ghostwriter Host** | Move reporting/ops off NightForge | 1.5GB RAM |
| **P2** | **Pi-hole Secondary DNS** | LAN DNS redundancy | 256MB RAM |
| **P2** | **Prometheus + Grafana** | Full monitoring stack for homelab | 1GB RAM |
| **P2** | **Container Registry Mirror** | Cache Docker Hub pulls locally | 10GB+ disk |
| **P3** | **Uptime Kuma** | External service monitoring | 128MB RAM |
| **P3** | **MinIO / S3 storage** | Object store for backups | 5GB+ disk |
| **P3** | **Syncthing / file sync** | Off-site backup sync target | 256MB RAM |

### What to Migrate TO Cerberus (from NightForge)

| Service | Current | Target | Benefit |
|---------|---------|--------|---------|
| Ghostwriter (7 containers) | NightForge Docker | Cerberus (K3s) | Frees 1.2GB RAM on NightForge |
| Prometheus + Grafana | None (Beszel only) | Cerberus (K3s) | Full visibility for all nodes |
| Pi-hole DNS (secondary) | Possibly separate box | Cerberus (Docker/K3s) | DNS redundancy |
| DB backups (Mythic + Ghostwriter) | None | Cerberus (cron + rsync) | Off-host backup |
| Container registry mirror | None | Cerberus | Faster Docker pulls, bandwidth savings |

### What to KEEP on NightForge

| Service | Reason |
|---------|--------|
| Mythic C2 | Payload generation needs x86_64; GPU/CPU-specific toolchains |
| FreeLLM API | RTX 3070 GPU inference — no ARM equivalent |
| Hermes Agent | Active session orchestrator |
| Local dev/build containers | Build/test before cluster deployment |
| CUDA/GPU workloads | NVIDIA GPU exclusive |

---

## 5. Migration Roadmap

### Phase 0: Assessment & Stabilization (Week 1) — $0

**Goal:** Recover Cerberus, stabilize Ghostwriter, document baseline

```
Task list:
[ ] 1. Recover Cerberus connectivity (SSH via WG or LAN nmap)
[ ] 2. Fix Ghostwriter — diagnose nginx restarting + django unhealthy
     - docker logs ghostwriter_sys-nginx-1
     - docker logs ghostwriter_sys-django-1
     - docker logs ghostwriter_sys-queue-1
[ ] 3. Install wireguard-tools on NightForge
[ ] 4. Extract WireGuard config: wg showconf wg0 > wg0.conf
[ ] 5. Fix SSH config malformed directives
[ ] 6. Audit 192.168.1.224 + ng3fpg devices
[ ] 7. Configure DB backup: pg_dump mythic + ghostwriter DBs
[ ] 8. Schedule cron: daily DB dump + rsync to /home/Backups/
[ ] 9. Clean up root disk (pacman cache, old containers, journalctl)
```

**Verification:** Cerberus online in Tailscale. Ghostwriter containers healthy. Cron for DB backups exists. Root disk >20% free.

### Phase 1: Foundation (Week 2-3) — $4/mo (Hetzner CX23)

**Goal:** Deploy orchestration layer, establish cloud presence

```
[ ] 1. Create Oracle Cloud Free Tier account
     - Provision 4 OCPU ARM instance (Ubuntu 24.04 ARM)
     - Setup WireGuard tunnel back to homelab
     - Configure security lists for ingress
[ ] 2. Install K3s on Cerberus (control plane)
     curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
[ ] 3. Join NightForge as K3s agent
     curl -sfL https://get.k3s.io | K3S_URL=https://10.0.0.1:6443 K3S_TOKEN=<token> sh -
[ ] 4. Join Oracle Cloud node as K3s agent
[ ] 5. Install Helm + deploy cert-manager
[ ] 6. Configure Traefik ingress (built into K3s)
[ ] 7. Deploy Hetzner CX23 as public ingress + Tailscale exit node
[ ] 8. Install kubectl aliases + k9s for management
```

**Verification:** `kubectl get nodes` shows 3+ nodes ready.

### Phase 2: Service Migration (Week 3-4) — $4/mo

**Goal:** Move Ghostwriter to cluster, deploy monitoring

```
[ ] 1. Install Kompose on dev machine
[ ] 2. Export Ghostwriter docker-compose -> K8s manifests
     cd ~/Tools/ghostwriter && kompose convert -o ~/k8s/ghostwriter/
[ ] 3. Deploy Ghostwriter to K3s on Cerberus
     kubectl apply -f ~/k8s/ghostwriter/
[ ] 4. Deploy PostgreSQL operator (CloudNativePG) for HA DB
[ ] 5. Deploy cert-manager + Let's Encrypt issuer
[ ] 6. Deploy Prometheus + Grafana via kube-prometheus-stack
[ ] 7. Deploy Uptime Kuma for external status checks
[ ] 8. Deploy Grafana Loki for Docker log aggregation
[ ] 9. Configure Ghostwriter with replicated Postgres (Cerberus + Oracle)
```

**Verification:** Ghostwriter accessible via domain. Prometheus scraping all K3s nodes. Grafana dashboards visible.

### Phase 3: Hardening (Week 4-6) — $4-6/mo

**Goal:** HA, backup, GitOps, security

```
[ ] 1. Deploy ArgoCD (GitOps) pointing to nightforge repo
[ ] 2. Move all manifests to nightforge/k8s/ directory
[ ] 3. Configure ArgoCD auto-sync from git
[ ] 4. Set up Velero for K8s backup (to Oracle object store or S3)
[ ] 5. Deploy Ghostwriter with 2 replicas (Cerberus + Oracle)
[ ] 6. Configure HA Postgres primary on Cerberus, replica on Oracle
[ ] 7. Deploy external-dns with automatic DNS updates
[ ] 8. Deploy Falco for runtime security on K3s
[ ] 9. Set up alertmanager rules (disk, pod restarts, cert expiry)
[ ] 10. Restore from backups at least once to validate
```

**Verification:** ArgoCD shows healthy apps. Ghostwriter survives a node failure. Backup restore tested.

### Phase 4: Advanced (Week 6-8) — Optional

```
[ ] 1. Deploy Mythic agent database on K3s Postgres (remove local)
[ ] 2. Set up HashiCorp Vault for secrets
[ ] 3. Deploy Argo Rollouts for canary deployments
[ ] 4. Use Tailscale Funnel for public services (no open firewall ports)
[ ] 5. Deploy Open WebUI + Ollama on Oracle ARM (24GB RAM for LLM)
[ ] 6. Deploy Keda for event-driven auto-scaling on cloud node
[ ] 7. Deploy code-server / VS Code Web on Cerberus
[ ] 8. Evaluate Hermes as Caddy + CrowdSec edge router
[ ] 9. Migrate Hermes to K3s agent (lightweight)
```

---

## Cost Summary

| Item | Monthly | Setup |
|------|---------|-------|
| NightForge (existing) | $0 | Sunk |
| Cerberus ARM CB (existing) | $0 | Sunk |
| Tairn ARM CB (existing) | $0 | Sunk |
| Hermes Alpine (existing) | $0 | Sunk |
| Oracle Cloud Free ARM | **$0** | $0 |
| Hetzner CX23 | **~$4** | $0 |
| **Total added cost** | **$4/mo** | $0 |

> **$21 remaining** of $25 budget for game servers, testing SPs, or upgrading to Hetzner CAX31 (8 vCPU, 16GB at ~$21/mo).

---

## Quick-Start Command Reference

```bash
# === Phase 0: Recovery ===
ssh 10.0.0.1  # Cerberus via WireGuard
sudo pacman -Syu wireguard-tools tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up --ssh

# === Phase 1: K3s on Cerberus ===
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
sudo kubectl get nodes

# Get join token:
sudo cat /var/lib/rancher/k3s/server/token

# Join NightForge as agent:
curl -sfL https://get.k3s.io | K3S_URL=https://10.0.0.1:6443 K3S_TOKEN=<token> sh -

# === Convert docker-compose to K8s ===
pip install kompose  # or download binary
cd ~/Tools/c2/ghostwriter
kompose convert -o ~/k8s/ghostwriter/
kubectl apply -f ~/k8s/ghostwriter/

# === GitOps Bootstrap ===
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
argocd admin initial-password -n argocd

# === Monitoring ===
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# === Oracle Cloud Free Tier ===
# Provision via OCI console:
#   Image: Canonical Ubuntu 24.04 ARM64
#   Shape: VM.Standard.A1.Flex (4 OCPU, 24GB RAM)
#   Storage: 200GB boot volume
#   Network: Assign public IP, open WireGuard port 51820/UDP
# Then install K3s agent + WireGuard back to homelab
```

---

## Final Recommendations (TL;DR)

1. **Recover Cerberus first** — it's your free HA node, sitting idle for 95 days
2. **Fix Ghostwriter** — unhealthy containers indicate config drift or resource contention
3. **K3s on ARM** — Cerberus as control plane, NightForge + Oracle as agents
4. **Oracle Cloud Free Tier** — 4 ARM cores + 24GB RAM for $0 is unmatched value
5. **Hetzner CX23** — $4/mo for public-facing proxy + redundancy
6. **Migrate Ghostwriter** from NightForge Docker -> K3s on Cerberus (frees resources)
7. **Keep Mythic + FreeLLM on NightForge** — they need x86_64 + GPU
8. **GitOps with ArgoCD** — manifests in nightforge repo, auto-sync
9. **$4 of your $25 budget** gets you a production-grade hybrid homelab
10. **Practice C2-style deployment discipline** — same operational rigor as red-team infra, applied to your own network
