# NixOS Configuration Documentation

This directory contains the human-readable documentation for AJ's NixOS configuration and machine setup workflow.

The docs are organized so that both humans and AI agents can understand:

- how a new machine is installed
- how trust material is restored
- how setup automation takes over
- what the major scripts do
- how this repo relates to the larger agentic workspace system
- how multi-machine sync is intended to work
- where input/custom environment layers fit

---

## Recommended reading order

### 1. `NIXOS-INSTALL.md`
Read this first when installing a completely new laptop.

This document covers:
- creating installer media
- wiping and partitioning disks
- setting up LUKS
- setting up Btrfs subvolumes
- generating initial config
- running `nixos-install`

Use this when the machine does not yet have a working installed NixOS system.

### 2. `MANUAL-BOOTSTRAP.md`
Read this after the base OS is installed and you can log into the new machine.

This document covers the intentionally manual trust/bootstrap steps:
- cloning `nixos-config`
- restoring GPG keys
- getting `pass` working
- restoring SSH files
- restoring the SOPS age key
- handing off to the scripted bootstrap

Use this when the machine is installed but not yet trusted/configured.

### 3. `NEW-MACHINE-SETUP.md`
Read this as the high-level overview.

This document explains the full bring-up flow in phases:
1. base install
2. manual bootstrap
3. scripted bootstrap
4. final rebuild
5. dotfiles/environment follow-up

Use this when you want the big picture.

### 4. `SECRETS.md`
Read this whenever you need to understand trust material and secret restoration.

This document covers:
- GPG keys
- `pass`
- SSH material
- the SOPS age key
- manual trust bootstrap expectations

Use this when secret-related setup is failing or needs to be reviewed.

### 5. `SCRIPTS.md`
Read this when you need to understand the operational tooling.

This document explains the purpose of each script in:

- `~/nixos-config/scripts`

Use this when you are debugging, extending, or orchestrating the scripted workflow.

### 6. `MULTI-MACHINE-SYNC.md`
Read this when you want to understand how the setup is intended to stay aligned across multiple laptops.

This document covers:
- tracked workspace snapshot flow
- repo sync responsibilities
- relationship between Nix config, workspace snapshot, repos, and dotfiles

### 7. `KANATA.md`
Read this when you want a human-readable explanation of the Kanata keybinding setup.

This document explains:
- layer behavior
- home-row mods
- navigation/number modes
- special chords
- relationship to Hyprland

---

## How these docs relate to the repo

This repo is more than just a flake or a set of Nix modules.

It is also an operational control center for:
- machine bootstrap
- tracked user systemd units
- workspace snapshot export/bootstrap/sync
- secrets restoration
- reproducible setup workflows

Important related directories include:

### `hosts/`
Machine-specific host definitions.

### `modules/`
Reusable NixOS modules.

### `scripts/`
Operational scripts used for setup and maintenance.

### `systemd/user/`
Tracked source of truth for user systemd unit files.

### `tools/workspace/`
Tracked snapshot of the `~/Repositories` workspace routing layer.

### `secrets/`
Secret-related configuration inputs.

---

## Related external runtime/config locations

### `~/.config/ai/`
Live AI runtime configuration:
- shared principles
- templates
- skills
- agent runtime directories

### `~/Repositories/`
Live working tree for actual project repositories and workspace routing.

### `~/.config/systemd/user/`
Active installed user systemd units.

### Dotfiles repo
Personal environment layers such as:
- Hyprland
- Quickshell
- shell/editor/UI config

should be documented in and managed from the separate dotfiles repo.

Known references:
- `https://github.com/aaronjan98/dotfiles`
- `https://github.com/aaronjan98/dotfiles/tree/main/.config/quickshell`

---

## Practical usage

### If you are setting up a brand new machine
Read in this order:
1. `NIXOS-INSTALL.md`
2. `MANUAL-BOOTSTRAP.md`
3. `NEW-MACHINE-SETUP.md`

### If you are debugging secrets or trust issues
Read:
1. `SECRETS.md`
2. `MANUAL-BOOTSTRAP.md`

### If you are changing or extending automation
Read:
1. `SCRIPTS.md`
2. `NEW-MACHINE-SETUP.md`
3. `MULTI-MACHINE-SYNC.md`

### If you are working on keyboard/input behavior
Read:
1. `KANATA.md`

---

## Summary

This documentation directory is the human-readable guide to how the machine is installed, trusted, bootstrapped, synchronized, and maintained.

It exists so that:
- setup remains understandable
- automation remains maintainable
- trust/bootstrap steps remain explicit
- multi-machine behavior is documented
- the whole system can be reproduced across machines
