# 2026-06-03 — Audio-swap cron recovery + SnapRAID 392k-error diagnosis

Morning session. Two findings from overnight, both blast-radius limited, neither caused data loss.

## What was worked on

1. **Overnight cron audit.** The 03:00 `audio-swap-nightly.sh` cron fired but failed disastrously: every single one of the 746 remaining worklist items got marked FAILED in 1 second. Investigated, root-caused, recovered, hardened.
2. **SnapRAID 392,490 file errors.** Initially looked alarming (3000× more than the prior night's 13). Turned out to be one file in a tight loop, fully benign.

## Root cause — cron cascade

- 02:00:01 — SnapRAID sync started (root cron), stopped Jellyfin as part of its outage window.
- 02:00 → 03:04:10 — sync ran for **64 minutes** instead of the usual ~10–15. The slowdown was caused by qBittorrent writing to an in-progress download (`/mnt/data3/downloads/incomplete/shows/The.Blacklist.S05.../the.blacklist.s05e10.1080p.bluray.x264-rovers.mkv`) — SnapRAID's "Unexpected time change at file..." retry loop fired ~196K times against that single file, generating the 392,490-error count.
- 03:00:01 — `audio-swap-nightly.sh` fired *during* the SnapRAID window. Jellyfin was still stopped.
- 03:00:37–38 — script blasted through the worklist. Every `docker exec jellyfin` returned `Error response from daemon: container ... is not running` (exit code 1). The script's failure handler interpreted rc≠0 as a real ffmpeg failure and appended each path to `failed.txt`. 746 items flipped to permanent-fail in 1 second.
- 03:04:10 — SnapRAID finished, restarted Jellyfin (healthy by 03:04:42).

## Key insights

- **The script had a confounding-failure bug.** It treated a transient infrastructure error (Docker reports container down) identically to a real workload error (ffmpeg returned non-zero). One failure mode shouldn't be allowed to permanently poison a denylist that the script consults forever after. Lesson: **infrastructure preconditions need to be checked before the workload runs, and again before any failure is committed to durable state.**
- **The mergerfs HDD-contention pattern is now visible at the cron-orchestration layer too.** Heavy I/O (qBittorrent random writes to in-progress downloads) on the same disks SnapRAID is hashing extends sync time non-linearly because SnapRAID retries each changed file. The bigger storage lesson from yesterday (don't mix heavy I/O on the same spindles) recurs here in a different shape.
- **`downloads/incomplete/` has no parity-protection value.** Snapraid should be excluding it. The 13 errors on 2026-06-02 and the 392,490 on 2026-06-03 are the *same class* of warning — just amplified by how long the file was being written to during the sync window.
- **The pre-existing 2 historical FAILs (S06E01 retries from 2026-06-02 morning) had already been cleaned from `failed.txt` before today** — confirmed by line count (746 = exactly today's batch, no leftover entries). Means truncating `failed.txt` was safe.
- **86 GB of stale `.remux.mkv` files** discovered in `/mnt/storage/jellyfin/movies/` (Oppenheimer, HSM 2, HSM 3) from 2026-06-02 morning's smoke tests. Originals untouched (mtimes from 2025), so these are partial outputs from interrupted runs. Next nightly will overwrite them via ffmpeg's `-y`.

## What was applied today

- **Recovery**: backed up `failed.txt` to `failed.txt.bak.20260603-pre-recovery`, truncated `failed.txt` to zero. 746 items returned to the queue.
- **Script hardening** (saved old version at `audio-swap-nightly.sh.bak.20260603-pre-pollwait`):
    - Added `jellyfin_running()` predicate using `docker inspect -f '{{.State.Status}}'`.
    - Added `wait_for_jellyfin()` poll-wait function: 30-second intervals, respects the existing 06:30 STOP cutoff, exits cleanly (no FAILED marks) if Jellyfin never comes up.
    - Mid-loop guard: checks `jellyfin_running` before every `docker exec ffmpeg` and on rc≠0 — if container disappears, `break` out of the loop instead of marking items FAILED.
    - Updated header comment "2 AM" → "3 AM" to match the cron.
- **qwerty.md updates** (durable only — no incident narrative):
    - "Gotchas" subsection in Audio-swap pipeline now mentions the poll-wait + mid-loop guards as the steady-state behavior.
    - Known-gaps row for SnapRAID rewritten: was "13 file errors should investigate" → now "exclude `**/downloads/incomplete/**` in snapraid.conf, here's why."

## Open questions / follow-ups

- **SnapRAID `exclude /downloads/incomplete/` — APPLIED later in this session** (backup at `/etc/snapraid.conf.bak.20260603`). `snapraid status` confirms config parses; `snapraid diff` shows existing tracked `incomplete/` entries flagged as `move`/`add` (will clear on next sync), and no new in-progress writes being indexed. Tonight's 02:00 sync should run clean — no more 392k-warning retry storms.
- **Manual audio-swap validation run — COMPLETED later in this session.** Fired with `STOP_HOUR=7 STOP_MIN=45`. Jellyfin was up → poll-wait short-circuited (no WAIT_OK log; expected). Processed 2 movies: Two Towers (79 GB → 62 GB, ~10:42) + Eternal Sunshine (75 GB → 69 GB, ~32 min). STOP fired correctly between items, END processed=2 remaining=744, failed=0. Happy-path validated end-to-end; the poll-wait / mid-loop guards weren't exercised today (no container outage to recover from) but the structural path is in place.
- **The 86 GB of stale `.remux.mkv` files.** Could either delete them by hand or let the next nightly run overwrite via `-y`. Letting the nightly handle it means 86 GB of waste persists for up to ~5 weeks until those three movies come up in the worklist. A 30-second `find … -name '*.remux.mkv' -delete` would reclaim it now, but should be done with confirmation per file (they're large).
- **Watch tomorrow's run.** With the SnapRAID exclude now in place, sync should complete in the usual ~10–15 min and finish well before 03:00, so audio-swap should see Jellyfin already running (no WAIT_OK). Validate: `grep "WAIT_OK\|WAIT_ABORT\|ABORT\|END" /home/aj/scripts/audio-swap/run.log` should show a clean END line with non-zero processed count.
- **`snapraid touch`** — `snapraid status` flagged 16,576 files with zero sub-second timestamps. Low priority, not blocking anything; run when convenient.

## Files touched this session

- `/home/aj/scripts/audio-swap-nightly.sh` — added poll-wait + mid-loop guards (backup at `.bak.20260603-pre-pollwait`)
- `/home/aj/scripts/audio-swap/failed.txt` — truncated from 746 → 0 (backup at `.bak.20260603-pre-recovery`)
- `Raymer/docs/qwerty.md` — durable-only changes (poll-wait note in audio-swap section, snapraid Known-gaps row rewritten)

Not touched: SnapRAID config, the 86 GB of stale `.remux.mkv` files.
