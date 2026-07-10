# Emacs Setup Spec

Branch: `doom-emacs` in `~/nixos-config`

Goal: integrate Emacs as a system-layer tool — global task capture, org-agenda
calendar, and system-wide text editing (emacs-everywhere) — while keeping
Neovim as the coding editor and Obsidian for the zettelkasten and LaTeX preview.

---

## How the pieces fit together — plain English

Before reading the checkpoints, read this. Each term is explained once here and
referenced by name in the checkpoints below.

### GNU Emacs

The actual program. Emacs is a text editor that has been extended over 40 years
into something closer to an operating environment — it has a mail client, a
file browser, a calendar, a terminal, and more, all built in or installable.
The reason it matters here is that Emacs runs a full programming language
(Elisp) in process, which means any two features can talk to each other
natively. That's why the blog author can have a single launcher that does
passwords AND bookmarks AND todos — they're all just Elisp functions running
inside the same process.

### emacs-pgtk

A build variant of Emacs. "pgtk" stands for "pure GTK" — it means the GUI
is drawn using GTK3 natively on Wayland, without going through XWayland.
This is the correct variant for Hyprland: it renders properly, clipboard
integration works, and fractional scaling works. The alternative (`emacs`
or `emacs-gtk`) would fall back to XWayland, causing blurry rendering and
clipboard issues.

### The pkgsUnstable pattern (how it works in this repo)

Your flake.nix maintains two nixpkgs sets:
- `nixpkgs` (stable, version 25.11) — the base for most of the system
- `nixpkgs-unstable` — imported separately as `pkgsUnstable`

Neither of these rebuilds packages from source. Both have binary caches on
cache.nixos.org, so installing from either just downloads a pre-built binary.
The difference is only recency: unstable gets newer versions faster.

The `myOverlay` at the bottom of flake.nix is how specific packages from
unstable get injected into the stable package set. Every entry in that overlay
says "when any NixOS module asks for pkgs.X, give it the unstable version
instead." For example:

    claude-code = pkgsUnstable.claude-code;

means any module that writes `pkgs.claude-code` gets the unstable build
automatically. We'll add `emacs-pgtk = pkgsUnstable.emacs-pgtk;` to that
same list. Then `modules/emacs.nix` can just write `pkgs.emacs-pgtk` and it
will resolve to the unstable version — no special handling needed in the module.

### Emacs daemon

Normally, running `emacs` starts a fresh process, loads your entire config,
and displays a window. With Doom installed, this takes 2-4 seconds. That's
fine for a text editor you open once, but it breaks the "capture from any
window in under a second" workflow.

The daemon solves this: `emacs --daemon` starts Emacs as a background process
with no window. It loads your entire config once at login and then sits waiting.
`emacsclient` is then a tiny program that connects to the running daemon and
says "open a frame" or "run this elisp command." Because the config is already
loaded, response is instant.

The systemd user service (`services.emacs.enable = true` in NixOS) makes this
automatic: at login, systemd starts the daemon. If it crashes, systemd restarts
it. You never have to think about it.

The daemon is also why all the Hyprland keybinds work. A keybind like:

    bind = CTRL SHIFT, C, exec, emacsclient -e '(org-capture)'

doesn't open Emacs — it sends the Elisp expression `(org-capture)` to the
already-running daemon, which pops up a small capture frame in under 100ms.

### Doom Emacs

Doom is a configuration framework that sits on top of GNU Emacs. Think of it
like a highly opinionated starter kit. By itself, vanilla Emacs has ~zero
configuration — you have to set up every feature from scratch. Doom pre-wires
everything: keybindings, completion, UI, Evil mode, and a curated set of
language and tool integrations. It uses a module system so you enable only
what you want.

Doom lives in `~/.emacs.d/` (the standard Emacs config directory). This
directory is NOT tracked in git — Doom manages it internally and it changes
constantly. Think of it like `node_modules/` or your neovim's `lazy` data
directory: generated runtime, not source code.

Your source code is `~/.doom.d/`, which has exactly three files:

- `init.el` — the module list. Each line enables a Doom feature. Examples:
  `(evil +everywhere)` turns on Vim keybindings. `(org +roam2)` turns on
  org-mode plus org-roam. You don't write elisp here, just enable/disable.

- `config.el` — your personal elisp. This is where you set org-directory,
  define capture templates, customize keybinds, and tweak behavior. This is
  the file you'll be editing the most once the basic setup is done.

- `packages.el` — extra package declarations for things not in Doom's module
  set. For example, `emacs-everywhere` isn't a Doom module, so it goes here.

These three files ARE tracked in `~/.dotfiles/` via the `dot` command.

### straight.el

straight.el is the package manager Doom uses internally. Emacs's built-in
package manager (package.el) installs packages from registries like MELPA —
similar to how npm installs from the npm registry. The problem is that MELPA
packages update constantly and can break without warning.

straight.el instead clones each package's git repository directly and pins
it to a specific commit hash. This is exactly what `lazy-lock.json` does for
your neovim plugins. Doom ships with its own lockfile
(`~/.emacs.d/.local/straight/versions/doom.lock`) that pins every package.
When you run `doom upgrade`, it updates those pins. When you run `doom sync`,
it ensures the installed packages match the pins.

You never interact with straight.el directly. You just run `doom sync` after
changing your config and `doom upgrade` when you want to update packages
(infrequently, on your schedule).

### org-mode

org-mode is an Emacs major mode (like how Neovim has filetypes). `.org` files
use a lightweight markup similar to Markdown but with built-in task states,
scheduling, and metadata. The power isn't in the file format — it's in what
Emacs can do with it:

- **org-agenda**: reads all your `.org` files and generates a unified calendar/
  TODO view filtered by date, priority, or tag
- **org-capture**: a pop-up that lets you quickly file a note/task/event into
  the right `.org` file using pre-defined templates, without losing your current
  context (you close the capture frame and go back to whatever you were doing)
- **org-babel**: runs code blocks inside `.org` files inline (not used heavily
  in our setup but useful for scripting)

The `~/org/` directory will hold your `.org` files. These are runtime data
(like `~/Documents/context-harness/conversations/`) — not tracked in git,
synced via Syncthing if needed across machines.

### emacs-everywhere

A package that makes Emacs act as an external editor for any text field on
your system. You focus a text field (browser URL bar, CF message input,
anything), press the keybind, and a small Emacs frame appears pre-populated
with whatever was in that field. You edit it with full Evil+Org, press
`C-c C-c`, and the text is pasted back into the original field. It uses
`wl-clipboard` under the hood (Wayland clipboard) to transfer the text.

---

## Checkpoints

### CP1 — NixOS: install emacs-pgtk

**Files changed**: `flake.nix`, `modules/emacs.nix`,
`hosts/thinkpad-t14/configuration.nix`

What happens:
- Add `emacs-pgtk = pkgsUnstable.emacs-pgtk;` to `myOverlay` in `flake.nix`
- Create `modules/emacs.nix` with `environment.systemPackages` and
  `services.emacs` (enables the daemon as a systemd user service)
- Import the module in `hosts/thinkpad-t14/configuration.nix`
- Run `nrt` to verify, then `nrs` to apply

Test:
```bash
emacs --version        # should print Emacs 29.x or 30.x
emacs &                # should open a plain Emacs GUI (no Doom yet)
```

The GUI at this point is vanilla Emacs — ugly, no keybindings, no anything.
That's expected. The point of this checkpoint is just that the binary is
installed and the daemon service unit exists in systemd.

Commit: nixos-config `doom-emacs` branch

---

### CP2 — Install Doom Emacs (manual, outside Nix)

**Files changed**: `~/.emacs.d/` (not tracked), `~/.doom.d/` (new, will be tracked)

What happens:
- Clone Doom to `~/.emacs.d/`
- Write a minimal `~/.doom.d/init.el` enabling only `evil` and `org`
- Run `~/.emacs.d/bin/doom install` — this pulls all package repos via
  straight.el and compiles them

Why manual and not through Nix: Doom's packages are managed by straight.el
with its own lockfile. Making all of this declarative through Nix (via
nix-doom-emacs) adds significant complexity and has compatibility edge cases.
The simpler model — Nix provides the Emacs binary, Doom manages its own
packages — is stable, well-understood, and used by most Doom+NixOS setups.
`~/.emacs.d/` is effectively like a locally-managed venv or node_modules:
ephemeral, reproducible via `doom install` on a fresh machine.

Test:
```bash
emacs                  # should open the Doom dashboard
                       # SPC h d h  → opens Doom help (tests evil leader key)
```

---

### CP3 — Verify daemon + emacsclient

**Files changed**: none (systemd service was created in CP1, just need to start it)

What happens:
- `systemctl --user enable --now emacs` starts the daemon for this session
  (after this point it starts automatically at every login via the NixOS-managed
  service unit)
- Verify emacsclient can reach it

Test:
```bash
systemctl --user status emacs    # should show active (running)
emacsclient -e '(+ 1 1)'        # should return 2
emacsclient -c                   # should open a Doom frame instantly
```

This is the checkpoint that unlocks everything that follows. Once
`emacsclient` works, every Hyprland keybind and every integration is just a
matter of calling the right elisp function.

---

### CP4 — Track ~/.doom.d/ in dotfiles + commit

**Files changed**: dotfiles repo adds `~/.doom.d/`

What happens:
- `dot add ~/.doom.d/init.el ~/.doom.d/config.el ~/.doom.d/packages.el`
- `dot commit`

Why this checkpoint exists separately: this is the gitops gate. Before writing
any more config, the source files should be in version control so every
subsequent change is tracked and reversible.

Note: `~/.emacs.d/` itself must stay out of the dotfiles repo. Add it to
`~/.dotfiles.gitignore` (the bare repo's gitignore) to be explicit.

---

### CP5 — org basics: directory, files, agenda

**Files changed**: `~/.doom.d/config.el`, new `~/org/` files

What happens:
- Set `org-directory` and `org-agenda-files` in config.el
- Create `~/org/tasks.org` and `~/org/inbox.org` with minimal structure
- Run `doom sync` to reload config

Test:
```
SPC o a          → opens org-agenda
SPC o c          → opens org-capture (with default Doom templates for now)
```

---

### CP6 — Hyprland keybinds

**Files changed**: `~/.config/hypr/conf.d/20-binds.conf`

What happens:
- `Super+C` → `emacsclient -e '(org-agenda-list)'` (calendar/agenda view)
- `Ctrl+Shift+C` → `emacsclient -e '(org-capture)'` (capture from anywhere)

Test: switch to Firefox, press `Ctrl+Shift+C` — a capture frame should
appear over Firefox without leaving it.

---

### CP7 — Custom org-capture templates

**Files changed**: `~/.doom.d/config.el`

What happens:
- Define templates for: task (files to tasks.org), inbox note (files to
  inbox.org), calendar event (with scheduled date)
- Discuss what templates make sense for the user's actual workflow here

Test: each template routes to the correct file and prompts for the right fields.

---

### CP8 — emacs-everywhere

**Files changed**: `~/.doom.d/packages.el`, `~/.doom.d/config.el`,
`~/.config/hypr/conf.d/20-binds.conf`

What happens:
- Declare `emacs-everywhere` in packages.el
- Configure it for Wayland (wl-clipboard)
- `Ctrl+Super+E` keybind in Hyprland

Test: focus the CF message input in Firefox, press `Ctrl+Super+E`, edit in
Emacs, confirm — text appears back in the input.

---

### CP9 — password-store integration (conditional)

Depends on whether pass is the active password manager. Discuss at CP8.

---

## What is NOT in scope

- `:lang latex` module — Obsidian handles LaTeX preview; no reason to duplicate
- mu4e (email) — not a stated need
- EMMS (music) — Navidrome handles this
- elfeed (RSS) — not a stated need  
- org-roam — Obsidian zettelkasten is the established system; no migration
- EXWM — explicitly rejected in favor of Hyprland

---

## Maintenance model

- `doom upgrade` — run deliberately when you want to update packages; not automatic
- `doom sync` — run after any change to `~/.doom.d/`
- NixOS rebuild is only needed if you change `modules/emacs.nix` or flake.nix
- `~/.doom.d/` changes do not require an `nrs` — they're just files that
  doom sync processes

---

## Future scope (not in this spec)

- Programmable integrations: smart speaker tool calls via org-capture HTTP
  endpoint or a small elisp server; possible since Emacs can open a socket
  server with `(server-start)` and accept connections from external scripts
- Calendar sync: org-gcal or similar to pull Google/CalDAV events into
  org-agenda
- Per-conversation org notes linked to ContextForge conversations
