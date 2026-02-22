# OSINT & Reconnaissance Workflow

**Version**: v0.5.0  
**Date**: February 2026

## Philosophy

**CLI-first for repeatability and scriptability.** Use web UIs only for:
- Initial exploration of a new data source
- Visual correlation (graphs, maps, timelines)
- Tools without good CLI alternatives

---

## Quick Start

### Automated Recon Pipeline

```bash
# Launch web container with recon layout
./scripts/zellij/zellij-launch.sh web recon

# Inside container, run automated recon
cd /work
recon-pipeline example.com
```

This runs the full OSINT pipeline in 7 stages with markdown report generation.

---

## Related Documentation

- [API Setup Guide](API-SETUP.md) - Configure Shodan, Censys, VirusTotal, etc.
- [Recon Pipeline Script](../scripts/recon/README.md) - Detailed usage guide
- [Container Guide](CONTAINER.md) - Container workflows
- [Zellij Workflows](ZELLIJ-WORKFLOWS.md) - Terminal multiplexer layouts
