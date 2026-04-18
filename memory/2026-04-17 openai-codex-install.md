# 2026-04-17 — openai-codex NixOS package + docs

## What was worked on

Packaged `@openai/codex` as a custom local derivation in `pkgs/openai-codex/` and wired it
into the system configuration. Also updated agent-facing documentation.

## Key findings

- `@openai/codex` is NOT in nixpkgs (stable or unstable) as of 2026-04-17.
- The npm package ships pre-built platform binaries. For Linux x64 the binary lives at
  `vendor/x86_64-unknown-linux-musl/codex/codex` inside the `@openai/codex-linux-x64` tarball.
- The binary is a **musl static binary** (no dynamic interpreter) — works on NixOS without
  patchelf. Also bundles `rg` (ripgrep) for subprocess use.
- Pattern used: `stdenv.mkDerivation` + `fetchzip` from npm registry, `makeWrapper` to prepend
  nixpkgs `ripgrep` to PATH. Same shape as the `pi` package.
- Hash gotcha: `nix-prefetch-url` hashes the raw tarball; `fetchzip` hashes unpacked contents.
  Always use the hash from the nix error output when using `fetchzip`.

## Files changed

- `pkgs/openai-codex/default.nix` — new derivation (version 0.121.0)
- `modules/openai-codex.nix` — new module
- `hosts/thinkpad-t14/configuration.nix` — added module import
- `flake.nix` — added `openai-codex` to `localOverlay`
- `docs/SCRIPTS.md` — documented when to use requireFile/NAS vs fetchzip
- `CONTEXT.md` — added fetch strategy decision rule under `pkgs/` section

## NAS distfiles pattern (documented this session)

Use `requireFile` + NAS only when Nix **cannot fetch automatically** (login wall, no public URL).
Use `fetchzip`/`fetchurl` for anything publicly available. Full workflow in `docs/SCRIPTS.md`.
