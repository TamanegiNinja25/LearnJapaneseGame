# Headless GDScript test runner. Run from the repo root with:
#   godot --headless --path game --import          (once, on a fresh checkout)
#   godot --headless --path game --script res://tests/test_runner.gd
# Exit code is 0 only when every test passes; CI gates on it.
extends SceneTree

var passed := 0
var failed := 0

# Autoloads enter the tree one frame after _initialize() in --script mode.
var content: Node
var progress: Node

const TESTS: Array[String] = [
	"test_furigana_parse",
	"test_furigana_plain_and_reading",
	"test_romaji",
	"test_answer_match",
	"test_sentence_check_correct_and_alternatives",
	"test_sentence_check_wrong_tiles_order_particle",
	"test_sentence_tiers",
	"test_mastery_sample_and_score",
	"test_mastery_gate_and_margin",
	"test_mastery_level_formula",
	"test_mastery_cooldowns",
	"test_word_rank_promotion",
	"test_word_lapse",
	"test_word_lapse_mastered_grace",
	"test_srs_next_box",
	"test_srs_review_schedules_due",
	"test_srs_pick_due_orders_and_caps",
	"test_quests",
	"test_recommender_rules",
	"test_recommender_shuffle",
	"test_update_check",
	"test_stroke_match",
	"test_writing_progress",
	"test_backup_restore",
	"test_style_drills",
	"test_content_loads",
	"test_content_stages",
	"test_exam_builder",
	"test_exam_daily_and_listening",
	"test_headword_markup",
	"test_progress_roundtrip",
	"test_progress_study_budget_and_review",
	"test_progress_daily_quests",
	"test_progress_exam_flow",
	"test_screens_instantiate",
]


func _initialize() -> void:
	await process_frame
	content = root.get_node("ContentDB")
	progress = root.get_node("Progress")
	for t in TESTS:
		var ok: Variant = await call(t)
		if ok != true:
			failed += 1
			push_error("FAIL %s: did not finish (runtime error?)" % t)
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


## Word id by headword (ids are stable hashes of headword + reading).
func wid(headword: String) -> String:
	return content.word_by_headword(headword)["id"]


func assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s: expected %s, got %s" % [label, expected, actual])


func assert_true(cond: bool, label: String) -> void:
	assert_eq(cond, true, label)


func assert_near(actual: float, expected: float, label: String, eps: float = 0.001) -> void:
	if absf(actual - expected) <= eps:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s: expected ~%s, got %s" % [label, expected, actual])


func fresh_progress(start: int = 1_700_000_000) -> Array:
	progress.persist = false
	progress.reset()
	var clock := [start]  # array: lambdas capture locals by value
	progress.now_provider = func() -> int: return clock[0]
	return clock


# ---------------------------------------------------------------- Furigana, Romaji, AnswerMatch

func test_furigana_parse() -> bool:
	var segs := Furigana.parse("{私|わたし}は{学生|がくせい}です。")
	assert_eq(segs.size(), 4, "segment count")
	assert_eq(segs[0], {"base": "私", "ruby": "わたし"}, "first kanji group")
	assert_eq(segs[1], {"base": "は", "ruby": ""}, "plain particle")
	assert_eq(segs[3], {"base": "です。", "ruby": ""}, "trailing plain")
	assert_eq(Furigana.parse("{broken").size(), 1, "unterminated group is kept as plain text")
	return true


func test_furigana_plain_and_reading() -> bool:
	var text := "{昨日|きのう}、{友達|ともだち}と{映画|えいが}を{見|み}ました。"
	assert_eq(Furigana.plain(text), "昨日、友達と映画を見ました。", "plain")
	assert_eq(Furigana.reading(text), "きのう、ともだちとえいがをみました。", "reading")
	assert_true(Furigana.has_kanji(text), "has kanji")
	assert_true(not Furigana.has_kanji("こんにちは"), "kana only")
	return true


func test_romaji() -> bool:
	assert_eq(Romaji.to_hiragana("mizuwokudasai"), "みずをください", "basic sentence")
	assert_eq(Romaji.to_hiragana("gakkou"), "がっこう", "double consonant")
	assert_eq(Romaji.to_hiragana("shinbun"), "しんぶn", "trailing n kept while typing")
	assert_eq(Romaji.to_hiragana("shinbun", true), "しんぶん", "final n")
	assert_eq(Romaji.to_hiragana("konnichiha"), "こんにちは", "nn")
	assert_eq(Romaji.to_hiragana("kyou"), "きょう", "yoon")
	assert_eq(Romaji.to_hiragana("tokyo"), "ときょ", "tokyo spelled literally")
	assert_eq(Romaji.to_hiragana("kan'i"), "かんい", "n apostrophe")
	assert_eq(Romaji.to_hiragana("みずを"), "みずを", "kana passes through")
	assert_true(Romaji.has_latin("abc") and not Romaji.has_latin("あ"), "has_latin")
	return true


func test_answer_match() -> bool:
	var accepted := ["水をください", "みずをください", "{水|みず}をお{願|ねが}いします"]
	assert_true(AnswerMatch.grade("水をください。", accepted)["correct"], "exact with punctuation")
	assert_true(AnswerMatch.grade("mizuwokudasai", accepted)["correct"], "romaji")
	assert_true(AnswerMatch.grade("みずをおねがいします", accepted)["correct"], "markup reading form")
	assert_true(AnswerMatch.grade("ミズヲクダサイ", accepted)["correct"], "katakana normalised")
	var r := AnswerMatch.grade("みずがください", accepted)
	assert_true(not r["correct"], "wrong particle rejected")
	assert_true(String(r["hint_ja"]).contains("が"), "hint names the particle")
	assert_eq(AnswerMatch.particle_diff("みずがください", "みずをください"), "が", "particle diff")
	assert_eq(AnswerMatch.distance("kitten", "sitting"), 3, "levenshtein")
	assert_true(not AnswerMatch.grade("", accepted)["correct"], "empty answer")
	return true


# ---------------------------------------------------------------- SentenceCheck

func test_sentence_check_correct_and_alternatives() -> bool:
	var accepted := [["{昨日|きのう}", "{学校|がっこう}", "に", "{行|い}きました"], ["{学校|がっこう}", "に", "{昨日|きのう}", "{行|い}きました"]]
	var r := SentenceCheck.evaluate(["{学校|がっこう}", "に", "{昨日|きのう}", "{行|い}きました"], accepted)
	assert_eq(r["result"], SentenceCheck.Result.CORRECT, "alternative order accepted")
	return true


func test_sentence_check_wrong_tiles_order_particle() -> bool:
	var accepted := [["{水|みず}", "を", "ください"]]
	var r := SentenceCheck.evaluate(["{水|みず}", "が", "ください"], accepted)
	assert_eq(r["result"], SentenceCheck.Result.WRONG_PARTICLE, "single particle swap")
	assert_eq(r["particle"], "が", "names the wrong particle")
	assert_eq(r["expected"], "を", "knows the expected particle")
	assert_eq(r["first_bad_index"], 1, "points at the particle")
	r = SentenceCheck.evaluate(["{水|みず}", "{飲|の}みます", "ください"], accepted)
	assert_eq(r["result"], SentenceCheck.Result.WRONG_TILES, "non-particle distractor")
	r = SentenceCheck.evaluate(["を", "{水|みず}", "ください"], accepted)
	assert_eq(r["result"], SentenceCheck.Result.WRONG_ORDER, "same tiles, wrong order")
	assert_eq(r["first_bad_index"], 0, "diverges at index 0")
	r = SentenceCheck.evaluate(["{水|みず}", "を"], accepted)
	assert_eq(r["result"], SentenceCheck.Result.WRONG_TILES, "missing tile")
	return true


func test_sentence_tiers() -> bool:
	assert_eq(SentenceCheck.tier_for_score(0), 1, "tier 1 below 40")
	assert_eq(SentenceCheck.tier_for_score(40), 2, "tier 2 from 40")
	assert_eq(SentenceCheck.tier_for_score(69), 2, "tier 2 to 69")
	assert_eq(SentenceCheck.tier_for_score(70), 3, "tier 3 from 70")
	return true


# ---------------------------------------------------------------- Mastery

func test_mastery_sample_and_score() -> bool:
	var s := Mastery.new_skill()
	s = Mastery.apply_sample(s, 1.0, 1.0)
	assert_near(s["perf"], 0.08, "one correct sample moves perf by alpha")
	s = Mastery.apply_sample(s, 0.0, 1.5)
	assert_near(s["perf"], 0.08 - 0.08 * 1.5 * 0.08, "weighted wrong sample")
	assert_eq(Mastery.score({"perf": 0.82, "n": 90.0}, &"vocab", 0.6), 71, "GDD worked example")
	assert_eq(Mastery.score({"perf": 1.0, "n": 15.0}, &"reading", 0.0), 50, "confidence halves at n=15")
	assert_eq(Mastery.samples_for(&"listening"), {&"listening": 1.0, &"vocab": 0.2}, "listening weights")
	assert_near(float(Mastery.samples_for(&"grammar_quiz", true)[&"grammar"]), 1.5, "assessment weight")
	return true


func test_mastery_gate_and_margin() -> bool:
	var ok := {&"vocab": 85, &"grammar": 90, &"reading": 85, &"conversation": 80, &"kanji": 80}
	assert_true(Mastery.evaluate_gate(ok, &"N5")["passed"], "exact thresholds pass")
	var low := ok.duplicate()
	low[&"grammar"] = 89
	assert_eq(Mastery.evaluate_gate(low, &"N5")["failing"], [&"grammar"], "names the failing skill")
	assert_true(not Mastery.evaluate_gate(ok, &"N4")["passed"], "N4 also needs listening")
	assert_true(Mastery.exam_unlocked({&"vocab": 70, &"grammar": 75, &"reading": 70, &"conversation": 65, &"kanji": 65}, &"N5"), "unlocked at threshold-15")
	assert_eq(Mastery.next_stage(&"N1"), &"MASTERY", "N1 leads to Mastery")
	assert_eq(Mastery.skills_by_gap({&"vocab": 85, &"grammar": 10, &"reading": 85, &"conversation": 80, &"kanji": 80}, &"N5")[0], &"grammar", "largest gap first")
	return true


func test_mastery_level_formula() -> bool:
	assert_eq(Mastery.level_for_xp(0), 1, "level 1 at 0 xp")
	assert_eq(Mastery.level_for_xp(1000), 2, "level 2 at 1000")
	assert_eq(Mastery.level_for_xp(45000), 10, "level 10 at 45000")
	return true


func test_mastery_cooldowns() -> bool:
	assert_eq(Mastery.exam_cooldown_seconds(1), 24 * 3600, "first fail 24h")
	assert_eq(Mastery.exam_cooldown_seconds(2), 48 * 3600, "second fail 48h")
	assert_eq(Mastery.exam_cooldown_seconds(9), 72 * 3600, "capped at 72h")
	return true


func test_word_rank_promotion() -> bool:
	var w := Mastery.new_word()
	w["rank"] = Mastery.Rank.DISCOVERED
	w = Mastery.word_correct(w, "rec")
	assert_eq(w["rank"], Mastery.Rank.DISCOVERED, "one rec is not enough")
	w = Mastery.word_correct(w, "rec")
	assert_eq(w["rank"], Mastery.Rank.FAMILIAR, "rec>=2 -> Familiar")
	for i in 2:
		w = Mastery.word_correct(w, "rec")
	for i in 2:
		w = Mastery.word_correct(w, "rcl")
	assert_eq(w["rank"], Mastery.Rank.LEARNED, "rec>=4 & rcl>=2 -> Learned")
	var jump := {"rank": Mastery.Rank.FAMILIAR, "rec": 9, "rcl": 9, "use": 9, "box": 8, "streak": 9, "lapses": 0, "due": 0}
	assert_eq(Mastery.promoted_rank(jump), Mastery.Rank.LEARNED, "promotion capped at one rank")
	return true


func test_word_lapse() -> bool:
	var w := {"rank": Mastery.Rank.PROFICIENT, "rec": 5, "rcl": 4, "use": 3, "box": 5, "streak": 4, "lapses": 0, "due": 0}
	w = Mastery.word_lapse(w, "rcl", 100)
	assert_eq(w["rank"], Mastery.Rank.LEARNED, "rank drops one")
	assert_eq(w["rcl"], 2, "tested counter -2")
	assert_eq(w["box"], 3, "box -2")
	w = Mastery.word_lapse(w, "rcl", 200)
	w = Mastery.word_lapse(w, "rcl", 300)
	assert_eq(w["rank"], Mastery.Rank.FAMILIAR, "floor is Familiar")
	return true


func test_word_lapse_mastered_grace() -> bool:
	var w := {"rank": Mastery.Rank.MASTERED, "rec": 9, "rcl": 9, "use": 9, "box": 7, "streak": 8, "lapses": 0, "due": 0}
	w = Mastery.word_lapse(w, "rec", 1_000_000)
	assert_eq(w["rank"], Mastery.Rank.MASTERED, "first lapse is graced")
	assert_eq(w["box"], 5, "box still drops")
	w = Mastery.word_lapse(w, "rec", 1_000_000 + 3600)
	assert_eq(w["rank"], Mastery.Rank.PROFICIENT, "second lapse within 30 days demotes")
	return true


# ---------------------------------------------------------------- Srs

func test_srs_next_box() -> bool:
	assert_eq(Srs.next_box(0, Srs.C_CORRECT), 1, "correct moves up one")
	assert_eq(Srs.next_box(8, Srs.C_CORRECT), 8, "capped at MAX_BOX")
	assert_eq(Srs.next_box(3, Srs.C_PARTIAL), 3, "partial keeps the box")
	assert_eq(Srs.next_box(5, Srs.C_WRONG), 3, "wrong drops two")
	assert_eq(Srs.next_box(1, Srs.C_WRONG), 0, "floored at 0")
	assert_eq(Srs.next_box(4, 0.75), 4, "in-between grade counts as partial")
	return true


func test_srs_review_schedules_due() -> bool:
	var now := 1_000_000
	var w := Mastery.new_word()
	w = Srs.review(w, Srs.C_CORRECT, now)
	assert_eq(w["due"], now + 4 * 3600, "box 1 is due in 4h")
	w = Srs.review(w, Srs.C_CORRECT, now)
	assert_eq(w["due"], now + 24 * 3600, "box 2 is due in 1d")
	assert_near(Srs.interval_hours(99), 2880.0, "box clamped to 120 days")
	return true


func test_srs_pick_due_orders_and_caps() -> bool:
	var now := 5000
	var words := {}
	for i in 25:
		var w := Mastery.new_word()
		w["rank"] = Mastery.Rank.FAMILIAR
		w["srs"] = true
		w["due"] = now - i
		words["w%02d" % i] = w
	var not_studied := Mastery.new_word()
	not_studied["rank"] = Mastery.Rank.DISCOVERED
	words["browsed"] = not_studied
	var due := Srs.pick_due(words, now, 20)
	assert_eq(due.size(), 20, "capped at 20")
	assert_eq(due[0], "w24", "most overdue first")
	assert_true("browsed" not in due, "words not added with 学習する are not scheduled")
	return true


# ---------------------------------------------------------------- Quests & Recommender

func test_quests() -> bool:
	assert_eq(Quests.newly_completed({"reviews": 19}, []).size(), 0, "not yet")
	var done := Quests.newly_completed({"reviews": 20, "sentences": 5}, ["sentences"])
	assert_eq(done.size(), 1, "one new quest")
	assert_eq(done[0]["id"], "reviews", "reviews quest")
	return true


func test_recommender_rules() -> bool:
	var zero := {&"vocab": 0, &"grammar": 0, &"reading": 0, &"conversation": 0, &"kanji": 0}
	var base := {"kana_mastery": 0.95, "due_count": 0, "exam_unlocked": false, "scores": zero, "stage": &"N5",
		"history": [], "daily_done": false, "daily_score": 0, "familiar_words": 0, "budget_left": 10, "weakest_grammar_correct": 5}
	var s := base.duplicate()
	s["kana_mastery"] = 0.5
	assert_eq(Recommender.recommend(s)["screen"], Recommender.KANA, "kana first")
	s = base.duplicate()
	s["due_count"] = 12
	assert_eq(Recommender.recommend(s)["screen"], Recommender.REVIEW, "big review pile")
	s = base.duplicate()
	s["exam_unlocked"] = true
	s["daily_done"] = true
	s["daily_score"] = 90
	assert_eq(Recommender.recommend(s), {"screen": Recommender.ASSESSMENT, "mode": "gate", "reason": Recommender.REASON["exam"]}, "exam after a good daily check")
	s = base.duplicate()
	s["familiar_words"] = 60
	assert_eq(Recommender.recommend(s)["mode"], "daily", "daily check when enough words are known")
	s = base.duplicate()
	s["scores"] = {&"vocab": 80, &"grammar": 10, &"reading": 80, &"conversation": 60, &"kanji": 75}
	assert_eq(Recommender.recommend(s)["screen"], Recommender.SENTENCES, "weak grammar -> builder")
	s["weakest_grammar_correct"] = 0
	assert_eq(Recommender.recommend(s)["screen"], Recommender.GRAMMAR, "uncovered grammar -> lesson")
	s["weakest_grammar_correct"] = 5
	s["history"] = ["sentences:", "sentences:"]
	assert_eq(Recommender.recommend(s)["screen"], Recommender.SENTENCES, "two attempts: still the usual suggestion")
	s = base.duplicate()
	s["scores"] = {&"vocab": 10, &"grammar": 85, &"reading": 80, &"conversation": 75, &"kanji": 75}
	s["budget_left"] = 0
	assert_eq(Recommender.recommend(s)["screen"], Recommender.REVIEW, "no budget -> review")
	s["scores"] = {&"vocab": 85, &"grammar": 90, &"reading": 85, &"conversation": 80, &"kanji": 10}
	assert_eq(Recommender.recommend(s)["screen"], Recommender.KANJI, "weak kanji -> kanji screen")
	return true


func test_recommender_shuffle() -> bool:
	var base := {"kana_mastery": 0.95, "due_count": 0, "exam_unlocked": false, "stage": &"N5",
		"scores": {&"vocab": 80, &"grammar": 10, &"reading": 80, &"conversation": 60, &"kanji": 75},
		"history": [], "daily_done": false, "daily_score": 0, "familiar_words": 0, "budget_left": 10,
		"weakest_grammar_correct": 5, "roll": 0}
	var usual := Recommender.recommend(base)
	assert_eq(Recommender.key(usual), "sentences:", "usual suggestion")
	var s := base.duplicate()
	s["history"] = ["sentences:", "sentences:", "sentences:"]
	var shuffled := Recommender.recommend(s)
	assert_true(shuffled.get("shuffled", false), "three attempts in a row shuffle")
	assert_true(Recommender.key(shuffled) != "sentences:", "the shuffle never repeats the usual one")
	assert_true(String(shuffled["reason"]).begins_with(Recommender.SHUFFLED_REASON), "shuffled reason says why")
	var picks := {}
	for roll in 8:
		s["roll"] = roll
		picks[Recommender.key(Recommender.recommend(s))] = true
	assert_true(picks.size() > 1, "different rolls give different activities")
	s["roll"] = 3
	assert_eq(Recommender.recommend(s), Recommender.recommend(s), "same roll, same pick (stable between visits)")
	s["history"] = ["sentences:", "kanji:", "sentences:"]
	assert_eq(Recommender.key(Recommender.recommend(s)), "sentences:", "a different attempt resets the run")
	s = base.duplicate()
	s["exam_unlocked"] = true
	s["daily_done"] = true
	s["daily_score"] = 90
	s["history"] = ["assessment:gate", "assessment:gate", "assessment:gate"]
	assert_eq(Recommender.recommend(s)["mode"], "gate", "the stage exam is never shuffled away")
	assert_eq(Recommender.key(Recommender.for_skill(&"reading", base)), "review:reading", "reading -> example reading")
	for rec in Recommender.alternatives(base):
		assert_true(rec["screen"] != Recommender.LISTENING, "no listening without a voice")
	base["tts"] = true
	var has_listening := false
	for rec in Recommender.alternatives(base):
		has_listening = has_listening or rec["screen"] == Recommender.LISTENING
	assert_true(has_listening, "listening offered with a voice")
	return true


func test_update_check() -> bool:
	assert_eq(UpdateCheck.parse_version("v0.3.1"), [0, 3, 1], "tag with v")
	assert_eq(UpdateCheck.parse_version("1.2"), [1, 2, 0], "short version padded")
	assert_eq(UpdateCheck.parse_version("v1.0.0-beta"), [1, 0, 0], "suffix ignored")
	assert_true(UpdateCheck.is_newer("v0.4.0", "0.3.1"), "minor bump is newer")
	assert_true(UpdateCheck.is_newer("0.3.10", "0.3.9"), "numeric, not text, comparison")
	assert_true(UpdateCheck.is_newer("1.0", "0.9.9"), "major bump is newer")
	assert_true(not UpdateCheck.is_newer("v0.3.1", "0.3.1"), "same version is not newer")
	assert_true(not UpdateCheck.is_newer("0.3.0", "0.3.1"), "older is not newer")
	var release := {"tag_name": "v0.4.0", "html_url": "https://example.test/r", "draft": false, "prerelease": false,
		"assets": [{"name": "SHA256SUMS.txt", "browser_download_url": "x"},
			{"name": "NihongoNoSekai-v0.4.0-android.apk", "browser_download_url": "https://example.test/a.apk"}]}
	release["assets"].append({"name": "NihongoNoSekai-v0.4.0-windows.zip", "browser_download_url": "https://example.test/w.zip"})
	var info := UpdateCheck.from_release(release)
	assert_eq(info["version"], "0.4.0", "release version")
	assert_eq(info["apk"], "https://example.test/a.apk", "android download")
	assert_eq(UpdateCheck.download_url(info, "Android"), "https://example.test/a.apk", "android gets the apk")
	assert_eq(UpdateCheck.download_url(info, "Windows"), "https://example.test/w.zip", "windows gets the zip")
	assert_eq(UpdateCheck.download_url(info, "Linux"), "https://example.test/r", "no linux file -> release page")
	assert_eq(UpdateCheck.download_url(info, "Web"), "https://example.test/r", "web -> release page")
	release["prerelease"] = true
	assert_eq(UpdateCheck.from_release(release), {}, "pre-releases are ignored")
	assert_eq(UpdateCheck.from_release({"message": "API rate limit exceeded"}), {}, "error body is ignored")
	return true


func test_stroke_match() -> bool:
	var hi: Array[PackedVector2Array] = content.strokes("日")
	assert_eq(hi.size(), 4, "日 has four strokes")
	assert_true(content.strokes("国").size() == 8, "国 has eight strokes")
	assert_true(content.strokes("ゞ").is_empty(), "no data -> no strokes")
	var first := hi[0]
	assert_true(StrokeMatch.judge(first, first)["ok"], "the model stroke matches itself")
	var wobbly := PackedVector2Array()
	for i in StrokeMatch.resample(first).size():
		var p := StrokeMatch.resample(first)[i]
		wobbly.append(p + Vector2(5.0 + 3.0 * sin(i * 0.6), 4.0))
	assert_true(StrokeMatch.judge(wobbly, first)["ok"], "a shaky, shifted hand-drawn stroke still matches")
	var backwards := first.duplicate()
	backwards.reverse()
	assert_eq(StrokeMatch.judge(backwards, first)["reason"], "direction", "drawn backwards -> direction")
	assert_eq(StrokeMatch.judge(hi[2], first)["reason"], "shape", "a horizontal stroke is not the vertical one")
	assert_true(not StrokeMatch.judge(hi[3], hi[2])["ok"], "the bottom bar is not the middle bar (position counts)")
	assert_eq(StrokeMatch.judge(PackedVector2Array([Vector2(30, 30), Vector2(30.5, 30)]), first)["reason"], "short", "a tap is ignored")
	var dot := PackedVector2Array([Vector2(50, 50), Vector2(53, 55), Vector2(55, 60)])
	assert_true(StrokeMatch.judge(PackedVector2Array([Vector2(48, 50), Vector2(52, 57)]), dot)["ok"], "dots only need the right place")
	assert_true(not StrokeMatch.judge(PackedVector2Array([Vector2(10, 90), Vector2(14, 95)]), dot)["ok"], "a dot in the wrong place fails")
	assert_eq(StrokeMatch.resample(first, 10).size(), 10, "resample count")
	assert_true(absf(StrokeMatch.length(StrokeMatch.resample(first, 40)) - StrokeMatch.length(first)) < 2.0, "resampling keeps the length")
	assert_eq(StrokeMatch.to_box(PackedVector2Array([Vector2(218, 109)]), 218.0)[0], Vector2(109, 54.5), "pad -> box")
	return true


func test_writing_progress() -> bool:
	assert_eq(Mastery.writing_correctness(0, 4), 1.0, "clean")
	assert_eq(Mastery.writing_correctness(1, 4), 0.5, "one slip on a short kanji")
	assert_eq(Mastery.writing_correctness(2, 4), 0.0, "two slips on four strokes")
	assert_eq(Mastery.writing_correctness(3, 12), 0.5, "longer kanji allow more slips")
	assert_true(Mastery.SKILLS.has(&"writing"), "writing is a skill")
	assert_true(not (Mastery.GATES[&"N5"] as Dictionary).has(&"writing"), "writing is optional (no gate)")
	fresh_progress()
	var before: int = progress.xp
	progress.record_writing("日", false, 0, 4)
	assert_eq(progress.writing["日"]["traced"], 1, "tracing counted")
	assert_eq(progress.writing_clean("日"), 0, "tracing is not a clean write")
	assert_eq(progress.coverage(&"writing"), 0.0, "no coverage from tracing")
	progress.record_writing("日", true, 0, 4)
	assert_eq(progress.writing_clean("日"), 1, "clean from memory")
	assert_true(progress.coverage(&"writing") > 0.0, "coverage after a clean write")
	assert_true(progress.xp > before, "writing earns XP")
	assert_true(progress.scores()[&"writing"] > 0, "writing score rises")
	progress.from_dict(JSON.parse_string(JSON.stringify(progress.to_dict())))
	assert_eq(progress.writing_clean("日"), 1, "writing survives a save")
	var rec := Recommender.for_skill(&"writing", {})
	assert_eq(rec["screen"], Recommender.WRITING, "writing skill -> writing screen")
	return true


func test_backup_restore() -> bool:
	fresh_progress()
	progress.add_xp(1234)
	progress.record_writing("日", true, 0, 4)
	var saved_xp: int = progress.xp
	var code: String = progress.backup_code()
	assert_true(code.begins_with(progress.BACKUP_PREFIX), "backup code has its prefix")
	assert_true(not code.contains("\n"), "backup code is one line")
	fresh_progress()
	assert_eq(progress.xp, 0, "fresh before restore")
	assert_true(not progress.restore_backup("hello"), "random text is refused")
	assert_true(not progress.restore_backup(progress.BACKUP_PREFIX + "!!!"), "broken code is refused")
	assert_eq(progress.xp, 0, "a refused restore changes nothing")
	assert_true(progress.restore_backup("  " + code + "\n"), "pasted code with spaces restores")
	assert_eq(progress.xp, saved_xp, "xp restored")
	assert_eq(progress.writing_clean("日"), 1, "writing restored")
	assert_true(progress.restore_backup(JSON.stringify(progress.to_dict())), "raw save JSON restores too")
	assert_true(Quests.quest("writing")["target"] > 0, "daily writing quest exists")
	return true


func test_style_drills() -> bool:
	var item := {"id": "t1", "from": "{行|い}きます。", "to_register": "casual", "answer": "{行|い}く。",
		"distractors": ["{行|い}きる。", "{行|い}くです。"], "en": "go", "note": "ます -> plain"}
	var q := StyleDrills.rewrite_question(item, [2, 0, 1])
	assert_eq(q["options"][q["answer"]], "{行|い}く。", "answer index follows the order")
	assert_eq(q["context"], "{行|い}きます。", "the source sentence is shown")
	assert_true(String(q["prompt"]).contains("{普通|ふつう}"), "prompt names the target register")
	var sc := [{"id": "s", "turns": [
		{"speaker": "A", "line_ja": "こんにちは", "line_en": "hi", "options": [
			{"ja": "こんにちは", "verdict": "correct"}, {"ja": "おはよう", "verdict": "unnatural", "feedback_ja": "x", "feedback_en": "y"}]},
		{"speaker": "A", "line_ja": "はい", "line_en": "yes", "options": [{"ja": "はい", "verdict": "correct"}, {"ja": "いいえ", "verdict": "wrong"}]}]}]
	var nat := StyleDrills.unnatural_questions(sc)
	assert_eq(nat.size(), 1, "only turns with an unnatural reply become questions")
	assert_eq(nat[0]["options"][nat[0]["answer"]], "おはよう", "the unnatural reply is the answer")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 10:
		var s := StyleDrills.shuffled(q, rng)
		assert_eq(s["options"][s["answer"]], "{行|い}く。", "shuffling keeps the answer right")
	var real := StyleDrills.unnatural_questions(content.unlocked_items("scenarios", &"N5"))
	assert_true(real.size() >= 5, "N5 scenarios give unnatural-reply questions")
	assert_true(content.stage_items("rewrites", &"N5").size() >= 20, "N5 rewrite drills load")
	return true


# ---------------------------------------------------------------- Content

func test_content_loads() -> bool:
	assert_true(content.stage_items("vocab", &"N5").size() >= 600, "N5 vocab ~700 words")
	assert_true(content.stage_items("grammar", &"N5").size() >= 40, "N5 grammar ~45 points")
	assert_true(content.stage_items("sentences", &"N5").size() >= 40, "N5 sentence prompts")
	assert_true(content.stage_items("scenarios", &"N5").size() >= 6, "N5 scenarios")
	assert_true(content.stage_items("passages", &"N5").size() >= 8, "N5 passages")
	assert_true(content.stage_items("anchors", &"N5").size() >= 8, "N5 anchors")
	assert_eq(content.stage_items("kanji", &"N5").size(), 103, "N5 kanji from KanjiDic2")
	assert_eq(content.kana["hiragana"].size(), 104, "hiragana rows incl. yoon")
	assert_eq(content.word_by_headword("勉強")["reading"], "べんきょう", "lookup by headword")
	assert_true(content.search_vocab("water").size() >= 1, "english search")
	assert_true(content.search_vocab("benkyou").size() >= 1, "romaji search")
	for g in content.grammar:
		for item in g["items"]:
			assert_true(int(item["answer"]) < (item["options"] as Array).size(), "grammar item answer in range (%s)" % g["id"])
	for s in content.sentences:
		for gid in s["grammar"]:
			assert_true(not content.grammar_point(gid).is_empty(), "sentence %s grammar %s exists" % [s["id"], gid])
	return true


func test_content_stages() -> bool:
	for stage in [&"N4", &"N3", &"N2", &"N1", &"MASTERY"]:
		assert_true(content.has_stage_content(stage), "%s has content" % stage)
		var pack: Dictionary = content.stage_pack(stage)
		assert_true((pack["vocab"] as Array).size() >= 10, "%s pack has vocab" % stage)
	assert_true(content.unlocked_items("vocab", &"N4").size() > content.stage_items("vocab", &"N5").size(), "unlocked includes earlier stages")
	return true


func test_exam_builder() -> bool:
	var pack: Dictionary = content.stage_pack(&"N5")
	var exam: Array = ExamBuilder.build_exam(pack)
	var first_slot := 0
	for q in exam:
		assert_true(int(q["answer"]) >= 0 and int(q["answer"]) < (q["options"] as Array).size(), "answer index is inside the options")
		if int(q["answer"]) == 0:
			first_slot += 1
	assert_true(first_slot < exam.size() * 0.7, "answers are not mostly the first option (%d of %d)" % [first_slot, exam.size()])
	var counts := {}
	for q in exam:
		counts[q["skill"]] = int(counts.get(q["skill"], 0)) + 1
		var opts: Array = q["options"]
		assert_true(opts.size() >= 2, "question has options")
		assert_true(int(q["answer"]) >= 0 and int(q["answer"]) < opts.size(), "answer index in range")
		var uniq := {}
		for o in opts:
			uniq[o] = true
		assert_eq(uniq.size(), opts.size(), "options unique (%s %s)" % [q["skill"], q.get("item_id", "")])
	assert_eq(counts.get(&"vocab", 0), 10, "10 vocab questions")
	assert_eq(counts.get(&"grammar", 0), 10, "10 grammar questions")
	assert_eq(counts.get(&"reading", 0), 8, "8 reading questions")
	assert_eq(counts.get(&"kanji", 0), 6, "6 kanji questions")
	assert_eq(counts.get(&"conversation", 0), 6, "6 conversation questions")
	assert_true(not counts.has(&"listening"), "no listening at N5 by default")
	var flags: Array = []
	for q in exam:
		flags.append(q["skill"] == &"vocab")
	var sections: Dictionary = ExamBuilder.section_scores(exam, flags)
	assert_eq(sections[&"vocab"], 100, "all vocab correct")
	assert_eq(sections[&"grammar"], 0, "no grammar correct")
	# No-repeat: excluding every item id of one exam yields a different vocab set.
	var exclude := {}
	for q in exam:
		exclude[q.get("item_id", "")] = true
	var again: Array = ExamBuilder.build_exam(pack, {}, exclude)
	var overlap := 0
	for q in again:
		if q["skill"] == &"vocab" and exclude.has(q["item_id"]):
			overlap += 1
	assert_eq(overlap, 0, "vocab items not repeated")
	return true


func test_exam_daily_and_listening() -> bool:
	var pack: Dictionary = content.stage_pack(&"N4")
	var exam: Array = ExamBuilder.build_exam(pack, {}, {}, true)
	var listening := exam.filter(func(q: Dictionary) -> bool: return q["skill"] == &"listening")
	assert_eq(listening.size(), ExamBuilder.LISTENING_QUESTIONS, "listening section when requested")
	assert_true(listening[0].get("listen_only", false), "listening question hides the text")
	var daily: Array = ExamBuilder.build_daily(content.stage_pack(&"N5"), {}, [&"grammar", &"kanji"])
	assert_eq(daily.size(), 10, "daily check has 10 questions")
	var g := daily.filter(func(q: Dictionary) -> bool: return q["skill"] == &"grammar").size()
	assert_true(g >= 3, "weakest skill weighted (grammar x%d)" % g)
	return true


func test_headword_markup() -> bool:
	assert_eq(ExamBuilder.headword_markup({"headword": "食べる", "reading": "たべる"}), "{食|た}べる", "okurigana outside")
	assert_eq(ExamBuilder.headword_markup({"headword": "お茶", "reading": "おちゃ"}), "お{茶|ちゃ}", "honorific prefix outside")
	assert_eq(ExamBuilder.headword_markup({"headword": "コンビニ", "reading": "コンビニ"}), "コンビニ", "katakana unchanged")
	assert_eq(ExamBuilder.headword_markup({"headword": "勉強", "reading": "べんきょう"}), "{勉強|べんきょう}", "kanji word")
	return true


# ---------------------------------------------------------------- Progress (autoload)

func test_progress_roundtrip() -> bool:
	fresh_progress()
	progress.record_sample(&"sentence_builder", 1.0)
	assert_true(progress.study_word(wid("勉強")), "study a word")
	progress.record_word_answer(wid("勉強"), "rec", Srs.C_CORRECT)
	progress.record_grammar("n5_wa", true)
	progress.add_xp(1200)
	progress.set_setting("theme", "dark")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(progress.to_dict()))
	progress.from_dict(parsed)
	assert_eq(progress.xp, 1200, "xp survives")
	assert_eq(progress.level(), 2, "level derived")
	assert_eq(progress.word(wid("勉強"))["rec"], 1, "word counters survive")
	assert_eq(progress.word(wid("勉強"))["box"], 1, "box survives")
	assert_true(progress.in_srs(wid("勉強")), "srs flag survives")
	assert_eq(progress.setting("theme"), "dark", "settings survive")
	assert_eq(progress.grammar["n5_wa"]["correct"], 1, "grammar record survives")
	var v1 := {"version": 1, "words": {"x": {"rank": 2, "box": 1, "due": 0}}}
	progress.from_dict(v1)
	assert_true(progress.in_srs("x"), "v1 saves migrate discovered words into reviews")
	fresh_progress()
	var rec := {"screen": &"kanji", "mode": "", "reason": ""}
	for i in 5:
		progress.record_recommend_attempt(rec)
	assert_eq(progress.recommend_history, ["kanji:", "kanji:", "kanji:"], "attempt history keeps the last three")
	var roll: int = progress.recommend_roll
	progress.from_dict(JSON.parse_string(JSON.stringify(progress.to_dict())))
	assert_eq(progress.recommend_roll, roll, "roll survives a save")
	assert_true(progress.recommender_input().has("roll"), "recommender input carries the roll")
	return true


func test_progress_study_budget_and_review() -> bool:
	var clock := fresh_progress()
	progress.discover_word(wid("私"))
	assert_eq(progress.due_words().size(), 0, "browsing does not schedule")
	assert_true(progress.study_word(wid("私")), "学習する schedules")
	assert_eq(progress.due_words(), [wid("私")] as Array[String], "studied word is due now")
	assert_true(not progress.study_word(wid("私")), "cannot study twice")
	progress.record_word_answer(wid("私"), "rec", Srs.C_CORRECT)
	assert_eq(progress.due_words().size(), 0, "answered word is scheduled later")
	clock[0] += 5 * 3600
	assert_eq(progress.due_words().size(), 1, "due again after 4h")
	progress.record_word_answer(wid("私"), "rec", Srs.C_WRONG)
	assert_eq(progress.word(wid("私"))["box"], 0, "lapse drops to box 0")
	var budget: int = progress.budget_left()
	var studied := 0
	for e in content.stage_items("vocab", &"N5"):
		if progress.study_word(e["id"]):
			studied += 1
		if studied > 30:
			break
	assert_eq(studied, budget, "daily new-word budget enforced")
	clock[0] += 86400
	assert_true(progress.budget_left() > 0, "budget resets the next day")
	return true


func test_progress_daily_quests() -> bool:
	fresh_progress()
	var xp_before: int = progress.xp
	for i in 5:
		progress.record_prompt("p%d" % i, 1.0)
	assert_true(progress.quest_paid("sentences"), "five sentences pays the quest")
	assert_eq(progress.xp, xp_before + 150, "quest XP paid once")
	progress.record_prompt("p9", 1.0)
	assert_eq(progress.xp, xp_before + 150, "not paid twice")
	progress.record_daily(90)
	assert_true(progress.daily["assessment_done"], "daily check recorded")
	assert_true(progress.quest_paid("daily_assessment"), "daily check quest")
	return true


func test_progress_exam_flow() -> bool:
	var clock := fresh_progress()
	var fail := {&"vocab": 50, &"grammar": 50, &"reading": 50, &"conversation": 50, &"kanji": 50}
	progress.record_exam(fail, ["a", "b"])
	assert_true(progress.on_cooldown(), "fail starts a cooldown")
	assert_eq(progress.cooldown_until - clock[0], 24 * 3600, "24h after first fail")
	progress.record_exam(fail)
	assert_eq(progress.cooldown_until - clock[0], 48 * 3600, "48h after second fail")
	assert_true(progress.recent_exam_items().has("a"), "items remembered for no-repeat")
	var pass_sections := {&"vocab": 90, &"grammar": 95, &"reading": 90, &"conversation": 85, &"kanji": 85}
	progress.record_exam(pass_sections)
	assert_eq(progress.stage, &"N4", "pass advances the stage")
	assert_true(not progress.on_cooldown(), "pass clears the cooldown")
	assert_eq(progress.english_mode, progress.STAGE_ENGLISH[&"N4"], "assistance follows the stage when automatic")
	return true


func test_screens_instantiate() -> bool:
	fresh_progress()
	var main_script: GDScript = load("res://scripts/main.gd")
	for name: StringName in main_script.SCREENS:
		var screen: Control = (load(main_script.SCREENS[name]) as GDScript).new()
		root.add_child(screen)
		await process_frame
		assert_true(screen.get_child_count() > 0, "%s built its widgets" % name)
		screen.queue_free()
		await process_frame
	for mode in ["daily", "practice"]:
		var a: Control = (load(main_script.SCREENS[&"assessment"]) as GDScript).new()
		a.set("args", {"mode": mode})
		root.add_child(a)
		await process_frame
		assert_true(a.get_child_count() > 0, "assessment %s builds" % mode)
		a.queue_free()
		await process_frame
	var label := FuriganaLabel.new()
	label.text = "{私|わたし}は{学生|がくせい}です。"
	label.autowrap = false
	assert_true(label.get_combined_minimum_size().x > 0, "furigana label measures its text")
	assert_eq(label.ruby_size(), 12, "ruby is half the base")
	UITheme.apply(true, false)
	assert_eq(UITheme.BG, Color("#1C1917"), "dark palette applies")
	UITheme.apply(false, false)
	return true
