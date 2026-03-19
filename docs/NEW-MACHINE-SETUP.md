# New Machine Setup

This document is the high-level guide for bringing up a new machine.

It intentionally points to more detailed documents for each phase.

---

## Overview

The setup process is divided into three phases:

1. base NixOS installation
2. manual trust/bootstrap preparation
3. scripted machine bootstrap and final rebuild

---

## Phase 1 — Install base NixOS

Follow:

- `NIXOS-INSTALL.md`

This phase covers:
- installer USB creation
- disk wipe and partitioning
- LUKS setup
- Btrfs subvolumes
- `nixos-install`

---

## Phase 2 — Manual bootstrap

Follow:

- `MANUAL-BOOTSTRAP.md`

This phase covers:
- cloning `nixos-config`
- restoring GPG keys
- getting `pass` working
- restoring SSH files
- restoring the SOPS age key

This phase exists because a new machine does not initially have the trust material needed for full automation.

---

## Phase 3 — Scripted machine bootstrap

Once the manual prerequisites are complete, use the scripts in `~/nixos-config/scripts/`.

Main orchestrator:

- `~/nixos-config/scripts/bootstrap-new-machine.sh`

This should:
1. optionally run `restore-secrets.sh`
2. install tracked user systemd units
3. seed the local git server
4. sync distfiles
5. bootstrap workspace layout
6. sync workspace repos
7. print the final rebuild command

---

## Final rebuild

After bootstrap, run:

    sudo nixos-rebuild switch --flake ~/nixos-config#thinkpad-t14

Alias reminder:

    nrs

if your shell environment already defines it.

---

## Supporting docs

- `README.md`
- `MANUAL-BOOTSTRAP.md`
- `NIXOS-INSTALL.md`
- `SCRIPTS.md`
- `SECRETS.md`
