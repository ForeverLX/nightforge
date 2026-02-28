# Container & VM Network Security

## Network Isolation Strategy

### Container Network (Podman)
- **Subnet:** 10.88.0.0/16
- **Gateway:** 10.88.0.1
- **Purpose:** Isolated container networking

### VM Network (KVM/libvirt)
- **Subnet:** 192.168.122.0/24
- **Purpose:** Virtual machine networking

## Firewall Rules

### Container Rules
```bash
# Allow container outbound traffic
sudo ufw allow out from 10.88.0.0/16 comment 'Podman containers outbound'

# Allow container-to-container communication
sudo ufw allow from 10.88.0.0/16 to 10.88.0.0/16 comment 'Container inter-communication'
```

### VM Rules
```bash
# Allow KVM/libvirt network
sudo ufw allow from 192.168.122.0/24 comment 'KVM/libvirt network'
sudo ufw allow out from 192.168.122.0/24 comment 'KVM outbound'
```

## Security Principles
- ✅ Containers can reach internet (for updates/tools)
- ✅ Containers can communicate with each other
- ❌ External networks cannot initiate connections to containers
- ❌ Host is protected from container breakout

## DNS Configuration
Containers use public DNS servers for reliability:
- Primary: 1.1.1.1 (Cloudflare)
- Secondary: 8.8.8.8 (Google)

Configuration: `/etc/containers/containers.conf`
