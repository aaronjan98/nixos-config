# 2026-05-18 — Forgejo git server setup

## What was worked on

Set up Forgejo at `git.aaronjanovitch.com` as a web UI mirror of the sweetpea bare git repos.
Wired up automated sync via post-receive hooks so every `git push home` mirrors to Forgejo.
Added `new-homelab-repo`, `install-forgejo-hooks`, and `tea` as system commands in nixos-config.

## Key decisions

- sweetpea bare repos (`/srv/git/repos/`) remain the primary remote (`home`); Forgejo is a mirror only
- Two Forgejo API tokens: `laptop-cli` stored in SOPS (`secrets/forgejo.yaml`) for scripting; `sweetpea-hook` in `/etc/forgejo-sync.conf` on sweetpea for the post-receive hook
- `$FORGEJO_TOKEN` exported via `~/.bashrc` directly (`export FORGEJO_TOKEN="$(cat /run/secrets/forgejo_token 2>/dev/null)"`), NOT via `environment.extraInit` — PAM sets `__NIXOS_SET_ENVIRONMENT_DONE=1` before shell init, which causes the NixOS guard to skip `/etc/set-environment` entirely in interactive shells

## Key insights

- `git rev-parse --git-dir` returns `.` in a bare repo post-receive hook context; use `$(pwd)` instead to get the repo name
- `install-forgejo-hooks` must list repos via `ssh sweetpea "ls /srv/git/repos/*.git"` — the path doesn't exist locally
- Multiple `ssh sweetpea "sudo ..."` calls each require a separate TTY; batch all installs into one SSH command
- `tea repos create` uses `--login <name>` not `--url`; login must first be registered with `tea login add`
- The `sweetpea-git` SSH alias exists because short SCP-style git URLs cannot encode a non-default port — it handles `User git` and `Port 2222` so remote URLs stay clean

## Files changed (nixos-config)

- `hosts/thinkpad-t14/configuration.nix` — sops secret for `forgejo_token`, `$FORGEJO_TOKEN` extraInit export, `tea` package, two new scripts
- `scripts/new-homelab-repo.sh` — creates bare repo + Forgejo repo + hook in one command
- `scripts/install-forgejo-hooks.sh` — backfill hooks on existing repos (lists via SSH, batches sudo)
- `secrets/forgejo.yaml` — SOPS-encrypted laptop-cli token

## Infrastructure on sweetpea

- `/srv/git/hooks/forgejo-sync` — shared post-receive hook (git:git 755), uses `$(pwd)` for repo name
- `/etc/forgejo-sync.conf` — sweetpea-hook token config (root:git 640)
- `/opt/forgejo/docker-compose.yml` — Forgejo container on the `reverse-proxy` Docker network
- Forgejo: `https://git.aaronjanovitch.com`

## Open questions / next steps

- Run `nixos-rebuild switch` after any SCRIPTS.md / SERVICES.md / CONTEXT.md doc changes to pick up the `ssh -n` fix in the system `install-forgejo-hooks` command
- The `local` remote in `~/Repositories/automation/video-summary` still points to the old name `clipper-video-summary` — update if that remote is ever used
- `install-forgejo-hooks` only installs on repos with a matching Forgejo counterpart; any new repos created outside `new-homelab-repo` need manual hook installation

## Resolved: initial Forgejo sync for all repos

Completed using `git -c safe.directory='*' push --mirror ...` as `aj` user. All 28 repos
successfully mirrored. See `2026-05-18 video-summary-fix.md` for the full command.
