#!/usr/bin/env python3
"""Check one or more word-list TSV files before baking.

    python tools/check_tsv.py tools/wordlists/n5/food.tsv [more.tsv ...] [--quiet]

Errors (exit 1): wrong column count, unknown category, kanji outside {漢字|かな} markup, bad
markup. Warnings: readings that JMdict/KanjiDic2 cannot confirm, headword/reading pairs missing
from JMdict, duplicates against every other word list, examples that do not contain the word.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import jpcheck as jp  # noqa: E402

COLUMNS = ["headword", "reading", "category", "jp_definition", "example_jp", "example_en", "related"]
CATEGORIES = {
    "noun", "pronoun", "verb-u", "verb-ru", "verb-irregular", "adj-i", "adj-na", "adverb",
    "expression", "conjunction", "counter", "particle", "prefix", "suffix", "interjection",
}


def read_rows(path: Path) -> tuple[list[dict], list[str]]:
    rows, errors = [], []
    header = None
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        if line.startswith("#"):
            header = line[1:].split("\t")
            if header != COLUMNS:
                errors.append(f"{path.name}:{n}: header must be #{chr(9).join(COLUMNS)}")
            continue
        cols = line.split("\t")
        if len(cols) == len(COLUMNS) - 1:
            cols.append("")
        if len(cols) != len(COLUMNS):
            errors.append(f"{path.name}:{n}: expected {len(COLUMNS)} tab-separated columns, got {len(cols)}")
            continue
        row = dict(zip(COLUMNS, cols))
        row["_line"] = n
        row["_file"] = path
        rows.append(row)
    if header is None:
        errors.append(f"{path.name}: missing #header line")
    return rows, errors


def all_wordlists() -> list[Path]:
    return sorted((jp.ROOT / "tools" / "wordlists").glob("*/*.tsv"))


def stem_for_example(row: dict) -> str:
    hw = row["headword"]
    cat = row["category"]
    if cat.startswith("verb") or cat == "adj-i":
        return hw[:-1] if len(hw) > 1 else hw
    if hw.endswith("する") and len(hw) > 2:
        return hw[:-2]
    return hw


def check_rows(rows: list[dict], others: dict[tuple[str, str], str]) -> tuple[list[str], list[str]]:
    errors, warns = [], []
    seen: dict[tuple[str, str], int] = {}
    for row in rows:
        where = f"{row['_file'].name}:{row['_line']} {row['headword']}"
        if row["category"] not in CATEGORIES:
            errors.append(f"{where}: unknown category {row['category']!r}")
        if jp.KANJI.search(row["reading"]) or not row["reading"]:
            errors.append(f"{where}: reading must be kana")
        if "{" in row["headword"] or "{" in row["reading"]:
            errors.append(f"{where}: headword/reading are plain text, no markup")
        for field in ("jp_definition", "example_jp"):
            if not row[field].strip():
                errors.append(f"{where}: empty {field}")
            for p in jp.check_text(row[field]):
                (errors if p.startswith("ERROR") else warns).append(f"{where} [{field}]: {p}")
        if not row["example_en"].strip():
            errors.append(f"{where}: empty example_en")
        key = (row["headword"], row["reading"])
        if key in seen:
            errors.append(f"{where}: duplicate of line {seen[key]} in the same file")
        seen[key] = row["_line"]
        if key in others:
            warns.append(f"{where}: also listed in {others[key]} (the earlier stage/file wins)")
        if jp.KANJI.search(row["headword"]) and jp.jmdict() is not None and not jp.jmdict_has_pair(*key):
            warns.append(f"{where}: JMdict has no entry {row['headword']}【{row['reading']}】")
        if stem_for_example(row) not in jp.plain(row["example_jp"]):
            warns.append(f"{where}: example does not contain {stem_for_example(row)!r}")
    return errors, warns


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+", type=Path)
    ap.add_argument("--quiet", action="store_true", help="hide warnings")
    args = ap.parse_args(argv)

    targets = {p.resolve() for p in args.files}
    others: dict[tuple[str, str], str] = {}
    for path in all_wordlists():
        if path.resolve() in targets:
            continue
        rows, _ = read_rows(path)
        for r in rows:
            others.setdefault((r["headword"], r["reading"]), f"{path.parent.name}/{path.name}")

    total_err, total_warn, total_rows = 0, 0, 0
    for path in args.files:
        rows, errors = read_rows(path)
        e2, warns = check_rows(rows, others)
        errors += e2
        total_rows += len(rows)
        for e in errors:
            print("ERROR", e)
        if not args.quiet:
            for w in warns:
                print("warn ", w)
        total_err += len(errors)
        total_warn += len(warns)
    print(f"{total_rows} rows, {total_err} error(s), {total_warn} warning(s)")
    if jp.jmdict() is None or not jp.kanjidic():
        print("note: JMdict or KanjiDic2 not found; reading checks were skipped")
    return 1 if total_err else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
