# Math OCR Pix2tex Venv Runtime Spec

**Status:** Draft; runtime path approved
**Goal:** Make `math-ocr` reliable on NixOS by keeping the screenshot wrapper in Nix and running pix2tex from a pinned user-space Python venv.

---

## Plain-English Model

`math-ocr` has two different jobs:

1. Capture a screen region and copy text to the clipboard.
2. Run an ML model that turns the captured equation image into LaTeX.

Nix is a good fit for the first job because tools like `grim`, `slurp`, `wl-copy`, and `notify-send` are stable system commands.

Nix has been a bad fit for the second job because pix2tex behaves like a mutable ML app: it downloads model files, writes checkpoints, and expects exact agreement between Python code, model config, and weights.

The next implementation should keep that boundary explicit:

- Nix installs orchestration commands.
- A local pix2tex checkout plus venv provides the OCR engine.

---

## Evidence Already Found

### Repo state

- `hosts/common/default.nix` currently installs `nix-tools.packages.${pkgs.stdenv.hostPlatform.system}.math-ocr`.
- `tools/pkgs/math-ocr.nix` currently packages only the wrapper and non-Python runtime tools.
- `tools/scripts/math-ocr.sh` still searches `PATH` for `pix2tex_cli` or `pix2tex`, so it needs a venv-backed OCR engine to be exposed.
- `pkgs/pix2tex/default.nix`, `pkgs/math-ocr/default.nix`, `modules/math-ocr.nix`, `scripts/math-ocr.sh`, and `scripts/pix2tex-config.yaml` are vestigial pure-Nix attempts.
- `flake.nix` and `hosts/common/default.nix` still contain commented-out `pix2tex` / `math-ocr` references from those attempts.
- Hyprland already binds `ALT+M` to `math-ocr` in `/home/aj/.config/hypr/conf.d/20-binds.conf`.

### Project notes

- `docs/ROADMAP.md` already records the correct direction: reimplement with a venv runtime model.
- `memory/2026-04-21 roadmap backlog session.md` records the same decision and lists dead files.
- The zettelkasten note `Inside/Projects/prompt next AI to setup pix2tex with venv runtime in nix.md` says the Fedora setup worked by using a cloned repo plus venv.
- The zettelkasten note `Inside/Paper/my failure of installing and setting up pix2tex on nix.md` says pure system-wide Nix packaging repeatedly failed because of model/version mismatch, runtime mutability, Python packaging friction, and high rebuild cost.

### Git history

- `40e53cd add pix2tex`: first pure-Nix derivation attempt, exporting `pix2tex` through the overlay.
- `e0d70c7 add clipboard history to math ocr`: added a `math-ocr` wrapper and module around the pure derivation.
- `b0326ad add cliphist`: expanded wrapper/debug behavior and kept iterating on the Nix pix2tex package.
- `4ee8eba add scripts/pix2tex-config.yaml`: tried config and checkpoint forcing, plus Python 3.11.
- `44eeb52 add tools dir for custom system-wide flake migrations`: introduced the separate `tools/` flake.
- `f77a559 WIP clear system pix2tex implementation for a runtime env`: commented pix2tex out of the overlay and tools runtime inputs.

---

## Decision

Do not retry pure Nix pix2tex packaging.

Use this architecture instead:

### Nix-managed layer

- `math-ocr` command.
- `bootstrap-pix2tex` command.
- Non-Python runtime tools: `grim`, `slurp`, `wl-clipboard`, `libnotify`, `file`, `coreutils`, `gnused`, `gnugrep`, `git`, and a Nix-provided Python interpreter capable of creating venvs.
- Optional user systemd service that runs `bootstrap-pix2tex` at login.

### User-space runtime layer

- Local pix2tex repo cloned from `ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/pix2tex.git`.
- Checked out to an explicit pinned commit.
- Python venv created inside or next to that checkout.
- Python packages installed inside the venv.
- Mutable caches and checkpoints under `$XDG_CACHE_HOME` or `$HOME/.cache`, never under `/nix/store`.

---

## Recommended Runtime Layout

Use this runtime path:

```text
~/Repositories/automation/pix2tex/
  .git/              # git clone of pix2tex
  .venv/             # ignored Python virtual environment
```

Reasoning:

- It keeps the mutable runtime outside `~/nixos-config`.
- It fits the existing `~/Repositories/automation` area, which owns laptop utility workflows and automation projects.
- It keeps repo code and venv close enough that cleanup/debugging is obvious.
- It keeps `.venv/` inside a git repo boundary so `export-workspace-state.sh` records the repo and does not recursively walk the venv.

Do not commit the venv into `~/nixos-config` or the pix2tex repo. The bootstrap script should add `.venv/` to the clone's local `.git/info/exclude`. Commit only the scripts, pinned commit, requirements, routing docs, and bootstrap instructions that recreate that runtime on each machine.

---

## Implementation Phases

Progress is tracked in this file. Session-level detail is tracked in `memory/YYYY-MM-DD*.md`.

| Checkpoint | Status | Exit Criteria |
|---|---|---|
| 1. Cleanup vestigial pure-Nix attempts | Complete | Dead files and stale comments removed; active `tools/` wrapper remains |
| 2. Build wrapper package | Complete | `tools` flake package builds after cleanup |
| 3. Add `bootstrap-pix2tex` | Complete | Manual bootstrap creates/repairs repo + `.venv` |
| 4. Wire `math-ocr` to venv | Complete | Wrapper calls `.venv/bin/pix2tex` and fails clearly if missing |
| 5. Manual OCR test | Pending | Simple equation screenshot copies LaTeX to clipboard |
| 6. Rebuild integration | Pending | `nrt` passes; `nrs` only after user approval |
| 7. Docs and sync | Pending | Docs, roadmap, memory, and workspace routing reflect final state |

### Phase 0: Confirm decisions

Ask the user before coding:

1. Runtime path: approved as `~/Repositories/automation/pix2tex`.
2. Should bootstrap use the local git server only, or fall back to upstream GitHub if the server is unreachable?
3. Should bootstrap run automatically at login via user systemd, or only on first `math-ocr` invocation?
4. Should the first implementation include GUI command support for `latexocr`, or only the screenshot CLI flow?

Recommended answers:

- Git source: local git server only, fail clearly if unreachable.
- Bootstrap trigger: both systemd user service and on-demand check from `math-ocr`.
- GUI support: defer GUI until CLI flow works.

Resolved source-repo blocker:

- `bootstrap-pix2tex` builds and runs.
- The pix2tex source repo now exists locally at `~/Repositories/automation/pix2tex`.
- Local `main` tracks `home/main`.
- `home` points at `ssh://git@ssh.aaronjanovitch.com:2222/srv/git/repos/pix2tex.git`.
- `upstream` points at `https://github.com/lukas-blecher/LaTeX-OCR.git` for fetch-only upstream reference, with push disabled.
- Checkpoint 3 completed after running `bootstrap-pix2tex` against the existing local repo and confirming it created/repaired `.venv`.
- Dependency constraints were added for the venv install. Unbounded PyPI resolution pulled newer dependencies that compiled `stringzilla`; constraints now keep the runtime closer to the 2025-era pix2tex stack.

### Phase 1: Clean vestigial pure-Nix artifacts

Delete:

- `pkgs/pix2tex/`
- `pkgs/math-ocr/`
- `modules/math-ocr.nix`
- `scripts/math-ocr.sh`
- `scripts/pix2tex-config.yaml`

Clean comments:

- `flake.nix` commented `pix2tex` overlay and package export.
- `hosts/common/default.nix` commented `modules/math-ocr.nix` import and `#pix2tex` package line.

Keep:

- `tools/flake.nix`
- `tools/pkgs/math-ocr.nix`
- `tools/scripts/math-ocr.sh`
- `docs/ROADMAP.md` until implementation is complete.

Checkpoint for user: show the cleanup diff before adding bootstrap logic.

### Phase 2: Add bootstrap command

Add `tools/scripts/bootstrap-pix2tex.sh`.

Responsibilities:

- Create runtime directories.
- Clone the pix2tex repo if missing.
- Fetch and checkout the pinned commit.
- Create or recreate the venv if `$VENV/bin/python` is missing or not executable.
- Install pinned Python requirements.
- Log to `$XDG_CACHE_HOME/math-ocr/bootstrap.log`.
- Exit with actionable errors if git, network, or pip setup fails.
- Be idempotent: repeated runs should normally do nothing expensive unless the repo, pinned commit, venv, or requirements changed.

Nix packaging:

- Update `tools/pkgs/math-ocr.nix` to install both `math-ocr` and `bootstrap-pix2tex`.
- Add runtime dependencies needed by the bootstrap script.

Checkpoint for user: run the bootstrap manually and review logs before integrating with `math-ocr`.

### Phase 3: Wire wrapper to venv

Rewrite `tools/scripts/math-ocr.sh` so it:

- Ensures sane `HOME` and `XDG_CACHE_HOME`.
- Checks for the runtime venv.
- Offers a clear error if bootstrap has not run.
- Activates the venv or calls the venv binary directly.
- Captures a selected screen region.
- Runs pix2tex from the runtime venv.
- Copies LaTeX to the clipboard.
- Logs failure details under `$XDG_CACHE_HOME/math-ocr/`.

Avoid:

- Pre-seeding weights from Nix.
- Passing forced `-m` or config paths unless proven necessary for the pinned checkout.
- Symlinking model files into `/nix/store`.

Checkpoint for user: test `math-ocr` manually on a simple equation screenshot.

### Phase 4: Optional user service

Add a user service only after the manual bootstrap succeeds.

Recommended service:

- Name: `bootstrap-pix2tex.service`
- Type: `oneshot`
- Command: `bootstrap-pix2tex`
- Trigger: user login, not system boot.

Checkpoint for user: verify `systemctl --user status bootstrap-pix2tex.service` after rebuild.

### Phase 5: Documentation and verification

Update:

- `docs/ROADMAP.md`: mark the item implemented or move remaining follow-up tasks.
- `docs/PACKAGES.md`: describe the split Nix/runtime model.
- `docs/SCRIPTS.md`: document `math-ocr` and `bootstrap-pix2tex`.
- `CONTEXT.md`: update the active spec status if needed.
- `memory/YYYY-MM-DD.md`: record decisions and verification results.

Verify:

- `nix flake check ./tools` or direct build of `nix-tools.packages.x86_64-linux.math-ocr`.
- `nrt` before applying system config.
- `nrs` only after the test rebuild passes.
- Manual `bootstrap-pix2tex`.
- Manual `math-ocr` screenshot OCR.

---

## Open Risks

- The local git server may be unreachable on a fresh machine before SSH trust is restored.
- CPU-only torch wheels can be large and slow to install.
- Python venvs can break when the Nix-provided interpreter path changes; bootstrap must recreate the venv when the interpreter is no longer executable.
- pix2tex model loading may still use unsafe pickle behavior. Treat the pix2tex repo and weights as trusted inputs only.
- `math-ocr` is best for isolated equations, not full document OCR.

---

## Current Recommendation

Proceed with the venv runtime design.

The next concrete step should be Phase 1 cleanup, but only after the user approves the four Phase 0 decisions.
