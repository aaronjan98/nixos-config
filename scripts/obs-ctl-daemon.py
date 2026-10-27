#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages (ps: [ps.websockets])"
#
# Long-lived obs-websocket (v5 protocol) client for the quickshell OBS
# control popup (components/services/ObsCtl.qml). Speaks newline-delimited
# JSON on stdin/stdout:
#
#   stdin  (one command object per line):
#     {"cmd": "recording_toggle"} | "recording_start" | "recording_stop"
#     {"cmd": "recording_pause_toggle"}
#     {"cmd": "streaming_toggle"} | "streaming_start" | "streaming_stop"
#     {"cmd": "vcam_toggle"}
#     {"cmd": "replay_toggle"} | {"cmd": "replay_save"}
#     {"cmd": "scene_set", "scene": "<name>"}
#     {"cmd": "input_mute_toggle", "input": "<name>"}
#     {"cmd": "input_set_volume", "input": "<name>", "volumeMul": 0.0-1.0+}
#     {"cmd": "refresh"}
#
#   stdout (one full state snapshot per line, emitted on every change):
#     {"connected": bool, "error": str|null, "obsVersion": str|null,
#      "recording": {"active":bool,"paused":bool,"timecode":str},
#      "streaming": {"active":bool}, "virtualCam": {"active":bool},
#      "replayBuffer": {"active":bool}, "currentScene": str,
#      "scenes": [str...], "inputs": [{"name","muted","volumeMul"}...]}
#
# Password comes straight from OBS's own obs-websocket config file (never
# duplicated into dotfiles) -- re-read on every (re)connect so a password
# rotated from OBS's UI is picked up without restarting this daemon.
#
# obs-cli (nixpkgs) was tried first and rejected: it's built on goobs v0.8.0,
# which only speaks the old v4 wire protocol (request type "ToggleMute" etc,
# confirmed via its generated source) -- OBS 28+'s bundled obs-websocket is
# v5-only, so obs-cli can't even complete the handshake. obs-cmd (nixpkgs,
# Rust/obws v0.14) does speak v5 correctly, but has no scene listing command
# and prints Rust Debug-formatted text instead of structured data. Talking
# the v5 JSON protocol directly over a raw websocket, as implemented here,
# is what gives this popup a live scene list, live mute states, and
# push updates via events instead of polling.

import asyncio
import base64
import hashlib
import itertools
import json
import os
import sys

import websockets

OBS_CONFIG_PATH = os.path.expanduser(
    "~/.config/obs-studio/plugin_config/obs-websocket/config.json"
)

# EventSubscription bitmask: General|Config|Scenes|Inputs|Transitions|Filters
# |Outputs|SceneItems|MediaInputs|Vendors|Ui (every non-high-volume category --
# excludes InputVolumeMeters, which fires many times a second per input).
EVENT_SUBSCRIPTIONS = 2047


def emit(obj):
    print(json.dumps(obj), flush=True)


def read_obs_config():
    try:
        with open(OBS_CONFIG_PATH) as f:
            cfg = json.load(f)
    except Exception:
        return None
    return {
        "port": cfg.get("server_port", 4455),
        "password": cfg.get("server_password", "") or "",
        "enabled": cfg.get("server_enabled", False),
    }


def make_auth_response(password, salt, challenge):
    secret = base64.b64encode(hashlib.sha256((password + salt).encode()).digest()).decode()
    return base64.b64encode(hashlib.sha256((secret + challenge).encode()).digest()).decode()


class ObsState:
    def __init__(self):
        self.connected = False
        self.error = None
        self.obs_version = None
        self.recording = {"active": False, "paused": False, "timecode": "00:00:00"}
        self.streaming = {"active": False}
        self.virtual_cam = {"active": False}
        self.replay_buffer = {"active": False}
        self.current_scene = ""
        self.scenes = []
        self.inputs = []

    def snapshot(self):
        return {
            "connected": self.connected,
            "error": self.error,
            "obsVersion": self.obs_version,
            "recording": self.recording,
            "streaming": self.streaming,
            "virtualCam": self.virtual_cam,
            "replayBuffer": self.replay_buffer,
            "currentScene": self.current_scene,
            "scenes": self.scenes,
            "inputs": self.inputs,
        }


state = ObsState()
_req_counter = itertools.count(1)
_pending = {}
_ws = None


def emit_status():
    emit(state.snapshot())


async def send_request(request_type, request_data=None, timeout=5):
    if _ws is None:
        raise RuntimeError("not connected")
    req_id = str(next(_req_counter))
    fut = asyncio.get_event_loop().create_future()
    _pending[req_id] = fut
    payload = {"op": 6, "d": {"requestType": request_type, "requestId": req_id}}
    if request_data is not None:
        payload["d"]["requestData"] = request_data
    await _ws.send(json.dumps(payload))
    try:
        resp = await asyncio.wait_for(fut, timeout)
    finally:
        _pending.pop(req_id, None)
    status = resp.get("requestStatus", {})
    if not status.get("result", False):
        raise RuntimeError(f"{request_type} failed: {status.get('comment')}")
    return resp.get("responseData", {}) or {}


async def refresh_scenes():
    data = await send_request("GetSceneList")
    state.scenes = [s.get("sceneName", "") for s in data.get("scenes", [])]
    cur = data.get("currentProgramSceneName")
    if cur:
        state.current_scene = cur


async def refresh_inputs():
    data = await send_request("GetInputList")
    names = [i.get("inputName", "") for i in data.get("inputs", [])]
    inputs = []
    for name in names:
        if not name:
            continue
        try:
            mute_data = await send_request("GetInputMute", {"inputName": name})
            vol_data = await send_request("GetInputVolume", {"inputName": name})
        except Exception:
            continue  # not an audio-capable input (e.g. a scene, a browser source)
        inputs.append({
            "name": name,
            "muted": bool(mute_data.get("inputMuted", False)),
            "volumeMul": float(vol_data.get("inputVolumeMul", 1.0)),
        })
    state.inputs = inputs


async def refresh_outputs():
    try:
        d = await send_request("GetRecordStatus")
        state.recording = {
            "active": bool(d.get("outputActive", False)),
            "paused": bool(d.get("outputPaused", False)),
            "timecode": d.get("outputTimecode", "00:00:00"),
        }
    except Exception:
        pass
    try:
        d = await send_request("GetStreamStatus")
        state.streaming = {"active": bool(d.get("outputActive", False))}
    except Exception:
        pass
    try:
        d = await send_request("GetVirtualCamStatus")
        state.virtual_cam = {"active": bool(d.get("outputActive", False))}
    except Exception:
        pass
    try:
        d = await send_request("GetReplayBufferStatus")
        state.replay_buffer = {"active": bool(d.get("outputActive", False))}
    except Exception:
        pass


async def full_refresh():
    await refresh_outputs()
    await refresh_scenes()
    await refresh_inputs()
    emit_status()


async def handle_event(event_type, data):
    if event_type == "RecordStateChanged":
        state.recording["active"] = bool(data.get("outputActive", state.recording["active"]))
        state.recording["paused"] = data.get("outputState") == "OBS_WEBSOCKET_OUTPUT_PAUSED"
        emit_status()
    elif event_type == "StreamStateChanged":
        state.streaming["active"] = bool(data.get("outputActive", state.streaming["active"]))
        emit_status()
    elif event_type == "VirtualcamStateChanged":
        state.virtual_cam["active"] = bool(data.get("outputActive", state.virtual_cam["active"]))
        emit_status()
    elif event_type == "ReplayBufferStateChanged":
        state.replay_buffer["active"] = bool(data.get("outputActive", state.replay_buffer["active"]))
        emit_status()
    elif event_type == "CurrentProgramSceneChanged":
        name = data.get("sceneName")
        if name:
            state.current_scene = name
            emit_status()
    elif event_type in ("SceneListChanged", "SceneCreated", "SceneRemoved", "SceneNameChanged"):
        try:
            await refresh_scenes()
            emit_status()
        except Exception:
            pass
    elif event_type == "InputMuteStateChanged":
        name, muted = data.get("inputName"), data.get("inputMuted")
        for inp in state.inputs:
            if inp["name"] == name:
                inp["muted"] = bool(muted)
        emit_status()
    elif event_type == "InputVolumeChanged":
        name, vol = data.get("inputName"), data.get("inputVolumeMul")
        for inp in state.inputs:
            if inp["name"] == name and vol is not None:
                inp["volumeMul"] = float(vol)
        emit_status()
    elif event_type in ("InputCreated", "InputRemoved", "InputNameChanged"):
        try:
            await refresh_inputs()
            emit_status()
        except Exception:
            pass


async def reader_loop(ws):
    async for raw in ws:
        msg = json.loads(raw)
        op = msg.get("op")
        d = msg.get("d", {})
        if op == 7:
            fut = _pending.get(d.get("requestId"))
            if fut and not fut.done():
                fut.set_result(d)
        elif op == 5:
            await handle_event(d.get("eventType"), d.get("eventData", {}) or {})


async def connection_loop():
    global _ws
    backoff = 2
    while True:
        cfg = read_obs_config()
        if not cfg:
            state.connected, state.error = False, "no_config"
            emit_status()
            await asyncio.sleep(backoff)
            continue

        uri = f"ws://127.0.0.1:{cfg['port']}"
        try:
            async with websockets.connect(uri, max_size=None, open_timeout=5) as ws:
                hello = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
                hd = hello.get("d", {})
                state.obs_version = hd.get("obsWebSocketVersion")

                identify = {
                    "op": 1,
                    "d": {
                        "rpcVersion": hd.get("rpcVersion", 1),
                        "eventSubscriptions": EVENT_SUBSCRIPTIONS,
                    },
                }
                auth = hd.get("authentication")
                if auth:
                    if not cfg["password"]:
                        state.connected, state.error = False, "password_required"
                        emit_status()
                        await asyncio.sleep(backoff)
                        continue
                    identify["d"]["authentication"] = make_auth_response(
                        cfg["password"], auth["salt"], auth["challenge"]
                    )
                await ws.send(json.dumps(identify))
                identified = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
                if identified.get("op") != 2:
                    state.connected, state.error = False, "auth_failed"
                    emit_status()
                    await asyncio.sleep(backoff)
                    continue

                _ws = ws
                state.connected, state.error = True, None
                backoff = 2

                reader_task = asyncio.ensure_future(reader_loop(ws))
                try:
                    await full_refresh()
                    await reader_task
                finally:
                    reader_task.cancel()
                    _ws = None
        except Exception as e:
            _ws = None
            state.connected, state.error = False, type(e).__name__
            emit_status()
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 15)


async def dispatch_command(cmd_obj):
    cmd = cmd_obj.get("cmd")
    try:
        if cmd == "refresh":
            await full_refresh()
        elif cmd == "recording_toggle":
            await send_request("ToggleRecord")
        elif cmd == "recording_start":
            await send_request("StartRecord")
        elif cmd == "recording_stop":
            await send_request("StopRecord")
        elif cmd == "recording_pause_toggle":
            await send_request("ToggleRecordPause")
        elif cmd == "streaming_toggle":
            await send_request("ToggleStream")
        elif cmd == "streaming_start":
            await send_request("StartStream")
        elif cmd == "streaming_stop":
            await send_request("StopStream")
        elif cmd == "vcam_toggle":
            await send_request("ToggleVirtualCam")
        elif cmd == "replay_toggle":
            await send_request("ToggleReplayBuffer")
        elif cmd == "replay_save":
            await send_request("SaveReplayBuffer")
        elif cmd == "scene_set":
            await send_request("SetCurrentProgramScene", {"sceneName": cmd_obj["scene"]})
        elif cmd == "input_mute_toggle":
            await send_request("ToggleInputMute", {"inputName": cmd_obj["input"]})
        elif cmd == "input_set_volume":
            await send_request(
                "SetInputVolume",
                {"inputName": cmd_obj["input"], "inputVolumeMul": cmd_obj["volumeMul"]},
            )
    except Exception as e:
        emit({"transientError": str(e)})


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
    await loop.connect_read_pipe(StdinProtocol, sys.stdin)
    await connection_loop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
