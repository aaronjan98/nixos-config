# project-memory

Durable, cross-session **memory and documentation** for all of AJ's projects —
the one place where design specs, future roadmap ideas, and consolidated notes
live *outside* any single project repo.

Each project repo keeps its own code and its own `CONTEXT.md` / `MEMORY.md`. This
repo is the layer *above* that: the specs that predate or span repos, the
"someday" ideas, and the reference runbooks worth keeping even while the work is
paused. If a document would help months from now to remember *why* something was
built or *what* was planned, it belongs here.

## What's here

### Specs — designs for things being (or about to be) built
- [hypr-session-spec.md](hypr-session-spec.md) — per-domain Hyprland workspace
  save/restore tool (Phase A/B implemented).
- [network-homelab-monitor.md](network-homelab-monitor.md) — the LANtern home
  network monitor project.
- [lantern-idle-automation-spec.md](lantern-idle-automation-spec.md) — LANtern
  idle-gated maintenance automation.
- [lantern-ui-spec.md](lantern-ui-spec.md) — LANtern UI.

### Roadmap & ideas — not started, worth remembering
- [future-projects.md](future-projects.md) — backlog of project ideas.
- [research-graph-workspace.md](research-graph-workspace.md) — research-graph
  workspace concept.

### Runbooks & reference
- [sweetpea-recovery-runbook.md](sweetpea-recovery-runbook.md) — quick recovery
  cheat-sheet for the sweetpea host.

## Conventions
- One document per spec/idea; Markdown; kebab-case filenames.
- Keep a **Status** line at the top of a spec (e.g. "Phase A/B implemented",
  "not started") so it's obvious what's live vs. aspirational.
- Cross-link the related project repo(s) and docs where useful.

Lives at `~/Repositories/projects/project-memory` and syncs across machines via
its private Forgejo remote (`git.aaronjanovitch.com/aj/project-memory`). It sits
at a `.git` boundary, so the nixos-config workspace snapshot stops here and no
longer mirrors these files (which is what this repo was created to fix).
