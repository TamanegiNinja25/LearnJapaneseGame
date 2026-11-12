# Content pipeline

Python 3.10+, no third-party packages. Formats are defined in `docs/CONTENT_GUIDE.md`.

| Script | What it does |
|---|---|
| `bake_content.py` | Reads `wordlists/<stage>/*.tsv`, adds JMdict English glosses, writes `game/content/vocab_<stage>.json`, `kanji_<stage>.json` (from KANJIDIC2) and `kana.json`. `--report` lists stage kanji no word uses yet. |
| `check_tsv.py` | Checks word lists: columns, categories, furigana markup (errors); reading plausibility against JMdict/KANJIDIC2, duplicates across stages, examples missing the word (warnings). |
| `validate_content.py` | Validates every JSON file in `game/content/` (CI). `--file <name>` checks one file. |
| `check_ui_text.py` | Scans GDScript for literal UI strings that would show a kanji without furigana (CI). |
| `jpcheck.py` | Shared helpers: markup parsing, stable word ids, the reading checker. |

## Dictionaries

The raw dictionaries are git-ignored; only baked JSON ships.

- **JMdict** (SQLite, schema `entries(id, common, data JSON)` + `forms(text, entry_id, is_kana)`).
  Looked up at `tools/data/jmdict.sqlite`, then
  `~/Downloads/Learn Japanese/Immersion Reader/data/jmdict.sqlite`. To build one, download the
  JSON from https://github.com/scriptin/jmdict-simplified and load it with the Immersion Reader's
  `build_dict.py`. Without JMdict the bake still works; English falls back to the example
  translation and reading checks are skipped.
- **KANJIDIC2**: `tools/data/kanjidic2-en.json.zip` from the same jmdict-simplified releases.

Both are © the Electronic Dictionary Research and Development Group, used under CC BY-SA 4.0
(https://www.edrdg.org/edrdg/licence.html).

## JLPT levels for kanji

KANJIDIC2 still uses the pre-2010 four-level JLPT field. Mapping: old 4 → N5, old 3 → N4,
old 2 split by frequency (more frequent half → N3, rest → N2), old 1 → N1.

## Word list format

Tab-separated, UTF-8, LF, one header line:

```
#headword	reading	category	jp_definition	example_jp	example_en	related
```

- `category`: noun, pronoun, verb-u, verb-ru, verb-irregular, adj-i, adj-na, adverb,
  expression, conjunction, counter, particle, prefix, suffix, interjection.
- `jp_definition` and `example_jp` use `{漢字|かんじ}` markup.
- `related`: comma-separated headwords (may be empty; the trailing tab may be omitted).
