# 2026-06-27 TAA - Opeth playlist

## What was worked on

### TAA - Opeth playlist
- Parsed Liz's 13-track Apple Music playlist (artist: Opeth, ~93 min / 5609 seconds).
- Opeth was entirely absent from NAS/Navidrome/Lidarr — full acquisition required.
- Added Opeth to Lidarr as artist ID 189 (foreignArtistId: `c14b4180-dc87-481e-b17a-64e4150f90f6`).

### Track list (Liz's order):
1. Silhouette — Orchid (1995)
2. The Funeral Portrait — Blackwater Park (2001)
3. All Things Will Pass — In Cauda Venenum (Extended Edition) (2019)
4. Slither — Heritage (2011)
5. Deliverance — Deliverance (2002)
6. Porcelain Heart — Watershed (2008)
7. Ending Credits — Damnation (2003)
8. Ghost of Perdition — Ghost Reveries (2005)
9. Sorceress — Sorceress (2016)
10. Goblin — Pale Communion (2014)
11. Face of Melinda — Still Life (1999)
12. The Night and the Silent Water — Morningrise (1996)
13. Epilogue — My Arms, Your Hearse (1998)

### Navidrome track IDs:
- Silhouette:                   8qyVH3REQmaHvKb89drTed
- The Funeral Portrait:         3CP7aHjiXpNX9ZZfzyYlDm
- All Things Will Pass:         Nh5rVivjNiYEe6CPmdBqJZ
- Slither:                      G28YH2dUHXg4grQLUO7TWf
- Deliverance:                  JC5igy8hF8HI4CAHX5SHUH
- Porcelain Heart:              Q2BO1ICqMheorNsV1u9Xje
- Ending Credits:               tEKP1ugtHVEKMmn34P3z3r
- Ghost of Perdition:           fFOyueh59qzqcEEao3XwOt
- Sorceress:                    5teNqiVrBzmOCdss4mE9RV
- Goblin:                       5kPTzEChNHF3aWZwHhWCZB
- Face of Melinda:              BsUXpeELtqp4Vc1LusECYX
- The Night and the Silent Water: stVfA9OH5DvdSZvvIwjwvz
- Epilogue:                     4BmAKChaS7imENtAk2b8pV

### Navidrome IDs:
- Artist: 68VMmUK8Ly4hBAgwUPOD1h
- Playlist: E9GQs1efEuYXVLdMH1uS5d

### Lidarr IDs:
- Artist: 189

## Acquisition strategy

Since all 13 albums were absent, used two approaches:

### Discography pack (9 tracks from 1995–2011)
- Torrent: "Opeth - Discography-(1995 - 2011)-FLAC-VINYL-2012-JKoop" (hash `1206d29f2e1350eb516c576138bea6c8e171b25d`)
- Saved to: `/mnt/nas/downloads/incomplete/music/Opeth - Discography.../`
- Used qBittorrent file-priority API to download only the 9 needed tracks (indices 1,8,20,27,35,39,50,52,63)
- Copied via `docker exec lidarr cp` to `/mnt/nas/music/Opeth/{Album (Year)}/`

### Individual albums (4 tracks, post-2011)
- **Pale Communion (2014)** — Goblin.flac: separate FLAC 24-96 torrent
- **Sorceress (2016)** — Sorceress.flac: separate torrent (had to replace slow 1-seed with 15-seed RuTracker version `274e2bc8...`)
- **Watershed (2008)** — Porcelain Heart.flac: 9-seed TPB FLAC surround version `3b1e86cc...` (earlier attempts with other versions got stuck in metaDL)
- **In Cauda Venenum Extended (2019)** — All Things Will Pass.flac: RuTracker version `ee4c0c06...` (original `e08cf946...` stuck in metaDL)

All files copied to `/mnt/nas/music/Opeth/{Album (Year)}/` (single-track directories by design — only needed tracks).

## Key insights

- **qBittorrent file priority to limit discography downloads**: POST `/api/v2/torrents/filePrio` with `hash=H&id=N|N|N&priority=0` (skip) or 7/6 (high/normal). Dramatically reduces download from ~11GB to ~1.4GB.
- **discography torrent saves to** `/mnt/nas/downloads/incomplete/music/` (not `/music/` root), despite category being `music`.
- **Single-track NAS directories work fine**: Navidrome picks up individual FLAC files in sparse album folders.
- **Navidrome artist image**: For TAA playlists, artist image is the TAA show-branded episode art for that band, found via `SG-MQ-US-001-Image000001` URLs in the Apple Music HTML. The correct Opeth one was `d74ccc40-69ce-a056-a7cc-b264a88fd552`.
- **Playlist cover**: The other SG-MQ-US-001 image (`0204c615-...`) is the show's generic b&w studio artwork.
- **Finding the correct artist image**: When multiple AMCArtistImages appear in the transcript, find which one appears most frequently within the specific playlist HTML block. The one with ~13×8 occurrences in the Opeth message was the right one.

## Image URLs (Apple Music)
- Playlist cover (b&w TAA studio): `SG-MQ-US-001-Image000001/v4/02/04/c6/0204c615-66a9-b166-d52b-67a9884e979b/image/610x610bb.webp`
- Opeth artist image (TAA Opeth episode): `SG-MQ-US-001-Image000001/v4/d7/4c/cc/d74ccc40-69ce-a056-a7cc-b264a88fd552/image/305x305cc.webp`
