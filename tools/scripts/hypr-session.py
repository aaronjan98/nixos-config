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
    if not s:
        return None
    return {"cmd": s, "skip": skip, "float": floatspec, "class": appclass}


def format_entry(e) -> str:
    flags = []
    if e.get("float") is not None:
        flags.append("float" + (f" {e['float']}" if e["float"] else ""))
    # Record class only when it isn't obvious from the command, so restore can
    # tell "already open" reliably without cluttering every line.
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
        cmd = launch_command(c.get("pid", -1), cls)
        if not cmd:
            continue
        model[d][slot_of(wid)].append(
            {
                "cmd": cmd,
                "skip": False,
                "float": "" if c.get("floating") else None,
                "class": c.get("class") or "",
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

    launched = 0
    skipped = 0
    for d in domains:
        if d not in blocks:
            print(f"domain {d}: nothing saved, skipping", file=sys.stderr)
            continue
        slots = parse_block(blocks[d])
        for slot in sorted(slots):
            wid = workspace_id(d, slot)
            for e in slots[slot]:
                if e["skip"]:
                    continue
                key = (e.get("class") or cmd_appkey(e["cmd"])).lower()
                if key and key in present[wid]:
                    print(f"ws {wid}: {e['cmd']}  [already open — skip]")
                    skipped += 1
                    continue
                if args.dry_run:
                    print(f"ws {wid}: {e['cmd']}")
                else:
                    subprocess.run(
                        ["hyprctl", "dispatch", "exec",
                         f"[workspace {wid} silent] {e['cmd']}"],
                        check=False,
                    )
                    time.sleep(SPAWN_GAP)
                launched += 1
    verb = "would restore" if args.dry_run else "restored"
    tail = f" (skipped {skipped} already-open)" if skipped else ""
    print(f"{verb} {launched} window(s) from {len(domains)} domain(s){tail}")


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
