# MEMORY.md

## Temporary Fixes

### nixpkgs-unstable pinned (as of 2026-05-02)
`flake.nix` has `nixpkgs-unstable` pinned to `01fbdeef22b76df85ea168fbfe1bfd9e63681b30` (2026-04-23).
**Reason:** new unstable rev (`c6d65881`) hard-errors on `primp`'s deprecated `pytestFlagsArray`, breaking `open-webui` build.
**To unpin:** revert to `github:NixOS/nixpkgs/nixpkgs-unstable`, then run `nix flake update nixpkgs-unstable` once the fix lands upstream.
See `memory/2026-05-02 nixpkgs-unstable primp pin.md` for full detail.

---

## Agent Procedures

### Rebuilding and Testing
When applying NixOS configuration changes, agents MUST use the following aliases to ensure consistency:

- **`nrt`**: Used for testing or dry-run of the configuration (e.g., `sudo nixos-rebuild test`).
- **`nrs`**: Used for applying the final configuration (e.g., `sudo nixos-rebuild switch`).

Always run `nrt` first to verify the configuration builds correctly before applying it with `nrs`.

### `dot` alias for dotfiles
For any operation on files tracked by the home-directory bare repo (`~/.config/`, `~/.bashrc`, `~/.bash_aliases`, `~/.gitconfig`, `~/.bash_profile`, `~/.dotfiles.gitignore`), use the `dot` shell function — not `g` or plain `git`.

```
dot add <path>
dot commit -m "..."
dot pushall    # pushes to home, hub (github), and local mirrors
dot pull
dot st
```

`dot` is defined as `git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"`. `g` is reserved for working-tree repos under `~/Repositories/`. This is also documented in `~/.config/ai/shared/tool-commands.md`.

### `ssh -t` for interactive remote commands
Always include `-t` (TTY allocation) when an `ssh` command will hit `sudo` or any interactive prompt on the remote. Without it, sudo's password prompt fails silently. `ssh user@host "sudo ..."` → `ssh -t user@host "sudo ..."`.

### Session notes location
Save session notes to `~/nixos-config/memory/YYYY-MM-DD topic.md`, not under `~/.claude/`. The repo-local `memory/` is agent-agnostic and gets browsed alongside the project files.

### Zettelkasten — `Zettels/` is permanent/general; `Inside/` is personal
Notes under `~/Repositories/self-hosted/zettelkasten/Zettels/` are **permanent, general-purpose** — they should read as true for any reader in that domain, not just the user. First-person framing ("this bit me"), project-specific names (sops.secrets, forgejo, ollama, framework-13), and one-off setup details belong under `Inside/` instead. When adding to `Zettels/`, strip personal narrative and use neutral example identifiers (`foo`, `someService`, `someAttrs`). If a topic genuinely combines general principles with personal specifics, split into a general zettel + an `Inside/` note that links to it.

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

## NixOS Firewall (iptables)

When opening ports manually (e.g. for a temporary sshd), do **not** append to the `INPUT` chain — it won't work. NixOS inserts its own chain (`nixos-fw`) near the top of `INPUT`, and that chain ends with a REJECT. Rules appended to `INPUT` land below it and are never reached.

Always insert into `nixos-fw` directly:

```bash
sudo iptables -I nixos-fw -p tcp --dport <port> -j nixos-fw-accept
```

These rules are temporary — they do not survive reboot or `nixos-rebuild`.

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
