#!/usr/bin/env python3
"""Persistent, model-resident Surya OCR server for local warm combined OCR.

Loads the Surya detection + recognition (math-aware) predictors once and reuses
them across requests, so repeat captures pay only inference time instead of the
~6-8s model reload every `surya_ocr` invocation costs. Models are loaded lazily
on the first request and unloaded again after an idle period to release RAM.

Protocol (mirrors the Sauron ocr-api so the ocr-combined client is backend-agnostic):
  GET  /health         -> {"status":"ok","models_loaded":bool}
  POST /ocr/combined   raw PNG body -> {"status":"ok","text":..,"raw_output":..}

Configuration (environment):
  SURYA_SERVER_HOST           default 127.0.0.1
  SURYA_SERVER_PORT           default 8012
  SURYA_SERVER_IDLE_TIMEOUT   seconds of inactivity before models unload (default 600; 0 = never)
  SURYA_SERVER_THREADS        torch CPU threads (default 6 -- the measured sweet spot on this APU)
"""

import io
import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = os.environ.get("SURYA_SERVER_HOST", "127.0.0.1")
PORT = int(os.environ.get("SURYA_SERVER_PORT", "8012"))
IDLE_TIMEOUT = int(os.environ.get("SURYA_SERVER_IDLE_TIMEOUT", "600"))
THREADS = int(os.environ.get("SURYA_SERVER_THREADS", "6"))
MAX_BYTES = int(os.environ.get("SURYA_SERVER_MAX_BYTES", str(64 * 1024 * 1024)))

# torch is memory-bandwidth-bound on this integrated-GPU APU: more threads is
# slower (16 threads ~= 2x slower than 6). Pin before any predictor loads.
os.environ.setdefault("TORCH_DEVICE", "cpu")
os.environ.setdefault("OMP_NUM_THREADS", str(THREADS))


def log(*a):
    print("[surya-server]", *a, file=sys.stderr, flush=True)


class Engine:
    """Holds the Surya predictors; loads lazily, unloads when idle."""

    def __init__(self):
        self._lock = threading.Lock()  # serialize load/unload/predict (models are not reentrant)
        self._foundation = None
        self._recognition = None
        self._detection = None
        self._last_active = time.time()

    def _load_locked(self):
        if self._recognition is not None:
            return
        import torch
        torch.set_num_threads(THREADS)
        t = time.time()
        log(f"loading predictors (threads={THREADS}) ...")
        from surya.foundation import FoundationPredictor
        from surya.recognition import RecognitionPredictor
        from surya.detection import DetectionPredictor
        self._foundation = FoundationPredictor()
        self._recognition = RecognitionPredictor(self._foundation)
        self._detection = DetectionPredictor()
        log(f"predictors loaded in {time.time() - t:.1f}s")

    def unload_if_idle(self):
        with self._lock:
            if self._recognition is None:
                return
            if IDLE_TIMEOUT <= 0:
                return
            if time.time() - self._last_active < IDLE_TIMEOUT:
                return
            log(f"idle > {IDLE_TIMEOUT}s; unloading predictors to free RAM")
            self._foundation = self._recognition = self._detection = None
            try:
                import gc
                gc.collect()
            except Exception:
                pass

    @property
    def models_loaded(self):
        return self._recognition is not None

    def ocr(self, png_bytes):
        from PIL import Image, ImageOps
        import numpy as np
        image = Image.open(io.BytesIO(png_bytes)).convert("RGB")
        arr = np.array(image)
        mean_val = float(np.mean(arr))
        if mean_val < 115.0:
            log(f"dark background detected (mean={mean_val:.1f} < 115); inverting colors before OCR")
            image = ImageOps.invert(image)
        with self._lock:
            self._load_locked()
            self._last_active = time.time()
            result = self._recognition([image], det_predictor=self._detection)[0]
            self._last_active = time.time()

        lines = [getattr(l, "text", "") or "" for l in getattr(result, "text_lines", [])]
        text = normalize_markup("\n".join(l for l in lines if l))
        # Same shape the surya_ocr CLI writes to results.json, so the client's
        # existing normalizer treats warm output identically to cold local output.
        raw_output = {
            "input": [
                {
                    "text_lines": [
                        {
                            "text": getattr(l, "text", "") or "",
                            "bbox": getattr(l, "bbox", None),
                            "confidence": getattr(l, "confidence", None),
                        }
                        for l in getattr(result, "text_lines", [])
                    ],
                    "image_bbox": getattr(result, "image_bbox", None),
                }
            ]
        }
        return text, raw_output


def normalize_markup(s):
    """Mirror ocr-combined.sh's normalize_combined_markup (math tags, entities)."""
    import re
    s = re.sub(r"<math[^>]*>", "$", s)
    s = s.replace("</math>", "$")
    s = re.sub(r"<p[^>]*>", "", s)
    s = s.replace("</p>", "\n\n")
    s = re.sub(r"<br\s*/?>", "\n", s)
    s = s.replace("&nbsp;", " ")
    s = s.replace("&amp;", "\\&")
    s = s.replace("&lt;", "<").replace("&gt;", ">")
    return s.strip()


ENGINE = Engine()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):  # quiet default access logging; we log meaningfully ourselves
        pass

    def do_GET(self):
        if self.path.rstrip("/") == "/health":
            self._send(200, {"status": "ok", "models_loaded": ENGINE.models_loaded})
        else:
            self._send(404, {"status": "error", "error": "not found"})

    def do_POST(self):
        if self.path.rstrip("/") != "/ocr/combined":
            self._send(404, {"status": "error", "error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BYTES:
            self._send(400, {"status": "error", "error": "missing or oversized body"})
            return
        png = self.rfile.read(length)
        t = time.time()
        try:
            text, raw_output = ENGINE.ocr(png)
        except Exception as e:  # keep the daemon alive across bad requests
            import traceback
            log("OCR failed:", traceback.format_exc())
            self._send(500, {"status": "error", "error": str(e)})
            return
        log(f"ocr ok in {time.time() - t:.1f}s ({len(text)} chars)")
        self._send(200, {"status": "ok", "text": text, "raw_output": raw_output})


def idle_monitor():
    interval = 30
    while True:
        time.sleep(interval)
        try:
            ENGINE.unload_if_idle()
        except Exception as e:
            log("idle monitor error:", e)


def main():
    threading.Thread(target=idle_monitor, daemon=True).start()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    log(f"listening on http://{HOST}:{PORT} (idle_timeout={IDLE_TIMEOUT}s, threads={THREADS})")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
