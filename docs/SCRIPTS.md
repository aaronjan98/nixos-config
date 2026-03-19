# Script Inventory

This document lists the operational scripts in `~/nixos-config/scripts` and explains when they should be used.

## `bootstrap-workspace.sh`
Purpose:
- recreate `~/Repositories`
- restore top-level and area-level routing files from the tracked workspace snapshot
- clone repos into their expected locations

Typical use:
- initial setup on a new machine
- rebuilding workspace structure after a clean reinstall

## `export-workspace-state.sh`
Purpose:
- scan the live `~/Repositories` tree
- export top-level and area-level routing files to the tracked workspace snapshot
- update the root repo manifest

Typical use:
- regular maintenance
- automatically via systemd timer

## `install-user-systemd-units.sh`
Purpose:
- install tracked user systemd units from `~/nixos-config/systemd/user/` into `~/.config/systemd/user/`
- reload user systemd
- enable `export-workspace-state.timer`

Typical use:
- after cloning `nixos-config` on a new machine
- whenever tracked user units have changed

## `restore-secrets.sh`
Purpose:
- restore SSH files from `pass`
- restore the SOPS age key from `pass`
- prepare the machine for private repo access and secret-backed Nix usage

Typical use:
- early in new-machine setup, after GPG and `pass` are functional

## `bootstrap-new-machine.sh`
Purpose:
- orchestrate the safe, guided machine setup sequence
- check prerequisites
- run the smaller scripts in the correct order
- print next steps

Typical use:
- new laptop setup
- first-time bring-up after cloning this repo

## `rsync-git-server-mirror.sh`
Purpose:
- mirror the homelab git server into the local git server

Typical use:
- when refreshing the local git mirror from home

## `seed-local-git-server.sh`
Purpose:
- set up the local git server structure on the machine

Typical use:
- new machine setup
- preparing a local git mirror workflow

## `sync-distfiles.sh`
Purpose:
- copy cached distfiles/binaries from the NAS-backed distfiles location into the local distfiles location

Typical use:
- before builds or installs that benefit from cached distfiles
- during new-machine bootstrap

## `sync-workspace-repos.sh`
Purpose:
- keep workspace repos aligned with the root manifest
- clone missing repos
- fetch and safely update existing repos

Typical use:
- multi-machine upkeep
- after bootstrap

## `math-ocr.sh`
Purpose:
- operational helper for the math OCR workflow

## `tmux-battery.sh`
Purpose:
- tmux helper/status script
