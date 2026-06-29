# 2026-06-26 TAA - Rosetta playlist

## What was worked on

### TAA - Rosetta playlist
- Parsed Liz's 9-track Apple Music playlist (artist: Rosetta, 9 songs, ~57 min).
- Rosetta was not in Lidarr — added as artist ID 188 (foreignArtistId: `79489e1b-5658-4e5f-8841-3e313946dc4d`).
- Lidarr found 6 albums (IDs 2731–2736).
- Needed albums: **The Anaesthete** (ID 2734) and **Utopioid** (ID 2736).

### Track list (Liz's order):
1. Amnion — Utopioid (2017)
2. In & Yo / Dualities of the Way — The Anaesthete (2013, Japan Ltd.)
3. Intrapartum — Utopioid (2017)
4. Ku / Emptiness — The Anaesthete (2013, Japan Ltd.)
5. King Ivory Tower — Utopioid (2017)
6. Hara / the Center — The Anaesthete (2013, Japan Ltd.)
7. 54543 — Utopioid (2017)
8. Myo / the Miraculous — The Anaesthete (2013, Japan Ltd.)
9. Qohelet — Utopioid (2017)

### Navidrome track IDs:
- Amnion:                    PrLQWG08yeYCl5mjemTFLb
- In & Yo / Dualities…:     Ixv29po7OUS4teBlkmC1tP
- Intrapartum:               7ZjGfkQxYn2708VW3w1Zbs
- Ku / Emptiness:            ljtDXWNIaaBmLoX029J21b
- King Ivory Tower:          hwfIg220OJHtO1MdKDHk5b
- Hara / the Center:         UFJlD26c9Al1Or9XTxUUA9
- 54543:                     cyrBn9KMlpubpTOL4DaVzP
- Myo / the Miraculous:      KewIWEIpZtWMp8jHaOpMuJ
- Qohelet:                   VTQS3YsfXMEbUDhZxPQqdR

### Navidrome artist ID: 6rmgSSayxRqWWs3NYtDn1Y
### Navidrome playlist ID: SqoeRTZbFnNhVDjnfwFfm8

## Key acquisition challenges

### Utopioid (2017)
- **0 results** on every public indexer (1337x, TPB, TheRARBG, LimeTorrents, etc.).
- Found in a RuTracker discography pack: "Rosetta (w Junius, Restorations) - 2010-2019" (magnet hash `A7714526A2ECB58B2F1B209078DCD2594D6D31DD`).
  - Got the magnet via Prowlarr's redirect response; added manually to qBittorrent with `music` category.
  - Pack contained 24-bit FLAC — skipped other albums, downloaded only Utopioid.
  - 9 tracks at `/mnt/nas/downloads/incomplete/music/Rosetta/Albums/2017 - Utopioid [24-bit FLAC]/`.
- Lidarr `manualimport` required switching monitored release from 11-track (21683) to 9-track (21681) then providing correct release/track IDs explicitly.
- Final import: copied to `/mnt/nas/music/Rosetta/Utopioid (2017)/` via `docker exec lidarr`, then `DownloadedAlbumsScan` on `/downloads/music/Rosetta` picked it up (9/9 tracks imported).

### The Anaesthete (2013)
- All The Pirate Bay magnets were dead (0 seeds, metaDL state).
- RuTracker direct downloads returned 403/HTML (auth broken for torrent DL).
- Found in full Rosetta discography pack: "Rosetta + Balboa... 2003-2019" (magnet hash `E82BF343C045206B6F31F9DD3297E9BA218212AC`).
  - Got magnet via Prowlarr redirect approach; added to qBittorrent.
  - Contains all Rosetta studio albums incl. The Anaesthete.
  - Downloaded **Japan Limited Edition** version — uses Zen track names (In & Yo, Ku, Hara, Myo).
  - Skipped non-needed tracks; only downloaded the 4 required MP3 files.
- Lidarr import completely failed (manualimport 202 but never committed; RefreshArtist found files but didn't import).
- **Workaround:** Bypassed Lidarr entirely — copied 4 MP3 files directly to `/mnt/nas/music/Rosetta/The Anaesthete (2013)/`, triggered Navidrome `startScan`, tracks appeared in Navidrome.

## Key insights
- **Prowlarr download link redirect trick:** When Prowlarr returns "Invalid link", immediately follow the download URL — it 301-redirects to `magnet:?xt=urn:btih:HASH&...`. Extract the hash and add directly to qBittorrent. Prowlarr links expire within seconds so do it programmatically (python `urllib.request` in one call).
- **RuTracker auth broken for downloads:** Prowlarr can search RuTracker but torrent downloads fail (returns HTML login page). Use the redirect trick above to extract the magnet hash.
- **Utopioid not on public trackers:** Only available via RuTracker discography packs.
- **Lidarr manualimport needs explicit release ID + track IDs:** The `release` object is not populated automatically in manualimport responses. Must query `/api/v1/album/{id}` for releases, pick the one matching track count, query `/api/v1/track?albumReleaseId=N` for track IDs, then POST the full payload.
- **Lidarr RefreshArtist inconsistency:** Even with files in `/music/Rosetta/`, RefreshArtist didn't import them. The DownloadedAlbumsScan on a `/downloads/` path worked for Utopioid (triggering a side-effect rescan of the music root), but not for Anaesthete.
- **Navidrome bypass:** For files Lidarr won't import, just put them in the NAS music path and trigger `startScan`. Navidrome is the end consumer — Lidarr registration is optional for playlist purposes.
- **Japan Limited Edition track names:** The Anaesthete Japan release uses Zen/Japanese philosophy names as track prefixes (Ryu/Tradition, Ku/Emptiness, Hara/The Center, Myo/The Miraculous, In & Yo/Dualities of the Way). These ARE the same tracks as the standard edition, just titled differently.

## Lidarr IDs
- Artist: 188
- The Anaesthete: album 2734, release 21673 (11-track Japan Ltd., monitored)
- Utopioid: album 2736, release 21681 (9-track, monitored after switch from 21683)

## Rosetta discography torrents (for future reference)
- 2010-2019 pack (Utopioid+): magnet `A7714526A2ECB58B2F1B209078DCD2594D6D31DD` (RuTracker)
- 2003-2019 complete discography: magnet `E82BF343C045206B6F31F9DD3297E9BA218212AC` (RuTracker)
  - Contains ALL Rosetta studio albums; Anaesthete is Japan Ltd. edition with Zen track names

## Pending
- Other albums still 0/N in Lidarr (The Galilean Satellites, Wake/Lift, etc.) — not needed for current playlist.
- The 2003-2019 torrent is still downloading other albums in the background.
