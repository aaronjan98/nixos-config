# Kanata setup

This document explains the behavior of the Kanata configuration used on the ThinkPad T14.

**Source of truth:** `hosts/thinkpad-t14/kanata/kanata-internal.kbd`

## What this config is doing

This Kanata setup is built around a small set of explicitly declared keys and a layered interaction model.

The major ideas are:

- home-row modifiers
- sticky uppercase mode
- sticky number mode
- momentary number mode on Space hold
- Vim-style arrows on `v`
- reusable multi-modifier “chord” keys
- a few global overrides that work across layers

It is not a full-keyboard Kanata matrix. Instead, `defsrc` defines a focused subset of keys that Kanata actively reasons about.

---

# How this config is structured

## `defcfg`

    (defcfg
      process-unmapped-keys yes
    )

- Kanata processes keys that are not explicitly remapped.
- This matters because the config only defines a subset of the keyboard in `defsrc`.

## `defvar`

The variables are timing constants and reusable modifier-chord definitions.

### Timing variables

- `hrm_tt`, `hrm_ht`
  - home-row mod tap/hold timing
- `nav_tt`, `nav_ht`
  - `v` tap/hold timing for navigation layer
- `cap_tt`, `cap_ht`
  - Caps tap/hold timing
- `lsft_tt`, `lsft_ht`
  - Left Shift tap/hold timing
- `rsft_tt`, `rsft_ht`
  - Right Shift tap/hold timing
- `spc_tt`, `spc_ht`
  - Space tap/hold timing

All are currently set to `200`.

### Reusable modifier chords

- `fj_chord`
  - `(multi lalt lsft)`
- `w_chord`
  - `(multi rctl lmet)`
- `g_chord`
  - `(multi rctl lalt lsft lmet)`
- `launch_chord`
  - `(multi lalt lmet)`

These are used by mod-tap aliases later in the file.

---

# `defsrc`: the keyboard shape Kanata knows about

`defsrc` defines the input positions Kanata is explicitly managing.

Current keys:

- `esc`
- `lsft rsft`
- `caps v`
- `q w e r t y u i o p`
- `a s d f g h j k l scln apos`
- `z x c b n m`
- `, . /`
- `tab bksl spc`
- `0 - =`
- `bspc`

## Important rule

Every `deflayer` must have the same number of entries, in the same order, as `defsrc`.

That is why the layers include trailing `_ _ _` entries corresponding to:

- `0`
- `-`
- `=`

and then a final `bspc`.

---

# Alias behavior

Most of the interesting behavior lives in `defalias`.

## Core special keys

### Caps

    cap (tap-hold-press $cap_tt $cap_ht esc lctl)

- tap `caps` → `esc`
- hold `caps` → `lctl`

### Caps in mode layers

    cap_exit (tap-hold $cap_tt $cap_ht (layer-switch default) lctl)

- tap `caps` → exit to `default`
- hold `caps` → `lctl`

So in sticky modes, Caps acts as both:
- a mode exit key
- a Control key

### `v` navigation key

#### Default layer

    nav (tap-hold-press $nav_tt $nav_ht v (layer-while-held arrows))

- tap `v` → `v`
- hold `v` → momentary `arrows` layer

#### Caps layer

    navC (tap-hold-press $nav_tt $nav_ht S-v (layer-while-held arrows))

- tap `v` → `V`
- hold `v` → momentary `arrows` layer

#### Major layer

    navM (tap-hold-press $nav_tt $nav_ht 8 (layer-while-held arrows))

- tap `v` → `8`
- hold `v` → momentary `arrows` layer

### Shift keys as mode-entry keys

#### Left Shift

    lsft_caps (tap-hold $lsft_tt $lsft_ht (layer-switch capslayer) lsft)

- tap `lsft` → enter `capslayer`
- hold `lsft` → normal left shift

#### Right Shift

    rsft_maj (tap-hold $rsft_tt $rsft_ht (layer-switch majlayer) rsft)

- tap `rsft` → enter `majlayer`
- hold `rsft` → normal right shift

### Space

    spcN (tap-hold-press $spc_tt $spc_ht spc (layer-while-held nums))

- tap `space` → space
- hold `space` → momentary `nums` layer

---

# Home-row modifiers

## Default-layer home-row mods

### Left side

- `a`:

      asft (tap-hold-press ... a lsft)

  - tap → `a`
  - hold → `lsft`

- `s`:

      salt (tap-hold-press ... s lalt)

  - tap → `s`
  - hold → `lalt`

- `d`:

      dmet (tap-hold-press ... d lmet)

  - tap → `d`
  - hold → `lmet`

### Right side

- `k`:

      kmet (tap-hold-press ... k rmet)

  - tap → `k`
  - hold → `rmet`

- `l`:

      lalt (tap-hold-press ... l lalt)

  - tap → `l`
  - hold → `lalt` (left Alt)

  > Note: this mod holds **left** Alt, not right. The physical **Right Alt**
  > key is intentionally left untouched by kanata so the compositor (XKB
  > `kb_variant = altgr-intl`) can use it as **AltGr** for typing accents.

- `;`:

      rsft (tap-hold-press ... scln rsft)

  - tap → `;`
  - hold → `rsft`

- `'`:

      rctl (tap-hold-press ... apos rctl)

  - tap → `'`
  - hold → `rctl`

## Caps-layer variants

These preserve the same modifier behavior while changing tap output to shifted characters.

Examples:

- `asftU`
  - tap → `A`
  - hold → `lsft`
- `saltU`
  - tap → `S`
  - hold → `lalt`
- `dmetU`
  - tap → `D`
  - hold → `lmet`

Also:

- `rsftU`
  - tap → `:`
  - hold → `rsft`
- `rctlU`
  - tap → `"`
  - hold → `rctl`

## Major/nums variants

These preserve modifier behavior while changing tap output to digits.

Examples:

- `saltM`
  - tap → `0`
  - hold → `lalt`
- `dmetM`
  - tap → `1`
  - hold → `lmet`
- `kmetM`
  - tap → `7`
  - hold → `rmet`
- `laltM`
  - tap → `5`
  - hold → `lalt` (left Alt)

---

# Special chord keys

These are keys that tap normally but hold as multi-modifier chords.

## `f` / `j`

### Default layer

- `fch`
  - tap `f`
  - hold `Alt+Shift`
- `jch`
  - tap `j`
  - hold `Alt+Shift`

### Caps layer

- `fchU`
  - tap `F`
  - hold `Alt+Shift`
- `jchU`
  - tap `J`
  - hold `Alt+Shift`

### Major/nums layer

- `fchM`
  - tap `8`
  - hold `Alt+Shift`
- `jchM`
  - tap `6`
  - hold `Alt+Shift`

## `w`

- `wch`
  - tap `w`
  - hold `rctl + lmet`
- `wchU`
  - tap `W`
  - hold `rctl + lmet`
- `wchM`
  - tap `8`
  - hold `rctl + lmet`

## `g`

- `gch`
  - tap `g`
  - hold `rctl + lalt + lsft + lmet`
- `gchU`
  - tap `G`
  - hold same chord
- `gchM`
  - tap `7`
  - hold same chord

## `tab` and `\`

These behave as launcher-style mod-taps:

- `tabL`, `tabLU`, `tabLM`
  - tap `tab`
  - hold `lalt + lmet`

- `bkslL`, `bkslLU`, `bkslLM`
  - tap `\`
  - hold `lalt + lmet`

---

# Global overrides

## Ctrl+H to Backspace

    (lctl h) (bspc)
    (lctl 6) (bspc)
    (lctl lsft h) (bspc)
    (lctl lsft 6) (bspc)

This makes `Ctrl+h` behave like Backspace.

It also covers:
- `Ctrl+6`
- `Ctrl+Shift+h`
- `Ctrl+Shift+6`

The `6` versions exist because `h` maps to `6` in the number-oriented layers.

## Zoom-related overrides

    (lmet =) (f13)
    (lmet -) (f14)
    (lmet 0) (f15)

These convert:
- `lmet + =` → `f13`
- `lmet + -` → `f14`
- `lmet + 0` → `f15`

This is explicitly described in the file as:

- “Zoom keybinds with hyprland”

So Kanata is not directly sending Ctrl+zoom shortcuts here. Instead, it emits synthetic function-key outputs intended to be handled later by Hyprland.

---

# Layers

## `default`

Purpose:
- normal typing layer

Notable behavior:
- `lsft` tap enters `capslayer`
- `rsft` tap enters `majlayer`
- `caps` tap is `esc`, hold is `ctrl`
- `v` hold enters `arrows`
- home-row mods active
- special chord mod-taps active
- `space` hold enters `nums`
- `0 - =` positions are `_ _ _`

## `arrows`

Purpose:
- momentary navigation layer entered by holding `v`

Notable mappings:
- `h` → `left`
- `j` → `down`
- `k` → `up`
- `l` → `rght`

Other details:
- the left side of the home row becomes plain modifiers / symbols rather than home-row mod aliases
- `0 - =` positions are `_ _ _`

## `capslayer`

Purpose:
- sticky uppercase / shifted-symbol layer entered by tapping left shift

Notable behavior:
- first key exits back to `default`:
  - `(layer-switch default)`
- `caps` uses `@cap_exit`
- `v` uses `@navC`
- top row becomes shifted letters / variants
- home-row mod-taps use uppercase/shifted tap outputs
- punctuation row is currently `_ _ _` for the `, . /` positions
- `0 - =` positions are `_ _ _`

## `majlayer`

Purpose:
- sticky number-oriented layer entered by tapping right shift

Notable mappings:
- top row includes numeric outputs like `4`, `1`, `9`
- home-row aliases switch to numeric tap outputs where defined
- `h` is `6`
- bottom row includes digits like `0`, `7`, `9`, `2`, `3`
- `v` uses `@navM`
- `0 - =` positions are `_ _ _`

## `nums`

Purpose:
- momentary number-oriented layer entered by holding space

Behavior:
- similar to `majlayer`
- not sticky
- exits when space is released
- begins with:
  - `esc`
  - `lsft rsft`
  - `@cap_exit`
  - `8`
- `0 - =` positions are `_ _ _`

---

# Layer summary

## `default`
- base typing
- home-row mods
- layer entry points
- launcher chords
- nav entry via `v`

## `arrows`
- held navigation layer
- `hjkl` arrows

## `capslayer`
- sticky uppercase / shifted layer
- entered by tapping left shift

## `majlayer`
- sticky number-oriented layer
- entered by tapping right shift

## `nums`
- momentary number-oriented layer
- entered by holding space

---

# Important implementation details

## 1. `defsrc` is intentionally incomplete

This is not a full keyboard matrix. It is a curated set of keys.

That means:
- Kanata only directly reasons about the declared keys
- every layer must stay aligned with this reduced key universe

## 2. Layer width must match `defsrc`

The three `_ _ _` entries near the bottom of layers correspond to the added:
- `0`
- `-`
- `=`

positions in `defsrc`.

## 3. Zoom is delegated to Hyprland

Kanata currently maps:
- `lmet + =` → `f13`
- `lmet + -` → `f14`
- `lmet + 0` → `f15`

The actual action is expected to happen outside Kanata.

## 4. Alias names can overlap with real modifier names

For example:

    lalt (tap-hold-press ... l lalt)

Here the first `lalt` is an **alias name**; the trailing `lalt` is the **built-in
left-Alt key** used as the hold action. They are the same word but different things:
alias references require a leading `@` (`@lalt`), so the un-prefixed `lalt` is always
the physical modifier. When reading the config, interpret names in context.

---

# Deploying & operating

## Applying a config change

The `.kbd` file is delivered to `/etc/kanata/kanata-internal.kbd` via
`environment.etc` (see each host's `configuration.nix`). **Important:** changing
the *contents* of that file does not change the systemd unit, and the service has
no `restartTrigger` on it — so `nrs` (`nixos-rebuild switch`) deploys the new file
but leaves the **old config running in memory**. After a `nrs` that touched the
`.kbd`, the change only takes effect once you restart the service (or reboot):

    sudo systemctl restart kanata-internal

To confirm the live process actually picked up the change, check which devices it
registered this boot — it should list only the intended keyboards:

    journalctl -u kanata-internal -b | grep registering

(If you'd rather have `nrs` alone apply `.kbd` edits, add a `restartTriggers` on the
config file to the service in `modules/kanata.nix`. Deliberately not done — a manual
restart avoids kanata dropping your keyboard grab mid-rebuild unexpectedly.)

## Validate before deploying

The config parses without touching any devices:

    kanata --cfg hosts/<host>/kanata/kanata-internal.kbd --check

## Device selection differs per host

`services.kanata.keyboards.*.devices` in `modules/kanata.nix` is **inert** because
both hosts supply a raw `configFile`; the module only honors `devices` when it
generates the config itself. So the device restriction lives in each host's
`defcfg`:

- **ThinkPad** — `linux-dev /dev/input/by-path/platform-i8042-serio-0-event-kbd`
  (internal keyboard only).
- **Framework** — `linux-dev-names-include ("AT Translated Set 2 keyboard" "SONiX
  USB DEVICE")` so both the internal and the external SONiX keyboard get the same
  layers. Name matching survives USB-port and event-number changes; it is only
  honored when `linux-dev` is omitted. Match is exact, and the external keyboard's
  live keystrokes come through its boot-keyboard interface (the `event*` node whose
  name is exactly `SONiX USB DEVICE`, carrying the `leds` handler).

## Troubleshooting: kanata at ~100% CPU

If kanata pegs a core and remaps don't work, and keyboard IRQs are **flat**
(`grep i8042 /proc/interrupts` twice — counts don't move), it is almost certainly a
**stuck key latched in the kernel** at boot, not a config bug. kanata busy-polls
`EVIOCGKEY` waiting for a release that never arrives. Find the key and clear it:

    PID=$(pgrep -x kanata)
    sudo timeout 1 strace -p "$PID" 2>&1 | grep -o 'EVIOCGKEY([0-9]*), \[[^]]*\]' | sort | uniq -c
    sudo systemctl stop kanata-internal   # then firmly press+release the named key
    sudo systemctl start kanata-internal

See `memory/2026-08-16 kanata 100pct cpu stuck-key.md` for the full diagnosis.

---

# Suggested repo placement

Given the current repo structure, this organization makes sense:

- `docs/KANATA.md`
  - human-facing explanation
- `hosts/thinkpad-t14/kanata/kanata-internal.kbd`
  - actual Kanata config
- `modules/kanata.nix`
  - service wiring and NixOS integration

A short note in `docs/README.md` linking to `docs/KANATA.md` also fits well.
