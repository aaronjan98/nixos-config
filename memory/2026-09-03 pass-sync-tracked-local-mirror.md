# 2026-09-03 — pass repo was silently pulling from the stale local mirror, not Forgejo

## Symptom
`sync-arrive` kept reporting `pass` "already up to date," but new password
entries pushed from the Framework weren't showing up on the ThinkPad.

## Root cause
`pass` (`~/.password-store`) has three remotes: `home` (Forgejo, the real
server), `hub` (n/a for pass), and `local` (a bare-repo mirror on this exact
machine, served by `git-server.nix` — `/srv/git/repos/*.git` over git-shell
SSH on 127.0.0.1). `local` is a **passive** mirror: nothing auto-syncs it from
`home`, it only updates on an explicit `git push local ...`.

`pass`'s `main` branch had its upstream (`@{u}`) set to `local/main` instead of
`home/main` — likely from an early bootstrap step, unlike `nixos-config` and
`zettelkasten` which correctly track `home`. `sync-machine.sh`'s `git_pull()`
did a bare `git pull --ff-only` (no explicit remote), so it silently followed
whatever `@{u}` pointed at — i.e. the dead local mirror — and always reported
"up to date" because, relative to that stale mirror, it *was*.

## Fix
1. One-time: `git branch --set-upstream-to=home/main main` in `~/.password-store`,
   then fast-forwarded from `home`, then `git push local main` to catch the
   mirror back up (verified all three refs — HEAD/home/local — converge).
2. Structural: `sync-machine.sh`'s `git_pull()` now does `git pull home main
   --ff-only` explicitly, matching `dotfiles_pull()`'s existing pattern —
   so a drifted tracking branch can't silently cause this again for
   `pass`/`nixos-config`/`zettelkasten`.

## Note
`local` (`git-server.nix`) is a genuine bare-repo git server on this laptop —
not an alias for anything remote. It exists for offline/local access but has
no automatic sync mechanism in either direction; treat it as a manual-push
target only, never a pull source for `sync-arrive`.
