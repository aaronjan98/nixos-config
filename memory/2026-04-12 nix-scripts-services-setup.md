# 2026-04-12 — Nix scripts, services, and documentation

## What was worked on

- Investigated `~/.local/bin/hypr-dispatch` — confirmed it is a legacy leftover from before the script was moved to Nix. The Nix version in `modules/hypr-dispatch.nix` is strictly better (pins hyprctl to exact store path). Safe to delete the local copy.
- Added `modules/wol-sauron.nix` — Wake-on-LAN magic packet to sauron (192.168.1.255, MAC 3C:52:82:74:03:F5, port 9). Uses `pkgs.wakeonlan`. Imported in `hosts/thinkpad-t14/configuration.nix`.
- Documented the pattern for adding global commands in `CONTEXT.md` under "Adding a new global system command".
- Added `systemd/user/sync-documents.service` and `sync-documents.timer` — hourly rsync of `~/Documents/` to `aj@qwerty:/mnt/storage/desktop-sync/Documents/`. Uses `SSH_AUTH_SOCK=%t/ssh-agent.socket`. Tested successfully (status=0).
- Updated `scripts/install-user-systemd-units.sh` to enable `sync-documents.timer` on new machine setup.
- Activated the timer manually: `systemctl --user enable --now sync-documents.timer`.
- Created `docs/SERVICES.md` — overview of automated timers, directory sync table, manual scripts quick reference, and global Nix commands.
- Updated `docs/README.md` to reference SERVICES.md.
- Fixed `~/.config/ai/skills/save-session/SKILL.md` to save sessions in the primary repo worked on, not the spawn directory.

## Key decisions

- Global system commands → `modules/<name>.nix` with `writeShellScriptBin` + `environment.systemPackages`. Never `~/.local/bin/` for reproducible things.
- `~/Documents/` sync is via user systemd timer (not a manual alias), so it runs reliably in the background.
- SSH auth for the sync service relies on the user ssh-agent socket (`%t/ssh-agent.socket`) — no sudo or system-level permissions needed.

## Open questions / next steps

- Delete `~/.local/bin/hypr-dispatch` (contents are identical to the Nix version, safe to remove).
- Run `nixos-rebuild switch` to make `wol-sauron` available system-wide.
