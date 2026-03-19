# AJ's NixOS Configuration

> This configuration is specific to AJ's machines, workflows, and preferences.
> It is best used as inspiration, reference, or a source of ideas rather than something to copy directly without modification.

This repository is both:

- a NixOS system configuration repo
- an operational tooling repo for reproducible machine setup, workspace reconstruction, and ongoing maintenance

It is designed to be understandable by both:

- humans
- AI agents working within the repo

That means the repo includes not only Nix files, but also:

- setup and maintenance scripts
- tracked user systemd units
- workspace snapshot tooling
- documentation for machine setup, secrets, and sync workflows

---

## Goals

This repo is designed to support:

- reproducible NixOS system configuration
- machine bring-up with explicit trust/bootstrap phases
- synchronization across multiple laptops
- an agent-aware filesystem and documentation structure
- separation between:
  - live AI runtime config
  - live working tree
  - tracked workspace snapshot
  - tracked systemd unit source

---

## Important directories

### `hosts/`
Machine-specific host definitions.

### `modules/`
Reusable NixOS modules.

### `pkgs/`
Custom packages and package-related sources.

### `scripts/`
Operational scripts used for:
- workspace export/bootstrap/sync
- user systemd unit installation
- secrets restoration
- new machine setup
- local git server setup
- distfiles sync

### `systemd/user/`
Tracked source of truth for user systemd units.

### `tools/workspace/`
Tracked skeletal snapshot of the live `~/Repositories` working tree.

### `docs/`
Human-readable documentation for installation, bootstrap, secrets, scripts, sync, and Kanata.

### `secrets/`
Secrets-related configuration inputs used by the Nix setup.

---

## Related external layers

### Live AI runtime config
Path:

- `~/.config/ai/`

This contains:
- shared AI rules
- templates
- skills
- agent runtime directories

### Live working tree
Path:

- `~/Repositories/`

This contains:
- actual project repos
- top-level and area-level routing surfaces
- project-local agent files inside repos

### Active user systemd runtime
Path:

- `~/.config/systemd/user/`

Tracked source copies live in:
- `systemd/user/`

### Dotfiles and personal environment config
This repo does not try to contain every personal environment file.

For UI/shell/workflow layers such as:
- Hyprland
- Quickshell
- other dotfiles-managed personal setup

refer to the separate dotfiles repository and its documentation.

Known reference:
- `https://github.com/aaronjan98/dotfiles`
- Quickshell path reference:
  - `https://github.com/aaronjan98/dotfiles/tree/main/.config/quickshell`

---

## Documentation

Start with:

- `docs/README.md`

Important docs include:
- `docs/NIXOS-INSTALL.md`
- `docs/MANUAL-BOOTSTRAP.md`
- `docs/NEW-MACHINE-SETUP.md`
- `docs/SECRETS.md`
- `docs/SCRIPTS.md`
- `docs/MULTI-MACHINE-SYNC.md`
- `docs/KANATA.md`
- `docs/PACKAGES.md`

---

## AI-agent friendliness

This repo is intentionally documented and structured so that an AI agent can understand:

- what this repo is for
- what each script does
- where the source of truth lives
- how the machine bootstrap process works
- how this repo relates to the broader workspace and AI setup

See also:
- `CONTEXT.md`
- `docs/README.md`

---

## Summary

This repo is a personal but structured operating center for:
- NixOS configuration
- machine bootstrap
- multi-machine sync
- workspace reproducibility
- agent-aware documentation and maintenance
