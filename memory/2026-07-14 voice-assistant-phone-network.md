# 2026-07-14 — Voice assistant: phone integration, network fixes, task registry

## What was worked on

Continued building the voice assistant pipeline (M5Stack Atom Echo S3R + HA + Gemini Flash + Claude CLI). Session focused on:
- Building SQLite task registry for voice-dispatched homelab queries
- Fixing HA pipeline silence (25s auto-fence for homelab_query)
- Writing public README for voice-assistant repo
- Debugging Atom Echo S3R firmware crash loop (reflash fixed it)
- Connecting HA Companion on Z Flip via Tailscale (100.82.211.39:8123)
- Fixing NetworkManager/Tailscale coexistence on Framework
- Diagnosing orchestrator 502s from googleSearch + functionDeclarations incompatibility
- Clarifying system prompt so general questions bypass homelab_query

## Key decisions

- **Task registry**: SQLite at `~/.local/share/voice-assistant/tasks.db`; every `homelab_query` call creates a row (pending→running→done/failed). `list_tasks` tool exposes history to Gemini so user can ask "what's running?"
- **25s fence**: If Claude doesn't respond within 25s, orchestrator immediately returns a spoken hold message and pushes result via Pushbullet when done. Uses `asyncio.shield` so the subprocess keeps running.
- **Google Search grounding**: `{"googleSearch": {}}` cannot be combined with `functionDeclarations` on gemini-2.5-flash — causes 502. Reverted. Gemini's training knowledge covers most general questions; web search can be added later via a `web_search` functionDeclaration with Tavily if needed.
- **NetworkManager unmanaged**: Added `networking.networkmanager.unmanaged = ["interface-name:tailscale0"]` to `hosts/common/default.nix` to prevent NM from probing the Tailscale interface
- **Resolved fallback DNS**: Added `fallbackDns = ["1.1.1.1" "8.8.8.8"]` so DNS doesn't die if Tailscale flickers
- **Network "brickups"**: Root cause turned out to be NM restarting during `nrs` runs (not suspend). WiFi takes 10-30s to reassociate after each rebuild — expected behaviour, not a bug.

## Key insights

- Atom Echo S3R firmware corruption: caused by power cut mid-NVS write when powered from computer USB. Fix: power from wall adapter. Recovery: `esphome run atom-echo-s3r.yaml --device /dev/ttyACM0`
- HA Companion uses the pipeline configured in HA web UI (Settings → Voice Assistants) — must set conversation agent to "Orchestrator Conversation" or it uses the default HA assistant
- mDNS (`framework-13.local`) unreliable on Android; use Tailscale IP `100.82.211.39` or LAN IP `10.0.50.189` as fallback in Companion
- `sg dialout` needed in new shell sessions before serial tools work, even if user is already in dialout group

## Commits made

### voice-assistant repo
- `aa20df8` Add SQLite task registry
- `1b5481d` Auto-fence homelab_query at 25s
- `50892cc` Add public README
- `f04a910` Add troubleshooting section to README
- `a3f35e6` Prompt Claude to always include names in responses
- `4e0fc86` Enable Gemini Google Search grounding (REVERTED)
- `801fd51` Revert googleSearch grounding
- `0593af3` Add orchestrator/__pycache__/ to .gitignore

### nixos-config repo
- `19c421c` Clarify system prompt + NM/resolved fixes

## Open questions / next steps

- [ ] Jellyfin playback control tool (`jellyfin_play`) — push "play this on this client" via Jellyfin API; discussed but not built
- [ ] Desktop app control bridge — small per-machine systemd user service to accept SSH commands and run them inside the GUI session (for ThinkPad app launching)
- [ ] Phase 2: Samsung Z Flip deeper integration (already connected via HA Companion)
- [ ] Phase 3: Google Home Nest Minis — limited to HA entity control only, AI layer not replaceable
- [ ] Persistent JSONL conversation history (currently in-memory, expires on restart)
- [ ] `~/.claude/CLAUDE.md` symlink still not created — `ln -s ~/.config/ai/agents/claude/CLAUDE.md ~/.claude/CLAUDE.md` needed for claude CLI to auto-load homelab context
