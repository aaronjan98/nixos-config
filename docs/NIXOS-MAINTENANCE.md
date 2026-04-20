# NixOS Maintenance Quick Reference

This document collects a few high-value NixOS maintenance commands that are easy to forget but useful during normal upkeep.

---

## Inspect system generations

List the current NixOS system generations:

```bash
nixos-rebuild list-generations
```

Use this when you want to:
- see which system generation is current
- inspect build dates and kernel versions
- confirm whether old system generations are still present

### About the `Specialisation` column

- `[]` means the normal base system configuration
- non-empty entries would indicate a named NixOS specialisation

If you are not using `specialisation = { ... };` in your config, this column will normally stay `[]`.

---

## Delete old system generations

Delete all old NixOS **system profile** generations and keep the current one:

```bash
sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations old
```

Use this when old generations are still hanging around after a rebuild and you want to prune them explicitly.

Important:
- this is for the **system** profile, not your user profile
- `--delete-generations` is a `nix-env` operation here, not a `nix-store` one

---

## Garbage-collect old store paths

After deleting old generations, reclaim disk space from unreferenced store paths:

```bash
sudo nix-collect-garbage -d
```

This is about store cleanup and free space, not just boot menu cleanup.

---

## Boot menu limit vs garbage collection

These solve different problems:

- `boot.loader.systemd-boot.configurationLimit = 10;` keeps the boot menu limited to the latest system configurations on future rebuilds
- `sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations old` removes old system generations now
- `sudo nix-collect-garbage -d` removes old unreferenced store paths

In short:
- boot menu cleanup and store cleanup are related, but not the same thing
- a generation can disappear from the boot menu without immediately reclaiming all possible disk space
