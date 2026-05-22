# 2026-05-19 — Framework 13 Bootstrap (in progress)

## Context
First boot of Framework 13 AMD onto NixOS multi-host config (branch multi-host, now merged to main).
Machine previously had Fedora with LUKS. Full wipe and fresh NixOS install.

---

## What was attempted and what failed

### nixos-install --flake failed
Tried `sudo nixos-install --flake ~/nixos-config#framework-13 --no-root-passwd` from live ISO.
Failed for two reasons:
1. `pkgs.requireFile` — Wolfram installer (6.9GB) not in Nix store on fresh machine
2. SOPS age key doesn't exist yet at `/var/lib/sops-nix/key.txt` during initial install

**Resolution:** use basic `nixos-install` (no --flake) for initial boot, then rebuild with flake after bootstrap.

### Tools not available on basic install
`git`, `gpg`, `pass`, `pinentry-curses` are not present on the minimal generated config.
**Resolution:** `nix-shell -p gnupg pass git pinentry-curses` at every session until full rebuild.

### GPG private key import failed silently
`gpg --import /tmp/pass-gpg-private.asc` gave "no pinentry" error.
**Resolution:** configure pinentry-curses BEFORE importing:
```bash
mkdir -p ~/.gnupg
echo "pinentry-program $(which pinentry-curses)" > ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
```

### ThinkPad SSH is localhost-only
MANUAL-BOOTSTRAP.md suggests `scp` from ThinkPad but ThinkPad sshd only listens on 127.0.0.1.
**Resolution:** use netcat for all file transfers.

### Netcat pattern that works
- **Sender connects, receiver listens** (preferred — Framework listens, no ThinkPad firewall issue)
- Open port on Framework first: `iptables -I nixos-fw -p tcp --dport 9999 -j nixos-fw-accept`
- Framework (receiver/listener): `nc -l 9999 > /tmp/file`
- ThinkPad (sender/connector): `nc -N <framework-ip> 9999 < /tmp/file`
- `-N` must be on the SENDER/CONNECTOR side only

### Chicken-and-egg: SSH key needed to clone pass
Cloning password store requires SSH key authorized on homelab git server.
But SSH keys are in pass. Need to break the cycle by transferring id_rsa first via netcat.
**Resolution:** transfer `~/.ssh/id_rsa` from ThinkPad before cloning pass, then `chmod 600`.

### nixos-rebuild switch failed: Wolfram not in Nix store
`pkgs.requireFile` check fires at build time.
**Resolution:** `bash ~/nixos-config/scripts/sync-distfiles.sh wolfram` (rsync from NAS via SSH).
Then: `nix store add-file /var/lib/distfiles/wolfram/Wolfram_14.3.0_LIN_Bndl.sh`
Note: sync-distfiles.sh is in nixos-config/scripts/ and uses `id_rsa` to SSH to `qwerty.home`.

### Running as root, not aj user
Basic install has no `aj` user. Everything lands in /root/ instead of /home/aj/.
Password store cloned to /root/.password-store.
This is expected for the bootstrap phase — after full rebuild, aj user exists and normal login works.

---

## Steps that worked (in order)

1. Boot NixOS USB (disable Secure Boot in UEFI first — Framework requires F2 for UEFI, must plug USB before powering on)
2. Connect WiFi: `sudo nmtui`
3. Partition disk (see NIXOS-INSTALL.md steps 4-10)
4. `sudo nixos-generate-config --root /mnt`
5. Transfer hardware-configuration.nix to ThinkPad via netcat, commit + push
6. `git pull` on Framework (reset --hard to origin/main first if needed)
7. `sudo nixos-install` (no --flake), set temp root password
8. Reboot, remove USB, log in as root
9. `nmcli device wifi connect "SSID" password "PASS"`
10. `nix-shell -p gnupg pass git pinentry-curses`
11. Configure pinentry-curses (see above)
12. Open Framework firewall: `iptables -I nixos-fw -p tcp --dport 9999 -j nixos-fw-accept`
13. Transfer `~/.ssh/id_rsa` from ThinkPad → Framework via netcat
14. `chmod 600 /root/.ssh/id_rsa`
15. Transfer GPG public + private keys from ThinkPad → Framework via netcat
16. `gpg --import /tmp/pass-gpg-public.asc`
17. `gpg --import /tmp/pass-gpg-private.asc` (pinentry prompts passphrase)
18. `rm /tmp/pass-gpg-*.asc`
19. `git clone ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/password-store.git ~/.password-store`
20. `pass ls` — verify
21. `nix-shell -p git --run "git clone https://github.com/aaronjan98/nixos-config /root/nixos-config"` (or from inside nix-shell)
22. `bash /root/nixos-config/scripts/restore-secrets.sh`
23. `bash /root/nixos-config/scripts/sync-distfiles.sh wolfram`
24. `nix store add-file /var/lib/distfiles/wolfram/Wolfram_14.3.0_LIN_Bndl.sh`
25. `nixos-rebuild switch --flake /root/nixos-config#framework-13` ← IN PROGRESS

---

## Open items after rebuild succeeds
- Update MANUAL-BOOTSTRAP.md and NEW-MACHINE-SETUP.md with refined flow
- Write clean step-by-step guide to zettelkasten (homelab project dir)
- Fix restore-secrets.sh hardcoded age key path
- Store Framework SSH host key in pass under laptop/framework-13/ssh/
- Add Framework's own ed25519 SSH key to aj.gitServer.authorizedKeys in host config
