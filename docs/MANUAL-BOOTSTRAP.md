# Manual Bootstrap

This document covers the complete process for bringing a new machine from a
fresh NixOS base install to a fully configured system.

The process has two phases that run on different users:

- **Root phase** — automated via `bootstrap-root.sh`, handles trust material
  (GPG, SSH, pass, age key) and the first `nixos-rebuild switch`
- **AJ phase** — automated via `post-rebuild-setup.sh`, handles dotfiles,
  git remotes, SSH key generation, and workspace setup

---

## Before you start — on ThinkPad

Make sure `send-secrets-to-new-machine.sh` is available and your GPG key is
accessible. You'll run this when `bootstrap-root.sh` pauses and waits for it.

---

## Phase 1 — Root bootstrap (on new machine, as root)

### 1. Connect to Wi-Fi

    nmcli device wifi connect "SSID" password "PASS"

### 2. Clone nixos-config

The bootstrap script lives in the repo, so clone it first:

    nix-shell -p git --run \
      "git clone https://github.com/aaronjan98/nixos-config /root/nixos-config"

### 3. Enter nix-shell with required tools

    nix-shell -p gnupg pass git netcat-gnu pinentry-curses age

### 4. Run the bootstrap script

    bash /root/nixos-config/scripts/bootstrap-root.sh <flake-hostname>

Replace `<flake-hostname>` with the machine's flake attribute name,
e.g. `framework-13`.

The script handles everything in order:

1. Configures `pinentry-curses` for GPG
2. Opens a netcat listener and prints the command to run on ThinkPad
3. Receives the secrets bundle (SSH key + GPG keys) from ThinkPad
4. Imports GPG keys — **passphrase prompt will appear here**
5. Sets GPG trust to ultimate
6. Clones the password store from the homelab git server
7. Runs `restore-secrets.sh` (SSH files + SOPS age key from pass)
8. If the age key is missing (new machine): generates one, stores it in pass,
   and **pauses with instructions** to add it to `secrets/*.yaml` on ThinkPad
9. Optionally syncs Wolfram distfiles from the NAS
10. Runs `nixos-rebuild switch --flake /root/nixos-config#<hostname>`

### 5. On ThinkPad — send secrets when prompted

When the script is listening, run in a ThinkPad terminal:

    bash ~/nixos-config/scripts/send-secrets-to-new-machine.sh <new-machine-ip>

This bundles `~/.ssh/id_rsa`, GPG public key, and GPG private key, and sends
them via netcat. The new machine receives and unpacks automatically.

### 6. If a new age key was generated

The script will pause and print something like:

    On ThinkPad, run:
      sops --rotate --add-age <pubkey> \
        secrets/users.yaml secrets/hf-token.yaml \
        secrets/context7.yaml secrets/opencode.yaml \
        secrets/forgejo.yaml
      g ci -am 'secrets: add <hostname> age key'
      g pushall

Do this on ThinkPad, then press Enter on the new machine to continue.

---

## Phase 2 — AJ setup (on new machine, as aj)

After `nixos-rebuild switch` succeeds, log out of root and log in as `aj`.

### 1. Clone nixos-config as aj

    git clone https://github.com/aaronjan98/nixos-config ~/nixos-config

### 2. Run post-rebuild setup

    bash ~/nixos-config/scripts/post-rebuild-setup.sh

The script handles:

1. Sets GPG key trust to ultimate
2. Adds `home`, `hub`, `local` remotes to `~/nixos-config`
3. Clones the dotfiles bare repo if missing and checks out into `$HOME`
   (backs up any conflicting files automatically)
4. Generates an `ed25519` SSH key for this machine and prints the public key
5. Authenticates Tailscale (`sudo tailscale up`)
6. Runs `bootstrap-new-machine.sh` (workspace setup, git server seeding, etc.)

The system-level `sync-leave-preflight` service is pulled in automatically
via `hosts/common` (no manual enable needed). It hooks `sleep.target` to
toast a dirty-repo warning before the machine suspends — see Phase 3
below to validate it after rebuild.

### 3. Add the new ed25519 key to NixOS config

The script prints the public key. Add it to
`hosts/<hostname>/configuration.nix`:

    aj.gitServer.authorizedKeys = [
      "ssh-ed25519 AAAA... aj@<hostname>"
      "ssh-rsa AAAA... aaronjan98@gmail.com"   # keep the existing RSA key
    ];

Then commit, push, and rebuild:

    g ci -am 'hosts/<hostname>: add ed25519 SSH key'
    g pushall
    nrs

---

## Phase 3 — Smoke test

After the rebuild, verify the cross-machine flows actually work:

1. **Keybinds**: press `Super+A` (sync-arrive) and `Super+E` (sync-leave) —
   both should toast (green "OK" or yellow "action needed").
2. **Pre-suspend toast**: `sudo systemctl start sync-leave-preflight` —
   should exit cleanly with a toast. Real validation: close the lid, wake,
   confirm the toast is in your notification history.
3. **Push reach**: `g pushall` on `~/nixos-config` should push to `home`,
   `hub`, and `local` without errors. Likewise `dot pushall`.
4. **Syncthing**: confirm the new host appears in the Syncthing UI on the
   other peers and shares `Documents`/`Pictures`.

---

## What requires human intervention

| Step | Why it can't be automated |
|------|--------------------------|
| GPG passphrase during import | Security — private key decryption |
| Age key update on ThinkPad | Requires access to ThinkPad secrets |
| Tailscale auth | Requires browser login or pre-generated auth key |
| Adding ed25519 key to NixOS config | Needs commit + push + rebuild cycle |

---

## Troubleshooting

**`nrs` applies the wrong host config** — the `nrs` alias uses `$(hostname)`
to pick the flake attribute. Do not run `nrs` until after the first successful
rebuild sets the correct hostname. Use the full explicit command instead:

    sudo nixos-rebuild switch --flake ~/nixos-config#<hostname>

**SOPS activation fails on first rebuild** — fixed in the config via
`neededForUsers = true` on password secrets. If you still see a "failed to
lookup user aj" error, log into a TTY as root and run `passwd aj` to set the
password manually, then log in as aj and proceed with Phase 2.

**Wolfram build fails** — the Wolfram installer must be in the Nix store
before the build. Run:

    bash ~/nixos-config/scripts/sync-distfiles.sh wolfram
    nix --extra-experimental-features 'nix-command' store add-file \
      /var/lib/distfiles/wolfram/Wolfram_14.3.0_LIN_Bndl.sh
    nrs

**`seed-local-git-server.sh` reports "fatal: not a git repository" for
every existing mirror** — `/srv/git/` is mode 700, blocking traversal by
group `git` members. Current `seed-local-git-server.sh` self-heals this
(`sudo chmod 2750 /srv/git`), but if you're on an older copy of the
script, apply the chmod manually and re-run.
