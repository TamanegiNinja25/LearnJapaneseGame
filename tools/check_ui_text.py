#!/usr/bin/env python3
"""Fail when a literal UI string in GDScript would show a kanji without furigana.

Checks string literals passed to UITheme.ja(), UITheme.button(), UITheme.toggle(),
UITheme.segmented([...]), UITheme.set_button_text(), TileButton.new() and UITheme.label().
Button-like helpers get furigana from UITheme.UI_RUBY automatically, so a kanji is only an error
there when the table does not cover it. UITheme.label() must never contain kanji.

    python tools/check_ui_text.py game/scripts game/world
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KANJI = re.compile(r"[々一-鿿]")
GROUP = re.compile(r"\{[^|{}]+\|[^|{}]+\}")
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
CALLS = {
    "ja": re.compile(r"UITheme\.ja\(\s*\"((?:[^\"\\]|\\.)*)\""),
    "button": re.compile(r"(?:UITheme\.button|UITheme\.set_button_text\([^,]+,|UITheme\.toggle)\(?\s*\"((?:[^\"\\]|\\.)*)\""),
    "tile": re.compile(r"TileButton\.new\(\s*\"((?:[^\"\\]|\\.)*)\""),
    "label": re.compile(r"UITheme\.label\(\s*\"((?:[^\"\\]|\\.)*)\""),
    "segmented": re.compile(r"UITheme\.segmented\(\s*\[([^\]]*)\]"),
}


def ui_ruby() -> dict[str, str]:
    src = (ROOT / "game" / "scripts" / "ui" / "ui_theme.gd").read_text(encoding="utf-8")
    block = src[src.index("const UI_RUBY"):]
    block = block[: block.index("}") + 1]
    return dict(re.findall(r'"([^"]+)":\s*"([^"]+)"', block))


def apply_ruby(text: str, table: dict[str, str]) -> str:
    if "{" in text:
        return text
    keys = sorted(table, key=len, reverse=True)
    out, i = "", 0
    while i < len(text):
        for k in keys:
            if text.startswith(k, i):
                out += "{%s|%s}" % (k, table[k])
                i += len(k)
                break
        else:
            out += text[i]
            i += 1
    return out


def bare(text: str) -> list[str]:
    return KANJI.findall(GROUP.sub("", text))


def main(argv: list[str]) -> int:
    roots = [Path(a).resolve() for a in argv] or [ROOT / "game" / "scripts"]
    table = ui_ruby()
    problems = []
    for root in roots:
        for path in sorted(root.rglob("*.gd")):
            for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
                if line.strip().startswith("#"):
                    continue
                for kind, rx in CALLS.items():
                    for m in rx.finditer(line):
                        texts = STRING.findall(m.group(1)) if kind == "segmented" else [m.group(1)]
                        for t in texts:
                            shown = apply_ruby(t, table) if kind in ("button", "segmented") else t
                            if kind == "label" and KANJI.search(t):
                                problems.append(f"{path.relative_to(ROOT)}:{n}: UITheme.label() with kanji {t!r} (use UITheme.ja)")
                            elif bare(shown):
                                problems.append(f"{path.relative_to(ROOT)}:{n}: kanji without furigana {''.join(bare(shown))} in {t!r}")
    for p in problems:
        print("ERROR", p)
    print(f"{len(problems)} UI text problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
