# Multi-Machine Sync

This document explains how the setup is intended to stay usable across multiple laptops.

The goal is not to make every machine identical in every detail at every moment.
The goal is to keep the important layers aligned:

- NixOS config
- tracked systemd unit source
- tracked workspace snapshot
- live project repos
- secrets/trust material
- personal environment layers such as dotfiles

---

## Main layers involved

### 1. `~/nixos-config`
Tracked source of truth for:
- NixOS config
- scripts
- docs
- tracked user systemd units
- tracked workspace snapshot

This should be cloned and kept current on each machine.

### 2. `~/Repositories`
Live working tree for actual project repos.

This is reconstructed and maintained using:
- `bootstrap-workspace.sh`
- `sync-workspace-repos.sh`

### 3. `~/.config/ai`
Live AI runtime configuration.

This contains the reusable AI rules, templates, and skills.

### 4. Dotfiles repo
Personal environment configuration such as:
- Hyprland
- Quickshell
- shell/editor/UI config

This should be documented and maintained separately from the NixOS repo, but referenced from it.

---

## Scripts involved

### `export-workspace-state.sh`
Exports the current non-repo routing layer from `~/Repositories` into the tracked snapshot under:

- `~/nixos-config/tools/workspace/`

This is how workspace structure changes get reflected back into tracked config.

### `bootstrap-workspace.sh`
Uses the tracked snapshot to reconstruct the broad workspace structure on another machine.

### `sync-workspace-repos.sh`
Uses the root manifest to:
- clone missing repos
- fetch updates
- safely fast-forward pull when possible

This is the main day-to-day multi-machine repo sync helper.

### `install-user-systemd-units.sh`
Installs tracked user units into the active user systemd location.

### `rsync-git-server-mirror.sh`
Mirrors the homelab git server into the local git server.

This is part of the local git workflow and can help keep a machine aligned with the home server.

---

## Recommended multi-machine workflow

### On the machine where workspace structure changes
If you:
- add a new top-level workspace area
- rename an area
- change top-level or area-level routing files

then export the snapshot:

    ~/nixos-config/scripts/export-workspace-state.sh

This keeps the tracked workspace snapshot current.

### After updating `~/nixos-config`
Commit and push the changes as usual.

### On another machine
Pull the latest `nixos-config`, then run:

    ~/nixos-config/scripts/install-user-systemd-units.sh
    ~/nixos-config/scripts/bootstrap-workspace.sh
    ~/nixos-config/scripts/sync-workspace-repos.sh

This restores:
- routing skeleton
- repo placement
- repo contents

---

## What is and is not synced

### Synced/tracked here
- tracked workspace skeleton
- repo placement manifest
- tracked systemd unit source
- bootstrap and sync scripts
- documentation

### Not duplicated here
- repo-local project contents
- repo-local AI files inside git repos
- full dotfiles contents
- active runtime state in `~/.config/systemd/user/`

Those are handled by their own sources of truth.

---

## Dotfiles in multi-machine sync

Hyprland, Quickshell, and similar user-environment layers should be synced through the dotfiles repo, not through this repo.

This repo should reference them, not absorb them.

---

## Summary

Multi-machine consistency in this setup comes from combining:

- tracked Nix config
- tracked workspace snapshot
- repo sync scripts
- tracked user systemd unit source
- explicit secrets restoration
- a separate dotfiles layer

No single layer tries to do everything.
