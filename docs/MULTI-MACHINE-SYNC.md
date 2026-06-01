# Multi-Machine Sync

This document explains how the setup stays usable across multiple laptops (and one always-on homelab peer).

The goal is not to make every machine identical at every moment — it is to keep the important layers aligned:

- NixOS config
- dotfiles
- secrets/trust material
- Documents and Pictures (continuous, via Syncthing)
- live project repos

---

## TL;DR — the everyday workflow

**Sitting down at a laptop:** press `Super+A`. That's it. It pulls
nixos-config, dotfiles, pass, zettelkasten, and every project repo.
A toast tells you when it's done. (It also runs automatically the
first time you log in graphically, so most of the time you don't even
press it.)

**Walking away from a laptop:** press `Super+E` *or just close the lid*.
A toast lists any repos with uncommitted changes — your reminder to
commit and push before suspend. It never auto-pushes; that part is on
you (`g pushall` / `dot pushall`).

**Documents and Pictures:** nothing to do — Syncthing mirrors them
continuously over LAN or relay between every laptop and the always-on
homelab peer (`qwerty`). Even if both laptops are never on at the same
time, the homelab catches changes and propagates them on next session.

**After a `Super+A` pull, if anything in `nixos-config` changed:** run
`nrs` to rebuild. If shell aliases changed: `source ~/.bashrc`.

That's the whole loop. Everything below is the detail behind it.

---

## Day-to-day workflow

Two keybinds in Hyprland (`~/.config/hypr/conf.d/20-binds.conf`) drive the manual layers. Both run through `~/.config/hypr/scripts/sync-toast`, which wraps `sync-machine.sh` and surfaces results via `notify-send` toasts (rendered by Quickshell).

### Sitting down at a machine — `Super+A` (arrive)

Equivalent to `sync-machine.sh --arrive`. Pulls every git-tracked layer:

1. `nixos-config` (fast-forward only)
2. Workspace skeleton restored from snapshot (`bootstrap-workspace.sh`)
3. dotfiles bare repo
4. `pass` (password store)
5. `zettelkasten`
6. All workspace repos from the manifest (`sync-workspace-repos.sh`)

Toast outcomes:
- Green "Sync-arrive OK — Workspace up to date"
- Red sticky "Sync-arrive FAILED" — see `/tmp/sync-arrive.log`

Sync-arrive *also* runs automatically on graphical login via `sync-arrive.service` (a user systemd unit triggered by `graphical-session.target`). The keybind is for explicit refreshes mid-session.

If `nixos-config` changed, run `nrs` to rebuild. If aliases changed, run `source ~/.bashrc`.

### Leaving a machine — `Super+E` (end-of-session)

Equivalent to `sync-machine.sh --leave`. **Read-only by design** — it does *not* push or commit. It walks every tracked layer and lists any repo with uncommitted changes (modified files, staged files, or untracked files; for the dotfiles bare repo, only tracked-file changes are checked since `$HOME` has too many untracked entries to be meaningful).

Scope (matches what sync-arrive pulls):
- `nixos-config`
- dotfiles bare repo (tracked-only check)
- `pass`
- Every repo under `~/Repositories/` listed in the workspace manifest (`tools/workspace/Repositories/repos.tsv`)

Toast outcomes:
- Green "Sync-leave OK — All repos clean, safe to close lid"
- Yellow "Sync-leave: action needed" with a bulleted list of dirty repos
- Red sticky "Sync-leave FAILED" — see `/tmp/sync-leave.log`

Closing the lid suspends wifi, so the toast is your signal to wait for completion before walking away. If the toast lists dirty repos, commit and push them yourself before leaving — sync-leave deliberately does *not* do that for you:

    g pushall
    dot pushall

The plain-text status (same as the toast body) is written to `/tmp/sync-leave.status` for later inspection.

---

## Documents and Pictures — Syncthing (continuous, automatic)

`~/Documents` and `~/Pictures` sync continuously over LAN/relay via Syncthing — not via rsync, not on a timer.

Topology: full mesh between every peer.

| Peer | Hostname | Role | Always on? |
|---|---|---|---|
| ThinkPad T14 | `nixos` | laptop | no |
| Framework 13 | `framework-13` | laptop | no |
| Homelab | `qwerty` | always-on Ubuntu server | yes |

The homelab peer guarantees convergence — even if the two laptops are never powered on simultaneously, changes flow through `qwerty` and reach the other laptop on its next session.

### Module

NixOS hosts use the declarative module at `modules/syncthing.nix`. Enabled in `hosts/common/default.nix` via `aj.syncthing.enable = true;`. Each host declares its peers in its host file:

```nix
aj.syncthing.devices = {
  framework-13.id = "HREY2AY-…";
  qwerty.id       = "F4NZQDP-…";
};
```

Device IDs are derived from the Syncthing TLS pubkey and are safe to commit publicly (same threat model as an SSH pubkey).

The homelab peer runs vanilla Syncthing (apt package) under `loginctl enable-linger` so the service stays up without a login session. Folders configured via `syncthing cli config folders/devices add-json` once at bootstrap.

### Versioning

Every folder uses staggered versioning (Syncthing retains deletes for 30 days at `~/.stversions/`), so a stray `rm` on one peer is recoverable from any other peer.

### Accessing the Syncthing GUI on `qwerty`

`qwerty`'s Syncthing GUI is bound to `127.0.0.1:8384` (not the LAN) so the
admin UI is never exposed beyond the box itself — auth is set, but localhost
binding removes the attack surface entirely.

To reach it from a laptop, open an SSH tunnel and visit the friendly local
domain wired into `modules/caddy.nix`:

```sh
ssh -L 8384:127.0.0.1:8384 aj@qwerty.home
# then in a browser:
#   http://syncthing.local
```

The caddy entry binds to `127.0.0.1` only, so the domain itself isn't
reachable off the laptop either — `syncthing.local` is purely a convenience
URL, not exposure.

For laptop-local Syncthing, `http://localhost:8384` works directly (no
tunnel needed) since the NixOS module binds the GUI to loopback on each
machine.

### Git repos are NOT synced via Syncthing

`.git/` is a mutable binary database; a sync-conflict file inside `.git/objects/` would corrupt the repo. Repos travel via explicit pull/push in `sync-machine.sh`. See `docs/ROADMAP.md` for the "WIP-branch helper" idea (deferred) — a possible future shortcut for moving uncommitted work between laptops via git's atomic primitives instead of Syncthing.

---

## Main sync layers

### `~/nixos-config`
Source of truth for NixOS config, scripts, docs, workspace snapshot, and tracked systemd units. Cloned on each machine. Pulled by `sync-arrive`.

### Dotfiles (`~/.dotfiles` bare repo)
Personal environment: Hyprland, Quickshell, shell/editor config. Accessed via the `dot` shell function (`git --git-dir=$HOME/.dotfiles --work-tree=$HOME`). Pulled by `sync-arrive`.

### `~/Repositories`
Live working tree for project repos. Reconstructed on new machines with `bootstrap-workspace.sh`; refreshed by `sync-workspace-repos.sh` (called by `sync-arrive`).

### `pass` (`~/.password-store`)
GPG-encrypted secrets. Pulled by `sync-arrive`.

### Zettelkasten (`~/Repositories/self-hosted/zettelkasten`)
Notes repo. Also covered by the workspace-repo sweep.

### Documents / Pictures
Continuous file sync via Syncthing (see above). No manual action needed.

---

## Systemd user units

Installed via `~/nixos-config/scripts/install-user-systemd-units.sh`:

| Unit | Trigger | Purpose |
|---|---|---|
| `sync-arrive.service` | `graphical-session.target` | Run `sync-machine.sh --arrive` on graphical login |
| `export-workspace-state.timer` | hourly | Refresh `tools/workspace/Repositories/` snapshot |

Old rsync-based units (`sync-documents.{service,timer}`, `sync-pictures.{service,timer}`) have been removed — superseded by Syncthing.

---

## Environment variables for sync-machine.sh

| Variable | Default |
|---|---|
| `ZETTELKASTEN` | `~/Repositories/self-hosted/zettelkasten` |

(NAS-related variables — `NAS_HOST`, `NAS_DOCS_REMOTE`, etc. — are gone. Documents/Pictures no longer go through rsync.)

---

## Workspace structure sync

### After adding/renaming workspace areas

Export the snapshot so other machines can reconstruct the structure:

    ~/nixos-config/scripts/export-workspace-state.sh

Commit and push `nixos-config`. Other machines pick it up on next `sync-arrive`.

### Reconstructing workspace on a new machine

    ~/nixos-config/scripts/bootstrap-workspace.sh
    ~/nixos-config/scripts/sync-workspace-repos.sh

`bootstrap-workspace.sh` is idempotent: it clones missing repos, reconciles per-repo remotes from `remotes.tsv`, and heals upstream tracking on the current branch (preferring the `home` remote, falling back to the first listed).

---

## What is and is not synced

### Synced
- tracked workspace skeleton and repo manifest (via `nixos-config`)
- NixOS config
- dotfiles
- Documents/Pictures (via Syncthing, continuous)
- secrets (via `pass`)
- project repos (via workspace sync)

### Not synced here
- repo-local project contents beyond what git tracks (build artifacts, caches, `.venv/`, `node_modules/`)
- runtime state in `~/.config/systemd/user/` (units themselves are tracked in nixos-config; runtime symlinks are not)
- ad-hoc files outside `~/Documents`, `~/Pictures`, dotfiles, or a known repo

---

## Syncthing reachability

Syncthing uses LAN discovery first, then global discovery + relay servers when peers are off-LAN. No VPN required. If a laptop is off-LAN, it still finds the homelab via the public discovery service and relays through it (encrypted end-to-end).

If both laptops are off-LAN with the homelab unreachable too, they will still converge directly via relay — just slower.
