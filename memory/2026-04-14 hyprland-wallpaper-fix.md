# 2026-04-14 Hyprland Wallpaper Fix

## Problem
The wallpaper was defaulting to a hardcoded vaporwave image instead of following the `~/Pictures/Wallpapers/current.png` symlink.

## Investigation
- Checked `~/.config/hypr/` and found the configuration is split into `conf.d/`.
- Identified the hardcoded path in `~/.config/hypr/conf.d/10-programs.conf`.
- Verified that the symlink `~/Pictures/Wallpapers/current.png` exists and points to `Moose-Lakeside.png`.
- Noticed the directory name is `Wallpapers` (plural) in the user's filesystem, whereas some documentation referred to `Wallpaper` (singular).

## Solution
- Updated `~/.config/hypr/conf.d/10-programs.conf` to use `img="/home/aj/Pictures/Wallpapers/current.png"` in the `swww` initialization script.
- Applied the change immediately using `swww img`.
- Reloaded Hyprland configuration using `hyprctl reload`.

## Files Changed
- `~/.config/hypr/conf.d/10-programs.conf`
