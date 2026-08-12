# Performance & Network Optimization

This document captures safe, incremental tuning steps for NightForge. Each change is optional and should be applied only after testing.

## Baseline (2026-02-10)
- Boot time: 21.331s total (firmware 9.967s, loader 2.061s, kernel 5.704s, userspace 3.598s)
- Top boot contributors:
  - man-db.service (6.942s)
  - systemd-cryptsetup@home.service (2.245s)
  - fstrim.service (2.144s)
  - plocate-updatedb.service (1.285s)

## Safe Optimization Targets

### 1) Move heavy jobs to timers
These are safe to run on timers instead of blocking boot.

```bash
# Check current state
systemctl status man-db.service fstrim.service plocate-updatedb.service

# Enable timers (preferred)
systemctl enable --now man-db.timer
systemctl enable --now fstrim.timer
systemctl enable --now plocate-updatedb.timer
```

### 2) Reduce DNS variability
Pin DNS servers to reduce resolver drift and improve stability.

```bash
# Example (NetworkManager connection)
# Replace <CONN> with your active connection name
nmcli connection modify <CONN> ipv4.ignore-auto-dns yes
nmcli connection modify <CONN> ipv4.dns "9.9.9.9 1.1.1.1"

# Apply
nmcli connection down <CONN>
nmcli connection up <CONN>
```

### 3) Wi-Fi stability (if used)
If you use Wi-Fi, ensure `iw` is installed and set power save to off.

```bash
sudo pacman -S iw

# Disable Wi-Fi power save on the connection
nmcli connection modify <WIFI_CONN> 802-11-wireless.powersave 2
```

### 4) Verify boot performance

```bash
systemd-analyze
systemd-analyze blame | head -n 50
```

## Notes
- Firmware/bootloader time is the dominant factor; keep BIOS updated.
- For encryption-related delays, check `systemd-cryptsetup@home` and disk health.

