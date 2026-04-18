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

## `ai-router.sh`
Purpose:
- choose how Claude Code is launched
- support:
  - cloud mode
  - local mode
  - auto mode

Typical use:
- normal interactive use should prefer cloud mode
- local mode is currently experimental and kept mainly for future use or limited testing

Behavior:
- `--cloud` launches normal Claude
- `--local` launches Claude with local backend environment overrides
- `--auto` uses routing logic, but current policy should strongly prefer cloud unless local is explicitly requested

Notes:
- local backend support is wired up but is not currently part of the normal recommended workflow
- bulk filesystem changes should still follow the script-first rule
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

When to use this pattern vs. a normal fetchzip/fetchurl derivation:
- Use `requireFile` + NAS when Nix **cannot fetch the source automatically** — e.g. the download
  requires a login, license acceptance, or has no stable public URL (Wolfram is the canonical example).
- Use `fetchzip`/`fetchurl` directly when the source is publicly available at a stable URL
  (npm packages, GitHub releases, etc.). The NAS is not needed for these.

Workflow for a `requireFile`-backed package:
1. Manually download the binary/installer and place it on the NAS under
   `/mnt/storage/distfiles/<package-name>/`
2. On the target machine: `sync-distfiles <package-name>`
3. Add the file to the Nix store: `nix store add-file /var/lib/distfiles/<package-name>/<file>`
4. The derivation's `requireFile` will now resolve and the build can proceed.

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

---

## Planned / not yet implemented

### `backup-secrets.sh`
Intended as the inverse of `restore-secrets.sh`.
Purpose:
- read SSH material from `~/.ssh/`
- store each file into `pass` under the hostname-derived prefix `laptop/<hostname>/ssh/<filename>`
- prepare or refresh the password-store entries that `restore-secrets.sh` depends on

See `CONTEXT.md` for the open design questions that must be resolved before this is written.
