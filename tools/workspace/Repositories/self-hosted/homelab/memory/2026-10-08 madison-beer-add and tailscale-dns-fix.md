# 2026-10-08 — Madison Beer add + lyrics offset fix + Tailscale/Symfonium DNS fix

## What was worked on

### Madison Beer — "Make You Mine" added to Navidrome
- Downloaded official audio from YouTube (`dqJDlRM5Jf4`, Madison Beer's own channel) via the
  established mweb/format-18 PO-token fallback. Hit the usual 403 on the default client; fix
  was exporting `PATH="$HOME/.deno/bin:$PATH"` (deno isn't on PATH in non-interactive SSH
  shells on qwerty) and passing `--js-runtimes deno --extractor-args "youtube:player_client=mweb" -f 18`.
- Lyrics: queried lrclib, found ~6 independent submissions all agreeing (0.89–1.0 word-overlap
  with each other) — strong confidence signal the text itself is correct, used the same
  word-overlap cross-check technique as the SHAUN verification earlier in the day but applied
  it between candidates instead of against an ASR transcript.
- Cover art: pulled from MusicBrainz Cover Art Archive (release `377f62b5-...`), 3000x3000 front.
- Final file: `/mnt/storage/music/Madison Beer/Make You Mine (2024)/01 - Make You Mine.flac`,
  owned `114:statd`.

### Lyrics timing fix — offset vs. true DTW (important distinction clarified)
User reported the Madison Beer lyrics "come a bit too soon." Compared to the PIXY LEGACY case
earlier in the day (which needed full chroma-feature DTW alignment because that edit was
genuinely time-compressed/non-uniform), this one was diagnosed differently:
- Checked silence boundaries at both the start (`ffmpeg silencedetect`) and the end of the
  downloaded audio, and compared both to the LRC's first/last timestamps.
- Offset was ~0.68s at the start and ~0.74s at the end — i.e. **constant**, not growing. That's
  the tell for "extra intro padding on this particular rip" rather than real tempo/time
  compression.
- Fix: a single global `+0.71s` shift applied to every LRC timestamp (regex replace), not DTW.
  Re-embedded, rescanned, confirmed against the detected silence boundaries.
- **General lesson for future lyric-sync issues**: before reaching for chroma-DTW, check
  whether the drift is constant across the track (global offset — simple shift) or grows/shrinks
  (real tempo mismatch — needs DTW). DTW on a constant-offset case is overkill and risks
  inventing spurious mappings in quiet intro/outro regions, which is exactly what happened and
  had to be manually corrected during the PIXY LEGACY fix.

### Tailscale / Symfonium remote-access diagnosis — corrected
User reported Symfonium (and, it turned out, ALL `.home` services) unreachable from the phone
over Tailscale away from home, but fine at home and fine from the laptop away from home.

**My initial diagnosis was wrong.** I assumed the phone was missing "Use Tailscale Subnets"
(accept-routes) — this was a real, previously-documented open gap for this exact phone
(`Raymer/docs/tailscale.md` "Known gaps" listed it), and verified via `tailscale status --json`
that the phone's peer entry only had its own /32, consistent with that theory. Recommended
toggling "Use Tailscale Subnets" in the Android app.

**Actual fix (confirmed by user): disabling "Use Tailscale DNS" in the Android Tailscale app**
resolved it — the opposite of what the architecture doc's split-DNS design would predict (split
DNS is implemented by pushing a custom nameserver + search domain through Tailscale's DNS
mechanism, which *requires* "Use Tailscale DNS" to be on). This means on Android, something
about the "Use Tailscale DNS" path was broken/misbehaving for this phone specifically — the
accept-routes gap may or may not still exist on the phone, but it wasn't the actual blocker.

**Open question / follow-up needed:** `Raymer/docs/tailscale.md` currently describes split DNS
as requiring "Use Tailscale DNS" enabled on the client. That doc needs a corrective note for
Android: at least on this phone, enabling "Use Tailscale DNS" broke `.home` resolution/routing
rather than enabling it, and disabling it fixed remote access. Did not get to root-cause *why*
(possible Android-side Private DNS conflict, or an Android Tailscale app quirk around domain-
restricted custom nameservers) — worth a closer look next time this phone's networking comes up,
and the "Known gaps" list in that doc should be corrected: the actual missing gap, if any
remains, is not confirmed to be the subnet-routes toggle after all.

## Decisions
- Lyrics-timing troubleshooting default: check for constant vs. growing offset first; only use
  chroma-DTW when the gap genuinely grows/shrinks across the track.
- Do not trust `Raymer/docs/tailscale.md`'s Android DNS guidance at face value for this phone —
  empirically, disabling "Use Tailscale DNS" was the fix, contradicting the documented design.

## Next steps
- Someone (AJ or a future session) should update `Raymer/docs/tailscale.md`'s "Known gaps" /
  Android section with this correction, and ideally root-cause why "Use Tailscale DNS" broke
  things on this phone rather than just leaving the contradiction undocumented.

## Correction (2026-10-09)
The "actual fix" above was **wrong and has been retracted by the user**: "Use Tailscale DNS"
does need to be **on** for remote `.home` access to work — matching the original documented
design, not contradicting it. The user re-tested and confirmed the earlier report (disabling
it fixed things) was backwards. `Raymer/docs/tailscale.md` has been corrected accordingly (the
"Android gotcha" callout and the "Known gaps" phone entry both now say DNS must stay on, and
flag the real root cause of the original "works at home, fails away" symptom as still
unconfirmed — not the DNS toggle, and not confirmed to be the accept-routes/subnet-routes gap
either). Lesson: don't lock in a root cause from a single user-reported toggle flip without a
second confirmation, especially for an intermittent network symptom — this one flipped twice.
