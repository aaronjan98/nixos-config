# Package Management

This document explains how packages are installed in this NixOS configuration and how to decide where a new package should be added.

This setup intentionally uses multiple layers:

- direct references to packages from the main `pkgs` set
- overlays (for package sources)
- custom derivations in `pkgs/`
- modules (for grouped features)
- system packages (global tools)
- user packages (user-specific apps)
- script-wrapped tools

Each layer has a different purpose.

---

## Overview

There are several intentional package paths in this repo:

1. overlays in `flake.nix`
2. custom derivations in `pkgs/`
3. `environment.systemPackages`
4. `users.users.<name>.packages`
5. dedicated modules in `modules/`

An additional category exists for utility commands:

6. `writeShellScriptBin`

---

## 1. Overlays (`flake.nix`)

Location:
- `flake.nix`

Purpose:
- define where packages come from
- expose unstable or custom packages into the main package set

Example:

    code-cursor = pkgsUnstable.code-cursor;
    claude-code = pkgsUnstable.claude-code;

This means:
- the package is sourced from unstable nixpkgs
- it is made available as `pkgs.claude-code`

The overlay is also where locally defined packages from `./pkgs` are exposed to the rest of the system as normal `pkgs.<name>` entries.

Current examples include:

    pi = final.callPackage ./pkgs/pi/default.nix { };
    openai-codex = final.callPackage ./pkgs/openai-codex/default.nix { };

### When to use overlays

Use overlays when:
- the package is not in stable nixpkgs
- you want a newer version from unstable
- you are defining a custom package from `./pkgs`
- you want to unify package access across the system

---

## Custom packages in `pkgs/`

Location:
- `pkgs/`

Purpose:
- pin packages that are not taken directly from nixpkgs
- package upstream binaries or npm releases with repo-controlled hashes
- add small wrapper behavior when needed

Current examples:

### `pkgs/pi/`
- packages Pi from the npm release tarball using `buildNpmPackage`
- keeps a checked-in `package-lock.json` for reproducible dependency resolution
- adds `fd` to Pi's runtime `PATH`

### `pkgs/openai-codex/`
- packages the official prebuilt Codex binary tarball from npm
- wraps it so `ripgrep` is available on `PATH`

### When to use a local derivation

Use `pkgs/<name>/default.nix` when:
- the package is missing from nixpkgs
- nixpkgs is not the update cadence you want
- you need to pin an upstream npm/binary release directly
- you need lightweight wrapping behavior around the upstream artifact

### Updating pinned packages

Pinned local packages should be updated through tracked repo workflows rather than ad-hoc global installers.

Current examples:

    ./scripts/update-all-pinned-packages.sh
    ./scripts/update-pi.sh
    ./scripts/update-openai-codex.sh

These refresh the pinned local package version and hashes without switching away from the repo-managed derivation workflow.
Use `update-all-pinned-packages.sh` when you want to refresh the full current set at once.
Their verification builds are host-aware, so they follow the current machine's flake target instead of assuming a specific laptop.

The exact update work differs by package type:

- `pi` is built with `buildNpmPackage`, so updates refresh the version, source hash, checked-in `package-lock.json`, and `npmDepsHash`
- `openai-codex` packages a prebuilt upstream tarball, so updates only need a new version and source hash

---

## 2. `environment.systemPackages`

Location:
- `hosts/.../configuration.nix`

Purpose:
- install system-wide tools available to all users

Example categories:
- CLI tools
- development tools
- system utilities
- stable nixpkgs packages used directly from `pkgs`
- overlay-exposed packages such as unstable tools or local derivations

Example:

    environment.systemPackages = with pkgs; [
      git
      neovim
      claude-code
    ];

### When to use systemPackages

Use this for:
- tools you expect to use everywhere
- CLI utilities
- development tools
- system-wide capabilities
- globally available AI/agent CLIs once their package source has already been decided elsewhere

---

## 3. `users.users.<name>.packages`

Location:
- `hosts/.../configuration.nix`

Purpose:
- install packages only for a specific user

Example:

    users.users.aj = {
      packages = with pkgs; [
        vesktop
        slack
      ];
    };

### When to use user packages

Use this for:
- user-specific applications
- apps not needed system-wide
- GUI apps tied to a specific user

---

## 4. Modules (`modules/*.nix`)

Location:
- `modules/`

Purpose:
- group related functionality
- combine packages + configuration + documentation

Examples:
- `kanata.nix`
- `ollama.nix`
- `tmux.nix`
- `claude-code.nix`
- `hypr-dispatch.nix` — wraps `hyprctl dispatch` with auto-detection of the Hyprland instance signature
- `wol-sauron.nix` — sends a Wake-on-LAN magic packet to sauron (192.168.1.255, MAC 3C:52:82:74:03:F5)
- `podman.nix` — rootless container runtime with podman-compose and Docker-compatible socket for devcontainer CLI

Example:

    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        claude-code
      ];
    }

### When to use modules

Use a module when:
- the package represents a feature, not just a tool
- it may grow additional config later
- it deserves documentation and separation
- you want to keep `configuration.nix` clean

Claude Code is implemented this way.

Other agentic CLIs follow the same pattern:
- `modules/claude-code.nix`
- `modules/openai-codex.nix`
- `modules/opencode.nix`
- `modules/pi.nix`

---

## 5. Script-wrapped tools (`writeShellScriptBin`)

Location:
- inside `environment.systemPackages`

Purpose:
- expose scripts as commands in the system profile

Example:

    (pkgs.writeShellScriptBin "seed-local-git-server"
      (builtins.readFile ../../scripts/seed-local-git-server.sh)
    )

### When to use this

Use this for:
- operational scripts you want available globally
- custom commands tied to your workflow

---

## How Claude Code fits into this system

Claude Code uses:

1. overlay (flake.nix)
   - source: `pkgsUnstable.claude-code`

2. module (`modules/claude-code.nix`)
   - installs it via `environment.systemPackages`

3. host config
   - imports the module

This gives:

- declarative install
- modular structure
- clear documentation boundary
- easy future extension

## How the other coding agents fit into this system

### OpenCode
- source: `pkgsUnstable.opencode`
- installation boundary: `modules/opencode.nix`

### Gemini CLI
- source: `pkgsUnstable.gemini-cli`
- installed directly in `environment.systemPackages`

### OpenAI Codex
- source: local derivation in `pkgs/openai-codex/`
- exposed through the overlay as `pkgs.openai-codex`
- installation boundary: `modules/openai-codex.nix`
- update workflow: `scripts/update-openai-codex.sh`

### Pi
- source: local derivation in `pkgs/pi/`
- exposed through the overlay as `pkgs.pi`
- installation boundary: `modules/pi.nix`
- update workflow: `scripts/update-pi.sh`

### Combined pinned-package updater
- source: orchestration script in `scripts/update-all-pinned-packages.sh`
- covers the current local pinned package set (`pi`, `openai-codex`)
- runs the individual updaters with one final verification build by default

---

## Decision guide

When adding a new package, ask:

### Is it from unstable or custom?
→ add to overlay

### Does it need its own pinned derivation or wrapper?
→ package it under `pkgs/` and expose it through the overlay

### Is it a system-wide CLI tool?
→ add to `environment.systemPackages`

### Is it user-specific?
→ add to `users.users.<name>.packages`

### Is it a feature with future complexity?
→ create a module

### Is it just a script?
→ use `writeShellScriptBin`

---

## What to avoid

- dumping everything into `environment.systemPackages`
- mixing user apps with system tools
- bypassing overlays when using unstable packages
- adding complex tools without a module boundary
- duplicating the same package across multiple layers

---

## Summary

Package management in this repo is layered intentionally:

- overlays define where packages come from
- local derivations in `pkgs/` pin packages that live outside nixpkgs
- modules define features
- systemPackages provide global tools
- user packages provide per-user apps
- script bins expose operational commands

This structure keeps the system:

- maintainable
- reproducible
- understandable to both humans and AI agents
