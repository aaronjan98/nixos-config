# 2026-06-02 — Jellyfin NVMe migration (transcode scratch + SQLite library DB)

Time: ~13:00–19:50 PT. Spanned two long sessions; this note covers both because they are the same arc.

## What was worked on

Resolved two surfaces of the same root cause on `qwerty` (HP EliteDesk 800 G4 Mini, 4×15 TB Terramaster + mergerfs):

1. **Transcode contention** — Jellyfin's `/cache` (HLS segments) and `/tmp/jellyfin` (ffmpeg scratch) were bound to `/mnt/storage/appdata/jellyfin/{cache,tmp}`, i.e. the mergerfs HDD pool. Every transcode collapsed playback within ~60 s because the head ping-ponged between source-media reads and segment writes on the same spindles.

2. **Library DB contention** — Jellyfin's `jellyfin.db` (4.4 GB SQLite, ~78 K files in `/config/data`) also lived on the HDD pool. Library scans (Sonarr import → LibraryMonitor inotify → metadata refresh) hammered the DB with tens of thousands of small random reads while the same disks served playback. `iostat sda: 407 r/s, rareq-sz 7.88 KB, %util 47%`. `/health` blocked 155 s. Manifested as the chronic "Server Unavailable" hang AJ had been hitting for months.

Both surfaces fixed by relocating to a single 80 GB LVM logical volume on the previously-unused NVMe space in `ubuntu-vg`: `/dev/ubuntu-vg/jellyfin-scratch` mounted at `/mnt/jellyfin-scratch` (ext4, label `jellyfin-scratch`).

Also created/cross-linked 5 zettels around the underlying mental model: Linux page cache, interleaved I/O, buffered cycle, sequential vs random I/O, NAND channels. Backfilled wiki-links in the HDD head-contention zettel and added a real-world case-study section to it. Promoted "don't run write-heavy or many-small-random-read workloads on the HDD pool while it's serving media" to the **top lesson banner** at the top of `Raymer/docs/qwerty.md`.

## Key insights

- **HDD head contention is the single durable lesson of this homelab.** Not transcoding-specific. Not Jellyfin-specific. The Terramaster spindles are the bottleneck for *anything* on `qwerty` that mixes I/O with playback. The head can only be in one place at a time, and on consumer HDDs that one place costs 5–10 ms to change. SSDs/NVMe have no head and use independent NAND channels — concurrent R+W is structurally cheap.
- **Concurrent *readers* of different files scale fine on HDD** because each reader is bandwidth-light (a 1080p HEVC stream is ~0.5–2 MB/s) and the page cache + multi-disk mergerfs spread takes most of the work. The trap is read+write on the *same* physical disk: even when each side is sequential in isolation, the interleaving makes it look like random I/O to the drive.
- **`ionice`/`nice` cannot fix this.** They reorder requests within a single saturated queue, not eliminate the contention. The cheap, durable fix is to put the two sides on different physical devices.
- **mergerfs's "existing path" behavior puts new sibling files on the same branch as the source**, which is exactly the condition that triggers the head thrash for a remux that writes next to the source. Writing outside the union mount (e.g., to the NVMe LV) and then `mv`-ing back at the end is benign because the final copy is a single sequential write with no concurrent read.
- **Health-probe measurement: 155 s → 3.7 ms (~42,000×).** Same probe, same network, same code path — only storage placement changed. This is the right kind of evidence to hold onto, because it isolates the variable cleanly.
- **The library-DB surface had been silently degrading for months.** AJ described "Server Unavailable" hangs as a chronic problem. Without an iostat trace during the freeze, the symptom would have stayed mysterious. Lesson: when a service "just hangs sometimes," check `iostat -x 1` against the relevant device during the hang, not just `top` and container logs.

## Decisions

- **80 GB LV size** (not 50 GB): typical transcode footprint is 1–3 GB; 80 GB gives ~25× headroom for orphans + plugin caches + DB working set. ~55 GB still unallocated in `ubuntu-vg` for future LVs. Online `lvextend + resize2fs` is available if we ever need more — no downtime.
- **Single shared LV** for both transcode scratch *and* the relocated DB hot dir, rather than two separate LVs. Simpler to manage; the two workloads don't compete (NVMe handles concurrent R+W via NAND channels).
- **Surgical split of `/config/data`** rather than moving the whole 209 GB:
  - NVMe: `jellyfin.db` (+wal/shm), `playback_reporting.db`, `ScheduledTasks`, `collections`, `introskipper`, `attachments`, `SQLiteBackups`, splashscreens (~6 GB).
  - HDD (bind-mounted back): `subtitles/` (145 GB, mostly cold reads at playback start), `backups/` (42 GB, cold daily writes).
  - Not migrated: `library.db.bak{1,2,3,5,6,7}`, `library.db.old`, `empty-backup/` — ~22 GB of dead weight from the pre-10.10 schema migration. Will delete after ~1 week of clean operation as a rollback safety margin.
- **Old `/mnt/storage/appdata/jellyfin/{cache,tmp,config/data}` left in place** for a ~1 week rollback window. Compose backups kept at `/opt/homelab/jellyfin/docker-compose.yml.bak.{20260602-181837,prescratch-data.20260602-193355}`.

## Open questions / follow-ups

- **Sonarr/Radarr hardlink imports** — the 18:00 PT incident that triggered the "high system load" check was a cross-disk Sonarr import (sdb reads + sda writes — heavy but not same-disk head thrash). With "Use Hardlinks" disabled, every import is read-then-write across mergerfs branches. Hardlinks would make this an instantaneous metadata operation. Need to (a) toggle "Use Hardlinks instead of Copy" in Sonarr + Radarr, and (b) verify arrs-vm mounts qwerty's NFS as a single `/mnt/storage` mount, not split `/downloads` + `/movies`, so hardlinks can span both. Tracked in `Raymer/project-memory/arrs-vm-storage-and-startup.md`.
- **Confirm Jellyfin "Maximum transcode age"** (Dashboard → Playback) is a few hours, not days — bounds orphan accumulation in the new LV. Listed in qwerty.md "Known gaps."
- **SnapRAID 2026-06-02 02:10 reported 13 file errors.** Non-fatal but should look at `/var/log/snapraid*.log` to identify which files.
- **`immich_machine_learning` healthcheck flapping** (`FailingStreak: 1680`). Service responds; healthcheck command itself appears broken. Not urgent.
- **Caption cleanup (item #3 from the original Jellyfin optimization list)** — Bazarr language profile narrowing + library pass to strip extras. Deferred behind the storage-contention work.
- **Controlled 10-bit HEVC retest** — previously off based on bad empirical experience with the Coffee Lake iHD driver. Worth a controlled before/after ffmpeg-log test on a specific file someday.

## Next steps (when AJ returns)

1. Watch for any "Server Unavailable" pattern over the next week of normal use. If it doesn't recur, the diagnosis was correct and the fix is durable.
2. After ~1 week of clean operation (target: ~2026-06-09):
   - Delete `/mnt/storage/appdata/jellyfin/{cache,tmp}/` — rollback safety net for the transcode-scratch move.
   - Delete `/mnt/storage/appdata/jellyfin/config/data/{jellyfin.db,jellyfin.db-wal,jellyfin.db-shm,playback_reporting.db,ScheduledTasks,collections,introskipper,attachments,SQLiteBackups,splashscreen*.png}` — rollback safety net for the DB move. **Do not delete `subtitles/` or `backups/`** — they are still active bind-mount targets.
   - Delete the ~22 GB of `library.db.bak*` + `library.db.old` + `empty-backup/` dead weight.
3. Tackle the Sonarr/Radarr hardlink toggle + NFS mount unification on arrs-vm.

## Files touched this session

- `Raymer/docs/qwerty.md` — top-lesson banner, "Scratch space on NVMe" subsection, new "SQLite library DB on NVMe" subsection, two new Known-gaps rows.
- `Raymer/project-memory/arrs-vm-storage-and-startup.md` — appended "Open follow-up: hardlink imports for Sonarr/Radarr" with the 18:00 incident citation and the four action items.
- `/opt/homelab/jellyfin/docker-compose.yml` (on qwerty) — added 3 bind mounts for the DB split; old transcode binds already swapped earlier in the session.
- Zettelkasten (new): `Linux page cache.md`, `interleaved I-O.md`, `buffered cycle.md`, `sequential vs random I-O.md`, `NAND channels.md`.
- Zettelkasten (edited): `HDD head contention — concurrent reads scale, read+write thrashes.md` — wiki-link backfill + new "Case study — Jellyfin on mergerfs (2026-06-02)" bullet block; `Index (Tech).md` — 5 new entries under System Administration and DevOps.
