# Multi-Host Refactor Spec

**Branch:** `multi-host`
**Goal:** Refactor the monolithic ThinkPad config into a shared base + thin per-host overrides, add Framework 13 AMD as a second host, and lay the foundation for host-selectable modules (e.g. pentest).

---

## Target directory structure

```
hosts/
  common/
    default.nix          ← shared config (packages, desktop, audio, users, sops, services)
  thinkpad-t14/
    configuration.nix    ← imports common + hardware overrides only
    hardware-configuration.nix
    kanata/
      kanata-internal.kbd
  framework-13/
    configuration.nix    ← imports common + hardware overrides + host-specific modules
    hardware-configuration.nix   ← generated on-device during install
    kanata/
      kanata-internal.kbd        ← copy of ThinkPad kbd initially; can diverge

modules/
  pentest.nix            ← security/pentest package set, importable by any host
  (existing modules unchanged)
```

`flake.nix` gains a second `nixosConfigurations.framework-13` entry alongside the existing `thinkpad-t14` one.

---

## What goes in `hosts/common/default.nix`

Everything currently in `hosts/thinkpad-t14/configuration.nix` EXCEPT the items listed as host-specific below:

- `nix.settings`
- `zramSwap`
- `boot.loader` (systemd-boot config, configurationLimit)
- `networking` block (minus `hostName`)
- `programs` (nm-applet, ssh.startAgent, dconf, nix-ld, hyprland)
- `services` (openssh, gnome, tailscale, resolved, printing, avahi, pipewire, flatpak, blueman, sane)
- `time.timeZone` and `i18n`
- `console` defaults
- `services.xserver` / KDE Plasma / SDDM
- `sops` block (secrets, age keyFile — paths remain `../../secrets/...` relative to host dir — verify this still resolves correctly)
- `users.users.aj` definition (shell, groups, packages, hashedPasswordFile)
- `users.users.root.hashedPasswordFile`
- `security.sudo.extraRules`
- `security.rtkit`
- `hardware.bluetooth`
- `hardware.sane`
- `xdg.portal`
- `environment.sessionVariables`
- `environment.extraInit` (sops env var exports)
- `fonts`
- `environment.systemPackages` (the full shared list)
- `system.activationScripts.cursorExtensions`
- `environment.etc."xdg/mimeapps.list"`
- `nixpkgs.config.allowUnfreePredicate`

---

## What stays per-host (in each host's `configuration.nix`)

| Item | Reason |
|---|---|
| `hardware-configuration.nix` import | Always machine-specific |
| `networking.hostName` | Per-machine identity |
| `boot.kernelParams` | ThinkPad: `pcie_aspm=off`; Framework: TBD |
| `services.udev.extraRules` (mic LED rule) | ThinkPad platform LED — not present on Framework |
| `environment.etc."kanata/kanata-internal.kbd".source` | Points to host-local kanata dir |
| `aj.gitServer.authorizedKeys` | Contains host-specific SSH public keys |
| `system.stateVersion` | Set at initial install time, never changes |
| `specialArgs` references (snippetsDir, etc.) | Verify path still resolves from host dir |

---

## `modules/pentest.nix`

A standalone importable module — NOT a NixOS `specialisation`. Any host imports it to get the pentest package set. No separate boot entry, no second closure.

Start with an empty or minimal stub. Populate with tooling as the Framework setup progresses.

Candidate packages (fill in as needed):
- `nmap`, `wireshark`, `burpsuite`, `metasploit`, `aircrack-ng`
- `john`, `hashcat`, `hydra`
- `sqlmap`, `gobuster`, `ffuf`
- `ghidra`, `radare2`
- networking: `netcat`, `tcpdump`, `ettercap`

---

## `hosts/framework-13/` notes

- Use `nixos-hardware` flake input → `nixos-hardware.nixosModules.framework-13-7040-amd` for AMD-specific tuning (power, fingerprint, ALS)
- `hardware-configuration.nix` is a placeholder until the machine is physically installed
- `system.stateVersion` will be set at install time
- `networking.hostName` — decide name before flashing (e.g. `framework-13` or something personal)
- Kanata: copy ThinkPad kbd file as starting point; Framework keyboard is close enough but keep separate so it can diverge
- Import `../../modules/pentest.nix` here

---

## flake.nix changes

1. Add `nixos-hardware` input:
   ```nix
   nixos-hardware.url = "github:NixOS/nixos-hardware";
   ```
2. Add `nixos-hardware` to `outputs` args
3. Add second configuration:
   ```nix
   nixosConfigurations.framework-13 = nixpkgs.lib.nixosSystem {
     inherit system;
     specialArgs = { inherit nix-tools pkgsUnstable nixos-hardware; snippetsDir = ./snippets; };
     modules = [
       ({ ... }: { nixpkgs.overlays = [ myOverlay ]; })
       ./hosts/framework-13/configuration.nix
       sops-nix.nixosModules.sops
       nix-flatpak.nixosModules.nix-flatpak
       nixos-hardware.nixosModules.framework-13-7040-amd
     ];
   };
   ```
   (Verify the exact module name against nixos-hardware repo before using)

---

## Progress checklist

- [x] Step 1 — Create `multi-host` branch
- [x] Step 2 — Extract `hosts/common/default.nix` from ThinkPad config
- [x] Step 3 — Slim `hosts/thinkpad-t14/configuration.nix` to overrides only
- [x] Step 4 — Verify ThinkPad: `nrt` then `nrs` (identical derivation confirmed)
- [x] Step 5 — Create `hosts/framework-13/` skeleton (placeholder hardware config)
- [x] Step 6 — Create `modules/pentest.nix` stub
- [x] Step 7 — Add `nixos-hardware` input and `framework-13` nixosConfiguration to `flake.nix`
- [x] Step 8 — Evaluate Framework config without building: clean derivation confirmed
- [ ] Step 9 — Merge `multi-host` → `main`
- [ ] Step 10 — Flash Framework, generate real hardware config, pull repo, `nixos-rebuild switch --flake ~/nixos-config#framework-13`

---

## Key constraints / decisions

- **Pentest as module, not specialisation** — always-on on Framework, no separate boot entry
- **Hosts maximally identical** — host files are thin; anything that can be shared should be
- **Kanata files are per-host** even if identical at first — prevents cross-host coupling
- **nixpkgs-unstable pin** — currently pinned to `01fbdeef22b76df85ea168fbfe1bfd9e63681b30`; applies to both hosts via shared flake.nix
- **sops secrets** — both hosts share the same `secrets/` directory; per-host secrets can be added as separate yaml files if needed later
- **Test on ThinkPad before touching Framework** — ThinkPad is the validation machine throughout the refactor
