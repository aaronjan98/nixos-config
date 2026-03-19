# Workspace Snapshot

This directory contains the tracked workspace snapshot for AJ's agentic filesystem.

It is designed to support a file-first, agent-agnostic workflow across multiple machines.

The live working tree remains:

- `~/Repositories`

The live AI runtime/config remains:

- `~/.config/ai`

This directory exists to track and reproduce the *workspace layer* that sits between those two things.

---

## High-level purpose

This snapshot solves a specific problem:

- `~/Repositories` is the real place where work happens
- but `~/Repositories` itself is not one big git repo
- and the top-level/area-level routing files are not naturally tracked by the project repos inside it

So this directory stores a *tracked skeletal representation* of the live workspace.

That tracked representation includes:

- broad routing files
- area-level routing files
- a manifest of what git repositories live where

This allows another machine to reconstruct the same high-level workspace layout.

---

## Relationship to the larger agentic workflow

The overall system has three major layers:

### 1. Live AI runtime config
Path:

- `~/.config/ai/`

Purpose:
- shared AI rules
- templates
- skills
- agent runtime home

This is where reusable AI logic lives.

### 2. Live working tree
Path:

- `~/Repositories/`

Purpose:
- actual work
- actual git repositories
- local routing surfaces for real projects

This is the directory tree where Claude Code and other agents will actually work.

### 3. Tracked workspace snapshot
Path:

- `~/nixos-config/tools/workspace/`

Purpose:
- track the broad structure of the live working tree
- track routing files that exist outside project repos
- track where project repos belong
- make the workspace reproducible across machines

This directory is the bridge between the abstract AI setup and the real working tree.

---

## What is stored here

### `Repositories/`
This directory mirrors the live `~/Repositories` tree only up to repo boundaries.

It stores:
- `ROUTER.md`
- area-level `CONTEXT.md`
- `repos.tsv`

It does *not* store:
- full repo contents
- repo-local AI files like `CONTEXT.md`, `MEMORY.md`, and `DEPENDENCIES.md`
- any subtree below a `.git` boundary

### `Repositories/ROUTER.md`
This is the broad routing file for the entire `~/Repositories` workspace.

Its role is to tell an agent:
- what broad areas exist
- which area should be inspected first

It is intentionally high-level.

### `Repositories/<area>/CONTEXT.md`
These are area-level routing files.

Examples:
- `school/CONTEXT.md`
- `automation/CONTEXT.md`
- `self-hosted/CONTEXT.md`

Their role is to tell an agent:
- what kind of work happens in that area
- when that area is relevant
- what kinds of repos it contains

### `Repositories/repos.tsv`
This is the authoritative root manifest for all repos in the workspace.

Each row records:
- the relative path under `~/Repositories`
- the repo name
- the preferred remote URL for cloning

This file is used by:
- the bootstrap script
- the sync script

---

## Why repo boundaries matter

The snapshot is intentionally *repo-boundary aware*.

When the export script walks `~/Repositories`, it stops descending when it finds a `.git` directory.

At that point:
- the repo path is written to `repos.tsv`
- traversal of that branch stops

This is important because repo-local files should remain owned by the repo itself.

For example:
- `~/Repositories/school/scientific_computing/CONTEXT.md` belongs to that repo
- so it should be tracked in that repo
- it should not be duplicated into the workspace snapshot

This keeps responsibilities clean.

---

## Scripts that work with this directory

### Export script
Path:

- `~/nixos-config/scripts/export-workspace-state.sh`

Purpose:
- scan the live `~/Repositories` tree
- mirror top-level and area-level routing files into this snapshot
- generate `Repositories/repos.tsv`
- stop at git repo boundaries

This script keeps the snapshot current.

### Bootstrap script
Path:

- `~/nixos-config/scripts/bootstrap-workspace.sh`

Purpose:
- reconstruct `~/Repositories` from this snapshot on another machine
- restore `ROUTER.md`
- restore area-level `CONTEXT.md`
- clone missing repos into the right paths using `repos.tsv`

This is mainly for first-time setup or rebuilding after reinstall.

### Sync script
Path:

- `~/nixos-config/scripts/sync-workspace-repos.sh`

Purpose:
- use `repos.tsv` to keep repo placement and repo contents aligned across machines
- clone missing repos
- fetch and safely update existing repos

This is for ongoing multi-laptop use.

---

## Tracked systemd units

Tracked user systemd units live in:

- `~/nixos-config/systemd/user/`

This is the tracked source of truth for user units such as:
- `export-workspace-state.service`
- `export-workspace-state.timer`
- `video-summary.service`
- `video-summary.path`
- `video-summary.timer`

The active installed copies live in:

- `~/.config/systemd/user/`

This means:
- `~/nixos-config/systemd/user/` is the tracked source of truth
- `~/.config/systemd/user/` is the active runtime location

### Unit installation script
Path:

- `~/nixos-config/scripts/install-user-systemd-units.sh`

Purpose:
- copy tracked unit files into `~/.config/systemd/user/`
- reload the user systemd daemon
- enable `export-workspace-state.timer`
- leave `video-summary` disabled by default so manual runs remain the normal behavior

---

## Data flow

The normal direction of flow is:

1. you work in `~/Repositories`
2. the export script snapshots the non-repo routing layer into this directory
3. this directory is tracked in your Nix config repo
4. on another machine, the bootstrap script reads this directory and recreates the broad workspace structure
5. the sync script keeps the actual repos aligned over time

So:

- live work -> exported snapshot -> tracked repo -> reconstructed workspace

---

## Why this is separate from `~/.config/ai`

`~/.config/ai` is the AI runtime/config layer.

This directory is the workspace-tracking layer.

They are related, but they solve different problems:

### `~/.config/ai`
answers:
- how should agents behave?
- what templates exist?
- what skills exist?

### `tools/workspace`
answers:
- what does the live workspace look like?
- what routing files exist outside repos?
- where do repos belong?

Keeping them separate makes the system easier to reason about.

---

## Operational expectations

### What should change often
- `Repositories/repos.tsv`
- area-level routing files when your workspace structure changes
- top-level `ROUTER.md`

### What should not change often
- the conceptual model
- the scripts
- the timer setup

### What is still tracked elsewhere
Repo-local files such as:
- `CONTEXT.md`
- `MEMORY.md`
- `DEPENDENCIES.md`

should remain inside each git repo and be tracked there.

---

## Reproducibility model

This setup is reproducible because:

- shared AI behavior is tracked in `~/.config/ai`
- workspace routing and repo placement are tracked here
- scripts are tracked in `~/nixos-config/scripts`
- tracked user systemd units live in `~/nixos-config/systemd/user/`
- active user systemd units are installed from those tracked files

A new machine only needs:
- the Nix config repo
- the AI config
- the bootstrap and sync scripts
- the tracked workspace snapshot

to reconstruct the same structure.

---

## Summary

This directory is the tracked, repo-boundary-aware workspace skeleton for `~/Repositories`.

It exists so that:
- the workspace routing layer is not lost
- repo placement is explicit
- the whole system is reproducible across machines
- the agentic filesystem remains understandable and maintainable
