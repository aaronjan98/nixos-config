# CONTEXT.md

## Project
nixos-config

## Purpose
This repository defines AJ's NixOS system configuration and the supporting operational tooling used to reproduce and maintain the machine.

It includes:
- host and module definitions for NixOS
- operational scripts for setup and maintenance
- tracked user systemd unit files
- the tracked workspace snapshot for `~/Repositories`
- documentation for machine bootstrap, secrets, scripts, sync, and Kanata

This repository should be treated as an operational control center for the machine.

## What good looks like
- configuration changes are understandable and reproducible
- machine setup is documented and scriptable
- tracked scripts have clear responsibilities
- user systemd units are managed from tracked source files
- workspace routing and repo placement remain reproducible across machines
- documentation is useful to both humans and AI agents

## What to avoid
- making broad changes without understanding the module or script boundary
- mixing workspace snapshot concerns with live AI runtime config
- duplicating responsibilities across scripts
- storing secrets directly in the repo outside the intended secret management flow
- editing tracked runtime-generated files when the source-of-truth file is elsewhere
- folding dotfiles-managed personal environment concerns into this repo unnecessarily

## Important directories

### `hosts/`
Machine-specific host configuration.

### `modules/`
Reusable NixOS modules.

### `pkgs/`
Custom package definitions and related package sources.

### `scripts/`
Operational scripts for:
- workspace export/bootstrap/sync
- user systemd unit installation
- local git server setup
- distfiles sync
- machine bootstrap
- secrets restoration
- other utility workflows

### `systemd/user/`
Tracked source of truth for user systemd unit files.

### `tools/workspace/`
Tracked workspace snapshot for the live `~/Repositories` tree.
This stores:
- top-level `ROUTER.md`
- area-level `CONTEXT.md`
- `repos.tsv`

### `docs/`
Human-readable setup and maintenance documentation.

### `secrets/`
Secret-related configuration inputs used by the Nix setup.

## Related external locations

### `~/.config/ai/`
Live AI runtime configuration:
- shared rules
- templates
- skills
- agent runtime directories

This is separate from the workspace snapshot and separate from this repo itself.

### `~/Repositories/`
Live working tree for actual project repositories and agent-facing workspaces.

### `~/.config/systemd/user/`
Active installed user systemd units.
Tracked canonical copies live in `systemd/user/` inside this repo.

### Dotfiles repo
Personal environment configuration such as:
- Hyprland
- Quickshell
- shell/editor/UI config

should live in the separate dotfiles repository and be documented there, while this repo should reference that layer where needed.

Known references:
- `https://github.com/aaronjan98/dotfiles`
- `https://github.com/aaronjan98/dotfiles/tree/main/.config/quickshell`

## Key files to read first
- `README.md`
- `docs/README.md`

## Key scripts

### `scripts/export-workspace-state.sh`
Scans the live `~/Repositories` tree and updates the tracked workspace snapshot.

### `scripts/bootstrap-workspace.sh`
Recreates the broad workspace layout and clones missing repos from the tracked manifest.

### `scripts/sync-workspace-repos.sh`
Keeps repos aligned with the tracked workspace manifest across machines.

### `scripts/install-user-systemd-units.sh`
Installs tracked user systemd units from `systemd/user/` into `~/.config/systemd/user/`.

### `scripts/restore-secrets.sh`
Restores SSH material and the SOPS age key from `pass`.

### `scripts/bootstrap-new-machine.sh`
Guided orchestrator for new machine setup.

## How to work in this repo
- Start with the smallest relevant file or directory for the task.
- Prefer understanding before editing.
- Treat scripts as composable units with distinct responsibilities.
- When changing bootstrap behavior, update the documentation as well.
- When changing systemd units, edit the tracked copies in `systemd/user/`, not only the active runtime copies.
- When changing workspace structure assumptions, update both the tracked workspace snapshot and the scripts that depend on it.
- When documenting user environment layers that live elsewhere, reference the external source of truth rather than duplicating it here unless a summary is useful.

## Routing guidance
- If the task is about NixOS system configuration, inspect `hosts/` and `modules/`.
- If the task is about machine setup automation, inspect `scripts/` and `docs/`.
- If the task is about user services, inspect `systemd/user/`.
- If the task is about workspace reproducibility, inspect `tools/workspace/`.
- If the task is about AI runtime behavior, inspect `~/.config/ai/` separately from this repo.
- If the task is about Hyprland, Quickshell, or other personal environment layers, inspect the dotfiles repo separately.

## Notes
This repo is both a system configuration repo and an operational tooling repo.
An agent working here should preserve clarity, reproducibility, and separation of responsibilities.
