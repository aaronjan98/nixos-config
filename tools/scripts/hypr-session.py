#!/usr/bin/env python3
"""hypr-session — per-domain save/restore for the 2D Hyprland workspace model.

Phase A+B: placement + editable menu (`skip`). Float geometry (Phase C) is
recorded as a bare `float` marker but not yet applied on restore.

Spec: ~/Repositories/projects/project-memory/hypr-session-spec.md
"""

import argparse
import json
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
import time
from collections import OrderedDict, defaultdict
from pathlib import Path

STATE_DIR = (
    Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    / "hypr-session"
)

# Delay between spawns so windows tile in a stable order.
SPAWN_GAP = 0.15

# Apps that restore their own tabs/windows on launch. For these we don't launch
# per-window: `save` records which window (by its active tab/note) belongs on
# each workspace (`restore=<class>`), and `restore` lets the app reopen its
# windows, then moves each to the workspace whose saved identity matches.
MATCH_APPS = {"firefox", "obsidian"}

# How to start each match-app so it restores its session.
MATCH_START = {"firefox": ["firefox"], "obsidian": ["obsidian-remote"]}


def window_identity(cls: str, title: str) -> str:
    """A stable per-window identity from its title: the active tab/note, with the
    app's constant suffix stripped. Used to match saved windows to restored ones."""
    t = (title or "").strip()
    if cls == "firefox":
        t = re.sub(r"\s+[—–-]\s+Mozilla Firefox$", "", t)
    elif cls == "obsidian":
        t = re.sub(r"\s+-\s+Obsidian(\s+[\d.]+)?$", "", t)  # -> "<note> - <vault>"
    return t.strip()


def state_file() -> Path:
    return STATE_DIR / f"{socket.gethostname()}.conf"


def default_header() -> str:
    return (
        f"# hypr-session — {socket.gethostname()}\n"
        "# Format: domain -> slot -> windows (one launch command per line).\n"
        "#   flags:  skip             keep as a menu entry, do not launch\n"
        "#           float [WxH@pos]  launch floating (geometry applied later)\n"
        "# Edit freely. `hypr-session save` overwrites the current domain;\n"
        "# last write wins (the file and a save are equal writers)."
    )


# --- workspace id <-> (domain, slot) --------------------------------------

def domain_of(wid: int) -> int:
    return 1 if 0 < wid < 10 else wid // 10


def slot_of(wid: int) -> int:
    return wid % 10


def workspace_id(domain: int, slot: int) -> int:
    return slot if domain == 1 else domain * 10 + slot


def cmd_appkey(cmd: str) -> str:
    """Best-effort window-class guess from a command (basename of argv[0])."""
    try:
        first = shlex.split(cmd)[0]
    except (ValueError, IndexError):
        parts = cmd.split()
        first = parts[0] if parts else ""
    return os.path.basename(first).lower()


# --- hyprctl ---------------------------------------------------------------

def hyprctl_json(*args):
    out = subprocess.run(
        ["hyprctl", "-j", *args], capture_output=True, text=True, check=True
    ).stdout
    return json.loads(out)


def current_domain() -> int:
    return domain_of(hyprctl_json("activeworkspace")["id"])


def cmdline_of(pid: int):
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return None
    parts = [p.decode("utf-8", "replace") for p in raw.split(b"\0") if p]
    if not parts:
        return None
    return " ".join(shlex.quote(p) for p in parts)


def launch_command(pid: int, cls: str):
    """Best launch command for a window: usually its /proc cmdline, but for
    wrapped Electron apps (Obsidian, etc.) the cmdline is `.../electron
    .../app.asar` — not runnable on its own — so prefer a clean PATH binary
    named after the window class (e.g. `obsidian`)."""
    raw = cmdline_of(pid)
    if not raw:
        return cls or ""
    try:
        argv0 = shlex.split(raw)[0]
    except (ValueError, IndexError):
        parts = raw.split()
        argv0 = parts[0] if parts else ""
    if os.path.basename(argv0).lower().startswith("electron"):
        cand = (cls or "").rsplit(".", 1)[-1].lower()
        if cand and shutil.which(cand):
            return cand
    return raw


def windows_of_class(cls: str):
    cls = cls.lower()
    return {
        c["address"]
        for c in hyprctl_json("clients")
        if (c.get("class") or "").lower() == cls
    }


def spawn_and_move(cmd: str, cls: str, wid: int):
    """Run cmd, wait for a NEW window of class `cls`, move it to workspace wid.
    Sequential (one window at a time) so the new window is unambiguous."""
    before = windows_of_class(cls)
    subprocess.Popen(cmd, shell=True, start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(30):  # up to ~15s
        time.sleep(0.5)
        fresh = windows_of_class(cls) - before
        if fresh:
            addr = sorted(fresh)[0]
            subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent",
                            f"{wid},address:{addr}"], check=False)
            return addr
    return None


def obsidian_open_vault():
    cfg = Path.home() / ".config" / "obsidian" / "obsidian.json"
    try:
        vaults = json.loads(cfg.read_text()).get("vaults", {})
    except (OSError, ValueError):
        return None
    openv = [v.get("path") for v in vaults.values() if v.get("open")]
    if openv:
        return openv[0]
    ranked = sorted(vaults.values(), key=lambda v: v.get("ts", 0), reverse=True)
    return ranked[0].get("path") if ranked else None


def obsidian_clear_floating():
    """Empty the popout-window list so a fresh launch opens only the main
    window, letting hypr-session own the extra windows. Other settings intact."""
    vault = obsidian_open_vault()
    if not vault:
        return
    wsf = Path(vault) / ".obsidian" / "workspace.json"
    try:
        data = json.loads(wsf.read_text())
    except (OSError, ValueError):
        return
    fl = data.get("floating")
    if isinstance(fl, dict) and fl.get("children"):
        fl["children"] = []
        try:
            wsf.write_text(json.dumps(data, indent=2))
        except OSError:
            pass


def obsidian_ensure_running():
    if windows_of_class("obsidian"):
        return
    subprocess.Popen(["obsidian-remote"], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(40):  # up to ~20s for cold start
        time.sleep(0.5)
        if windows_of_class("obsidian"):
            return


def windows_of_class_detailed(cls: str):
    cls = cls.lower()
    return [
        (c["address"], c.get("title") or "")
        for c in hyprctl_json("clients")
        if (c.get("class") or "").lower() == cls
    ]


def start_match_app(cls: str):
    cmd = MATCH_START.get(cls)
    if cmd:
        subprocess.Popen(cmd, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def match_and_move(cls, items):
    """items = [(ws, identity)]. The app restores its own windows; as each one
    appears AND its title populates, move it to the workspace whose saved
    identity matches. Re-scans until all are placed or the deadline, so windows
    that open late during a slow cold-start restore still get caught (a single
    pass would miss them). Returns how many were placed."""
    if not windows_of_class(cls):
        start_match_app(cls)
    wanted = list(items)
    placed = [False] * len(wanted)
    moved_addrs = set()
    end = time.monotonic() + 30  # generous for cold-start session restore
    while time.monotonic() < end and not all(placed):
        for addr, title in windows_of_class_detailed(cls):
            if addr in moved_addrs:
                continue
            ident = window_identity(cls, title)
            if not ident:  # title not loaded yet — try again next scan
                continue
            for i, (ws, wident) in enumerate(wanted):
                if not placed[i] and wident == ident:
                    subprocess.run(
                        ["hyprctl", "dispatch", "movetoworkspacesilent",
                         f"{ws},address:{addr}"], check=False)
                    placed[i] = True
                    moved_addrs.add(addr)
                    break
        if all(placed):
            break
        time.sleep(0.5)
    return sum(placed)


# --- entry <-> text --------------------------------------------------------

_FLOAT_RE = re.compile(r"\s+float(?:\s+(\S+))?$")


def parse_entry(line: str):
    """Peel `skip`/`float [spec]` flags off the right; the rest is the command."""
    s = re.sub(r"\s+#.*$", "", line).strip()  # drop inline comment
    if not s:
        return None
    skip = False
    floatspec = None
    appclass = None
    moveclass = None
    restoreclass = None
    changed = True
    while changed:
        changed = False
        if s == "skip" or s.endswith(" skip"):
            skip = True
            s = "" if s == "skip" else s[: -len(" skip")].rstrip()
            changed = True
            continue
        if s == "float":
            floatspec = ""
            s = ""
            changed = True
            continue
        m = _FLOAT_RE.search(s)
        if m:
            floatspec = m.group(1) or ""
            s = s[: m.start()].rstrip()
            changed = True
            continue
        m = re.search(r"\s+app=(\S+)$", s)
        if m:
            appclass = m.group(1)
            s = s[: m.start()].rstrip()
            changed = True
            continue
        m = re.search(r"\s+move=(\S+)$", s)
        if m:
            moveclass = m.group(1)
            s = s[: m.start()].rstrip()
            changed = True
            continue
        m = re.search(r"\s+restore=(\S+)$", s)
        if m:
            restoreclass = m.group(1)
            s = s[: m.start()].rstrip()
            changed = True
            continue
    if not s:
        return None
    return {"cmd": s, "skip": skip, "float": floatspec,
            "class": appclass, "move": moveclass, "restore": restoreclass}


def format_entry(e) -> str:
    flags = []
    if e.get("float") is not None:
        flags.append("float" + (f" {e['float']}" if e["float"] else ""))
    if e.get("restore"):
        # The text is the window's active tab/note identity, not a command.
        flags.append(f"restore={e['restore']}")
    elif e.get("move"):
        # move= carries the class and marks this as a spawn-and-move entry.
        flags.append(f"move={e['move']}")
    else:
        # Record class only when it isn't obvious from the command, so restore
        # can tell "already open" reliably without cluttering every line.
        cls = e.get("class")
        if cls and cls.lower() != cmd_appkey(e["cmd"]):
            flags.append(f"app={cls}")
    if e.get("skip"):
        flags.append("skip")
    body = e["cmd"]
    if flags:
        body = f"{e['cmd']:<30} {' '.join(flags)}"
    return "        " + body


def format_block(domain: int, slots) -> str:
    lines = [f"domain {domain}:"]
    for slot in sorted(slots):
        wid = workspace_id(domain, slot)
        lines.append(f"    slot {slot}:{'':<22}# -> workspace {wid}")
        for e in slots[slot]:
            lines.append(format_entry(e))
    return "\n".join(lines)


# --- state file (block-level, preserving untouched domains) ----------------

_DOMAIN_RE = re.compile(r"^domain\s+(\d+)\s*:")


def read_blocks(path: Path):
    """Return (header_text, OrderedDict{domain: block_text})."""
    if not path.exists():
        return default_header(), OrderedDict()
    header_lines = []
    blocks = OrderedDict()
    dnum = None
    buf = []
    for line in path.read_text().splitlines():
        m = _DOMAIN_RE.match(line)
        if m:
            if dnum is None:
                header_lines = buf
            else:
                blocks[dnum] = "\n".join(buf)
            dnum = int(m.group(1))
            buf = [line]
        else:
            buf.append(line)
    if dnum is None:
        header_lines = buf
    else:
        blocks[dnum] = "\n".join(buf)
    header = "\n".join(header_lines).strip() or default_header()
    return header, blocks


def write_blocks(path: Path, header: str, blocks) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    chunks = [header.rstrip()]
    for d in sorted(blocks):
        chunks.append(blocks[d].strip())
    path.write_text("\n\n".join(c for c in chunks if c).rstrip() + "\n")


def parse_block(text: str):
    """Parse a domain block into {slot: [entry, ...]}."""
    slots = defaultdict(list)
    slot = None
    for line in text.splitlines():
        if _DOMAIN_RE.match(line):
            continue
        ms = re.match(r"^\s*slot\s+(\d+)\s*:", line)
        if ms:
            slot = int(ms.group(1))
            continue
        if slot is None or not line.strip() or line.lstrip().startswith("#"):
            continue
        e = parse_entry(line)
        if e:
            slots[slot].append(e)
    return slots


# --- collect live state ----------------------------------------------------

def collect(target_domains):
    """Build {domain: {slot: [entry]}} from live clients.

    target_domains=None means every domain that has windows.
    """
    model = defaultdict(lambda: defaultdict(list))
    for c in hyprctl_json("clients"):
        wid = c.get("workspace", {}).get("id", 0)
        if wid < 1:  # special/scratchpad/invalid
            continue
        d = domain_of(wid)
        if target_domains is not None and d not in target_domains:
            continue
        cls = c.get("class") or ""
        restore = None
        if cls.lower() in MATCH_APPS:
            # The app restores its own tabs; record which window (by active
            # tab/note) belongs here, and match+move it on restore.
            cmd = window_identity(cls.lower(), c.get("title"))
            restore = cls.lower()
        else:
            cmd = launch_command(c.get("pid", -1), cls)
        if not cmd:
            continue
        model[d][slot_of(wid)].append(
            {
                "cmd": cmd,
                "skip": False,
                "float": "" if c.get("floating") else None,
                "class": cls,
                "move": None,
                "restore": restore,
            }
        )
    return model


# --- commands --------------------------------------------------------------

def cmd_save(args):
    path = state_file()
    header, blocks = read_blocks(path)
    if args.all:
        model = collect(None)
        blocks = OrderedDict(
            (d, format_block(d, model[d])) for d in sorted(model)
        )
    else:
        d = current_domain()
        model = collect({d})
        if d in model:
            blocks[d] = format_block(d, model[d])
        else:
            blocks[d] = f"domain {d}:\n    # (no windows captured)"
    write_blocks(path, header, blocks)
    dom_desc = "all domains" if args.all else f"domain {current_domain()}"
    print(f"saved {dom_desc} -> {path}")


def cmd_restore(args):
    path = state_file()
    if not path.exists():
        sys.exit(f"no session file at {path} (run `hypr-session save` first)")
    _, blocks = read_blocks(path)
    if args.all:
        domains = sorted(blocks)
    elif args.domain is not None:
        domains = [args.domain]
    else:
        domains = [current_domain()]

    # Snapshot which app classes are already open on each workspace, ONCE, before
    # launching anything. An entry is skipped only if its app is already present
    # on its target workspace at this point — so duplicates saved on a fresh
    # workspace still all spawn, but we never re-open something you already have
    # open (e.g. a terminal you restored a tmux session into yourself).
    present = defaultdict(set)
    for c in hyprctl_json("clients"):
        wid = c.get("workspace", {}).get("id", 0)
        if wid >= 1:
            present[wid].add((c.get("class") or "").lower())

    # Flatten to an ordered plan so spawn-and-move entries run sequentially.
    plan = []  # (wid, entry)
    for d in domains:
        if d not in blocks:
            print(f"domain {d}: nothing saved, skipping", file=sys.stderr)
            continue
        slots = parse_block(blocks[d])
        for slot in sorted(slots):
            wid = workspace_id(d, slot)
            for e in slots[slot]:
                if not e["skip"]:
                    plan.append((wid, e))

    # `restore=` entries are matched to app-restored windows by identity (grouped,
    # handled after the loop); everything else is placed/spawned directly.
    direct = []
    match_groups = defaultdict(list)  # class -> [(ws, identity)]
    for wid, e in plan:
        if e.get("restore"):
            match_groups[e["restore"]].append((wid, e["cmd"]))
        else:
            direct.append((wid, e))

    # Manual move=obsidian (blank-window) path clears Obsidian's popouts so a
    # fresh launch opens only the main window. (restore=obsidian keeps them.)
    if not args.dry_run and any(e.get("move") == "obsidian" for _, e in direct):
        obsidian_clear_floating()
        obsidian_ensure_running()

    launched = 0
    skipped = 0
    obsidian_main_used = False
    for wid, e in direct:
        key = (e.get("move") or e.get("class") or cmd_appkey(e["cmd"])).lower()
        if key and key in present[wid]:
            print(f"ws {wid}: {e['cmd']}  [already open — skip]")
            skipped += 1
            continue

        move_cls = e.get("move")
        if args.dry_run:
            how = f"spawn+move[{move_cls}]" if move_cls else "place"
            print(f"ws {wid}: {how}: {e['cmd']}")
            launched += 1
            continue

        # First Obsidian slot reuses the main window the fresh launch already
        # opened; later slots spawn new windows via obsidian-remote.
        if move_cls == "obsidian" and not obsidian_main_used:
            existing = sorted(windows_of_class("obsidian"))
            if existing:
                subprocess.run(["hyprctl", "dispatch", "movetoworkspacesilent",
                                f"{wid},address:{existing[0]}"], check=False)
                obsidian_main_used = True
                present[wid].add("obsidian")
                launched += 1
                time.sleep(SPAWN_GAP)
                continue

        if move_cls:
            spawn_and_move(e["cmd"], move_cls, wid)
        else:
            subprocess.run(
                ["hyprctl", "dispatch", "exec",
                 f"[workspace {wid} silent] {e['cmd']}"],
                check=False,
            )
        present[wid].add(key)
        launched += 1
        time.sleep(SPAWN_GAP)

    # restore= groups: let each app reopen its own windows, then move each to the
    # workspace whose saved active-tab/note identity matches.
    for cls, items in match_groups.items():
        if args.dry_run:
            for ws, ident in items:
                print(f"ws {ws}: match {cls} window [{ident}]")
                launched += 1
            continue
        moved = match_and_move(cls, items)
        launched += moved
        if moved < len(items):
            print(f"{cls}: matched {moved}/{len(items)} window(s)",
                  file=sys.stderr)

    verb = "would restore" if args.dry_run else "restored"
    tail = f" (skipped {skipped} already-open)" if skipped else ""
    print(f"{verb} {launched} window(s){tail}")


def cmd_edit(args):
    path = state_file()
    if not path.exists():
        write_blocks(path, default_header(), OrderedDict())
    editor = os.environ.get("EDITOR", "vi")
    subprocess.run([*shlex.split(editor), str(path)], check=False)


def main():
    p = argparse.ArgumentParser(prog="hypr-session", description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)

    ps = sub.add_parser("save", help="save the current domain (or --all)")
    ps.add_argument("--all", action="store_true", help="save the whole 2D grid")
    ps.set_defaults(func=cmd_save)

    pr = sub.add_parser("restore", help="restore a domain (default: current)")
    pr.add_argument("domain", nargs="?", type=int, help="domain number")
    pr.add_argument("--all", action="store_true", help="restore every domain")
    pr.add_argument("--dry-run", action="store_true",
                    help="print what would launch, don't spawn anything")
    pr.set_defaults(func=cmd_restore)

    pe = sub.add_parser("edit", help="open the session file in $EDITOR")
    pe.set_defaults(func=cmd_edit)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
