# Manual Bootstrap

This document covers the intentionally manual steps required before the scripted new-machine bootstrap can take over.

These steps are needed because a new machine does not initially have the trust material required to:
- decrypt the password store
- restore SSH files
- restore the SOPS age key

Once these manual prerequisites are complete, the scripted bootstrap flow can proceed.

---

## Overview

The manual bootstrap phase is:

1. install base NixOS
2. log into the new machine
3. clone `nixos-config`
4. restore GPG secret keys used for `pass`
5. verify `pass` works
6. restore SSH files and SOPS age key
7. hand off to the scripted bootstrap

---

## Clone `nixos-config`

Clone the config repo into the expected location:

    git clone https://github.com/aaronjan98/nixos-config ~/nixos-config
    cd ~/nixos-config

---

## Restore GPG keys for `pass`

The new machine must have the secret GPG keys needed to decrypt the password store.

For now, the recommended method is to transfer them from an existing trusted machine.

### Transfer key files using password auth

    scp -o IdentitiesOnly=yes -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      pass-gpg-private.asc pass-gpg-public.asc \
      aj@192.168.1.XXX:/home/aj/

### Or transfer using an existing SSH key already trusted by the new machine

    scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519.fedora \
      pass-gpg-private.asc pass-gpg-public.asc \
      aj@192.168.1.XXX:/home/aj/

### Import the GPG keys on the new machine

    gpg --import ~/pass-gpg-public.asc
    gpg --import ~/pass-gpg-private.asc
    rm -f ~/pass-gpg-public.asc ~/pass-gpg-private.asc
    gpg --list-secret-keys --keyid-format=long

Verify that your expected secret key is listed.

---

## Ensure `pass` is available and usable

If `pass` is not installed yet, install it using your preferred method for the temporary environment or after the first rebuild if already available.

Then verify `pass` works:

    pass ls

If your password store itself is a git repo and is not already present locally, restore or clone it first.

Known remotes may include:

- `ssh://git@localhost/srv/git/repos/password-store.git`
- `ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/password-store.git`

If needed, clone it to the default password-store location:

    git clone ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/password-store.git ~/.password-store

Then test again:

    pass ls

---

## Restore SSH files and SOPS age key

Once GPG and `pass` are working, run:

    ~/nixos-config/scripts/restore-secrets.sh

This should:
- restore SSH files from `pass` under `laptop/<hostname>/ssh`
- restore the SOPS age key from `pass` entry `laptop/thinkpad-t14-nixos/sops/age`
- write the age key to `/var/lib/sops-nix/key.txt`

After that, verify:

    ls -la ~/.ssh
    sudo ls -l /var/lib/sops-nix/key.txt

---

## Install tracked user systemd units

Run:

    ~/nixos-config/scripts/install-user-systemd-units.sh

This installs tracked user units into:

- `~/.config/systemd/user/`

and enables:

- `export-workspace-state.timer`

It leaves `video-summary` disabled by default.

---

## Run the guided machine bootstrap

Now hand off to the orchestrator:

    ~/nixos-config/scripts/bootstrap-new-machine.sh

This script will:
- optionally offer to run `restore-secrets.sh` again
- install user systemd units
- seed the local git server
- sync distfiles
- bootstrap the workspace
- sync workspace repos
- print the final rebuild command

---

## Final rebuild

After bootstrap is complete, run:

    sudo nixos-rebuild switch --flake ~/nixos-config#thinkpad-t14

Or use an alias if already set up:

    nrs

---

## Summary

Manual bootstrap exists to solve the trust problem honestly.

The new machine must first gain access to:
- GPG secret keys
- `pass`
- SSH files
- SOPS age key

Only after that should the scripted bootstrap take over.
