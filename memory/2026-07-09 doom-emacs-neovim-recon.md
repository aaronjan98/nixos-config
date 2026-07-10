# 2026-07-09 — Doom Emacs recon + neovim status check

## What was discussed

User asked to:
1. Review the cross-editor snippet plans from the CF editor work
2. Check the neovim plugin-pinning documentation in nixos-config
3. Weigh neovim (pinned config) vs Doom Emacs, with a full reconnaissance

## Findings

### Neovim — nothing needs to change

- `lazy-lock.json` already pins all plugins to exact commit SHAs
- `checker = { enabled = false }` in `lazy_setup.lua` disables auto-update
- The config is already protected from breaking changes
- `lua/snippets/markdown.lua` looks like the completed redo from the 2026-04-28 session (proper `in_math()`, correct return format, `ma/mar/ga` helpers) — worth testing before assuming it's still broken

### Cross-editor snippet architecture

Settled and documented in `context-harness/project-memory/snippet-strategy.md`:
- Canonical source: `~/Repositories/self-hosted/zettelkasten/Documents/shortcuts.json`
- Neovim adapter: LuaSnip (`markdown.lua`) — may already be working
- Obsidian: latex-suite reads shortcuts.json natively — working
- VSCodium: not yet done
- CF editor: CodeMirror 6 Phase 2

### Doom Emacs recommendation

Add Doom specifically for the task management / org-agenda gap. Do NOT replace Obsidian (zettelkasten + LaTeX preview) or Neovim (coding). Minimum viable init.el enables only `evil +everywhere` + `org`.

NixOS integration: emacs-overlay (binary cache, avoid source rebuild) → `emacs-pgtk` as system package → Doom manages its own packages under `~/.emacs.d` outside Nix store.

## Zettels updated

- `Zettels/Programming/Doom Emacs.md` — expanded from stub to full zettel (architecture, evil, org, latex, strengths/weaknesses)
- `Zettels/Programming/Org Mode.md` — expanded from stub (core syntax, agenda, capture, export, babel, org-roam)
- `Inside/editor workflow — neovim vs doom emacs.md` — created; personal decision note with current state, NixOS integration approach, tool split
