# ADR-0001: Build the game in Godot 4.7 with GDScript

**Status:** Accepted
**Date:** 2026-11-10
**Deciders:** TamanegiNinja25

## Context

The concept (`docs/CONCEPT.md`) is a Japanese-first learning RPG: furigana on every kanji, a
dictionary that is a core screen, a sentence builder, scenario conversations and a proficiency
gate. The concept proposed Unity and C#, and its own roadmap says to ship the learning core as a
desktop app first and add the explorable world afterwards.

Facts on the development machine when the decision was made:

- Godot 4.7.2 (standalone) and Unity 6000.5 were both present. Node 20 and Python 3.11 were on
  the path. The `gh` CLI was not installed.
- The art assets on hand are four KayKit low-poly packs and two Quaternius animation libraries.
  Every KayKit pack ships glTF, FBX and OBJ variants.
- A previous local attempt used Kotlin and Jetpack Compose for Android; it was never pushed and
  was abandoned because an Android-only, text-only app could not grow into the 3D town.
- An earlier project (Immersion Reader) already holds an 88 MB JMdict SQLite database, a kana
  module and a tagged grammar-pattern list that can seed the content pipeline.
- One developer, learning as they go, who wants CI to build and test without a licence step.

## Decision

Build the game in **Godot 4.7 with GDScript**. The Phase 1 vertical slice is a desktop UI built
entirely from `Control` nodes in code (no `.tscn` per screen), with a custom `FuriganaLabel` for
ruby text. Content is baked to JSON by a Python pipeline (`tools/`) and loaded by the `ContentDB`
autoload; player state lives in the `Progress` autoload and is saved to `user://save.json`.
GitHub Actions imports the project headlessly and runs `tests/test_runner.gd`.

## Options considered

### A. Unity 6 + C# (the concept's proposal)

| Dimension | Assessment |
|---|---|
| Asset fit | FBX variants work, but the Library folder and meta files bloat the repo. |
| CI | Needs a licensed runner or activation step. Builds are slow. |
| Furigana | No ruby text; a custom TextMeshPro layout is required either way. |
| Tooling here | No Unity-specific agents or skills in this workspace. |

### B. Godot 4.7 + GDScript (chosen)

| Dimension | Assessment |
|---|---|
| Asset fit | glTF is Godot's native import; Godot 4 retargets Quaternius clips to KayKit rigs. |
| CI | `godot --headless --import` then `--script` runs tests with a real exit code. No licence. |
| Furigana | No ruby tag in `RichTextLabel`; `FuriganaLabel` draws it in ~150 lines. |
| Exports | Windows, Linux, macOS, Web (itch.io) and Android from one project. |
| Tooling here | Godot specialist agents and skills (UI, resources, headless testing, export). |

### C. Web (TypeScript + Three.js)

| Dimension | Assessment |
|---|---|
| Furigana | Free via the HTML `<ruby>` element. The strongest option for typography. |
| 3D town | Possible with Three.js but every tool (physics, nav, animation retarget) is hand-rolled. |
| Offline | Needs a wrapper (Tauri/Electron) for a desktop build. |

## Consequences

- Godot's default font falls back to system fonts for CJK, which is fine on Windows but not
  guaranteed elsewhere; Noto Sans JP must be bundled before the first public build
  (`game/assets/ASSETS.md`).
- Furigana is authored as `{漢字|かんじ}` markup in content JSON. `tools/validate_content.py`
  fails CI if any kanji appears outside a group, which keeps the "furigana on every kanji"
  promise honest.
- Screens are code-built, so there is nothing to merge in `.tscn` files, but designers cannot
  tweak layouts in the editor. Revisit if a second contributor joins on the art side.
- Content is small and curated (64 N5 words). Scaling to the GDD's ~700-word N5 inventory is a
  pipeline and editorial job, not an engine change.
