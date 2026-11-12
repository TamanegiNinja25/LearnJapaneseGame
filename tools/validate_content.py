#!/usr/bin/env python3
"""Validate the game's content JSON. Exits non-zero on any schema problem.

    python tools/validate_content.py game/content            # every file, every stage
    python tools/validate_content.py game/content --file grammar_n4.json   # one file

Schema rules are summarised in docs/GAME_DESIGN.md §11. The one rule that matters most: no kanji
may appear outside {漢字|かな} markup in any Japanese field, so the game can always draw furigana.
This script needs no JMdict/KanjiDic2 and runs in CI.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

FURIGANA = re.compile(r"\{([^|{}]+)\|([^|{}]+)\}")
KANJI = re.compile(r"[々一-鿿]")
STAGES = ["n5", "n4", "n3", "n2", "n1", "mastery"]
LEVELS = {"n5": "N5", "n4": "N4", "n3": "N3", "n2": "N2", "n1": "N1", "mastery": "MASTERY"}
SKILLS = {"vocab", "grammar", "reading", "listening", "conversation", "kanji"}
REGISTERS = {"casual", "polite", "business", "respectful", "written"}
BLANK = "［　］"

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def require(obj, keys: dict[str, type], where: str) -> bool:
    if not isinstance(obj, dict):
        err(f"{where}: expected an object")
        return False
    ok = True
    for key, typ in keys.items():
        if key not in obj:
            err(f"{where}: missing '{key}'")
            ok = False
        elif not isinstance(obj[key], typ) or (typ is int and isinstance(obj[key], bool)):
            err(f"{where}: '{key}' should be {typ.__name__}")
            ok = False
    return ok


def ja(text, where: str) -> None:
    """Every kanji must sit inside a {漢字|かな} group."""
    if not isinstance(text, str):
        err(f"{where}: expected a string")
        return
    if KANJI.search(FURIGANA.sub("", text)):
        err(f"{where}: kanji without furigana markup in {text!r}")
    for base, reading in FURIGANA.findall(text):
        if KANJI.search(reading):
            err(f"{where}: reading contains kanji in {text!r}")
        if not KANJI.search(base):
            err(f"{where}: furigana group without kanji {{{base}|{reading}}}")
    if text.count("{") != text.count("}"):
        err(f"{where}: unbalanced braces in {text!r}")


def check_choice(q: dict, where: str, ja_fields=("prompt_ja",)) -> None:
    for f in ja_fields:
        if f in q:
            ja(q[f], f"{where}.{f}")
    opts = q.get("options")
    if not isinstance(opts, list) or not 2 <= len(opts) <= 4:
        err(f"{where}: needs 2-4 options")
        return
    for i, o in enumerate(opts):
        ja(o, f"{where}.options[{i}]")
    if len(set(opts)) != len(opts):
        err(f"{where}: options must be unique")
    a = q.get("answer")
    if not isinstance(a, int) or isinstance(a, bool) or not 0 <= a < len(opts):
        err(f"{where}: answer must be an index into options")
    if "why_ja" in q:
        ja(q["why_ja"], f"{where}.why_ja")


# ---------------------------------------------------------------- per file type

def check_kana(data, name: str) -> None:
    for table in ("hiragana", "katakana"):
        rows = data.get(table) if isinstance(data, dict) else None
        if not isinstance(rows, list) or len(rows) < 46:
            err(f"{name}: '{table}' needs at least 46 rows")
            continue
        for i, row in enumerate(rows):
            require(row, {"kana": str, "romaji": str, "group": str}, f"{name} {table}[{i}]")


def check_vocab(data, name: str, stage: str, ids: set) -> None:
    for i, e in enumerate(data):
        where = f"{name}[{i}]"
        if not require(e, {"id": str, "headword": str, "reading": str, "level": str, "category": str,
                           "definition_ja": str, "english": str, "examples": list, "related": list}, where):
            continue
        if e["id"] in ids:
            err(f"{where}: duplicate id {e['id']} ({e['headword']})")
        ids.add(e["id"])
        if e["level"] != LEVELS[stage]:
            err(f"{where}: level {e['level']} does not match file stage {LEVELS[stage]}")
        ja(e["definition_ja"], f"{where}.definition_ja")
        for j, ex in enumerate(e["examples"]):
            if require(ex, {"ja": str, "en": str}, f"{where}.examples[{j}]"):
                ja(ex["ja"], f"{where}.examples[{j}]")


def check_kanji(data, name: str, stage: str) -> None:
    for i, k in enumerate(data):
        require(k, {"kanji": str, "on": list, "kun": list, "meanings": list, "strokes": int, "words": list}, f"{name}[{i}]")


def check_grammar(data, name: str, stage: str, gids: set) -> None:
    for i, g in enumerate(data):
        where = f"{name}[{i}]"
        if not require(g, {"id": str, "pattern": str, "level": str, "meaning_en": str, "explanation_ja": str,
                           "explanation_en": str, "one_liner_ja": str, "examples": list, "items": list}, where):
            continue
        if g["id"] in gids:
            err(f"{where}: duplicate grammar id {g['id']}")
        gids.add(g["id"])
        for f in ("pattern", "explanation_ja", "one_liner_ja"):
            ja(g[f], f"{where}.{f}")
        for j, ex in enumerate(g["examples"]):
            if require(ex, {"ja": str, "en": str}, f"{where}.examples[{j}]"):
                ja(ex["ja"], f"{where}.examples[{j}]")
        if len(g["items"]) < 6:
            err(f"{where}: needs at least 6 quiz items (has {len(g['items'])})")
        for j, item in enumerate(g["items"]):
            iw = f"{where}.items[{j}]"
            if not require(item, {"ja": str, "options": list, "answer": int, "why_ja": str, "why_en": str, "kind": str}, iw):
                continue
            ja(item["ja"], f"{iw}.ja")
            if BLANK not in item["ja"]:
                err(f"{iw}: 'ja' must contain the blank {BLANK}")
            if item["kind"] not in ("particle", "conjugation", "meaning", "choice"):
                err(f"{iw}: kind must be particle|conjugation|meaning|choice")
            check_choice(item, iw, ja_fields=())


def check_sentences(data, name: str, stage: str) -> None:
    for i, s in enumerate(data):
        where = f"{name}[{i}]"
        if not require(s, {"id": str, "level": str, "tier": int, "prompt_en": str, "tiles": list,
                           "distractors": list, "accepted": list, "grammar": list}, where):
            continue
        if s["tier"] not in (1, 2, 3):
            err(f"{where}: tier must be 1, 2 or 3")
        if not s["accepted"]:
            err(f"{where}: needs at least one accepted order")
        for k, acc in enumerate(s["accepted"]):
            if not isinstance(acc, list) or sorted(acc) != sorted(s["tiles"]):
                err(f"{where}.accepted[{k}] must be a permutation of tiles")
        if s["accepted"] and s["accepted"][0] != s["tiles"]:
            err(f"{where}: accepted[0] must equal tiles (tiles are the canonical order)")
        for t in s["tiles"] + s["distractors"]:
            ja(t, where)
        if set(s["distractors"]) & set(s["tiles"]):
            err(f"{where}: a distractor is also a tile")
        if "ja_hint" in s:
            ja(s["ja_hint"], f"{where}.ja_hint")


def check_scenarios(data, name: str, stage: str) -> None:
    for i, sc in enumerate(data):
        where = f"{name}[{i}]"
        if not require(sc, {"id": str, "title_ja": str, "title_en": str, "level": str, "location": str,
                            "register": str, "turns": list}, where):
            continue
        ja(sc["title_ja"], f"{where}.title_ja")
        ja(sc["location"], f"{where}.location")
        if sc["register"] not in REGISTERS:
            err(f"{where}: register must be one of {sorted(REGISTERS)}")
        unnatural = 0
        for j, turn in enumerate(sc["turns"]):
            tw = f"{where}.turns[{j}]"
            if not require(turn, {"speaker": str, "line_ja": str, "line_en": str, "options": list}, tw):
                continue
            ja(turn["line_ja"], tw)
            ja(turn["speaker"], f"{tw}.speaker")
            verdicts = []
            for k, opt in enumerate(turn["options"]):
                ow = f"{tw}.options[{k}]"
                if not require(opt, {"ja": str, "verdict": str, "feedback_ja": str, "feedback_en": str}, ow):
                    continue
                ja(opt["ja"], ow)
                ja(opt["feedback_ja"], f"{ow}.feedback_ja")
                if opt["verdict"] not in ("correct", "unnatural", "wrong"):
                    err(f"{ow}: verdict must be correct|unnatural|wrong")
                if "register" in opt and opt["register"] not in REGISTERS:
                    err(f"{ow}: unknown register")
                verdicts.append(opt["verdict"])
            if not 2 <= len(verdicts) <= 4:
                err(f"{tw}: needs 2-4 options")
            if verdicts.count("correct") != 1:
                err(f"{tw}: exactly one option must be 'correct' (found {verdicts.count('correct')})")
            if "wrong" not in verdicts:
                err(f"{tw}: needs at least one 'wrong' option")
            unnatural += verdicts.count("unnatural")
            for t, typed in enumerate(turn.get("typed", [])):
                if not isinstance(typed, str) or "{" in typed:
                    err(f"{tw}.typed[{t}]: typed answers are plain strings without markup")
        if unnatural < 2:
            err(f"{where}: a scenario needs at least two 'unnatural' options overall")


def check_passages(data, name: str, stage: str) -> None:
    for i, p in enumerate(data):
        where = f"{name}[{i}]"
        if not require(p, {"id": str, "level": str, "title_ja": str, "text_ja": str, "text_en": str, "questions": list}, where):
            continue
        ja(p["title_ja"], f"{where}.title_ja")
        ja(p["text_ja"], f"{where}.text_ja")
        if not 2 <= len(p["questions"]) <= 4:
            err(f"{where}: needs 2-4 questions")
        for j, q in enumerate(p["questions"]):
            qw = f"{where}.questions[{j}]"
            if require(q, {"q_ja": str, "q_en": str, "options": list, "answer": int, "why_ja": str}, qw):
                check_choice(q, qw, ja_fields=("q_ja",))


def check_anchors(data, name: str, stage: str) -> None:
    for i, a in enumerate(data):
        where = f"{name}[{i}]"
        if not require(a, {"id": str, "level": str, "ja": str, "en": str, "variants": list}, where):
            continue
        ja(a["ja"], f"{where}.ja")
        if len(a["variants"]) < 4:
            err(f"{where}: needs at least 4 variants")
        for j, v in enumerate(a["variants"]):
            vw = f"{where}.variants[{j}]"
            if require(v, {"type": str, "section": str, "prompt_ja": str, "prompt_en": str, "options": list,
                           "answer": int, "why_ja": str}, vw):
                if v["section"] not in SKILLS:
                    err(f"{vw}: section must be a skill key")
                check_choice(v, vw)


# ---------------------------------------------------------------- driver

def kind_of(name: str) -> tuple[str, str | None]:
    if name == "kana.json":
        return "kana", None
    m = re.fullmatch(r"(vocab|kanji|grammar|sentences|scenarios|passages|anchors)_(n5|n4|n3|n2|n1|mastery)\.json", name)
    if not m:
        return "unknown", None
    return m.group(1), m.group(2)


def validate(content: Path, only: str | None) -> None:
    files = [content / only] if only else sorted(content.glob("*.json"))
    vocab_ids: set = set()
    grammar_ids: set = set()
    sentence_grammar_refs: list[tuple[str, str]] = []
    for path in files:
        if not path.exists():
            err(f"{path.name}: file missing")
            continue
        kind, stage = kind_of(path.name)
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            err(f"{path.name}: invalid JSON ({exc})")
            continue
        if kind == "unknown":
            warnings.append(f"{path.name}: unknown content file, skipped")
            continue
        if kind != "kana" and not isinstance(data, list):
            err(f"{path.name}: expected a JSON array")
            continue
        if kind == "kana":
            check_kana(data, path.name)
        elif kind == "vocab":
            check_vocab(data, path.name, stage, vocab_ids)
        elif kind == "kanji":
            check_kanji(data, path.name, stage)
        elif kind == "grammar":
            check_grammar(data, path.name, stage, grammar_ids)
        elif kind == "sentences":
            check_sentences(data, path.name, stage)
            sentence_grammar_refs += [(path.name, g) for s in data if isinstance(s, dict) for g in s.get("grammar", [])]
        elif kind == "scenarios":
            check_scenarios(data, path.name, stage)
        elif kind == "passages":
            check_passages(data, path.name, stage)
        elif kind == "anchors":
            check_anchors(data, path.name, stage)
        if kind not in ("kana", "kanji"):
            for i, item in enumerate(data):
                if isinstance(item, dict) and item.get("level") not in (None, LEVELS.get(stage)):
                    err(f"{path.name}[{i}]: level {item.get('level')} does not match file stage")
    if not only:
        for required in ("kana.json", "vocab_n5.json", "grammar_n5.json", "sentences_n5.json", "scenarios_n5.json"):
            if not (content / required).exists():
                err(f"{required}: required file missing")
        for fname, gid in sentence_grammar_refs:
            if gid not in grammar_ids:
                err(f"{fname}: references unknown grammar id {gid}")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("content", nargs="?", default="game/content", type=Path)
    ap.add_argument("--file", help="validate only this file name inside the content folder")
    args = ap.parse_args(argv)
    validate(args.content, args.file)
    for w in warnings:
        print("warn ", w, file=sys.stderr)
    if errors:
        for e in errors:
            print("ERROR", e, file=sys.stderr)
        print(f"{len(errors)} problem(s)", file=sys.stderr)
        return 1
    print("content OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
