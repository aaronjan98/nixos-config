#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
#
# Long-lived TCP client for kanata's built-in control socket (port 7979, set
# via `services.kanata.keyboards.internal.port` in modules/kanata.nix), used
# by the quickshell mode island (components/services/KanataCtl.qml). Speaks
# newline-delimited JSON on stdin/stdout, mirroring the obs-ctl-daemon.py
# contract:
#
#   stdin  (one command object per line):
#     {"cmd": "set_layer", "layer": "<name>"}
#     {"cmd": "refresh"}
#
#   stdout (one full state snapshot per line, emitted on every change):
#     {"connected": bool, "layer": str, "layers": [str...]}
#
# Wire protocol to kanata itself (confirmed against kanata v1.9.0 source,
# tcp_protocol/src/lib.rs and src/tcp_server.rs -- see
# ~/.config/quickshell/project-memory/kanata-island.md):
#   client -> kanata : {"ChangeLayer": {"new": "<name>"}}
#                       {"RequestLayerNames": {}}
#   kanata -> client : {"LayerChange": {"new": "<name>"}}   -- pushed on
#                       connect with the current layer, and again on every
#                       layer change (including ones this client caused)
#                       {"LayerNames": {"names": ["<name>", ...]}}
# Struct-variant enums serialize as {"Variant": {field: value}}, including
# the empty-field variants (RequestLayerNames is "{}", not a bare string).
# Messages are JSON values written back to back (kanata appends a trailing
# newline but does not require one on input); treated as newline-delimited
# here since every message observed in practice is one line.

import asyncio
import json

HOST = "127.0.0.1"
PORT = 7979


def emit(obj):
    print(json.dumps(obj), flush=True)


class State:
    def __init__(self):
        self.connected = False
        self.layer = ""
        self.layers = []

    def snapshot(self):
        return {"connected": self.connected, "layer": self.layer, "layers": self.layers}


state = State()
_writer = None


def emit_status():
    emit(state.snapshot())


async def send(obj):
    if _writer is None:
        return
    _writer.write((json.dumps(obj) + "\n").encode())
    await _writer.drain()


async def reader_loop(reader):
    buf = b""
    while True:
        chunk = await reader.read(4096)
        if not chunk:
            return
        buf += chunk
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except Exception:
                continue
            await handle_message(msg)


async def handle_message(msg):
    if "LayerChange" in msg:
        state.layer = msg["LayerChange"].get("new", state.layer)
        emit_status()
    elif "LayerNames" in msg:
        state.layers = msg["LayerNames"].get("names", [])
        emit_status()
    elif "Error" in msg:
        emit({"transientError": msg["Error"].get("msg", "")})


async def connection_loop():
    global _writer
    backoff = 2
    while True:
        try:
            reader, writer = await asyncio.open_connection(HOST, PORT)
            _writer = writer
            state.connected = True
            backoff = 2
            emit_status()

            await send({"RequestLayerNames": {}})
            await reader_loop(reader)
        except Exception:
            pass
        finally:
            _writer = None
            state.connected = False
            emit_status()
        await asyncio.sleep(backoff)
        backoff = min(backoff * 2, 15)


async def dispatch_command(cmd_obj):
    cmd = cmd_obj.get("cmd")
    if cmd == "set_layer":
        await send({"ChangeLayer": {"new": cmd_obj["layer"]}})
    elif cmd == "refresh":
        await send({"RequestLayerNames": {}})


class StdinProtocol(asyncio.Protocol):
    def __init__(self):
        self.buf = b""

    def data_received(self, data):
        self.buf += data
        while b"\n" in self.buf:
            line, self.buf = self.buf.split(b"\n", 1)
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                continue
            asyncio.ensure_future(dispatch_command(obj))


async def main():
    loop = asyncio.get_event_loop()
    import sys
    await loop.connect_read_pipe(StdinProtocol, sys.stdin)
    await connection_loop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
