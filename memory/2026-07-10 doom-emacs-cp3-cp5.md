# 2026-07-10 — Doom Emacs CP3–CP5 + cosmetics

## CP3 — Daemon verified

`systemctl --user start emacs` brought the daemon up (it was enabled but
inactive from CP1 since the service predated the Doom install).
- `emacsclient -e '(+ 1 1)'` → `2` ✓
- `emacsclient -c` → Doom frame opens instantly ✓
- Log showed "Doom loaded 62 packages across 10 modules in 0.521s"
- Also logged: `cat: /run/secrets/hf_token: Permission denied` — non-fatal,
  some env-sourcing script tries to read an optional secret

## Cosmetics — matching Ghostty appearance

**Goal**: make Emacs look like the Ghostty terminal (background `#1a0810`, 75%
opacity). Three separate things were wrong:

1. **Wrong transparency mechanism**: Hyprland `opacity` rule dims the ENTIRE
   window including text. What we want is `alpha-background` — an Emacs 29+
   frame parameter that makes only the background transparent, keeping text
   fully opaque. Added to `default-frame-alist` in config.el; removed the
   Hyprland window rule for emacs.

2. **Wrong background color**: Doom One theme uses `#282c34` (grey). Ghostty
   uses `#1a0810` (deep purple-black). Transparency of grey ≠ transparency of
   purple. Need to override the face background color.

3. **Solaire-mode timing**: Doom's `:ui doom` module enables `solaire-global-mode`
   which remaps almost every face through `solaire-*` variants (default →
   solaire-default-face, mode-line → solaire-mode-line-face, etc.). `after!`
   hooks and `custom-set-faces!` ran too early; `:ui doom` re-enabled it after.
   Fix: `add-hook 'doom-load-theme-hook` at depth 110 (solaire runs at 100),
   iterating over both base faces and their solaire-* variants and setting
   `:background "#1a0810"` on all of them.

Also fixed: initial Hyprland window rule used `class:^(Emacs)$` (capital E) but
`hyprctl clients` shows `class: emacs` (lowercase). Fixed to `class:^(emacs)$`.

## CP4 — Dotfiles tracking (folded into previous session)

Already done: `~/.doom.d/init.el`, `config.el`, `packages.el` committed to
dotfiles at end of previous context window.

## CP5 — Org basics

Added to `config.el`:
```elisp
(setq org-directory "~/org/"
      org-agenda-files '("~/org/tasks.org" "~/org/inbox.org"))
```

Created `~/org/tasks.org` and `~/org/inbox.org` with minimal `#+TITLE` and
`* Tasks` / `* Inbox` headings. These are runtime data — not tracked in git.

`SPC o a` opens org-agenda (empty for now). `SPC o c` opens org-capture with
Doom's default templates.

## Final config.el state

```elisp
;;; Frame — match Ghostty's background color (#1a0810) and opacity (0.75)
(add-to-list 'default-frame-alist '(alpha-background . 75))

;; Solaire-mode remaps many faces through solaire-* variants and runs at depth 100.
;; Hook in at depth 110 so we always win.
(add-hook 'doom-load-theme-hook
  (lambda ()
    (dolist (face '(default fringe
                    line-number line-number-current-line
                    mode-line mode-line-inactive mode-line-active header-line
                    solaire-default-face solaire-fringe-face
                    solaire-line-number-face
                    solaire-mode-line-face solaire-mode-line-inactive-face
                    solaire-mode-line-active-face solaire-header-line-face))
      (when (facep face)
        (set-face-attribute face nil :background "#1a0810"))))
  110)

;;; Cursor — red in all Evil states, blinking
(setq evil-normal-state-cursor '(box "red")
      evil-insert-state-cursor '(bar "red")
      evil-visual-state-cursor '(hollow "red")
      evil-emacs-state-cursor  '(box "red"))
(blink-cursor-mode 1)

;;; Org
(setq org-directory "~/org/"
      org-agenda-files '("~/org/tasks.org" "~/org/inbox.org"))
```
