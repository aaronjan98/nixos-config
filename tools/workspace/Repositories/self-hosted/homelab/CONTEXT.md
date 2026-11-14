# CONTEXT.md

## Area
homelab

## Purpose
This directory is the operational home for AJ's homelab environments.
Each homelab gets its own subdirectory containing:
- machine-specific config repos (cloned from bare repos on each machine)
- official documentation in `docs/`
- session notes in `memory/`

## Known homelabs

### Raymer
Ubuntu-based homelab. See `Raymer/CONTEXT.md`.

## Config tracking strategy
**Intended, not actually implemented for Raymer** (checked 2026-10-16: no `~/.homelab-configs`
bare repo exists on qwerty or sweetpea, and no per-machine config snapshot directories exist
under `Raymer/`). The description below is the intended design if this ever gets built —
don't assume it reflects current state.

Each machine would run a bare git repo at `~/.homelab-configs/` with `--work-tree=/`
to track `/etc/` config files without placing `.git` inside `/etc/`.
Config repos would be cloned here as read-only snapshots — edits still happen directly
on each machine over SSH.

**What Raymer actually tracks today instead**: machine-specific service/script repos
per machine (see `Raymer/CONTEXT.md`'s git repo table — e.g. `qwerty-scripts.git` at
`~/qwerty-scripts/` covers scripts and, as of 2026-10-16, a `systemd-units/` copy of
the user-level systemd `.service`/`.timer` files that drive them; `qwerty-services.git`
at `/opt/homelab/` covers docker-compose files). `/etc/` itself is not git-tracked on
any Raymer machine.

## Routing note
- For official machine documentation: look in `<homelab>/docs/`
- For config file state: look in `<homelab>/<machine>/` if it exists (not currently true for Raymer — see above)
- For session notes: look in `<homelab>/memory/`
- For experimental notes, failed builds, and learning logs: see the zettelkasten at
  `~/Repositories/self-hosted/zettelkasten/Inside/Projects/Homelab/`
  (that is a learning resource, not authoritative state)
