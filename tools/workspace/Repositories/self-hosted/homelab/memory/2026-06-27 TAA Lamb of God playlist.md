# 2026-06-27 TAA - Lamb of God playlist

## What was worked on

### TAA - Lamb of God playlist
- Parsed Liz's 15-track Apple Music playlist (artist: Lamb of God, ~57 min / 3418 seconds).
- Lamb of God was entirely absent from NAS/Navidrome/Lidarr — full acquisition required.
- Added Lamb of God to Lidarr as artist ID 190 (foreignArtistId: `298909e4-ebcb-47b8-95e9-cc53b087fc65`).

### Track list (Liz's order):
1. Omertá — Ashes of the Wake (2004)
2. The Black Dahlia — New American Gospel (2000)
3. Redneck — Sacrament (2006)
4. Laid to Rest — Ashes of the Wake (2004)
5. Black Label — New American Gospel (2000)
6. Purified (Remixed / Remastered) — As The Palaces Burn (2003)
7. Foot to the Throat — Sacrament (2006)
8. Ghost Walking — Resolution (2012)
9. The Passing — Wrath (2009)
10. In Defense Of Our Good Name (Remixed / Remastered) — As The Palaces Burn (2003)
11. Straight For The Sun — Resolution (2012)
12. Nightmare Seeker (The Little Red House) — VII: Sturm und Drang (2015)
13. New Colossal Hate — Lamb of God (2020)
14. Ditch — Omens (2022)
15. Grace — Wrath (2009)

### Navidrome track IDs:
- Omertá:                                   Ox3t5glUaqZHmozV0ripKj
- The Black Dahlia:                          yQUmbXmOJOolEhJtuD7WK7
- Redneck:                                   m8pwH0BvXmsmv3SRjBANmA
- Laid to Rest:                              aDE2GBy6VQtQZlnK8C23LL
- Black Label:                               MtzttbtXk7mDDiAhWJhwRG
- Purified (Remixed / Remastered):           j1ZK2S3smlRVKjOTkN1LTV
- Foot to the Throat:                        LWFE1AiyGVxIKl6PbQYo02
- Ghost Walking:                             smcp0viojfGFVoIhhysNMx
- The Passing:                               Rx78efGRQtmiLSSzyZFLBi
- In Defense Of Our Good Name (R/R):         z2DoiJZAcQOnctJ4ITaDQ7
- Straight For The Sun:                      oAlTNUiSfTmFxSkQMIYNFu
- Nightmare Seeker (The Little Red House):   BShuzzZBgWEn4jA2Ar1JE2
- New Colossal Hate:                         RV2sX4tHoNpJJvU93wFXUP
- Ditch:                                     jdRPR9l3kxqGcnqV3FiyUl
- Grace:                                     MkR3LYIVCk1PWIv2aDynrY

### Navidrome IDs:
- Artist: 75hnOxk0lWjpINikF8enWg
- Playlist: KFWjmn6x9UrFjNEXEvJXEL

### Lidarr IDs:
- Artist: 190

## Acquisition strategy

All 15 tracks came from two torrents:

### PMEDIA discography pack (13 tracks)
- Torrent: "Lamb of God - Discography [FLAC Songs] [PMEDIA]" (hash `c6bca181ca1fc3ca1ad717dd398250e68ad78759`)
- Saves to: `/mnt/nas/downloads/music/Lamb of God - Discography [FLAC Songs] [PMEDIA] ⭐️/`
- Used qBittorrent file-priority API (indices 3,7,20,25,43,47,80,82,105,110,159,171,208)
- Contains albums through 2022 (Omens), but does NOT include Resolution (2012)
- The 10th Anniversary Edition of As The Palaces Burn is included — tracks tagged as "Purified (Remixed / Remastered)" and "In Defense Of Our Good Name (Remixed / Remastered)" in Navidrome

### Resolution (2012) — 2 tracks
- Torrent: "Lamb Of God - Resolution (2012) FLAC, lossless" (hash `89e512810c276b969f8ec349fc2a6bef5f1fe312`)
- Found on TPB with 15 seeds; saves to `/mnt/nas/downloads/music/Lamb Of God/2012 - Resolution/`
- Note: this torrent is named just "Lamb Of God" in qBittorrent
- Only downloaded Ghost Walking (index 4) and Straight For The Sun (index 12)

## NAS paths:
All files at `/mnt/nas/music/Lamb of God/{Album (Year)}/` (one FLAC file per album directory).

## Image URLs (Apple Music)
- Playlist cover: `SG-MQ-US-004-Image-000001/v4/c3/4a/7f/c34a7ff7-1f39-e382-e75e-5db5f8c73147/image/610x610bb.webp`
- Artist image: `AMCArtistImages221/v4/26/78/95/267895e0-865f-1797-698f-6b3e5af02ca6/ami-identity-5049f93e1a9d1de75a9e4b8321952b30-2026-01-15T14-25-31.040Z_cropped.png/486x486bb.webp`

## Key notes
- PMEDIA torrent has 6+ seeds and covers 2000–2022 discography (minus Resolution)
- Resolution (2012) missing from PMEDIA pack — needs separate torrent always
- "Purified" and "In Defense Of Our Good Name" from the 10th Anniv. Edition are already tagged "(Remixed / Remastered)" in the files, so Navidrome shows those names correctly
- TAA playlist cover: different image source than prior playlists — uses `SG-MQ-US-004-Image-000001` (not `SG-MQ-US-001-Image000001`)
