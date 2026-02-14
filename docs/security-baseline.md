# Security Baseline — Host Firewall (iptables)

Last updated: 2026-02-12  
Profile intent: **local-first / OPSEC-by-default** host baseline for the offsec-workstation.

This baseline is designed for a Red Team workstation where:
- the host should not accept unsolicited inbound connections by default
- outbound is allowed (developer workstation reality)
- engagement services (e.g., reporting platforms, C2 frameworks) should run **per-engagement**, ideally inside the **container profile**, not on the host

---

## Goals

- Reduce passive exposure on untrusted networks (Wi-Fi, travel, coworking, etc.)
- Make inbound behavior deterministic (default deny)
- Keep networking functional (DNS, DHCP, IPv6 basics)
- Keep the rules simple enough to audit and reproduce

Non-goals:
- Full “deny all outbound” lockdown (too disruptive for a dev/offsec workstation baseline)
- nftables migration (deferred; kernel support must be verified first)

---

## Policy Model

### IPv4
- INPUT: **DROP**
- FORWARD: **DROP**
- OUTPUT: **ACCEPT**

### IPv6
- INPUT: **DROP**
- FORWARD: **DROP**
- OUTPUT: **ACCEPT**

This means:
- unsolicited inbound packets are dropped unless explicitly allowed
- outbound connections work normally
- replies to outbound traffic are allowed back in via `ESTABLISHED,RELATED`

---

## Allowed Inbound Traffic

### 1) Loopback
Required for local services and normal OS behavior.

- IPv4: `-i lo`
- IPv6: `-i lo`

### 2) Established / Related
Allows return traffic for outbound connections.

- `conntrack --ctstate ESTABLISHED,RELATED`

### 3) ICMP / ICMPv6
- IPv4 ICMP is allowed (ping, PMTU, diagnostics)
- IPv6 ICMP is allowed (required for healthy IPv6 behavior)

### 4) DHCP
Allows DHCP client traffic when using NetworkManager.

- IPv4: UDP ports 67–68
- IPv6: UDP port 546 (DHCPv6 client)

---

## Baseline Rule Application (One-Time)

The commands below apply the baseline rules immediately.

> Note: This is intentionally minimal. If you need inbound listeners for a lab, add them explicitly and document them per-engagement.

```bash
sudo iptables -F
sudo iptables -X
sudo ip6tables -F
sudo ip6tables -X

sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

sudo ip6tables -P INPUT DROP
sudo ip6tables -P FORWARD DROP
sudo ip6tables -P OUTPUT ACCEPT

sudo iptables -A INPUT -i lo -j ACCEPT
sudo ip6tables -A INPUT -i lo -j ACCEPT

sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

sudo iptables -A INPUT -p icmp -j ACCEPT
sudo ip6tables -A INPUT -p ipv6-icmp -j ACCEPT

sudo iptables -A INPUT -p udp --sport 67:68 --dport 67:68 -j ACCEPT
sudo ip6tables -A INPUT -p udp --sport 546 --dport 546 -j ACCEPT

