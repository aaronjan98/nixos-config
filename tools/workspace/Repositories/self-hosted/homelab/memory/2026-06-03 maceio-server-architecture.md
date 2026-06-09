# 2026-06-03 — Maceió (Brazil) server architecture finalized

Afternoon session (~10:30–11:30 PT). Pure planning + plan-doc work,
no production system changes.

## What was worked on

Iterated on the Maceió box plan multiple times based on AJ's feedback,
landing on a final architecture meaningfully different from what the
`maceio-server-plan.md` doc had previously sketched (which was option-
shopping across A–E). The doc was rewritten end-to-end to reflect the
new shape. Also verified specific plugin/API behavior in upstream
source before committing to webhook-driven triggers.

## Final architecture (decided)

- **Two sovereign libraries** (AJ's on qwerty, Liz's on Maceió). Liz's
  Firestick connects to her local Jellyfin on LAN for everything she's
  pulled; her existing Jellyfin account on AJ's server stays in use via
  Tailscale on the Firestick but only as the **back-catalog browser**.
- **No Tailscale on Maceió, no Tailscale on oreos.** Only outbound-only
  patterns (rsync pull, Borg push) plus a single-peer WireGuard server
  for AJ as Brazilian exit node.
- **No *arr stack on her side.** No custom UI either. Two webhook-driven
  rsync triggers handle population:
  - **New content**: Sonarr/Radarr `Connections → OnImport` webhook →
    bash script on qwerty filters by Seerr requester == Liz → rsync the
    imported directory to Maceió.
  - **Back-catalog**: AJ's Jellyfin runs `jellyfin-plugin-webhook` on
    `UserDataSaved`. Handlebars filter matches
    `User.Id == LIZ_ID && SaveReason == "UpdateUserRating" && IsFavorite == true`
    → same script (different branch) rsyncs to Maceió.
- **Transfer direction**: Maceió pulls from qwerty over SSH (port 2220 is
  already exposed). Outbound only from her box; no port-forwards on her
  router.
- **Storage check before rsync**: script compares `du -sb` source size
  against `df --output=avail` on Maceió, 20 GB safety margin, blocks
  transfer and Pushbullets AJ if insufficient. She gets Jellyfin admin
  on her own server so she can delete media from Jellyfin UI directly
  (no SSH required).
- **Borg backup target for AJ.** Geographic complement to oreos.
- **Book server**: Calibre-Web on each side, books folder mirrored via
  Syncthing, **`metadata.db` excluded from sync** so each side has
  independent metadata catalog. Same qwerty Syncthing daemon — just add
  Maceió as a new device, share only the books folder with it. Syncthing
  uses its own discovery/relay so doesn't need Tailscale.
- **Hardware**: buy locally in Maceió during July 2026 trip — used
  Dell OptiPlex Micro / Lenovo M720q Tiny / HP EliteDesk Mini on
  Mercado Livre or OLX Brasil. Inspect-before-pay avoids US-Brazil
  customs duties (~60%) entirely.

## Key insights

- **Seerr's Watchlist has no webhook event.** Verified by reading
  `server/lib/notifications/index.ts` in the `Fallenbagel/jellyseerr`
  repo. The Notification.Type enum covers media lifecycle and issues
  only; no `WATCHLIST_*` events fire. This means "use Add to Watchlist
  as the back-catalog trigger" — which sounded clean — is unworkable
  without polling or proxy interception. Forces the trigger onto
  Jellyfin's Favorite mechanism instead, which is actually a better
  primitive because favorites live on the server she's already browsing.
- **Seerr's Watchlist also doesn't trigger Sonarr/Radarr requests.**
  `server/entity/Watchlist.ts:createWatchlist` is pure DB CRUD; no
  `MediaRequest.request()` call. So watchlisting is decoupled from
  requesting — answered AJ's worry that "if she watchlists it might
  download." It won't.
- **Jellyfin Webhook plugin's `UserDataSaved` payload includes
  `SaveReason` + `IsFavorite` + `UserId`.** Confirmed in
  `Notifiers/UserDataSavedNotifier/UserDataSavedNotifierEntryPoint.cs`.
  `SaveReason == "UpdateUserRating"` is the discriminator that isolates
  favorite-toggle from played-state-change. This is the linchpin: the
  whole no-custom-UI architecture depends on this single field
  existing in the payload.
- **Project naming**: Seerr (rebranded from Jellyseerr). Source repo
  still `Fallenbagel/jellyseerr` for now but docs at `docs.seerr.dev`.
  Use "Seerr" in any user-facing wording going forward.
- **Router (RP5/OpenWrt at 10.0.50.1) is not RAM-constrained.** AJ's
  intuition was that the home router was "capping at 8 GB." Live check:
  `free` reports `used: 73 MB / 8 GB`, load avg `0.00 0.00 0.00`,
  uptime 10 days. Doesn't justify a 16 GB box for the Maceió hardware
  on those grounds. Whatever AJ was noticing (if anything) is not a
  memory pressure issue.
- **Hardware sourcing reality**: Brazilian customs on declared
  electronics is ~60% federal + state. Anything sealed in retail
  packaging looks like commercial import. Local Mercado Livre / OLX
  pickup during the July trip side-steps the entire issue and gives
  hands-on inspection.
- **"Federation" and "CDN" framings were both misleading.** Jellyfin
  has no federation protocol; "CDN" implies many-clients-per-object
  economics that don't hold for one viewer. The actually-correct
  framing is "two independent Jellyfin instances + on-demand rsync of
  specific items."

## Decisions

- No Tailscale on Maceió or oreos. oreos role unchanged (arrs-vm WG
  egress + Immich Borg target).
- No *arr stack on Maceió. Population is rsync-driven via the two
  webhooks.
- No custom UI. Both triggers are existing webhook events from
  off-the-shelf plugins.
- Liz is admin on her own Jellyfin (not on AJ's). She uses Jellyfin's
  own delete-media UI rather than a separate Homepage/Glances dashboard.
- Book server uses Calibre-Web on each side with per-side `metadata.db`
  exclusion in Syncthing.
- Buy hardware in person in Maceió during July 2026 trip. Used SFF
  business desktop, not Pi 5, not bring-from-US.

## Open questions / follow-ups

- **AJ's book server + obo sync project** — separate, AJ-server-only
  project that AJ wants to pick up next. Not yet investigated; user
  asked the agent to get familiar with the docs/roadmap and report.
  Listed as the immediate next task after this session save.
- **Storage sizing for Maceió library.** 2 TB SATA SSD is the current
  assumption. May want larger if back-catalog binges fill it. Disk-
  pressure check in the rsync script covers the runtime case, but the
  initial sizing is open.
- **What gets backed up to the Maceió Borg target?** At minimum mirror
  what oreos receives (Immich + DB dumps). Could add configs, docs.
  Decide before the July trip.
- **WireGuard exit-node use case frequency.** If AJ has near-zero
  Brazilian-IP needs in practice, skip this role at deploy time.
- **Existing Jellyfin "Server Unavailable" issue** was already resolved
  2026-06-02 (the 80 GB NVMe LV migration). Agent had stale info from
  the prior conversation summary and incorrectly listed it as still
  open; corrected mid-session. Not a follow-up.

## Files touched this session

- `Raymer/project-memory/maceio-server-plan.md` — full rewrite. New
  architecture, verified plugin behavior section, edge-case handling
  with storage check, new book-server section, "out of scope" with
  decided-against options and reasons, updated sequencing list.

## Next steps

1. Investigate `Raymer/ROADMAP.md` and project-memory for AJ's
   **book server + obo sync** project. Report what's already
   captured. AJ-server-only — distinct from the Maceió book-server
   work above.
2. All Maceió implementation work waits for the July 2026 trip
   (hardware purchase in person, then sequence steps 2–8 in the plan
   doc).
