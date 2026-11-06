# Light/dark theme propagation — session notes (2026-11-04/05)

## What was worked on
Continuation of the `quickshell-light-mode` work: getting every app to switch
light/dark with the wallpaper, the way kitty/ghostty already did.

1. **Obsidian** — fixed `theme-glass.css` so `.theme-dark`/`.theme-light` are
   fully separate (previously identical, neutralizing both the manual toggle
   and the automated switch). Light palette mirrors kitty/ghostty's warm-paper
   scheme. Fixed invisible command-palette selection highlight and
   button/dropdown contrast along the way. Committed in zettelkasten (`5d8cefc4`).
2. **RStudio** — added a custom warm-paper "Paper Light" theme
   (`~/.config/rstudio/themes/paper-light.rstheme`) to pair with the existing
   Cobalt dark theme. Tried hard to make it switch live via a `.Rprofile`
   polling loop + `rstudioapi`/`later` (new nix deps) — **abandoned**: RStudio
   has no live-reload path for `editor_theme` at all, confirmed directly
   (`writeRStudioPreference()` and `addTheme(apply=TRUE)` both persist to
   `rstudio-prefs.json` but never re-render an open window). Simplified to
   `set-wallpapers` writing the pref directly — "correct on next launch,"
   same as the kitty symlink swap. Committed in dot (`c99dd2e`).
3. **Firefox** — the big one. Replaced Super Dark Mode (no system-sync
   feature on its Firefox build) with Dark Reader (1.3M+ AMO daily users,
   vs. ~1 for the first alternative considered — AMO's `average_daily_users`
   API field is worth checking before trusting any extension with
   `<all_urls>`). Then spent most of the session chasing why **web content**
   wouldn't follow the system theme even though the OS-level signal chain
   (`gsettings color-scheme` → portal → GTK) was provably correct the whole
   time. Two real, separate bugs found and fixed:
   - Firefox's **chrome** (toolbar/menus) reads the actual GTK theme *name*,
     not the `color-scheme` hint. `gtk-theme` was hardcoded at
     `Adwaita-dark` forever; `set-wallpapers` now flips it between
     `Adwaita`/`Adwaita-dark` alongside `color-scheme`.
   - Firefox's **content** process (what `prefers-color-scheme` resolves to
     for web pages) was stuck because `widget.use-xdg-desktop-portal.settings`
     defaults to `2` (auto-detect), which gates on a desktop-environment
     allowlist that doesn't recognise Hyprland — so it silently never turns
     on, regardless of the pref being internally consistent. Forced to `1`
     via `firefox-autoconfig.js` (not `programs.firefox.preferences` — same
     not-on-Mozilla's-Preferences-policy-allowlist problem as the existing
     userChrome.css pref). Confirmed fixed via chatgpt.com switching live.
   Both committed in nixos-config (`8cc5b5d`).
4. **ContextForge** (`~/Repositories/projects/context-harness`) — once the
   Firefox-level bug was fixed, found a separate, much simpler bug in its own
   theme code: `matchMedia` was only ever checked once at the very first page
   load with empty localStorage; after that `zustand`'s `persist` middleware
   froze whatever got saved forever, with no live listener. Added a `'system'`
   theme option (default) resolved via a live `matchMedia('change')` listener
   (`useResolvedTheme()` in `store/settings.ts`). Existing users with a stale
   persisted `'dark'`/`'light'` value need to click Settings → System once to
   clear it. Committed on `main` (`be7df64`).

## Key insights
- **Don't trust a single layer's correctness as proof the whole chain works.**
  `gsettings`/the portal were correct almost the entire session while the
  actual symptom (stuck dark) persisted — the bug was always further
  downstream (GTK theme name, then the portal-integration gate, then
  ContextForge's own stale localStorage). Verify end-to-end, not link-by-link.
- `dconf dump /org/gnome/desktop/interface/` is the fast way to see every
  relevant gsettings key at once instead of querying them one by one.
- **"Correct on next launch" is often the ceiling, not "truly live."**
  RStudio confirmed to have zero live-theme-reapply path. Don't assume a
  pref-write API implies live UI reapplication — test it, as the
  `writeRStudioPreference`/`addTheme(apply=TRUE)` case showed neither does.
- Low-adoption browser extensions (AMO `average_daily_users`) are a real
  signal worth checking before granting `<all_urls>` — went from a ~1-user
  extension to Dark Reader (1.3M+) after checking this.
- Blind keyboard automation (`wtype`) into code-completion-heavy editors
  (RStudio's console) is unreliable — autocomplete popups eat characters
  unpredictably (dropped `,`, `=`, doubled quotes, a dropped trailing `i` in
  `rstudioapi`). Named-argument calls with `=` are especially fragile;
  positional args + avoiding `::` namespacing fared better, but still not
  reliable enough to depend on for anything beyond throwaway diagnostics.
- GTK portal file-choosers in Hyprland are a **separate top-level window**
  (`xdg-desktop-portal-gtk` class) that doesn't automatically have Hyprland
  keyboard focus even when visually on top — `hyprctl dispatch focuswindow`
  needs to target it explicitly, and `closewindow` is the reliable way to
  dismiss it (Escape didn't work).

## Decisions
- RStudio: "correct on next launch" accepted as the ceiling; the
  `rstudioapi`/`later` nix deps and `.Rprofile` polling approach were tried
  and explicitly reverted once proven not to buy anything over the simpler
  direct-pref-write approach.
- Dark Reader chosen over Auto Dark Mode V2 specifically for adoption/trust
  reasons, at the user's explicit request to re-check after I flagged it.

## Open questions / residual
- The native `<select>` dropdown's internal highlight color in Obsidian
  remains OS/Chromium-native on Linux — known, accepted limitation, not
  worth more iteration unless raised again.
- `~/.config/quickshell/rices/limerence/components/services/Notifs.qml` has
  unrelated uncommitted WIP in the `dot` repo (not from this session) —
  left untouched throughout, same as the two unrelated zettelkasten note
  files. Don't commit these without being asked.
- The empty `quickshell-light-mode` branch state in nixos-config predates
  this: branch now has real commits (Firefox fix). Not yet pushed this
  session — last explicit push instruction was for the *previous* round of
  changes (RStudio/Obsidian), before this Firefox/ContextForge work.

## Next steps
- None outstanding. User said "commit everything" (not "push") to close out
  this round — pushing the newer commits wasn't requested yet.
