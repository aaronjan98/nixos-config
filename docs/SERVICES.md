# Services and Automated Jobs

This document lists the user systemd services and timers tracked in `systemd/user/`, and provides an overview of what runs automatically vs. what must be triggered manually.

Tracked unit source files live in `~/nixos-config/systemd/user/`.
Active installed copies live in `~/.config/systemd/user/`.

To install or reinstall all units: run `scripts/install-user-systemd-units.sh`.

---

## Automated timers

### `export-workspace-state.timer` + `export-workspace-state.service`

**What it does:**
Scans the live `~/Repositories` tree and writes the current state into the tracked workspace snapshot (`tools/workspace/`).

**Schedule:** 5 minutes after boot, then every hour.

**Why it runs automatically:** Keeps the workspace snapshot in sync passively so it is always up to date for bootstrap or multi-machine sync without manual intervention.

---

### `sync-documents.timer` + `sync-documents.service`

**What it does:**
Rsyncs `~/Documents/` to `aj@qwerty:/mnt/storage/desktop-sync/Documents/` — a homelab NAS-backed storage path on the `qwerty` machine.

**Schedule:** 5 minutes after boot, then every hour.

**Why it runs automatically:** Keeps a live backup of local documents on the homelab without requiring manual invocation.

**SSH auth:** Uses `SSH_AUTH_SOCK=%t/ssh-agent.socket` (the running user ssh-agent). Requires an SSH key for `aj@qwerty` to be loaded in the agent at service start time.

**Manual trigger:**
```
systemctl --user start sync-documents.service
```

---

## Inactive / manually managed units

### `video-summary.path` + `video-summary.service` + `video-summary.timer`

Disabled by default. Left in tracked source for potential future use. Not part of normal operation.

---

## Directory sync overview

| Source | Destination | Mechanism | Frequency |
|--------|-------------|-----------|-----------|
| `~/Documents/` | `aj@qwerty:/mnt/storage/desktop-sync/Documents/` | rsync over SSH (systemd timer) | hourly |

---

## Manually-run scripts

See `docs/SCRIPTS.md` for full descriptions. Quick reference:

| Script | When to run |
|--------|-------------|
| `bootstrap-new-machine.sh` | New machine bring-up |
| `bootstrap-workspace.sh` | Recreate `~/Repositories` layout |
| `export-workspace-state.sh` | Force a workspace snapshot export |
| `sync-workspace-repos.sh` | Align repos with manifest across machines |
| `install-user-systemd-units.sh` | Install/reinstall tracked user units |
| `restore-secrets.sh` | Restore SSH material and SOPS age key from `pass` |
| `rsync-git-server-mirror.sh` | Mirror homelab git server to local git server |
| `sync-distfiles.sh` | Copy cached distfiles from NAS to local |
| `seed-local-git-server.sh` | Set up local git server structure |

---

## Printing (CUPS)

Enabled via `services.printing.enable = true` and `services.avahi` in `hosts/thinkpad-t14/configuration.nix`.

**Add or manage printers:** `http://localhost:631/`

**Check printer status:**
```
lpstat -p
```

**List queued jobs:**
```
lpstat -o
```

**Cancel a job:**
```
lprm <job-id>
```

Printer discovery on the local network is handled by avahi (mDNS). If a network printer is not appearing in CUPS, confirm avahi-daemon is running:
```
systemctl status avahi-daemon
```

If a driver is missing, add `pkgs.gutenprint` (generic) or a vendor package (e.g. `pkgs.hplip` for HP) to `environment.systemPackages` and rebuild.

---

## Global commands (Nix modules)

These are installed system-wide via `environment.systemPackages` and available in any terminal after `nixos-rebuild switch`.

| Command | What it does |
|---------|-------------|
| `hypr-dispatch` | Runs `hyprctl dispatch` with auto-detection of Hyprland instance signature |
| `wol-sauron` | Sends a Wake-on-LAN magic packet to sauron (192.168.1.255, MAC 3C:52:82:74:03:F5) |
| `new-homelab-repo` | Creates a bare repo on sweetpea + Forgejo repo + post-receive hook in one command |
| `install-forgejo-hooks` | Installs forgejo-sync hook on all sweetpea repos with a matching Forgejo counterpart |
| `tea` | Forgejo CLI; pre-configured login `home` pointing to `git.aaronjanovitch.com` as user `aj` |

See `docs/PACKAGES.md` and `CONTEXT.md` for how to add new commands.

---

## Forgejo git server

Forgejo runs on sweetpea at `https://git.aaronjanovitch.com` as a web UI mirror of the
bare repos at `/srv/git/repos/`. The bare repos are the source of truth — Forgejo is kept
in sync automatically via post-receive hooks.

**Workflow for a new repo:**
```bash
new-homelab-repo my-project           # private (default)
new-homelab-repo my-project --public  # public
cd my-project && git init
git remote add home git@sweetpea-git:/srv/git/repos/my-project.git
git push home main
# Forgejo mirrors automatically via hook
```

**Day-to-day:** `git push home main` — hook fires, Forgejo updates. Never push to Forgejo directly.

**`$FORGEJO_TOKEN`:** Exported in `~/.bashrc` from `/run/secrets/forgejo_token` (SOPS secret).
`environment.extraInit` does NOT work for this — PAM sets `__NIXOS_SET_ENVIRONMENT_DONE=1`
before shell init, which causes the NixOS guard to skip `/etc/set-environment` in interactive shells.

**SSH alias:** Git remotes use `git@sweetpea-git:` (not `git@sweetpea:`). The `sweetpea-git`
entry in `~/.ssh/config` encodes `User git` and `Port 2222` — necessary because the short
SCP-style git URL syntax cannot encode a non-default port.

**Architecture doc:** `~/Repositories/self-hosted/homelab/Raymer/project-memory/forgejo-sync.md`
