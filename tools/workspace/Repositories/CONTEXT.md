# CONTEXT.md — Repositories Workspace Root

## Purpose
This is AJ's workspace root. It contains all active repositories and the agent-facing routing layer that governs how AI agents navigate and operate across the workspace.

## Navigation
- See `ROUTER.md` for area-by-area routing guidance.
- See `~/nixos-config/docs/AGENT-WORKFLOW.md` for the full agent workflow spec.
- See `~/.config/ai/shared/` for machine-wide agent rules.

## Areas
| Directory     | Purpose |
|---------------|---------|
| `automation/` | Scripts and workflows running on AJ's laptop or interacting with homelab services |
| `courses/`    | Exploratory or course-related experimental work |
| `experiment/` | Templates, cloned repos, non-serious experiments |
| `school/`     | Class-specific projects, notebooks, assignments, research papers |
| `self-hosted/`| Locally run systems — zettelkasten, llmfit, etc. |

## Active agent role — workspace architect
When spawned from this directory, the agent has the broadest view of the workspace.
Suitable for:
- Configuring `~/.config/ai/` shared rules, skills, agent files
- Changes to the workspace routing layer (ROUTER.md, area CONTEXT.md files)
- Cross-cutting decisions about how agents should behave across the system

For project-specific work, navigate into the relevant area first.

## Memory
- Short-term session notes: `memory/YYYY-MM-DD.md`
- Durable project memory: `project-memory/`
- This file and MEMORY.md are backed up hourly to `~/nixos-config/tools/workspace/` via the export-workspace-state systemd timer.
