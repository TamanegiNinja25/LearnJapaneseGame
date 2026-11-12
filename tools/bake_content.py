#!/usr/bin/env python3
"""Bake game content JSON from the curated word lists plus JMdict and KanjiDic2.

Inputs
------
tools/wordlists/<stage>/*.tsv   hand-curated words per stage (n5, n4, n3, n2, n1, mastery)
JMdict SQLite (optional)        English glosses; see tools/README.md for where it is looked up
tools/data/kanjidic2-en.json.zip (optional)  kanji readings, meanings, JLPT level

Outputs (game/content/)
-----------------------
kana.json              hiragana + katakana (basic, dakuten, handakuten, yoon)
vocab_<stage>.json     one entry per word, id = stable hash of headword+reading
kanji_<stage>.json     the stage's kanji with readings, meanings and the words that use them

Grammar, sentence prompts, scenarios, passages and anchors are authored directly as JSON in
game/content/ and are not touched by this script.

Usage
-----
    python tools/bake_content.py [--report]

--report also lists stage kanji that no word of that stage uses yet (a curation to-do list).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import jpcheck as jp  # noqa: E402
from check_tsv import read_rows  # noqa: E402

OUT = jp.ROOT / "game" / "content"
WORDLISTS = jp.ROOT / "tools" / "wordlists"

POS_MAP = {
    "n": "noun", "pn": "pronoun", "v1": "verb-ru", "vk": "verb-irregular", "vs-i": "verb-irregular",
    "adj-i": "adj-i", "adj-na": "adj-na", "exp": "expression", "int": "interjection", "adv": "adverb",
    "conj": "conjunction", "ctr": "counter", "prt": "particle", "pref": "prefix", "suf": "suffix",
}
CATEGORY_JA = {
    "noun": "名詞", "pronoun": "代名詞", "verb-u": "動詞（五段）", "verb-ru": "動詞（一段）",
    "verb-irregular": "動詞（不規則）", "adj-i": "い形容詞", "adj-na": "な形容詞", "adverb": "副詞",
    "expression": "表現", "conjunction": "接続詞", "counter": "助数詞", "particle": "助詞",
    "prefix": "接頭辞", "suffix": "接尾辞", "interjection": "感動詞",
}
STAGE_LABEL = {"n5": "N5", "n4": "N4", "n3": "N3", "n2": "N2", "n1": "N1", "mastery": "MASTERY"}


# ---------------------------------------------------------------- kana

_BASIC = [
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
]
_DAKUTEN = [
    ("が", "ga"), ("ぎ", "gi"), ("ぐ", "gu"), ("げ", "ge"), ("ご", "go"),
    ("ざ", "za"), ("じ", "ji"), ("ず", "zu"), ("ぜ", "ze"), ("ぞ", "zo"),
    ("だ", "da"), ("ぢ", "ji"), ("づ", "zu"), ("で", "de"), ("ど", "do"),
    ("ば", "ba"), ("び", "bi"), ("ぶ", "bu"), ("べ", "be"), ("ぼ", "bo"),
]
_HANDAKUTEN = [("ぱ", "pa"), ("ぴ", "pi"), ("ぷ", "pu"), ("ぺ", "pe"), ("ぽ", "po")]
_YOON_BASE = [("き", "k"), ("し", "sh"), ("ち", "ch"), ("に", "n"), ("ひ", "h"), ("み", "m"), ("り", "r"),
              ("ぎ", "g"), ("じ", "j"), ("び", "b"), ("ぴ", "p")]


def _yoon() -> list[tuple[str, str]]:
    out = []
    for kana, cons in _YOON_BASE:
        for small, vowel in (("ゃ", "a"), ("ゅ", "u"), ("ょ", "o")):
            romaji = cons + vowel if cons in ("sh", "ch", "j") else cons + "y" + vowel
            out.append((kana + small, romaji))
    return out


def hiragana_table() -> list[dict]:
    rows = []
    for kind, items in (("basic", _BASIC), ("dakuten", _DAKUTEN), ("handakuten", _HANDAKUTEN), ("yoon", _yoon())):
        rows += [{"kana": k, "romaji": r, "group": kind} for k, r in items]
    return rows


def katakana_table() -> list[dict]:
    return [{"kana": "".join(chr(ord(c) + 0x60) for c in row["kana"]), "romaji": row["romaji"], "group": row["group"]}
            for row in hiragana_table()]


# ---------------------------------------------------------------- vocab

def jmdict_gloss(headword: str, reading: str) -> tuple[list[str], str | None]:
    best = None
    for entry in jp.jmdict_entries(headword):
        kana = [k["t"] for k in entry.get("kana", [])]
        if reading in kana or headword in kana:
            score = 2 if entry["_common"] else 1
            if best is None or score > best[0]:
                best = (score, entry)
    if best is None:
        return [], None
    glosses: list[str] = []
    pos = None
    for sense in best[1].get("sense", []):
        if pos is None:
            for tag in sense.get("pos", []):
                if tag in POS_MAP or tag.startswith("v5"):
                    pos = POS_MAP.get(tag, "verb-u")
                    break
        for g in sense.get("g", []):
            if g not in glosses:
                glosses.append(g)
        if len(glosses) >= 3:
            break
    return glosses[:3], pos


def bake_stage_vocab(stage: str, seen: dict[tuple[str, str], str]) -> list[dict]:
    entries = []
    for path in sorted((WORDLISTS / stage).glob("*.tsv")):
        rows, errors = read_rows(path)
        if errors:
            raise SystemExit("\n".join(errors))
        for row in rows:
            key = (row["headword"], row["reading"])
            if key in seen:
                print(f"skip duplicate {row['headword']} in {stage}/{path.name} (already in {seen[key]})", file=sys.stderr)
                continue
            seen[key] = f"{stage}/{path.name}"
            glosses, _pos = jmdict_gloss(*key)
            category = row["category"]
            entries.append({
                "id": jp.word_id(*key),
                "headword": row["headword"],
                "reading": row["reading"],
                "level": STAGE_LABEL[stage],
                "category": category,
                "category_ja": CATEGORY_JA.get(category, category),
                "definition_ja": row["jp_definition"],
                "english": "; ".join(glosses) if glosses else row["example_en"],
                "examples": [{"ja": row["example_jp"], "en": row["example_en"]}],
                "related": [r.strip() for r in row["related"].split(",") if r.strip()],
                "kanji": sorted(set(jp.KANJI.findall(row["headword"]))),
                "source": "JMdict (EDRDG, CC BY-SA 4.0) + original editorial content" if glosses else "original editorial content",
            })
    return entries


# ---------------------------------------------------------------- kanji

def stage_of_kanji() -> dict[str, str]:
    kd = jp.kanjidic()
    out = {ch: jp.OLD_JLPT_TO_STAGE[info["jlpt_old"]] for ch, info in kd.items() if info["jlpt_old"] in jp.OLD_JLPT_TO_STAGE}
    old2 = sorted((ch for ch, info in kd.items() if info["jlpt_old"] == 2),
                  key=lambda ch: kd[ch]["freq"] if kd[ch]["freq"] else 99999)
    half = len(old2) // 2
    for i, ch in enumerate(old2):
        out[ch] = "n3" if i < half else "n2"
    return out


def bake_kanji(vocab_by_stage: dict[str, list[dict]]) -> dict[str, list[dict]]:
    kd = jp.kanjidic()
    if not kd:
        return {}
    stages = stage_of_kanji()
    words_using: dict[str, list[str]] = {}
    for stage in jp.STAGES:
        for entry in vocab_by_stage.get(stage, []):
            for ch in entry["kanji"]:
                words_using.setdefault(ch, []).append(entry["id"])
    out: dict[str, list[dict]] = {s: [] for s in jp.STAGES}
    for ch, stage in stages.items():
        info = kd[ch]
        out[stage].append({
            "kanji": ch, "on": info["on"], "kun": info["kun"], "meanings": info["meanings"][:4],
            "strokes": info["strokes"], "freq": info["freq"], "level": STAGE_LABEL[stage],
            "words": words_using.get(ch, [])[:8],
        })
    for stage in out:
        out[stage].sort(key=lambda k: (k["freq"] or 99999, k["kanji"]))
    return out


# ---------------------------------------------------------------- main

def write_json(name: str, data) -> None:
    (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", action="store_true", help="list stage kanji not yet used by any word")
    args = ap.parse_args(argv)
    if jp.jmdict() is None:
        print("JMdict not found; English glosses fall back to example translations", file=sys.stderr)

    OUT.mkdir(parents=True, exist_ok=True)
    write_json("kana.json", {"hiragana": hiragana_table(), "katakana": katakana_table()})

    seen: dict[tuple[str, str], str] = {}
    vocab_by_stage: dict[str, list[dict]] = {}
    for stage in jp.STAGES:
        if not (WORDLISTS / stage).exists():
            continue
        vocab = bake_stage_vocab(stage, seen)
        vocab_by_stage[stage] = vocab
        write_json(f"vocab_{stage}.json", vocab)
        print(f"{stage}: {len(vocab)} words")

    kanji = bake_kanji(vocab_by_stage)
    for stage, rows in kanji.items():
        if rows:
            write_json(f"kanji_{stage}.json", rows)
            used = sum(1 for k in rows if k["words"])
            print(f"{stage}: {len(rows)} kanji ({used} used by at least one word)")
            if args.report:
                missing = [k["kanji"] for k in rows if not k["words"]]
                if missing:
                    print(f"  unused {stage} kanji: {''.join(missing)}")
    if not kanji:
        print("KanjiDic2 not found; kanji_<stage>.json not regenerated", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
