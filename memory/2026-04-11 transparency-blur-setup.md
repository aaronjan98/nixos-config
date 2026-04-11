# Session: Transparency & Blur Setup
Date: 2026-04-11

## Summary
Set up per-app transparency and compositor blur across the desktop.
Removed global Hyprland opacity in favour of targeted window rules and per-app config.

---

## Key decisions

### Global opacity removed
Removed `active_opacity` / `inactive_opacity` from `conf.d/30-look.conf`.
These applied compositor transparency to every window including videos and images — undesirable.

### Blur kept global
Hyprland blur only activates on transparent surfaces, so having it global is correct and has
no effect on fully opaque windows. Final values: `size = 4, passes = 1`.

### Terminals: native opacity
Ghostty and Kitty handle transparency themselves via `background-opacity` / `background_opacity`.
Both set to `0.75`. Blur shows through from Hyprland.

**Ghostty shader bug fixed**: `shaders/cursor_smear.glsl` had alpha hardcoded to `1.0` on the
final `fragColor` output, overriding `background-opacity` entirely. Fixed to `terminalColor.a`.

### Other apps: windowrulev2
Created `conf.d/40-windowrules.conf` for per-app compositor opacity rules.
Format: `windowrulev2 = opacity <active> <inactive>, class:^(<class>)$`

Current rules:
| App            | Class                  | Active | Inactive |
|----------------|------------------------|--------|----------|
| Obsidian       | obsidian               | 0.85   | 0.80     |
| Vesktop        | vesktop                | 0.85   | 0.80     |
| Evince         | org.gnome.Evince       | 0.75   | 0.70     |
| Nautilus       | org.gnome.Nautilus     | 0.75   | 0.70     |
| Cursor         | cursor                 | 0.75   | 0.70     |
| VSCodium       | vscodium               | 0.75   | 0.70     |
| Slack          | slack                  | 0.75   | 0.70     |
| Element        | element                | 0.75   | 0.70     |

### Firefox: userChrome.css only
Firefox toolbar/tabs are transparent via `~/.mozilla/firefox/zpqkr59d.default/chrome/userChrome.css`.
Web content area cannot be made selectively transparent — videos/images render in a flat compositor
surface with no per-element metadata. This is a hard browser/Wayland protocol limitation.
Required: `widget.gtk.transparent-background = true` and `toolkit.legacyUserProfileCustomizations.stylesheets = true` in about:config.
`MOZ_ENABLE_WAYLAND = "1"` added to `environment.sessionVariables` in configuration.nix.

### Obsidian: CSS snippet
Created `zettelkasten/.obsidian/snippets/theme-glass.css` — full replacement for `true-black-bg.css`.
Disable `true-black-bg`, enable `theme-glass`.
Backgrounds use `rgba(17, 17, 17, 0.75)` (matching kitty). Popups/modals are fully opaque (`#111111`)
to prevent text bleed-through. True-black variant preserved as commented block in section 0 for easy toggle.

### Vesktop: Vencord QuickCSS
Add via Settings → Vencord → QuickCSS. Uses Discord's CSS variables (`--background-primary` etc.)
set to `rgba(17, 17, 17, 0.75)`. Popup selectors use attribute selectors (`[class*="modal"]`) since
Discord's generated class names change with every build.

---

## Theme switcher — future work
User has a quickshell symlink switcher and wants a live runtime theme switcher long-term.

**Stylix is NOT the right tool for this.** Stylix generates configs at build time and requires
a NixOS rebuild to switch themes — incompatible with a live/runtime switcher.

**Recommended direction: `matugen`**
- Generates base16-style palettes from a wallpaper at runtime
- Pairs naturally with a symlink switcher: generate configs per theme, symlink to active set
- Keeps the existing quickshell-based approach intact
- Look into: matugen + per-app config templates + symlink switcher orchestration
