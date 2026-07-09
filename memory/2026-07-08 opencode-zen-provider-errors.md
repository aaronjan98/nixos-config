# Session Notes — 2026-07-08 16:41 PDT

## What was worked on

- Investigated how OpenCode is installed and updated on this NixOS system.
- Confirmed OpenCode is not locally pinned by a repo script; it comes from `pkgsUnstable.opencode` via `flake.nix` and `modules/opencode.nix`.
- Updated `~/.config/opencode/opencode.json` so the top-level default model is `opencode/big-pickle`, while keeping the old `provider.ollama` / `glm-4.7-flash` block as dormant reminiscence config.
- User ran `nix flake update nixpkgs-unstable` and `nrs`; rebuild initially failed through `open-webui -> faster-whisper -> ctranslate2`.
- Added a narrow `ctranslate2` overlay in `flake.nix` to correct the upstream `CTranslate2` 4.8.1 fixed-output hash from `sha256-+82u+w08wGX0oh1wBaH/epI2IH7lxbvMThJEoGt0Kvk=` to `sha256-cchwv+esysn/0v6RqD5zp306HfzOjjlCxH5usLETXs0=`.
- User confirmed the rebuild worked after the overlay.

## OpenCode provider behavior

- New OpenCode conversation showed `Big Pickle` selected as expected, but sending a message returned:
  - `No provider available`
- Switching to another free model produced the same `No provider available` behavior.
- `GPT-5.4 OpenCode Zen` worked, but showed intermittent upstream/provider errors:
  - `Service Unavailable: upstream connect error or disconnect/reset before headers`
  - `Bad Gateway`
- Despite those errors, the paid model continued reasoning through the prompt.
- Relevant OpenCode session id: `ses_0c0f2c70affeU2T09dzdGryV8I`

## Key insights

- The `Streaming response failed` problem is unlikely to be fixed only by updating OpenCode or setting the default model, because the fresh session still fails on OpenCode Zen free models.
- Current evidence points to OpenCode Zen/provider-side instability or free-tier routing issues, not a stale local default model.
- Paid OpenCode Zen models appear usable but can still surface transient upstream gateway errors.

## Decisions

- User will likely use paid models for now because the free OpenCode Zen models appear unreliable.
- For future NixOS rebuild/apply work, the user prefers to run `nrs` and other long build commands directly so live output is visible in their terminal.

## Next steps

- If the free-model issue needs follow-up, collect the OpenCode logs around session `ses_0c0f2c70affeU2T09dzdGryV8I` and report the provider/model names plus error messages upstream.
- Keep the `ctranslate2` overlay until nixpkgs fixes the 4.8.1 source hash upstream, then remove the local override.
