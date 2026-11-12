# Asset manifest — 日本語の世界

Rules that apply to everything below:

- **Only the files the game actually references are committed.** The source zips live
  outside the repo (`C:\Users\<you>\Downloads\Game Assets\` locally); everything else in a pack
  is re-downloadable from the author page listed here. Do not commit a whole pack.
- **glTF only.** Each KayKit pack ships `gltf`, `fbx`, `fbx (unity)` and `obj` variants; we
  import from the `gltf/` folder only. Quaternius animation libraries: import the glTF/GLB
  clips only, never the FBX.
- Pack files keep their original filenames so a re-download diffs cleanly. Our wrapper
  scenes follow the naming convention in `docs/ART_BIBLE.md` §4.2.
- Every third-party file lives under `game/assets/<pack>/`; its licence text (or a
  `LICENSE.txt` pointing at CC0 1.0 / SIL OFL 1.1) sits in the same folder.
- All 3D packs here are **CC0 1.0 Universal** (public domain dedication): no attribution is
  legally required. We credit anyway (see Attribution).

## 3D packs

| Pack | Author | Source | Licence | Import from zip | Local path |
|---|---|---|---|---|---|
| KayKit Adventurers 2.0 (Free) | Kay Lousberg | https://kaylousberg.itch.io | CC0 1.0 | `Characters/gltf/` (11 rigs, Rig_Medium animations) + the pack texture atlas | `game/assets/kaykit_adventurers/` |
| KayKit Dungeon Pack 1.1 (Free) | Kay Lousberg | https://kaylousberg.itch.io | CC0 1.0 | `Assets/gltf/` (~420 modular pieces) + atlas | `game/assets/kaykit_dungeon/` |
| KayKit Forest Nature Pack 1.0 (Free) | Kay Lousberg | https://kaylousberg.itch.io | CC0 1.0 | `Assets/gltf/` (~210 trees, rocks, plants) + atlas | `game/assets/kaykit_forest/` |
| KayKit Skeletons 1.1 (Free) | Kay Lousberg | https://kaylousberg.itch.io | CC0 1.0 | `Characters/gltf/` (5 rigs, Rig_Medium) + atlas | `game/assets/kaykit_skeletons/` |
| Universal Animation Library [Standard] | Quaternius | https://quaternius.itch.io · https://quaternius.com | CC0 1.0 | glTF/GLB clips only | `game/assets/quaternius_ual/` |
| Universal Animation Library 2 [Standard] | Quaternius | https://quaternius.itch.io · https://quaternius.com | CC0 1.0 | glTF/GLB clips only | `game/assets/quaternius_ual2/` |

### Files actually imported (3D town, `game/world/town.tscn`)

Copied unchanged from the zips (gltf variant only; `.gltf` + its `.bin` + the pack atlas, or
self-contained `.glb`). Total ≈ 4.0 MB. Each folder also holds the pack's `License.txt` (CC0).

| Pack | Zip path | Files |
|---|---|---|
| KayKit Adventurers 2.0 | `Characters/gltf/` | `Barbarian.glb`, `Knight.glb`, `Mage.glb`, `Ranger.glb`, `Rogue.glb`, `Rogue_Hooded.glb` (textures embedded) |
| KayKit Adventurers 2.0 | `Animations/gltf/Rig_Medium/` | `Rig_Medium_General.glb` (Idle_A), `Rig_Medium_MovementBasic.glb` (Walking_A, Running_A) — same skeleton names as the characters, so no retargeting |
| KayKit Forest Nature Pack 1.0 | `Assets/gltf/` | `Tree_1_A_Color1`, `Tree_2_A_Color1`, `Tree_3_A_Color1`, `Tree_4_A_Color1`, `Bush_1_A_Color1`, `Bush_2_A_Color1`, `Rock_1_A_Color1`, `Rock_2_A_Color1` (`.gltf` + `.bin` each), `forest_texture.png` |
| KayKit Dungeon Pack 1.1 | `Assets/gltf/` | `barrel_large`, `crates_stacked`, `box_small` (`.gltf` + `.bin` each), `dungeon_texture.png` |

Not imported: KayKit Skeletons, both Quaternius libraries, all fbx/obj variants, the loose
character PNGs (the `.glb` files embed them). Atlas filtering is set to Nearest at load time by
`TownActor.use_nearest_filter()` (ART_BIBLE §4.4); the `.import` files use Godot defaults.

Sub-folder names inside the zips are given from the pack layout as shipped at the time of
writing; if a pack reorganises, the rule stays "the gltf variant and its atlas, nothing else".

Shared project files that belong to no pack:

| File | Purpose |
|---|---|
| `game/assets/kaykit_adventurers/bone_map_rig_medium.tres` | Hand-built Godot bone map (Rig_Medium → `SkeletonProfileHumanoid`) used to retarget Quaternius clips onto KayKit characters. Authored by us; reused by every KayKit character import. |
| `game/assets/env_jp/` | Our in-house Japanese signature props (roofs, shoji, noren, vending machine, utility pole, …) and their atlas `env_jp_atlas.png`. Original work; project licence. |

Not yet in the folder, to be evaluated later for Phase 2 (see `docs/ART_BIBLE.md` §3.2): further
KayKit "Bits" packs (kaylousberg.itch.io), Kenney city/furniture/train kits (kenney.nl), and
Quaternius building/furniture packs (quaternius.com). Add a row here when one is adopted.

## Fonts

All fonts below are licensed under the **SIL Open Font License 1.1**: free to bundle in and
distribute with the game, including commercially; the font files may not be sold on their own;
the OFL text must ship with the font. Place each family in its own folder with its `OFL.txt`.

| Family | Weights bundled | Source | Local path |
|---|---|---|---|
| Noto Sans JP (primary UI/body) | Regular 400, Medium 500, Bold 700 (static) | https://fonts.google.com/noto/specimen/Noto+Sans+JP · https://github.com/notofonts/noto-cjk | `game/assets/fonts/noto_sans_jp/` |
| Zen Kaku Gothic New (optional headings) | Medium 500, Bold 700 | https://fonts.google.com/specimen/Zen+Kaku+Gothic+New | `game/assets/fonts/zen_kaku_gothic_new/` |
| BIZ UDPGothic (accessibility toggle) | Regular 400, Bold 700 | https://fonts.google.com/specimen/BIZ+UDPGothic · https://github.com/googlefonts/morisawa-biz-ud-gothic | `game/assets/fonts/biz_udpgothic/` |

Only Noto Sans JP is required for Phase 1; the other two are added when the corresponding
feature (heading style / legibility toggle) is built.

## Icons

| Set | Licence | Source | Local path |
|---|---|---|---|
| Tabler Icons or Lucide (pick one; do not mix) | MIT / ISC | https://tabler.io/icons · https://lucide.dev | `game/assets/ui/icons/` |
| Six skill icons (語彙 文法 読解 聴解 会話 漢字) | project | authored in-house | `game/assets/ui/icons/skill/` |

## Attribution

Ready to paste into the in-game credits screen and the README:

```
3D assets
  KayKit Adventurers, Dungeon Pack, Forest Nature Pack and Skeletons by Kay Lousberg
  (kaylousberg.itch.io) — CC0 1.0
  Universal Animation Library 1 & 2 by Quaternius (quaternius.com) — CC0 1.0

Fonts
  Noto Sans JP — Google / Noto Project, SIL Open Font License 1.1
  Zen Kaku Gothic New — Yoshimichi Ohira, SIL Open Font License 1.1
  BIZ UDPGothic — Morisawa Inc., SIL Open Font License 1.1

Icons
  Tabler Icons (MIT) / Lucide (ISC) — whichever set is adopted

All Japanese town props under game/assets/env_jp/ are original work for 日本語の世界.
```

Single-line form for store pages: *3D assets by Kay Lousberg (KayKit) and Quaternius, CC0;
fonts Noto Sans JP, Zen Kaku Gothic New and BIZ UDPGothic under the SIL Open Font License.*

## How to re-download

1. **KayKit packs** — open https://kaylousberg.itch.io, find the pack by name (Adventurers,
   Dungeon Pack, Forest Nature Pack, Skeletons), download the **Free** zip, extract to
   `Downloads\Game Assets\`. Copy only the needed `gltf/` files and the atlas into
   `game/assets/<pack>/`. Versions in use: Adventurers 2.0, Dungeon 1.1, Forest 1.0,
   Skeletons 1.1 — note any version bump here and re-check the bone map.
2. **Quaternius Universal Animation Library 1 and 2** — https://quaternius.itch.io or
   https://quaternius.com, download the Standard zips, extract, copy only the glTF/GLB
   clips actually referenced by `game/assets/quaternius_ual*/`.
3. **Fonts** — download the family from the Google Fonts page or GitHub release listed above;
   copy the static weight files named in the table plus `OFL.txt`.
4. **Icons** — download the SVG set from the project site; copy only the icons referenced by
   the UI theme.
5. Re-open the project in Godot 4.7 so the committed `.import` files re-generate the
   `.godot/imported/` cache. Do not commit `.godot/`.

If a file in `game/assets/` is not listed in this manifest or referenced by a scene, it should
not be in the repo.
