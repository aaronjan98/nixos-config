# Session: Obsidian Transparency & Resize Fix
Date: 2026-04-14

## Summary
Fixed Obsidian transparency and Super+P pseudo-resize, both broken by the same root cause:
Obsidian's WM class is `electron`, not `obsidian`. All three windowrules that referenced `obsidian`
as the class never matched.

---

## Root cause

Obsidian is an Electron app and its WM class is `electron` (confirmed via `hyprctl clients`).
The rules in `conf.d/40-windowrules.conf` and `conf.d/20-binds.conf` used `class:^(obsidian)$`
which never matched. Vesktop works correctly because its class is actually `vesktop`.

Because `class:^(electron)$` would match all Electron apps, the fix uses a combined matcher:
`class:^(electron)$, title:.*Obsidian.*`

---

## Changes made

### `~/.config/hypr/conf.d/40-windowrules.conf`
- Changed opacity rule from `class:^(obsidian)$` → `class:^(electron)$, title:.*Obsidian.*`

### `~/.config/hypr/conf.d/20-binds.conf`
- Removed `obsidian` from the shared size rule
- Added separate: `windowrulev2 = size 1800 980, class:^(electron)$, title:.*Obsidian.*`

### `~/nixos-config/MEMORY.md`
- Added caveat under Obsidian section documenting the correct class/title matcher

---

## Key insights

- The session notes from 2026-04-11 recorded Obsidian's class as `obsidian` — this was incorrect
- Prior transparency likely came from Obsidian's native `translucency: true` (Electron transparent
  window) + CSS snippet rgba backgrounds, not from the windowrule
- After Obsidian auto-updated to 1.12.7 (via `.asar` in `~/.config/obsidian/`), native translucency
  may have changed behavior, making the broken windowrule visible
- The `size` rule for pseudo-mode was also using the wrong class, causing Super+P to not snap
  Obsidian to the expected 1800x980 size

---

## Open questions

- Why did native `translucency: true` stop working after the Obsidian 1.12.7 auto-update?
  Could be an Electron 41.0.2 + Wayland + newer app code compatibility issue.

---

## No next steps — both issues resolved
