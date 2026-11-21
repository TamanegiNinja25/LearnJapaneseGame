# 日本語の世界 — LearnJapaneseGame

A Japanese-first language-learning RPG. You level up from N5 to N1 and on to Mastery by proving
proficiency across six skills (語彙・文法・読解・聴解・会話・漢字), not by grinding XP, with optional
kanji writing practice (書き) on top. Every kanji
carries furigana, every word has an original Japanese definition first and a short English
explanation second, and English assistance shrinks as you advance.

Built with **Godot 4.7** and **GDScript**. Word data is baked from JMdict and KANJIDIC2 and
hand-curated.

## What's in the game

| Screen | What it does |
|---|---|
| ホーム Dashboard | Stage, skill bars against the gate thresholds (書き is optional), tap a skill to practise it, streak, counters, today's quests, the recommended next activity |
| 町 Town | A walkable low-poly 3D town (KayKit assets). Talk to people at 8 locations that unlock by stage |
| かな Kana | Hiragana and katakana rounds, including yōon, with audio |
| 辞書 Dictionary | 1,951 words across N5–Mastery, search by kana, kanji, romaji or English. 学習する adds a word to reviews within a daily budget |
| 復習 Review | Leitner spaced repetition: recognition, typed recall, kanji reading and usage questions; missed words return in the same session |
| 漢字 Kanji | The stage's kanji (103 at N5) with readings, meanings, stroke counts and the words that use them |
| 書き Writing | Write kanji, hiragana, katakana or whole words stroke by stroke with a finger or the mouse: trace over a model (なぞる) or write from the readings, the meaning or the romaji (見ないで書く). Each stroke is checked for order, shape and direction; 書き順を見る animates the stroke order |
| 文法 Grammar | 145 grammar lessons, each with an explanation and a 6-question quiz |
| 表現 Natural Japanese | 言い換え: rewrite a sentence into another register (polite, casual, honorific). 不自然な文: pick the reply a native speaker would not say |
| 文を作る Sentence builder | Word tiles with distractors in three tiers, particle-specific feedback, hints |
| 会話 Conversation | 27 scenarios with 正解 / 惜しい / 不正解 answers, spoken NPC lines, and an optional typed-answer mode |
| 聴解 Listening | Word and sentence listening with the system Japanese voice, plus shadowing with your microphone |
| 試験 Assessment | The stage gate exam, a daily 10-question check, and practice sittings |
| 設定 Settings | English assistance, light/dark theme, an accessibility font, voice and speed, data, credits |

Until you pass the N4 exam, beginner help shows English under every label, button, word tile and
conversation answer, whatever the assistance mode (設定 › "N4まで英語を全部表示する" turns it off).
The layout adapts to the screen, and 設定 › 文字の大きさ sets the text size (automatic is larger on
touch screens). Touch drags scroll every list, including ones full of buttons.

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
設定 › データ › バックアップをコピー puts your whole progress on the clipboard as one line of text;
keep it in a note or e-mail and use クリップボードから復元 on a new device or after reinstalling
(desktop builds can also save and load a backup file in Documents). Sound effects and an optional
quiet background loop are switched in 設定 › サウンド.

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

## Android (APK)

A debug-signed APK for sideloading is built with the "Android" export preset:

```bash
godot --headless --path game --export-debug "Android" ../build/android/NihongoNoSekai.apk
```

It needs Godot's Android export templates, the Android SDK build tools and a JDK configured in
Godot's editor settings (Editor › Editor Settings › Export › Android). Local and CI builds are signed
with the project's debug key in `tools/android/debug.keystore`, so new APKs install over old ones
and keep your progress. To install it on a phone,
copy the APK over and allow "Install unknown apps" for your file manager, or run
`adb install NihongoNoSekai.apk`. Requires Android 7.0 or newer (arm64 or x86_64).

On touch screens the town shows a joystick, a 話す (talk) button and drag-to-look on the right
half; Android's back gesture returns to ホーム. Listening uses the phone's text-to-speech, so
install a Japanese voice (Google Speech Services › Japanese) for the 聴解 screen.

Test an APK on a USB-connected phone (install over the current app, launch, check it stays up
with no script errors, save a screenshot):

```bash
python tools/phone_smoke.py build/android/NihongoNoSekai.apk
```

### Play Store

The "Android (Play Store)" preset builds a signed `.aab` app bundle with Gradle. It needs your own
release key, which must stay private (never commit it):

1. Create a key once: `keytool -genkeypair -keystore release.keystore -alias nihongo -keyalg RSA -keysize 2048 -validity 10000`.
   Keep the file and its password safe: every Play Store update must be signed with it.
2. In the GitHub repository, add the secrets `ANDROID_RELEASE_KEYSTORE_BASE64` (the keystore file
   in base64), `ANDROID_RELEASE_KEY_ALIAS` and `ANDROID_RELEASE_KEY_PASSWORD`. The next tagged
   release then uploads `play-store-bundle` as a workflow artifact.
3. Upload that `.aab` in the Google Play Console and link the privacy policy
   [docs/PRIVACY.md](docs/PRIVACY.md).

To build it locally, unpack Godot's `android_source.zip` export template into `game/android/build`
(git-ignored) and set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` and `_PASSWORD`. On Windows,
if your user folder has non-ASCII characters, also set `GRADLE_USER_HOME` and
`JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=<an ASCII path>`, or Gradle fails with "Unable to
establish loopback connection".

The app icon's source is `tools/icon/app_icon_source.png`. After replacing it, regenerate the
project and Android launcher icons with
`godot --headless --path game --script ../tools/make_app_icons.gd`.

## Updates

At start the game asks GitHub once for the latest release (one request to
`api.github.com/repos/TamanegiNinja25/LearnJapaneseGame/releases/latest`). If it is newer than
the installed version, a popup offers ダウンロード (the APK on Android, the release page
elsewhere), あとで, or このバージョンをスキップ. Nothing else is sent and nothing happens when
offline. Turn it off in 設定 › 起動時に更新を確認する. This is the only reason the Android build
has the internet permission.

## Build releases

Push a tag such as `v0.2.0` and [release.yml](.github/workflows/release.yml) exports Windows,
Linux, macOS, Web and Android (APK) builds and publishes them as a GitHub release. The macOS
build is a universal app, unsigned: on first launch right-click it and choose Open. The Web build
can be uploaded to itch.io as an HTML5 game. Presets live in `game/export_presets.cfg`. iOS builds
need a Mac with Xcode and an Apple developer account, so they are not built here.

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
KANJIDIC2 is © EDRDG under CC BY-SA 4.0. Stroke-order data is from KanjiVG (© Ulrich Apel and
contributors, CC BY-SA 3.0, http://kanjivg.tagaini.net). KayKit assets are CC0. Fonts are SIL OFL 1.1. Icons are
Tabler (MIT). Full attribution: [game/assets/ASSETS.md](game/assets/ASSETS.md).
