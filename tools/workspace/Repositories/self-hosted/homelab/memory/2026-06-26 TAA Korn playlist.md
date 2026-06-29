# 2026-06-26 TAA - Korn playlist

## What was worked on

### TAA - Korn playlist
- Parsed Liz's 15-track Apple Music playlist.
- Korn already in Lidarr as artist ID 178 with 14 albums monitored.
- 13 of 14 needed albums had full file counts; only The Serenity of Suffering (albumId 2627) was 0/14.
- The Serenity of Suffering download was difficult: first auto-grab was FLAC image+.cue (single-file, Lidarr can't import); second auto-grab was FLAC24 WEB (stalled at 1.2%, "no connections"); third attempt was RuTracker FLAC24 Roadrunner (also stalled). Finally the RuTracker Deluxe Edition (indexer 10) downloaded successfully.
- All 15 tracks found in Navidrome after scan (7,975 files).
- Created playlist `TAA - Korn`, ID `WL1Oe3AfopaXpHINza8zcV`, 15 tracks, ~59 min. Cover uploaded.

### Track list:
1. The End Begins — The Nothing (2019)
2. I Will Protect You — [untitled] (2007)
3. Wake Up — Issues (Deluxe Edition) CD1 (1999)
4. Start The Healing — Requiem (2022)
5. Freak On a Leash — Follow The Leader (1998)
6. Falling Away from Me — Issues (Deluxe Edition) CD1 (1999)
7. Predictable — Korn (1994)
8. Wicked (feat. Chino Moreno) — Life Is Peachy (1996)
9. Fear Is a Place to Live — Korn III Remember Who You Are (2010)
10. Get Up! (feat. Skrillex) — The Path of Totality (2011)
11. Souvenir — See You On The Other Side (20th Anniversary Edition - Remastered) (2005)
12. Insane — The Serenity of Suffering (2016)
13. H@rd3r — The Nothing (2019)
14. Reclaim My Place — Follow The Leader (1998)
15. Forgotten — Requiem (2022)

### Navidrome track IDs:
- The End Begins:       eDqLsdJmVAf7mtyoKbOB0X
- I Will Protect You:   JS4OB9cmZ9dVRfhlD9Rurj
- Wake Up:              tBR0u18xiKqmjcLrzN7YA8
- Start The Healing:    NnalASJ3N3ch65plKiL3GZ
- Freak On a Leash:     n0uRilV6DuNjr0Y6IKSf1a
- Falling Away from Me: LlcoWo93vfeVXKXmsYmLt3
- Predictable:          G1RXj5UNmSqRjXFdyBInUZ
- Wicked:               Ps5M7LsQeSxc5NN4xQ717n
- Fear Is a Place to Live: P2OFOmroLV90qEIm1y2UM0
- Get Up!:              FYZxBk4sfs15z2by4VEFao
- Souvenir:             Ti2oGV6HGLVdWwgFky5mLI
- Insane:               0q9AwTApg5QgBDwABuJaM1
- H@rd3r:               cY1BMQahl7GW6xTAc5mmUN
- Reclaim My Place:     yJQPsbZBVVEZYAfcMY7vHM
- Forgotten:            oCU9O7JsD7pBsZLwvt0MXN

## Key insights
- Korn was already in Lidarr (artist 178) from a prior session (before Linkin Park). 14 albums, 181 track files before this session.
- 12 of the 15 tracks were under the `KoЯn` artist entry (Cyrillic Я) in Navidrome — older imports with different artist name encoding. Navidrome search without artist filtering finds them; filter for "korn" misses them. Always search without artist filter for Korn tracks.
- "Forgotten" is on the standard Requiem album (not a separate Requiem Mass release) — Navidrome correctly found it.
- "I Will Protect You" is on the standard [untitled] album (not the deluxe) — Navidrome confirmed.
- The Serenity of Suffering had multiple failed download attempts:
  - First: image+.cue FLAC (single file, Lidarr can't import individual tracks)
  - Second/third: FLAC24 WEB + FLAC24 RuTracker both stalled "no connections" / 409 qBittorrent conflict
  - Working: RuTracker Deluxe Edition FLAC (indexer 10, `10_https://rutracker.org/forum/viewtopic.php?t=...`)
- qBittorrent 409 "Conflict" appears when sending the same torrent hash (E75D9C55) a second time — blocklisting doesn't always clear the hash from qBittorrent's internal registry.

## Decisions
- No YouTube fallbacks needed — all tracks were in Navidrome from existing library.
- Proceeded without waiting for Lidarr to confirm import count (downloaded directly from RuTracker via indexer 10).

## Open questions / next steps
- The KoЯn vs Korn artist split still exists in Navidrome. Older catalog albums (Follow The Leader, Life Is Peachy, Korn, Issues, Korn III, The Path of Totality, See You On The Other Side) are under KoЯn. Newer Lidarr-imported ones (The Nothing, Requiem, [untitled]) are under Korn. Not urgent since playback works.
- Next TAA playlist when Liz provides one.
