# 2026-05-22 — Multi-machine sync wrap-up

Closing-out session for the multi-machine-sync task list (tasks #1–#8).
The big remaining piece was task #6 (sync-leave-preflight on suspend),
which surfaced a chain of bootstrap-flow bugs.

## What was worked on

### sync-leave-preflight module (task #6)
- Found `%U` specifier was rendered **literally** by NixOS in
  `Environment=` lines — notify-send tried to reach
  `/run/user/%U/bus` (no such file).
- Refactored `modules/sync-leave-preflight.nix` to use a `script = ...`
  block that resolves `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS`
  via `id -u` at runtime. Avoids depending on systemd specifier
  expansion entirely.
- Validated: `sudo systemctl start sync-leave-preflight` toasts cleanly;
  real lid-close suspend produces the toast on wake.

### 3 ThinkPad-only repos (vulnlab, directional_fields, phase_portraits)
- Caused `repos.tsv` ping-pong because they had no remote and
  `export-workspace-state.sh` kept rewriting them with empty URLs.
- Created bare repos on sweetpea (homelab git server) via
  `ssh -t sweetpea "sudo -u git git init --bare ..."` —
  **deliberately did NOT install the `forgejo-sync` post-receive hook**
  so they don't appear in Forgejo.
- Added `home` remote to each local working copy, pushed `main`.
- Added the 3 entries to `seed-local-git-server.sh` REPOS array so
  Framework's `/srv/git/repos` mirrors them automatically.

### seed-local-git-server.sh hardening (latent bugs surfaced when
seeding Framework)
1. `/srv/git` is mode 700 by default — blocks `git` group members
   from traversing to the bare repos. Script now self-heals via
   `sudo chmod 2750 /srv/git`.
2. Some pre-existing bare repos were created via `git init --bare`
   (no `origin` remote). Script now detects missing `origin` and adds
   it with `--mirror=fetch` semantics, instead of silently failing
   `remote set-url` and then erroring on `remote update`.
3. Pre-existing `objects/` subdirs sometimes had stricter perms than
   current umask. Script now does `sudo chmod -R g+rwX "$dest"` before
   the update path runs, not just after a successful clone.

### llmfit cleanup
- `~/Repositories/self-hosted/llmfit` was a March scratch clone for
  developing `pkgs/llmfit/hf-accept-encoding-identity.patch`. The
  finished patch lives in nixos-config; the local clone had an empty
  patch file and a no-op detached-HEAD commit.
- Removed the clone, re-ran `export-workspace-state.sh`. The Nix
  package itself (`pkgs/llmfit/default.nix`) is unaffected.

### Documentation
- Added Phase 3 "Smoke test" section to `docs/MANUAL-BOOTSTRAP.md` —
  4-item checklist (Super+A/E, sync-leave-preflight, `g pushall`
  reach, Syncthing visibility).
- Added note that `sync-leave-preflight` is auto-pulled via
  `hosts/common` (no manual enable needed).
- Added troubleshooting entry for the `/srv/git` mode-700 symptom.

## Key insights

- **Systemd specifier `%U` is unreliable inside NixOS-generated
  `Environment=` values.** Always resolve at runtime via `id -u`
  inside a wrapper script when running as a specific user.
- **The `local` git remote pattern is per-machine, not shared.**
  `ssh://git@localhost/...` only works because each machine has its
  own `/srv/git/repos`, seeded by `seed-local-git-server.sh` mirroring
  from the home Forgejo server. Without a shared upstream (home),
  there is no cross-machine propagation.
- **`new-homelab-repo.sh` installs the `forgejo-sync` post-receive
  hook** which auto-syncs to Forgejo on push. If you want a bare
  repo on sweetpea WITHOUT a Forgejo entry, skip the hook install
  and `tea repos create` — i.e. don't use the script, just
  `sudo -u git git init --bare` directly on sweetpea.
- **Bash parameter expansion `${1:?msg}` breaks if `msg` contains
  `}`** — discovered earlier in sync-toast wrapper. Worth remembering.

## Decisions made

- 3 scratch repos went to `home` only (no Forgejo, no GitHub) per
  user preference for keeping experimental work private.
- llmfit clone deleted (the patch is preserved in nixos-config).
- Skipped wiping Framework for end-to-end bootstrap validation —
  cost/benefit unfavorable. Will validate on next new machine using
  the new Phase 3 smoke-test checklist.

## Open questions / next steps

- None for this task list. Tasks #1–#8 all complete.
- Future bootstrap validation will follow the new Phase 3 smoke
  test in `docs/MANUAL-BOOTSTRAP.md`.
- A handful of dirty repos still need user-driven commits/pushes
  (Raymer needs `g pull --rebase home main` first; lazy-lock.json
  needs a commit policy decision).
