# 2026-05-21 — Workspace sync scripts breakdown + remote mirroring design

## Context
Continuing Framework 13 bootstrap. After the 2026-05-19 session got the OS+pass+nixos-rebuild working, today focused on making the live workspace (`~/Repositories/`) match between ThinkPad and Framework — both repo placement and per-repo remote configuration.

---

## The three workspace scripts and their roles

These are the moving parts that keep `~/Repositories/` reproducible across machines. All three are documented in `tools/workspace/README.md`, but here is the concise version:

### `scripts/export-workspace-state.sh`
- **Direction:** live `~/Repositories/` → tracked snapshot `tools/workspace/Repositories/`
- Walks the live tree, stopping at `.git` boundaries.
- Writes non-repo routing files into the snapshot: `ROUTER.md`, area-level `CONTEXT.md`, `MEMORY.md`, `memory/`, `project-memory/`.
- Generates `repos.tsv` (one row per discovered repo: relative path, repo name, preferred remote URL).
- Runs hourly via `export-workspace-state.timer` on the source-of-truth machine.

### `scripts/bootstrap-workspace.sh`
- **Direction:** tracked snapshot → live `~/Repositories/`
- Rsyncs the entire snapshot tree (excluding `repos.tsv`) into `~/Repositories/` — this is what populates non-repo files like `automation/CONTEXT.md` and `automation/memory/` on a fresh machine.
- Reads `repos.tsv` and clones any missing repos.
- For newly cloned repos, `setup_remotes()` renames `origin` → `local` and adds `home` (for localhost URLs), or renames `origin` → `hub` (for GitHub URLs).
- **Does NOT touch remotes on already-existing repos** — see "remote mirroring" below.

### `scripts/sync-workspace-repos.sh`
- **Direction:** keeps repo contents aligned over time.
- Uses `repos.tsv` to clone missing repos and fetch+fast-forward existing ones.
- Called from `sync-machine.sh --arrive` as the final step.

### Orchestrator: `scripts/sync-machine.sh --arrive`
1. Pull `nixos-config` (so latest scripts are present)
2. Run `bootstrap-workspace.sh` (restore non-repo files, clone missing repos)
3. Pull dotfiles / pass / zettelkasten
4. Rsync `~/Documents` and `~/Pictures` from NAS
5. Run `sync-workspace-repos.sh` (fetch all workspace repos)

---

## Why the user kept seeing "deleted" files in `git status`

The earlier `bootstrap-workspace.sh` only copied one-level-deep routing files (top-level + area-level). Anything deeper — `automation/memory/2026-03-29.md`, `school/research-paper-test/CONTEXT.md`, etc. — never made it onto the Framework. Meanwhile `export-workspace-state.sh` was capturing those files into the snapshot on the ThinkPad, so they appeared as "deleted" on the Framework's git status because the snapshot had them but the live tree didn't.

**Fix:** `restore_routing_files()` now does a single `rsync -a --exclude='repos.tsv' "${SNAPSHOT_ROOT}/" "${LIVE_ROOT}/"` — the whole tree, recursively. Committed to main.

---

## Remote mirroring — open design question

### Why this matters
On the ThinkPad each repo has been manually configured with the right combination of `local` / `home` / `hub` remotes. On the Framework, repos cloned by `bootstrap-workspace.sh` get only what `setup_remotes()` derives from the single URL in `repos.tsv`. So a repo that's `local + home + hub` on the ThinkPad ends up as just `local + home` on the Framework — and the user has to manually `git remote add hub …` on every push.

### Snapshot of actual ThinkPad state (2026-05-21)

| Repo | local | home | hub |
|------|-------|------|-----|
| automation/video-summary | ✓ | ✓ (uses `sweetpea-git:` SSH alias) | — |
| projects/agent-display | ✓ | ✓ | — |
| school/published-real-analysis-notes | ✓ | ✓ | ✓ |
| school/published-stats-notes | ✓ | ✓ | ✓ |
| self-hosted/zettelkasten | ✓ | ✓ | ✓ |
| self-hosted/llmfit | — | — | ✓ |

`repos.tsv` only carries one URL per repo — it cannot express this.

### Proposed design (not yet implemented — awaiting decision)
1. New file `tools/workspace/Repositories/remotes.tsv`, rows of `<relative_path>\t<remote_name>\t<remote_url>` — one row per remote.
2. Extend `export-workspace-state.sh` to emit each repo's `git remote -v` into `remotes.tsv`.
3. Extend `bootstrap-workspace.sh` to apply `remotes.tsv` after the clone-or-skip step, idempotently:
   - `git remote add <name> <url>` if missing
   - `git remote set-url <name> <url>` if URL differs
   - (Optional, opinionated) remove remotes not in `remotes.tsv` — needs explicit confirmation.

### Gotcha to handle
The `video-summary` repo's `home` remote uses an SSH alias (`git@sweetpea-git:...`) instead of the canonical `ssh://git@ssh.aaronjanovitch.com:2222/...` URL. Whatever the export captures gets replayed verbatim — so if the Framework lacks the alias in `~/.ssh/config`, `git fetch home` will fail despite the remote being "set up." Either normalize to the canonical form on the ThinkPad before exporting, or ensure SSH aliases are tracked in `~/.dotfiles`.

---

## Related fixes committed earlier in this session

- `seed-local-git-server.sh`: moved known_hosts from `/var/lib/git-seed/` (root-owned) to `~/.config/git-seed/` (user-writable). Avoids "Failed to add host to known_hosts" failures on the Framework.
- `bootstrap-new-machine.sh`: distfiles sync is now opt-in (was always-run).
- `repos.tsv`: added all homelab repos that were missing; `self-hosted/homelab/Raymer` intentionally uses `sweetpea-git:` SSH alias.

---

## Open items
- Decide whether to implement the `remotes.tsv` design above.
- Normalize the `sweetpea-git:` alias usage (or track the SSH config alias deliberately).
- Update `MANUAL-BOOTSTRAP.md` / `NEW-MACHINE-SETUP.md` with the refined flow once Framework is fully equivalent.
