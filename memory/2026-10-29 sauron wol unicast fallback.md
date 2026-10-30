# 2026-10-29 — Sauron Wake-on-LAN fails over Tailscale; added unicast fallback

## What was worked on
Super+X (`ocr-custom-split-sauron`) failed to wake Sauron while the user was on campus
wifi, away from home. `prepare_sauron()` in `tools/scripts/ocr-custom-split.py` calls
`wol-sauron` then polls SSH for up to 90s, retrying per crop — logs in the attempt at
`~/.local/share/ocr-captures/attempts/2026-10-29T14-12-10.053741-0700_custom/backend.log`
showed "waking Sauron" firing 5 times (once per display/inline crop), each followed by
"Sauron SSH did not become ready" after the full 90s wait — ~8 minutes total, no result.

## Diagnosis path
1. Ruled out DNS/routing as the blocker: `sauron.home` resolves via Tailscale MagicDNS
   to its real LAN IP `10.0.50.213`; `ip route show table all` confirmed the
   `10.0.50.0/24` route IS installed (table 52, via the `sweetpea` Tailscale subnet
   router) — `services.tailscale.extraSetFlags` with `--accept-routes` in
   `hosts/common/default.nix` is working as intended on this host (ThinkPad T14,
   tailscale hostname `nixos`). `framework-13` deliberately overrides this to
   `--accept-routes=false` since it lives ON that LAN itself (see comment there).
2. `journalctl -u tailscaled` showed real attempts: `open-conn-track: timeout opening
   (TCP ... => 10.0.50.213:22) to node [Rjoy9]` — unicast traffic genuinely reaches the
   subnet-router path and times out waiting for Sauron itself, confirming unicast
   forwarding works fine.
3. Root cause: `wol-sauron` (`modules/wol-sauron.nix`) only sent the magic packet to the
   **broadcast** address `10.0.50.255`. Linux routers (sweetpea) do not forward directed
   broadcasts onto a physical LAN by default (`bc_forwarding` off) — so the magic packet
   was silently dying at sweetpea every time this ran over Tailscale, regardless of
   retries/wait time. This is a known class of problem ("WoL doesn't work across a
   router/VPN") with a standard fix: send the magic packet as **unicast** directly to the
   target's IP instead — normal unicast IP forwarding applies, no special sysctl needed.

## Decision
Edited `modules/wol-sauron.nix` to send the magic packet twice: once broadcast to
`10.0.50.255` (works when physically on the home LAN) and once unicast to Sauron's LAN IP
`10.0.50.213` (works when routed in over Tailscale from anywhere else). Verified with
`nix flake check --no-build` (clean), then the user ran `nixos-rebuild switch` themselves
to apply it.

## Open questions / next steps
- Not yet re-tested end-to-end (next Super+X attempt from off-site should confirm the
  unicast packet actually wakes Sauron).
- If unicast WoL still fails: check whether sweetpea even has a fresh ARP/neighbor entry
  for Sauron's MAC while it's powered off — some switches/routers drop ARP entries for
  machines that have been down a while, which would stop a unicast-addressed magic
  packet from resolving to the right Ethernet frame even though IP routing is fine.
