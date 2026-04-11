# Session Notes — 2026-04-10

## Topic: MIME defaults, image viewer fix, yazi install, dolphin removal

### What was worked on
- Diagnosed and fixed a red overlay bug when opening images
- Set up gwenview as the default image viewer
- Added yazi to the NixOS config
- Removed Dolphin from the system
- Committed relevant dotfiles and documented changes

---

### Key Insights

#### Red overlay root cause
- `~/.config/mimeapps.list` had `org.gnome.eog.desktop` as the default for image types, but `eog` is not installed on this system
- `gio open` silently fell back to `okularApplication_kimgio.desktop` (Okular)
- Okular had `ChangeColors=true` / `RenderMode=Recolor` set in `~/.config/okularpartrc`, causing a red color remap over all images
- Fix: set `ChangeColors=false`, `RenderMode=Normal` in `okularpartrc` and point `mimeapps.list` to `org.kde.gwenview.desktop`

#### Dolphin origin
- Dolphin was never explicitly added to `configuration.nix`
- It ships automatically with `services.desktopManager.plasma6.enable = true`
- Removed via `environment.plasma6.excludePackages = [ pkgs.kdePackages.dolphin pkgs.kdePackages.dolphin-plugins ]`

#### Yazi
- Added to `environment.systemPackages` in `hosts/thinkpad-t14/configuration.nix`
- Works out of the box with Kitty terminal (native Kitty Graphics Protocol for image preview)
- Batch rename: select files with Space, press `r`, edit list in `$EDITOR`

---

### Decisions
- Use **Nautilus** (already installed) for GUI file management
- Use **Yazi** for terminal file management
- **gwenview** is the registered default for all image MIME types (png, jpeg, webp, gif, bmp, tiff, avif, heif, jxl)
- **eog** should never be set as default — it is not installed

---

### Files Changed
| File | Repo | Change |
|---|---|---|
| `hosts/thinkpad-t14/configuration.nix` | nixos-config (`g`) | add yazi, exclude dolphin/dolphin-plugins |
| `~/.config/mimeapps.list` | dotfiles (`dot`) | gwenview for all image types |
| `~/.config/okularpartrc` | dotfiles (`dot`) | ChangeColors=false, RenderMode=Normal |
| `~/.config/CONTEXT.md` | dotfiles (`dot`) | document individually tracked config files |
| `MEMORY.md` | nixos-config (`g`) | document plasma6 excludePackages pattern |

---

### Open Questions / Next Steps
- None outstanding — yazi, gwenview, and Nautilus are all functional
</content>
</invoke>