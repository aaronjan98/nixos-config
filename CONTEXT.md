# CONTEXT.md

## Project
nixos-config

## Purpose
This repository defines AJ's NixOS system configuration and the supporting operational tooling used to reproduce and maintain the machine.

It includes:
- host and module definitions for NixOS
- operational scripts for setup and maintenance
- tracked user systemd unit files
- the tracked workspace snapshot for `~/Repositories`
- documentation for machine bootstrap, secrets, scripts, sync, and Kanata

This repository should be treated as an operational control center for the machine.

## What good looks like
- configuration changes are understandable and reproducible
- machine setup is documented and scriptable
- tracked scripts have clear responsibilities
- user systemd units are managed from tracked source files
- workspace routing and repo placement remain reproducible across machines
- documentation is useful to both humans and AI agents

## What to avoid
- making broad changes without understanding the module or script boundary
- mixing workspace snapshot concerns with live AI runtime config
- adding scripts here for behaviour the **voice-assistant orchestrator** drives at runtime. Ownership boundary: a file belongs in this repo only if a Nix module or systemd unit references it by path; anything the orchestrator decides to do at runtime lives in the `voice-assistant` repo as Python. This repo is touched only for a new system package or a systemd unit. See `voice-assistant/project-memory/browser-playback-spec.md`.
- duplicating responsibilities across scripts
- storing secrets directly in the repo outside the intended secret management flow
- editing tracked runtime-generated files when the source-of-truth file is elsewhere
- folding dotfiles-managed personal environment concerns into this repo unnecessarily

## Important directories

### `hosts/`
Machine-specific host configuration.

### `modules/`
Reusable NixOS modules.

### `pkgs/`
Custom package definitions and related package sources.

Notable current patterns:
- locally pinned derivations in `pkgs/` for tools not taken directly from nixpkgs (for example `pi` and `openai-codex`)
- overlay exposure in `flake.nix` so those packages can be consumed as normal `pkgs.<name>` entries

When writing a new package derivation, choose the fetch strategy based on source availability:
- **Public URL** (npm, GitHub releases, etc.): use `fetchzip` or `fetchurl` directly.
- **Requires login / no public URL** (e.g. Wolfram): use `pkgs.requireFile` backed by the NAS
  distfiles store. See `docs/SCRIPTS.md` → `sync-distfiles.sh` for the full workflow.

### `scripts/`
Operational scripts for:
- workspace export/bootstrap/sync
- user systemd unit installation
- local git server setup
- distfiles sync
- machine bootstrap
- secrets restoration
- other utility workflows

### `systemd/user/`
Tracked source of truth for user systemd unit files.

### `tools/workspace/`
Tracked workspace snapshot for the live `~/Repositories` tree.
This stores:
- top-level `ROUTER.md`
- area-level `CONTEXT.md`
- `repos.tsv`

### `docs/`
Human-readable setup and maintenance documentation.

### `secrets/`
Encrypted SOPS inputs used by the Nix setup.

Important distinction:
- bootstrap trust material (SSH files and the SOPS age key) lives in `pass`
- declarative runtime secrets live encrypted in `secrets/*.yaml` and are materialized under `/run/...` by `sops-nix`
- shell-visible env vars exported from those runtime secret files may require reloading with `unset __NIXOS_SET_ENVIRONMENT_DONE; . /etc/set-environment` after a rebuild when testing in an already-open shell. NOTE: this approach does NOT work for dynamic secrets using `$(cat ...)` command substitution — PAM sets `__NIXOS_SET_ENVIRONMENT_DONE=1` before any shell starts, so the NixOS guard in `/etc/profile` skips re-sourcing. For those, export directly in `~/.bashrc` instead (e.g. `export FORGEJO_TOKEN="$(cat /run/secrets/forgejo_token 2>/dev/null)"`)

## Related external locations

### `~/.config/ai/`
Live AI runtime configuration:
- shared rules
- templates
- skills
- agent runtime directories

This is separate from the workspace snapshot and separate from this repo itself.

### `~/Repositories/`
Live working tree for actual project repositories and agent-facing workspaces.

### `~/.config/systemd/user/`
Active installed user systemd units.
Tracked canonical copies live in `systemd/user/` inside this repo.

### Dotfiles repo
Personal environment configuration such as:
- Hyprland
- Quickshell
- shell/editor/UI config

should live in the separate dotfiles repository and be documented there, while this repo should reference that layer where needed.

Known references:
- `https://github.com/aaronjan98/dotfiles`
- `https://github.com/aaronjan98/dotfiles/tree/main/.config/quickshell`

## Key files to read first
- `README.md`
- `docs/README.md`
- `docs/AGENT-WORKFLOW.md`

## Key scripts

### `scripts/export-workspace-state.sh`
Scans the live `~/Repositories` tree and updates the tracked workspace snapshot.

### `scripts/bootstrap-workspace.sh`
Recreates the broad workspace layout and clones missing repos from the tracked manifest.

### `scripts/sync-workspace-repos.sh`
Keeps repos aligned with the tracked workspace manifest across machines.

### `scripts/install-user-systemd-units.sh`
Installs tracked user systemd units from `systemd/user/` into `~/.config/systemd/user/`.

### `scripts/restore-secrets.sh`
Restores SSH material and the SOPS age key from `pass`.

### `scripts/bootstrap-new-machine.sh`
Guided orchestrator for new machine setup.

### `scripts/update-pi.sh`
Refreshes the pinned `pkgs/pi` package from npm, regenerates its lockfile and hashes, and optionally verifies the current host's system build.

### `scripts/update-openai-codex.sh`
Refreshes the pinned `pkgs/openai-codex` package from npm, updates its source hash, and optionally verifies the current host's system build.

### `scripts/update-all-pinned-packages.sh`
Runs the tracked pinned-package update scripts in sequence and optionally verifies the current host's combined result with one Nix build.

## How to work in this repo
- Start with the smallest relevant file or directory for the task.
- Prefer understanding before editing.
- Treat scripts as composable units with distinct responsibilities.
- When changing bootstrap behavior, update the documentation as well.
- When changing systemd units, edit the tracked copies in `systemd/user/`, not only the active runtime copies.
- When changing workspace structure assumptions, update both the tracked workspace snapshot and the scripts that depend on it.
- When documenting user environment layers that live elsewhere, reference the external source of truth rather than duplicating it here unless a summary is useful.

## Adding a new global system command

To add a reproducible command available system-wide (like `hypr-dispatch` or `wol-sauron`):

1. Create `modules/<name>.nix` using `pkgs.writeShellScriptBin` — pin any dependencies via `pkgs.<dep>` rather than hardcoding paths.
2. Add the import to `hosts/thinkpad-t14/configuration.nix` under the `imports` list.
3. Add a one-line description of the module to the examples list in `docs/PACKAGES.md`.
4. Run `nixos-rebuild switch` — the command will be on `$PATH` system-wide immediately.

Do NOT place scripts in `~/.local/bin/` for anything that should be reproducible. That directory is for legacy or temporary one-offs only.

## Forgejo git server

Forgejo at `https://git.aaronjanovitch.com` is a web UI mirror of the bare repos on sweetpea
at `/srv/git/repos/`. The bare repos are the source of truth; Forgejo is kept in sync via
post-receive hooks. See `docs/SERVICES.md` for workflow and architecture details.

Key scripts: `new-homelab-repo` (create repo end-to-end), `install-forgejo-hooks` (backfill hooks), `tea` (Forgejo CLI).

Architecture doc: `~/Repositories/self-hosted/homelab/Raymer/project-memory/forgejo-sync.md`

## Routing guidance
- If the task is about NixOS system configuration, inspect `hosts/` and `modules/`.
- If the task is about how a package is sourced or updated, inspect `flake.nix`, `pkgs/`, `modules/`, and the relevant update script in `scripts/`.
- If the task is about machine setup automation, inspect `scripts/` and `docs/`.
- If the task is about user services, inspect `systemd/user/`.
- If the task is about workspace reproducibility, inspect `tools/workspace/`.
- If the task is about AI runtime behavior, inspect `~/.config/ai/` separately from this repo.
- If the task is about Hyprland, Quickshell, or other personal environment layers, inspect the dotfiles repo separately.
- If the task is about the homelab git server or Forgejo, inspect `scripts/new-homelab-repo.sh`, `scripts/install-forgejo-hooks.sh`, and `docs/SERVICES.md`.

## Future implementations

Broader deferred bugs and future feature planning now live in `docs/ROADMAP.md`.
Use the roadmap for durable backlog items; keep this section for implementation stubs that need concrete design constraints captured close to repo orientation.

### `scripts/backup-secrets.sh` (not yet implemented)
This script is the intended inverse of `restore-secrets.sh`.
It should read SSH material from `~/.ssh/` and store each file into `pass` under the hostname-derived prefix `laptop/<hostname>/ssh/<filename>`, mirroring the structure that `restore-secrets.sh` expects.

Before implementing this script, an agent must ask the user to resolve the following design questions:

1. **Scope**: Should the script store everything found in `~/.ssh/`, or only the known fixed list used by `restore-secrets.sh` (e.g. `config`, `authorized_keys`, `id_ed25519.*`, `known_hosts`, etc.)?
2. **Overwrite behavior**: If a `pass` entry already exists for a file, should the script silently overwrite it, skip it, or prompt the user interactively?
3. **Hostname**: Should the script derive the pass prefix from `$(hostname)` (matching `restore-secrets.sh` behavior), or accept a hostname argument to allow seeding entries for a different machine?
4. **Auto-push**: Should the script run `pass git push` at the end to sync to the remote automatically, or leave that to the user?

Do not implement this script without confirming these decisions with the user first.

## Active project specs

Long-running, multi-session work items with design decisions and progress checklists live in `project-memory/`. Read the relevant spec before starting work on a tracked initiative.

- `project-memory/multi-host-refactor-spec.md` — multi-host refactor (ThinkPad + Framework 13 AMD), shared base extraction, pentest module, branch: `multi-host`
- `project-memory/math-ocr-pix2tex-venv-spec.md` — math OCR reimplementation using a Nix-managed wrapper plus pinned pix2tex repo/venv runtime
- `project-memory/text-math-ocr-pipeline-spec.md` — broader Mathpix-like OCR plan for text OCR, math OCR, combined Markdown OCR, feedback capture, correction workflow, and optional `sauron` backend

## Notes
This repo is both a system configuration repo and an operational tooling repo.
An agent working here should preserve clarity, reproducibility, and separation of responsibilities.
