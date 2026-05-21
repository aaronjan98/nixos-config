# Multi-Machine Sync

This document explains how the setup stays usable across multiple laptops.

The goal is not to make every machine identical at every moment — it is to keep the important layers aligned:

- NixOS config
- dotfiles
- secrets/trust material
- Documents and Pictures (via NAS)
- live project repos

---

## Day-to-day workflow

### Sitting down at a machine

    sync-arrive

This runs `scripts/sync-machine.sh --arrive`, which:
1. Pulls `nixos-config` (fast-forward only)
2. Pulls dotfiles bare repo
3. Pulls `pass` (password store)
4. Pulls `zettelkasten`
5. Pulls Documents from NAS (no `--delete` — preserves local-only files)
6. Pulls Pictures from NAS
7. Runs `sync-workspace-repos.sh` to update project repos

If `nixos-config` changed, run `nrs` to rebuild.
If aliases changed, run `source ~/.bashrc`.

### Leaving a machine

    sync-leave

This runs `scripts/sync-machine.sh --leave`, which:
1. Checks nixos-config, pass, and zettelkasten for uncommitted changes (warns but does not block)
2. Pushes Documents to NAS (with `--delete` — NAS mirrors current state)
3. Pushes Pictures to NAS

After leaving, push git repos:

    g pushall
    dot pushall

---

## Background sync (hourly, automatic)

Two systemd user timers push to the NAS on a schedule:

- `sync-documents.timer` — pushes `~/Documents` to NAS hourly
- `sync-pictures.timer` — pushes `~/Pictures` to NAS hourly

To trigger them manually without waiting for the timer:

    sync-documents
    sync-pictures

These aliases start the existing service unit (`systemctl --user start sync-documents.service`).

---

## Main sync layers

### `~/nixos-config`
Source of truth for NixOS config, scripts, docs, workspace snapshot, and tracked systemd units.

Cloned on each machine. Kept current with `sync-arrive`.

### Dotfiles (`~/.dotfiles` bare repo)
Personal environment: Hyprland, Quickshell, shell/editor config.

Kept current with `sync-arrive` (via `dotfiles_pull`).

### `~/Repositories`
Live working tree for project repos.

Reconstructed on new machines with `bootstrap-workspace.sh`. Kept current with `sync-workspace-repos.sh` (called by `sync-arrive`).

### Documents / Pictures
Personal files synced to/from NAS via rsync over SSH (Tailscale).

NAS host: `aj@qwerty.home` (override with `$NAS_HOST`).

### `pass` (`~/.password-store`)
GPG-encrypted secrets. Pulled with `sync-arrive`.

### Zettelkasten (`~/Repositories/self-hosted/zettelkasten`)
Notes repo. Pulled with `sync-arrive`.

---

## Environment variables for sync-machine.sh

| Variable | Default |
|---|---|
| `NAS_HOST` | `aj@qwerty.home` |
| `NAS_DOCS_REMOTE` | `/mnt/storage/desktop-sync/Documents` |
| `NAS_PICS_REMOTE` | `/mnt/storage/desktop-sync/Pictures` |
| `LOCAL_DOCS` | `~/Documents` |
| `LOCAL_PICS` | `~/Pictures` |
| `ZETTELKASTEN` | `~/Repositories/self-hosted/zettelkasten` |

---

## Workspace structure sync

### After adding/renaming workspace areas

Export the snapshot so other machines can reconstruct the structure:

    ~/nixos-config/scripts/export-workspace-state.sh

Commit and push `nixos-config`. Other machines pick it up on next `sync-arrive`.

### Reconstructing workspace on a new machine

    ~/nixos-config/scripts/bootstrap-workspace.sh
    ~/nixos-config/scripts/sync-workspace-repos.sh

---

## What is and is not synced

### Synced
- tracked workspace skeleton and repo manifest
- NixOS config
- dotfiles
- Documents/Pictures (via NAS)
- secrets (via pass)
- project repos (via workspace sync)

### Not synced here
- repo-local project contents beyond what git tracks
- active runtime state in `~/.config/systemd/user/`
- build artifacts, caches

---

## NAS reachability

The NAS is on the home LAN. If you are off-network, run:

    tailscale up

before attempting any NAS sync. The rsync helpers warn if the NAS is unreachable rather than failing hard.
