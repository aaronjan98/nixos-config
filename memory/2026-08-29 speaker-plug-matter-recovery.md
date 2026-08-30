# 2026-08-29 — Speaker Kasa plug went unavailable: 4-layer root cause + durable fixes

The desk-speaker Kasa plug (`switch.kasa_smart_wi_fi_plug`, KP125M, MAC `20E15D9E1D12`,
`10.0.50.124`) dropped to `unavailable` in Home Assistant and the `speakers` alias /
orchestrator `speaker_power` tool stopped working. It took a long debug because **four
independent problems stacked up the same day**. Recovered end-to-end (on→off→on verified).

## The four layers (in the order they had to be peeled)

1. **Tailscale subnet-route hijack (unicast black-hole).**
   sweetpea advertises `10.0.50.0/24` as a tailnet subnet route (so travel laptops reach
   home devices when away). framework-13 had `--accept-routes` on (from `hosts/common`),
   so it accepted a route for the LAN it's *physically* on. `ip rule` `from all lookup 52`
   sent `10.0.50.124` out `tailscale0` instead of `wlp192s0` → no ARP, ping TTL 254,
   matter-server's traffic to the plug tunnelled away. Runtime fix:
   `sudo tailscale set --accept-routes=false`.

2. **Deco reboot left the mesh degraded → cross-band mDNS multicast stopped.**
   framework-13 (5 GHz `Connect here`) stopped hearing the plug (2.4 GHz
   `Connect here_IoT`). Unicast/ARP crossed fine (same subnet `10.0.50.0/24`), but
   multicast (mDNS `224.0.0.251`) did not — an AP handles broadcast vs multicast
   differently, and the soft reboots didn't re-form the mesh. A **full cold power-cycle
   of the Deco** fixed it (framework-13 then heard the whole LAN over mDNS again). NOTE
   for the deco-reboot project: the *soft* API reboot is NOT a substitute for a power
   cycle when the fault is radio/mesh-level.

3. **IPv6 got auto-disabled on `wlp192s0` — the real Matter killer.**
   `net.ipv6.conf.wlp192s0.disable_ipv6=1` (global/`all`/`default` were 0). Matter runs
   over **IPv6 link-local**; with it off, matter-server got
   `SendMessage to [fe80::…] failed: Network is unreachable`. During commissioning that
   forced a retry which tripped a python-matter-server 8.1.1 bug
   (`Returned Node ID must match requested Node ID`, 3 vs 4) that discarded the node.
   Cause: the MT7925 flapping during the degraded window → link-local DAD failure →
   kernel auto-disabled IPv6. Runtime fix: `sudo sysctl -w …wlp192s0.disable_ipv6=0`
   (came back with a `fe80::` link-local, which is all Matter needs).

4. **The plug had been factory-reset out of the Matter fabric.**
   Re-adding it in the Kasa app factory-resets the device, wiping HA's Matter fabric
   membership (advertises `_matterc`, no operational `_matter._tcp`). So it needed a full
   **re-commission**, not just rediscovery. (Same thing that removed the deco plug's
   node 2 earlier — see [[2026-08-29 deco-router-plug-matter-commissioned]] in the
   voice-assistant repo.)

## Recovery sequence that worked

Fix routing (accept-routes off) → cold-boot Deco (multicast back) → enable IPv6 →
remove the two stale/half-committed fabric nodes (`remove_node`) → Kasa remove/re-add to
open a fresh commissioning window → `commission_with_code 2628-530-5721` (network_only).
With IPv6 up it paired cleanly on the first try: **node_id=6, available=true**, HA
recreated `switch.kasa_smart_wi_fi_plug` (clean id, no `_2`).

## Durable fixes committed (this session)

- **`hosts/framework-13/configuration.nix`**: `services.tailscale.extraSetFlags =
  lib.mkForce [ "--accept-routes=false" "--operator=aj" ]`. framework-13 is always home
  and on `10.0.50.0/24`, so it must not import the tailnet route for its own LAN. Travel
  laptops keep `--accept-routes` (unchanged). Without this the `tailscaled-set` unit
  re-adds `--accept-routes` on every boot and the hijack returns.
- **`modules/wifi-reliability.nix`**: keep IPv6 alive on `wlp192s0` — a NetworkManager
  dispatcher forces `disable_ipv6=0` + `accept_dad=1` on every up/dhcp/connectivity
  event, and the existing net-watchdog re-asserts it after any NM restart / mt7925e
  reload (the exact flaps that auto-disable it).

## To activate / remember

- Needs `nrt` (nixos-rebuild switch) to install the dispatcher + persist the tailscale
  flag. Runtime state already matches, so no behavior change on switch — just durability.
- Matter needs IPv6 + working multicast + the plug on a segment framework-13 shares mDNS
  with. Long-term, wiring framework-13 (Ethernet) would remove the WiFi-multicast and
  IPv6-flap fragility entirely (user can't wire it currently).
- Don't remove/re-add the plug in the Kasa app casually — it factory-resets Matter and
  forces a re-commission.
- matter-server WS helper approach (no client CLI): reuse the
  `python-matter-server-8.1.1` interpreter + its bundled aiohttp to talk
  `ws://localhost:5580/ws` (`get_nodes`, `discover`, `commission_with_code`,
  `remove_node`, `interview_node`).
