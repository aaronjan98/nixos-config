# 2026-05-22 — SSH config standardization across hosts

## Context
Continuing the multi-laptop sync work from 2026-05-21. After implementing `remotes.tsv` and restoring SSH material from pass on the Framework, `git fetch home` for `automation/video-summary` failed twice:

1. First: `~/.ssh/config` (copied from ThinkPad) pointed `sweetpea-git` at `~/.ssh/thinkpad-t14` — a key that doesn't exist on the Framework.
2. Second: after repointing to `~/.ssh/id_ed25519` (Framework's locally-generated machine key), homelab rejected the key — `id_ed25519.pub` is authorized on the *local* git server (via `configuration.nix`) but not on the homelab git server.

## Decision: use `id_rsa` for `sweetpea-git` on all hosts

`id_rsa` is the shared cross-machine bootstrap key. It is already authorized on the homelab (see comment in `seed-local-git-server.sh`). Using it for the `sweetpea-git` alias means:

- A new host can bootstrap with zero manual `authorized_keys` editing on the homelab.
- The SSH config for `sweetpea-git` becomes identical across all hosts → easy `pass cp` when staging a new host.
- Per-host machine identity keys (`~/.ssh/thinkpad-t14`, future `~/.ssh/framework-13`) still exist for local git server access (which IS managed declaratively in each host's `configuration.nix`) and for any other per-host service the user opts into.

This is a small dilution of the per-host security model for homelab git specifically — the user accepted this trade for the seamless bootstrap.

## Files updated

- `docs/SECRETS.md` — added "Per-host SSH config convention" section under SSH material.
- `~/.ssh/config` on both ThinkPad and Framework — `sweetpea-git` `IdentityFile` changed from machine key to `~/.ssh/id_rsa`.
- pass `laptop/thinkpad-t14-nixos/ssh/config` and `laptop/framework-13/ssh/config` — re-inserted to reflect the change.

## Pass conflict notes (Framework-side)

While pulling pass on the Framework, hit an `add/add` conflict on `laptop/framework-13/sops/age.gpg` because both ThinkPad and Framework had independently `pass insert`-ed the same age key. Decrypted contents were identical (GPG ciphertext is non-deterministic). Resolved by rebasing with `git checkout --ours` (during rebase, `--ours` = the rebase target = origin/main = ThinkPad's version), then `git rebase --continue` auto-dropped the now-redundant commit.

**Lesson for the workflow:** `laptop/<host>/...` entries should originate from one canonical machine (ThinkPad). Always `pass git pull` before `pass insert` on a non-canonical machine to avoid this kind of silent divergence.

## Still-open items

- `restore-secrets.sh` hardcoded filename list is out of sync with what's actually in pass — list is from the Fedora era. Switching to `pass ls`-based discovery would fix this drift. Not blocking.
- Rename Framework's `~/.ssh/id_ed25519` → `~/.ssh/framework-13` to match ThinkPad's hostname-keyed pattern. Plan: defer until wipe-and-rebootstrap rehearsal.
- `bootstrap-new-machine.sh` should be rehearsed against a wiped Framework once all prereqs are in pass — that's the integration test.
- Documents/Pictures `sync-documents.timer + --delete` footgun → Syncthing (deferred per user direction).
