# Content pipeline

Two scripts, Python 3.10+, no third-party packages.

## `bake_content.py`

Reads `n5_wordlist.tsv` and writes `game/content/kana.json` and `game/content/vocab_n5.json`.

If a JMdict SQLite database is available, each word is enriched with up to three English glosses
and a part of speech. The expected schema is the one produced by the Immersion Reader project:

```
entries(id INTEGER PRIMARY KEY, common INTEGER, data TEXT)   -- data is JMdict JSON per entry
forms(text TEXT, entry_id INTEGER, is_kana INTEGER)
```

Search order: `--jmdict PATH`, then `tools/data/jmdict.sqlite` (git-ignored), then
`~/Downloads/Learn Japanese/Immersion Reader/data/jmdict.sqlite`. Without JMdict the bake still
succeeds; the English field falls back to the example translation.

JMdict is © the Electronic Dictionary Research and Development Group and is used under
CC BY-SA 4.0 (https://www.edrdg.org/edrdg/licence.html). To obtain it, download the JSON build
from https://github.com/scriptin/jmdict-simplified and load it into the schema above (the
Immersion Reader's `build_dict.py` does this).

## `validate_content.py`

Checks every file in `game/content/` for required fields and, crucially, that **no kanji appears
outside `{漢字|かんじ}` markup** in any Japanese field. CI runs it; run it before committing content.

## Word list format

Tab-separated, UTF-8, header line starting with `#`:

```
headword  reading  category  jp_definition  example_jp  example_en  related
```

- `category`: noun, pronoun, verb-u, verb-ru, verb-irregular, adj-i, adj-na, expression, adverb.
- `jp_definition` and `example_jp` use furigana markup.
- `related`: comma-separated headwords (may be empty; the trailing tab may be omitted).
