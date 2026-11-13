# 日本語の世界 — Game Design Document

Version 0.1 — 2026-11-10. Derived from `docs/CONCEPT.md` (do not edit that file; edit this one).
Engine: Godot 4.7, GDScript. Content: JSON baked by a Python pipeline from JMdict (CC BY-SA 4.0,
EDRDG, attribution required) and hand-curated. This document is the source of truth for
implementers of Phase 1.

---

## 1. Vision and pillars

**One line.** An RPG whose only real progression stat is the player's ability to understand and
use Japanese. Levels are gated by demonstrated proficiency; XP is for participation only.

| # | Pillar | What it means in rules | What it forbids |
|---|---|---|---|
| P1 | **Japanese-first, English-supported** (日本語優先) | Every screen is readable in Japanese alone; kanji always carry furigana; English is a toggle, never the primary text. Assistance mode shrinks automatically with stage but can always be turned back on. | UI whose primary labels are English; removing the English toggle. |
| P2 | **Mastery over memorisation** (暗記より習得) | A word is only *Mastered* when recognition, recall and usage are each proven across spaced reviews. Skill scores mix coverage and recent accuracy, so cramming decays. | Translation-match-only mastery; XP-based levelling. |
| P3 | **Communication over exam scores** (点数より会話) | Conversation (会話) is a mandatory gate skill at every stage and its threshold rises faster than any other. Scenario feedback distinguishes *grammatical* from *natural*. | Gates that can be passed by multiple-choice vocab alone. |

Where two pillars pull against each other (e.g. P1 vs onboarding clarity for a complete beginner)
the tension is listed in §13 as an open question rather than silently resolved.

### MDA target aesthetics

- **Challenge** — every activity has a clear right/wrong with a reason.
- **Discovery** — the dictionary and related-word links reward curiosity.
- **Fantasy / Narrative** (later phases) — living in a Japanese town.
- **Submission** (healthy habit) — the daily review queue and quests give a reason to return.

Self-Determination Theory check: *Autonomy* = the player chooses any screen at any time; the
recommendation is advice, not a lock. *Competence* = skill bars, word ranks and explanations
after every answer. *Relatedness* = NPC scenarios (Phase 1: one; later: a town).

## 2. Player fantasy and target player

**Fantasy.** "I am becoming someone who can live in Japan." Each stage feels like moving to a
bigger town where more people can be understood. The dashboard is a passport, not a report card.

**Target player (Phase 1).** A self-directed adult beginner who already knows (or is willing to
learn in the first session) hiragana, has 10–20 minutes a day, and is bored by flashcard apps that
never ask them to *produce* a sentence. Secondary: returning learners at N4/N3 who use the
dictionary and sentence builder to patch gaps.

**Bartle coverage.** Achievers: skill bars, ranks, counters, gate exams. Explorers: dictionary
graph (related words, collocations), the "why" explanations. Competitors (later): timed 試験モード
leaderboards. Socialisers (later): NPC relationships.

## 3. Phase 1 vertical slice — desktop app

Phase 1 is a single-window desktop app with seven screens and no 3D world. The slice is
complete when a new player can go from zero to passing the N5 gate exam using only this app.

Global rules for all screens:

1. All text is Japanese with furigana ruby on every kanji; English is shown according to the
   player's assistance mode (日本語のみ / 日本語＋英語の説明 / 日本語＋翻訳 / 二か国語).
2. Every answer gives feedback within 0.5 s: colour (green 正解 / amber 惜しい / red 不正解), a one-line
   Japanese explanation, and an English line if the assistance mode allows it.
3. Every scored answer produces a **sample** `(skill, weight, correctness)` that updates the six
   skill scores (§5.2) and, where relevant, a word's mastery record (§6).
4. Back/escape always returns to the Dashboard; unfinished activities are discarded, not saved.

### 3.1 Dashboard (ダッシュボード)

| | |
|---|---|
| Purpose | Show state and tell the player what to do next. |
| Inputs | Player save file. |
| Displays | Stage (N5 初級 …), XP level and XP bar, six skill bars (語彙 文法 読解 聴解 会話 漢字) each with its gate threshold marked, counters (単語 learned ≥ Learned, 文法 points seen, 会話 completed, 学習日数 days studied, 連続日数 streak), weakest two skills, due-review count, today's daily quests with XP, and one **おすすめ** (recommended next activity) button computed by §10. |
| Outputs | Navigation to any screen. |
| Writes | `last_played`, streak update, daily quest reset at local midnight. |

### 3.2 Kana trainer (かなトレーナー)

| | |
|---|---|
| Purpose | Recognition of hiragana and katakana (46 basic + 25 dakuten/handakuten + 33 yōon = 104 per script). |
| Inputs | Kana table JSON; per-kana SRS boxes in save file. |
| Session | 20 cards. Card shows one kana (or a 2–3 kana word for yōon); player picks the romaji reading from 4 choices, or (reverse mode, unlocked at box ≥ 3) sees romaji and picks the kana. Distractors are drawn from the kana's `similar` list first (さ/き, シ/ツ, ソ/ン). |
| Success | Green, next card after 0.4 s. Box +1. |
| Failure | Red, correct answer shown with the stroke-order image, card re-queued at the end of the session. Box = max(0, box − 2). |
| Writes | `kana[char].box`, `kana[char].due`; a 読解 sample with weight 0.2 per card; XP 2 per correct card. |

Kana mastery = share of the 208 kana at box ≥ 3. The Dashboard shows it until it reaches 100%.

### 3.3 Dictionary (辞書)

| | |
|---|---|
| Purpose | Browse and search the N5 word list; the main "encounter" faucet. |
| Inputs | Vocab JSON; search string (kana, kanji, romaji or English); filters: part of speech, mastery rank, tag (挨拶, 食べ物, …). |
| Entry view | Exactly the concept's 勉強 template: headword with furigana · reading · JLPT level · part of speech · Japanese definition · English explanation (toggle) · example sentences (furigana, English toggle) · related words (links) · common combinations · synonyms / antonyms · mastery rank with the three dimension counters. Buttons: 学習する (add to study), 例文を読む (reading quiz on one example). |
| Success/failure | No scoring on browse. The 例文を読む quiz (choose the correct English meaning of an example from 3) scores 読解. |
| Writes | Opening an entry: rank Unseen → Discovered, `last_seen`. 学習する: SRS box 0, due = now (immediate review). Example quiz: 読解 sample, recognition counter of the headword +1 if correct. |

New-word budget: the Dictionary surfaces at most 10 *new* words per day in the 「今日の単語」 list;
the player may still add more manually (autonomy), but the recommender never suggests more.

### 3.4 Sentence builder (文を作ろう)

| | |
|---|---|
| Purpose | Produce grammatical, natural sentences from tiles. Serves 文法 first, 語彙 and 読解 second. |
| Inputs | Prompt JSON (§7); player's 文法 score selects difficulty tier. |
| Session | 5 prompts. Each shows the English (or Japanese paraphrase in 日本語のみ mode) and a shuffled tile tray containing the target tiles plus distractors. Player drags/taps tiles into the answer row and presses 確認. |
| Success | Accepted order (canonical or any alternative): green, the sentence is read back with furigana; if an alternative order was used, a note 「別の語順でも正しいです」. |
| Failure | Tiles in wrong positions are shaded; if the only error is a particle, the particle tile pulses and the linked grammar point's one-line rule is shown. Up to 3 attempts; after the third the answer is shown. |
| Writes | Samples per §7.3; usage counter +1 for every vocab id in the target if correct without hints; XP per §5.5. |

### 3.5 Scenario conversation (会話シナリオ)

| | |
|---|---|
| Purpose | Choose natural, register-appropriate responses. Phase 1 ships one scenario: コンビニ (convenience store), 4–6 NPC turns. |
| Inputs | Scenario JSON (§8). |
| Flow | NPC line appears with furigana (English on toggle). 2–4 option cards. Player picks one; feedback card shows the tag colour and the Japanese + English explanation; the NPC reacts according to the tag; next turn. |
| Success | 正解: NPC continues naturally. 惜しい (grammatical-but-unnatural): NPC understands but the explanation says what a native would say. |
| Failure | 不正解: NPC says 「すみません、もう一度お願いします」 and the same options return minus the chosen one; the second pick scores at most 0.5. |
| Writes | Per-turn samples (§8.3); usage counter +1 for vocab ids in a 正解 option; scenario completion count; XP 200 on completing all turns. |

### 3.6 N5 assessment (N5 昇級試験)

| | |
|---|---|
| Purpose | Proficiency gate from stage 1 to stage 2. |
| Availability | Unlocked when every mandatory skill ≥ (threshold − 15) and no cooldown active. Shown greyed with the missing skills otherwise. |
| Inputs | Assembled per §9 from vocab, grammar, prompt and scenario pools. |
| Success | Every mandatory section ≥ its threshold: stage advances, 1000 XP, certificate screen. |
| Failure | Report per section with pass/fail, three recommended activities, 24 h cooldown. |
| Writes | `assessments[]` entry; section scores feed skill scores as samples with weight 1.5; on pass `stage` += 1 and coverage recomputed against the new inventory. |

### 3.7 Spaced-repetition review (復習)

| | |
|---|---|
| Purpose | Serve due words (and kana) in the dimension they are weakest in. |
| Inputs | Save file word records; due = `due_at <= now`. |
| Session | Up to 20 items ordered by most overdue first; new (box 0) words interleaved after every 3 due items. Question type per item chosen by §6.4. |
| Success | Green, box +1, counters +1 in the tested dimension. |
| Failure | Red with explanation; box = max(0, box − 2), lapse recorded, item re-queued in the same session until answered correctly once (that re-answer does not count as a promotion). |
| Writes | Word record (rank, counters, box, due, streak, lapses), skill samples per question type (§5.3), XP 5 per correct review. |

## 4. Core loop and a 10-minute session

```
   encounter word/pattern ──► understand (dictionary, grammar note)
          ▲                            │
          │                            ▼
   unlock next stage ◄── gate exam ◄── use in conversation ◄── build sentences ◄── review (SRS)
          │                                                                          ▲
          └────────────────── skill scores rise ───────────────────────────────────────┘
```

Nested loops:

- **30 s micro-loop:** one card / one tile sentence / one dialogue turn → instant verdict + reason.
- **5–15 min meso-loop:** one activity session (20 reviews, 5 sentences, 1 scenario) → quest ticked,
  skill bar visibly moves, rank-ups announced (「勉強」が Learned になりました).
- **Macro-loop (days–weeks):** skill bars approach thresholds → exam unlocks → stage advances.
  Natural stopping point: due queue empty and daily quests done.

A typical 10-minute session:

| Minute | Activity | Why |
|---|---|---|
| 0–1 | Dashboard: see 14 due reviews, 文法 is weakest, おすすめ = 復習 | Orientation |
| 1–5 | Review 14 items (mix of recognition, recall, example-reading) | Clears the faucet backlog first |
| 5–8 | Sentence builder, 5 prompts at tier 2 | Serves weakest skill |
| 8–10 | Dictionary: 3 new words from 今日の単語, press 学習する | Feeds tomorrow's queue |

## 5. Progression model

### 5.1 Stages

| Stage | Name | Mandatory skills (Phase 1) | Content inventory |
|---|---|---|---|
| 1 | N5 初級 | 語彙 文法 読解 会話 漢字 (聴解 optional until TTS ships) | ~700 words, ~100 kanji, ~45 grammar points |
| 2 | N4 初中級 | all six | +~900 words, +~170 kanji, +~60 grammar |
| 3 | N3 中級 | all six | later phase |
| 4 | N2 中上級 | all six | later phase |
| 5 | N1 上級 | all six | later phase |
| 6 | Mastery 完全習得 | 会話-weighted; see §12 | later phase |

### 5.2 Six skill scores (0–100)

Each skill `k` keeps `perf_k` (exponential moving average of correctness, 0–1), `n_k` (sample
count) and, for inventory skills, `cov_k` (coverage).

```
on sample (k, w, c):   perf_k ← perf_k + α·w·(c − perf_k),  α = 0.08,  c ∈ {0, 0.5, 1}
                        n_k ← n_k + w
confidence_k = min(1, n_k / 30)
score_k = round(100 · (covw_k · cov_k + (1 − covw_k) · perf_k · confidence_k))
```

| Skill | covw | cov definition (current stage inventory) |
|---|---|---|
| 語彙 | 0.5 | share of stage words at rank ≥ Learned |
| 漢字 | 0.5 | share of stage kanji appearing in ≥ 1 word at rank ≥ Learned |
| 文法 | 0.5 | share of stage grammar points with ≥ 3 correct answers |
| 読解 | 0 | — |
| 会話 | 0 | — |
| 聴解 | 0 | — |

Worked example: 語彙 with 420/700 words Learned (cov 0.6), perf 0.82, n 90 → 100·(0.3 + 0.5·0.82·1) = 71.

The EMA means a skill score drifts down toward recent performance if the player only does easy
items; `α = 0.08` ≈ the last ~25 samples dominate. Samples carry `w = 1.5` from assessments.

### 5.3 Activity → skill weights

Each activity emits one sample per question for every skill with a non-zero weight.

| Activity / question type | 語彙 | 文法 | 読解 | 聴解 | 会話 | 漢字 |
|---|---|---|---|---|---|---|
| Kana card | – | – | 0.2 | – | – | – |
| Review: recognition (JP → meaning) | 1.0 | – | – | – | – | 0.3 if headword has kanji |
| Review: recall (meaning → JP) | 1.0 | – | – | – | – | – |
| Review: kanji reading (kanji form → kana) | 0.3 | – | – | – | – | 1.0 |
| Review: example reading quiz | 0.3 | – | 1.0 | – | – | – |
| Review: usage (fill the word into a sentence) | 0.5 | 0.5 | – | – | – | – |
| Grammar point quiz (particle / conjugation fill-in) | – | 1.0 | 0.2 | – | – | – |
| Sentence builder prompt | 0.2 | 0.6 | 0.2 | – | – | – |
| Scenario turn | 0.2 | 0.2 | – | – | 0.6 | – |
| Assessment section question | as the underlying type × 1.5 | | | | | |
| Listening (later phase) | – | – | – | 1.0 | – | – |

### 5.4 Gate thresholds and gate outcomes

Thresholds are game-design values, not JLPT rules. N5 values come from the concept; later
values are proposals that raise 会話 fastest (pillar P3).

| Stage exam | 語彙 | 文法 | 読解 | 聴解 | 会話 | 漢字 |
|---|---|---|---|---|---|---|
| N5 → N4 | 85 | 90 | 85 | 85 (optional in Phase 1) | 80 | 80 |
| N4 → N3 | 85 | 90 | 85 | 85 | 82 | 80 |
| N3 → N2 | 85 | 88 | 85 | 85 | 85 | 82 |
| N2 → N1 | 85 | 88 | 85 | 85 | 88 | 85 |
| N1 → Mastery | 85 | 88 | 85 | 85 | 90 | 85 |

Rules:

1. The exam button unlocks when every mandatory skill score ≥ threshold − 15.
2. Pass = every mandatory section score in the exam itself ≥ threshold (§9). Dashboard scores
   decide eligibility; exam scores decide passing.
3. On pass: `stage += 1`; `perf_k` and `n_k` carry over; `cov_k` is recomputed against the new
   inventory (scores visibly drop — the sawtooth); new content unlocks; 1000 XP; cooldown cleared.
4. On fail: 24 h cooldown; report lists failed sections and three recommended activities; no
   score penalty beyond the exam's own samples.
5. The player may re-sit a passed exam for XP only (250 XP, once per day) — it never demotes.

### 5.5 XP, levels and daily quests (participation track)

XP never substitutes for a gate. Level = `floor((1 + sqrt(1 + XP / 125)) / 2)` (i.e. level L
needs 500·L·(L−1) cumulative XP: L2 at 1 000, L5 at 10 000, L10 at 45 000).

| Daily quest (concept values) | XP | Phase 1 tracking |
|---|---|---|
| 新しい単語を10個学ぶ — learn 10 words | 100 | words moved Unseen/Discovered → Familiar today |
| 20項目を復習する — review 20 entries | 100 | review answers today |
| 文法レッスンを1つ — one grammar lesson | 150 | one grammar point quiz completed |
| 会話を聞く — listen to a conversation | 100 | disabled until TTS |
| 会話を完了する — complete a conversation | 200 | scenario completed |
| 文を5つ作る — build five sentences | 150 | sentence builder session completed |
| 毎日の確認テスト — daily assessment | 250 | 10-question mini exam (§9.4) |

Per-item XP: kana card 2, review 5, sentence 20 (10 with hints), scenario turn 15, grammar quiz
question 10. XP unlocks cosmetics and (later) town locations — never content required to pass a gate.

## 6. Vocabulary mastery

### 6.1 Ranks and dimensions

Each word record tracks three dimensions as integer correct-counters: `rec` (recognition: JP →
meaning, or kanji form → reading), `rcl` (recall: meaning/English → JP, or kana → kanji form),
`use` (usage: correct in a sentence-builder target, scenario 正解 option, or usage review). Plus
`streak` (consecutive correct reviews across all dimensions), `lapses`, SRS `box` and `due_at`.

| Rank | Promotion condition (checked after every answer, in order) |
|---|---|
| 0 Unseen | default |
| 1 Discovered | entry opened or the word appeared in any activity |
| 2 Familiar | `rec ≥ 2` |
| 3 Learned | `rec ≥ 4` and `rcl ≥ 2` |
| 4 Proficient | `rcl ≥ 4` and `use ≥ 2` and `box ≥ 4` (interval ≥ 7 d) |
| 5 Mastered | `use ≥ 4` and `box ≥ 6` (interval ≥ 30 d) and `streak ≥ 6` |

Promotion moves one rank per answer at most. A translation-match-only history (only `rec`) can
never pass Learned (pillar P2).

### 6.2 Lapse and demotion

A **lapse** = wrong answer on a review, exam, or usage question for that word (sentence-builder
and scenario mistakes count as lapses only for the word the player misplaced/misused).

On lapse: `streak = 0`, `lapses += 1`, counter of the tested dimension `= max(0, counter − 2)`,
`box = max(0, box − 2)`, and if `rank ≥ Learned` then `rank −= 1`. Floor is Familiar; the word is
never sent back to Unseen/Discovered. Because counters are reduced, the word must re-earn the rank.

### 6.3 SRS schedule (Leitner-style, one box per word)

| Box | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| Interval | immediate (same session, after ≥ 5 other items) | 4 h | 1 d | 3 d | 7 d | 14 d | 30 d | 60 d | 120 d (cap) |

```
correct, no hint:  box = min(8, box + 1)
correct with hint / partial (0.5):  box unchanged
wrong (lapse):     box = max(0, box − 2)
due_at = answered_at + interval[box]
```

Due query: `due_at <= now`, sorted by `now − due_at` descending, limit 20 per session. 「学習する」
sets box 0 so the first review is immediate (concept: first encounter → immediate review → later
that day (4 h) → next day → several days → longer).

### 6.4 Which question a due word gets

Pick the dimension with the lowest counter among those unlocked for the rank, tie → the earlier one:

| Rank | Unlocked question types |
|---|---|
| Discovered, Familiar | recognition (meaning choice from 4), kanji reading if headword has kanji |
| Learned | + recall (choose the Japanese from 4, or type kana at box ≥ 3) |
| Proficient, Mastered | + usage (fill the word into a cloze example from 4 tiles), example reading quiz |

Distractors come from the same part of speech and JLPT level; for kanji reading, from words
sharing a kanji.

## 7. Sentence builder rules

### 7.1 Prompt definition

A prompt has: `target` (ordered tile list — the canonical answer), `alternatives` (list of other
accepted tile orders), `distractors` (tiles that must not be used), `en`, `ja_hint` (Japanese
paraphrase used in 日本語のみ mode), `grammar_ids`, `vocab_ids`, `tier` (1–3), `particle_tiles`
(indices of particle tiles for the targeted feedback). Tiles are whole bunsetsu-ish chunks: a
particle is always its own tile; verbs include their ending (見ました is one tile).

Example: target `[昨日, 友達と, 映画を, 見ました]`, alternatives `[[友達と, 昨日, 映画を, 見ました]]`,
distractors `[友達に, 映画が]`, tier 2.

### 7.2 Tiers and tray composition

| Tier | Target length | Distractors | Chosen when 文法 score |
|---|---|---|---|
| 1 | 2–3 tiles | 1 | < 40 |
| 2 | 3–5 tiles | 2 | 40–69 |
| 3 | 5–7 tiles | 3 | ≥ 70 |

Distractors are authored, not generated: a wrong particle, a wrong conjugation, or a near-synonym.

### 7.3 Scoring, attempts and hints

| Outcome | Correctness `c` | XP | Usage credit |
|---|---|---|---|
| Accepted on attempt 1, no hint | 1.0 | 20 | `use += 1` for every `vocab_id` |
| Accepted on attempt 2–3 or with ≤ 2 hints | 0.5 | 10 | none |
| Not accepted after attempt 3 (answer shown) | 0 | 0 | lapse for misplaced vocab tiles |

Hint policy: hint 1 greys out all distractors; hint 2 locks the next correct tile in place. No
hint 3. Hints are free (no XP cost beyond the halved reward) — failure must stay cheap because it
is frequent.

Acceptance: the submitted sequence equals `target` or any entry in `alternatives`, compared tile
by tile. Samples: 文法 0.6, 語彙 0.2, 読解 0.2 with the outcome's `c`. If the only difference from an
accepted order is one particle tile, the feedback names the particle and shows the grammar
point's one-line rule (「と」は一緒にする相手を表します).

## 8. Conversation scenario format

### 8.1 Structure

A scenario is a list of turns. Each turn: NPC line (`ja` with ruby, `en`), 2–4 options, `next`
(turn id or `end`). Each option has `tag`, `ja`, `en`, `why_ja`, `why_en`, `register`,
`vocab_ids`, `grammar_ids`.

| Tag | Colour / label | NPC reaction | `c` |
|---|---|---|---|
| `correct` | green 正解 | continues naturally | 1.0 |
| `unnatural` | amber 惜しい (grammatical but unnatural) | understands, but the explanation says what a native would say; conversation continues | 0.5 |
| `wrong` | red 不正解 | 「すみません、もう一度お願いします」; option removed, re-choose; max `c` 0.5 on the retry | 0 |

Every turn has at least one `correct` and at least one `wrong` option; `unnatural` is optional
but every scenario must contain at least two (teaching the grammatical/natural gap, pillar P3).

Example turn (コンビニ): 店員「いらっしゃいませ！何をお探しですか？」
- 水をください — correct — 「〜をください」は丁寧なお願いの形です。/ "〜をください" is the polite way to ask for something.
- 水がいます — wrong — 「います」は生き物に使います。水は「あります」。/ います is for living things; water takes あります — and this still isn't a request.
- 水をあります — wrong — 「あります」は「〜が」と使います。お願いは「〜をください」。/ あります takes が, not を; to ask, use 〜をください.
- 水、ある？ — unnatural — 文法的には通じますが、店員にはタメ口は失礼です。/ Understandable, but casual speech to staff is rude.

### 8.2 Register tags

`casual` (タメ口) · `polite` (丁寧語 です/ます) · `business` (ビジネス敬語) · `respectful` (尊敬語/謙譲語)
· `written`. Each scenario declares the expected register; an option in the wrong register is
tagged `unnatural` at best, never `correct`. NPC lines carry their own register so later phases can
vary by location (§12).

### 8.3 Scoring and writes

Per turn: samples 会話 0.6, 文法 0.2, 語彙 0.2 with `c`. Scenario score = mean `c` over turns; the
scenario is "completed" regardless of score (200 XP once per day per scenario), and "cleared" (shown
with a star) at ≥ 0.8. `use += 1` for `vocab_ids` of a first-try `correct` option.

## 9. Assessment design

### 9.1 N5 gate exam composition (Phase 1)

| Section (skill) | Questions | Question types |
|---|---|---|
| 語彙 | 10 | 5 recognition (JP → meaning), 5 recall (meaning → JP) |
| 文法 | 10 | 6 particle fill-in, 4 conjugation fill-in (present/past/negative, です/ます) |
| 読解 | 8 | 4 example-sentence meaning, 4 short-passage questions (2 passages of 3–4 sentences) |
| 漢字 | 6 | kanji-form → reading |
| 会話 | 6 | scenario turns drawn from the scenario pool (options shuffled) |
| 聴解 | 0 in Phase 1 (optional section, auto-pass) | |

40 questions, no time limit in Phase 1 (per-question time is logged for later tuning). Items are
drawn only from content the player has at rank ≥ Discovered plus up to 20% unseen N5 items (an
N5 speaker should cope with unknown-but-level words). No item repeats across the last 3 sittings.

Pass criteria: each section's percentage ≥ its threshold (§5.4). Section results emit samples with
`w = 1.5`. On fail: 24 h cooldown. On pass: §5.4 rule 3.

### 9.2 Varied challenges on one sentence (文一つ、いろいろな問題)

The pipeline marks some example sentences as **anchors**. For an anchor such as
昨日、友達と映画を見ました。 the exam may spawn up to 6 question variants, at most 3 per sitting:

| Variant | Type | Section |
|---|---|---|
| 主語・目的語は？ — identify subject / object (tap the tile) | tap | 文法 |
| 「と」の意味は？ — meaning of と (4 choices) | choice | 文法 |
| なぜ「見ました」？ — why 見る → 見ました (4 choices: past polite / negative / …) | choice | 文法 |
| 否定の過去形に — rewrite as negative past (tiles) | tiles | 文法 |
| 同じ形で新しい文を — build a new sentence with the pattern (tiles) | tiles | 文法 + 語彙 |
| 意味は？ — choose the meaning | choice | 読解 |
| 質問に答えて — answer a related question naturally (scenario-style options) | choice | 会話 |
| (later) 聞いて選んで — hear it and choose | audio | 聴解 |

Anchor variants are also used in the daily assessment and, at tier 3, in the Sentence builder.

### 9.3 Grammar point quiz (文法レッスン)

Each grammar point has 6–10 authored fill-in items (4 choices). A lesson = read the point's
explanation + 6 items; ≥ 5 correct marks the point for coverage (`correct ≥ 3` rule in §5.2).

### 9.4 Daily assessment (毎日の確認テスト)

10 questions, 2 per mandatory skill, drawn like the gate exam but weighted toward the two weakest
skills (4 of the 10). Not a gate; samples with `w = 1.5`; 250 XP once per day.

## 10. Adaptive difficulty (Phase 1)

### 10.1 Recommended next activity

Evaluated on the Dashboard, first matching rule wins:

1. Kana mastery < 90% → **かなトレーナー**.
2. Due reviews ≥ 10 → **復習**.
3. Gate exam unlocked (all mandatory skills ≥ threshold − 15), not on cooldown, and the daily
   assessment today scored ≥ 80% → **N5 昇級試験**.
4. Daily assessment not done today and the player has ≥ 50 words at rank ≥ Familiar → **毎日の確認テスト**.
5. Otherwise pick the weakest mandatory skill by `gap = threshold − score` (largest gap) and map:
   語彙 → 辞書 (今日の単語, if new-word budget remains; else 復習) · 文法 → 文を作ろう (or a grammar
   lesson if the lowest-coverage grammar point has < 3 correct) · 読解 → 復習 with example-reading
   questions forced · 会話 → 会話シナリオ · 漢字 → 復習 with kanji-reading questions forced.
6. Tie-break / anti-repetition: if the mapped activity was the last two recommendations, take the
   second-largest gap.

### 10.2 Within-activity difficulty

- Sentence builder tier from 文法 score (§7.2); after 3 consecutive first-try successes in a
  session, tier +1 for the rest of the session; after 2 consecutive failures, tier −1.
- Review question type by weakest dimension (§6.4); kanji reading forced when 漢字 is the weakest skill.
- Grammar point selection: lowest `correct` count first; prerequisites (`requires`) must have ≥ 3 correct.
- Multiple-choice option count: 3 while a skill score < 30, otherwise 4.

## 11. Content data model

The authoritative schemas, with examples, are in `docs/CONTENT_GUIDE.md`; `tools/validate_content.py`
enforces them in CI. This section records the shape and the decisions behind it. (The first draft
of this section proposed `漢字[かんじ]` ruby, JMdict-seq ids and different field names; the
implementation below replaced it, 2026-11-12.)

**Furigana markup.** Every Japanese field uses inline `{漢字|かんじ}` groups. No kanji may appear
outside a group — the validator fails CI otherwise, and `tools/check_ui_text.py` applies the same
rule to literal UI strings in GDScript. Okurigana stays outside the group (`{食|た}べる`);
jukujikun is one group (`{今日|きょう}`).

**Files.** `game/content/<kind>_<stage>[_suffix].json`, kind ∈ vocab, kanji, grammar, sentences,
scenarios, passages, anchors; stage ∈ n5, n4, n3, n2, n1, mastery. All files of a kind and stage
are merged at load. `kana.json` holds both scripts (basic, dakuten, handakuten, yōon).

| Kind | Source | Key fields |
|---|---|---|
| vocab | baked from `tools/wordlists/<stage>/*.tsv` + JMdict | `id` (stable hash of headword+reading), `headword`, `reading`, `level`, `category`, `definition_ja` (original), `english` (JMdict), `examples[{ja,en}]`, `related`, `kanji[]`, `source` |
| kanji | baked from KANJIDIC2 | `kanji`, `on[]`, `kun[]`, `meanings[]`, `strokes`, `freq`, `level`, `words[]` (vocab ids using it) |
| grammar | authored | `id`, `pattern`, `level`, `meaning_en`, `explanation_ja/en`, `one_liner_ja`, `requires[]`, `examples[]`, `items[{kind, ja (with ［　］), options, answer, why_ja, why_en}]` (6–10) |
| sentences | authored | `id`, `level`, `tier` 1–3, `prompt_en`, `ja_hint`, `tiles` (canonical order), `distractors`, `accepted[][]` (accepted[0] = tiles), `grammar[]` |
| scenarios | authored | `id`, `level`, `register`, `title_ja/en`, `location`, `turns[{speaker, line_ja, line_en, options[{ja, verdict correct/unnatural/wrong, register?, feedback_ja/en}], typed[]}]` |
| passages | authored | `id`, `level`, `title_ja`, `text_ja`, `text_en`, `questions[{q_ja, q_en, options, answer, why_ja, why_en}]` |
| anchors | authored | `id`, `level`, `ja`, `en`, `variants[{type, section, prompt_ja, prompt_en, options, answer, why_ja, why_en}]` (≥ 4) |

**Stage inventory as shipped (2026-11-13, v0.3.0).**

| Stage | Words | Kanji (KANJIDIC2) | Grammar | Prompts | Scenarios | Passages | Anchors |
|---|---|---|---|---|---|---|---|
| N5 | 772 | 103 (all used by N5 words) | 46 | 72 | 11 | 18 | 10 |
| N4 | 630 | 181 (176 used) | 38 | 46 | 7 | 12 | 10 |
| N3 | 158 | 369 | 15 | 12 | 2 | 3 | 3 |
| N2 | 155 | 370 | 15 | 10 | 2 | 3 | 3 |
| N1 | 149 | 1207 | 16 | 10 | 2 | 3 | 3 |
| Mastery | 87 expressions | — | 15 | 10 | 3 | 3 | 3 |

Every scenario option also carries an `en` translation, shown to beginners until N4.

N5 meets the §5.1 inventory and N4 is most of the way there. N3–N1 and Mastery are starter packs: every system works at every
stage, but those stages need more curated words to match the §5.1 targets (§12).

**Player save — `user://save.json` (version 2).** `stage`, `xp`, `english_mode`, `settings`
{theme, font, english_auto, tts_rate, voice, onboarded, typed_answers}, `skills` {perf, n} per
skill, `words` id → {rank, rec, rcl, use, box, due, streak, lapses, last_lapse, srs}, `kana`,
`grammar` id → {attempts, correct, lesson_done}, `prompts`, `scenarios`, `assessments`
[{date, stage, sections, passed, items}], `cooldown_until`, `consecutive_fails`, `daily`
{date, counters, paid, new_words, assessment_done, assessment_score, scenarios_rewarded},
`study_days`, `recommend_history`, `cleared_stages`, `recent_samples` (ring of 200), `reports`.
Version-1 saves migrate on load (every discovered word joins the review queue). Saves are written
after every completed item with write-to-temp-then-rename.

## 12. Later phases

Status 2026-11-13: listening (system TTS), shadowing with self-rating, typed answers (romaji or IME), N4–N1/Mastery starter content and the explorable 3D town are implemented. Automatic pronunciation scoring and free composition graded by a language model are not — they need a speech recogniser or an online service, which conflicts with the offline design. The paragraphs below are the original plan.

**N4–N1 content.** Same schemas; the pipeline adds JLPT-tagged word lists per stage and curators
write grammar points and anchors. Sentence builder gains clause reordering, formal ↔ casual rewrite,
alternative-grammar rewrite and 「不自然な日本語を探せ」 (spot the unnatural sentence). Thresholds per §5.4.

**Listening / TTS.** 聴解 becomes mandatory. Native TTS voices with speed variants, casual
contractions and multiple speakers; anchor variant 聞いて選んで; 会話を聞く quest enabled. Speaking
(read aloud, repeat, answer without options) and pronunciation feedback (vowel length, double
consonants, mora timing, pitch accent, おばさん vs おばあさん) follow once a recogniser is chosen.

**Free-text answers.** Scenario options are replaced by typed answers graded on grammar, word choice,
particles, naturalness, politeness and context; multiple-choice remains the fallback assistance
level. Free composition from a situation joins the sentence builder.

**Explorable 3D town.** Godot 3D scene of a small town: 自宅 · 学校 · 商店街 · 駅 · レストラン · 会社 ·
図書館 · 都会, unlocked by proficiency stage (XP unlocks cosmetics and side locations). Built from
the KayKit low-poly packs (Adventurers, Dungeon, Forest Nature, Skeletons — CC0) with the
Quaternius Universal Animation Library (CC0) for characters; all recorded in the credits screen.
The seven Phase 1 screens become in-world interactions (dictionary at the 図書館, scenarios with NPCs).

**NPC registers by location.** Each NPC carries a register tag (§8.2): friends casual, elders
distinct patterns, staff polite, teachers didactic, professionals formal. The same intent spoken
in the wrong register is `unnatural`; post-N1 content adds natural connectors (そういえば、ちなみに…)
and contextual depth (大丈夫 in five situations). Mastery stage is gated mainly by 会話 (90) and a
separate practical-communication rubric.

## 13. Design decisions (formerly open questions, resolved 2026-11-12)

| # | Question | Decision as implemented |
|---|---|---|
| 1 | Onboarding vs Japanese-first | A one-time bilingual onboarding (3 cards, `onboarding.gd`) explains the game, lets the player pick an English-assistance mode, then sends them to the kana trainer. Everything after it is Japanese-first. |
| 2 | Coverage weight / N5 size | Keep `covw = 0.5`; the N5 inventory is now 772 words, so 語彙 85 needs real coverage plus accuracy. Revisit after playtests. |
| 3 | 聴解 in Phase 1 | Visible and marked 任意 (optional) at N5. It becomes mandatory from N4. Without an installed Japanese voice the gate section is waived and labelled 免除, so a missing voice never blocks progress. |
| 4 | Missing natural orders | The sentence builder offers 「この{順番|じゅんばん}も{自然|しぜん}だと{思|おも}う」 on a wrong-order answer. Reports are saved in the save file and exported from 設定 to `user://reports.json` for curation. |
| 5 | Lapse severity for Mastered words | One grace lapse per 30 days: counters and box still drop, but a Mastered word only loses its rank on a second lapse inside the window (`Mastery.MASTERED_GRACE_SECONDS`). |
| 6 | Exam farming | Escalating cooldown after consecutive fails: 24 h, 48 h, then 72 h. A pass resets it. Practice sittings (模擬試験) are always available and never change the stage. |
| 7 | Furigana granularity | Per-kanji-run ruby, with jukujikun as one group, authored by hand and checked against JMdict/KANJIDIC2 by `tools/jpcheck.py`. No morphological analyser in the pipeline. |
| 8 | Daily new-word budget | Base 10; +5 when recent review accuracy ≥ 85% and fewer than 20 reviews are due; −5 when 40 or more are due; minimum 5. Words only enter reviews through 学習する (or by being answered in review). |

## 14. Glossary of in-game Japanese terms

| Term | Reading | English |
|---|---|---|
| 日本語の世界 | にほんごのせかい | The World of Japanese (title) |
| ダッシュボード | — | Dashboard |
| 語彙 | ごい | Vocabulary (skill) |
| 文法 | ぶんぽう | Grammar (skill) |
| 読解 | どっかい | Reading comprehension (skill) |
| 聴解 | ちょうかい | Listening comprehension (skill) |
| 会話 | かいわ | Conversation (skill) |
| 漢字 | かんじ | Kanji (skill) |
| 六つのスキル | むっつのスキル | The six skills |
| 初級 / 初中級 / 中級 / 中上級 / 上級 | しょきゅう / しょちゅうきゅう / ちゅうきゅう / ちゅうじょうきゅう / じょうきゅう | Beginner / upper-beginner / intermediate / upper-intermediate / advanced |
| 完全習得 | かんぜんしゅうとく | Mastery |
| かなトレーナー | — | Kana trainer |
| 辞書 | じしょ | Dictionary |
| 今日の単語 | きょうのたんご | Today's words |
| 学習する | がくしゅうする | Study this (add to SRS) |
| 例文 | れいぶん | Example sentence |
| 関連語 | かんれんご | Related words |
| 文を作ろう | ぶんをつくろう | Sentence builder ("Let's build a sentence") |
| 確認 | かくにん | Confirm / check |
| ヒント | — | Hint |
| 会話シナリオ | かいわシナリオ | Conversation scenario |
| コンビニ | — | Convenience store |
| 店員 | てんいん | Shop staff |
| 正解 / 惜しい / 不正解 | せいかい / おしい / ふせいかい | Correct / close (unnatural) / incorrect |
| 昇級試験 | しょうきゅうしけん | Promotion (gate) exam |
| 毎日の確認テスト | まいにちのかくにんテスト | Daily assessment |
| 文法レッスン | ぶんぽうレッスン | Grammar lesson |
| 復習 | ふくしゅう | Review (SRS queue) |
| おすすめ | — | Recommended (next activity) |
| 連続日数 | れんぞくにっすう | Streak (days in a row) |
| 学習日数 | がくしゅうにっすう | Days studied |
| 丁寧語 / タメ口 / 敬語 | ていねいご / タメぐち / けいご | Polite form / casual speech / honorific language |
| 日本語のみ | にほんごのみ | Japanese only (assistance mode) |
| 二か国語 | にかこくご | Bilingual (assistance mode) |
| 情報 | じょうほう | Info / credits screen |
