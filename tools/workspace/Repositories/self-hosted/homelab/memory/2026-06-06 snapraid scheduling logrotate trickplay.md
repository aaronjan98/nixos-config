# 2026-06-06 — snapraid scheduling collision, logrotate, trickplay exclude

## What was worked on

Investigated a Pushbullet alert ("Unable to get SnapRAID status") fired by the
06:00 health monitor cron on 2026-06-06. Investigation proved last night's sync
itself was clean — the alert was a scheduling-collision artifact. Discovered
and fixed three follow-up issues in the process: a long-buggy scrub cron schedule,
missing logrotate config (logs were ~1 GB combined and unrotated since
2025-07-05), and trickplay thumbnail dirs hitting "Missing file" warnings during
scrub.

## Sequence of work

1. **Triage the 06:00 health-monitor alert**
   - Confirmed yesterday's 02:00 sync ran cleanly: 389 log lines, 32 KB,
     **0** `WARNING|Rerun` matches, completed 02:09:32 with `Everything OK`.
     The 06-05 postgres/redis excludes worked exactly as intended (huge win —
     this was the proof-of-fix moment).
   - The alert text was `Unable to get SnapRAID status`. Root cause: a `snapraid
     scrub` was running 03:00–07:00 today and holding the state lock; the 06:00
     health monitor's `snapraid status` call couldn't acquire it (snapraid
     serializes on the state file — only one operation at a time).
   - The aggregate sync log (`/var/log/snapraid-sync.log`, 127 MB) still showed
     the 336k/111k/392k `WARNING|Rerun` matches because it was cumulative since
     2025-07-05. Filtering to the **last-night window only** showed all zeros.
     Confirmed the metric we trust now is "per-run window," not "whole file."

2. **Root-cause the cron OR-gotcha**
   - User's root crontab had `0 3 1-7 * 7 /usr/local/bin/snapraid-scrub.sh`
     intended as "first Sunday of the month at 3 AM" (per the inline comment).
   - **Vixie cron OR's day-of-month and day-of-week when both are specified
     non-`*`** — so the job actually fires every day 1–7 of the month at 03:00
     **plus** every Sunday. Roughly 7–11 scrub runs per month instead of 1.
   - On 2026-06-06 (1st of month), today's scrub started at 03:00 and was still
     running at 06:00 when the health monitor tried to read status → alert.
   - Fix: changed to `0 3 1 * *` (1st of the month, 03:00 — `*` for DOW so cron
     doesn't apply the OR rule). Matches the original comment intent.

3. **Add trickplay exclude**
   - Cumulative scrub log had "Missing file" warnings against Jellyfin trickplay
     thumbnail dirs nested under `jellyfin/movies/<title>/<title>.trickplay/`
     and `jellyfin/shows/<show>/<Season>/<episode>.trickplay/`. Jellyfin
     regenerates these on demand, so they churn outside snapraid's window.
   - Appended `exclude *.trickplay/` to `/etc/snapraid.conf`. Unrooted pattern
     matches the dir name at any depth on any disk.

4. **Set up logrotate**
   - Pre-rotate sizes: `/var/log/snapraid-sync.log` 127 MB,
     `/var/log/snapraid-scrub.log` 446 MB, `/var/log/snapraid-health.log`
     1.7 MB, `/var/log/cron-scrub.log` 446 MB. None had ever rotated.
   - Wrote `/etc/logrotate.d/snapraid` covering all four logs: monthly, rotate
     6, compress+delaycompress, missingok, notifempty, `create 0644 root root`.
   - Hit `error: skipping ... because parent directory has insecure permissions`
     on dry-run. Ubuntu's `/var/log` is `root:syslog 775` — logrotate refuses
     to operate from a non-root group-writable parent by default. Fix:
     `su root syslog` directive **inside the logrotate config** (not on the
     filesystem). The directive tells logrotate to assume that uid/gid when
     accessing the parent, so the security check passes.
   - Force-rotated immediately: `sudo logrotate -vf /etc/logrotate.d/snapraid`.
     Recovered ~1 GB. New files start clean.

5. **Commit + push**
   - `~/qwerty-scripts/`: `snapraid/snapraid.conf` + new
     `snapraid/logrotate.snapraid` + `crontab/root.crontab` — committed as
     `1db4045` (amended once to include the crontab snapshot), pushed to
     `home/main`.
   - `/opt/arr-stack/docker-compose.yml` on arrs-vm: yesterday's hardlink
     restructure (PUID=114:121, single-bind pattern) had been left
     uncommitted. Committed as `4277568`, pushed to `home/main` (remote is
     `home`, not `origin` — `git push -u home main` to reset upstream).

## Key insights / lessons (durable)

1. **Vixie cron OR's DOM + DOW when both are non-`*`** — the most-bitten
   scheduling footgun in unix history. If you want "first Sunday of month,"
   either use `0 3 1-7 * 0 [ "$(date +\%u)" = 7 ] && cmd` (AND-via-shell
   guard) OR pick "1st of month" and live with whatever weekday it is. The
   inline comment lied for months because no one ran the schedule against the
   actual fire pattern.

2. **A health monitor that wraps another tool's lockable command will
   false-alarm during long operations.** Snapraid serializes status/sync/scrub
   on the state file. The 06:00 monitor fires once/month into a running
   scrub (now that scrub runs correctly — once instead of seven times). That's
   an acceptable false alarm; alternative is to wrap the monitor in `flock -n`
   and silently skip if locked, but the 06:00 collision is rare enough not
   to bother.

3. **Cumulative log metrics are useless for proof-of-fix.** When validating
   "did last night work?", always filter to the per-run window first (timestamp
   range or first/last "snapraid sync started" marker). I almost concluded
   the fix had failed because I grep'd against the cumulative file.

4. **Ubuntu `/var/log` group-write requires `su root syslog` in logrotate
   configs.** It's a config directive, not a filesystem change. Easy to misread
   the error as needing a chmod.

5. **`git remote` name isn't always `origin`.** The arr-stack remote is named
   `home`. Always `git remote -v` before pushing into someone else's
   repository conventions.

## Files touched on systems / commits made

- qwerty `/etc/snapraid.conf` — appended `exclude *.trickplay/` (plus 06-05's
  `/postgres/` and `/nextcloud/redis/` were already there).
- qwerty `/etc/logrotate.d/snapraid` — new file with `su root syslog` directive.
- qwerty root crontab — scrub line `0 3 1-7 * 7` → `0 3 1 * *`.
- qwerty `/var/log/snapraid-sync.log`, `/var/log/snapraid-scrub.log`,
  `/var/log/snapraid-health.log`, `/var/log/cron-scrub.log` — force-rotated;
  ~1 GB reclaimed.
- `~/qwerty-scripts` commit `1db4045` (amended), pushed to `home/main`.
- arrs-vm `/opt/arr-stack` commit `4277568` (yesterday's hardlink restructure),
  pushed to `home/main`.

## Open / next checks

- **2026-07-01 ~03:00** — first scheduled scrub run after the fix. Expect
  exactly one scrub that month (not 7–11). Skim `/var/log/cron-scrub.log` after
  the run to confirm a single entry, and check that `snapraid-health.log` for
  06:00 on 07-01 still shows the "Unable to get SnapRAID status" entry once
  (acceptable rare collision, see lesson #2).
- **Logrotate first cycle** — first monthly rotate fires on the dateset
  cron logrotate schedule (probably 01-of-next-month via `/etc/cron.daily/
  logrotate`). After that, `ls -la /var/log/snapraid-sync.log*` should show
  `.1`, `.2.gz`, etc.
- **Tonight 02:00 sync (2026-06-07)** — confirm `exclude *.trickplay/` didn't
  inadvertently exclude anything legitimate (very low risk — trickplay dirs
  are pure caches).
