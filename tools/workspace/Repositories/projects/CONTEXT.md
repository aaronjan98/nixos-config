# CONTEXT.md

## Area
projects

## What belongs here
Personal tools and applications built by AJ for his own use.
Each subdirectory is its own git-tracked repository with its own CONTEXT.md.

Early project ideas that are not yet real repositories should be captured in
the area-level `MEMORY.md` and `project-memory/` docs until they are concrete
enough to promote into their own repo directories.

## Typical tasks
- Build or extend a personal tool
- Add features, fix bugs, or refactor project code
- Review specs or session memory before continuing work
- Capture and refine future project ideas before creating new repositories

## Repositories

| Repo | Status | Description |
|------|--------|-------------|
| `agent-display/` | active | Local conversation workspace for AI agents and chats — file-first thread storage, browser UI, Markdown import/export, future math-native and graph workflows |
| `canvas-accessibility-skill/` | active | Portable, agent-agnostic skill that produces WCAG 2.1-conformant accessible PDFs from course slides (LaTeX source or PDF-only). Shipped as a zipped directory to professors who unzip it and point their AI agent at it. Initial recipient: Prof. Jing Li, CSUN MATH 351 |
| `ipod-dap-sync/` | active | Sync a Navidrome/Subsonic playlist onto a Rockbox iPod over USB (no WiFi). Pure-stdlib Python + Subsonic API; portable to Dennis's MacBook Air. Part of the homelab music-server + DAPs project. Also ships `BUILD.md` — the all-Linux iPod (iFlash + Rockbox) flash procedure. |
| `language-tutor/` | active | CLI tooling for self-studying languages from video. Flake devshell (piper-tts, yt-dlp, jq, ffmpeg); `bin/` = get-voice, captions, new-video, say. Pulls captions/comments, generates slowed Brazilian-Portuguese practice MP3s into a Syncthing folder (→ phone), stubs breakdown notes into the zettelkasten. Per-language config in `languages/`. Laptop-local. Content/zettels live in the vault, not here. |

## Future project pipeline
- Keep unstarted ideas in `project-memory/`
- Promote an idea into its own repo only once the product direction is clear
- When promoted, update this file to move the idea from planning into the repo
  table
