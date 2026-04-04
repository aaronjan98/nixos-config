# Session: 2026-04-03 — Ghostty & Neovide Setup

## What was worked on
- Evaluated switching from kitty to ghostty terminal emulator
- Audited all kitty references across dotfiles and nixos-config
- Added ghostty and neovide to the system, configured both
- Cleaned up remaining uncommitted dotfile changes

## Key decisions

### Ghostty
- Keeping kitty as default terminal (Super+Q), ghostty added as Super+G
- `TERMINAL` env var left as `kitty` — no need to change since kitty is still primary
- Ghostty window class is `com.mitchellh.ghostty` (needed for hyprland windowrules)
- `shell-integration-features = no-cursor` required to prevent shell integration from overriding block cursor shape
- Background: `#1a0810` (dark raspberry), opacity: 0.85, cursor: block, `#E62600` (ferrari red)

### Neovide
- Installed as a separate GUI Neovim frontend, not a terminal emulator
- Launched via Super+N from Hyprland
- Cursor color required explicit `-Cursor` hl group in `guicursor` string — setting `Cursor` hl alone doesn't work without it
- Used `if vim.g.neovide` guard in init.lua so settings don't affect terminal Neovim
- Final animation: no vfx mode, `animation_length = 0.13`, `trail_size = 0.8` (smooth elastic stretch)
- Cursor: ferrari red `#E62600` with autocmd to reapply after colorscheme changes

## Files changed
- `~/.config/ghostty/config` — created
- `~/.config/hypr/conf.d/10-programs.conf` — unchanged (kept `$terminal = kitty`)
- `~/.config/hypr/conf.d/20-binds.conf` — added Super+G, Super+N, updated windowrule
- `~/.config/nvim/init.lua` — added neovide block
- `hosts/thinkpad-t14/configuration.nix` — added `ghostty`, `neovide` to systemPackages

## Open questions
- Ghostty notification integration (shell integration for command-complete pings) not yet wired up — requires sourcing shell integration script in `.bashrc`

## Next steps
- Try ghostty's notification feature by enabling shell integration in `.bashrc`
- Tune neovide animation values further if desired
