# 2026-06-04 — Hardlink restructure for arr stack on arrs-vm

Long focused session. Goal: enable Sonarr/Radarr "Use Hardlinks instead of Copy" by unifying the NFS mount surface and uid namespace on arrs-vm, so cross-disk copy imports stop hammering qwerty's mergerfs HDDs during arr-stack moves.

## Morning check-in

- **Overnight audio-swap cron (3 AM) ran clean.** WAIT_OK fired after ~270 s of poll-wait (because the snapraid sync window now ends earlier with the `exclude /downloads/incomplete/` from 2026-06-03 in effect). 16 movies processed, 0 failures. End-of-window stats: processed=16, remaining=728, failed=0. This validates yesterday's hardening end-to-end in production — the poll-wait + mid-loop guards worked exactly as designed.
- **Overnight snapraid sync ran clean.** 14 file errors (same baseline as 2026-06-02 nights, down from 2026-06-03's 392,490 storm). Sync wall time ~4 min, services restarted by 03:04:56. The `exclude /downloads/incomplete/` did exactly what was predicted.
- Decided to push on the next backburner item: Sonarr/Radarr hardlink toggle.

## Why hardlinks matter

Without hardlinks, every Sonarr/Radarr import is a full read-then-write across the mergerfs HDD pool — even when source and dest are on the same physical disk. Same head-contention failure mode as the Jellyfin transcode case from 2026-06-02 ([[HDD head contention]]). With hardlinks, the import is a single metadata op (link inode); zero bytes move; the disk head doesn't budge.

Prerequisites for arr hardlinks to work over NFS:
1. Source and dest must live under a **single client mount** with the same `st_dev` (Linux `link()` returns EXDEV otherwise).
2. Underlying server filesystem must support hardlinks across the involved paths (mergerfs does, within a branch).
3. The arr container's uid must be allowed to `link()` the source file — which means either owning it or satisfying `fs.protected_hardlinks`.

## Plan (12 steps)

0. Re-establish SSH host trust with arrs-vm (host key changed; benign — VM reprovision/libvirt regen).
1. Inventory current bind mounts in `/opt/arr-stack/docker-compose.yml`.
2. Back up compose + fstab on arrs-vm.
3. `docker compose stop -t 30` arrs stack (graceful shutdown protects qbt state).
4. Switch arrs-vm `/etc/fstab` from 5 per-dir NFS mounts to a single `10.0.50.83:/mnt/storage → /mnt/nas`; verify all subdirs share `st_dev`.
5. Fix NFS uid passthrough so containers can write to media dirs.
6. Edit compose: update radarr/sonarr/bazarr paths; change qbittorrent PUID/PGID.
7. Chown affected dirs to 114:121.
8. `docker compose up -d` + verify.
9. Toggle "Use Hardlinks instead of Copy" in Sonarr UI.
10. Toggle in Radarr UI.
11. Smoke test (manual import while watching `iostat -x 1` on qwerty: hardlink success = 0 write activity).
12. Document outcome.

## Steps 0–4: completed

- SSH host key rotated for arrs-vm (ssh-keygen -R + accept new fingerprint).
- Inventoried compose bind mounts (radarr/sonarr/bazarr point at `/mnt/nas/movies` and `/mnt/nas/tv`; need to become `/mnt/nas/jellyfin/movies` and `/mnt/nas/jellyfin/shows`).
- Compose backup: `/opt/arr-stack/docker-compose.yml.bak.20260604-pre-hardlink`.
- Fstab backup: `/etc/fstab.bak.20260604-pre-hardlink`.
- Stopped stack with `docker compose stop -t 30` (graceful).
- Replaced 5 per-dir NFS mounts in `/etc/fstab` with one unified mount:
  ```
  10.0.50.83:/mnt/storage  /mnt/nas  nfs  defaults,nofail,x-systemd.after=network-online.target,x-systemd.wants=network-online.target,vers=3  0 0
  ```
- Verified `st_dev=45` (decimal) for `/mnt/nas`, `/mnt/nas/downloads`, `/mnt/nas/jellyfin/movies`, `/mnt/nas/jellyfin/shows` — hardlink prerequisite met at NFS layer.

## Step 5: NFS uid passthrough — three iterations

### Iteration 1 (wrong): added 192.168.30.40-specific export on qwerty

Initial theory: the parent `/mnt/storage` export had `all_squash,anonuid=1000`, so all writes from arrs-vm were getting squashed to uid 1000. Wanted to add a more-specific entry for arrs-vm's IP with `no_all_squash,no_root_squash`.

Edited `/etc/exports` on qwerty (backup at `/etc/exports.bak.20260604-pre-hardlink`):
```
/mnt/storage 192.168.30.40(rw,sync,no_subtree_check,insecure,fsid=0,crossmnt,no_root_squash,no_all_squash) \
             192.168.30.0/24(...all_squash,anonuid=1000) \
             10.0.50.0/24(...all_squash,anonuid=1000)
```

First attempt put each client spec on its own line — wrong. NFS requires all client specs for one path on a single line separated by spaces. Got `exportfs: Failed to stat 192.168.30.0/24(...)` errors. Fixed by joining all three onto one line.

`exportfs -v` then showed all three entries active. But the uid-114 write test STILL failed:
```
docker run --rm -u 114:121 -v /mnt/nas:/mnt/nas alpine touch /mnt/nas/jellyfin/movies/test
→ touch: test: Permission denied
```

### Iteration 2 (right): replaced 192.168.30.40 with sweetpea SNAT IP 10.0.50.47

A parallel AI flagged that qwerty actually sees NFS connections from `10.0.50.47` (sweetpea SNATs cross-VLAN traffic), not from `192.168.30.40`. Confirmed empirically: `ss -tn state established sport = :2049` on qwerty showed `10.0.50.83:2049 ← 10.0.50.47:946`. Documented in `Raymer/docs/arrs-vm.md`.

Changed the host spec from `192.168.30.40` to `10.0.50.47`. After `exportfs -ra`:
```
docker run --rm -u 114:121 ... touch /mnt/nas/jellyfin/movies/test-perms-114.tmp
→ -rw-r--r-- 1 114 121 ... /mnt/nas/jellyfin/movies/test-perms-114.tmp
MOVIES_OK; SHOWS_OK
touch /mnt/nas/downloads/test-perms-114.tmp
→ Permission denied
```

Movies/shows OK (uid 114 preserved). Downloads still denied — because `/mnt/storage/downloads` is owned `1000:1000` mode `755`, so uid 114 has no write bit there.

### Iteration 3: hardlink attempt as uid 114 → EPERM, not EACCES

Tried the actual workflow (hardlink from /downloads to /jellyfin/shows):
```
ln "/mnt/nas/downloads/Gen V/Season 2/Gen V - S02E01....mkv" /mnt/nas/jellyfin/shows/test-hardlink-114.tmp
→ Operation not permitted (EPERM, not EACCES)
```

Different error class. The kernel's `fs.protected_hardlinks=1` sysctl blocks the link: linker (uid 114) doesn't own the source (uid 1000) and doesn't have write access (mode 644). Confirmed `sudo sysctl fs.protected_hardlinks` returned `1` on arrs-vm.

This is the kernel-level hardening flag (Linux protected_hardlinks(7)), default on most distros. We can't just relax NFS export options to fix it — the check happens client-side in the linker's kernel before any NFS RPC fires.

## Decision: Path A — unify uid namespace

Two paths considered:

- **Path A**: chown `/mnt/storage/downloads` to 114:121 on qwerty + chown qBittorrent's config dir on arrs-vm + flip qBittorrent's PUID/PGID to 114:121. Result: all arr-stack-managed files owned by the same uid; hardlinks work natively; no kernel-hardening regression. Reversible by re-chowning back to 1000.
- **Path B**: disable `fs.protected_hardlinks` on arrs-vm via sysctl. Fast but mild security regression and goes against kernel-hardening best practice. arrs-vm has no untrusted users so the actual risk is theoretical, but it's tech debt either way.

Picked Path A.

## Step 6–8: chown + compose rewrite + restart

### Step 7a — chown downloads on qwerty (instant, not slow)

```sh
sudo chown -R 114:121 /mnt/storage/downloads
```

Suspiciously instant for 4.1 TB — turned out `find … | wc -l` reports only **6,473 inodes** (the 4.1 TB is concentrated in large media files). Chown is metadata-only, so 6.5k inodes through cached metadata is sub-second.

Pre-chown there was one quirky entry: `/mnt/storage/downloads/(2025)` owned by `root:root` from some early misconfiguration. Recursive chown swept it up.

### Step 7b — chown qbittorrent config on arrs-vm

```sh
sudo chown -R 114:121 /opt/arr-stack/qbittorrent
```

64 MB, instant.

### Step 6 (first attempt) — qbt PUID/PGID + path rename

First compose edit:
- qbittorrent `PUID/PGID: 1000/1000 → 114/121`.
- radarr `/mnt/nas/movies:/movies → /mnt/nas/jellyfin/movies:/movies`.
- sonarr `/mnt/nas/tv:/shows → /mnt/nas/jellyfin/shows:/shows`.
- bazarr both paths updated similarly.

`docker compose up -d` cycled all five containers (gluetun stayed up, seerr/flaresolverr/prowlarr untouched). Containers came up healthy in ~10 s; gluetun healthcheck passed; qbt webui port 8081 served correctly.

### Discovery — docker bind-mounts of NFS subpaths re-mount as fresh NFS shares

Tried a hardlink test:
```sh
docker exec -u abc sonarr ln /downloads/foo.mkv /shows/bar.tmp
→ failed to create hard link: Cross-device link
```

But `stat -c %d /downloads /shows` reported the same st_dev (45) for both! Investigated `mountinfo`:
```
1139 1129 0:45 / /shows rw,relatime - nfs 10.0.50.83:/mnt/storage/jellyfin/shows ...
1140 1129 0:45 / /downloads rw,relatime - nfs 10.0.50.83:/mnt/storage/downloads ...
```

Two **separate NFS mounts** inside the container, both with the same anonymous bdev (0:45) but distinct superblocks. Docker doesn't truly bind-mount sub-paths of an NFS share from the host — it issues a fresh NFS mount of the sub-path inside the container namespace. `link()` checks superblock equality (`inode->i_sb != dir->i_sb`), not just `st_dev`, so the call returns EXDEV.

Confirmed with a single-bind POC: `docker run -v /mnt/nas:/data` produces ONE NFS mount of `10.0.50.83:/mnt/storage` at `/data`, all subdirs share superblock, hardlink succeeds.

### Step 6 (second attempt) — symlink-redirect approach

Two options to give the arr containers a single underlying NFS mount:

- **Proper `/data` layout** (TRaSH-recommended): bind `/mnt/nas:/data`, then reconfigure each app's root folders (`/shows → /data/jellyfin/shows`, etc.) plus bulk-relocate the 190 series / 569 movies in each DB. Most disruption.
- **Symlink redirect** (chosen): bind `/mnt/nas:/data`, override the linuxserver `/init` entrypoint with `sh -c "ln -sfn /data/... /shows && ln -sfn /data/... /downloads && exec /init"`. App DB unchanged. Kernel resolves the symlinks during pathname lookup, both resolve into the single `/data` mount, hardlink succeeds.

Symlink redirect chosen for minimum disruption and full reversibility.

Final compose pattern for each of qbittorrent, radarr, sonarr, bazarr, lidarr:
```yaml
entrypoint:
  - /bin/sh
  - -c
  - "ln -sfn /data/downloads /downloads && ln -sfn /data/jellyfin/shows /shows && exec /init"
volumes:
  - ./<service>:/config
  - /mnt/nas:/data
```

(Symlink targets per service: qbt = `/downloads`; radarr = `/downloads + /movies`; sonarr = `/downloads + /shows`; bazarr = `/movies + /tv`; lidarr = `/downloads + /music`.)

Verified post-restart:
- All containers up healthy.
- All symlinks present and pointing where expected.
- Single `/data` NFS mount in each container's mountinfo.
- `ln /downloads/foo.mkv /shows/bar.tmp` as uid 114 inside sonarr: `ln_exit=0`, same inode (10781307003015247370), both paths see the file as 114:121.
- Same test inside radarr: `ln_exit=0`, same inode (16387537549088819973).
- bazarr writes to /movies and /tv succeed as uid 114.
- qbt writes to /downloads as `abc` (uid 114) succeed.
- Sonarr API: 190 series intact. Radarr API: 569 movies intact. qbt: 24 torrents tracked.
- `copyUsingHardlinks: true` was **already set** in both Sonarr and Radarr — the setting was enabled all along, the kernel was silently rejecting link() with EXDEV and falling back to copy. Now link() succeeds, so hardlinks will be used on every future import. No UI toggle needed.

### Transient noise post-restart (resolved on its own)

- Sonarr/Radarr logged `Connection refused (gluetun:8080)` once at 09:48 — qbt was being recreated mid-rolling-restart. wget through gluetun returned HTML within seconds.
- Prowlarr 429.TooManyRequests warnings during the restart window — indexer disable timers from the connection churn. Cleared shortly after.

## Step 9–10: Use Hardlinks toggles

**Not needed.** Both Sonarr and Radarr already had `copyUsingHardlinks: true` from prior setup. The work was entirely at the mount/uid layer.

## Step 11: smoke test outcome

The kernel-level hardlink validation from inside both sonarr and radarr containers was the smoke test (same-inode confirmation across `/downloads` ↔ `/shows` and `/downloads` ↔ `/movies`). Next real arr-stack import will exercise the path end-to-end through the apps' own code; no further action needed to enable it.

## Outstanding issues

- ~~**lidarr → /music returned "Permission denied"** for uid 114 writes.~~ **Resolved later same session.** Ran `sudo chown -R 114:121 /mnt/storage/music` on qwerty; find for any non-114-owned files returned empty. Then verified `ln /data/music/.lnprobe /data/downloads/.lnprobe.link` inside the lidarr container: `ln_exit=0`, same inode `16574162041665018001` on both sides. Lidarr is now hardlink-capable end-to-end.
- **mergerfs branch-spanning hardlinks**: even with all our fixes, a hardlink only succeeds when source and destination land on the *same physical disk* of the mergerfs pool. If qBittorrent saved a torrent on `/mnt/data2` and Sonarr's target series dir lives on `/mnt/data1`, mergerfs returns EXDEV and the arr falls back to copy. This is expected and graceful (no breakage), just means some files still copy. The mfs (most-free-space) placement policy tends to keep related files together, so most hardlinks should succeed. Monitor proportion of fall-throughs in arr logs over time.

## Key insights (additions)

- **`stat -c %d` matching is not sufficient to predict `link()` success.** Two mounts with the same anonymous bdev can still have distinct superblocks. The kernel checks `inode->i_sb != dir->i_sb` in `vfs_link()`, not `st_dev`. The right diagnostic is to read `/proc/self/mountinfo` and see whether two paths fall under the same mount entry (same mount ID + same source).
- **Docker handles NFS bind mounts by re-mounting the sub-path inside the container's namespace, not by bind-propagating the host mount.** This is invisible from `docker inspect` but obvious in container mountinfo. The implication: any container using two sub-paths of a single NFS share will see them as separate mounts and hardlinks across them will fail with EXDEV. The fix is to bind-mount the *parent* once.
- **Symlinks defeat the docker NFS-remount behavior because pathname lookup resolves them before the link() syscall.** This makes "single-bind + symlinks back to old container paths" a viable zero-DB-change strategy for arr stacks that originally had per-dir mounts.
- **linuxserver/* images' `/init` accepts an entrypoint wrapper.** `entrypoint: [sh, -c, "<setup> && exec /init"]` works cleanly. s6-overlay starts normally after the wrapper exec's into /init.
- **`copyUsingHardlinks: true` being silently ineffective is the worst kind of bug** — the setting was on, the user could see it on, and yet no hardlinks were happening because the kernel was rejecting them at the syscall layer. The fix produces no visible change in the UI but a structural change in I/O behavior. Worth remembering as a debugging pattern: when a "use feature X" toggle is on but observed behavior doesn't match, suspect a lower-layer rejection.

## Files touched this session

- `/home/aj/Repositories/self-hosted/homelab/memory/2026-06-04 hardlink restructure for arr stack.md` — this note.
- `arrs-vm:/etc/fstab` — replaced 5 per-dir NFS mounts with single unified `/mnt/storage → /mnt/nas` mount (backup at `.bak.20260604-pre-hardlink`).
- `arrs-vm:/opt/arr-stack/docker-compose.yml` — qbt PUID/PGID change + 5 services migrated to single `/mnt/nas:/data` mount with entrypoint-symlink setup (backup at `.bak.20260604-pre-hardlink`).
- `arrs-vm:/opt/arr-stack/qbittorrent/` — chowned 114:121.
- `qwerty:/etc/exports` — added `10.0.50.47` host-specific entry on parent `/mnt/storage` with `no_root_squash,no_all_squash` (backup at `/etc/exports.bak.20260604-pre-hardlink`).
- `qwerty:/mnt/storage/downloads` — chowned 114:121 (entire tree, 6,473 inodes / 4.1 TB).
- `qwerty:/mnt/storage/music` — chowned 114:121 (lidarr unblock).
- `Raymer/docs/arrs-vm.md` — collapsed 5-row per-dir NFS table → single `/mnt/nas` row; added "Host-specific carve-out for 10.0.50.47" callout; added new "Hardlinks & the single-parent bind pattern" subsection with symlink table + EXDEV explanation; PUID/PGID section now lists qbt as 114:121; media pipeline diagram updated to `/data/...` paths.
- `Raymer/docs/qwerty.md` — added 10.0.50.47 row to NFS exports table; rewrote "Why movies/shows/music are unsquashed" to cover the unified pipeline + `fs.protected_hardlinks` + HDD-contention reasoning; removed the resolved "Use Hardlinks instead of Copy" Known-gaps row.

## Reversibility

Fully reversible if needed:
- `qwerty:/etc/exports` — restore from `.bak.20260604-pre-hardlink`, `sudo exportfs -ra`.
- `arrs-vm:/etc/fstab` — restore from `.bak.20260604-pre-hardlink`, `sudo systemctl daemon-reload && sudo umount /mnt/nas && sudo mount -a`.
- `arrs-vm:/opt/arr-stack/docker-compose.yml` — restore from `.bak.20260604-pre-hardlink`, `docker compose up -d`.
- `qwerty:/mnt/storage/downloads` chown — `sudo chown -R 1000:1000 /mnt/storage/downloads`.

The arr apps' DBs were never touched, so no Sonarr/Radarr DB rollback needed.

## Next steps (when AJ returns)

**Check after the next overnight cron cycle (2 AM snapraid + 3 AM audio-swap on 2026-06-05):**
- Verify the unified `/mnt/nas:/data` mount survived a reboot/remount cycle cleanly (no container stuck on empty local inode — see "Bind-mount ordering gotcha" in `Raymer/docs/arrs-vm.md`).
- Inspect overnight snapraid output for any new "Unexpected time change" warnings against the `/mnt/storage/downloads` tree now that it's 114:121 instead of 1000:1000 (chowns bump ctime; a single sync after chown should absorb them — flag only if they persist beyond tomorrow morning's run).
- Skim sonarr/radarr/lidarr logs for `Hardlinked file` vs `Copying file` ratio on whatever imported overnight. The first morning after enabling the structural fix is the cleanest signal we'll get.

**Other carry-overs:**
- ~~Add `/etc/exports` to the `qwerty-scripts` repo~~ **done 2026-06-04 EOD** — created `qwerty-scripts/nfs/exports` (chowned to `aj:aj` so future edits don't need sudo to stage), extended `qwerty-scripts/README.md` with a `## nfs/` section matching the snapraid/audio-swap/bridge pattern (edit workflow + restore block + callout for the 10.0.50.47 carve-out). Committed + pushed to `sweetpea:/srv/git/repos/qwerty-scripts.git`. Tonight's hardlink-support export changes are now backed up off the OS disk.
- ~~Stale `.remux.mkv` cleanup~~ **done 2026-06-04 EOD** — removed 3 orphan `.remux.mkv` files (HSM 1/2/3, total ~64.5 GB — not the ~48 GB the earlier session estimated) plus 42 metadata sidecars (`.remux.nfo`, `.remux-*.jpg/png`) that Jellyfin downloaded during the brief window when each `.remux.mkv` existed mid-audio-swap. Surface area was wider than expected: 10 movies had orphan sidecars (Avatar, Eternal Sunshine, Reservoir Dogs, Titanic, Die Hard, Meet Joe Black, Oppenheimer, Terminator Dark Fate, What Happened to Monday + the 3 HSM titles that still had the .mkv too). The 3 HSM .mkv files will get retried by audio-swap on a future nightly run since they were never marked done in `done.txt`. Jellyfin library rescan needed to prune phantom entries.
- ~~snapraid `touch`~~ **done 2026-06-04 EOD** — `snapraid status` reported 16,592 zero-subsecond files (vs the 16,576 estimated), all immich uploads under `/mnt/data1/immich/immich/upload/d386f7e1-…/`. Ran `sudo snapraid touch`, all 16,592 files set to non-zero sub-second mtimes, content state re-saved + verified on parity and data1 (3 sec each). Post-run `snapraid status` reports "No file has a zero sub-second timestamp." Tonight's 02:00 sync should be much quieter as a result.

### Lesson added to qwerty.md "Top lesson" banner
Extended the banner to call out the arr-stack hardlink case as a **third surface** of the HDD-head-contention lesson. Generalised form: HDD head contention can also be caused by I/O that *didn't need to happen at all* — audit "moves" that are secretly copy+delete on the same filesystem.

## Key insights so far

- **crossmnt + parent squash overrides sub-export squash.** Empirically verified: when accessed via the unified parent mount (`/mnt/storage`), the parent export's `all_squash,anonuid=1000` applies even when sub-paths have their own export entries with `no_all_squash`. Sub-export options only take effect when the sub-path is mounted directly. This is contrary to how I'd naively expect crossmnt to work and is the trap that ate iteration 1.
- **Sweetpea's SNAT changes the apparent client IP on the NFS server.** Cross-VLAN NFS clients show up as `10.0.50.47` (sweetpea) at qwerty, not their real VLAN-30 IP. Any IP-specific NFS export rule for arrs-vm must target `10.0.50.47`, not `192.168.30.40`. This was already documented in `Raymer/docs/arrs-vm.md` but easy to miss when writing export rules.
- **EPERM vs EACCES on `link()` is the diagnostic signal.** EACCES means perms/ownership mismatch (fixable with chmod/chown). EPERM means a *policy* check rejected the call — most commonly `fs.protected_hardlinks` or a privileged-op check. Reading "Operation not permitted" without distinguishing it from "Permission denied" leads to chasing the wrong fix.
- **The hardlink prerequisite stack is three layers deep, not one.** (a) Same `st_dev` on client; (b) underlying server FS supports cross-path hardlinks within the involved branches; (c) linker process's kernel allows the link given file ownership/perms. Each layer can fail independently. We had to satisfy all three sequentially.

## Files touched so far

- `arrs-vm:/etc/fstab` — replaced 5 per-dir NFS mounts with single unified `/mnt/storage → /mnt/nas` mount (backup at `.bak.20260604-pre-hardlink`).
- `arrs-vm:/opt/arr-stack/docker-compose.yml` — NOT yet edited (backup at `.bak.20260604-pre-hardlink` taken pre-emptively).
- `qwerty:/etc/exports` — added `10.0.50.47` host-specific entry on parent `/mnt/storage` with `no_root_squash,no_all_squash` (backup at `/etc/exports.bak.20260604-pre-hardlink`).

## Open items (will fill in as session continues)

- Path A execution: chown 4.1 TB on qwerty, chown qbt config on arrs-vm, edit compose, restart stack, verify, flip UI toggles, smoke test.
- Documentation in `Raymer/docs/arrs-vm.md` once stable.
