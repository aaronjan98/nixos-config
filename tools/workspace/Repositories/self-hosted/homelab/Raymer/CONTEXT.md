# CONTEXT.md

## Homelab
Raymer — Ubuntu-based homelab

## Machines

### sweetpea
- Hardware: Dell OptiPlex 7050 Micro
- OS: Ubuntu
- Role: DNS, DHCP, nginx reverse proxy
- Config repo: `sweetpea/` (clone when ready)

### qwerty
- Hardware: HP EliteDesk 800 G4 Mini
- OS: Ubuntu
- Role: Docker host — Immich (photos), Jellyfin (media), Nextcloud (file storage)
- Storage: Terramaster NAS mounted to this machine
- Config repo: `qwerty/` (clone when ready)

### sauron
- Hardware: HP Z640 Workstation
- OS: Ubuntu
- Role: AI workloads, woken via Wake-on-LAN
- Config repo: `sauron/` (clone when ready)

## Directory structure
- `docs/` — official documentation for Raymer (current deployed state, runbooks)
- `memory/` — session notes for work done on Raymer
- `sweetpea/`, `qwerty/`, `sauron/` — config repo clones (read-only snapshots)

## Current implementation state
See `project-memory/homelab-codification.md` for the phased implementation plan,
what has been completed, and what is still pending.

## Routing note
- For the implementation plan and current progress: `project-memory/homelab-codification.md`
- For authoritative machine documentation: `docs/`
- For session notes: `memory/`
- For deferred bugs and future features: `ROADMAP.md`
- For learning logs, experiments, and historical notes: zettelkasten `Inside/Projects/Homelab/`
