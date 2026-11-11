#!/usr/bin/env python3
"""Validate the game's content JSON files. Exits non-zero on the first schema problem.

Usage: python tools/validate_content.py game/content
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

FURIGANA = re.compile(r"\{([^|{}]+)\|([^|{}]+)\}")
KANJI = re.compile(r"[一-鿿]")

errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def require(obj: dict, keys: dict[str, type], where: str) -> None:
    for key, typ in keys.items():
        if key not in obj:
            err(f"{where}: missing '{key}'")
        elif not isinstance(obj[key], typ):
            err(f"{where}: '{key}' should be {typ.__name__}")


def check_furigana_text(text: str, where: str) -> None:
    """Every kanji must sit inside a {漢字|かな} group, so the UI can always draw furigana."""
    stripped = FURIGANA.sub("", text)
    if KANJI.search(stripped):
        err(f"{where}: kanji without furigana markup in {text!r}")
    for base, reading in FURIGANA.findall(text):
        if KANJI.search(reading):
            err(f"{where}: reading contains kanji in {text!r}")


def check_kana(data: dict) -> None:
    for table in ("hiragana", "katakana"):
        rows = data.get(table)
        if not isinstance(rows, list) or len(rows) < 46:
            err(f"kana.json: '{table}' needs at least 46 rows")
            continue
        for i, row in enumerate(rows):
            require(row, {"kana": str, "romaji": str, "group": str}, f"kana.json {table}[{i}]")


def check_vocab(data: list) -> None:
    ids = set()
    for i, entry in enumerate(data):
        where = f"vocab[{i}]"
        require(entry, {"id": str, "headword": str, "reading": str, "level": str, "category": str,
                        "definition_ja": str, "english": str, "examples": list, "related": list}, where)
        if entry.get("id") in ids:
            err(f"{where}: duplicate id {entry.get('id')}")
        ids.add(entry.get("id"))
        check_furigana_text(entry.get("definition_ja", ""), f"{where}.definition_ja")
        for j, ex in enumerate(entry.get("examples", [])):
            require(ex, {"ja": str, "en": str}, f"{where}.examples[{j}]")
            check_furigana_text(ex.get("ja", ""), f"{where}.examples[{j}]")


def check_grammar(data: list) -> None:
    for i, g in enumerate(data):
        where = f"grammar[{i}]"
        require(g, {"id": str, "pattern": str, "level": str, "meaning_en": str, "explanation_ja": str,
                    "explanation_en": str, "examples": list}, where)
        check_furigana_text(g.get("explanation_ja", ""), f"{where}.explanation_ja")
        check_furigana_text(g.get("pattern", ""), f"{where}.pattern")
        for j, ex in enumerate(g.get("examples", [])):
            require(ex, {"ja": str, "en": str}, f"{where}.examples[{j}]")
            check_furigana_text(ex.get("ja", ""), f"{where}.examples[{j}]")


def check_sentences(data: list) -> None:
    for i, s in enumerate(data):
        where = f"sentences[{i}]"
        require(s, {"id": str, "level": str, "prompt_en": str, "tiles": list, "distractors": list,
                    "accepted": list, "grammar": list}, where)
        tiles = s.get("tiles", [])
        for k, acc in enumerate(s.get("accepted", [])):
            if not isinstance(acc, list):
                err(f"{where}.accepted[{k}] should be a list of tile strings")
                continue
            if sorted(acc) != sorted(tiles):
                err(f"{where}.accepted[{k}] must be a permutation of tiles")
        for t in tiles + s.get("distractors", []):
            if not isinstance(t, str):
                err(f"{where}: tile {t!r} is not a string")
            else:
                check_furigana_text(t, where)


def check_scenarios(data: list) -> None:
    for i, sc in enumerate(data):
        where = f"scenarios[{i}]"
        require(sc, {"id": str, "title_ja": str, "title_en": str, "level": str, "location": str, "turns": list}, where)
        check_furigana_text(sc.get("title_ja", ""), f"{where}.title_ja")
        for j, turn in enumerate(sc.get("turns", [])):
            tw = f"{where}.turns[{j}]"
            require(turn, {"speaker": str, "line_ja": str, "line_en": str, "options": list}, tw)
            check_furigana_text(turn.get("line_ja", ""), tw)
            check_furigana_text(turn.get("speaker", ""), f"{tw}.speaker")
            correct = 0
            for k, opt in enumerate(turn.get("options", [])):
                ow = f"{tw}.options[{k}]"
                require(opt, {"ja": str, "verdict": str, "feedback_ja": str, "feedback_en": str}, ow)
                check_furigana_text(opt.get("ja", ""), ow)
                check_furigana_text(opt.get("feedback_ja", ""), f"{ow}.feedback_ja")
                if opt.get("verdict") not in ("correct", "unnatural", "wrong"):
                    err(f"{ow}: verdict must be correct|unnatural|wrong")
                if opt.get("verdict") == "correct":
                    correct += 1
            if turn.get("options") and correct != 1:
                err(f"{tw}: exactly one option must be 'correct' (found {correct})")


CHECKS = {
    "kana.json": check_kana,
    "vocab_n5.json": check_vocab,
    "grammar_n5.json": check_grammar,
    "sentences_n5.json": check_sentences,
    "scenarios_n5.json": check_scenarios,
}


def main(argv: list[str]) -> int:
    content = Path(argv[0]) if argv else Path("game/content")
    for name, check in CHECKS.items():
        path = content / name
        if not path.exists():
            err(f"{name}: file missing")
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            err(f"{name}: invalid JSON ({exc})")
            continue
        check(data)
    if errors:
        for e in errors:
            print("ERROR", e, file=sys.stderr)
        print(f"{len(errors)} problem(s)", file=sys.stderr)
        return 1
    print(f"content OK ({len(CHECKS)} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
