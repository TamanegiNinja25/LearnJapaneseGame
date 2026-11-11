# CLAUDE.md — LearnJapaneseGame

Japanese-first language-learning RPG in **Godot 4.7 / GDScript**. Read `docs/GAME_DESIGN.md`
before changing any rule; it is the source of truth. `docs/CONCEPT.md` is the original concept
and is never edited. `docs/ART_BIBLE.md` holds the palette and typography rules.

## Commands

```bash
godot --headless --path game --import                        # once per fresh checkout
godot --headless --path game --script res://tests/test_runner.gd   # tests, exit code matters
python tools/validate_content.py game/content               # content schema + furigana check
python tools/bake_content.py                                # TSV + JMdict -> game/content/*.json
godot --path game                                           # run the game
```

On this machine the Godot binary is `..\Godot\Godot_v4.7.2-stable_win64_console.exe` relative to
the repo. CI runs the first three commands on every push.

## Architecture rules

- **Pure rules in `game/scripts/core/`** (`Mastery`, `Srs`, `SentenceCheck`, `Furigana`,
  `Recommender`, `ExamBuilder`): static functions, no node access, no I/O. Every rule change
  gets a test in `game/tests/test_runner.gd`.
- **Two autoloads only.** `ContentDB` loads JSON (read-only). `Progress` owns the save and is the
  only code that mutates player state; it applies the pure rules and persists.
- **Screens are code-built** (`game/scripts/screens/*.gd` extending `ScreenBase`). No per-screen
  `.tscn`. `main.gd` routes by name through its `SCREENS` map.
- **Furigana markup is `{漢字|かんじ}`** everywhere: content JSON, UI labels, constants. Any Japanese
  string containing kanji must use it, because `FuriganaLabel` draws ruby from it and the
  validator fails CI on bare kanji. Use `UITheme.ja()` for Japanese text, `UITheme.label()` only
  for kana, Latin and digits.
- **Japanese first, English second.** English goes through `Progress.show_english()` /
  `show_explanations()` and `UITheme.en()`; it is never larger than or above the Japanese.
- **Design tokens come from `UITheme`** (ART_BIBLE §2). Do not hard-code colours or sizes.

## GDScript conventions

- Static typing everywhere; `:=` only when the right side has a declared type. Values pulled out
  of a `Dictionary` or returned by an autoload called dynamically need an explicit type.
- Tabs for indentation. `class_name` on every core and UI script.
- Headless runner caveats: autoloads enter the tree one frame after `_initialize()`, tests must
  `await process_frame`; never use bare `assert()` in tests.

## Content rules

- Vocabulary is authored in `tools/n5_wordlist.tsv`, never edited in `vocab_n5.json` directly.
- Japanese definitions are original editorial text; English glosses come from JMdict and carry the
  EDRDG CC BY-SA attribution in each entry's `source`.
- Every scenario turn has exactly one `correct` option; `unnatural` means grammatical but not what
  a native would say.

## Out of scope for Phase 1

Listening/TTS, free-text answers, the 3D town, N4+ content. Keep hooks (skill keys, stage list)
but do not build UI for them.

## Attribution

Commits end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` when Claude wrote
the change.
