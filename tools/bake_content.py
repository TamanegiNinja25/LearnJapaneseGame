#!/usr/bin/env python3
"""Bake game content JSON from the curated word list plus JMdict.

Inputs
------
tools/n5_wordlist.tsv      hand-curated headwords, readings, Japanese definitions, examples
tools/data/jmdict.sqlite   optional; JMdict (EDRDG, CC BY-SA 4.0) in the schema produced by the
                           Immersion Reader project: entries(id, common, data JSON), forms(text, entry_id)

Outputs (written into game/content/)
-----------------------------------
kana.json        hiragana + katakana tables (generated, no external data)
vocab_n5.json    one entry per word list row, enriched with JMdict English glosses and part of speech

Usage
-----
    python tools/bake_content.py [--jmdict PATH] [--out game/content]

Without JMdict the English gloss falls back to the example translation and the part of speech
to the category column, so the game still builds from a clean checkout.
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_JMDICT = ROOT / "tools" / "data" / "jmdict.sqlite"
FALLBACK_JMDICT = Path.home() / "Downloads" / "Learn Japanese" / "Immersion Reader" / "data" / "jmdict.sqlite"

# JMdict part-of-speech tags → the game's coarse categories.
POS_MAP = {
    "n": "noun", "pn": "pronoun", "v1": "verb-ru", "v5u": "verb-u", "v5k": "verb-u", "v5s": "verb-u",
    "v5t": "verb-u", "v5n": "verb-u", "v5b": "verb-u", "v5m": "verb-u", "v5r": "verb-u", "v5g": "verb-u",
    "v5k-s": "verb-u", "v5r-i": "verb-u", "vk": "verb-irregular", "vs-i": "verb-irregular", "vs": "noun",
    "adj-i": "adj-i", "adj-na": "adj-na", "exp": "expression", "int": "expression", "adv": "adverb",
}

CATEGORY_JA = {
    "noun": "名詞", "pronoun": "代名詞", "verb-u": "動詞（五段）", "verb-ru": "動詞（一段）",
    "verb-irregular": "動詞（不規則）", "adj-i": "い形容詞", "adj-na": "な形容詞",
    "expression": "表現", "adverb": "副詞",
}


def hiragana_table() -> list[dict]:
    rows = [
        ("あ", "a"), ("い", "i"), ("う", "u"), ("え", "e"), ("お", "o"),
        ("か", "ka"), ("き", "ki"), ("く", "ku"), ("け", "ke"), ("こ", "ko"),
        ("さ", "sa"), ("し", "shi"), ("す", "su"), ("せ", "se"), ("そ", "so"),
        ("た", "ta"), ("ち", "chi"), ("つ", "tsu"), ("て", "te"), ("と", "to"),
        ("な", "na"), ("に", "ni"), ("ぬ", "nu"), ("ね", "ne"), ("の", "no"),
        ("は", "ha"), ("ひ", "hi"), ("ふ", "fu"), ("へ", "he"), ("ほ", "ho"),
        ("ま", "ma"), ("み", "mi"), ("む", "mu"), ("め", "me"), ("も", "mo"),
        ("や", "ya"), ("ゆ", "yu"), ("よ", "yo"),
        ("ら", "ra"), ("り", "ri"), ("る", "ru"), ("れ", "re"), ("ろ", "ro"),
        ("わ", "wa"), ("を", "wo"), ("ん", "n"),
        ("が", "ga"), ("ぎ", "gi"), ("ぐ", "gu"), ("げ", "ge"), ("ご", "go"),
        ("ざ", "za"), ("じ", "ji"), ("ず", "zu"), ("ぜ", "ze"), ("ぞ", "zo"),
        ("だ", "da"), ("ぢ", "ji"), ("づ", "zu"), ("で", "de"), ("ど", "do"),
        ("ば", "ba"), ("び", "bi"), ("ぶ", "bu"), ("べ", "be"), ("ぼ", "bo"),
        ("ぱ", "pa"), ("ぴ", "pi"), ("ぷ", "pu"), ("ぺ", "pe"), ("ぽ", "po"),
    ]
    return [{"kana": k, "romaji": r, "group": "basic" if i < 46 else "dakuten"} for i, (k, r) in enumerate(rows)]


def katakana_table() -> list[dict]:
    out = []
    for row in hiragana_table():
        kata = "".join(chr(ord(c) + 0x60) for c in row["kana"])
        out.append({"kana": kata, "romaji": row["romaji"], "group": row["group"]})
    return out


def read_wordlist(path: Path) -> list[dict]:
    rows = []
    with path.open(encoding="utf-8") as fh:
        header = None
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            if line.startswith("#"):
                header = line[1:].split("\t")
                continue
            cols = line.split("\t")
            if header is not None and len(cols) == len(header) - 1:
                cols.append("")  # editors strip a trailing tab when the last column is empty
            if header is None or len(cols) != len(header):
                raise SystemExit(f"bad row (expected {len(header or [])} columns): {line!r}")
            rows.append(dict(zip(header, cols)))
    return rows


def lookup_jmdict(db: sqlite3.Connection | None, headword: str, reading: str) -> tuple[list[str], str | None]:
    """Return (english glosses, coarse pos) for the JMdict entry whose kanji/kana form matches."""
    if db is None:
        return [], None
    candidates = db.execute(
        "SELECT e.data, e.common FROM forms f JOIN entries e ON e.id = f.entry_id WHERE f.text = ?", (headword,)
    ).fetchall()
    best = None
    for data, common in candidates:
        entry = json.loads(data)
        kana = [k["t"] for k in entry.get("kana", [])]
        if reading in kana or headword in kana:
            score = 1 + (1 if common else 0)
            if best is None or score > best[0]:
                best = (score, entry)
    if best is None:
        return [], None
    entry = best[1]
    glosses: list[str] = []
    pos = None
    for sense in entry.get("sense", []):
        if pos is None:
            for tag in sense.get("pos", []):
                if tag in POS_MAP:
                    pos = POS_MAP[tag]
                    break
        for g in sense.get("g", []):
            if g not in glosses:
                glosses.append(g)
        if len(glosses) >= 3:
            break
    return glosses[:3], pos


def bake_vocab(rows: list[dict], db: sqlite3.Connection | None) -> list[dict]:
    entries = []
    for i, row in enumerate(rows, start=1):
        glosses, pos = lookup_jmdict(db, row["headword"], row["reading"])
        category = row["category"] or pos or "noun"
        english = "; ".join(glosses) if glosses else row["example_en"]
        entries.append({
            "id": f"n5_{i:03d}",
            "headword": row["headword"],
            "reading": row["reading"],
            "level": "N5",
            "category": category,
            "category_ja": CATEGORY_JA.get(category, category),
            "definition_ja": row["jp_definition"],
            "english": english,
            "examples": [{"ja": row["example_jp"], "en": row["example_en"]}],
            "related": [r for r in row["related"].split(",") if r],
            "source": "JMdict (EDRDG, CC BY-SA 4.0) + original editorial content" if glosses else "original editorial content",
        })
    return entries


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--jmdict", type=Path, default=None, help="path to jmdict.sqlite")
    ap.add_argument("--out", type=Path, default=ROOT / "game" / "content")
    ap.add_argument("--wordlist", type=Path, default=ROOT / "tools" / "n5_wordlist.tsv")
    args = ap.parse_args(argv)

    jmdict_path = args.jmdict or (DEFAULT_JMDICT if DEFAULT_JMDICT.exists() else FALLBACK_JMDICT)
    db = None
    if jmdict_path.exists():
        db = sqlite3.connect(str(jmdict_path))
        print(f"JMdict: {jmdict_path}")
    else:
        print("JMdict not found; baking with editorial content only", file=sys.stderr)

    args.out.mkdir(parents=True, exist_ok=True)
    kana = {"hiragana": hiragana_table(), "katakana": katakana_table()}
    (args.out / "kana.json").write_text(json.dumps(kana, ensure_ascii=False, indent=1), encoding="utf-8")

    rows = read_wordlist(args.wordlist)
    vocab = bake_vocab(rows, db)
    missing = [v["headword"] for v in vocab if "JMdict" not in v["source"]]
    (args.out / "vocab_n5.json").write_text(json.dumps(vocab, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"wrote {len(vocab)} vocab entries, {len(kana['hiragana'])} hiragana, {len(kana['katakana'])} katakana")
    if db is not None and missing:
        print(f"no JMdict match for: {', '.join(missing)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
