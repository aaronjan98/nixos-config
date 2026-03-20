# Agent Workflow

This document describes how AI agents (Claude, Gemini, Codex, etc.) are expected to operate within this system.

This is not specific to a single tool. It defines the workflow and expectations for any agent interacting with the filesystem.

---

## Core idea

Agents operate on top of a structured filesystem with explicit routing and memory boundaries.

The system is designed so that:
- context is loaded intentionally, not globally
- project-level files define behavior
- shared configuration is reusable across agents

---

## Key layers

### 1. Shared agent configuration

Path:

    ~/.config/ai/

Contains:
- shared principles
- templates
- skills
- routing rules
- memory model

This is agent-agnostic.

---

### 2. Workspace routing

Path:

    ~/Repositories/

Contains:
- `ROUTER.md`
- area-level `CONTEXT.md`

Purpose:
- guide agents to the correct part of the workspace
- prevent unnecessary context loading

---

### 3. Project-level control

Inside each project:

- `CONTEXT.md`
- `MEMORY.md`
- `DEPENDENCIES.md`

These define:
- what the project is
- how the agent should behave
- what external sources are allowed

---

## Standard session workflow

For any agent:

1. Start inside a project directory

2. Read:

    CONTEXT.md
    MEMORY.md
    DEPENDENCIES.md

3. Identify:
- the task
- the relevant files
- allowed dependencies

4. Work locally first

5. Expand outward only if needed:
- other repos
- zettelkasten
- external sources

6. Record outcomes:
- update memory if needed
- capture decisions explicitly

---

## What agents should NOT do

- load all repositories by default
- search the entire system without routing
- assume context outside the current project
- treat chat history as durable memory

---

## Local vs remote models

Agents may run against:

### Remote models
- Claude (Anthropic)
- other hosted APIs

### Local models
- Ollama or similar

Example override:

    ANTHROPIC_BASE_URL=http://localhost:11434 claude

This allows:
- using the same workflow
- swapping model backends

---

## Philosophy

This system is:

- file-first
- explicit over implicit
- modular
- agent-agnostic

Agents are tools that operate within this structure.

They are not the source of truth.

---

## Summary

Agents should:
- start narrow
- follow routing
- respect project boundaries
- expand context only when necessary
- write down important decisions

The filesystem defines behavior, not the agent itself.
