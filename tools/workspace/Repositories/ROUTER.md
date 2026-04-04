# ROUTER.md

This file is the broad routing map for AJ's repositories.

## Purpose
Use this file only to determine which top-level area or repository should be inspected next.

Do not treat this file as project memory or as a detailed project description.

## Top-level areas

### automation
Automation scripts and processes that run on AJ's laptop or interact with homelab services.
This area often contains scripts, timers, and utility workflows.

### courses
Projects used for experiments, course-related documentation, or exploratory work that is not necessarily part of the main school project flow.

### experiment
Templates, cloned repositories, and non-serious experimental work.
This area is mostly for trying things out and should not usually be treated as a source of durable project knowledge.

### school
Class-specific projects such as notebooks, assignments, and research papers.
When the task is about coursework, mathematical work, scientific computing, or class writing, inspect this area first.

### self-hosted
Locally run or self-hosted services such as the zettelkasten and llmfit.
This area is for things AJ runs, not things he builds.
Do not inspect unless a project indicates it is relevant.

### projects
Personal tools and applications that AJ builds for his own use.
Each subdirectory is its own git-tracked repo with a CONTEXT.md.
Inspect the relevant subdirectory's CONTEXT.md to orient.

## Directories outside ~/Repositories

These are not repositories and are not routed through this file's area system.
Go here only when a task explicitly requires it.

### ~/nixos-config
NixOS system configuration, dotfiles, and machine-level setup.
Go here if the task involves system packages, services, Hyprland config, NixOS modules,
or anything that requires a rebuild to take effect.

### ~/Documents
Primary storage for PDFs, papers, and reference material linked from zettelkasten notes.
If a task involves finding a source, reading a paper, or locating a resource referenced
in a zettelkasten note, look here first before searching elsewhere.

### ~/Pictures
Images and wallpapers. Wallpapers specifically live at ~/Pictures/Wallpapers/.
Go here if the task involves finding, changing, or referencing visual assets.

### ~/.config/ai
Agent workspace: shared rules, skills, and per-agent bootstrap configs.
Go here only if the task involves modifying agent behavior, skills, or orientation files.
Do not read this directory speculatively.

## General routing rules
- Start with the repository most directly related to the task.
- Do not inspect unrelated repositories by default.
- Use area-level and project-level context files to narrow further.
