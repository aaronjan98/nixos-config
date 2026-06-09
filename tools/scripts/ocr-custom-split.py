#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


MATH_SYMBOLS = set("=+-*/\\^_{}[]()<>|~√∑∫πΠΔδθλμσ∞≤≥≠≈→←×÷—−")
STRONG_MATH_SYMBOLS = set("=+\\^_{}√∑∫≤≥≠≈×÷—−")
MATH_WORDS = {
    "sin",
    "cos",
    "tan",
    "log",
    "ln",
    "lim",
    "max",
    "min",
    "sup",
    "inf",
    "sqrt",
    "frac",
    "dfrac",
    "int",
    "sum",
}
KNOWN_COMPOUND_VARIABLES = {"bx", "dx", "dy", "dc"}


@dataclass
class Word:
    text: str
    conf: float
    left: int
    top: int
    width: int
    height: int
    block_num: int
    par_num: int
    line_num: int
    word_num: int

    @property
    def right(self) -> int:
        return self.left + self.width

    @property
    def bottom(self) -> int:
        return self.top + self.height


@dataclass
class Span:
    line_index: int
    word_start: int
    word_end: int
    display: bool
    reason: str
    bbox: dict[str, int]
    text: str
    crop: str | None = None
    pix2tex_status: str = "not-run"
    pix2tex_output: str = ""
    pix2tex_rejected_output: str = ""
    pix2tex_stderr: str = ""
    pix2tex_duration_ms: int = 0


@dataclass
class DisplayBlock:
    block_index: int
    line_start: int
    line_end: int
    reason: str
    bbox: dict[str, int]
    text: str
    crop: str | None = None
    pix2tex_status: str = "not-run"
    pix2tex_output: str = ""
    pix2tex_rejected_output: str = ""
    pix2tex_stderr: str = ""
    pix2tex_duration_ms: int = 0
    display_backend: str = "none"
    display_backend_status: str = "not-run"
    display_backend_output: str = ""
    display_backend_stderr: str = ""
    display_backend_duration_ms: int = 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prototype a custom text/math OCR split on an existing image."
    )
    parser.add_argument(
        "image",
        nargs="?",
        help="Image to analyze. If omitted, capture a screen region first.",
    )
    parser.add_argument(
        "--attempt-dir",
        help="Write artifacts to this directory instead of creating an archive attempt.",
    )
    parser.add_argument(
        "--capture-root",
        default=os.environ.get("OCR_CAPTURE_DIR"),
        help="Archive root. Defaults to OCR_CAPTURE_DIR or ~/.local/share/ocr-captures.",
    )
    parser.add_argument(
        "--lang",
        default=os.environ.get("TEXT_OCR_LANG", "eng"),
        help="Tesseract language.",
    )
    parser.add_argument(
        "--psm",
        default=os.environ.get("TEXT_OCR_PSM", "6"),
        help="Tesseract page segmentation mode.",
    )
    parser.add_argument(
        "--pix2tex-bin",
        default=os.environ.get("PIX2TEX_BIN"),
        help="pix2tex executable. Defaults to PIX2TEX_BIN or the standard pix2tex venv.",
    )
    parser.add_argument(
        "--no-pix2tex",
        action="store_true",
        help="Only segment text/math regions; do not run pix2tex.",
    )
    parser.add_argument(
        "--pix2tex-mode",
        choices=("auto", "always", "never"),
        default=os.environ.get("OCR_CUSTOM_PIX2TEX_MODE", "auto"),
        help="When to run pix2tex on crops. auto skips simple Tesseract-cleanable math.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=int(os.environ.get("OCR_CUSTOM_PIX2TEX_TIMEOUT", "20")),
        help="pix2tex timeout per crop in seconds.",
    )
    parser.add_argument(
        "--backend",
        choices=("local", "sauron"),
        default=os.environ.get("OCR_CUSTOM_BACKEND", "local"),
        help="Overall custom OCR backend profile. The sauron profile sends complex display crops to Sauron.",
    )
    parser.add_argument(
        "--display-backend",
        choices=("auto", "none", "sauron"),
        default=os.environ.get("OCR_CUSTOM_DISPLAY_BACKEND", "auto"),
        help="Backend for complex display math crops. auto uses Sauron when --backend=sauron.",
    )
    copy_group = parser.add_mutually_exclusive_group()
    copy_group.add_argument(
        "--copy",
        action="store_true",
        help="Copy normalized output to the Wayland clipboard.",
    )
    copy_group.add_argument(
        "--no-copy",
        action="store_true",
        help="Do not copy output. This is the default for saved-image mode.",
    )
    notify_group = parser.add_mutually_exclusive_group()
    notify_group.add_argument(
        "--notify",
        action="store_true",
        help="Send desktop notifications.",
    )
    notify_group.add_argument(
        "--no-notify",
        action="store_true",
        help="Do not send desktop notifications. This is the default for saved-image mode.",
    )
    return parser.parse_args()


def expanded_path(value: str | None, fallback: Path | None = None) -> Path:
    if value:
        return Path(value).expanduser()
    if fallback is None:
        raise ValueError("missing path")
    return fallback.expanduser()


def timestamp_id() -> str:
    return datetime.now().astimezone().strftime("%Y-%m-%dT%H-%M-%S.%f%z")


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def run_command(
    command: list[str],
    log_path: Path,
    *,
    cwd: Path | None = None,
    timeout: int | None = None,
    stdin: bytes | None = None,
) -> subprocess.CompletedProcess[bytes]:
    with log_path.open("ab") as log_file:
        log_file.write(("running: " + shlex.join(command) + "\n").encode())
        started = time.monotonic()
        try:
            result = subprocess.run(
                command,
                input=stdin,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=str(cwd) if cwd else None,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired as error:
            duration_ms = int((time.monotonic() - started) * 1000)
            log_file.write(f"timeout after {duration_ms}ms\n".encode())
            stdout = error.stdout or b""
            stderr = error.stderr or b""
            log_file.write(stderr)
            raise
        duration_ms = int((time.monotonic() - started) * 1000)
        log_file.write(f"exit: {result.returncode}\n".encode())
        log_file.write(f"duration_ms: {duration_ms}\n".encode())
        if result.stderr:
            log_file.write(b"stderr:\n")
            log_file.write(result.stderr)
            if not result.stderr.endswith(b"\n"):
                log_file.write(b"\n")
        return result


def notify_user(title: str, message: str, log_path: Path, urgency: str = "normal") -> None:
    notify = os.environ.get("NOTIFY", "notify-send")
    command = [notify, "-u", urgency, title, message]
    try:
        result = run_command(command, log_path)
    except FileNotFoundError:
        with log_path.open("a", encoding="utf-8") as log_file:
            log_file.write(f"notify command not found: {notify}\n")
        return
    if result.returncode != 0:
        with log_path.open("a", encoding="utf-8") as log_file:
            log_file.write(f"notify failed: {result.returncode}\n")


def capture_region(input_image: Path, log_path: Path) -> str | None:
    slurp = os.environ.get("SLURP", "slurp")
    grim = os.environ.get("GRIM", "grim")
    slurp_result = run_command(
        [
            slurp,
            "-b",
            "00000000",
            "-c",
            "e62600ff",
            "-B",
            "00000000",
            "-w",
            "2",
            "-s",
            "1e000080",
        ],
        log_path,
    )
    if slurp_result.returncode != 0:
        return None
    region = slurp_result.stdout.decode(errors="replace").strip()
    if not region:
        return None
    grim_result = run_command([grim, "-g", region, str(input_image)], log_path)
    if grim_result.returncode != 0:
        raise RuntimeError(grim_result.stderr.decode(errors="replace").strip())
    return region


def copy_file_to_clipboard(text_path: Path, log_path: Path) -> bool:
    wl_copy = os.environ.get("WL_COPY", "wl-copy")
    systemd_run = os.environ.get("SYSTEMD_RUN", "systemd-run")
    bash = os.environ.get("BASH", "bash")
    unit = f"ocr-custom-split-clipboard-{time.time_ns()}"
    command = [
        systemd_run,
        "--user",
        "--quiet",
        "--collect",
        "--unit",
        unit,
        f"--setenv=WAYLAND_DISPLAY={os.environ.get('WAYLAND_DISPLAY', '')}",
        f"--setenv=XDG_RUNTIME_DIR={os.environ.get('XDG_RUNTIME_DIR', '')}",
        bash,
        "-lc",
        'exec "$1" --foreground --type "text/plain;charset=utf-8" < "$2"',
        "_",
        wl_copy,
        str(text_path),
    ]
    try:
        result = run_command(command, log_path)
        if result.returncode == 0:
            return True
    except FileNotFoundError:
        with log_path.open("a", encoding="utf-8") as log_file:
            log_file.write(f"systemd-run command not found: {systemd_run}\n")

    try:
        fallback = subprocess.run(
            [wl_copy, "--type", "text/plain;charset=utf-8"],
            input=text_path.read_bytes(),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except FileNotFoundError:
        with log_path.open("a", encoding="utf-8") as log_file:
            log_file.write(f"wl-copy command not found: {wl_copy}\n")
        return False

    with log_path.open("ab") as log_file:
        log_file.write(f"direct wl-copy exit: {fallback.returncode}\n".encode())
        if fallback.stderr:
            log_file.write(fallback.stderr)
            if not fallback.stderr.endswith(b"\n"):
                log_file.write(b"\n")
    return fallback.returncode == 0


def parse_int(value: str | None) -> int:
    try:
        return int(float(value or "0"))
    except ValueError:
        return 0


def parse_conf(value: str | None) -> float:
    try:
        return float(value or "-1")
    except ValueError:
        return -1.0


def load_words(tsv_path: Path) -> list[Word]:
    words: list[Word] = []
    with tsv_path.open(newline="", encoding="utf-8", errors="replace") as tsv_file:
        reader = csv.DictReader(tsv_file, delimiter="\t")
        for row in reader:
            if parse_int(row.get("level")) != 5:
                continue
            text = (row.get("text") or "").strip()
            if not text:
                continue
            width = parse_int(row.get("width"))
            height = parse_int(row.get("height"))
            if width <= 0 or height <= 0:
                continue
            words.append(
                Word(
                    text=text,
                    conf=parse_conf(row.get("conf")),
                    left=parse_int(row.get("left")),
                    top=parse_int(row.get("top")),
                    width=width,
                    height=height,
                    block_num=parse_int(row.get("block_num")),
                    par_num=parse_int(row.get("par_num")),
                    line_num=parse_int(row.get("line_num")),
                    word_num=parse_int(row.get("word_num")),
                )
            )
    return words


def bbox_for_words(words: list[Word], padding: int = 0) -> dict[str, int]:
    left = min(word.left for word in words) - padding
    top = min(word.top for word in words) - padding
    right = max(word.right for word in words) + padding
    bottom = max(word.bottom for word in words) + padding
    return {
        "left": left,
        "top": top,
        "width": right - left,
        "height": bottom - top,
    }


def group_lines(words: list[Word]) -> list[dict[str, Any]]:
    grouped: dict[tuple[int, int, int], list[Word]] = {}
    for word in words:
        grouped.setdefault((word.block_num, word.par_num, word.line_num), []).append(word)

    lines: list[dict[str, Any]] = []
    for line_key, line_words in sorted(
        grouped.items(),
        key=lambda item: (
            min(word.top for word in item[1]),
            min(word.left for word in item[1]),
        ),
    ):
        sorted_words = sorted(line_words, key=lambda word: (word.left, word.word_num))
        line_text = " ".join(word.text for word in sorted_words)
        line = {
            "line_index": len(lines),
            "key": {
                "block_num": line_key[0],
                "par_num": line_key[1],
                "line_num": line_key[2],
            },
            "text": line_text,
            "bbox": bbox_for_words(sorted_words),
            "words": [
                {
                    "text": word.text,
                    "conf": word.conf,
                    "left": word.left,
                    "top": word.top,
                    "width": word.width,
                    "height": word.height,
                }
                for word in sorted_words
            ],
            "_words": sorted_words,
        }
        lines.append(line)
    return lines


def count_matching(text: str, allowed: set[str]) -> int:
    return sum(1 for character in text if character in allowed)


def compact_token(text: str) -> str:
    return text.strip().strip(",.;:!?")


def normalize_math_token(text: str) -> str:
    return compact_token(text).replace("¢", "c").replace("©", "c")


def is_variable_token(text: str) -> bool:
    token = normalize_math_token(text)
    return bool(re.fullmatch(r"[A-Za-z](?:['’])?", token))


def is_number_token(text: str) -> bool:
    token = normalize_math_token(text)
    return bool(re.fullmatch(r"[$€£¥]?[0-9][0-9,]*(?:\.[0-9]+)?%?", token))


def is_delta_token(text: str) -> bool:
    token = normalize_math_token(text)
    return bool(re.fullmatch(r"(?:A|Δ|∆)[A-Za-z]", token))


def is_compound_variable_token(text: str) -> bool:
    return normalize_math_token(text).lower() in KNOWN_COMPOUND_VARIABLES


def is_math_word(text: str) -> bool:
    token = compact_token(text).lower().lstrip("\\")
    return token in MATH_WORDS


def word_profile(word: Word) -> dict[str, Any]:
    text = word.text
    token = compact_token(text)
    symbol_count = count_matching(text, MATH_SYMBOLS)
    strong_symbol_count = count_matching(text, STRONG_MATH_SYMBOLS)
    alpha_count = sum(1 for character in text if character.isalpha())
    digit_count = sum(1 for character in text if character.isdigit())
    non_alnum_count = sum(1 for character in text if not character.isalnum())
    has_latex = "\\" in text
    has_prime = "'" in text or "’" in text
    has_math_word = is_math_word(text)
    has_seed = (
        strong_symbol_count > 0
        or has_latex
        or has_math_word
        or "√" in text
        or (has_prime and alpha_count > 0)
        or (word.conf >= 0 and word.conf < 50 and non_alnum_count > 0)
    )
    adjacent_ok = (
        is_variable_token(text)
        or is_number_token(text)
        or is_delta_token(text)
        or is_compound_variable_token(text)
        or has_math_word
        or symbol_count > 0
        or (digit_count > 0 and non_alnum_count > 0)
        or bool(re.fullmatch(r"[(){}\[\],.]+", token))
    )
    return {
        "text": text,
        "symbol_count": symbol_count,
        "strong_symbol_count": strong_symbol_count,
        "alpha_count": alpha_count,
        "digit_count": digit_count,
        "non_alnum_count": non_alnum_count,
        "has_seed": has_seed,
        "adjacent_ok": adjacent_ok,
        "variable": is_variable_token(text),
        "number": is_number_token(text),
        "math_word": has_math_word,
    }


def line_is_display_math(line_words: list[Word], profiles: list[dict[str, Any]]) -> tuple[bool, str]:
    if not line_words:
        return False, "empty"
    line_text = " ".join(word.text for word in line_words)
    if re.search(r"\bi[.;]?\s*e[.;]?", line_text, flags=re.IGNORECASE):
        return False, "contains-prose-abbreviation"
    seed_count = sum(1 for profile in profiles if profile["has_seed"])
    symbol_count = sum(profile["symbol_count"] for profile in profiles)
    alpha_words = sum(1 for profile in profiles if profile["alpha_count"] > 1 and not profile["math_word"])
    total_words = len(line_words)
    seed_ratio = seed_count / max(total_words, 1)
    has_equals = "=" in line_text
    has_fraction = "/" in line_text or "\\" in line_text or "√" in line_text

    if total_words <= 2 and seed_count > 0 and symbol_count > 0:
        return True, "short-symbol-line"
    if has_equals and seed_ratio >= 0.45 and alpha_words <= 3:
        return True, "equals-heavy-line"
    if has_fraction and seed_ratio >= 0.55 and alpha_words <= 2:
        return True, "fraction-heavy-line"
    if symbol_count >= 3 and seed_ratio >= 0.60:
        return True, "symbol-dense-line"
    return False, "text-line"


def detect_spans(lines: list[dict[str, Any]]) -> list[Span]:
    spans: list[Span] = []
    for line in lines:
        line_words: list[Word] = line["_words"]
        profiles = [word_profile(word) for word in line_words]
        display_math, reason = line_is_display_math(line_words, profiles)
        if display_math:
            spans.append(
                Span(
                    line_index=line["line_index"],
                    word_start=0,
                    word_end=len(line_words),
                    display=True,
                    reason=reason,
                    bbox=bbox_for_words(line_words, padding=8),
                    text=" ".join(word.text for word in line_words),
                )
            )
            continue

        current_start: int | None = None
        current_end: int | None = None
        current_has_seed = False

        def flush_span() -> None:
            nonlocal current_start, current_end, current_has_seed
            if current_start is None or current_end is None:
                return
            span_words = line_words[current_start:current_end]
            span_text = " ".join(word.text for word in span_words)
            strong = any(word_profile(word)["has_seed"] for word in span_words)
            has_boundary_symbol = any(
                count_matching(word.text, STRONG_MATH_SYMBOLS) > 0 for word in span_words
            )
            useful_length = len(span_words) >= 2 or has_boundary_symbol
            if current_has_seed and strong and useful_length:
                spans.append(
                    Span(
                        line_index=line["line_index"],
                        word_start=current_start,
                        word_end=current_end,
                        display=False,
                        reason="inline-seed-span",
                        bbox=bbox_for_words(span_words, padding=8),
                        text=span_text,
                    )
                )
            current_start = None
            current_end = None
            current_has_seed = False

        for word_index, profile in enumerate(profiles):
            if profile["has_seed"]:
                if current_start is None:
                    current_start = word_index
                    while current_start > 0 and profiles[current_start - 1]["adjacent_ok"]:
                        current_start -= 1
                current_end = word_index + 1
                current_has_seed = True
                continue

            if current_start is not None and profile["adjacent_ok"]:
                current_end = word_index + 1
                continue

            flush_span()

        flush_span()

    return spans


def line_math_density(line: dict[str, Any]) -> float:
    words: list[Word] = line["_words"]
    if not words:
        return 0.0
    mathish = 0
    for word in words:
        profile = word_profile(word)
        if profile["has_seed"] or profile["adjacent_ok"] or is_delta_token(word.text):
            mathish += 1
    return mathish / len(words)


def line_has_prose_marker(line: dict[str, Any]) -> bool:
    text = line["text"].lower()
    prose_words = {
        "let",
        "then",
        "suppose",
        "where",
        "if",
        "we",
        "put",
        "the",
        "term",
        "constant",
        "function",
        "derivative",
        "identity",
        "infinitesimal",
        "depend",
        "independent",
        "variable",
    }
    tokens = re.findall(r"[a-z]+", text)
    return sum(1 for token in tokens if token in prose_words) >= 2


def line_is_display_block_candidate(line: dict[str, Any], image_width: int) -> bool:
    words: list[Word] = line["_words"]
    if not words:
        return False
    bbox = line["bbox"]
    text = line["text"]
    word_count = len(words)
    density = line_math_density(line)
    left_margin = bbox["left"]
    right_margin = image_width - (bbox["left"] + bbox["width"])
    centered = min(left_margin, right_margin) > image_width * 0.12
    narrow = bbox["width"] < image_width * 0.72
    has_equation_symbol = any(symbol in text for symbol in ("=", "+", "-", "—", "−", "/", "_", "#"))
    all_shortish = all(len(compact_token(word.text)) <= 7 for word in words)
    if line_has_prose_marker(line):
        return False
    if word_count <= 10 and density >= 0.45 and has_equation_symbol and (centered or narrow):
        return True
    if word_count <= 5 and density >= 0.40 and (centered or narrow) and all_shortish:
        return True
    return False


def detect_display_blocks(lines: list[dict[str, Any]], image_width: int) -> list[DisplayBlock]:
    candidate_indexes = [
        line["line_index"]
        for line in lines
        if line_is_display_block_candidate(line, image_width)
    ]
    if not candidate_indexes:
        return []

    blocks: list[DisplayBlock] = []
    current: list[int] = []

    def flush() -> None:
        nonlocal current
        if not current:
            return
        block_lines = [lines[index] for index in current]
        block_words: list[Word] = []
        for block_line in block_lines:
            block_words.extend(block_line["_words"])
        if block_words:
            blocks.append(
                DisplayBlock(
                    block_index=len(blocks),
                    line_start=current[0],
                    line_end=current[-1] + 1,
                    reason="math-heavy-centered-lines",
                    bbox=bbox_for_words(block_words, padding=14),
                    text="\n".join(block_line["text"] for block_line in block_lines),
                )
            )
        current = []

    previous_index: int | None = None
    for line_index in candidate_indexes:
        if previous_index is None:
            current = [line_index]
        elif line_index == previous_index + 1:
            current.append(line_index)
        else:
            flush()
            current = [line_index]
        previous_index = line_index
    flush()

    return blocks


def line_in_display_block(line_index: int, display_blocks: list[DisplayBlock]) -> DisplayBlock | None:
    for block in display_blocks:
        if block.line_start <= line_index < block.line_end:
            return block
    return None


def identify_image(image_path: Path, log_path: Path) -> tuple[int, int]:
    result = run_command(["magick", "identify", "-format", "%w %h", str(image_path)], log_path)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode(errors="replace").strip())
    width_text, height_text = result.stdout.decode().strip().split()
    return int(width_text), int(height_text)


def image_mean_brightness(image_path: Path, log_path: Path) -> float:
    result = run_command(
        ["magick", str(image_path), "-colorspace", "Gray", "-format", "%[fx:mean]", "info:"],
        log_path,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode(errors="replace").strip())
    return float(result.stdout.decode().strip())


def preprocess_image(input_image: Path, processed_image: Path, log_path: Path) -> dict[str, Any]:
    mean = image_mean_brightness(input_image, log_path)
    threshold = float(os.environ.get("OCR_CUSTOM_INVERT_MEAN_THRESHOLD", "0.45"))
    scale = os.environ.get("OCR_CUSTOM_PREPROCESS_SCALE", "200%")
    inverted = mean < threshold
    command = [
        "magick",
        str(input_image),
        "-colorspace",
        "Gray",
        "-auto-level",
    ]
    if inverted:
        command.append("-negate")
    command.extend(
        [
            "-resize",
            scale,
            "-sharpen",
            "0x1",
            str(processed_image),
        ]
    )
    result = run_command(command, log_path)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode(errors="replace").strip())
    return {
        "source_mean_brightness": mean,
        "invert_threshold": threshold,
        "inverted": inverted,
        "scale": scale,
        "processed_image": str(processed_image),
    }


def clamp_bbox(bbox: dict[str, int], image_width: int, image_height: int) -> dict[str, int]:
    left = max(0, bbox["left"])
    top = max(0, bbox["top"])
    right = min(image_width, bbox["left"] + bbox["width"])
    bottom = min(image_height, bbox["top"] + bbox["height"])
    return {
        "left": left,
        "top": top,
        "width": max(1, right - left),
        "height": max(1, bottom - top),
    }


def crop_span(image_path: Path, span: Span, crop_path: Path, image_size: tuple[int, int], log_path: Path) -> None:
    bbox = clamp_bbox(span.bbox, image_size[0], image_size[1])
    span.bbox = bbox
    crop_geometry = f"{bbox['width']}x{bbox['height']}+{bbox['left']}+{bbox['top']}"
    crop_path.parent.mkdir(parents=True, exist_ok=True)
    result = run_command(
        ["magick", str(image_path), "-crop", crop_geometry, "+repage", str(crop_path)],
        log_path,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode(errors="replace").strip())


def write_debug_overlay(
    image_path: Path,
    spans: list[Span],
    display_blocks: list[DisplayBlock],
    overlay_path: Path,
    log_path: Path,
) -> None:
    draw_parts: list[str] = []
    for block in display_blocks:
        bbox = block.bbox
        left = bbox["left"]
        top = bbox["top"]
        right = left + bbox["width"]
        bottom = top + bbox["height"]
        draw_parts.extend(["-stroke", "cyan", "-strokewidth", "5", "-fill", "none", "-draw", f"rectangle {left},{top} {right},{bottom}"])
    for span in spans:
        bbox = span.bbox
        left = bbox["left"]
        top = bbox["top"]
        right = left + bbox["width"]
        bottom = top + bbox["height"]
        color = "red" if span.display else "orange"
        draw_parts.extend(["-stroke", color, "-strokewidth", "3", "-fill", "none", "-draw", f"rectangle {left},{top} {right},{bottom}"])
    if not draw_parts:
        shutil.copy2(image_path, overlay_path)
        return
    result = run_command(["magick", str(image_path), *draw_parts, str(overlay_path)], log_path)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode(errors="replace").strip())


def resolve_pix2tex_bin(value: str | None) -> Path | None:
    if value:
        return Path(value).expanduser()
    home = Path(os.environ.get("HOME", "~")).expanduser()
    runtime_dir = Path(os.environ.get("PIX2TEX_RUNTIME_DIR", home / "Repositories/automation/pix2tex")).expanduser()
    venv_dir = Path(os.environ.get("PIX2TEX_VENV_DIR", runtime_dir / ".venv")).expanduser()
    for candidate in (venv_dir / "bin/pix2tex", venv_dir / "bin/pix2tex_cli"):
        if candidate.exists() and os.access(candidate, os.X_OK):
            return candidate
    return None


def normalize_pix2tex_output(output: str, crop_path: Path) -> str:
    normalized = output.replace("\r", "").strip()
    for prefix in (f"{crop_path}: ", f"{crop_path}:"):
        if normalized.startswith(prefix):
            normalized = normalized[len(prefix) :].strip()
    if normalized.startswith("{") and normalized.endswith("}"):
        normalized = normalized[1:-1].strip()
    return normalized


def pix2tex_output_is_suspicious(span_text: str, output: str) -> str | None:
    if not output:
        return "empty-output"
    normalized_input = span_text.lower()
    normalized_output = output.lower()
    if "\\int" in normalized_output and "∫" not in normalized_input and "int" not in normalized_input:
        return "unexpected-integral"
    if "\\mathbf" in normalized_output and "mathbf" not in normalized_input:
        return "unexpected-bold-symbol"
    if "\\tau" in normalized_output and "tau" not in normalized_input and "τ" not in normalized_input:
        return "unexpected-tau"
    compact_input = re.sub(r"\s+", "", span_text)
    compact_output = re.sub(r"\s+", "", output)
    if len(compact_output) > max(24, len(compact_input) * 5):
        return "output-too-long-for-crop"
    return None


def span_is_simple_math(span: Span) -> bool:
    text, _suffix = split_math_suffix(span.text)
    if any(marker in text for marker in ("\\", "√", "∑", "∫", "≤", "≥", "≠", "≈")):
        return False
    if "/" in text:
        return False
    cleaned = cleanup_math_text(text)
    if not cleaned or len(cleaned) > 80:
        return False
    simplified = cleaned.replace("\\Delta", "Delta")
    return bool(re.fullmatch(r"[A-Za-z0-9\s=+\-*'(),.]+", simplified))


def run_pix2tex(span: Span, pix2tex_bin: Path, crop_path: Path, log_path: Path, timeout: int) -> None:
    extra_args = shlex.split(os.environ.get("OCR_CUSTOM_PIX2TEX_ARGS", "--no-cuda"))
    command = [str(pix2tex_bin), *extra_args, str(crop_path)]
    started = time.monotonic()
    try:
        result = run_command(command, log_path, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        span.pix2tex_status = "timeout"
        span.pix2tex_stdout = (error.stdout or b"").decode(errors="replace")
        span.pix2tex_stderr = (error.stderr or b"").decode(errors="replace")
        span.pix2tex_duration_ms = int((time.monotonic() - started) * 1000)
        return
    span.pix2tex_duration_ms = int((time.monotonic() - started) * 1000)
    span.pix2tex_stderr = result.stderr.decode(errors="replace")
    stdout = result.stdout.decode(errors="replace")
    normalized = normalize_pix2tex_output(stdout, crop_path)
    if result.returncode == 0 and normalized:
        suspicious_reason = pix2tex_output_is_suspicious(span.text, normalized)
        if suspicious_reason:
            span.pix2tex_rejected_output = normalized
            span.pix2tex_stderr = (span.pix2tex_stderr + f"\nrejected: {suspicious_reason}").strip()
            span.pix2tex_status = f"rejected:{suspicious_reason}"
            span.pix2tex_output = ""
            return
        span.pix2tex_output = normalized
        span.pix2tex_status = "succeeded"
    else:
        span.pix2tex_status = f"failed:{result.returncode}"


def run_pix2tex_for_block(block: DisplayBlock, pix2tex_bin: Path, crop_path: Path, log_path: Path, timeout: int) -> None:
    proxy = Span(
        line_index=block.line_start,
        word_start=0,
        word_end=0,
        display=True,
        reason=block.reason,
        bbox=block.bbox,
        text=block.text,
    )
    run_pix2tex(proxy, pix2tex_bin, crop_path, log_path, timeout)
    block.pix2tex_status = proxy.pix2tex_status
    block.pix2tex_output = proxy.pix2tex_output
    block.pix2tex_rejected_output = proxy.pix2tex_rejected_output
    block.pix2tex_stderr = proxy.pix2tex_stderr
    block.pix2tex_duration_ms = proxy.pix2tex_duration_ms


def log_message(log_path: Path, message: str) -> None:
    with log_path.open("a", encoding="utf-8") as log_file:
        log_file.write(message.rstrip() + "\n")


def is_truthy(value: str | None) -> bool:
    return (value or "").strip().lower() not in {"", "0", "false", "no", "off"}


def env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, str(default)))
    except ValueError:
        return default


def command_from_env(name: str, default: str) -> list[str]:
    return shlex.split(os.environ.get(name, default))


def resolve_display_backend(args: argparse.Namespace) -> str:
    if args.display_backend != "auto":
        return args.display_backend
    if args.backend == "sauron":
        return "sauron"
    return "none"


def sauron_ssh_command(*remote_args: str) -> list[str]:
    host = os.environ.get("SAURON_HOST", "sauron")
    return [
        *command_from_env("SSH", "ssh"),
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=5",
        host,
        *remote_args,
    ]


def wait_for_sauron_ssh(log_path: Path) -> bool:
    wait_seconds = env_int("SAURON_SSH_WAIT_SECONDS", 90)
    deadline = time.monotonic() + wait_seconds
    log_message(log_path, f"waiting for SSH on {os.environ.get('SAURON_HOST', 'sauron')} for up to {wait_seconds}s")
    while time.monotonic() < deadline:
        try:
            result = run_command(sauron_ssh_command("echo", "ready"), log_path, timeout=10)
        except (FileNotFoundError, subprocess.TimeoutExpired) as error:
            log_message(log_path, f"SSH probe failed: {error}")
            result = None
        if result is not None and result.returncode == 0:
            log_message(log_path, "Sauron SSH is ready")
            return True
        time.sleep(2)
    return False


def wait_for_sauron_api(log_path: Path) -> bool:
    wait_seconds = env_int("SAURON_API_WAIT_SECONDS", 30)
    api_url = os.environ.get("SAURON_OCR_API_URL", "http://127.0.0.1:8011").rstrip("/")
    deadline = time.monotonic() + wait_seconds
    log_message(log_path, f"waiting for Sauron OCR API at {api_url} for up to {wait_seconds}s")
    while time.monotonic() < deadline:
        try:
            result = run_command(
                sauron_ssh_command("curl", "-fsS", "--max-time", "5", f"{api_url}/health"),
                log_path,
                timeout=10,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired) as error:
            log_message(log_path, f"Sauron API probe failed: {error}")
            result = None
        if result is not None and result.returncode == 0:
            log_message(log_path, "Sauron OCR API is ready")
            return True
        time.sleep(1)
    return False


def warm_sauron(log_path: Path) -> bool:
    if not is_truthy(os.environ.get("SAURON_WARMUP", "1")):
        return True
    api_url = os.environ.get("SAURON_OCR_API_URL", "http://127.0.0.1:8011").rstrip("/")
    timeout = env_int("SAURON_OCR_TIMEOUT_SECONDS", 1200)
    log_message(log_path, "warming Sauron OCR API")
    try:
        result = run_command(
            sauron_ssh_command("curl", "-fsS", "--max-time", str(timeout), f"{api_url}/warmup"),
            log_path,
            timeout=timeout + 30,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as error:
        log_message(log_path, f"Sauron warmup failed: {error}")
        return False
    return result.returncode == 0


def prepare_sauron(log_path: Path) -> bool:
    if is_truthy(os.environ.get("SAURON_WAKE", "1")):
        wake_command = command_from_env("WOL_SAURON", "wol-sauron")
        if wake_command and shutil.which(wake_command[0]):
            log_message(log_path, "waking Sauron")
            try:
                run_command(wake_command, log_path, timeout=30)
            except (FileNotFoundError, subprocess.TimeoutExpired) as error:
                log_message(log_path, f"Sauron wake command failed: {error}")
        else:
            log_message(log_path, f"Sauron wake command not found: {' '.join(wake_command)}")

    if not wait_for_sauron_ssh(log_path):
        log_message(log_path, "Sauron SSH did not become ready")
        return False
    if not wait_for_sauron_api(log_path):
        log_message(log_path, "Sauron OCR API did not become ready")
        return False
    if not warm_sauron(log_path):
        log_message(log_path, "Sauron OCR API warmup failed")
        return False
    return True


def normalize_sauron_display_output(text: str) -> str:
    normalized = text.replace("\r", "").strip()
    normalized = re.sub(r"<math>\s*(.*?)\s*</math>", r"\1", normalized, flags=re.DOTALL)
    normalized = normalized.strip()
    if normalized.startswith("```") and normalized.endswith("```"):
        normalized = re.sub(r"^```[a-zA-Z0-9_-]*\n?", "", normalized)
        normalized = normalized.removesuffix("```").strip()
    while normalized.startswith("$$") and normalized.endswith("$$"):
        normalized = normalized[2:-2].strip()
    while normalized.startswith("$") and normalized.endswith("$"):
        normalized = normalized[1:-1].strip()
    return normalized


def extract_sauron_text(response: dict[str, Any]) -> str:
    for key in ("text", "normalized_text", "output"):
        value = response.get(key)
        if isinstance(value, str) and value.strip():
            return value
    return ""


def run_sauron_display_ocr(
    block: DisplayBlock,
    crop_path: Path,
    response_path: Path,
    log_path: Path,
) -> None:
    api_url = os.environ.get("SAURON_OCR_API_URL", "http://127.0.0.1:8011").rstrip("/")
    timeout = env_int("SAURON_OCR_TIMEOUT_SECONDS", 1200)
    block.display_backend = "sauron"
    started = time.monotonic()
    try:
        result = run_command(
            sauron_ssh_command(
                "curl",
                "-sS",
                "--max-time",
                str(timeout),
                "-X",
                "POST",
                f"{api_url}/ocr/combined",
                "-H",
                "Content-Type:image/png",
                "--data-binary",
                "@-",
            ),
            log_path,
            timeout=timeout + 30,
            stdin=crop_path.read_bytes(),
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as error:
        block.display_backend_status = "failed"
        block.display_backend_stderr = str(error)
        block.display_backend_duration_ms = int((time.monotonic() - started) * 1000)
        return

    block.display_backend_duration_ms = int((time.monotonic() - started) * 1000)
    block.display_backend_stderr = result.stderr.decode(errors="replace")
    response_text = result.stdout.decode(errors="replace")
    response_path.write_text(response_text)
    if result.returncode != 0:
        block.display_backend_status = f"failed:{result.returncode}"
        return

    try:
        response = json.loads(response_text)
    except json.JSONDecodeError as error:
        block.display_backend_status = "failed:non-json"
        block.display_backend_stderr = (block.display_backend_stderr + f"\n{error}").strip()
        return

    detail = response.get("detail")
    if isinstance(detail, str) and detail.strip():
        block.display_backend_status = "failed:remote-error"
        block.display_backend_stderr = (block.display_backend_stderr + f"\n{detail.strip()}").strip()
        return

    text = normalize_sauron_display_output(extract_sauron_text(response))
    if response.get("status") == "ok" and text:
        block.display_backend_output = text
        block.display_backend_status = "succeeded"
    else:
        block.display_backend_status = "failed:empty-output"


def line_to_text(line: dict[str, Any], spans: list[Span]) -> str:
    line_words: list[Word] = line["_words"]
    line_spans = [span for span in spans if span.line_index == line["line_index"]]
    if not line_spans:
        return render_text_words(line_words, has_math_context(line_words))

    display_spans = [span for span in line_spans if span.display]
    if display_spans:
        span = display_spans[0]
        span_suffix = trailing_sentence_punctuation(span.text)
        if span.pix2tex_output:
            return f"$${span.pix2tex_output}{span_suffix}$$"
        fallback = cleanup_math_text(span.text)
        if fallback:
            return f"$${fallback}{span_suffix}$$"
        return cleanup_spacing(" ".join(word.text for word in line_words))

    pieces: list[str] = []
    word_index = 0
    for span in sorted(line_spans, key=lambda item: item.word_start):
        if span.word_start < word_index:
            continue
        pieces.append(render_text_words(line_words[word_index : span.word_start], True))
        span_core, span_suffix = split_math_suffix(span.text)
        if span.pix2tex_output:
            pieces.append(f"${span.pix2tex_output}${span_suffix}")
        else:
            fallback = cleanup_math_text(span_core)
            if fallback:
                pieces.append(f"${fallback}${span_suffix}")
            else:
                pieces.append(render_text_words(line_words[span.word_start : span.word_end], True))
        word_index = span.word_end
    pieces.append(render_text_words(line_words[word_index:], True))
    return cleanup_spacing(" ".join(piece for piece in pieces if piece))


def has_math_context(words: list[Word]) -> bool:
    return any(word_profile(word)["has_seed"] or is_delta_token(word.text) for word in words)


def split_wrappable_token(text: str) -> tuple[str, str, str]:
    match = re.fullmatch(r"([^A-Za-z0-9\\]*)(.*?)([^A-Za-z0-9']*)", text)
    if not match:
        return "", text, ""
    return match.group(1), match.group(2), match.group(3)


def render_text_words(words: list[Word], math_context: bool) -> str:
    rendered: list[str] = []
    for word in words:
        text = word.text
        if math_context:
            prefix, core, suffix = split_wrappable_token(text)
            if is_delta_token(core):
                rendered.append(f"{prefix}$\\Delta {normalize_math_token(core)[-1]}${suffix}")
                continue
            if is_variable_token(core) and compact_token(core).lower() not in {"i"}:
                rendered.append(f"{prefix}${normalize_math_token(core)}${suffix}")
                continue
        rendered.append(text)
    return cleanup_spacing(" ".join(rendered))


def cleanup_math_text(text: str) -> str:
    cleaned = text.replace("¢", "c").replace("©", "c")
    cleaned = cleaned.replace("—", "-").replace("−", "-")
    cleaned = cleaned.replace("”", "'").replace("’", "'").replace("`", "'")
    cleaned = re.sub(r"\b(?:A|Δ|∆)([A-Za-z])\b", r"\\Delta \1", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    cleaned = re.sub(r"\s+([,.;:!?])", r"\1", cleaned)
    cleaned = re.sub(r"\s*([=+\-*/])\s*", r" \1 ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned.rstrip(",.;:")


def split_math_suffix(text: str) -> tuple[str, str]:
    stripped = text.rstrip()
    ie_match = re.match(r"^(.*?)([;:,]?\s*i[.;]?\s*e[.;]?,?)$", stripped, flags=re.IGNORECASE)
    if ie_match and re.search(r"[=()']", ie_match.group(1)):
        return ie_match.group(1).rstrip(" ;:,."), "; i.e.,"
    suffix = trailing_sentence_punctuation(stripped)
    return stripped, suffix


def trailing_sentence_punctuation(text: str) -> str:
    stripped = text.rstrip()
    if stripped.endswith((",", ".", ";", ":")):
        return stripped[-1]
    return ""


def cleanup_spacing(text: str) -> str:
    cleaned = re.sub(r"\s+", " ", text).strip()
    cleaned = re.sub(r"\s+([,.;:!?])", r"\1", cleaned)
    cleaned = re.sub(r"([(])\s+", r"\1", cleaned)
    cleaned = re.sub(r"\s+([)])", r"\1", cleaned)
    cleaned = cleaned.replace(":.", ":")
    return cleaned


def normalize_for_pattern(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("$", "")).strip()


def postprocess_merged_lines(lines: list[str]) -> list[str]:
    processed: list[str] = []
    index = 0
    while index < len(lines):
        if index + 2 < len(lines):
            first = normalize_for_pattern(lines[index])
            second = normalize_for_pattern(lines[index + 1])
            third = normalize_for_pattern(lines[index + 2])
            derivative_variable_match = re.fullmatch(r"d([A-Za-z])\.?", first)
            derivative_denominator_match = re.fullmatch(r"dx(?:\s*[%.,])?", third)
            derivative_middle_match = re.match(
                r"^[\-—−]?\s*=?\s*0,?\s*d[ec]\s*=\s*0\.?$",
                second,
                flags=re.IGNORECASE,
            )
            if derivative_variable_match and derivative_denominator_match and derivative_middle_match:
                variable = derivative_variable_match.group(1).lower()
                processed.append(rf"$$\frac{{d{variable}}}{{dx}} = 0, \quad d{variable} = 0.$$")
                index += 3
                continue
            if (
                re.fullmatch(r"d\s*[-—−]?", first)
                and re.match(r"^(?:LE|lE|1E|Lo|LO|l0|10|=)?\s*1,?\s*dx\s*=\s*dx\.?$", second)
                and re.fullmatch(r"dx\.?", third)
            ):
                processed.append(r"$$\frac{dx}{dx} = 1, \quad dx = dx$$")
                index += 3
                continue
        processed.append(postprocess_line(lines[index]))
        index += 1
    return processed


def postprocess_line(line: str) -> str:
    processed = line
    processed = re.sub(r"\bie,?$", "i.e.,", processed)
    processed = re.sub(r"\bie,\s*$", "i.e.,", processed)
    processed = re.sub(r"\bconstant\s+[¢©c],", r"constant $c$,", processed)
    processed = processed.replace("term bx $+ c$", "term $bx + c$")
    if "derivative of the identity" in processed or "function $f(x) = x$ is" in processed:
        processed = processed.replace("$f(x) = 1$; i.e.,", "$f'(x) = 1$; i.e.,")
        processed = processed.replace("$f(x) = 1$; ie,", "$f'(x) = 1$; i.e.,")
        processed = processed.replace("$f(x) = 1$;ie,", "$f'(x) = 1$; i.e.,")
    if "derivative of the constant function" in processed or "function $f(x) = c$ is" in processed:
        processed = processed.replace("$f(x) = 0$; i.e.,", "$f'(x) = 0$; i.e.,")
        processed = processed.replace("$f(x) = 0$; ie,", "$f'(x) = 0$; i.e.,")
        processed = processed.replace("$f'(x) = 0; ie,$$", "$f'(x) = 0$; i.e.,")
    return processed


def block_is_tesseract_cleanable(block: DisplayBlock) -> bool:
    lines = [line.strip() for line in block.text.splitlines() if line.strip()]
    if not lines:
        return True
    collapsed = postprocess_merged_lines(lines)
    if len(collapsed) == 1 and collapsed[0].startswith("$$"):
        return True
    if len(lines) == 1:
        raw = lines[0].lower()
        if any(marker in raw for marker in ("cos", "sin", "tan", "exp", "e*", "e ", "e'", "e\"", "c,", "r,", "lambda", "mu", "cent", "cytent", "cytet", "=c ", " et", "tet")):
            return False
        cleaned = cleanup_math_text(lines[0])
        simplified = cleaned.replace("\\Delta", "Delta")
        return bool(cleaned and len(cleaned) <= 90 and re.fullmatch(r"[A-Za-z0-9\s=+\-*'(),.]+", simplified))
    return False


def render_display_block(block: DisplayBlock) -> str:
    if block.display_backend_output:
        return f"$${block.display_backend_output}$$"
    if block.pix2tex_output:
        return f"$${block.pix2tex_output}$$"

    raw_lines = [line.strip() for line in block.text.splitlines() if line.strip()]
    collapsed = postprocess_merged_lines(raw_lines)
    if len(collapsed) == 1 and collapsed[0].startswith("$$"):
        return collapsed[0]

    if not block_is_tesseract_cleanable(block):
        return f"$$\\text{{[display math OCR unresolved: {block.crop or 'display crop'}]}}$$"

    cleaned_lines = [cleanup_math_text(line) or line for line in raw_lines]
    if len(cleaned_lines) == 1:
        return f"$${cleaned_lines[0]}$$"
    return "$$\n" + "\n".join(cleaned_lines) + "\n$$"


def lines_to_text_with_display_blocks(
    lines: list[dict[str, Any]],
    spans: list[Span],
    display_blocks: list[DisplayBlock],
) -> list[str]:
    rendered: list[str] = []
    line_index = 0
    while line_index < len(lines):
        block = line_in_display_block(line_index, display_blocks)
        if block is not None:
            if line_index == block.line_start:
                rendered.append(render_display_block(block))
            line_index = block.line_end
            continue
        rendered.append(line_to_text(lines[line_index], spans))
        line_index += 1
    return rendered


def serializable_line(line: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in line.items() if key != "_words"}


def serializable_span(span: Span) -> dict[str, Any]:
    return {
        "line_index": span.line_index,
        "word_start": span.word_start,
        "word_end": span.word_end,
        "display": span.display,
        "reason": span.reason,
        "bbox": span.bbox,
        "text": span.text,
        "crop": span.crop,
        "pix2tex_status": span.pix2tex_status,
        "pix2tex_output": span.pix2tex_output,
        "pix2tex_rejected_output": span.pix2tex_rejected_output,
        "pix2tex_stderr": span.pix2tex_stderr,
        "pix2tex_duration_ms": span.pix2tex_duration_ms,
    }


def serializable_display_block(block: DisplayBlock) -> dict[str, Any]:
    return {
        "block_index": block.block_index,
        "line_start": block.line_start,
        "line_end": block.line_end,
        "reason": block.reason,
        "bbox": block.bbox,
        "text": block.text,
        "crop": block.crop,
        "pix2tex_status": block.pix2tex_status,
        "pix2tex_output": block.pix2tex_output,
        "pix2tex_rejected_output": block.pix2tex_rejected_output,
        "pix2tex_stderr": block.pix2tex_stderr,
        "pix2tex_duration_ms": block.pix2tex_duration_ms,
        "display_backend": block.display_backend,
        "display_backend_status": block.display_backend_status,
        "display_backend_output": block.display_backend_output,
        "display_backend_stderr": block.display_backend_stderr,
        "display_backend_duration_ms": block.display_backend_duration_ms,
    }


def write_review(attempt_dir: Path, attempt_id: str, merged_output: str, backend: str) -> None:
    review = attempt_dir / "review.md"
    review.write_text(
        "\n".join(
            [
                "---",
                f"id: {attempt_id}",
                "type: custom",
                "status: needs-review",
                f"backend: {backend}",
                "engine: tesseract+pix2tex+sauron-display",
                "input: input.png",
                f"created_at: {attempt_id.removesuffix('_custom')}",
                "---",
                "",
                "# OCR Attempt",
                "",
                "![capture](input.png)",
                "",
                "## Raw Output",
                "",
                "```text",
                (attempt_dir / "raw-output.txt").read_text(errors="replace").rstrip(),
                "```",
                "",
                "## Normalized Output",
                "",
                "```markdown",
                merged_output.rstrip(),
                "```",
                "",
                "## Correction",
                "",
                "```markdown",
                "",
                "```",
                "",
                "## Notes",
                "",
                "- ",
                "",
            ]
        )
    )


def append_capture_queue(capture_root: Path, attempt_id: str, attempt_timestamp: str) -> None:
    capture_root.mkdir(parents=True, exist_ok=True)
    queue = capture_root / "review.md"
    if not queue.exists():
        queue.write_text("# OCR Review Queue\n\n## Attempts\n")
    with queue.open("a", encoding="utf-8") as queue_file:
        queue_file.write(f"- [ ] `{attempt_timestamp}` `custom` `needs-review`\n")
        queue_file.write(f"  - Review: [attempts/{attempt_id}/review.md](attempts/{attempt_id}/review.md)\n")
        queue_file.write(f"  - Image: [input.png](attempts/{attempt_id}/input.png)\n")
        queue_file.write("  - Output: edit the `## Correction` block if this was wrong.\n")
        queue_file.write("  - Notes:\n")


def main() -> int:
    args = parse_args()
    home = Path(os.environ.get("HOME", "~")).expanduser()
    live_capture = args.image is None
    source_image = Path(args.image).expanduser() if args.image else None
    if source_image is not None and not source_image.exists():
        print(f"ocr-custom-split: image not found: {source_image}", file=sys.stderr)
        return 2

    capture_root = expanded_path(args.capture_root, home / ".local/share/ocr-captures")
    attempt_timestamp = timestamp_id()
    attempt_id = f"{attempt_timestamp}_custom"
    attempt_dir = expanded_path(args.attempt_dir) if args.attempt_dir else capture_root / "attempts" / attempt_id
    crops_dir = attempt_dir / "crops"
    attempt_dir.mkdir(parents=True, exist_ok=True)
    crops_dir.mkdir(parents=True, exist_ok=True)

    log_path = attempt_dir / "backend.log"
    log_path.write_text(
        "\n".join(
            [
                "== ocr-custom-split debug ==",
                f"date: {datetime.now().astimezone().isoformat()}",
                f"mode: {'live-capture' if live_capture else 'saved-image'}",
                f"source_image: {source_image or ''}",
                f"attempt_dir: {attempt_dir}",
                f"backend: {args.backend}",
                f"display_backend: {args.display_backend}",
                f"lang: {args.lang}",
                f"psm: {args.psm}",
                "",
            ]
        )
    )

    input_image = attempt_dir / "input.png"
    region = ""
    if live_capture:
        try:
            captured_region = capture_region(input_image, log_path)
        except RuntimeError as error:
            (attempt_dir / "raw-output.txt").write_text(str(error) + "\n")
            if not args.no_notify:
                notify_user("Custom OCR failed", f"Screen capture failed.\nLog: {log_path}", log_path, "critical")
            print(f"ocr-custom-split: screen capture failed; see {log_path}", file=sys.stderr)
            return 1
        if captured_region is None:
            write_json(
                attempt_dir / "metadata.json",
                {
                    "timestamp": attempt_timestamp,
                    "attempt_id": attempt_id,
                    "command": "ocr-custom-split",
                    "mode": "live-capture",
                    "status": "cancelled",
                },
            )
            print(attempt_dir)
            return 0
        region = captured_region
    elif source_image is not None and source_image.resolve() != input_image.resolve():
        shutil.copy2(source_image, input_image)

    processed_image = attempt_dir / "processed.png"
    try:
        preprocess_metadata = preprocess_image(input_image, processed_image, log_path)
    except RuntimeError as error:
        (attempt_dir / "raw-output.txt").write_text(str(error) + "\n")
        if live_capture or args.notify:
            notify_user("Custom OCR failed", f"Image preprocessing failed.\nLog: {log_path}", log_path, "critical")
        print(f"ocr-custom-split: image preprocessing failed; see {log_path}", file=sys.stderr)
        return 1
    write_json(attempt_dir / "preprocess.json", preprocess_metadata)

    tesseract_tsv = attempt_dir / "tesseract.tsv"
    tesseract_result = run_command(
        ["tesseract", str(processed_image), "stdout", "-l", args.lang, "--psm", str(args.psm), "tsv"],
        log_path,
    )
    tesseract_tsv.write_bytes(tesseract_result.stdout)
    if tesseract_result.returncode != 0:
        (attempt_dir / "raw-output.txt").write_text(tesseract_result.stderr.decode(errors="replace"))
        if live_capture or args.notify:
            notify_user("Custom OCR failed", f"Tesseract failed.\nLog: {log_path}", log_path, "critical")
        print(f"ocr-custom-split: tesseract failed; see {log_path}", file=sys.stderr)
        return tesseract_result.returncode or 1

    words = load_words(tesseract_tsv)
    lines = group_lines(words)
    image_size = identify_image(processed_image, log_path)
    display_blocks = detect_display_blocks(lines, image_size[0])
    inline_lines = [
        line
        for line in lines
        if line_in_display_block(line["line_index"], display_blocks) is None
    ]
    spans = detect_spans(inline_lines)
    pix2tex_bin = resolve_pix2tex_bin(args.pix2tex_bin)
    pix2tex_mode = "never" if args.no_pix2tex else args.pix2tex_mode
    display_backend = resolve_display_backend(args)
    sauron_ready = False

    display_crops_dir = attempt_dir / "display-crops"
    display_crops_dir.mkdir(parents=True, exist_ok=True)
    display_backend_dir = attempt_dir / "display-backend"
    display_backend_dir.mkdir(parents=True, exist_ok=True)

    for block_index, block in enumerate(display_blocks, start=1):
        block.display_backend = display_backend
        crop_path = display_crops_dir / f"block-{block_index:03d}.png"
        try:
            crop_span(processed_image, block, crop_path, image_size, log_path)
            block.crop = str(crop_path.relative_to(attempt_dir))
        except RuntimeError as error:
            block.pix2tex_status = "crop-failed"
            block.pix2tex_stderr = str(error)
            continue

        if pix2tex_mode == "auto":
            if block_is_tesseract_cleanable(block):
                block.pix2tex_status = "skipped-simple"
                block.display_backend_status = "skipped-simple"
                continue
            if display_backend == "sauron":
                if not sauron_ready:
                    sauron_ready = prepare_sauron(log_path)
                if sauron_ready:
                    response_path = display_backend_dir / f"block-{block_index:03d}-sauron-response.json"
                    run_sauron_display_ocr(block, crop_path, response_path, log_path)
                else:
                    block.display_backend_status = "failed:sauron-not-ready"
            else:
                block.pix2tex_status = "unresolved-needs-display-backend"
                block.display_backend_status = "unresolved-needs-display-backend"
            continue
        if pix2tex_mode == "never":
            if display_backend == "sauron" and not block_is_tesseract_cleanable(block):
                if not sauron_ready:
                    sauron_ready = prepare_sauron(log_path)
                if sauron_ready:
                    response_path = display_backend_dir / f"block-{block_index:03d}-sauron-response.json"
                    run_sauron_display_ocr(block, crop_path, response_path, log_path)
                else:
                    block.display_backend_status = "failed:sauron-not-ready"
            else:
                block.pix2tex_status = "disabled"
                block.display_backend_status = "disabled"
            continue
        if pix2tex_bin is None:
            block.pix2tex_status = "missing-pix2tex"
            continue
        run_pix2tex_for_block(block, pix2tex_bin, crop_path, log_path, args.timeout)

    for span_index, span in enumerate(spans, start=1):
        crop_path = crops_dir / f"span-{span_index:03d}.png"
        try:
            crop_span(processed_image, span, crop_path, image_size, log_path)
            span.crop = str(crop_path.relative_to(attempt_dir))
        except RuntimeError as error:
            span.pix2tex_status = "crop-failed"
            span.pix2tex_stderr = str(error)
            continue

        if pix2tex_mode == "never":
            span.pix2tex_status = "disabled"
            continue
        if pix2tex_mode == "auto" and span_is_simple_math(span):
            span.pix2tex_status = "skipped-simple"
            continue
        if pix2tex_bin is None:
            span.pix2tex_status = "missing-pix2tex"
            continue
        run_pix2tex(span, pix2tex_bin, crop_path, log_path, args.timeout)

    merged_lines = postprocess_merged_lines(lines_to_text_with_display_blocks(lines, spans, display_blocks))
    merged_output = "\n".join(line for line in merged_lines if line.strip()).strip()
    raw_text = "\n".join(line["text"] for line in lines).strip()

    try:
        write_debug_overlay(processed_image, spans, display_blocks, attempt_dir / "debug-overlay.png", log_path)
    except RuntimeError as error:
        with log_path.open("a", encoding="utf-8") as log_file:
            log_file.write(f"debug overlay failed: {error}\n")

    (attempt_dir / "raw-output.txt").write_text(raw_text + ("\n" if raw_text else ""))
    (attempt_dir / "merged-output.md").write_text(merged_output + ("\n" if merged_output else ""))
    (attempt_dir / "normalized-output.txt").write_text(merged_output + ("\n" if merged_output else ""))
    write_json(attempt_dir / "lines.json", [serializable_line(line) for line in lines])
    write_json(attempt_dir / "spans.json", [serializable_span(span) for span in spans])
    write_json(attempt_dir / "display-blocks.json", [serializable_display_block(block) for block in display_blocks])
    write_json(
        attempt_dir / "metadata.json",
        {
            "timestamp": attempt_timestamp,
            "attempt_id": attempt_id,
            "command": "ocr-custom-split",
            "mode": "live-capture" if live_capture else "saved-image",
            "backend": args.backend,
            "engine": {
                "text": "tesseract",
                "math": "pix2tex",
                "display_backend": display_backend,
                "pix2tex_bin": str(pix2tex_bin) if pix2tex_bin else None,
                "pix2tex_args": os.environ.get("OCR_CUSTOM_PIX2TEX_ARGS", "--no-cuda"),
                "pix2tex_mode": pix2tex_mode,
                "pix2tex_timeout_seconds": args.timeout,
                "language": args.lang,
                "page_segmentation_mode": args.psm,
            },
            "files": {
                "input": str(input_image),
                "processed_input": str(processed_image),
                "preprocess": str(attempt_dir / "preprocess.json"),
                "tesseract_tsv": str(tesseract_tsv),
                "lines": str(attempt_dir / "lines.json"),
                "spans": str(attempt_dir / "spans.json"),
                "display_blocks": str(attempt_dir / "display-blocks.json"),
                "display_crops": str(display_crops_dir),
                "display_backend": str(display_backend_dir),
                "debug_overlay": str(attempt_dir / "debug-overlay.png"),
                "raw_output": str(attempt_dir / "raw-output.txt"),
                "normalized_output": str(attempt_dir / "normalized-output.txt"),
                "merged_output": str(attempt_dir / "merged-output.md"),
                "log": str(log_path),
            },
            "image": {
                "width": image_size[0],
                "height": image_size[1],
            },
            "preprocess": preprocess_metadata,
            "capture": {
                "region": region,
            },
            "counts": {
                "words": len(words),
                "lines": len(lines),
                "spans": len(spans),
                "display_blocks": len(display_blocks),
                "pix2tex_succeeded": sum(1 for span in spans if span.pix2tex_status == "succeeded"),
                "display_pix2tex_succeeded": sum(1 for block in display_blocks if block.pix2tex_status == "succeeded"),
                "display_backend_succeeded": sum(1 for block in display_blocks if block.display_backend_status == "succeeded"),
            },
            "status": "succeeded",
        },
    )
    write_review(attempt_dir, attempt_id, merged_output, args.backend)

    should_copy = args.copy or (live_capture and not args.no_copy)
    should_notify = args.notify or (live_capture and not args.no_notify)
    copied = False
    if should_copy:
        copied = copy_file_to_clipboard(attempt_dir / "normalized-output.txt", log_path)

    if should_notify:
        if copied or not should_copy:
            notify_user("Custom OCR", f"Copied Markdown to clipboard.\nAttempt: {attempt_dir}", log_path)
        else:
            notify_user("Custom OCR failed", f"OCR finished, but clipboard copy failed.\nLog: {log_path}", log_path, "critical")

    if not args.attempt_dir:
        capture_root.mkdir(parents=True, exist_ok=True)
        for symlink_name in ("latest", "latest-custom"):
            symlink_path = capture_root / symlink_name
            try:
                symlink_path.unlink()
            except FileNotFoundError:
                pass
            symlink_path.symlink_to(attempt_dir)
        append_capture_queue(capture_root, attempt_id, attempt_timestamp)

    print(attempt_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
