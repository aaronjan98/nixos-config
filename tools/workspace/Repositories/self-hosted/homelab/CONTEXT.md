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
Each machine runs a bare git repo at `~/.homelab-configs/` with `--work-tree=/`
to track `/etc/` config files without placing `.git` inside `/etc/`.
Config repos are cloned here as read-only snapshots — edits still happen directly
on each machine over SSH.

## Routing note
- For official machine documentation: look in `<homelab>/docs/`
- For config file state: look in `<homelab>/<machine>/`
- For session notes: look in `<homelab>/memory/`
- For experimental notes, failed builds, and learning logs: see the zettelkasten at
  `~/Repositories/self-hosted/zettelkasten/Inside/Projects/Homelab/`
  (that is a learning resource, not authoritative state)
