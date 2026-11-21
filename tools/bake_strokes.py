#!/usr/bin/env python3
"""Bake stroke-order data for the writing practice from KanjiVG.

Input
-----
tools/data/kanjivg.xml.gz   KanjiVG release XML (https://github.com/KanjiVG/kanjivg/releases)
game/content/kanji_<stage>.json   the kanji the game teaches (written by bake_content.py)

Output
------
game/content/strokes_<stage>.json   [{"kanji": "日", "strokes": [[x0, y0, x1, y1, ...], ...]}]
game/content/strokes_extra.json     the same for every hiragana and katakana, ー and 々, and any
                                    kanji used in a word but on no stage list (word writing)

Coordinates are KanjiVG's 109 x 109 box, one decimal. Strokes are in writing order and each
runs in the direction it is written. Curves are sampled, then simplified (Ramer-Douglas-Peucker)
so a straight stroke keeps two points.

KanjiVG is (C) Ulrich Apel and contributors, CC BY-SA 3.0 (http://kanjivg.tagaini.net).

Usage
-----
    python tools/bake_strokes.py
"""
from __future__ import annotations

import gzip
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tools" / "data" / "kanjivg.xml.gz"
CONTENT = ROOT / "game" / "content"
STAGES = ["n5", "n4", "n3", "n2", "n1", "mastery"]
SAMPLES_PER_CURVE = 8
SIMPLIFY = 0.35  # max deviation in KanjiVG units when dropping points

TOKEN = re.compile(r"[MmCcSsLlHhVvZz]|-?\d*\.?\d+(?:e-?\d+)?")


def path_points(d: str) -> list[tuple[float, float]]:
    """Flatten an SVG path (the subset KanjiVG uses) into a polyline."""
    tokens = TOKEN.findall(d)
    pts: list[tuple[float, float]] = []
    i = 0
    cmd = ""
    cur = (0.0, 0.0)
    start = (0.0, 0.0)
    last_ctrl: tuple[float, float] | None = None

    def num() -> float:
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    while i < len(tokens):
        if re.fullmatch(r"[A-Za-z]", tokens[i]):
            cmd = tokens[i]
            i += 1
        rel = cmd.islower()
        c = cmd.upper()
        ox, oy = cur if rel else (0.0, 0.0)
        if c == "M":
            cur = (num() + ox, num() + oy)
            start = cur
            pts.append(cur)
            cmd = "l" if rel else "L"  # extra pairs after M are line-tos
            last_ctrl = None
        elif c == "L":
            cur = (num() + ox, num() + oy)
            pts.append(cur)
            last_ctrl = None
        elif c == "H":
            cur = (num() + ox, cur[1])
            pts.append(cur)
        elif c == "V":
            cur = (cur[0], num() + oy)
            pts.append(cur)
        elif c in ("C", "S"):
            if c == "C":
                c1 = (num() + ox, num() + oy)
            else:
                c1 = (2 * cur[0] - last_ctrl[0], 2 * cur[1] - last_ctrl[1]) if last_ctrl else cur
            c2 = (num() + ox, num() + oy)
            end = (num() + ox, num() + oy)
            p0 = cur
            for k in range(1, SAMPLES_PER_CURVE + 1):
                t = k / SAMPLES_PER_CURVE
                mt = 1 - t
                x = mt**3 * p0[0] + 3 * mt * mt * t * c1[0] + 3 * mt * t * t * c2[0] + t**3 * end[0]
                y = mt**3 * p0[1] + 3 * mt * mt * t * c1[1] + 3 * mt * t * t * c2[1] + t**3 * end[1]
                pts.append((x, y))
            last_ctrl = c2
            cur = end
        elif c == "Z":
            cur = start
            pts.append(cur)
        else:
            raise ValueError(f"unsupported path command {cmd!r} in {d!r}")
    return pts


def simplify(pts: list[tuple[float, float]], eps: float) -> list[tuple[float, float]]:
    """Ramer-Douglas-Peucker."""
    if len(pts) < 3:
        return pts
    (x1, y1), (x2, y2) = pts[0], pts[-1]
    dx, dy = x2 - x1, y2 - y1
    norm = math.hypot(dx, dy) or 1e-9
    worst, idx = 0.0, 0
    for k in range(1, len(pts) - 1):
        x, y = pts[k]
        dist = abs(dy * x - dx * y + x2 * y1 - y2 * x1) / norm if norm > 1e-9 else math.hypot(x - x1, y - y1)
        if dist > worst:
            worst, idx = dist, k
    if worst <= eps:
        return [pts[0], pts[-1]]
    return simplify(pts[: idx + 1], eps)[:-1] + simplify(pts[idx:], eps)


def load_kanjivg() -> dict[str, list[str]]:
    """kanji -> stroke path strings in order (the plain variant of each character only)."""
    ns = "{http://kanjivg.tagaini.net}"
    out: dict[str, list[str]] = {}
    with gzip.open(SOURCE, "rb") as fh:
        for _, el in ET.iterparse(fh, events=("end",)):
            if el.tag != "kanji":
                continue
            kid = el.get("id", "")
            m = re.fullmatch(r"kvg:kanji_([0-9a-f]{5})", kid)
            if m:
                ch = chr(int(m.group(1), 16))
                paths = [p for p in el.iter("path")]
                paths.sort(key=lambda p: int(re.search(r"-s(\d+)$", p.get("id", "-s0")).group(1)))
                out[ch] = [p.get("d", "") for p in paths]
            el.clear()
    del ns
    return out


def main() -> int:
    if not SOURCE.exists():
        print(f"missing {SOURCE}; download kanjivg-<date>.xml.gz from the KanjiVG releases", file=sys.stderr)
        return 1
    kvg = load_kanjivg()
    missing: list[str] = []
    total = 0
    for stage in STAGES:
        src = CONTENT / f"kanji_{stage}.json"
        if not src.exists():
            continue
        entries = []
        for k in json.loads(src.read_text(encoding="utf-8")):
            ch = k["kanji"]
            if ch not in kvg:
                missing.append(ch)
                continue
            strokes = []
            for d in kvg[ch]:
                pts = simplify(path_points(d), SIMPLIFY)
                strokes.append([round(v, 1) for p in pts for v in p])
            entries.append({"kanji": ch, "strokes": strokes})
        out = CONTENT / f"strokes_{stage}.json"
        text = "[\n" + ",\n".join(json.dumps(e, ensure_ascii=False, separators=(",", ":")) for e in entries) + "\n]\n"
        out.write_text(text, encoding="utf-8", newline="\n")
        total += len(entries)
        print(f"{out.name}: {len(entries)} kanji, {len(text) // 1024} KB")
    # Kana and the leftovers needed to write whole words.
    staged: set[str] = set()
    for stage in STAGES:
        src = CONTENT / f"kanji_{stage}.json"
        if src.exists():
            staged.update(k["kanji"] for k in json.loads(src.read_text(encoding="utf-8")))
    extra = [chr(c) for c in range(0x3041, 0x3097)] + [chr(c) for c in range(0x30A1, 0x30FB)] + ["ー", "々"]
    for vocab in sorted(CONTENT.glob("vocab_*.json")):
        for e in json.loads(vocab.read_text(encoding="utf-8")):
            for ch in e["headword"]:
                if "一" <= ch <= "鿿" and ch not in staged and ch not in extra:
                    extra.append(ch)
    entries = []
    for ch in extra:
        if ch in kvg:
            entries.append({"kanji": ch, "strokes": [[round(v, 1) for p in simplify(path_points(d), SIMPLIFY) for v in p] for d in kvg[ch]]})
    out = CONTENT / "strokes_extra.json"
    text = "[\n" + ",\n".join(json.dumps(e, ensure_ascii=False, separators=(",", ":")) for e in entries) + "\n]\n"
    out.write_text(text, encoding="utf-8", newline="\n")
    print(f"{out.name}: {len(entries)} characters, {len(text) // 1024} KB")
    print(f"{total} kanji baked" + (f"; no KanjiVG data for {''.join(missing)}" if missing else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
