# New Machine Setup

High-level guide for bringing up a new machine. Each phase points to a
detailed document.

---

## Overview

| Phase | What | Where |
|-------|------|--------|
| 1 | Base NixOS install | `NIXOS-INSTALL.md` |
| 2 | Root bootstrap (GPG, pass, age key, first rebuild) | `MANUAL-BOOTSTRAP.md` — Phase 1 |
| 3 | AJ setup (dotfiles, remotes, SSH key, Tailscale) | `MANUAL-BOOTSTRAP.md` — Phase 2 |

---

## Phase 1 — Base NixOS install

Follow `NIXOS-INSTALL.md`.

Covers: USB creation, disk wipe, LUKS, Btrfs subvolumes, `nixos-install`,
and committing the generated `hardware-configuration.nix` to this repo.

---

## Phase 2 — Root bootstrap

Follow `MANUAL-BOOTSTRAP.md` — Phase 1.

Two commands start it:

    nix-shell -p git --run \
      "git clone https://github.com/aaronjan98/nixos-config /root/nixos-config"
    nix-shell -p gnupg pass git netcat-gnu pinentry-curses age
    bash /root/nixos-config/scripts/bootstrap-root.sh <flake-hostname>

On ThinkPad when prompted:

    bash ~/nixos-config/scripts/send-secrets-to-new-machine.sh <new-machine-ip>

---

## Phase 3 — AJ setup

Follow `MANUAL-BOOTSTRAP.md` — Phase 2.

Two commands start it:

    git clone https://github.com/aaronjan98/nixos-config ~/nixos-config
    bash ~/nixos-config/scripts/post-rebuild-setup.sh

---

## After setup

- Run `nrs` to rebuild after any config change
- Run `g pushall` / `dot pushall` to sync both repos to all remotes
- See `MULTI-MACHINE-SYNC.md` for the ongoing multi-laptop sync workflow
