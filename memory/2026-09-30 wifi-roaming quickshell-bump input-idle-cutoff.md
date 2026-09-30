# 2026-09-30 — framework: wrong-wifi outage, Quickshell crashes, input-idle speakers cutoff

Long multi-day session (spanned ~09-13 → 09-30). Three framework/system issues,
all on host `framework-13`, plus the root-cause chain that tied several of them
together. Voice-assistant browser-playback work from the same session is in that
repo's memory ([[2026-09-30 pause-all-nonservice-tabs alarm-youtube-overlap]]).

## 1. Speakers + LEDs "dead", HA commands failed — the framework was on the WRONG wifi
- Symptom: after an `nrs`, LEDs (`desk-leds.home` 10.0.50.127) and the Kasa
  speaker plug (via HA) were unreachable; even CLI failed. Also HA unreachable
  from the phone off-wifi.
- Root cause: `nrs` restarts NetworkManager; the home Deco AP (`connect-here`,
  10.0.50.0/24) wasn't beaconing at that instant, so NM fell back to the ISP
  modem's default SSID **`SpectrumSetup-50`** (192.168.1.x). NM never roams back
  once connected. DNS still resolved `.home` (via sweetpea over Tailscale) but
  there was no route from 192.168.1.x → 10.0.50.x, so every home-LAN device was
  unreachable while Tailscale-reachable things (HA web) still worked. That
  partial pattern = "wrong network / lost LAN", not a broken service.
- Fix (live): `nmcli connection up connect-here` → back on 10.0.50.x.
- Prevention (committed via nmcli, persists across nrs since these are imperative
  connections, not in the declarative sops module): disabled autoconnect on the
  in-range fallbacks so only `connect-here` auto-joins:
  `nmcli connection modify SpectrumSetup-50 connection.autoconnect no` and same
  for `DJ VIP`. Now NM waits/retries home instead of grabbing the ISP AP.
  Tradeoff: if the Deco is down long-term the framework has no net/Tailscale
  until it returns — acceptable for a box whose job IS the home LAN.
- Off-wifi HA access is Tailscale-only (no public URL / Nabu Casa / cloudflared
  for HA); phone must have Tailscale connected. Related: [[speaker-plug-kasa]].

## 2. Quickshell keeps crashing on framework but not thinkpad
- Crashes recurring (up to 3/day around 09-14/15); backtrace in
  `Process::onStdoutReadyRead → SplitParser`, 23 MB crash log full of Bluetooth
  BLE advertisement churn (rotating MACs).
- Why framework and not thinkpad: identical config, but the crash needs the BT
  adapter powered + scanning in a device-dense room 24/7. On the framework BT is
  on+discovering; on the thinkpad BT stays off. Confirmed the differentiator.
- **Why BT keeps turning on despite `hardware.bluetooth.AutoEnable=false` +
  `powerOnBoot=false`:** Home Assistant runs on the framework and has a
  `bluetooth` integration config entry (bound to the MediaTek MT7922 USB adapter,
  DC:56:7B:03:22:48) — it powers hci0 on and scans continuously for BLE sensors
  (kegtron_ble etc.), re-enabling after every resume. HA overrides BlueZ's
  AutoEnable via D-Bus. That's the framework-only factor. The thinkpad has no HA.
- Fix chosen: **bump Quickshell 0.2.1 → 0.3.0** (parser crash is an upstream
  0.2.1 bug; can't just turn BT off because HA needs it). Done via the existing
  `myOverlay` pattern in flake.nix: `quickshell = pkgsUnstable.quickshell;`
  (committed on branch `bump-quickshell` as "bump quickshell to v0.3.0"). The
  rice is `~/.config/quickshell/rices/limerence` (its BluetoothPopup has power/
  scan toggles). Watch for QML API breakage 0.2→0.3 after deploy.

## 3. Speakers/computer stay on all day — idle never fires (audio inhibits it)
- Root mechanism: `wayland-pipewire-idle-inhibit` holds a Wayland idle inhibitor
  while ANY PipeWire stream is uncorked, which freezes ALL hypridle timers — so
  the 5-min blackout that runs `speakers.sh off` never fires. Any persistent
  audio defeats it. Seen 3x: a Firefox autoplay tab, then a **Vesktop (Discord)
  voice channel** (Electron reports as "Chromium"; found TWO Vesktop instances,
  one orphaned windowless from Sep 7 — killed it; disconnecting voice / closing
  Vesktop released the inhibit).
- Note: this framework NEVER suspends (logind ignores idle/suspend; it's the
  always-on home host). So "before sleep" hooks don't apply; the only real hooks
  are hypridle idle (frozen by audio) and the bedtime wind-down.
- **Fix committed** (`839813b` on `bump-quickshell`): new input-based backstop in
  `modules/hypr-idle-lock.nix` — a libinput-based watchdog (`input-idle-cutoff`)
  that watches raw HID input (immune to the audio inhibitor) and runs a command
  after N sec of no keyboard/mouse/touch, regardless of audio. Runs as a **user
  service** (aj is already in `input` group → reads /dev/input, no root; the cmd
  inherits aj's HOME so `speakers.sh` finds the HA token in the orchestrator
  `.env`). Gated behind new options `aj.hyprIdle.inputCutoffSecs` / `.inputCutoffCmd`,
  both default off → ThinkPad gets neither the service nor the libinput dep
  (byte-identical, matching the module's existing philosophy). Framework sets
  `inputCutoffSecs = 1800` → `speakers.sh off`. One number to tune in
  `hosts/framework-13/configuration.nix`.

## State / open items
- All three fixes deployed by aj (nrs done). `bump-quickshell` branch has:
  quickshell bump + firefox auto-hide chrome (aj's) + input-idle cutoff.
- Not merged to main yet; not pushed. If splitting is wanted, the input-idle
  cutoff (839813b) is independent of the quickshell bump.
- If Quickshell 0.3.0 breaks the limerence rice, adjust the rice or roll back the
  one overlay line.

## Reminders
- Jellyfin/HA on `qwerty` (10.0.50.83) via `ssh qwerty`; HA is local on framework
  (`home-assistant.service`, HA_URL localhost:8123). HA token: orchestrator `.env`.
- Test python: `/nix/store/j9ihw14rkv7wssfg0g2yap2p5wb0hjcb-python3-3.13.12-env/bin/python`.
