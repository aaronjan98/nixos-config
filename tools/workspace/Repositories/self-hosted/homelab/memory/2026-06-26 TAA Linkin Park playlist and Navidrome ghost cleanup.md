# 2026-06-26 TAA - Linkin Park playlist + Navidrome ghost album cleanup

## What was worked on

### TAA - Linkin Park playlist
- Parsed Liz's 18-track Apple Music playlist.
- Meteora (15/15 FLAC) and Hybrid Theory (12/12 M4A) were already in the library from a prior session.
- Living Things (0/18) was missing — triggered Lidarr AlbumSearch, grabbed 289-seed FLAC torrent which imported during the session.
- YouTube-ripped BURN IT DOWN as fallback (vid `dxytyRy-O1k`) — not needed in the end as the FLAC imported first. YT rip later deleted.
- "A Place for My Head" not found via exact-title search; found as "Place For My Head" via mid-fragment query (`place my head`). ID: `LcTqld721yNxMwPuczfhDT`.
- Created playlist `TAA - Linkin Park`, ID `uIhEHuTACVeb4wH2ks09Mb`, 18 tracks, ~57 min. Cover uploaded.
- Deleted redundant YT rip (`/mnt/storage/music/Linkin Park/Living Things/01 Burn It Down.m4a`) via docker python after discovering the FLAC had already imported to `Living Things (2012)/`.

### Navidrome ghost album investigation + fix
- Two greyed-out albums reported: `See You On The Other Side - CD1 (2005, Virgin - 0946 3 47113 2 G) [USA]` and `Living Things` (1 song).
- Root cause: Lidarr replaced old m4a files with new FLACs under different filenames/paths. Navidrome marks old paths `missing=1` in a full scan but does NOT delete the DB entries.
- The "See You On The Other Side" ghost was under a separate Navidrome artist entry `KoЯn` (artist ID `6AKLcLFypKFKHq9bQDdV4E`) — m4a files replaced by `See You On The Other Side (20th Anniversary Edition - Remastered)` FLACs.
- Tried full scan (`startScan?fullScan=true`) — marked ghosts `missing=1` but didn't delete them.
- Fix: direct SQLite DELETE:
  ```sql
  DELETE FROM media_file WHERE album_id IN ('29QtJ6hIKu8v3tYA7HgVoA', '3CnUGEXTiDC47GQOA4Jbxp');
  DELETE FROM album WHERE id IN ('29QtJ6hIKu8v3tYA7HgVoA', '3CnUGEXTiDC47GQOA4Jbxp');
  ```
- DB at `/opt/homelab/navidrome/data/navidrome.db`. Editing while Navidrome is running is safe (SQLite WAL mode).

### Navidrome cleanup cron
- Installed `/opt/homelab/navidrome/cleanup.sh` on qwerty:
  1. Calls `startScan?fullScan=true`, polls until complete.
  2. Runs `DELETE FROM media_file/album/artist WHERE missing=1`.
- Password for scan API copied to qwerty at `/opt/homelab/navidrome/.aj-navidrome-pass`.
- Cron: `0 4 * * 0` (Sunday 4am), logs to `/var/log/navidrome-cleanup.log`.
- Test run: 4.5 min, clean exit.

## Key insights
- Navidrome's `missing=1` flag is set by full scan but entries are never auto-deleted — this is intentional (guards against network drive going offline).
- Lidarr DOES delete old files on format upgrade (same as Radarr) — the ghost problem is purely Navidrome's DB hygiene.
- The `KoЯn` artist entry (Cyrillic Я) is a separate artist in Navidrome from `Korn` — both exist because the old m4a tags used a different artist name encoding from MusicBrainz tagger.
- Navidrome tokenizes search on word boundaries — leading articles drop out. Use mid-word fragments when exact-title search returns nothing.

## Decisions
- Weekly cleanup cron is the right long-term fix. Max 1 week of ghost entries after any Lidarr format upgrade.
- Password file approach (chmod 600 on qwerty) is appropriate for home server context.

## Open questions / next steps
- The `KoЯn` vs `Korn` artist split still exists in Navidrome (the KoЯn entry has the other catalog-style albums: Follow The Leader, Life Is Peachy, Untouchables, etc.). These all have files but with catalog-style album tags. Could consolidate into the main `Korn` artist by normalizing album artist tags, but not urgent since they play fine.
- Next TAA playlist when Liz provides one.
