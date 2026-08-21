# 2026-07-14 — Voice assistant speaker power via Kasa

> **CORRECTION / SUPERSEDED (2026-08-19):** This `python-kasa` approach never actually
> worked. The plug is a KP125M whose firmware uses **`TPAP`** encryption, which
> `python-kasa` does not implement, so it could never authenticate locally — the
> "validation" below was only an import/syntax check, never a live toggle. Speaker
> control now goes through **Home Assistant's Matter integration** (entity
> `switch.kasa_smart_wi_fi_plug`); `matter-server` is enabled in
> `modules/home-assistant.nix`. Full details in the voice-assistant repo:
> `memory/2026-08-19 speaker-power-via-ha-matter.md`. The `KASA_*` env vars are gone.

Added a first-class `speaker_power` tool to the voice-assistant orchestrator for the Sony receiver / desk speakers.

- Receiver Kasa plug IP: `10.0.50.124`.
- Credentials are expected in `orchestrator/.env` as `KASA_USERNAME`, `KASA_PASSWORD`, and `KASA_RECEIVER_HOST`.
- Password source: `pass show apps/kasa-smart/aaronjan98@gmail.com`.
- The tool supports `on`, `off`, and `status` and uses `python-kasa` locally.
- `modules/orchestrator.nix` now includes `python-kasa` in the `voice-orchestrator` Python environment.

Validation:

- Python import/syntax check passed using a Nix Python environment with `httpx` and `python-kasa`.
- Framework Nix build passed:
  `nix --extra-experimental-features 'nix-command flakes' build --print-out-paths '/home/aj/nixos-config#nixosConfigurations."framework-13".config.system.build.toplevel' --no-link`

Runtime follow-up:

- Updating the live gitignored `orchestrator/.env` from `pass` timed out because GPG did not unlock in the non-interactive Codex command. User should add the three Kasa variables locally, then run `nrt` and restart `voice-orchestrator`.
