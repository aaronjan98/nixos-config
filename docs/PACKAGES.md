# Package Management

This document explains how packages are installed in this NixOS configuration and how to decide where a new package should be added.

This setup intentionally uses multiple layers:

- overlays (for package sources)
- modules (for grouped features)
- system packages (global tools)
- user packages (user-specific apps)
- script-wrapped tools

Each layer has a different purpose.

---

## Overview

There are four main ways packages enter the system:

1. overlays in `flake.nix`
2. `environment.systemPackages`
3. `users.users.<name>.packages`
4. dedicated modules in `modules/`

A fifth category exists for utility commands:

5. `writeShellScriptBin`

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

### When to use overlays

Use overlays when:
- the package is not in stable nixpkgs
- you want a newer version from unstable
- you are defining a custom package from `./pkgs`
- you want to unify package access across the system

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

---

## Decision guide

When adding a new package, ask:

### Is it from unstable or custom?
→ add to overlay

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
- modules define features
- systemPackages provide global tools
- user packages provide per-user apps
- script bins expose operational commands

This structure keeps the system:

- maintainable
- reproducible
- understandable to both humans and AI agents
