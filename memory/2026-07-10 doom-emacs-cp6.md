# 2026-07-10 — Doom Emacs CP6 + cosmetic polish

## CP6 — Hyprland keybinds

Three binds added to `20-binds.conf`:
- `Super+O` → `emacsclient -c -e '(org-agenda-list)'`
- `Super+Shift+O` → `emacsclient -c -e '(org-capture)'`
- `Super+Shift+E` → `emacsclient -c` (general frame)

Note: `Super+E` was already taken by `sync-toast leave` (end-of-session sync).
`Super+Shift+E` chosen as the Emacs frame opener.

## Capture floating window rule

Added to `40-windowrules.conf`:
```
windowrulev2 = float,        class:^(emacs)$, title:^(CAPTURE.*)$
windowrulev2 = size 900 500, class:^(emacs)$, title:^(CAPTURE.*)$
windowrulev2 = center,       class:^(emacs)$, title:^(CAPTURE.*)$
```

Org-capture buffer names follow the pattern `CAPTURE-<filename>`, so
`title:^(CAPTURE.*)$` reliably matches them. The rule must use `emacs`
(lowercase) — `hyprctl clients` confirms that is the actual WM class for
emacs-pgtk on this system.

## Font size

Added `(set-face-attribute 'default nil :height 130)` inside the existing
`doom-load-theme-hook` lambda (depth 110). Height 130 = 13pt. Ghostty has
no explicit font setting so the system monospace default is used in both.

## CP7 — deferred

Custom org-capture templates (task, inbox, calendar event) deferred to a
future session. User wants to design the template structure before
implementing.
