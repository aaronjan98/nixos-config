# Secrets and Trust Material

This document explains the secrets-related pieces needed for a new machine setup.

## Main categories

### GPG keys
Needed to decrypt and use `pass`.

Without working GPG secret keys, the password store cannot be used to restore other material.

### Password store
The password store contains bootstrap trust material, including:
- SSH files
- SOPS age key material

This is primarily for the manual/new-machine trust phase, not for every runtime secret the system uses.

### SOPS-encrypted repo secrets
The `secrets/*.yaml` files in this repo hold encrypted declarative secrets consumed by `sops-nix`.

Examples currently include:
- user password hashes
- Hugging Face token material
- Context7 API key material
- OpenCode Zen API key material
- Obsidian local API key material

Known password-store remotes may include:
- `ssh://git@localhost/srv/git/repos/password-store.git`
- `ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/password-store.git`

### SSH material
SSH files are restored from `pass` using the prefix:

- `laptop/<hostname>/ssh`

These are written into:
- `~/.ssh/`

#### Per-host SSH config convention

Each host's `~/.ssh/config` is stored separately in pass and may differ across hosts in `IdentityFile` lines. The standing conventions are:

- `Host sweetpea-git` (homelab git server) → `IdentityFile ~/.ssh/id_rsa`. `id_rsa` is the shared cross-machine key already authorized on the homelab, so any new host can bootstrap without manual `authorized_keys` editing.
- `Host *.home` and other homelab aliases → `IdentityFile ~/.ssh/id_rsa` for the same reason.
- Machine-specific identity keys (`~/.ssh/<hostname>`, e.g. `~/.ssh/thinkpad-t14`) exist for local git server access (authorized in each host's `configuration.nix` via `aj.gitServer.authorizedKeys`) and any per-host services you choose. They are not used for homelab git access.

Adding a new host:
1. On an existing source-of-truth host, `pass cp laptop/<existing>/ssh/<file> laptop/<new-host>/ssh/<file>` for each file that should propagate (skip the existing host's machine identity key).
2. Push pass.
3. On the new host, after GPG + pass are working, run `restore-secrets.sh`.
4. Generate the new host's machine identity key locally (`~/.ssh/<new-host>`), add the pubkey to that host's `configuration.nix`, push.

### SOPS age key
The SOPS age key is stored in `pass` at:

- `laptop/thinkpad-t14-nixos/sops/age`

It is restored to:

- `/var/lib/sops-nix/key.txt`

---

## Two secret layers

This setup intentionally uses two different secret systems for two different jobs.

### 1. `pass` handles bootstrap trust material

Use `pass` for the secrets needed to make a fresh machine trusted enough to continue:
- SSH keys/config
- the SOPS age key

Why this exists:
- a new machine cannot use repo-encrypted SOPS secrets until it already has the age key
- the age key itself therefore has to come from outside the repo during bootstrap

### 2. `sops-nix` handles declarative runtime secrets

Once the age key is restored and a rebuild runs, `sops-nix` decrypts tracked repo secrets into runtime files under `/run/...`.

This is the normal pattern for ongoing system operation.

---

## How repo-encrypted secrets appear at runtime

After `nixos-rebuild switch` with a working age key:

- secrets without a custom path typically appear under `/run/secrets/<name>`
- secrets with an explicit `path = ...` appear exactly where configured

Current examples:
- `passwords/aj` → `/run/sops-nix/passwords_aj`
- `passwords/root` → `/run/sops-nix/passwords_root`
- `context7_api_key` → `/run/secrets/context7_api_key`
- `hf_token` → `/run/secrets/hf_token`
- `opencode_zen_api_key` → `/run/secrets/opencode_zen_api_key`

---

## How secrets are consumed on this system

There are multiple valid runtime consumption patterns in this repo.

### Direct file use

Some settings point directly at the decrypted runtime file path.

Examples:
- user password hashes via `hashedPasswordFile`
- scripts like the Obsidian IPC helper reading `config.sops.secrets.<name>.path`

### Export into environment variables

Some secrets are read from their runtime file in `environment.extraInit` and exported for tools that expect env vars.

Current examples:
- `CONTEXT7_API_KEY`
- `HUGGING_FACE_HUB_TOKEN`
- `OPENCODE_ZEN_API_KEY`

### Refreshing exported secret env vars in the current shell

After `nixos-rebuild switch`, an already-running shell session may still have the old environment.

To reload the NixOS exported environment variables in the current shell, run:

    unset __NIXOS_SET_ENVIRONMENT_DONE
    . /etc/set-environment

Then verify, for example:

    test -n "$CONTEXT7_API_KEY" && echo "Context7 key is set"

Notes:
- logging out and back in also works
- `/etc/set-environment` may print permission errors for unrelated secrets if the current user cannot read one of the exported source files
- in this setup, `hf_token` may produce `cat: /run/secrets/hf_token: Permission denied` while other readable exports like `CONTEXT7_API_KEY` and `OPENCODE_ZEN_API_KEY` still refresh correctly

---

## Editing encrypted repo secrets

When editing an existing encrypted SOPS file in this repo, use `sops edit`.

Typical workflow from the repo root:

    export SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt
    sops edit secrets/context7.yaml

Notes:
- The encrypted file already contains the metadata SOPS needs for decryption and re-encryption.
- For new files under `secrets/`, run the command from the repo root so `.sops.yaml` is found.

### External tools reading `/run/...` directly

Tracked or external config outside this repo can read the `sops-nix` runtime file directly without storing the secret in that config.

Example pattern:
- Pi config in dotfiles can use `!cat /run/secrets/opencode_zen_api_key`

This keeps the secret out of tracked dotfiles while still using declarative Nix-managed secret material.

---

## Trust bootstrap order

1. restore or import GPG secret keys
2. ensure `pass` works
3. restore SSH files
4. restore SOPS age key
5. proceed with workspace/bootstrap automation
6. run `nixos-rebuild`

---

## Transfer GPG keys from an existing trusted machine

### Transfer with password authentication

    scp -o IdentitiesOnly=yes -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      pass-gpg-private.asc pass-gpg-public.asc \
      aj@192.168.1.XXX:/home/aj/

### Or transfer using an existing trusted SSH key

    scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519.fedora \
      pass-gpg-private.asc pass-gpg-public.asc \
      aj@192.168.1.XXX:/home/aj/

---

## Import GPG keys on the new machine

    gpg --import ~/pass-gpg-public.asc
    gpg --import ~/pass-gpg-private.asc
    rm -f ~/pass-gpg-public.asc ~/pass-gpg-private.asc
    gpg --list-secret-keys --keyid-format=long

Verify that the expected secret key appears.

---

## Verify `pass`

Once GPG is working, verify:

    pass ls

If the password store repo itself is not present locally, clone it first, then verify again.

---

## Restore SSH files and SOPS age key

After `pass` works, run:

    ~/nixos-config/scripts/restore-secrets.sh

This should restore:
- SSH files to `~/.ssh`
- age key to `/var/lib/sops-nix/key.txt`

Verify afterwards:

    ls -la ~/.ssh
    sudo ls -l /var/lib/sops-nix/key.txt

### Saving SSH material back to pass

After editing `~/.ssh/config` (or any other tracked SSH file), save it back with:

    ~/nixos-config/scripts/backup-secrets.sh
    pass git push

To propagate a change to another machine's pass entry:

    pass cp laptop/thinkpad-t14-nixos/ssh/config laptop/framework-13/ssh/config
    pass git push

---

## After the first rebuild

Once the SOPS age key is restored and the system rebuild succeeds, the repo-managed secrets become available through `sops-nix` runtime files.

At that point:
- `pass` is still the source of truth for bootstrap trust material
- SOPS becomes the normal source of truth for tracked runtime secrets used by the system and related tools

This is why both systems exist: one bootstraps trust, the other manages ongoing declarative secret delivery.

---

## Important note

This setup intentionally assumes that the first trust bootstrap is manual.

For now, do not rely on the new machine being able to fetch its own GPG secret keys automatically from the homelab.

Use an existing trusted machine to transfer/import those keys first.

---

## Adding a WiFi network

NetworkManager WiFi profiles are managed declaratively via `modules/networkmanager-profiles.nix`: each network's `.nmconnection` file is SOPS-encrypted under `secrets/networkmanager/`, decrypted at boot into `/run/secrets/nm/<secret>`, and copied into `/etc/NetworkManager/system-connections/` as a real file before NetworkManager starts.

To add a network you must already have connected to (or otherwise saved) it once — NetworkManager writes the plaintext profile to `/etc/NetworkManager/system-connections/<name>.nmconnection` regardless of whether you are currently connected.

### 1. Make `sops` available

`sops` is not installed system-wide. Get it (and `age`) in an ephemeral shell:

    nix shell nixpkgs#sops nixpkgs#age
    export SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt

### 2. Copy the plaintext profile into the repo

The profile is root-owned (contains `psk=`), so read it with `sudo`. The `>` redirect runs as your user, so the copy lands owned by you:

    sudo cat "/etc/NetworkManager/system-connections/<SSID>.nmconnection" \
      > secrets/networkmanager/<secret-name>.nmconnection

Pick a clean `<secret-name>` (lowercase kebab-case, e.g. `my-home-wifi`, to match the existing profiles). It is the SOPS filename and is independent of the SSID.

### 3. Encrypt it in place

    sops -e -i --input-type binary --output-type binary \
      secrets/networkmanager/<secret-name>.nmconnection

Verify before committing — the file must start with `{"data":"ENC[` or you would commit the plaintext password:

    head -c 15 secrets/networkmanager/<secret-name>.nmconnection

### 4. Register it in the module

Add a line to the `nmProfiles` list in `modules/networkmanager-profiles.nix`:

    { secret = "<secret-name>"; target = "<Exact NM filename>.nmconnection"; }

`target` must exactly match the on-disk filename NetworkManager uses in `/etc/NetworkManager/system-connections/`, including spaces and capitalization (e.g. `VIRUS PERIGOSO_5G.nmconnection`). The activation script installs the decrypted secret to exactly that name.

### 5. Rebuild

    sudo nixos-rebuild switch --flake .#<hostname>

### Gotchas

- **`sops: command not found`** — SOPS is not installed system-wide; use the `nix shell` in step 1.
- **`error loading config: no matching creation rules found`** — SOPS matches its creation rule against the *input* path. Do **not** pipe plaintext through `/dev/stdin` with a `>` redirect: SOPS sees `/dev/stdin`, which does not match the `^secrets/` rule in `.sops.yaml`. Copy the file under `secrets/` first (step 2), then encrypt in place (step 3), so the path matches.
- The `secret` value may use any casing, but lowercase kebab-case is the convention here.
- Encrypted files are safe to commit and can be world-readable ciphertext; `chmod 600` only for cosmetic consistency with the older profiles.
