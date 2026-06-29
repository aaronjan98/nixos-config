# 2026-06-27 TAA - Whitechapel playlist

## What was worked on

### TAA - Whitechapel playlist
- Parsed Liz's 14-track Apple Music playlist (artist: Whitechapel, ~60 min / 3606 seconds).
- Whitechapel was entirely absent from NAS/Navidrome/Lidarr — full acquisition required.
- Added Whitechapel to Lidarr as artist ID 191 (foreignArtistId: `56ba013c-610e-4d9b-98ed-c2ccff977a9e`).

### Track list (Liz's order):
1. I, Dementia — Whitechapel (2012)
2. Psychopathy — Our Endless War (2014)
3. A Killing Industry — Mark of the Blade (2016)
4. Lost Boy — Kin (2021)
5. Breeding Violence — A New Era of Corruption (2010)
6. Black Bear — The Valley (2019)
7. Elitist Ones — Mark of the Blade (2016)
8. Kin — Kin (2021)
9. Possession — This Is Exile (2008)
10. I Will Find You — Kin (2021)
11. Articulo Mortis — The Somatic Defilement (Remastered) (2013)
12. Mark of the Blade — Mark of the Blade (2016)
13. Make It Bleed — Whitechapel (2012)
14. Anticure — Kin (2021)

### Navidrome track IDs:
- I, Dementia:                    AFsDEGktc2gPyynfzNqCOQ
- Psychopathy:                    vEWNomcBleKjfU2f4tud7h
- A Killing Industry:             fNyuQxbQA8az0ReylymAxO
- Lost Boy:                       yNs5a5dTwfy9ErbT7Jw5gB
- Breeding Violence:              QoJoLQWRW4CUcVAhAeyJum
- Black Bear:                     Mz68y719L4JaK7ohf5AOq3
- Elitist Ones:                   ji5rEUIFsBzWyXRLO4UIxI
- Kin:                            4FgEE5EeRSJrpYG62G5Bql
- Possession:                     gZSzU4lzMxF1tucNhenZ9r
- I Will Find You:                aJQOJdjxVMnRSLdgSnnUx3
- Articulo Mortis:                3A47i92O2ame41q2IM9Gpz
- Mark of the Blade:              T7DM72kf5VyQfbEdj45xhn
- Make It Bleed:                  Vd0hrVRD3qXm4uPYhIeQop
- Anticure:                       OG7ELcTdexDvHSYUMrgFWf

### Navidrome IDs:
- Artist: 7GUkArn4qtEb0KdFh5DYAh
- Playlist: bSDnfUoTBI2UGWaM6INpTc

### Lidarr IDs:
- Artist: 191

## Acquisition strategy

All 14 tracks came from two torrents:

### Discography pack (13 tracks)
- Torrent: "Whitechapel Discography 2007-2025 FLAC" (hash `3c42efc7cc7df93b275739c0fe42acfc1c7cecf4`)
- Source: limetorrents (7 seeds at search time, 1 actually connected)
- Magnet extracted from limetorrents page GUID
- Saves to: `/mnt/nas/downloads/incomplete/music/Whitechapel - Discography 2007-2025 FLAC/`
- Used qBittorrent file-priority API to download only needed indices:
  23, 35, 68, 71, 94, 113, 114, 117, 143, 151, 152, 154, 161
- Notable: this pack uses Japan Edition of Whitechapel (2012) and Deluxe Edition of Mark of the Blade (2016) — that's fine, same tracks

### Our Endless War (2014) — Psychopathy
- Torrent: "Whitechapel - Collection (FLAC)" — 2-album set with Our Endless War + Mark of the Blade
- Hash: `4eae4b8cb5dbffa410af2a6a9dd407a9d5258d0b`
- Source: RuTracker (5 seeds), magnet via Prowlarr redirect
- Saves to: `/mnt/nas/downloads/incomplete/music/Whitechapel - Collection (FLAC)/`
- Only downloaded: `2014 - Our Endless War/08 Psychopathy.flac` (index 17)
- Note: Our Endless War is absent from the main discography pack

## NAS paths:
All files at `/mnt/nas/music/Whitechapel/{Album (Year)}/` (one FLAC file per album directory).

## Image URLs (Apple Music)
- Playlist cover: `SG-MQ-US-032-Image000001/v4/e7/59/88/e7598882-f733-ce3c-c29e-39238d0e2ef7/image/610x610bb.webp`
- Artist image: `AMCArtistImages221/v4/96/c7/68/96c768af-e4fd-ca17-8577-6677c52ae3aa/ami-identity-e688949b297c69940c024274423c4cc6-2025-01-17T02-21-49.671Z_cropped.png/486x486bb.webp`

## Key notes
- Our Endless War (2014) is NOT in the discography pack — always needs a separate torrent
- The discography pack contains 2007-2025 including Hymns in Dissonance (2025)
- Background copy monitor (python3 nohup) was used to auto-copy files as they completed
- Download was slow (~110 KB/s, 1 active seed) — took ~45 min total for 13 tracks
- Playlist cover uses `SG-MQ-US-032-Image000001` (different number from prior TAA playlists)
