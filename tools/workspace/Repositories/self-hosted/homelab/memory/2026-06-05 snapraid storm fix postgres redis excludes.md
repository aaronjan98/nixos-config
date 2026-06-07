# 2026-06-05 — snapraid sync storm root-caused & fixed

## What was worked on

Investigated and eliminated the snapraid sync warning storm that had grown progressively worse over the last 3 daily cron runs (06-03 ~65 min, 06-04 ~65 min, 06-05 **128 min** with 392k+ "Rerun" + 336k+ "WARNING! You cannot modify files during a sync" lines).

Original hypothesis (from 06-04 memory note): `/downloads/incomplete/` churn from qbittorrent was the storm source, and `exclude /downloads/incomplete/` added to `/etc/snapraid.conf` on 06-03 08:05 should have fixed it but didn't. Today's investigation proved that hypothesis only-partially-right and uncovered the actual root cause.

## Sequence of work

1. **Inspect overnight cron outputs (06-05 02:00 sync + 06:35 audio-swap)**
   - Audio-swap clean (14 processed, STOP at cutoff).
   - Snapraid sync: 128 min wall time, 21 final file errors, warning storm visible in syslog.
   - The new finding: storm lines were dominated by `/mnt/data1/postgres/nextcloud/base/16384/2619` etc., **NOT** by `/downloads/incomplete/` paths. Nextcloud's postgres + redis were the actual loudest writers all along — qbittorrent was just additive noise.

2. **Plan A: one-shot purge with qbt stopped (script v1)**
   - Stopped qbt on arrs-vm, ran `snapraid sync` in foreground on qwerty.
   - Storm continued (postgres + redis writers active). Sync went to 8% / 1:00 ETA before…
   - User ctrl+c'd. Parity uncorrupted (snapraid handles interrupts cleanly).

3. **Plan B: stop nextcloud writers + add postgres/redis excludes (script v2)**
   - Discovered + stopped: postgres-nextcloud, redis-nextcloud, nextcloud-fpm, nextcloud-web, immich_postgres, immich_redis (immich grep-caught — fine, same issue). Talk (nextcloud/aio-talk) wasn't stopped (image-name match only, container name didn't contain match keywords).
   - Verified 0 writers on `/mnt/data1/postgres`, `/mnt/data3/nextcloud/redis`, `/mnt/storage/downloads`.
   - Sync started clean — at 0% / 488 MB/s / 0:59 ETA when tmux pane unexpectedly closed and killed the ssh, killing the sync. No corruption (pre-sync state preserved).

4. **Plan C: detached tmux session on qwerty itself**
   - Switched to running sync inside `tmux new-session -d -s sync` on qwerty (not over ssh-pipe-tee from local).
   - Hit a buffering issue: with `sudo snapraid sync | tee $LOG` and `tmux -d`, the sudo password prompt was waiting silently inside the detached pane — sudo's `tty_tickets` cache is per-pty, so the cache primed from interactive `sudo -v` didn't apply.
   - Resolved via `tmux switch-client -t sync`, typed password manually, detached with `Ctrl+B D`.
   - Sync completed clean: **`Everything OK`, 1207 MB accessed, no warnings**.

5. **Snapraid.conf changes applied**
   ```
   exclude /postgres/
   exclude /nextcloud/redis/
   ```
   Pre-existing context: the conf already had ~13 narrow postgres excludes (pg_stat_tmp, pg_wal, pg_log, pg_xlog, pg_replslot, etc.) — whoever set it up knew postgres needed exclusion but missed the `base/*/N` heap files where the actual table data lives. The new broad `/postgres/` line catches everything inside the postgres data dir, including the heaps.

6. **Container recovery**
   - Restarted in dependency order: DBs/caches → fpm → nginx.
   - All 11 containers up and healthy as of 09:54.

## Key insights / lessons (durable)

1. **Mutable databases must NOT be in snapraid parity** — narrow excludes for postgres WAL/log/temp dirs are insufficient; the heap files in `base/<oid>/<relfilenode>` change on every transaction and produce the same warning storm. The right fix is a broad `exclude /postgres/` AND a separate backup strategy (pg_dump → parity-protected location). Same applies to redis dump.rdb. **Generalized lesson** — same family as the hardlink case: avoid generating I/O that didn't need to happen.

2. **Snapraid exclude rules block new additions but the storm shape depends on what's already tracked** — adding the exclude doesn't immediately purge previously-tracked files; only a clean sync with no writers will remove them from parity. This is why 06-04's exclude addition didn't fix anything on 06-05.

3. **sudo + ssh + non-interactive = silent failure** — every time you pipe a heredoc/scp through `ssh aj@host 'sudo ...'` without `-t`, sudo errors with "a terminal is required" and the surrounding `set -e` won't catch it because the ssh exit is 0 (the failing sub-command is gated by `&&`). Always use `ssh -t` for sudo, OR run sudo commands from a shell that's already on the target.

4. **sudo `tty_tickets` defeats `sudo -v` across ptys** — `sudo -v` primes the cache for the calling tty only. A subsequently-created tmux pane has a fresh pty and gets no cache, so detached `tmux new -d -s X "sudo …"` will silently wait at a password prompt with no obvious indication.

5. **tee block-buffers when stdout isn't a tty** — long-running pipelines like `cmd | tee log` will write to the log in 8K/64K chunks (or not at all) when run detached, making `tail -f` useless for progress monitoring. Use `tmux capture-pane -p -t <session>` to see what the pane actually contains, or `stdbuf -oL` on the producer.

6. **For long-running root operations: run them inside a tmux session ON THE TARGET MACHINE** — not over an ssh-pipe-tee. Survives any local disconnect, gives you a real tty for sudo, and avoids buffering games.

## Open / next checks

- **Tonight (2026-06-06 02:00) cron snapraid sync** is the real proof-of-fix — that's the first sync with writers actively churning AND the new excludes in place. Pass criteria: wall time ~11–15 min, `0` grep matches for `WARNING|Rerun`, final `Everything OK` or `Nothing to do`.
- **Hardlink validation in production**: user is adding "Off Campus" via Sonarr right now (release grabbed: `Off.Campus.S01.Complete.1080p.WEBRip.10Bit.DDP5.1.x265-NeoNoir` from The Pirate Bay). After import completes, check `docker logs --since 10m sonarr | grep -iE "Hardlink|Copying"` — want `Hardlinked file`, not `Copying file`.
- **`/downloads/incomplete/` stale orphans** from Aug–Sep 2025: Jurassic World Dominion, Rush Hour (1998).mkv (21 GB), Rush Hour 2, Pair of Kings S01, Jurassic World Fallen Kingdom REMUX BD3D, plus empty `movies/`, `music/`, `shows/`, `tv/` placeholder dirs. Backburner cleanup. Currently excluded from snapraid so they don't cause active harm.
- **Stale tmux session on qwerty**: a `snapraid` session from 2026-05-19 21:42 is still there. Probably orphaned from an earlier interactive run. Worth `tmux kill-session -t snapraid` after confirming nothing important is in it.
- **immich_machine_learning healthcheck** previously flapping — user said "we can ignore" on 06-04. Still flagged Accepted in qwerty.md.

## Files touched on qwerty / system state

- `/etc/snapraid.conf` — appended `exclude /postgres/` + `exclude /nextcloud/redis/`. Backup at `/etc/snapraid.conf.bak.20260605-<HHMMSS>`.
- Clean sync log: `/tmp/snapraid-sync-20260605-0933.log` on qwerty (`Everything OK`, 1207 MB accessed).
- Containers restarted: postgres-nextcloud, redis-nextcloud, nextcloud-fpm, nextcloud-web, immich_postgres, immich_redis.
