# AJ's NixOS Configuration

> [!NOTE]
> This configuration is specific to my machines, workflows, and preferences.
> I recommend the repo be an inspiration, reference, or a source of ideas rather than something to copy directly without modification.

![](https://cloud.home/s/WjEspgBbQdWmpKi)

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
This includes locally pinned derivations such as `pi` and `openai-codex`, which are exposed through the overlay and then installed via modules or package lists.

### `scripts/`
Operational scripts used for:
- workspace export/bootstrap/sync
- user systemd unit installation
- secrets restoration
- new machine setup
- local git server setup
- distfiles sync
- pinned package update workflows (`pi`, `openai-codex`, and the combined orchestrator)

### `systemd/user/`
Tracked source of truth for user systemd units.

### `tools/workspace/`
Tracked skeletal snapshot of the live `~/Repositories` working tree.

### `docs/`
Human-readable documentation for installation, bootstrap, secrets, scripts, sync, and Kanata.

### `secrets/`
Encrypted SOPS inputs used by the Nix setup.
These are distinct from bootstrap trust material stored in `pass`.

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

### Important docs include:

#### Setup
- [docs/NIXOS-INSTALL.md](./docs/NIXOS-INSTALL.md)         — base OS installation (disk, LUKS, Btrfs, initial system setup)
- [docs/MANUAL-BOOTSTRAP.md](./docs/MANUAL-BOOTSTRAP.md)   — manual trust bootstrap (GPG, pass, SSH, age key)
- [docs/NEW-MACHINE-SETUP.md](./docs/NEW-MACHINE-SETUP.md) — high-level machine bring-up flow (install → bootstrap → rebuild → dotfiles)

#### System
- [docs/SECRETS.md](./docs/SECRETS.md)                     — how `pass`, SOPS, runtime secret files, and env exports fit together
- [docs/PACKAGES.md](./docs/PACKAGES.md)                   — how packages are sourced and installed (stable, unstable, local `pkgs/`, modules, system vs user)
- [docs/NIXOS-MAINTENANCE.md](./docs/NIXOS-MAINTENANCE.md) — quick reference for generations, garbage collection, and boot-entry cleanup
- [docs/ROADMAP.md](./docs/ROADMAP.md)                     — deferred issues, planned features, and other durable future work
- [docs/KANATA.md](./docs/KANATA.md)                       — detailed explanation of the Kanata keybinding system and layers

#### Operation
- [docs/SCRIPTS.md](./docs/SCRIPTS.md)                     — operational tooling and scripts (including workspace, bootstrap, and pinned package update workflows)
- [docs/MULTI-MACHINE-SYNC.md](./docs/MULTI-MACHINE-SYNC.md) — how the system stays consistent across multiple machines)
- [docs/AGENT-WORKFLOW.md](./docs/AGENT-WORKFLOW.md)       — how agents operate across the filesystem (routing, memory, execution model)

---

## AI-agent friendliness

This repo is intentionally documented and structured so that an AI agent can understand:

- what this repo is for
- what each script does
- where the source of truth lives
- how the machine bootstrap process works
- how this repo relates to the broader workspace and AI setup

See also:
- [CONTEXT.md](./CONTEXT.md)
- [docs/README.md](./docs/README.md)

---

## Summary

This repo is a personal but structured operating center for:
- NixOS configuration
- machine bootstrap
- multi-machine sync
- workspace reproducibility
- agent-aware documentation and maintenance
