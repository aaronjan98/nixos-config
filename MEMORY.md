# MEMORY.md

## Agent Procedures

### Rebuilding and Testing
When applying NixOS configuration changes, agents MUST use the following aliases to ensure consistency:

- **`nrt`**: Used for testing or dry-run of the configuration (e.g., `sudo nixos-rebuild test`).
- **`nrs`**: Used for applying the final configuration (e.g., `sudo nixos-rebuild switch`).

Always run `nrt` first to verify the configuration builds correctly before applying it with `nrs`.

---

## Excluding KDE Plasma Packages

To remove a package that ships with `services.desktopManager.plasma6`, use:

```nix
environment.plasma6.excludePackages = [ pkgs.kdePackages.<name> ];
```

Currently excluded: `dolphin`, `dolphin-plugins` (replaced by Nautilus for GUI file management).

---

## Transparency & Blur Architecture

Per-app transparency is handled by two layers:
1. **Terminals** (ghostty, kitty): `background-opacity` / `background_opacity` in the app config. Blur shows through from Hyprland.
2. **Other apps**: `windowrulev2 = opacity <active> <inactive>, class:^(<class>)$` in `conf.d/40-windowrules.conf`.

Global Hyprland opacity (`active_opacity` / `inactive_opacity`) is intentionally absent — it applied to all windows including videos.
Hyprland blur is global but only activates on transparent surfaces, so this is correct.

**Ghostty shader note**: `background-opacity` is not live-reloadable (requires full restart), and custom shaders
must pass `terminalColor.a` (not `1.0`) as the alpha output or they silently override opacity.

**Firefox**: Only the browser chrome (toolbar, tabs) can be made transparent via `userChrome.css` +
`widget.gtk.transparent-background = true`. Web content area is a flat compositor surface — videos/images
cannot be selectively excluded from transparency. Hard browser/Wayland protocol limitation.

**Obsidian**: Uses `snippets/theme-glass.css` (disable `true-black-bg`). Popups need explicit opaque
backgrounds or text bleeds through. See session notes 2026-04-11 for full detail.
**Obsidian WM class caveat**: Obsidian's WM class is `electron`, NOT `obsidian`. The windowrule must use
`class:^(electron)$, title:.*Obsidian.*` to avoid matching all Electron apps.

---

## Theme Switcher — Future Direction

User has a quickshell symlink switcher and wants a live runtime theme switcher.
**Do not suggest Stylix** — it requires NixOS rebuilds to switch themes, incompatible with live switching.
**Recommended tool: `matugen`** — generates base16 palettes from wallpaper at runtime, pairs with symlink switcher.
Pattern: matugen generates per-theme config files → symlink switcher points to active set → reload affected processes.

## Hyprland & Locking

### Hyprlock/Hypridle Implementation (2026-04-12)
- **Config:** Managed in \`modules/hypr-idle-lock.nix\`.
- **Auth:** Added \`security.pam.services.hyprlock = {}\` for password validation.
- **Idle Progression:**
    - 5 mins: Screen blackout via \`screen-blackout-on\` (screensaver mode).
    - 10 mins: Screen lock via \`hyprlock\`.
    - 15 mins: Display sleep via DPMS.
- **Aesthetic:** Custom "Clockwork" theme using JetBrains Mono, blurred background (\`path = screenshot\`), and bezier fade-in animations.
- **Note on Systemd:** If \`hypridle\` fails to start, check for broken symlinks in \`~/.config/systemd/user/\` that might be shadowing the NixOS-managed unit. Remove them and run \`systemctl --user daemon-reload\`.

### Future: Qylock/Quickshell
- **Animation Goal:** The "exact" high-fidelity animations from [Darkkal44/qylock](https://github.com/Darkkal44/qylock) are QML-based.
- **Path:** Requires switching from \`hyprlock\` to \`quickshell\` as the lockscreen provider.
- **Status:** Researched but not implemented to avoid significant architectural shift during this session.

---

## Common Tasks

### Adding a Split DNS Entry
When adding a new local domain (e.g., `photos.local`):

1. **Configuration:** Update `modules/caddy.nix`:
   - Add the domain to `networking.hosts."127.0.0.1"`.
   - Add a new `virtualHosts` entry with the appropriate `reverse_proxy` target (e.g., `http://qwerty:<port>`).
2. **Apply Changes:** 
   - Run `nrt` first to verify the configuration is valid.
   - Run `nrs` to apply and switch.
   - *Note:* Simply restarting the `caddy` service is insufficient because `/etc/hosts` needs to be updated by NixOS to resolve the new `.local` domain.
3. **Verification:** Check the domain in a browser or use `curl -I http://domain.local`.
