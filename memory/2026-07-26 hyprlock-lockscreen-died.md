# 2026-07-26 — hyprlock "lockscreen app died" on lid close

## Symptom
On thinkpad-t14 (hostname `nixos`), closing the lid frequently landed on Hyprland's
"Oopsie daisy… the lockscreen app died :(" fallback screen, forcing a TTY recovery
(`hyprctl keyword misc:allow_session_lock_restore 1`, restart hyprlock / `killall -9
hyprlock`). User suspected recent external-monitor config.

## Root cause (evidence-backed)
Lid close → suspend (thinkpad uses default lid=suspend; no ignore override) →
hypridle `before_sleep_cmd` locks the session → hyprlock launches. hyprlock's
background was `path = screenshot`, so it waited on a wlr-screencopy of every output
(~10s) before acquiring the Wayland `ext_session_lock`. logind's default delay
inhibitor cap (~5s) expired first → system suspended mid-lock → hyprlock lost the
lock ("onLockFinished… Seems we got yeeten. Is another lockscreen running?") and
exited → dead lock client → death screen.

Proof: journal `yeeten` only on before-sleep/suspend cycles, never on plain idle
locks (which locked fine). Crash logs showed only eDP-1 — **not** the external
monitor. So the external monitor was a red herring (it would only widen the race by
making the screenshot slower); the real trigger was screenshot-lock racing the
suspend inhibitor timeout.

## Fixes (all applied this session)
1. `misc { allow_session_lock_restore = true }` — `~/.config/hypr/conf.d/30-look.conf`
   (dot repo, shared). Hyprland's own recommended remedy: a relaunched/second
   hyprlock reclaims the lock instead of the death screen. Verified live:
   `hyprctl getoption misc:allow_session_lock_restore` → `int: 1, set: true`.
2. `path = screenshot` → `path = /home/aj/Pictures/Wallpapers/current.png` in
   `modules/hypr-idle-lock.nix`. Static image locks instantly (no screencopy race).
   Blur/effects still apply to the image. Missing file just falls back to `color`.
3. `services.logind.settings.Login.InhibitDelayMaxSec = "20s"` (hypr-idle-lock.nix) —
   headroom so logind waits for the lock before suspending.
4. Removed `no_fade_in` / `grace` / `disable_loading` from hyprlock `general {}` —
   invalid in hyprlock v0.9.2 (`no_fade_in`/`disable_loading` don't exist; `grace`
   isn't in `general`, and value 0 = default). Silences `[ERR] Config has errors`.

## Validation
`nix eval`/dry-build of thinkpad-t14 passed; generated hyprlock.conf shows the static
path and no stale opts; logind.conf renders `InhibitDelayMaxSec=20s`.

## Follow-ups / notes
- NixOS changes (#2–#4) need `sudo nixos-rebuild switch --flake ~/nixos-config#thinkpad-t14`
  to take effect (dotfiles #1 already hot-reloaded). Real test: rebuild, close+reopen lid.
- Latent, separate bug found: framework-13's intended `HandleLidSwitch = "ignore"`
  (commit d7f35a9) isn't in the running system's logind.conf — the deployed system is
  just stale. Confirmed the current flake now renders logind `settings.Login`
  correctly, so a `nixos-rebuild switch` on the Framework will finally apply it.
  See [[2026-07-21 timezone-follows-travel]] for the other recent framework session.
