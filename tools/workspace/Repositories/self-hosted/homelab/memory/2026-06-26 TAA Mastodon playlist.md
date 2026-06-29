# 2026-06-26 TAA - Mastodon playlist

## What was worked on

### TAA - Mastodon playlist
- Parsed Liz's 15-track Apple Music playlist.
- Mastodon was not in Lidarr — added as artist ID 187 (foreignArtistId: bc5e2ad6-0a4a-4d90-b911-e9a7e6861727).
- All 8 needed albums were present in Lidarr after artist add (no EP metadata profile issue this time).
- Two albums downloaded as single-FLAC+CUE (Lidarr can't import these): Once More 'Round the Sun and Hushed and Grim. Blocklisted and re-grabbed — got properly split FLAC on retry.
- Also: one stalled PMEDIA grab for Hushed and Grim (warning status) — blocklisted immediately.
- All 8 albums imported successfully. Created playlist `TAA- Mastodon`, ID `xiUBZ7uYVQw8uuQWYRXyan`, 15 tracks, ~57 min.
- Cover and Mastodon artist image (ID `2r2X1J1bHG6DvfZuXogofP`) uploaded.

### Track list:
1. Blood and Thunder — Leviathan (2004)
2. Pain with an Anchor — Hushed and Grim (2021)
3. Divinations — Crack the Skye (2009)
4. I Am Ahab — Leviathan (2004)
5. Hand of Stone — Blood Mountain (2006)
6. Where Strides the Behemoth — Remission (2002)
7. Island — Leviathan (2004)
8. Blasteroid — The Hunter (2011)
9. More Than I Could Chew — Hushed and Grim (2021)
10. High Road — Once More 'Round the Sun (2014)
11. Iron Tusk — Leviathan (2004)
12. Sultan's Curse — Emperor of Sand (2017)
13. Bedazzled Fingernails — The Hunter (2011)
14. Pushing the Tides — Hushed and Grim (2021)
15. March of the Fire Ants — Remission (2002)

### Navidrome track IDs:
- Blood and Thunder:          wX3HXMgpbtPvilPKBZutLs
- Pain with an Anchor:        PQEx9Pp67mEhXV5jUqreoa
- Divinations:                27a55NyGHoSTtexTYHNQsj
- I Am Ahab:                  55FT2fBqqUZpLGtlPAskTB
- Hand of Stone:              Y1R58HSCIf9bxMHGpa299Y
- Where Strides the Behemoth: khxCt1smJhus1gNrhzBMo3
- Island:                     vWXsW45hvVKui9IjdRE0bi
- Blasteroid:                 9yt1Wx0zHfhltjyaq9leWH
- More Than I Could Chew:     KZdq9GSzutl597yjZmAH9l
- High Road:                  qy8FBYVVHtO41Eguz4DV3A
- Iron Tusk:                  3dgT4nvX6m3ps80YZVPWbh
- Sultan's Curse:             z0QBSNSM8H3ofKvApqAjrh
- Bedazzled Fingernails:      qKiV5hebzpyEqsPDgMIFxx
- Pushing the Tides:          uVooSqV5zfiIr7VondLBm5
- March of the Fire Ants:     Y1vaS6LtsdpNSq40Iny0tY

### Navidrome artist ID: 2r2X1J1bHG6DvfZuXogofP

## Key insights
- Single-FLAC+CUE downloads (image rips) are a recurring Lidarr import failure. Blocklist and re-search immediately — don't try to manually split. A proper multi-track release almost always exists.
- PMEDIA releases in Lidarr queue tend to be single-FLAC or stall on warning status — blocklist on sight.
- Hand of Stone imported under "Blood Mountain [Japanese Release]" — the album name had a suffix. Search without album filter as fallback works fine; Navidrome found it correctly.

## Decisions
- No YouTube fallbacks needed — all tracks found after re-grabs.
- Kept both Hushed and Grim (24bit-48kHz) and Once More 'Round the Sun (Vinil Rip) — both imported cleanly as split tracks.

## Open questions / next steps
- Next TAA playlist when Liz provides one.
