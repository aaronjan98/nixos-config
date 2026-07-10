# 2026-07-10 — Doom Emacs CP1 + CP2

## CP1 — emacs-pgtk installed

- Added `emacs-pgtk = pkgsUnstable.emacs-pgtk;` to `myOverlay` in `flake.nix`
  (same pattern as claude-code, opencode)
- Created `modules/emacs.nix`: `environment.systemPackages`, `services.emacs`
  (daemon as systemd user service), `defaultEditor = true`
- Imported in `hosts/common/default.nix` (all hosts, not just thinkpad)
- `nrt` passed, `nrs` applied — Emacs 30.2 installed from unstable cache, no
  source build
- `systemctl --user status emacs` shows `enabled` but `inactive` — correct,
  session predated the rebuild; will auto-start at next login, started manually
  in CP3

## CP2 — Doom Emacs installed

### The `--depth 1` / submodule problem

`git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.emacs.d`
followed by `doom install` failed with two errors:
1. Git hooks deployment: `Wrong type argument (listp "/home/aj/.emacs.d")` — non-fatal
2. `No such file or directory: /home/aj/.emacs.d/sources/doom+/modules` — this one mattered

Root cause: Doom's module library (`completion/`, `editor/`, `lang/`, `ui/`, etc.)
was moved to a separate git repository (`https://github.com/doomemacs/modules`)
and is registered as a git submodule at `sources/doom+`. The `--depth 1` shallow
clone does NOT initialize submodules by default, leaving `sources/doom+/` as an
empty directory. Doom registered all modules correctly from `~/.doom.d/init.el`
but couldn't find their files (paths were `nil` in the module table), so only
12 infrastructure packages installed instead of 65.

Fix:
```bash
cd ~/.emacs.d && git submodule update --init --depth 1
~/.emacs.d/bin/doom sync
```

`doom sync` then installed all 65 packages with every module resolved to a
real path under `~/.emacs.d/sources/doom+/modules/`.

### Module rename

Doom warned: `(:ui doom-dashboard) was moved to (:ui dashboard) in 2.1`.
Updated `~/.doom.d/init.el` accordingly.

### Result

`emacs` opens the Doom dashboard with dark theme, Evil mode active, org-mode
available. CP2 complete.

## Files changed

- `nixos-config/flake.nix` — emacs-pgtk in myOverlay
- `nixos-config/modules/emacs.nix` — new module
- `nixos-config/hosts/common/default.nix` — imports emacs.nix
- `nixos-config/project-memory/emacs-setup-spec.md` — checkpoint spec
- `~/.doom.d/init.el` — minimal module list; dashboard rename
- `~/.doom.d/config.el` — empty placeholder
- `~/.doom.d/packages.el` — empty placeholder

## Key lesson for future Doom installs on NixOS

After cloning Doom, always initialize the submodule before running doom sync:
```bash
git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.emacs.d
cd ~/.emacs.d && git submodule update --init --depth 1
~/.emacs.d/bin/doom install    # or doom sync if install was already attempted
```
