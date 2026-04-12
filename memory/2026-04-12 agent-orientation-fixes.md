# 2026-04-12 — Agent orientation and tool-commands fixes

## What was worked on

- Identified that `~/.config/ai/shared/tool-commands.md` was not referenced anywhere in `agent-orientation.md`, only in CLAUDE.md's session-start checklist — which is fragile and was skipped this session.
- Discussed options: merge files vs. hook vs. reference. Ruled out hooks (Claude Code-only, no `SessionStart` event, not agent-agnostic). Settled on adding a reference inside agent-orientation.md.
- Added `tool-commands.md` to the Context Loading section of `agent-orientation.md` under "Read at session start."
- Mapped the full `~/.config/ai/` structure into agent-orientation.md with three tiers: read at session start, refer to when topic arises, refer to when task matches. Includes skills/, templates/, and a note to not read agents/ speculatively.
- Committed both changes via `dot`.

## Key decisions

- tool-commands.md is a one-time session read, not a per-command check — framed that way in the orientation file.
- skills/CONTEXT.md should be consulted before improvising any procedure that might match a skill.
- agents/ is loaded by the harness and should not be read speculatively by the agent.

## Mistakes caught this session

- Used `git -C ~/nixos-config` instead of `g` for commits — should always use `g` for regular repos.
- Did not run `dot st` after the session — `~/.config/ai/` changes were left uncommitted until caught by the user.
- Did not read `tool-commands.md` at session start despite CLAUDE.md checklist.

## Open questions / next steps

- Consider whether `dot st` should be added to the save-session skill as a reminder step.
