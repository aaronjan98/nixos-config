# 2026-05-19 — Multi-host refactor plan

**Time:** 18:27 PDT

---

## What was worked on

Planning and spec work for the multi-host NixOS configuration refactor — adding a Framework 13 AMD as a second host alongside the existing ThinkPad T14, extracting a shared common base, and establishing a pentest module pattern.

---

## Key insights

- The multi-host refactor was already in ROADMAP.md ("Framework 13 AMD support") and session memory (2026-04-21) but had not been started
- Currently everything lives in the monolithic `hosts/thinkpad-t14/configuration.nix` — no shared base exists
- The sync scripts (`sync-workspace-repos.sh`, `bootstrap-workspace.sh`, etc.) handle the *workspace* layer, not the NixOS config multi-host split — that refactor was the missing piece
- `nixos-hardware` flake (`github:NixOS/nixos-hardware`) has `framework-13-7040-amd` module — should be added as a flake input for Framework-specific hardware tuning
- Pentest tooling: user confirmed they want `modules/pentest.nix` (always-on import per host), NOT a NixOS `specialisation`. Specialisation adds a separate boot entry and second closure — wrong fit when the Framework is a dedicated pentest machine

---

## Decisions

- **Hosts should be maximally identical** — common base carries ~95% of config; host files are thin overrides
- **Pentest as a shared importable module** (`modules/pentest.nix`), not a specialisation
- **Kanata files are per-host** even if initially identical — prevents cross-host coupling, allows safe divergence
- **Workflow**: refactor on ThinkPad in a branch, validate with `nrt`/`nrs`, then merge and flash Framework from clean state
- **`project-memory/`** directory created for durable cross-session specs; spec lives at `project-memory/multi-host-refactor-spec.md`
- **CONTEXT.md** updated to point agents to `project-memory/` and the active spec

---

## Progress as of session end

- [x] Branch `multi-host` created by user
- [x] Spec written to `project-memory/multi-host-refactor-spec.md`
- [x] `project-memory/` directory established as pattern for this repo
- [x] CONTEXT.md updated with active project specs section
- [ ] Extract `hosts/common/default.nix` — next step

---

## Open questions

- Framework hostname — decide before flashing (e.g. `framework-13`, something personal)
- Verify exact `nixos-hardware` module name for Framework 13 AMD 7040 series before wiring into flake.nix
- SOPS secrets path resolution: `../../secrets/...` is relative to the host directory — confirm it still resolves correctly when `sops` block moves to `hosts/common/default.nix` (it should, since the path is relative to the flake root via `./secrets/...` convention, but double-check)
- Whether Framework gets any ThinkPad-only SOPS secrets (mic LED udev, etc.) or if secrets stay fully shared

## Next steps

Pick up at step 2 of the checklist in `project-memory/multi-host-refactor-spec.md`: extract `hosts/common/default.nix` from the ThinkPad config.
