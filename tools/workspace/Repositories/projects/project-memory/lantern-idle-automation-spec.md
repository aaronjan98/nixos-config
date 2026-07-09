# LANtern — Idle-Gated Maintenance Automation (spec)

Status: **DRAFT / planning** (2026-07-06). No code yet. Actuator (Kasa plug + reboot
script) is built and validated; the "brain" (activity oracle + gated schedulers) is
specified here.

Parent project: **LANtern** (`~/Repositories/projects/project-memory/network-homelab-monitor.md`,
repo github.com/aaronjan98/LANtern). This automation is **LANtern's first working
vertical slice**, not a separate project — see "Relationship to LANtern" below.

---

## 1. Purpose

Run disruptive maintenance jobs (Deco reboot, SnapRAID sync, future others) **only when
nobody is actively using the internet or the homelab services**, deciding programmatically
instead of on a blind fixed-time cron — so real people are never interrupted, while
uptime and data-parity are still kept current.

Design principle (agreed with AJ): **deterministic rules at the core, AI layer on top.**
The idle gate and job logic are plain, reliable rules. The LLM / smart-speaker layer sits
*above* for narration, questions ("who's online right now?"), and human-approval prompts —
never in the safety-critical "should I cut power" path.

**No deadline fallback** (AJ's call): it's a low-user homelab, idle windows always come.
Jobs **postpone-and-recheck indefinitely** until idle. Nothing ever force-runs during use.

---

## 2. Relationship to LANtern (and the smart-speaker project)

- **This IS LANtern's first slice.** LANtern's core is sensing the network (presence,
  per-device traffic, service use, degradation) — which *is* the activity oracle's data
  layer — plus a controls layer (WOL/firewall/etc.), of which "power-cycle the AP" and
  "trigger a gated job" are instances. Building this standalone would duplicate LANtern.
- **Built lightweight first.** Implement with direct signal reads (conntrack, Jellyfin
  API, nfsd counters) so it delivers value *now* without waiting on the full
  Prometheus/Loki/Grafana/Ollama stack. As LANtern's richer data layer lands, the oracle
  graduates to reading from it.
- **The smart-speaker is a SEPARATE downstream project** that consumes LANtern's API:
  voice I/O + a **device→person identity map** so it can answer "who (a *person*) is online
  and what are they doing." That identity layer belongs in LANtern (both the speaker and a
  "who's online" query need it); the speaker is just a consumer.

---

## 2.5 RECONCILIATION (2026-07-06): LANtern Phase 1 is ALREADY DEPLOYED

Discovered on takeover — Phase 1 is not scaffolding, it's **live (4 weeks)** at
**`/opt/lantern`** (git repo; remotes `home` Forgejo + `hub` github.com/aaronjan98/LANtern;
clean + fully pushed):
- **docker-compose** runs 5 services: `dnsmasq-ingest`, `netflow`, `inventory`
  (build → `lantern:latest`), plus **`api`** (FastAPI) and **`ui`** (React/Vite/TS).
- **SQLite** `/var/lib/lantern/lantern.db` — **~3.3 GB, 4 weeks of data, actively written.**
- Ingest: dnsmasq log (per-client DNS), DHCP leases + OUI (device inventory), **NetFlow v9
  from RPi5 `softflowd`** (per-device, per-port, per-flow bytes) → tables `devices`,
  `dns_queries`, `dhcp_events`, `lease_observations`, `netflow_records`.
- UI already has device list + per-device detail (DNS + flows) + **device labeling for
  randomized-MAC devices** = the seed of the device→person identity layer.

**Consequence for this spec — the oracle READS the existing DB; it does NOT build new probes:**
- `internet_idle` = query `netflow_records` for recent WAN-bound bytes (supersedes §4/§5
  "sample eth1 / conntrack").
- `homelab_idle` = query `netflow_records` for recent flows to service ports — Jellyfin
  `:8096`, NFS `:2049`, nginx `:443` are ALL already captured (supersedes §4's direct
  nfsd/nginx reads). Jellyfin `/Sessions` optional, only for play-vs-pause nuance.
- presence/liveness = `devices` + `dns_queries` (already there).

**Revised build order (supersedes §8):**
1. Add `lantern/activity.py` in `/opt/lantern` → `is_internet_idle()` / `is_homelab_idle()`
   querying `netflow_records`; expose `/api/activity/idle` on the FastAPI.
2. Job gates call it via that API (or a shared CLI): deco-reboot (sweetpea-scripts) + snapraid
   (qwerty-scripts). No new sensing infra.
3. Calibrate thresholds against the 4 weeks of `netflow_records` already collected.
4. Device→person identity: extend the existing device-labeling → serves both "who's online
   (people)" and the smart speaker.

**New operational item (IMPORTANT):** DB is **3.3 GB after 4 weeks** (unbounded
`netflow_records` growth). Add a **retention/pruning policy** (delete netflow rows older than
N days + VACUUM) before it fills the disk.

**Cleanup:** `sweetpea-scripts/{lantern,api,bin,systemd,README-lantern.md}` is a **stale
pre-fork duplicate** of `/opt/lantern` — should be removed (only `deco-reboot/` and
`logrotate/` belong in sweetpea-scripts).

---

## 3. Architecture

```
          ┌─────────────────────────── LANtern ───────────────────────────┐
 signals  │  ACTIVITY ORACLE (sweetpea)                                    │
 ───────► │   is_internet_idle()   is_homelab_idle()                       │
 (§4)     │   (deterministic; reads §4 signals)                            │
          └──────────┬───────────────────────────────┬───────────────────┘
                     │ gate                            │ gate
        ┌────────────▼───────────┐         ┌───────────▼────────────────┐
        │ Deco reboot job         │         │ SnapRAID sync job           │
        │ (sweetpea)              │         │ (qwerty)                    │
        │ weekly OR degradation-  │         │ ≥24h since last success,    │
        │ triggered + approval    │         │ then seek idle window       │
        └────────────┬───────────┘         └───────────┬────────────────┘
                     │ actuate                          │ actuate
          Kasa KP125M plug (built)            snapraid sync (existing script)
          power-cycle main Deco 10.0.50.216   on qwerty, moved off blind 2 AM
```

**The oracle** = a small deterministic module on **sweetpea** (always-on, wired, central;
reaches the RPi5 and Jellyfin). Exposes a simple check other jobs call — start as a CLI
returning exit 0/1 (`lantern-idle --for reboot|snapraid`), later an HTTP/JSON endpoint so
qwerty and the smart speaker can query it too.

---

## 4. Signals (survey 2026-07-06 — availability confirmed)

| Signal | Source | Reads | Status |
|---|---|---|---|
| WAN throughput | RPi5 `eth1` byte counters (`/proc/net/dev`), sample over interval | internet in use | ✅ available |
| Active flow count | RPi5 `nf_conntrack_count` (397 idle baseline) | internet in use | ✅ |
| Per-device bandwidth | RPi5 `conntrack -L` parse (or add `nlbwmon`) | which device/person | ⚠️ nlbwmon not installed; conntrack parse works |
| Media playback | Jellyfin `/Sessions` (qwerty:8096) NowPlaying | homelab in use | ⚠️ needs API key (TODO) |
| Array I/O | qwerty `nfsd` call counter (`/proc/net/rpc/nfsd`), sample rate | array reads/writes | ✅ |
| Active downloads | arrs-vm download client API (qbit/SAB) writing to pool | array writes | TODO: locate/confirm |
| External service use | `cloudflared` tunnel + nginx access logs | someone using hosted services from outside | ⚠️ cloudflared NOT on sweetpea as systemd; nginx containerized — LOCATE (TODO) |
| Device presence | RPi5 DHCP/ARP | coarse "who's home/awake" | ✅ (weak signal) |

**Note:** presence ≠ use. Gate on *throughput / active sessions / I/O*, not mere presence
(idle phones beacon DNS + keepalives constantly).

---

## 5. Idle definitions (CALIBRATED 2026-07-06 against 29 days of lantern.db netflow_records)

Source of truth is **`lantern.db` → `netflow_records`** (per §2.5 reconciliation), *not* RPi5
`/proc` counters. Calibration ran read-only against ~924k flow rows / 29 days.

### Calibration lessons that shape the query (do not skip these)
1. **Bucket on `received_unix`** (sweetpea's collector clock). The exporter's `first_unix`/
   `last_unix` are skewed ~1 h (OpenWrt derives flow time from device uptime) — using them
   answers "now?" an hour late.
2. **Count BOTH directions.** Downloads are flows with `dst_addr` = LAN (src = external);
   filtering only `src_addr = LAN` measured *upload* and undercounted bytes 3.5× (7d: 14.5 GB
   download vs 4.2 GB upload). Identify the LAN endpoint per flow (`src` or `dst`), require
   exactly one side LAN (WAN-facing: `(src LIKE 10.0.50.%) <> (dst LIKE 10.0.50.%)`).
3. **Exclude infra/IoT** or the network never looks idle. sweetpea's persistent WireGuard
   (port 51820) + repeated 2 GB replication pulls from VPS `154.53.63.124` alone would mask
   every human. Exclusion set (verified identities):
   `.47` sweetpea, `.83` qwerty, `.213` sauron, `.1` router (infra);
   `.131/.101/.159` Nest/Home Minis, `.105/.197` Wyze cams, `.205/.201` Nest Labs,
   `.207` Flume (IoT sensors). Keep phones/laptops/tablets **and TV/Roku/Tablo** (`.203/.211`)
   — someone mid-stream must block a reboot.
4. **Sum bytes per device per window, never per-flow max.** softflowd's active-timeout chops
   one stream into many flows (no human flow > ~59 MB even while streaming).

### `internet_idle` (nobody browsing) — signal = human client devices, WAN, both directions
- **IDLE** when, over a **≥60 min** lookback (≥2 consecutive 30-min windows):
  - human WAN bytes **< 3 MB per 30-min window**, **AND**
  - **0 devices** moved **> 1 MB** in any window (`activeDev == 0`).
- Measured basis: overnight idle floor **0.2–0.9 MB/30min, activeDev 0**; lightest real
  activity jumps to **4–65 MB, activeDev 1–3**. Clean ~4× dead-zone → 3 MB sits safely inside.
- Require *sustained* quiet to reject isolated overnight blips (phone background sync shows as
  a single ~1.8 MB / 1-device window ~2×/night).

### `homelab_idle` (nobody using hosted services) — signal = sweetpea's Cloudflare tunnel
- External service access arrives **through the cloudflared tunnel**, so it appears as
  sweetpea(`.47`) ↔ Cloudflare-edge (`172.70.x`, `162.158.x`) on **port 443**. Exclude the
  backup VPS `154.53.63.124`.
- **IDLE** when sweetpea-443 (minus backup VPS) is **< 1 MB AND < 250 flows per 30-min**.
- Measured basis: keepalive-only floor **~0.15 MB / ~110 flows/30min** (tunnel never drops to
  zero flows); active service sessions clearly step to **>1 MB / 300–650 flows**.
- Add later: direct LAN→sweetpea access (someone on the LAN hitting a service bypasses
  Cloudflare) — LAN-src flows to `.47` on service ports; port 22 SSH seen but that's admin.

### Diurnal context (Pacific)
Reliable quiet band **~02:00–08:00 PT**; prime time **15:00–23:00 PT** (peak ~233 MB/hr @ 5 PM).
But overnight **machine** spikes exist (01:00 & 04:00 bumps = backups/sync, and a 3-hour
00:00–03:00 service-access block on 07-06) → **the oracle must measure, never trust the clock.**

---

## 6. Job policies

### SnapRAID sync (qwerty)
- Trigger: **≥24 h since last *successful* sync** (track a timestamp/state file).
- Then enter "seeking idle": every ~20 min check **`homelab_idle`** (focus: array I/O —
  no NFS activity, no downloads writing; reads compete but writes are the correctness
  concern). Run when idle; else postpone and recheck. **No deadline.**
- On success, record timestamp. Existing `~/qwerty-scripts/snapraid/*.sh` do the sync;
  wrap them with the gate. **Retire the blind 2 AM cron** once the gate is live.

### Deco reboot (sweetpea)
- Trigger: **~weekly since last reboot, OR** LANtern's RF-degradation probe fires earlier
  (the better trigger — see the recurring 5 GHz gotcha in network.md / LANtern notes).
- **Human-in-the-loop for the degradation trigger:** LANtern notifies "reboot recommended"
  → AJ **approves** → job then waits for `internet_idle && homelab_idle` (reboot drops
  WiFi → affects both internet and homelab users) → executes. Weekly backstop can run
  without a prompt (or with a passive notice).
- Actuator: the built + validated `~/deco-reboot/deco-reboot.sh` (Kasa plug power-cycle,
  wired-ping confirmation). **No deadline.**
- "Time since last reboot": prefer the Deco's real uptime if readable; note the plug's
  `on_since` only reflects *power-cycle* reboots, not app-initiated ones, so lean on the
  degradation signal + weekly backstop rather than trusting a single uptime source.

---

## 7. Human-in-the-loop / notifications

Degradation-suggest → approve → execute-when-idle loop needs a notify+approve channel.
**Provisional default: reuse Pushbullet** (AJ already runs `jellyfin-pushbullet-bridge`).
Approval could be a Pushbullet reply, a small web link, or (later) the smart speaker.
TODO: confirm channel with AJ.

---

## 8. Build order

1. **Locate the missing signals** — cloudflared/nginx logs; Jellyfin API key; download
   client on arrs-vm. (read-only)
2. **Log real traffic** a day or two (collectd interface stats on RPi5 + a homelab-activity
   sampler) → **calibrate §5 thresholds.**
3. **Build the oracle** on sweetpea: `is_internet_idle` / `is_homelab_idle`, CLI first.
4. **Gate SnapRAID** (qwerty wrapper, 24h + seek-idle) → retire blind 2 AM cron.
5. **Gate the Deco reboot** (weekly backstop + degradation-triggered + approval).
6. **Fold into LANtern proper** — oracle reads LANtern's data layer; add device→person
   identity; expose HTTP/JSON for the smart speaker.

---

## 9. Open items (TODO)

- [ ] Locate `cloudflared` + nginx access logs (external-service-use signal).
- [ ] Jellyfin `/Sessions` API key (source: qwerty config or `pass`).
- [ ] Confirm arrs-vm download client + how to read "actively writing to pool."
- [ ] Calibrate thresholds against real logged traffic.
- [ ] Confirm notify/approve channel (default: Pushbullet).
- [ ] Decide oracle interface: CLI now, HTTP/JSON when the speaker needs it.
