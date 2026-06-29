# 2026-06-26 TAA - Lorna Shore playlist

## What was worked on

### TAA - Lorna Shore playlist
- Parsed Liz's 14-track Apple Music playlist.
- Lorna Shore was not in Lidarr — added as artist ID 186 (foreignArtistId: e86fc1f5-d632-44b2-8aea-38f83aadffe8).
- Root folder for Lidarr is `/music/` (not `/mnt/storage/music/` — that path doesn't exist inside the container).
- Default metadata profile (ID 1 "Standard") excludes EPs. Switched to profile ID 5 "Catalog Import" (allows EPs) temporarily to get the EP to show up in Lidarr's album list.
- 4 releases needed: Flesh Coffin (2017), Immortal (2020), ...And I Return to Nothingness EP (2021), Pain Remains (2022).
- First grabs for Immortal and Pain Remains were instrumental editions (Lidarr auto-grabbed them). Blocklisted and re-searched.
- Pain Remains (2022) downloaded slowly (~2 hours total); intermediate check showed 27.4% but it kept progressing.
- All 4 releases downloaded and imported successfully.
- Created playlist `TAA - Lorna Shore`, ID `NFCFCL6utOrJylCTUARpB7`, 14 tracks, ~80 min. Cover uploaded.
- Artist profile image (from Featured Artist section in HTML) uploaded to Navidrome artist `7spA7yF4egsI66KYGgAeAA`.

### Track list:
1. Immortal — Immortal (2020)
2. Sun//Eater — Pain Remains (2022)
3. Of the Abyss — ...And I Return To Nothingness - EP (2021)
4. Cursed to Die — Pain Remains (2022)
5. ...And I Return to Nothingness — ...And I Return To Nothingness - EP (2021)
6. Into the Earth — Pain Remains (2022)
7. To the Hellfire — ...And I Return To Nothingness - EP (2021)
8. Pain Remains I: Dancing Like Flames — Pain Remains (2022)
9. Pain Remains II: After All I've Done, I'll Disappear — Pain Remains (2022)
10. Pain Remains III: In a Sea of Fire — Pain Remains (2022)
11. King Ov Deception — Immortal (2020)
12. Apotheosis — Pain Remains (2022)
13. Fvneral Moon — Flesh Coffin (2017)
14. Wrath — Pain Remains (2022)

### Navidrome track IDs:
- Immortal:                   YbA41f8ag3qrjuc192vQsj
- Sun//Eater:                 yKK8HtpcWBqs0D26xhvwi5
- Of the Abyss:               kkqyewL6yxSG6I703Sk0D0
- Cursed to Die:              MFJJ9MdjznJQatUIyvGkWA
- ...And I Return:            RpnlxqB1TXCB8A5Xm357N8
- Into the Earth:             ztelkXEMWeyQOEFiRCAq2t
- To the Hellfire:            Mmh1L0jIzNYVUhiP2LwU9g
- Pain Remains I:             Vv7ebVxcbPRx52wHskdJk1
- Pain Remains II:            4R6Di4yjIwszfSYD8SCrDp
- Pain Remains III:           XbviQqknR1VWL06mxcy9RC
- King Ov Deception:          WGdAeGcRzdY09ky9g2oOF9
- Apotheosis:                 Dk6VsulcLeyUfeciIDG9Vk
- Fvneral Moon (FVNERAL MOON): gOynASXGLTb4uI7qNGUn3S
- Wrath:                      FqwUVUUMGSieghkIf7Iyto

## Key insights
- Lidarr root folder path inside the container is `/music/` (NOT `/mnt/storage/music/`).
- Default metadata profile (ID 1) excludes EPs. Profile ID 5 "Catalog Import" includes EPs. Switch artist to profile 5 before RefreshArtist to get EP albums to appear.
- Navidrome playlist cover upload uses field name `image` (NOT `file`) — `POST /api/playlist/{id}/image` multipart with field `image`.
- Artist image upload also uses field name `image` — `POST /api/artist/{id}/image` multipart with field `image`.
- The ...And I Return To Nothingness EP tracks (Of the Abyss, ...And I Return to Nothingness, To the Hellfire) are ALSO included as tracks 11-13 on the full Pain Remains (2022) album. Use the EP versions per Apple Music playlist source.
- "FVNERAL MOON" is all-caps in the file tags (tracks as imported). Navidrome shows it exactly as tagged. Apple Music shows "Fvneral Moon". These are the same track.
- Lidarr may auto-grab instrumental editions over regular albums if instrumentals have more seeds — blocklist and re-search.

## Decisions
- No YouTube fallbacks needed — all tracks were in Navidrome after downloads completed.
- Kept metadata profile ID 5 "Catalog Import" for Lorna Shore permanently (so the EP stays managed by Lidarr).

## Open questions / next steps
- Next TAA playlist when Liz provides one.
