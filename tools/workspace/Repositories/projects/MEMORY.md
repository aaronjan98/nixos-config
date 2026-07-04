# MEMORY.md

## Purpose
Durable area-level memory for the `projects/` workspace.

Use this file to point future agents at:
- the currently active repository
- the most relevant future project ideas
- any area-level conventions about when to create a new repo

## Current active repo
- `context-harness/` — active Context Forge build in progress

## Agent collaboration preferences
- For Context Forge debugging, do not keep making commits for speculative
  fixes. Use WIP commits only when they help safe rollback. Otherwise commit
  after the user confirms the issue is actually fixed.

## Future project ideas
- `project-memory/research-graph-workspace.md` — graph-native mathematical
  research workspace centered on idea/dependency graphs with overlay views for
  conversation and linked documents
- `project-memory/future-projects.md` — index of incubating project ideas in
  this area

## Repo creation rule
Do not create a new project directory just because an idea exists.
Create a new repo only when:
- the product direction is clear enough to describe in a dedicated `CONTEXT.md`
- there is enough scope to justify its own memory/spec files
- active implementation is about to begin
