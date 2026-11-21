# Content pipeline

Python 3.10+, no third-party packages. Formats are defined in `docs/CONTENT_GUIDE.md`.

| Script | What it does |
|---|---|
| `bake_content.py` | Reads `wordlists/<stage>/*.tsv`, adds JMdict English glosses, writes `game/content/vocab_<stage>.json`, `kanji_<stage>.json` (from KANJIDIC2) and `kana.json`. `--report` lists stage kanji no word uses yet. |
| `bake_strokes.py` | Reads KanjiVG (`data/kanjivg.xml.gz`) and writes `game/content/strokes_<stage>.json` for the writing practice: each stage kanji's strokes as polylines in the 109 box. |
| `make_sounds.gd` | Godot script: synthesises the sound effects and the background loop (Karplus-Strong plucks on the yo pentatonic scale) into `game/assets/audio/`. Original audio. |
| `phone_smoke.py` | Installs an APK on a USB phone over the current app, launches it and checks it stays up with no script errors; saves a screenshot. |
| `make_app_icons.gd` | Godot script: builds the app and Android launcher icons from `icon/app_icon_source.png`. |
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

- **KanjiVG**: `tools/data/kanjivg.xml.gz`, the `kanjivg-<date>.xml.gz` file from
  https://github.com/KanjiVG/kanjivg/releases. © Ulrich Apel and contributors, CC BY-SA 3.0
  (http://kanjivg.tagaini.net). Only the baked strokes ship.

JMdict and KANJIDIC2 are © the Electronic Dictionary Research and Development Group, used under CC BY-SA 4.0
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
