# 2026-10-30 — Super+X (ocr-custom-split-sauron) pipeline: full fix chain

## What was worked on
Super+X kept failing when used off the home LAN (campus wifi + Tailscale). Traced and
fixed a chain of independent bugs on the laptop side, then handed off to a Sauron-side
GPU investigation that ended in a deliberate pause — see
[[2026-10-30 sauron-ocr-gpu-investigation]] in the Raymer homelab repo for that half.

## Fixes made here (all committed)
1. **`modules/wol-sauron.nix`** — the magic packet now gets relayed through `sweetpea`
   (SSH, broadcast from sweetpea's own NIC) instead of being sent directly from the
   laptop. Direct send never worked off-site: broadcast to `10.0.50.255` gets routed to
   `sweetpea`'s subnet-router via Tailscale, but routers don't forward directed
   broadcasts onto their own LAN by default; a unicast packet to Sauron's LAN IP needs an
   ARP entry for a host that's powered off, which won't exist either.
2. **`tools/pkgs/math-ocr.nix`** — `ocr-custom-split-sauron` now sets
   `SAURON_HOST=sauron.home` instead of the default `sauron` (which resolves via
   `~/.ssh/config` to the public `ssh.aaronjanovitch.com:2221` port-forward). That public
   path showed two different failure modes (`No route to host`, later `Connection
   refused` on a *different* port-forward too) independent of whether Sauron was
   actually reachable. `sauron.home` → Tailscale-direct → `10.0.50.213` has been solid
   every time since.
3. **`tools/scripts/ocr-custom-split.py`** — added `has_garbled_exponent_artifact()`,
   used in both `block_is_tesseract_cleanable()` and `span_is_simple_math()`. The old
   heuristic was letting Tesseract's own garbling of exponents/derivatives (e.g. `y'' +
   2y' + y = 4e^t` misread as `Y + 2 +y=4det.`) pass as "simple enough to clean up
   locally," skipping Sauron entirely and copying the wrong answer. New rule: a digit
   directly followed by 2+ letters with no separator is never genuine simple math in
   this context (real simple terms only ever pair a digit with a single-letter variable,
   `3t`/`2y`) — validated against all 7 real skip-decisions in the capture history
   (`~/.local/share/ocr-captures/attempts/*/`) with zero false positives.
4. **`modules/ntfy-sauron-gpu-relay.nix`** (new, imported in `hosts/common/default.nix`)
   — a `systemd.user.services` unit subscribing to the ntfy topic Sauron's boot-time
   health check publishes to, re-emitting via `notify-send` so it also shows in
   Quickshell's panel, not just the ntfy phone app.

## Non-nixos-config pieces (documented fully in the Raymer memory note)
- Sauron's `ocr-api.service` got `Environment=CUDA_LAUNCH_BLOCKING=1` (reduces but
  doesn't eliminate a separate mid-session CUDA crash on the Quadro M5000 — unsupported
  GPU architecture, see linked note).
- A boot-time GPU health tripwire (`ocr-api-health-check.service` on Sauron) + the ntfy
  relay here catch the *other* failure mode (driver/library version mismatch after
  apt-upgrades-without-reboot) within a minute of any future boot.
- `/etc/apt/apt.conf.d/50unattended-upgrades` on Sauron now has
  `Automatic-Reboot "true"` at 04:00, so that mismatch shouldn't recur silently.

## Current state
Client-side pipeline (this repo) is fully fixed and ready to use. Sauron's GPU still has
an unresolved intermittent crash (failure mode 2 in the Raymer note) that wasn't worth
chasing further this session — **Sauron OCR use is paused by choice**, not because
anything here is broken. If picked back up later, start from the Raymer note's "Decision"
section for the remaining options (self-healing `app.py` patch, CPU fallback, or an older
PyTorch pin).
