"""Shared helpers for the content pipeline: furigana markup parsing, kanji detection, and a
heuristic checker that verifies each {漢字|かな} group against JMdict and KanjiDic2.

The reading checker is a *warning* tool for curators, never a CI gate: it needs the local JMdict
SQLite and KanjiDic2 zip (both git-ignored), and readings such as jukujikun or irregular
conjugation stems (来ない → こ) are legitimately outside what it can prove.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import zipfile
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "tools" / "data"
JMDICT_CANDIDATES = [
    DATA / "jmdict.sqlite",
    Path.home() / "Downloads" / "Learn Japanese" / "Immersion Reader" / "data" / "jmdict.sqlite",
]
KANJIDIC_ZIP = DATA / "kanjidic2-en.json.zip"

FURIGANA = re.compile(r"\{([^|{}]+)\|([^|{}]+)\}")
KANJI = re.compile(r"[々一-鿿]")  # 々 counts as a kanji for markup purposes
STAGES = ["n5", "n4", "n3", "n2", "n1", "mastery"]

# KanjiDic2 still carries the pre-2010 four-level JLPT field. Mapping used here:
#   old 4 -> N5, old 3 -> N4, old 2 split by frequency (top half N3, rest N2), old 1 -> N1.
OLD_JLPT_TO_STAGE = {4: "n5", 3: "n4", 1: "n1"}


# ---------------------------------------------------------------- markup

def groups(text: str) -> list[tuple[str, str]]:
    return FURIGANA.findall(text)


def plain(text: str) -> str:
    return FURIGANA.sub(lambda m: m.group(1), text)


def reading(text: str) -> str:
    return FURIGANA.sub(lambda m: m.group(2), text)


def bare_kanji(text: str) -> list[str]:
    """Kanji that sit outside any {base|reading} group."""
    return KANJI.findall(FURIGANA.sub("", text))


def word_id(headword: str, reading_: str) -> str:
    """Stable id independent of file, row order and JMdict availability."""
    return "w_" + hashlib.md5(f"{headword}|{reading_}".encode("utf-8")).hexdigest()[:10]


def kata_to_hira(s: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in s)


# ---------------------------------------------------------------- dictionaries

@lru_cache(maxsize=1)
def jmdict() -> sqlite3.Connection | None:
    for path in JMDICT_CANDIDATES:
        if path.exists():
            return sqlite3.connect(str(path))
    return None


@lru_cache(maxsize=1)
def kanjidic() -> dict[str, dict]:
    if not KANJIDIC_ZIP.exists():
        return {}
    z = zipfile.ZipFile(KANJIDIC_ZIP)
    data = json.loads(z.read(z.namelist()[0]))
    out: dict[str, dict] = {}
    for ch in data["characters"]:
        on, kun, meanings = [], [], []
        rm = ch.get("readingMeaning") or {}
        for group in rm.get("groups", []):
            for r in group.get("readings", []):
                if r["type"] == "ja_on":
                    on.append(kata_to_hira(r["value"]))
                elif r["type"] == "ja_kun":
                    kun.append(r["value"])
            for m in group.get("meanings", []):
                if m.get("lang", "en") == "en":
                    meanings.append(m["value"])
        misc = ch.get("misc", {})
        out[ch["literal"]] = {
            "on": on, "kun": kun, "meanings": meanings, "nanori": rm.get("nanori", []),
            "strokes": (misc.get("strokeCounts") or [0])[0], "freq": misc.get("frequency"),
            "grade": misc.get("grade"), "jlpt_old": misc.get("jlptLevel"),
        }
    return out


def jmdict_entries(form: str) -> list[dict]:
    db = jmdict()
    if db is None:
        return []
    rows = db.execute(
        "SELECT e.id, e.data, e.common FROM forms f JOIN entries e ON e.id = f.entry_id WHERE f.text = ?", (form,)
    ).fetchall()
    out = []
    for seq, data, common in rows:
        entry = json.loads(data)
        entry["_seq"] = seq
        entry["_common"] = bool(common)
        out.append(entry)
    return out


def jmdict_has_pair(headword: str, reading_: str) -> bool:
    for entry in jmdict_entries(headword):
        if reading_ in [k["t"] for k in entry.get("kana", [])]:
            return True
    return False


# ---------------------------------------------------------------- reading heuristics

_RENDAKU = {
    "か": "が", "き": "ぎ", "く": "ぐ", "け": "げ", "こ": "ご", "さ": "ざ", "し": "じ", "す": "ず",
    "せ": "ぜ", "そ": "ぞ", "た": "だ", "ち": "ぢじ", "つ": "づず", "て": "で", "と": "ど",
    "は": "ばぱ", "ひ": "びぴ", "ふ": "ぶぷ", "へ": "べぺ", "ほ": "ぼぽ",
}


def kanji_readings(ch: str) -> set[str]:
    """All plausible hiragana readings of one kanji inside a word."""
    info = kanjidic().get(ch)
    if not info:
        return set()
    base: set[str] = set(info["on"])
    for k in info["kun"] + info["nanori"]:
        k = k.strip("-")
        stem, _, okuri = k.partition(".")
        base.add(stem)
        if okuri:
            base.add(stem + okuri)
    out = set(base)
    for r in base:
        if not r:
            continue
        for v in _RENDAKU.get(r[0], ""):
            out.add(v + r[1:])
        if r[-1] in "つくちき" and len(r) > 1:
            out.add(r[:-1] + "っ")
    out.discard("")
    return out


def _splits(base: str, reading_: str) -> bool:
    """True if reading_ can be split into one plausible reading per kanji of base."""
    if not base:
        return reading_ == ""
    ch = base[0]
    if ch == "々":
        return False  # handled by caller via previous kanji
    opts = kanji_readings(ch)
    if len(base) > 1 and base[1] == "々":
        doubled = set()
        for r in opts:
            doubled.add(r + r)
            for v in _RENDAKU.get(r[0], ""):
                doubled.add(r + v + r[1:])
        for r in doubled:
            if reading_.startswith(r) and _splits(base[2:], reading_[len(r):]):
                return True
        return False
    for r in opts:
        if reading_.startswith(r) and _splits(base[1:], reading_[len(r):]):
            return True
    return False


def check_group(base: str, reading_: str) -> str | None:
    """Return None when the group's reading is plausible, else a short reason."""
    if KANJI.search(reading_):
        return "reading contains kanji"
    if not KANJI.search(base):
        return "group base has no kanji (drop the braces)"
    if not kanjidic() and jmdict() is None:
        return None  # nothing to check against
    if jmdict_has_pair(base, reading_):
        return None
    # Mixed groups like 行き|いき: strip shared trailing kana.
    b, r = base, reading_
    while b and r and not KANJI.match(b[-1]) and b[-1] == r[-1]:
        b, r = b[:-1], r[:-1]
    if b != base and jmdict_has_pair(b, r):
        return None
    if KANJI.fullmatch(b[0] if b else "") and all(KANJI.match(c) for c in b) and _splits(b, r):
        return None
    return f"cannot confirm {base}→{reading_} from JMdict/KanjiDic2"


def check_text(text: str) -> list[str]:
    """All problems in one Japanese string: bare kanji (errors start with 'ERROR')."""
    problems = []
    bare = bare_kanji(text)
    if bare:
        problems.append(f"ERROR bare kanji {''.join(bare)} in {text!r}")
    for base, rd in groups(text):
        why = check_group(base, rd)
        if why and why.startswith("reading contains") or why and why.startswith("group base has no"):
            problems.append(f"ERROR {why}: {{{base}|{rd}}}")
        elif why:
            problems.append(f"warn {why}")
    return problems
