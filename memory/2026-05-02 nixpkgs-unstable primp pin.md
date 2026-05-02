# Session Notes — 2026-05-02

## nixpkgs-unstable pinned to working commit (TEMPORARY)

### Problem
`nix flake update nixpkgs-unstable` bumped to rev `c6d65881c5624c9cae5ea6cedef24699b0c0a4c0` (2026-05-01).
This rev has a bug: `pkgs/development/python-modules/primp/default.nix:48` uses the deprecated
`pytestFlagsArray` attribute, which nixpkgs now hard-errors on.
The error surfaces via `open-webui`'s dependency chain → `systemd.services.open-webui.serviceConfig` → build failure.

### Fix applied
Pinned `nixpkgs-unstable.url` in `flake.nix` to the previous known-good commit:

```
github:NixOS/nixpkgs/01fbdeef22b76df85ea168fbfe1bfd9e63681b30
```

(2026-04-23 — the rev used before the `41fb138` update commit)

### What to do when nixpkgs fixes primp
1. Revert `flake.nix` line back to: `github:NixOS/nixpkgs/nixpkgs-unstable`
2. Run `nix flake update nixpkgs-unstable`
3. Verify with `nrt` then `nrs`

Track upstream fix: search nixpkgs commits for `primp: replace pytestFlagsArray` or similar.
