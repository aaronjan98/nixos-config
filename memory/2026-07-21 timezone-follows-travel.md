# 2026-07-21 — Timezone follows physical location (travel)

## Problem
Quickshell top-right island clock showed Los Angeles time while travelling to
Maceió (Brazil). Root question: why, and make it track local time anywhere.

## Diagnosis
- `Clock.qml` was not hardcoded to LA. It used `Qt.formatDateTime(new Date(), …)`,
  which renders in the **system** timezone.
- System zone was pinned declaratively: `time.timeZone = "America/Los_Angeles"` in
  `hosts/common/default.nix`. Because it was declarative, even `timedatectl
  set-timezone` would fail at runtime.
- Deeper issue for a live-updating clock: a long-lived process (quickshell) caches
  the zone glibc/Qt read at **process start**, so `new Date()` never reflects a zone
  change mid-session — it would need a restart.

## What was done (Option B — location-following, event-driven)
1. `hosts/common/default.nix`:
   - `services.automatic-timezoned.enable = true;` — GeoClue2 (WiFi geolocation via
     BeaconDB, the live successor to the dead Mozilla Location Service; it's the
     nixpkgs `geoProviderUrl` default) + systemd-timedated update the zone at runtime
     on network-change events. Event-driven, not polling; no reboot.
   - `time.timeZone = lib.mkDefault "America/Los_Angeles";` — the module itself sets
     `time.timeZone = null`; mkDefault avoids the conflict error the module raises and
     leaves a fallback zone if the service is ever disabled.
   - Applies to both laptops (framework-13, thinkpad-t14) — both import common. There
     is no stationary host: home-assistant runs ON framework-13.
2. `~/.config/quickshell/.../widgets/Clock.qml` (dotfiles / `dot` repo) — hardened so
   the running bar reflects zone changes with no restart:
   - Renders from absolute epoch shifted by a live UTC offset (so it never trusts the
     process-cached zone).
   - Offset refreshed by a fresh `date +%z` subprocess, triggered by: startup, a
     `FileView` watching `/etc/localtime` (`onFileChanged` — fires the instant the OS
     zone swaps), and a 5-min safety timer (covers DST, which doesn't touch the
     symlink, and any missed watch event). Per-second display tick stays in-process.

## Key insight
The clock is a *mirror* of the OS zone; the fix is two-layered — make the OS zone
follow location (automatic-timezoned) AND make the long-lived bar re-read the zone on
change (FileView event → subprocess re-probe), since glibc/Qt cache it at startup.

## Deliberately left alone
`modules/home-assistant.nix` keeps HA's own `time_zone = "America/Los_Angeles"`. That
is the automation engine's timezone (sunrise/sunset, house schedules) and should stay
on **home** time even as the laptop's OS clock follows travel.

## Verification
User ran `nrt` (nixos-rebuild) — the clock updated to local time live, WITHOUT
restarting quickshell. Confirms the FileView event path + quickshell live-reload work
end to end. qmllint (with proper import paths) reported Clock.qml clean; `nix eval`
confirmed `time.timeZone → null`, `automatic-timezoned.enable → true`,
`geoclue2.enable → true`, provider = beacondb.

## Notes / open questions
- Offline (e.g. on the plane) the zone won't change until online at destination — expected.
- No revert needed on returning home — that's the point of Option B (auto-follows back).
- If the zone doesn't update at a destination, check: network up, `systemctl status
  automatic-timezoned geoclue`, and that BeaconDB is reachable.
