# Engagement Directory Management

Scripts for creating and managing penetration testing engagement directories.

## create-engagement.sh

Creates a properly structured engagement directory with correct permissions for container access.

### Usage

```bash
./scripts/engagement/create-engagement.sh <engagement-name>
```

### Example

```bash
./scripts/engagement/create-engagement.sh acme-corp-2026
```

### Directory Structure

```
~/engage/<engagement-name>/
├── recon/       # Reconnaissance output
├── exploit/     # Exploitation work
├── loot/        # Captured data
├── notes/       # Markdown notes (with template)
└── reports/     # Final reports
```

### Permissions

Directories are created with `755` (rwxr-xr-x) permissions to allow container access.

**Note**: If you encounter permission issues with containers, use `chmod 777` on the engagement directory:

```bash
chmod 777 ~/engage/acme-corp-2026
```

This is safe since engagement directories are in your home folder and only contain pentesting data.

## Workflow

```bash
# 1. Create engagement
./scripts/engagement/create-engagement.sh client-pentest

# 2. Navigate to directory
cd ~/engage/client-pentest

# 3. Launch container with recon layout
~/Github/offsec-workstation/scripts/zellij/zellij-launch.sh web recon

# 4. Run reconnaissance
recon-pipeline target.com

# 5. Review results
cat recon-*/REPORT.md
```

## Notes Template

Each engagement directory includes a `notes/README.md` template with:
- Objectives checklist
- Timeline table
- Findings sections (Critical/High/Medium/Low)
- Command log
- References

Edit this file as you work to maintain proper documentation.
