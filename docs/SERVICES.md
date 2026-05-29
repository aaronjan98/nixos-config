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

Enabled via `services.printing.enable = true` and `services.avahi` in `hosts/common/default.nix` (so all hosts that import the common module get printing — currently disabled only on the `pi` host via `lib.mkForce false`).

The household printer is an **Epson ET-2850** on the home network's IoT SSID (`Connect here IoT`, 2.4 GHz only — see homelab `docs/network.md` for why the SSID was split). It is discovered via Avahi/mDNS and registered as a CUPS queue automatically — no driver package is needed for IPP-Everywhere capable printers like this one.

### Architecture — how the printer ends up as a CUPS queue

Three daemons cooperate to make a network printer printable:

- **`avahi-daemon`** — listens for mDNS announcements on the LAN, resolves `<printer>.local` hostnames, populates `nss-mdns` so the system can look up `.local` names
- **`cupsd`** — the CUPS server, accepts print jobs, manages queues, talks IPP to the printer
- **`cups-browsed`** — bridges DNS-SD-discovered remote printers into local CUPS queues using an `implicitclass://` indirection, so the actual IPP endpoint can change underneath without breaking the queue

The implicit-class indirection is what makes the printer "self-healing" — if the printer changes IP, sleeps and wakes, or rejoins the network on a different SSID, the user-facing queue keeps working because `cups-browsed` rebinds the underlying URI transparently.

### Day-to-day commands

```sh
lpstat -p                                    # queue status: enabled/disabled, idle/printing, last error
lpstat -v                                    # device-uri for each queue (tells you queue origin — see below)
lpstat -o                                    # all queued / in-progress jobs
lpstat -W not-completed                      # all in-flight jobs (cleaner than -o)
lpstat -W not-completed -o <queue-name>      # in-flight jobs for one queue
lpstat -t                                    # full system status — verbose but complete

cancel <job-id>                              # cancel one job
cancel -a <queue-name>                       # cancel ALL jobs on a queue (use when queue is stuck)

sudo lpadmin -x <queue-name>                 # delete a queue
sudo lpadmin -d <queue-name>                 # set the default queue
```

The CUPS web UI at `http://localhost:631/` provides the same controls in a browser.

### Reading `lpstat -v` — three URI families to recognize

When debugging or cleaning up, the `device-uri` reveals where a queue came from and how robust it is.

| URI prefix | Origin | Behavior |
|------------|--------|----------|
| `ipp://<host>.local:631/ipp/print` | Static auto-add at discovery time | Fragile — locked to a specific hostname/path captured when the queue was created; silently breaks if the printer's IPP endpoint shifts |
| `implicitclass://<queue-name>/` | `cups-browsed` indirection | Robust — re-binds to whatever IPP target is currently advertised via DNS-SD |
| `dnssd://...` | Direct DNS-SD URI | Resolves at print time via Avahi; works as long as DNS-SD is healthy |
| `ipp://<ip>:631/ipp/print` | Manual add by IP | Pinned to one IP — breaks on DHCP renewal |

**Preference order:** `implicitclass://` > `dnssd://` > `ipp://<ip>` > `ipp://<hostname>.local`. If you see two queues for the same physical printer and one is `implicitclass://`, keep that one and delete the others.

### Verifying mDNS resolution

```sh
avahi-resolve -n EPSON139ABF.local           # → 10.0.50.114 (the printer's current IP)
avahi-browse -art | grep -i epson             # list every Bonjour service the printer advertises
systemctl status avahi-daemon                 # confirm avahi is running
```

### Common gotchas

#### Printer is "online" but AirPrint / Bonjour can't find it

Consumer Epsons (the ET-2850 included) sleep aggressively. **While asleep, they stop sending mDNS / Bonjour announcements**, so the print dialog on phones and laptops never sees the printer. The IP-layer is fine — `ping` works, the web UI responds — but AirPrint discovery is silent.

**Quick wake from any always-on host on the LAN:**
```sh
curl -s -o /dev/null http://EPSON139ABF.local/      # any TCP connect wakes the printer
```

The cups-browsed `implicitclass://` queue will re-bind within a few seconds once the printer announces itself again.

**Permanent fix:** in the printer's panel, set Power Saving → Sleep Timer to a much longer interval (or disable it), and enable "Wake from Sleep" → "Wake by Network" if available.

#### Two queues for the same printer (one works, one doesn't)

Common after re-pairing the printer or moving it between SSIDs. CUPS keeps the original queue, but cups-browsed creates a new implicitclass one. Both appear in `lpstat -p` and only one (the implicitclass) actually works — the other piles up stuck jobs marked "The printer is unreachable at this time."

**Cleanup:**
```sh
lpstat -v                                    # identify the stale queue (it'll be the ipp:// one, not implicitclass://)
cancel -a <stale-queue-name>                 # clear stuck jobs
sudo lpadmin -x <stale-queue-name>           # delete it
lpstat -p                                    # confirm only the implicitclass queue remains
```

#### Printer recently moved to a different SSID — old queue is stuck

This is the same scenario as above. The static `ipp://<hostname>.local:...` URI was captured when the printer was on the previous SSID; even if Avahi still resolves the hostname correctly, the CUPS IPP backend can fail in subtle ways (TLS handshake mismatch, capability negotiation, stale port path). Delete and let cups-browsed re-create from the current DNS-SD announcement.

#### No driver appears to load (legacy printers only)

The ET-2850 uses IPP Everywhere / driverless printing — no PPD needed. For older printers that *do* need a driver:

- Generic: add `pkgs.gutenprint` to `environment.systemPackages`
- HP: add `pkgs.hplip`
- Brother: add the vendor-provided package (varies)

Then `nixos-rebuild switch` and re-add the printer via the CUPS web UI.

### Scanning

The ET-2850 is also a scanner. SANE is enabled in the same `hosts/common/default.nix` block via `hardware.sane.enable = true` and `hardware.sane.extraBackends = [ pkgs.sane-airscan ]` for eSCL/AirScan over the network. Use any SANE frontend (`simple-scan`, `xsane`, GIMP's Acquire menu) and the printer should appear automatically — no separate configuration needed.

---

## Research tools

### Zotero

Reference manager for academic papers. Installed from `pkgsUnstable` (Zotero 9) via overlay
in `flake.nix` — the stable nixpkgs version (7.x) is incompatible with Better BibTeX 9.x.

**Plugins installed:**
- Better BibTeX (BBT) — stable cite keys and BibTeX/CSL export for LaTeX/Pandoc

**Sync setup:**
- Metadata: Zotero account (free tier, cloud) — handles titles, authors, tags, collections
- PDF attachments: Nextcloud WebDAV at `https://cloud.janovitch.com/remote.php/dav/files/aj/zotero`
- App password for WebDAV is stored in `pass` under the Zotero entry

**Where PDFs actually live:**
Attachments sync to Nextcloud → stored on qwerty NAS at
`/mnt/storage/nextcloud/data/aj/files/zotero/`. Not inside the Docker container.

**Workflow:**
- Capture papers from the browser using the Zotero Connector (Firefox extension)
- Organize into Collections per project
- BBT assigns stable cite keys (e.g. `nowak1992`) for use in LaTeX `\cite{}`
- Export BibTeX: right-click collection → Export Collection → Better BibTeX

**LibreOffice plugin note:**
Zotero's LibreOffice plugin installer fails on NixOS (looks for `/opt`, which doesn't exist).
Use BBT + BibTeX export instead — works with LaTeX and Pandoc.

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
