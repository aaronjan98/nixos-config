# 2026-06-26 TAA - TOOL playlist

## What was worked on

### TAA - TOOL playlist
- Parsed Liz's 8-track Apple Music playlist.
- Undertow (1993) was already in the library (10 tracks, previously imported).
- 5 albums had to be downloaded fresh via Lidarr: Ænima, Lateralus, 10,000 Days, Fear Inoculum, and Opiate EP.
- Opiate EP was missing from Lidarr entirely — added via `/api/v1/album` with `foreignAlbumId=bec2ca63-468d-46bc-895c-75861d931fb9`.
- All 5 albums grabbed and imported within ~15 minutes once searches were triggered.
- Fear Inoculum initial grab was stalled (2-seed torrent, ETA July 12). Replaced with 64-seed FLAC deluxe; however the original torrent actually sped up and completed first. Cancelled the replacement.
- All 8 tracks found in Navidrome after scan. No YouTube fallbacks needed.
- Created playlist `TAA - TOOL`, ID `kXet4tS7IpyMMqjfvu7Rpq`, 8 tracks, ~54 min. Cover uploaded.

### Track list:
1. Fear Inoculum — Fear Inoculum (2019)
2. Stinkfist — Ænima (1996)
3. Parabola — Lateralus (2001)
4. Jambi — 10,000 Days (2006)
5. Prison Sex — Undertow (1993)
6. Eulogy — Ænima (1996)
7. Wings For Marie (Pt 1) — 10,000 Days (2006)
8. Opiate — Opiate (12 Inch EP, 1992)

## Key insights
- TOOL artist was already in Lidarr (artist ID 25) but unmonitored. The individual albums were monitored — so AlbumSearch worked fine.
- Opiate EP wasn't in Lidarr at all. Used `/api/v1/album/lookup?term=tool+opiate` to find `foreignAlbumId`, then POST to `/api/v1/album` with `addOptions.searchForNewAlbum: true`.
- Music path on qwerty host: `/mnt/nas/music/` (NFS mount from 10.0.50.83:/mnt/storage). Inside Lidarr docker container this is `/music/`. Inside Navidrome it's `/mnt/storage/music/` (a separate NFS mount path in that container).
- A "warning" status in Lidarr queue means the download client reported an issue but the download may still proceed — don't immediately cancel.
- Two concurrent downloads for the same albumId (e.g. two grabs of Fear Inoculum) are fine — Lidarr imports whichever finishes first.
- Navidrome picks up new files either via inotify or on the next scan. After Lidarr imports, a `startScan` (not fullScan) is enough to pick up new tracks quickly.

## Decisions
- Let the original Fear Inoculum torrent complete (it sped up to reasonable speed) rather than waiting for the replacement.
- No YouTube fallbacks were needed — all albums were available on indexers.

## Open questions / next steps
- The slow "TOOL - 1992 - Opiate [Hi-Res]" download (albumId=2699, slow RuTracker grab) was left running but the PBTHAL version imported first. Lidarr should ignore/cancel it eventually, or the cleanup cron will handle any ghost entries.
- Next TAA playlist when Liz provides one.
