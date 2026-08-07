# 2026-08-01 — Foreign-language accents, emoji picker, and host-scaled dotfiles

## Goal
Standardize typing accented characters (Portuguese first: á ã â à ç é ê ó õ ô ú ü …)
and emoji on a US physical layout, working **everywhere including terminals/nvim**.
No prior plan existed (searched ROADMAP, MEMORY, KANATA.md, memory/, project-memory/,
dotfiles — nothing). The ISO keyboard bought for the Framework turned out unnecessary;
none of this depends on ANSI vs ISO.

## Final architecture (what shipped)

### Accents — AltGr + a per-vowel popup picker
- **Right Alt = AltGr** via XKB `kb_variant = altgr-intl` (Hyprland `input {}`).
  Direct single-keysym accents work in *every* app: `AltGr+a/e/i/o/u` → á é í ó ú,
  `AltGr+n` → ñ, **`AltGr+,` (comma) → ç** (NOT AltGr+c, which is © in this variant).
- **kanata**: the `l` home-row mod used to hold `ralt`; moved it to `lalt`
  (`lalt`/`laltU`/`laltM` in both hosts' `kanata-internal.kbd`) so the *physical*
  Right Alt is the sole source of AltGr and `l`-hold stays normal (left) Alt.
- **Why not dead keys** (ã â à ü = dead_key + vowel): composition is done per-toolkit,
  so it's inconsistent. Works in **kitty** (libxkbcommon; fixed by `XCOMPOSEFILE`
  pointing at libX11's Compose file, since NixOS lacks `/usr/share/X11/locale`), but
  **fails in ghostty** because ghostty runs the **GTK runtime** and its input path
  ignores `XCOMPOSEFILE`. This per-app fragility is exactly the terminal/nvim gap we
  were trying to escape, so dead keys were rejected as the primary path.
- **Chosen solution**: `~/.config/hypr/scripts/accent-pick <vowel>` — a fuzzel popup of
  that vowel's variants; the pick is typed via **wtype**, which inserts the real
  codepoint → universal, no compose, nothing to memorize. Bound in Hyprland on
  **MOD5** (= ISO_Level3_Shift = AltGr) + the base vowel: `bind = MOD5, a, exec …`
  (and `MOD5 SHIFT` for uppercase). Gotcha learned: a bare `bind = , aacute` does NOT
  fire because AltGr sets the Mod5 modifier — must match `MOD5` + the base key.
- **Caret-anchored popup** (like GTK `Ctrl+;`) is impossible for an external tool: only
  the input-method / text-input protocol carries caret position, which terminals/nvim
  don't implement. Universal placement (centered) and caret-anchoring are mutually
  exclusive; we kept universal.

### Emoji
- `bemoji` (nixpkgs) + fuzzel + wtype/wl-copy. `Super+.` = single pick; `Super+Shift+.`
  = multi mode (loops the picker, Escape ends). Replaces GTK `Ctrl+;`, which only ever
  worked inside GTK text entries (never the terminal).

### Keybind reshuffle (dotfiles `hypr/conf.d/20-binds.conf`)
- `Super+.` reclaimed for emoji (was `focusmonitor +1`).
- Monitor focus moved to `Super+Alt+H` / `Super+Alt+L` (left/right).
- Removed the unused `Super+Alt+L` hyprlock keybind (screen still auto-locks via
  hypridle) and the unused `Super+Shift+.` move-window-to-monitor.

### Host-scaled shared dotfiles (ThinkPad vs Framework)
The shared `~/.config` (bare dotfiles repo) needs per-host sizes. Two working
discriminators exist and both were used:
- **hostname** differs: ThinkPad = `nixos`, Framework = `framework-13`.
- **`QS_UI_SCALE`** env (NixOS `sessionVariables`): Framework `1.75`, ThinkPad falls
  through to quickshell's default `1.25` (read as `C.Appearance.uiScale`).

Applied:
- **fuzzel**: `~/.config/hypr/scripts/fz` wrapper gates `--font/--width/--lines` on
  `$(hostname)` (thinkpad 11/40/12, framework-13 20/30/10) and is used by the launcher
  (`$menu`), the emoji picker (`BEMOJI_PICKER_CMD="…/fz -d"`), and accent-pick. fuzzel
  uses one non-merging config file, so a wrapper (not per-caller flags) is the clean
  way to cover bemoji too. bemoji honors `BEMOJI_PICKER_CMD` (confirmed in its script).
- **quickshell notification center** (`components/frame/NotifLayer.qml`): its width and
  content `panelScale` were raw/identical on both laptops. Gated on
  `C.Appearance.uiScale >= 1.5`: ThinkPad → 400px width, panelScale 1.05; Framework
  keeps 460 / 1.15. Top-right toasts untouched (separate `scale_`).

## Pending actions
- **ThinkPad**: `nrt` then `nrs` to deploy the kanata `l`→lalt change (until then,
  holding `l` also acts as AltGr — transient), `bemoji`, and `XCOMPOSEFILE`; then
  **re-login** so `XCOMPOSEFILE` (a session var) reaches all apps.
- **Framework**: `g pull` + `dot pull` + `nrs` to receive everything. All host-specific
  bits are gated, so it keeps its larger fuzzel and 460px notif center automatically.

## Commits (all pushed to home/GitHub/local)
nixos-config: `73f1a22` kanata l→lalt · `05885eb` bemoji · `387239c` XCOMPOSEFILE.
dotfiles: `686f46e` altgr-intl · `fbcd216` emoji bind + monitor rebind · `22e7780`
multi-emoji · `1bc3154` accent-pick · `8e80b81` fz wrapper · `9d4b257` notif center.

See also: `project-memory/multi-host-refactor-spec.md` (the host-scaling pattern here is
reusable for other shared-dotfiles-with-per-host-size cases).
