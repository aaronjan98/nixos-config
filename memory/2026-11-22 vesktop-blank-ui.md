# 2026-11-22 — Vesktop blank white UI: version bumps were a red herring

## What was worked on

User reported Vesktop showing a blank white UI on launch. Investigated across
several turns, with two false fixes before the real one:

1. **Version check**: confirmed Vesktop was pinned via the stable `nixpkgs`
   (nixos-25.11) input at 1.6.5, and that branch's tip still only has 1.6.5 —
   no newer build available on stable. Added `vesktop = pkgsUnstable.vesktop;`
   to `myOverlay` in `flake.nix` (same pattern as code-cursor, zotero,
   quickshell) to pull 1.6.7 from the already-locked `nixpkgs-unstable` input.
2. Tried bumping `nixpkgs-unstable` further to get 1.6.9 — this dragged
   zotero's bundled `firefox-esr-140-bin-unwrapped` forward onto a build that's
   now past its EOL/insecure-package cutoff. Backed out rather than permit an
   insecure package just for vesktop.
3. **Better fix**: added a dedicated `nixpkgs-vesktop` flake input, pinned to
   the specific nixpkgs-unstable rev `5d2b81a7a3be3e2f832879028e4d60abbf58e9a0`
   (2026-11-14) that has vesktop 1.6.9, and a separate `pkgsVesktop` import —
   isolates the vesktop bump from `pkgsUnstable` so zotero/other unstable
   packages are untouched. `vesktop = pkgsVesktop.vesktop;` in `myOverlay`.
4. User ran `nixos-rebuild switch`, relaunched — still blank. A stale 1.6.5
   process (`SingletonLock` held) was also found and killed along the way,
   but that wasn't the real cause either.
5. Captured actual renderer console output via
   `vesktop --enable-logging=stderr --v=1 > logfile 2>&1` (redirect to a file
   directly — piping through `tail` loses output when `timeout` kills the
   process). Found the real error signature:
   `Error in patched module factory: TypeError: Cannot read properties of
   undefined (reading 'get')` in `fast-connect.*.js`, followed by
   `Uncaught TypeError: i.A is not a constructor` in the main `web.*.js`
   bundle, right as Vencord's WebpackPatcher tries to hook into Discord's
   current web client. This happened identically on 1.6.5, 1.6.7, and 1.6.9 —
   proof the Vesktop package version was never the variable that mattered.

## Key insight: Vencord's JS is NOT baked into the Vesktop package

Vesktop downloads Vencord's actual renderer/main JS bundle at runtime into
`~/.config/vesktop/sessionData/vencordFiles/` and caches it there,
**independent of the installed Vesktop app version**. This machine's cached
copy was dated **April 19, 2026** — 7 months stale — so every Nix package
version bump (1.6.5 → 1.6.7 → 1.6.9) was irrelevant; the actual broken code
was the same stale cached bundle the whole time, now mismatched against
Discord's current web client (which ships new builds frequently and can
break Vencord's generic webpack patches until Vencord/Vesktop issues a fix).
This is a widely-reported class of bug (confirmed via web search: Vesktop
issue #1407 "Persisted Vencord renderer failure leaves a black window after
reinstall" — reinstalling the app doesn't help for exactly this reason).

**The fix**: `pkill -f vesktop` (to release the SingletonLock Vesktop holds
even when "closed" to tray) then `vesktop --repair`, which re-downloads fresh
Vencord files. Confirmed via a follow-up `--enable-logging=stderr` capture
that the patch-failure errors were gone after repair.

## Decisions

- Kept the three-input split (`nixpkgs`, `nixpkgs-unstable`, `nixpkgs-vesktop`)
  in `flake.nix` even though it turned out not to be the fix — 1.6.9 is still
  strictly better than stable's 1.6.5 (adds a "Repair" prompt specifically for
  when Vencord fails to load, per its Nov 5 2026 changelog), and the isolated
  input avoids any future coupling between vesktop bumps and zotero's
  firefox-esr version.
- Did not add `firefox-esr-140-bin-unwrapped` to any unfree/insecure allowlist
  — reverted that attempt once the separate `nixpkgs-vesktop` input made it
  unnecessary.

## Next time this happens

If Vesktop (or any Vencord-based client) goes blank again, check
`~/.config/vesktop/sessionData/vencordFiles/*.js` timestamps **before**
touching the Nix package version — `vesktop --repair` (after fully killing
any running instance first, since it holds a SingletonLock even when
minimized to tray) is almost certainly the fix, not a version bump.

## Open questions / next steps

None outstanding — user confirmed Vesktop is working after the repair.
