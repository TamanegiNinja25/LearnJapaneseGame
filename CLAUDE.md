# CLAUDE.md — LearnJapaneseGame

Japanese-first language-learning RPG in **Godot 4.7 / GDScript**. Read `docs/GAME_DESIGN.md`
before changing any rule; it is the source of truth. `docs/CONCEPT.md` is the original concept and
is never edited. `docs/ART_BIBLE.md` holds the palette and typography rules.
`docs/CONTENT_GUIDE.md` defines every content format.

## Commands

```bash
godot --headless --path game --import                              # once per fresh checkout
godot --headless --path game --script res://tests/test_runner.gd   # game tests, exit code matters
godot --headless --path game --script res://tests/test_world.gd    # 3D town tests
python tools/validate_content.py game/content                      # content schemas + furigana
python tools/check_ui_text.py game/scripts game/world              # UI strings: no bare kanji
python tools/check_tsv.py tools/wordlists/n5/*.tsv                 # word lists (readings need JMdict)
python tools/bake_content.py --report                              # TSV + JMdict + KANJIDIC2 -> JSON
godot --path game                                                  # run the game
```

On this machine the Godot binary is `..\Godot\Godot_v4.7.2-stable_win64_console.exe` relative to
the repo. CI runs the test, validate and UI-text commands on every push.

## Architecture rules

- **Pure rules in `game/scripts/core/`** (`Mastery`, `Srs`, `Quests`, `Recommender`,
  `ExamBuilder`, `SentenceCheck`, `AnswerMatch`, `Romaji`, `Furigana`): static functions, no node
  access, no I/O. Every rule change gets a test in `game/tests/test_runner.gd`. `Speech` wraps
  the OS text-to-speech and is safe without a voice.
- **Two autoloads only.** `ContentDB` loads JSON (read-only, per stage). `Progress` owns the
  save and is the only code that mutates player state.
- **Screens are code-built** (`game/scripts/screens/*.gd` extending `ScreenBase`), routed by
  `main.gd` through `SCREENS` and opened with `go(screen, args)`. No per-screen `.tscn`.
  Register answer buttons with `set_options()` (keys 1–9) and the next button with
  `set_primary()` (Enter).
- **Furigana markup is `{漢字|かんじ}`** everywhere. Use `UITheme.ja()` for Japanese text,
  `UITheme.button()` / `toggle()` / `segmented()` for controls (they add ruby from
  `UITheme.UI_RUBY`; extend that table for new UI words), and `UITheme.label()` only for kana,
  Latin and digits. Dropdowns cannot show ruby, so do not put kanji in `OptionButton` items.
- **Japanese first, English second.** English goes through `Progress.show_english()` /
  `show_explanations()` and `UITheme.en()`; it is never larger than or above the Japanese.
- **Design tokens come from `UITheme`** (light and dark palettes). Do not hard-code colours or
  sizes in screens. After a theme change `main.gd` rebuilds the UI.
- **The 3D town (`game/world/`)** exposes `TownWorld` (signals `interact(location_id)`,
  `exit_requested`; `set_unlocked()`); `town_screen.gd` maps locations to screens.

## GDScript conventions

- Static typing everywhere; `:=` only when the right side has a declared type. Values from a
  `Dictionary`, `Variant` returns and autoload calls need an explicit type.
- Tabs for indentation, LF line endings (`.gitattributes`). `class_name` on core and UI scripts.
- Headless runner caveats: autoloads enter the tree one frame after `_initialize()`, so tests
  `await process_frame`; never use bare `assert()`; lambdas capture locals by value, so use an
  Array holder for a mutable test clock.

## Content rules

- Vocabulary is authored in `tools/wordlists/<stage>/*.tsv`, never edited in `vocab_*.json`.
  The first occurrence of a headword+reading across stages wins.
- Japanese definitions are original editorial text; English glosses come from JMdict with the
  EDRDG CC BY-SA attribution in each entry's `source`.
- Every scenario turn has exactly one `correct` option; `unnatural` means grammatical but not what
  a native would say.

## Not built (by design)

Automatic pronunciation scoring and free-composition grading need a speech recogniser or an
online model; the game is offline. Shadowing uses self-rating instead.

## Attribution

Commits written with Claude end with a `Co-Authored-By: Claude …` trailer.
