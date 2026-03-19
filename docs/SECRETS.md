# Secrets and Trust Material

This document explains the secrets-related pieces needed for a new machine setup.

## Main categories

### GPG keys
Needed to decrypt and use `pass`.

Without working GPG secret keys, the password store cannot be used to restore other material.

### Password store
The password store contains important machine bootstrap material, including:
- SSH files
- SOPS age key material

Known password-store remotes may include:
- `ssh://git@localhost/srv/git/repos/password-store.git`
- `ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/password-store.git`

### SSH material
SSH files are restored from `pass` using the prefix:

- `laptop/<hostname>/ssh`

These are written into:
- `~/.ssh/`

### SOPS age key
The SOPS age key is stored in `pass` at:

- `laptop/thinkpad-t14-nixos/sops/age`

It is restored to:

- `/var/lib/sops-nix/key.txt`

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

---

## Important note

This setup intentionally assumes that the first trust bootstrap is manual.

For now, do not rely on the new machine being able to fetch its own GPG secret keys automatically from the homelab.

Use an existing trusted machine to transfer/import those keys first.
