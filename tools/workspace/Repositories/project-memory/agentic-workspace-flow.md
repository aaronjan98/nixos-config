# Agentic Workspace Flow

## What has been built (as of 2026-04-02)

### Layer 1 — Global Claude config (`~/.config/ai/agents/claude/`)
- `CLAUDE.md` — injected into every Claude session automatically. Instructs Claude to:
  - Read `~/.config/ai/shared/tool-commands.md` on start
  - Read CONTEXT.md / MEMORY.md / DEPENDENCIES.md in the working directory
  - Fall back to ROUTER.md if no CONTEXT.md found
  - Store session notes in `memory/YYYY-MM-DD.md`, durable knowledge in `MEMORY.md`
  - Never write memories to `~/.claude/projects/`
- Symlinked from `~/.claude/CLAUDE.md`

### Layer 2 — Shared agent config (`~/.config/ai/shared/`)
- `agent-orientation.md` — full system architecture (three-layer model, operational rules)
- `tool-commands.md` — canonical CLI commands: PDF reading, DOCX→PDF, git workflow
- `routing-rules.md`, `principles.md`, `memory-model.md`, `model-routing.md`, `external-knowledge.md`

### Layer 3 — Per-agent config (`~/.config/ai/agents/`)
- `claude/` — home for Claude-specific authored config (CLAUDE.md lives here)
- `codex/`, `gemini/`, `opencode/` — empty, reserved for future per-agent config

### Layer 4 — Workspace routing (`~/Repositories/`)
- `ROUTER.md` — area-by-area navigation guide
- `CONTEXT.md` — workspace root context and agent role (this workspace)
- `MEMORY.md` — index pointing to session notes and project memory
- `memory/` — daily session notes
- `project-memory/` — durable workspace-level knowledge (this file)
- Backed up hourly to `~/nixos-config/tools/workspace/` via export-workspace-state systemd timer

### Layer 5 — Project-level files (inside each repo or zettelkasten folder)
- Each active project has CONTEXT.md, MEMORY.md, memory/, and optionally project-memory/
- Notable active setups:
  - `Inside/School/2026 Spring/MATH 351 - Diff Equations/` — full study agent with study plan and tutor prompt workflow
  - `Inside/School/2026 Spring/Math 382 - Scientific Comp & Lab/` — seeded 2026-04-02
  - `Inside/Life/` — life advisor agent with AJ's career/school/personal context
  - `Inside/School/` — academic profile in MEMORY.md

---

## Aspirations — not yet implemented

### 1. Staleness check script
**What:** A bash script (no AI) that reads git commit dates on CONTEXT.md and MEMORY.md files across the zettelkasten and reports which ones haven't been updated in over N days.
**Why:** Many folders (Work/, Life/ subareas, older course folders) go dormant but their agent files don't reflect the current state.
**Output:** A report file, e.g. `~/Repositories/memory/staleness-YYYY-MM-DD.md`, listing stale directories.
**Where it lives:** Probably `~/nixos-config/scripts/check-vault-staleness.sh`, paired with a systemd timer.
**Trigger:** Weekly, or on demand.

### 2. Vault-review skill (`~/.config/ai/skills/vault-review/`)
**What:** A structured skill for intentional vault maintenance sessions. When invoked:
1. Lists directories flagged as stale (or all major areas)
2. For each: reads current notes, proposes updates to CONTEXT.md and index annotations
3. Human approves or rejects each proposed change
4. Updates MEMORY.md with what was reviewed and when
**Why:** Automated AI sweeps without human context produce poor updates. This keeps humans in control while reducing friction.
**Cadence:** Monthly or once per semester, or when life shifts significantly (e.g., new semester, job change).

### 3. Annotated index files
**What:** Enrich index files (MOC notes) across the zettelkasten to include:
- A one-line annotation under each link describing the note's current role
- A "Historical / Earlier thinking" section at the bottom for notes that are no longer current but worth preserving
**Why:** Plain link lists force the reader (human or agent) to open every note to understand its role. Annotations make the index a useful at-a-glance map.
**How to implement:** Work through each folder's index file collaboratively — agent proposes annotations, human finalizes. Do not automate fully; only the human can decide what's historical.
**Starting point:** Begin with the most-used indexes (School, Projects/Agentic Workspaces, Career).

### 4. Extend export-workspace-state.sh
**What:** Update `~/nixos-config/scripts/export-workspace-state.sh` to also copy:
- Root-level `CONTEXT.md` and `MEMORY.md` from `~/Repositories/`
- `MEMORY.md` files from non-repo subdirectories (alongside existing CONTEXT.md copies)
- Contents of `memory/` and `project-memory/` directories from non-repo areas
**Why:** Currently only CONTEXT.md (for subdirs) and ROUTER.md (for root) are backed up. Session notes and durable memory are lost if not in git.
**Risk:** Low — additive change only, no existing behavior removed.

### 5. Spec directory (optional)
**What:** A `~/Repositories/spec/` directory for detailed implementation specs of aspirational items.
**Why:** Project-memory is for durable facts; spec files are for design decisions and implementation details before work begins.
**Status:** Holding aspirations in this file for now; promote to spec/ when ready to implement.
