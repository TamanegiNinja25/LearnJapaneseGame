# Content guide

How to write content for 日本語の世界. Every content file is checked by
`tools/validate_content.py` in CI; word lists are checked by `tools/check_tsv.py`. Read
`docs/GAME_DESIGN.md` §6–§9 for *why* the formats look like this.

## The one rule: furigana markup on every kanji

Japanese text is written with inline markup `{漢字|かんじ}`. The game draws the reading above the
base. **No kanji may appear outside a group** — the validator fails otherwise.

- One group per kanji word or kanji run: `{学校|がっこう}`, `{日本語|にほんご}`.
- Okurigana stays outside the group: `{食|た}べます`, `{新|あたら}しい`, `{行|い}きました`.
- Honorific お/ご outside: `お{茶|ちゃ}`, `ご{飯|はん}`.
- Jukujikun as one group: `{今日|きょう}`, `{一人|ひとり}`, `{大人|おとな}`, `{上手|じょうず}`.
- Numbers + counters: `{三人|さんにん}`, `{七時|しちじ}`, `{百|ひゃく}{円|えん}` (either style is fine).
- Katakana and hiragana words need no markup: `コンビニ`, `ください`.
- Readings are hiragana only. Full-width Japanese punctuation (。、「」！？).
- Plain-text fields (`headword`, `reading`, `typed`) never contain markup.

`tools/check_tsv.py` also verifies each group's reading against JMdict and KanjiDic2 and prints
`warn cannot confirm X→Y` when it cannot. Treat each warning as "double-check this": fix real
mistakes, leave legitimate exceptions (お{母|かあ}さん, {来|こ}ない).

## Voice and level

- Definitions (`jp_definition`, `explanation_ja`, `why_ja`, `feedback_ja`) are **original**
  Japanese written for learners of that stage: short, plain です/ます or dictionary style, using
  words at or below the stage where possible. Never copy definitions from a dictionary.
- English is short support text, never a literal gloss of the Japanese definition.
- Examples are natural, everyday, and show the word in its most common use.
- No real brands, real people, or copyrighted text. Shop names are invented.

## Word lists — `tools/wordlists/<stage>/<topic>.tsv`

UTF-8, tab-separated, one header line, one word per line. `<stage>` is `n5`, `n4`, `n3`, `n2`,
`n1` or `mastery`. Several files per stage are fine; they are merged in file-name order and the
first occurrence of a headword+reading wins across all stages.

```
#headword	reading	category	jp_definition	example_jp	example_en	related
勉強	べんきょう	noun	{知識|ちしき}を{身|み}につけるために{学|まな}ぶこと。	{毎日|まいにち}{日本語|にほんご}を{勉強|べんきょう}します。	I study Japanese every day.	学習,練習
```

| Column | Content |
|---|---|
| headword | dictionary form as normally written (kanji if usually written in kanji) |
| reading | hiragana (katakana words: the katakana itself) |
| category | `noun pronoun verb-u verb-ru verb-irregular adj-i adj-na adverb expression conjunction counter particle prefix suffix interjection` |
| jp_definition | original Japanese definition, markup |
| example_jp | one example sentence containing the word, markup |
| example_en | natural English translation of the example |
| related | comma-separated headwords (may be empty) |

Verbs with する: list the noun (勉強, category noun) — the example can use する.
Check a file with `python tools/check_tsv.py tools/wordlists/n5/<file>.tsv`. Zero errors is
required; aim for zero unexplained warnings.

## Grammar — `game/content/grammar_<stage>.json`

Any JSON content file may carry a suffix (`grammar_n5_verbs.json`); the game loads every file
of a kind and stage, and ids must be unique across all of them.

```json
{
 "id": "n5_wa",
 "pattern": "〜は〜です",
 "level": "N5",
 "meaning_en": "A is B (topic は + polite copula です)",
 "explanation_ja": "「は」は{話|はなし}の{主題|しゅだい}を{表|あらわ}します。…",
 "explanation_en": "は marks the topic …",
 "one_liner_ja": "「は」は{主題|しゅだい}を{表|あらわ}します。",
 "requires": [],
 "examples": [{"ja": "{私|わたし}は{学生|がくせい}です。", "en": "I am a student."}],
 "items": [
  {"kind": "particle", "ja": "{私|わたし}［　］{学生|がくせい}です。",
   "options": ["は", "を", "に", "で"], "answer": 0,
   "why_ja": "「{私|わたし}」が{主題|しゅだい}なので「は」です。", "why_en": "私 is the topic, so は."}
 ]
}
```

- `id`: `<stage>_<short_name>`, unique across all stages. Keep existing ids stable.
- `one_liner_ja`: one short sentence, shown when the player misplaces a tile of this pattern.
- `requires`: ids of grammar points that should be learned first (may be empty).
- `items`: **6–10** quiz items. `ja` contains exactly the blank `［　］`; 2–4 unique `options`;
  `answer` is the index of the correct option; `kind` is `particle`, `conjugation`, `meaning` or
  `choice`. Exactly one option must be correct in context — avoid items where two options are
  both natural.

## Sentence-builder prompts — `game/content/sentences_<stage>.json`

```json
{
 "id": "n5_sb_001", "level": "N5", "tier": 1,
 "prompt_en": "I drink water.",
 "ja_hint": "{水|みず}を{飲|の}む{文|ぶん}",
 "tiles": ["{水|みず}", "を", "{飲|の}みます"],
 "distractors": ["が"],
 "accepted": [["{水|みず}", "を", "{飲|の}みます"]],
 "grammar": ["n5_wo"]
}
```

- `tiles` is the canonical correct order; `accepted[0]` must equal `tiles`; further entries are
  other natural orders (e.g. time word first or after the topic).
- A particle is always its own tile. A verb tile includes its ending (`{見|み}ました`).
- `tier` 1: 2–3 tiles, 1 distractor. Tier 2: 3–5 tiles, 2 distractors. Tier 3: 5–7 tiles,
  3 distractors. Distractors are a wrong particle, a wrong conjugation or a near-synonym and must
  make the sentence wrong if used.
- `grammar`: ids that exist in some `grammar_<stage>.json`.

## Scenarios — `game/content/scenarios_<stage>.json`

```json
{
 "id": "n5_sc_konbini", "level": "N5", "register": "polite",
 "title_ja": "コンビニで{買|か}い{物|もの}", "title_en": "Shopping at the convenience store",
 "location": "{商店街|しょうてんがい}",
 "turns": [
  {"speaker": "{店員|てんいん}", "line_ja": "いらっしゃいませ！", "line_en": "Welcome!",
   "options": [
    {"ja": "{水|みず}をください。", "verdict": "correct", "register": "polite",
     "feedback_ja": "…", "feedback_en": "…"},
    {"ja": "{水|みず}、ある？", "verdict": "unnatural", "register": "casual", "feedback_ja": "…", "feedback_en": "…"},
    {"ja": "{水|みず}がいます。", "verdict": "wrong", "feedback_ja": "…", "feedback_en": "…"}
   ],
   "typed": ["水をください", "みずをください", "水をお願いします"]}
 ]
}
```

- `register`: `casual`, `polite`, `business`, `respectful` or `written`.
- `location` is one of the town locations: 自宅 学校 商店街 駅 レストラン 会社 図書館 都会 (markup).
- Each turn: 2–4 options, **exactly one `correct`**, at least one `wrong`. `unnatural` means
  grammatical but not what a native speaker would say here (wrong register, too blunt, odd word).
  Each scenario needs at least two `unnatural` options in total.
- `typed`: plain strings (no markup, no final 。) that count as correct when the player types
  instead of choosing — the correct option plus common natural variants, in kanji and in kana.

## Reading passages — `game/content/passages_<stage>.json`

```json
{
 "id": "n5_rd_001", "level": "N5",
 "title_ja": "{私|わたし}の{一日|いちにち}",
 "text_ja": "{私|わたし}は{毎朝|まいあさ}{七時|しちじ}に{起|お}きます。…",
 "text_en": "I get up at seven every morning. …",
 "questions": [
  {"q_ja": "{何時|なんじ}に{起|お}きますか。", "q_en": "What time does the writer get up?",
   "options": ["{六時|ろくじ}", "{七時|しちじ}", "{八時|はちじ}"], "answer": 1,
   "why_ja": "「{七時|しちじ}に{起|お}きます」とあります。", "why_en": "The text says 7 o'clock."}
 ]
}
```

3–6 sentences at the stage's level, 2–4 questions answerable only from the text.

## Anchor sentences — `game/content/anchors_<stage>.json`

One sentence, many questions (GDD §9.2). Each anchor has **at least 4** variants.

```json
{
 "id": "n5_an_001", "level": "N5",
 "ja": "{昨日|きのう}、{友達|ともだち}と{映画|えいが}を{見|み}ました。",
 "en": "Yesterday I watched a movie with a friend.",
 "variants": [
  {"type": "particle_meaning", "section": "grammar",
   "prompt_ja": "この{文|ぶん}の「と」の{意味|いみ}は？", "prompt_en": "What does と mean here?",
   "options": ["いっしょにする{人|ひと}", "{場所|ばしょ}", "{時間|じかん}", "{理由|りゆう}"], "answer": 0,
   "why_ja": "…", "why_en": "…"}
 ]
}
```

`type`: `subject_object`, `particle_meaning`, `conjugation_why`, `rewrite`, `same_pattern`,
`meaning`, `respond`. `section`: the skill the question counts for (`grammar`, `reading`,
`conversation`, `vocab`, `kanji`). For `rewrite` and `same_pattern`, the options are full
sentences.

## Commands

```bash
python tools/check_tsv.py tools/wordlists/n5/*.tsv          # word lists
python tools/validate_content.py game/content --file grammar_n5.json   # one JSON file
python tools/bake_content.py --report                       # rebuild vocab/kanji JSON (maintainers)
python tools/validate_content.py game/content               # everything (what CI runs)
```

## Kanji lists by stage (from KanjiDic2's JLPT field)

- **N5 (103)**: 日一国会人年大十二本中長出三時行社見月分後前生五間上東四今新金九入立手学高円子目外言八六下来気小七山話多安女北午百書先名川千道水半男西電口少校語空土木聞食車何南足万店毎白古天買週母火花右読友左休父駅雨飲魚耳
- **N4 (181)**: 同事自民発者地合市業方回場員開力問代明動京通理体田主題首意不作用度強持野都以思家世区県進正院心界産教文元重近考画海売知集別物引使所品計死特私始朝村運終台広住真有町料工建急止送切説転研究楽起着乗病声質待試族銀早映親験働好英頭低医仕去味門写字答夜音注帰歌光悪図室太歩風紙黒春赤青森館屋色走秋林夏顔短薬習便洋旅軽池服遠夕借曜弱肉貸堂暗鳥飯勉冬昼茶弟洗牛兄犬菜暑妹寒姉漢
- N3, N2, N1: run `python tools/bake_content.py --report` or read `game/content/kanji_<stage>.json`.

Words of a stage should use that stage's kanji (and lower stages') so the 漢字 skill can be
covered. Higher-stage kanji inside a lower-stage word are allowed when that is how the word is
normally written; the furigana carries the reader.
