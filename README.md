# 日本語の世界 — LearnJapaneseGame

A Japanese-first language-learning RPG. You level up by proving proficiency across six skills
(語彙・文法・読解・聴解・会話・漢字), not by grinding XP. Every kanji carries furigana, every word
has a Japanese definition first and a short English explanation second, and the dictionary is a
core screen rather than a menu.

Built with **Godot 4.7** and **GDScript**. Content is baked from JMdict and hand-curated.

## Phase 1 (this repository today)

A desktop vertical slice of the learning core:

| Screen | What it does |
|---|---|
| ホーム Dashboard | Stage, six skill bars with gate thresholds, counters, recommended next activity, English-assistance mode |
| かな Kana trainer | Ten-card rounds of hiragana and katakana recognition |
| 辞書 Dictionary | Searchable N5 word list; opening an entry discovers the word and schedules its first review |
| 復習 Review | Spaced-repetition queue (Leitner boxes) with recognition, recall, kanji-reading and usage questions |
| 文を作る Sentence builder | Assemble sentences from word tiles with distractors, three attempts, two hints |
| 会話 Conversation | A convenience-store scenario with 正解 / 惜しい / 不正解 options and Japanese-first feedback |
| 試験 Assessment | The N5 gate exam (38 questions across five sections) plus a practice mode |

The explorable 3D town (KayKit assets) is Phase 2. See `docs/GAME_DESIGN.md` §12.

## Run it

1. Download Godot 4.7.2 (standard build) from https://godotengine.org/download.
2. Open Godot, click **Import**, pick `game/project.godot`, then press **F5**.

Or from a terminal:

```bash
godot --path game
```

Save data lives in Godot's user directory (`%APPDATA%\Godot\app_userdata\...` on Windows).

## Test it

```bash
godot --headless --path game --import
godot --headless --path game --script res://tests/test_runner.gd
python tools/validate_content.py game/content
```

The first command is needed once per fresh checkout. The runner exits non-zero on any failure;
CI (`.github/workflows/ci.yml`) runs the same three commands.

## Edit content

Words live in `tools/n5_wordlist.tsv` (headword, reading, category, Japanese definition,
example, English, related words). Kanji must be written as `{漢字|かんじ}` so the game can draw
furigana. Then:

```bash
python tools/bake_content.py
```

The bake step enriches each row with JMdict glosses when `jmdict.sqlite` is available (see
`tools/README.md`) and writes `game/content/*.json`. Grammar points, sentence prompts and
scenarios are edited directly in `game/content/`.

## Repository layout

```
docs/            CONCEPT.md (source), GAME_DESIGN.md (rules), ART_BIBLE.md (visuals), adr/
game/            the Godot project
  content/       baked JSON content
  scripts/core/  pure rules: Mastery, Srs, SentenceCheck, Furigana, Recommender, ExamBuilder
  scripts/autoload/  ContentDB (content) and Progress (save state)
  scripts/ui/    UITheme, FuriganaLabel, TileButton, ScreenBase
  scripts/screens/   one script per screen
  tests/         headless test runner
  assets/        ASSETS.md manifest; only referenced glTF files are committed
tools/           Python content pipeline
```

## Licences

Code and original content: MIT (`LICENSE`). Dictionary data derived from JMdict is © EDRDG under
CC BY-SA 4.0. KayKit and Quaternius assets are CC0. Fonts are SIL OFL. Full attribution in
`game/assets/ASSETS.md`.
