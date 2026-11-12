# 日本語の世界 — LearnJapaneseGame

A Japanese-first language-learning RPG. You level up from N5 to N1 and on to Mastery by proving
proficiency across six skills (語彙・文法・読解・聴解・会話・漢字), not by grinding XP. Every kanji
carries furigana, every word has an original Japanese definition first and a short English
explanation second, and English assistance shrinks as you advance.

Built with **Godot 4.7** and **GDScript**. Word data is baked from JMdict and KANJIDIC2 and
hand-curated.

## What's in the game

| Screen | What it does |
|---|---|
| ホーム Dashboard | Stage, six skill bars against the gate thresholds, streak, counters, today's quests, the recommended next activity |
| 町 Town | A walkable low-poly 3D town (KayKit assets). Talk to people at 8 locations that unlock by stage |
| かな Kana | Hiragana and katakana rounds, including yōon, with audio |
| 辞書 Dictionary | 1,539 words across N5–Mastery, search by kana, kanji, romaji or English. 学習する adds a word to reviews within a daily budget |
| 復習 Review | Leitner spaced repetition: recognition, typed recall, kanji reading and usage questions; missed words return in the same session |
| 漢字 Kanji | The stage's kanji (103 at N5) with readings, meanings, stroke counts and the words that use them |
| 文法 Grammar | 127 grammar lessons, each with an explanation and a 6-question quiz |
| 文を作る Sentence builder | Word tiles with distractors in three tiers, particle-specific feedback, hints |
| 会話 Conversation | 17 scenarios with 正解 / 惜しい / 不正解 answers, spoken NPC lines, and an optional typed-answer mode |
| 聴解 Listening | Word and sentence listening with the system Japanese voice, plus shadowing with your microphone |
| 試験 Assessment | The stage gate exam, a daily 10-question check, and practice sittings |
| 設定 Settings | English assistance, light/dark theme, an accessibility font, voice and speed, data, credits |

How progress works is specified in [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).

## Run it

1. Download Godot 4.7.2 (standard build) from https://godotengine.org/download.
2. Open Godot, click **Import**, pick `game/project.godot`, then press **F5**.

Or from a terminal:

```bash
godot --path game
```

Listening practice needs a Japanese text-to-speech voice installed in your operating system. On
Windows: Settings › Time & language › Speech › Add voices › Japanese. Without one, the listening
screen explains this and the listening exam section is waived.

Save data lives in Godot's user directory (`%APPDATA%\Godot\app_userdata\` on Windows).

## Test it

```bash
godot --headless --path game --import
godot --headless --path game --script res://tests/test_runner.gd
godot --headless --path game --script res://tests/test_world.gd
python tools/validate_content.py game/content
python tools/check_ui_text.py game/scripts game/world
```

The import is needed once per fresh checkout. Every command exits non-zero on failure;
CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs all of them.

## Build releases

Push a tag such as `v0.2.0` and [release.yml](.github/workflows/release.yml) exports Windows,
Linux and Web builds as workflow artifacts. The Web build can be uploaded to itch.io as an HTML5
game. Presets live in `game/export_presets.cfg`.

## Add content

Read [docs/CONTENT_GUIDE.md](docs/CONTENT_GUIDE.md) first. In short:

- Words go in `tools/wordlists/<stage>/*.tsv`; run `python tools/check_tsv.py <file>`, then
  `python tools/bake_content.py`.
- Grammar, sentence prompts, scenarios, reading passages and anchor sentences are JSON in
  `game/content/`.
- Every kanji is written as `{漢字|かんじ}` so the game can draw its reading.

## Repository layout

```
docs/            CONCEPT.md (source), GAME_DESIGN.md (rules), ART_BIBLE.md (visuals),
                 CONTENT_GUIDE.md (authoring), adr/
game/            the Godot project
  content/       baked and authored JSON, per stage
  scripts/core/  pure rules: Mastery, Srs, Quests, Recommender, ExamBuilder, SentenceCheck,
                 AnswerMatch, Romaji, Furigana, Speech
  scripts/autoload/  ContentDB (content) and Progress (save state)
  scripts/ui/    UITheme, FuriganaLabel, TileButton, ScreenBase, Toast
  scripts/screens/   one script per screen
  world/         the 3D town
  tests/         headless test runners
  assets/        fonts, icons, KayKit glTF files, ASSETS.md manifest
tools/           Python content pipeline and checks
```

## Licences

Code and original content: MIT ([LICENSE](LICENSE)). Dictionary data derived from JMdict and
KANJIDIC2 is © EDRDG under CC BY-SA 4.0. KayKit assets are CC0. Fonts are SIL OFL 1.1. Icons are
Tabler (MIT). Full attribution: [game/assets/ASSETS.md](game/assets/ASSETS.md).
