# 日本語の世界 — Art Bible

Visual source of truth. Derived from `docs/CONCEPT.md` (do not edit that; change this). v0.1,
written before any screen exists: every number is a starting value to check against real
screens and then lock. Section 2 (Phase 1 UI) is the load-bearing part.

---

## 1. Visual identity

**One line:** *a small Japanese town at golden hour — warm, calm, unhurried, low-poly.*

The player is going to spend hours reading. Everything visual exists to make reading
comfortable and to make progress feel earned and gentle; the look must never compete with the
text. The concept's three principles translate visually as: **Japanese-first** — Japanese text
is always the largest, highest-contrast element, English smaller, secondary colour, never bold;
**mastery over memorisation** — progress is slow continuous fills (bars, rings), never confetti,
rank-ups are the one celebration; **communication over scores** — numbers are quiet (caption
size, secondary colour), faces, places and sentences are loud.

**Mood references (describe, do not copy):** late-afternoon light on a quiet shopping street;
washi paper and ink; the flat-shaded, chunky, friendly KayKit proportions (big heads, short
limbs, bevelled edges, one small gradient atlas per pack, no normal maps).

**Palette logic:** warm paper neutrals for surfaces, one warm accent (persimmon, 柿) for
actions, cool colours for information — "do something" is warm, "read something" is calm.
Phase 2 lighting follows the same logic: a warm low sun against a cool sky.

---

## 2. Phase 1 UI direction

### 2.1 Fonts

Ship fonts in the repo under `game/assets/fonts/`. All candidates are SIL Open Font License
1.1 (free to bundle, modify and redistribute; ship the licence file beside the font).

| Role | Font | Weights to bundle | Why |
|---|---|---|---|
| **Primary UI and body (default)** | **Noto Sans JP** | Regular 400, Medium 500, Bold 700 | Complete JIS coverage (all JLPT kanji and beyond), excellent hinting at 22–32 px, Latin and digits included so one family covers mixed text. |
| Headings / display (optional) | Zen Kaku Gothic New | Medium 500, Bold 700 | Slightly rounder, friendlier than Noto at 30 px+; same vertical metrics class, so it mixes cleanly. Only adopt if Noto headings feel too corporate in real screens. |
| Accessibility alternative (user toggle) | BIZ UDPGothic | Regular 400, Bold 700 | Universal-design gothic by Morisawa; most legible option for learners who struggle to tell similar kanji apart (e.g. 末/未, 徴/微). Offer as a settings toggle, not the default. |

Rejected for primary use: M PLUS 1p / 2 (good, but Noto's kanji are clearer at our base size
and its glyph set is fuller); any mincho/serif for body (too thin at desktop sizes). A mincho or
Klee One (also SIL OFL) may be used **only** for decorative Phase 2 shop signs, never UI text.
Bundle **static** weight files, not the variable font (smaller, simpler rendering); MSDF **off**
for CJK (it loses stroke detail in dense kanji), hinting Light, subpixel positioning Auto.

### 2.2 Japanese typography rules

The single most important part of this document: a language app whose kanji cannot be read
has failed regardless of anything else.

1. **Minimum base size for any text containing kanji: 22 px** at 100 % UI scale; default body
   24 px. No captions, tooltips or table cells below 22 px if they hold a kanji. Kana-only or
   Latin-only text may go to 18 px.
2. **Furigana (ruby) is 50 % of its base size** (24 px base → 12 px ruby; 22 px base → 11 px
   ruby). Never below 11 px. Ruby uses Regular weight even when the base is Bold.
3. **Ruby gap:** 2 px between the base glyph box top and the ruby glyph box bottom. Ruby is
   centred over its base (中付き); ruby wider than its base overhangs symmetrically rather
   than spreading the base text.
4. **Line height:** lines carrying ruby use 1.9 × base (24 px → 46 px); kana-only or Latin
   lines use 1.6 × base. Never mix the two inside one paragraph.
5. **Paragraph width:** 32–40 full-width characters per line (at 24 px: a ~800–960 px
   column). Longer lines make the eye lose the ruby.
6. **Letter spacing 0, no justification.** A line break never separates a kanji from its
   ruby; apply 禁則処理 (no line begins with 。、」） or small kana).
7. **No italics, no fake bold.** Emphasis is Medium weight, colour (`text-primary` vs
   `text-secondary`), or a 2 px underline in the primary accent.
8. **English support text is 0.83 × the Japanese base** (24 px JP → 20 px EN), Regular weight,
   `text-secondary` colour, placed below or to the right, never above the Japanese.
9. **Furigana density follows the assistance mode** (Japanese-only mode hides ruby for kanji
   at "Proficient" or above), but the layout always reserves ruby height so lines never jump.
10. **Punctuation and numerals:** full-width punctuation in Japanese runs; half-width Arabic
    numerals (XP 100, 3日). Never the full-width Latin alphabet.

Note: Godot 4.7's `RichTextLabel` has no ruby tag; ruby needs a custom control built to these rules.

### 2.3 Type scale

| Token | Size | Weight | Line height | Use |
|---|---|---|---|---|
| `display` | 44 px | Bold | 1.5 | Stage name on the dashboard, headword in a dictionary entry |
| `h1` | 36 px | Bold | 1.5 (1.9 with ruby) | Screen title |
| `h2` | 30 px | Medium | 1.5 (1.9 with ruby) | Section title, card title |
| `body-l` | 26 px | Regular | 1.9 with ruby | Example sentences, conversation lines, sentence-builder result |
| `body` | 24 px | Regular | 1.9 with ruby / 1.6 without | Default |
| `label` | 22 px | Medium | 1.6 | Buttons, chips, table headers — the floor for kanji |
| `caption` | 20 px | Regular | 1.5 | Kana/Latin/digits only: "100 XP", dates, counters |
| `ruby` | 50 % of base | Regular | — | Furigana |

### 2.4 Colour palette — light theme (default)

| Token | Hex | Use |
|---|---|---|
| `bg` | `#FBF6EC` | Window background (warm paper) |
| `surface` | `#FFFDF8` | Cards, panels, inputs |
| `surface-alt` | `#F3EBDC` | Table stripes, inactive tabs, chip backgrounds |
| `border` | `#E3D8C3` | 1 px hairlines, card outlines |
| `text-primary` | `#2B2520` | All Japanese text (contrast on `bg` ≈ 13:1) |
| `text-secondary` | `#6B6159` | English support text, captions, placeholders (≈ 5.6:1 on `bg`) |
| `text-disabled` | `#A69C91` | Disabled controls only, never for content |
| `primary` | `#C4521F` | Persimmon. Primary buttons, links, active tab, focus of attention (white text on it ≈ 4.6:1) |
| `primary-hover` | `#A8441A` | Hover / pressed |
| `primary-tint` | `#FBE9DD` | Selected rows, placed word tiles, highlighted sentence |
| `correct` | `#2F7D5B` | Correct answer, mastered state, threshold met |
| `correct-tint` | `#E1F1E8` | Correct card background |
| `incorrect` | `#B83A4B` | Wrong answer, lapse, threshold not met. A cool crimson so it cannot be confused with `primary` |
| `incorrect-tint` | `#F7E2E5` | Wrong card background |
| `neutral` | `#3A6EA5` | Information, "check your answer", hints, neutral badges, keyboard focus ring |
| `neutral-tint` | `#E2ECF6` | Info banner background |
| `warning` | `#B8860B` | Review overdue, streak at risk |

Every feedback colour is paired with a glyph or label (2.8); colour is never the only signal.

### 2.5 Six skill colours

Used for skill bars, rings, chips and the skill icon. `fill` is for bars/chips/icons; `ink` is
the darkened variant to use whenever the colour is applied to text on a light surface
(all `ink` values reach ≥ 4.5:1 on `surface`).

| Skill | fill | ink | Mnemonic |
|---|---|---|---|
| 語彙 vocabulary | `#E0A526` | `#7A5A0E` | 山吹 gold — collecting |
| 文法 grammar | `#3A6EA5` | `#2A5280` | 藍 indigo — structure |
| 読解 reading | `#2F7D5B` | `#245F45` | 常磐 evergreen — steady |
| 聴解 listening | `#7B5EA7` | `#5C4580` | 藤 wisteria — sound |
| 会話 conversation | `#D65D7A` | `#A23A54` | 撫子 pink — people |
| 漢字 kanji | `#8B5E3C` | `#67432A` | 茶 tea brown — ink and brush |

The six are spaced around the hue wheel and differ in lightness so bars stay distinguishable
under deuteranopia; bars still always carry their kanji label and icon. `文法` deliberately
shares its hue with `neutral` (grammar explanations are "information").

### 2.6 Dark theme tokens

Same structure, warmer than a typical dark theme (no pure black, no blue-grey).

| Token | Hex |
|---|---|
| `bg` / `surface` / `surface-alt` / `border` | `#1C1917` / `#26221F` / `#302B27` / `#3E3733` |
| `text-primary` / `text-secondary` / `text-disabled` | `#F3EDE4` / `#B5ABA0` / `#6E655D` |
| `primary` / `primary-hover` / `primary-tint` | `#E8824F` (dark text `#1C1917` on it) / `#F09A6E` / `#3F2A1E` |
| `correct` / `correct-tint` | `#5BBF8A` / `#1E3A2C` |
| `incorrect` / `incorrect-tint` | `#E26A79` / `#3F2228` |
| `neutral` / `neutral-tint` | `#7FA7D9` / `#1F2D3E` |
| `warning` | `#E0B341` |
| skill fills | 語彙 `#F0BE4A` · 文法 `#6A9AD0` · 読解 `#5BBF8A` · 聴解 `#A58BD0` · 会話 `#E8809A` · 漢字 `#B88A64` |

In dark theme the skill `fill` doubles as `ink` (all ≥ 4.5:1 on `#26221F`). Light theme is
built first and is the default; dark theme is a user toggle, not an auto-switch.

### 2.7 Spacing, shape, elevation

- **Spacing scale (4-px base):** `4, 8, 12, 16, 24, 32, 48, 64`. Card padding 24; card gap
  16; section gap 32; page margin 48 (24 below 1280 px width).
- **Corner radius:** cards 12, buttons/inputs/word tiles 10, chips pill (999), bars 6.
- **Borders:** 1 px `border` on cards and inputs; in dark theme borders are the only
  separation (no shadows).
- **Elevation (light only):** cards `0 2px 8px rgba(43,37,32,0.08)`; dragged tile
  `0 6px 16px rgba(43,37,32,0.16)`; modals `0 12px 32px rgba(43,37,32,0.20)` over a 40 %
  `#2B2520` scrim. Nothing else casts a shadow.
- **Layout:** 12-column grid, 1280 × 800 minimum, 1920 × 1080 design size. Dashboard is two
  columns (skills + counters left, recommended activity right); every study screen is one
  centred column (max 960 px) to keep line lengths in range.

### 2.8 Components

**Buttons.** Min height 48 px, horizontal padding 24, `label` text (22 px Medium). Primary:
`primary` fill, white text. Secondary: `surface` fill, 1.5 px `primary` border and text.
Tertiary: `primary` text, underline on hover. Destructive: `incorrect` fill. Disabled:
`surface-alt` fill, `text-disabled`. Focus: 2 px `neutral` ring, 2 px offset (keyboard
navigation matters on desktop). Labels are Japanese; an English gloss goes in a tooltip.

**Cards.** `surface`, radius 12, padding 24, title `h2`, body `body`. A card is one idea
(one dictionary entry, one grammar point, one quest). Never nest cards.

**Word tiles (sentence builder).** Height 56 px (room for ruby), `body` text with ruby,
`surface` fill, 1.5 px `border`, radius 10. States: idle · hover (border `primary`) ·
dragging (elevated, 1.02 scale) · placed (`primary-tint`) · distractor revealed
(`surface-alt`, `text-secondary`). Particle tiles are the same size as word tiles.

**Skill bars.** 12 px tall, radius 6, track `surface-alt`, fill in the skill colour, kanji
label left (`label`), percentage right (`caption`, `text-secondary`); the threshold is a 2 px
`text-primary` tick that turns `correct` when reached.

**Mastery rank (Unseen → Mastered).** Six 10 px circles, 4 px gap: empty `border` ring →
filled `primary`; Mastered fills the last one `correct`. No stars, no medals.

**Feedback marks.** Correct = `○` (maru), incorrect = `✕` (batsu), partial credit
(grammatical but unnatural) = `△` in `warning` — the Japanese classroom convention, not ✓ / ✗.

**Conversation lines.** Speaker chip (`label`, `surface-alt`), line in `body-l` with ruby, NPC
lines left-aligned, player choices as stacked full-width secondary buttons (12 px gaps); the
chosen line re-renders as a `primary-tint` card.

### 2.9 Iconography

- Line icons, 2 px stroke, rounded caps, 24 px default (32 px in the sidebar) on a 24-grid
  with 2 px safe margin; single colour (`text-primary`, `text-secondary` or a skill colour);
  filled variants only for the active navigation item. No emoji anywhere in UI.
- Source: Tabler Icons (MIT) or Lucide (ISC) for generic UI; six skill icons drawn in-house
  to the same grid — 語彙 (tag/book), 文法 (three joined nodes), 読解 (open book), 聴解
  (headphones), 会話 (two speech bubbles), 漢字 (brush stroke).
- Icons sit left of their label, 8 px gap; icon-only buttons need a tooltip and 40 × 40 px.

### 2.10 Motion

Motion communicates state, never entertains. All durations ≤ 200 ms, with one exception.

| Event | Duration | Curve | Shape |
|---|---|---|---|
| Hover / focus colour | 100 ms | ease-out | Colour only |
| Screen change | 150 ms | ease-out | Cross-fade + 16 px slide in the direction of navigation |
| Correct answer | 120 ms | ease-out | Card background fills `correct-tint`, `○` fades in, 1.00 → 1.02 scale and back. No confetti, no particles. |
| Incorrect answer | 150 ms | ease-in-out | Horizontal shake ±4 px, 2 cycles, settles exactly in place. **No bounce, no overshoot, no screen flash, no red full-screen tint.** Then the `✕` and the explanation fade in (100 ms). |
| Neutral / info | 100 ms | linear | Fade only |
| Word tile placed | 150 ms | ease-out | Moves to slot; no spring |
| Skill bar update | 200 ms | ease-in-out | Fill grows; the percentage number counts up in the same time |
| **Rank-up / stage unlock (exception)** | up to 400 ms | ease-out | Circle fills, a 1.05 scale pulse and a single ring expanding from the mark. This is the only celebration in the game; keep it rare. |

A "reduce motion" setting turns every entry into a 0 ms cut except the rank-up (150 ms fade).
Nothing in the UI loops or idles: no pulsing buttons, no breathing highlights.

---

## 3. Phase 2 world direction

### 3.1 What the packs in the folder give us (gltf variant only)

| Pack | Use it for |
|---|---|
| **KayKit Adventurers 2.0** | Player avatar and NPC bodies (11 rigged characters on Rig_Medium, own animation set). Re-colour via the atlas to distinguish NPC registers (see 3.4). |
| **KayKit Skeletons 1.1** | Not tonally right for a calm town; keep for a seasonal event (お盆 / Halloween) or a 試験モード "exam dungeon" — otherwise unused. |
| **KayKit Dungeon Pack 1.1** | Stone floors and paths, walls, stairs, columns, doors, barrels, crates, shelves, torches, fences. Reads well as interiors: 図書館 library stacks, 学校 corridor, 会社 storage, castle-ish parts of the 都会 city. |
| **KayKit Forest Nature Pack 1.0** | All greenery: street trees, park, riverbank, rocks, grass, flowers, bushes, stumps. Enough to make a town block feel alive. |
| **Universal Animation Library 1 & 2 (Quaternius)** | Humanoid clips that KayKit does not ship: sit, talk, wave, bow, point, look-around, idle variants. Retargeted onto Rig_Medium (3.4). |

### 3.2 What is missing, and the honest answer

**There is no Japanese town kit in the folder.** No shop fronts, tiled roofs, sliding doors,
station, vending machines, noren or utility poles — precisely the things that make a town read
as Japanese. Phase 2 cannot be assembled from the current packs alone. Plan:

1. **Greybox first** (CSG / plain `MeshInstance3D` boxes, one flat `surface-alt` material).
   Block out 自宅, 学校, 商店街, 駅, レストラン, 会社, 図書館 at true scale (shop front 6–8 m
   wide, eaves at 3 m, two storeys ≤ 7 m), dressed with Forest trees and Dungeon props so the
   pacing already feels finished. NPC conversations are playtested on the greyboxes.
2. **Add free CC0 kits later** — confirm names and licence on the author page before
   downloading; this list is from memory, not verified:
   - KayKit (kaylousberg.itch.io): "City Builder Bits", "Furniture Bits", "Restaurant Bits"
     style packs — same atlas style as Adventurers, mix without re-texturing.
   - Kenney (kenney.nl): "City Kit (Suburban / Commercial / Roads)", "Furniture Kit", "Food
     Kit", "Train Kit" (for 駅) — flat-shaded, needs a palette pass to our warm atlas (4.3).
   - Quaternius (quaternius.itch.io / quaternius.com): "Ultimate Buildings / Furniture / Food /
     Nature" families — leaner proportions than KayKit; keep to props and interiors.
3. **Model the Japanese signature set in-house** (10–20 props in KayKit style, one small
   gradient atlas): 入母屋 / 切妻 tiled roof modules, 格子 lattice window, 引き戸 sliding door,
   暖簾, 自動販売機, 電柱, 郵便ポスト, 駅 sign, 鳥居, 石灯籠, 提灯. Placed on generic modular walls,
   this set is what makes the town Japanese — the only bespoke 3D art the project needs, and
   the first hand-made or outsourced batch.

### 3.3 Lighting and environment

- One `DirectionalLight3D`, colour `#FFD9A8`, energy ~1.2, elevation 20–25° (long, soft
  shadows), from the south-west so street-facing shop fronts catch the light.
- `ProceduralSkyMaterial`: sky top `#8FB8E0`, horizon `#F5D2A6`; ambient energy ~0.6 so
  shadows stay readable. Light fog `#F2DDC2`, very low density — a depth cue, not mood.
- Tonemap ACES; no bloom on text-bearing scenes, no SSAO, no screen-space reflections.
- Time of day is fixed at golden hour for the first world release.

### 3.4 Characters

- Player and NPCs use the Adventurers rigs. NPC register (friend / elder / staff / teacher /
  professional) is shown by atlas recolour and one prop (apron, briefcase, cane, book) —
  never by scale. Elders walk slower; staff idle with hands together. No facial rigs.
- Animations: KayKit's own Rig_Medium clips for locomotion; conversation and everyday
  gestures (sit, talk, wave, bow, look-around) from the Universal Animation Library,
  retargeted via the glTF importer's **Skeleton3D > Retarget > Bone Map** with
  `SkeletonProfileHumanoid`. Rig_Medium bone names do not auto-map: build the bone map by
  hand once, save it as `bone_map_rig_medium.tres`, reuse it on every KayKit character
  import, and re-check it whenever a pack is updated.
- A conversation in the 3D town opens the Phase 1 conversation UI (2.8) over the scene;
  the world is the stage, the UI is the dialogue. The camera does not move while talking.

---

## 4. Asset standards

### 4.1 Formats

- **3D: glTF only** (the `gltf/` folder of each pack as shipped; never fbx, fbx(unity) or obj).
- **Textures:** PNG, one atlas per pack (KayKit's own); in-house props share one atlas
  `env_jp_atlas.png` built to the same gradient-strip layout.
- **Fonts:** TTF/OTF static instances with their OFL file beside them.
- **UI art:** SVG for icons; PNG at 1× and 2× for anything raster.

### 4.2 Naming and location

Pack files keep their original filenames inside `game/assets/<pack>/` so re-downloads diff
cleanly. Everything we author follows `[category]_[name]_[variant]_[size].[ext]`, lowercase
snake_case ASCII (Japanese goes in scene content, not paths): `env_shopfront_a_large.gltf`,
`prop_vending_machine_01.gltf`, `char_npc_elder_a.tscn`, `anim_bow_polite.res`,
`ui_icon_skill_vocab_24.svg`, `ui_btn_primary_hover.png`, `fx_rankup_ring_small.tres`,
`fnt_noto_sans_jp_regular.ttf`. Wrapper scenes carry our names; the pack mesh keeps its own.

### 4.3 Scale and style match

- **1 Godot unit = 1 metre.** Character height on import 1.6–1.8 m; set the import scale
  once per pack, never scale individual meshes. Environment modules snap to 1 m / 0.5 m.
- Materials: albedo only, roughness 1.0, metallic 0.0, no normal maps; emission only on
  lanterns and the vending machine (`#FFD9A8`, low energy).
- Other authors' kits (Kenney, Quaternius) get their palette texture swapped for one in our
  warm range before placement.

### 4.4 Godot import settings

Set once per file type via import defaults where possible; commit the `.import` files.

- **glTF environment:** Root Type `Node3D`; Generate LODs **on**; Lightmap UV **on** for
  static modules only; Skins off; Animation > Import **off**.
- **glTF characters:** Import as Skeleton; Use Named Skins **on**; Animation > Import **on**,
  FPS 30, loop mode per clip (idle/walk loop, bow/wave one-shot); Retarget > Bone Map =
  `bone_map_rig_medium.tres`; Remove Immutable Tracks on.
- **Atlas textures:** Compress **Lossless**; Mipmaps **off**; filter **Nearest** (gradient
  atlases bleed between swatches under linear filtering); sRGB on.
- **Fonts:** MSDF off; Hinting Light; Subpixel Positioning Auto; Antialiasing Grayscale;
  preload the sizes in 2.3 to avoid first-use stutter.

---

## 5. Do-not list

1. Do not render any text containing kanji below 22 px, or furigana below 11 px.
2. Do not use italics, fake bold, full-width Latin, or emoji in the UI.
3. Do not use colour as the only feedback signal; always pair with ○ / ✕ / △ or a label.
4. Do not bounce, spring, flash or tint the screen on a wrong answer.
5. Do not animate anything in the UI for longer than 200 ms except the rank-up (≤ 400 ms).
6. Do not place English above or larger than the Japanese it supports.
7. Do not use pure black (`#000000`) or pure white (`#FFFFFF`) anywhere in either theme.
8. Do not import fbx/obj variants, normal maps, or prop textures larger than 1024²; do not
   scale meshes to fix proportions (fix the import scale per pack).
9. Do not copy characters, signs, logos, maps or text from any existing game or real brand;
   shop names and signage are original. No Skeletons in the everyday town.
10. Do not add a visual element that competes with the sentence currently being read.
