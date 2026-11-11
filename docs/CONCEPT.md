# 日本語の世界 — Concept Reference

Condensed from the original ChatGPT concept conversation
(https://chatgpt.com/share/6af2dc9a-7ff0-83ec-8dcc-cae99ebf803c), 2026-11-09.
This file is the *source* the Game Design Document is derived from. Edit the GDD, not this.

## One-line pitch

An RPG in which the player's main progression system is their own ability to understand and
use Japanese. The whole interface is Japanese-first (furigana on every kanji), English only
supports. Levelling up is gated by demonstrated proficiency, never by XP alone.

## Core game concept

| Element | Description |
|---|---|
| Genre | Educational RPG / language simulation |
| Primary language | Japanese (furigana on kanji) |
| Supporting language | Short English explanations, toggleable |
| Audience | Beginners to advanced learners |
| Progression | Proficiency-based levelling (JLPT N5 → N1 → Mastery) |
| Skills | Reading, listening, grammar, vocabulary, conversation, writing/kanji |
| Goal | Natural Japanese communication, not exam scores |

Core loop: encounter words/expressions → understand meaning and grammar → see them in real
sentences → construct own sentences → use them in scenario conversations → pass a proficiency
assessment → unlock the next stage.

## Proficiency stages

| Stage | Name | Focus | Example |
|---|---|---|---|
| 1 | N5 初級 | kana, basic kanji, greetings, は/が/を/に/で, present/past/negative | 私は学生です。 |
| 2 | N4 初中級 | conjugation, て-form, potential, giving/receiving, joining sentences | 日本語を勉強しているので、少し話せます。 |
| 3 | N3 中級 | complex sentences, casual vs polite, opinions, implied meaning | 日本で生活するなら、日常会話を理解できるようになりたいです。 |
| 4 | N2 中上級 | advanced grammar, formal/business, articles, nuance | 状況に応じて、適切な対応をする必要があります。 |
| 5 | N1 上級 | literary/academic, registers, native-level reading | 彼の発言は、必ずしも事実を反映しているとは限らない。 |
| 6 | Mastery 完全習得 | context without translating, humour, idioms, regional variation, spontaneity | 言葉だけでなく、相手の気持ちや状況も考えて話すことが大切です。 |

N1 is not native mastery; the final stage measures practical communication separately.

## Adaptive mastery system (the most important mechanic)

Each stage tracks independent attributes: 読解 reading, 聴解 listening, 文法 grammar,
語彙 vocabulary, 会話 conversation, plus writing and kanji recognition.

Proposed gate thresholds (game-design values, not JLPT rules):
reading 85%, listening 85%, grammar 90%, vocabulary 85%, conversation 80%, writing 80%.
The player advances only when **all** mandatory attributes meet their thresholds.

Understanding is detected with varied challenges on one sentence
(昨日、友達と映画を見ました。): identify subject/object; explain と; explain why 見る → 見ました;
rewrite as negative past; build a new sentence with the same pattern; understand it spoken;
answer a related question naturally.

Dynamic difficulty: the game watches performance per skill and serves more of whatever the
player is weak at (particles, listening, sentence building…), and harder structures when the
player is consistently strong.

## Japanese-first interface

| Content | Display |
|---|---|
| Kanji | always with furigana |
| Kana | plain |
| Definitions | Japanese explanation + short English |
| Example sentences | Japanese with furigana, English toggle |
| Conversation | Japanese-first |

English assistance modes: Japanese only · Japanese + English explanations · Japanese +
translations · full bilingual. Assistance is reduced automatically as proficiency rises, but the
option is never removed.

Dictionary entry template (勉強): headword with furigana · reading · JLPT level · part of speech
· Japanese definition · English explanation · example sentences · related words (学習, 練習,
研究, 復習) · common combinations · synonyms/antonyms · mastery status.

## Vocabulary mastery and spaced repetition

Per-word rank: Unseen → Discovered → Familiar → Learned → Proficient → Mastered.
Recognition, recall and contextual usage are tracked separately; a translation match alone
never masters a word.

SRS schedule sketch: first encounter → immediate review; then later that day; next day; several
days; progressively longer. A lapse shortens the interval.

## Grammar and sentence construction

| Level | Example grammar |
|---|---|
| N5 | は、が、を、に、で、です、ます |
| N4 | て-form、ない-form、たり、ながら |
| N3 | ように、ために、ことになる、わけ |
| N2 | によって、ものの、に違いない |
| N1 | いかん、ならでは、を禁じ得ない |

Sentence construction mode: the player gets word tiles (including distractors) and assembles a
correct sentence. Later: multiple valid orders, clause reordering, formal ↔ casual, rewriting
with alternative grammar, spotting unnatural Japanese, free composition from a situation.
Teach the gap between *grammatical* and *natural*. Accept natural alternative answers.

## Everyday communication scenarios

Meeting someone · convenience store · restaurant · train station · grocery store · workplace ·
school · hospital · government office · social gathering.

Example (convenience store): 店員「いらっしゃいませ！何をお探しですか？」 → choose
水をください ✓ / 水がいます ✗ / 水をあります ✗. Later allow free-text answers graded on grammar,
word choice, particles, naturalness, politeness and context.

## Listening, speaking, pronunciation (later phases)

Native TTS voices, speed variants, casual contractions, multiple speakers. Speaking: read aloud,
repeat, answer without options. Pronunciation feedback: vowel length, double consonants, mora
timing, pitch accent, intonation (おばさん vs おばあさん).

## Daily quests

Learn 10 words 100 XP · review 20 entries 100 XP · one grammar lesson 150 XP · listen to a
conversation 100 XP · complete a conversation 200 XP · build five sentences 150 XP · daily
assessment 250 XP. XP unlocks locations, conversations, categories, cosmetics. XP never
substitutes for proficiency gates.

## World and NPCs

Start in a small Japanese town. Areas unlock with proficiency:
自宅 home · 学校 school · 商店街 shopping district · 駅 station · レストラン · 会社 workplace ·
図書館 library · 都会 city. NPC registers: friends casual, elders distinct patterns, staff polite,
teachers didactic, professionals formal.

## Advanced language system (post-N1)

Natural connectors (そういえば、ちなみに、それにしても、なるほど、たしかに、ということは);
register by situation (casual / polite / business polite / respectful / written formal);
contextual vocabulary depth (大丈夫 as okay / fine / no problem / no thank you / are you okay?);
"thinking in Japanese": respond in Japanese without translating.

## Game modes

単語モード vocabulary · 文法モード grammar · 会話モード conversation · 聴解モード listening ·
漢字モード kanji · 試験モード examination (timed, JLPT-style).

## Dashboard

Level and stage · overall progress · six skill bars (語彙、文法、読解、聴解、会話、漢字) ·
counters (words learned, grammar patterns, conversations, days studied) · weakest areas ·
recommended next activity.

## Original technical proposal and our deviation

The concept proposed Unity/C#, SQLite, JMdict + KanjiDic2, MeCab/Sudachi for furigana, TTS and
speech recognition. The concept's own roadmap says: ship the learning core (dictionary, N5
curriculum, sentence builder, assessment) as a desktop app first, add the explorable world
after the learning mechanics are proven.

This project follows that roadmap with **Godot 4.7 + GDScript** (see
`docs/adr/0001-godot-gdscript.md`) and a Python content pipeline that bakes JMdict-derived,
editorially curated JSON into the game.

## Roadmap (from the concept)

1. Japanese-first interface, kana, furigana
2. Dictionary and word mastery
3. Grammar lessons and sentence construction
4. N5 progression and assessments
5. Spaced repetition and adaptive difficulty
6. Conversations and NPC dialogue
7. Listening, TTS, speaking evaluation
8. N4–N1 content
9. Explorable world
10. Full mastery system

## Design principles to preserve

1. Japanese-first, English-supported.
2. Mastery over memorisation.
3. Practical communication over examination scores.
