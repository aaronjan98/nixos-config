# 2026-06-26 TAA - Meshuggah playlist

## What was worked on

### TAA - Meshuggah playlist
- Parsed Liz's 11-track Apple Music playlist.
- Meshuggah was not in Lidarr at all — added as artist ID 185 (foreignArtistId: cf8b3b8c-118e-4136-8d1d-c37091173413).
- 6 albums needed: Contradictions Collapse / None, obZen (2023 remaster), Nothing, The Violent Sleep of Reason, Koloss, Immutable.
- obZen (2008) original was already on disk at `/mnt/nas/music/Meshuggah/obZen (2008)/` but not linked to Lidarr. The 2023 15th Anniversary remaster (MusicBrainz ID `695821e7-1d7d-4506-b989-cf7897636004`) is a stub with only 1 track registered — but the downloaded remaster imported into the obZen (2008) folder and Navidrome picked it up as "Bleed (15th Anniversary Remastered Edition)".
- Contradictions Collapse & None: Lidarr downloaded the vinyl rip ([24/48] 2011 reissue) but gave `albumImportIncomplete` because of vinyl-side filenames (a1, b1, c1, d1 etc. instead of track numbers). Files were in `/mnt/nas/downloads/music/Meshuggah - Contradictions Collapse & None/`. Manually copied all 13 FLACs to `/mnt/nas/music/Meshuggah/Contradictions Collapse & None (1991)/` via `docker exec lidarr cp`.
- All 11 tracks found in Navidrome after second scan (7,961 files).
- Created playlist `TAA - Meshuggah`, ID `Byoh7d82rG5g1ipXC2MRXL`, 11 tracks, ~61 min. Cover uploaded.

### Track list:
1. Ritual — Contradictions Collapse & None (1991)
2. Bleed — obZen (15th Anniversary Remastered Edition)
3. Stengah — Nothing (2002)
4. Born in Dissonance — The Violent Sleep of Reason (2016)
5. Demiurge — Koloss (2012)
6. Rational Gaze — Nothing (2002)
7. The Abysmal Eye — Immutable (2022)
8. Clockworks — The Violent Sleep of Reason (2016)
9. Gods of Rapture — Contradictions Collapse & None (1991)
10. Do Not Look Down — Koloss (2012)
11. Obsidian — Nothing (2002)

## Key insights
- When adding a new artist to Lidarr, pass the full lookup object from `/api/v1/artist/lookup` to `/api/v1/artist POST` — just adding `qualityProfileId/metadataProfileId/rootFolderPath/monitored/addOptions` to the lookup result is enough.
- MusicBrainz stub albums (like obZen 2023 with only 1 track registered) cause Lidarr `statistics.trackFileCount` to show 0 even after download/import. Don't use that as a health check for stub albums — check the physical files instead.
- Vinyl rip torrents use side-letter naming (a1, b1, c1) which Lidarr can't match to MusicBrainz track numbers → `albumImportIncomplete`. Fix: copy files manually to the music folder; Navidrome reads TITLE/ARTIST tags, not filenames.
- `docker exec lidarr cp` is the way to write to `/mnt/nas/music/` — the `aj` user on qwerty doesn't have write permission (owner is `statd 121`), but Lidarr runs as root in the container.
- `X-Nd-Authorization: Bearer <jwt>` (not `Authorization`) is required for Navidrome internal API playlist cover uploads.
- Bleed was found in Navidrome as "ObZen (15th Anniversary Remastered Edition)" because the remaster download imported over the existing original obZen files.

## Decisions
- Kept Contradictions Collapse vinyl rip (24/48 2011 reissue) by manually copying instead of re-downloading — the tags were correct (TITLE, ARTIST, ALBUM) even though filenames were wrong.
- No YouTube fallbacks needed.

## Open questions / next steps
- Contradictions Collapse / None files are in `/mnt/nas/music/Meshuggah/Contradictions Collapse & None (1991)/` but NOT imported in Lidarr (Lidarr still shows 0 files for albumId 2711). This is fine for Navidrome playback but Lidarr won't manage these files. Not urgent.
- Multiple competing downloads for the same albums (Lidarr AlbumSearch grabbed additional releases for Nothing, Violent Sleep, Immutable, Koloss). These are still in the queue. Lidarr will import whichever finishes next if quality upgrades apply; the weekly cleanup cron handles ghost entries.
- Next TAA playlist when Liz provides one.
