# 2026-07-14 — Framework/ThinkPad cursor and desktop session

## What changed

- ThinkPad Quickshell failed after sync because `config/Layout.qml` was missing from dotfiles. That was added and pushed earlier, restoring the bars on ThinkPad.
- Shared cursor default was changed to `Breeze_Hacked` size 32 for the ThinkPad. Framework keeps its host override at size 72.
- A black-outline cursor variant was introduced as `Breeze_Hacked_Black` to avoid reusing cached assets under the original theme name.
- Framework SSH over Tailscale was enabled while keeping access constrained through the Tailscale interface and ACLs.
- Framework logind was adjusted so the machine can stay awake for SSH/home-assistant duties while display blanking remains handled by Hyprland/hypridle.

## Cursor state

The red cursor size is now acceptable:

- Framework: 72
- ThinkPad: 32

The remaining unresolved issue is the pointer/finger cursor outline. The desired result is a simple red hand with a thin black outer outline and no internal black decorative seams.

Attempts made:

- Changed the upstream SVG base/halo colors.
- Removed the old transparent dark backing.
- Switched the outline/halo colors.
- Added a per-pointer raster post-process in `pkgs/breeze-hacked-cursor/default.nix` that keeps the red hand silhouette, fills holes, and draws a 1px black outline before regenerating `Breeze_Hacked/cursors/pointer`.

Observed problem:

- The generated/extracted pointer test frame looked clean.
- The live Hyprland cursor still looked unchanged or double-outlined to the user.

Most likely next step:

- Stop changing artwork until the active runtime cursor asset is proven.
- Verify whether the visible hand cursor is actually loading `pointer`, another alias such as `hand2`, or a toolkit/client-side cached cursor.
- Use a deliberately obvious test cursor under a fresh theme name if needed to prove what Hyprland/clients are rendering.

## Current caution

There is uncommitted cursor work in `pkgs/breeze-hacked-cursor/default.nix`, host cursor configuration, and dotfiles cursor env. There is also a generated `pointer.conf` present in the repo worktree; review before committing so it does not become accidental repo state.
