# Headless GDScript test runner. Run from the repo root with:
#   godot --headless --path game --import          (once, on a fresh checkout)
#   godot --headless --path game --script res://tests/test_runner.gd
# Exit code is 0 only when every test passes; CI gates on it.
extends SceneTree

var passed := 0
var failed := 0

# Autoloads are registered after this script compiles, so fetch them from the tree by path.
var content: Node
var progress: Node

const TESTS: Array[String] = [
	"test_furigana_parse",
	"test_furigana_plain_and_reading",
	"test_sentence_check_correct_and_alternatives",
	"test_sentence_check_wrong_tiles_and_order",
	"test_mastery_sample_and_score",
	"test_mastery_gate_and_margin",
	"test_mastery_level_formula",
	"test_word_rank_promotion",
	"test_word_lapse",
	"test_srs_next_box",
	"test_srs_review_schedules_due",
	"test_srs_pick_due_orders_and_caps",
	"test_content_loads",
	"test_progress_roundtrip",
	"test_progress_review_flow",
	"test_recommender_rules",
	"test_exam_builder",
	"test_screens_instantiate",
]


func _initialize() -> void:
	# Autoloads enter the tree only after the first frame in --script mode.
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


# ---------------------------------------------------------------- Furigana

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


# ---------------------------------------------------------------- SentenceCheck

func test_sentence_check_correct_and_alternatives() -> bool:
	var accepted := [["{昨日|きのう}", "{学校|がっこう}", "に", "{行|い}きました"], ["{学校|がっこう}", "に", "{昨日|きのう}", "{行|い}きました"]]
	var r := SentenceCheck.evaluate(["{学校|がっこう}", "に", "{昨日|きのう}", "{行|い}きました"], accepted)
	assert_eq(r["result"], SentenceCheck.Result.CORRECT, "alternative order accepted")
	return true


func test_sentence_check_wrong_tiles_and_order() -> bool:
	var accepted := [["{水|みず}", "を", "ください"]]
	var r := SentenceCheck.evaluate(["{水|みず}", "が", "ください"], accepted)
	assert_eq(r["result"], SentenceCheck.Result.WRONG_TILES, "distractor used")
	assert_eq(r["first_bad_index"], 1, "points at the distractor")
	assert_true(r["hint"].contains("が"), "hint names the extra tile")
	r = SentenceCheck.evaluate(["を", "{水|みず}", "ください"], accepted)
	assert_eq(r["result"], SentenceCheck.Result.WRONG_ORDER, "same tiles, wrong order")
	assert_eq(r["first_bad_index"], 0, "diverges at index 0")
	r = SentenceCheck.evaluate(["{水|みず}", "を"], accepted)
	assert_eq(r["result"], SentenceCheck.Result.WRONG_TILES, "missing tile")
	return true


# ---------------------------------------------------------------- Mastery

func test_mastery_sample_and_score() -> bool:
	var s := Mastery.new_skill()
	s = Mastery.apply_sample(s, 1.0, 1.0)
	assert_near(s["perf"], 0.08, "one correct sample moves perf by alpha")
	assert_near(s["n"], 1.0, "n counts weight")
	s = Mastery.apply_sample(s, 0.0, 1.5)
	assert_near(s["perf"], 0.08 - 0.08 * 1.5 * 0.08, "weighted wrong sample")
	# GDD worked example: cov 0.6, perf 0.82, n 90 -> 71
	assert_eq(Mastery.score({"perf": 0.82, "n": 90.0}, &"vocab", 0.6), 71, "GDD worked example")
	assert_eq(Mastery.score({"perf": 1.0, "n": 15.0}, &"reading", 0.0), 50, "confidence halves at n=15")
	assert_eq(Mastery.score({"perf": 1.0, "n": 30.0}, &"reading", 0.0), 100, "full confidence")
	return true


func test_mastery_gate_and_margin() -> bool:
	var ok := {&"vocab": 85, &"grammar": 90, &"reading": 85, &"conversation": 80, &"kanji": 80}
	assert_true(Mastery.evaluate_gate(ok, &"N5")["passed"], "exact thresholds pass")
	var low := ok.duplicate()
	low[&"grammar"] = 89
	var r := Mastery.evaluate_gate(low, &"N5")
	assert_true(not r["passed"], "one skill below fails")
	assert_eq(r["failing"], [&"grammar"], "names the failing skill")
	assert_true(Mastery.exam_unlocked({&"vocab": 70, &"grammar": 75, &"reading": 70, &"conversation": 65, &"kanji": 65}, &"N5"), "unlocked at threshold-15")
	assert_true(not Mastery.exam_unlocked({&"vocab": 69, &"grammar": 90, &"reading": 85, &"conversation": 80, &"kanji": 80}, &"N5"), "locked below margin")
	assert_eq(Mastery.next_stage(&"N5"), &"N4", "next stage")
	assert_eq(Mastery.next_stage(&"MASTERY"), &"MASTERY", "last stage sticks")
	var order := Mastery.skills_by_gap({&"vocab": 85, &"grammar": 10, &"reading": 85, &"conversation": 80, &"kanji": 80}, &"N5")
	assert_eq(order[0], &"grammar", "largest gap first")
	return true


func test_mastery_level_formula() -> bool:
	assert_eq(Mastery.level_for_xp(0), 1, "level 1 at 0 xp")
	assert_eq(Mastery.level_for_xp(999), 1, "still level 1 at 999")
	assert_eq(Mastery.level_for_xp(1000), 2, "level 2 at 1000")
	assert_eq(Mastery.level_for_xp(10000), 5, "level 5 at 10000")
	assert_eq(Mastery.level_for_xp(45000), 10, "level 10 at 45000")
	assert_eq(Mastery.xp_for_level(10), 45000, "inverse")
	return true


func test_word_rank_promotion() -> bool:
	var w := Mastery.new_word()
	w["rank"] = Mastery.Rank.DISCOVERED
	w = Mastery.word_correct(w, "rec")
	assert_eq(w["rank"], Mastery.Rank.DISCOVERED, "one rec is not enough")
	w = Mastery.word_correct(w, "rec")
	assert_eq(w["rank"], Mastery.Rank.FAMILIAR, "rec>=2 -> Familiar")
	w = Mastery.word_correct(w, "rec")
	w = Mastery.word_correct(w, "rec")
	w = Mastery.word_correct(w, "rcl")
	assert_eq(w["rank"], Mastery.Rank.FAMILIAR, "rcl 1 keeps Familiar")
	w = Mastery.word_correct(w, "rcl")
	assert_eq(w["rank"], Mastery.Rank.LEARNED, "rec>=4 & rcl>=2 -> Learned")
	# Proficient needs rcl>=4, use>=2, box>=4
	w = Mastery.word_correct(w, "rcl")
	w = Mastery.word_correct(w, "rcl")
	w = Mastery.word_correct(w, "use")
	w = Mastery.word_correct(w, "use")
	assert_eq(w["rank"], Mastery.Rank.LEARNED, "box too low for Proficient")
	w["box"] = 4
	assert_eq(Mastery.promoted_rank(w), Mastery.Rank.PROFICIENT, "box 4 unlocks Proficient")
	# Only one rank per call even if Mastered conditions are met
	var jump := {"rank": Mastery.Rank.FAMILIAR, "rec": 9, "rcl": 9, "use": 9, "box": 8, "streak": 9, "lapses": 0, "due": 0}
	assert_eq(Mastery.promoted_rank(jump), Mastery.Rank.LEARNED, "promotion capped at one rank")
	var unseen := Mastery.new_word()
	assert_eq(Mastery.promoted_rank(unseen), Mastery.Rank.UNSEEN, "unseen stays unseen")
	return true


func test_word_lapse() -> bool:
	var w := {"rank": Mastery.Rank.PROFICIENT, "rec": 5, "rcl": 4, "use": 3, "box": 5, "streak": 4, "lapses": 0, "due": 0}
	w = Mastery.word_lapse(w, "rcl")
	assert_eq(w["rank"], Mastery.Rank.LEARNED, "rank drops one")
	assert_eq(w["rcl"], 2, "tested counter -2")
	assert_eq(w["rec"], 5, "other counters untouched")
	assert_eq(w["box"], 3, "box -2")
	assert_eq(w["streak"], 0, "streak reset")
	assert_eq(w["lapses"], 1, "lapse counted")
	w = Mastery.word_lapse(w, "rcl")
	w = Mastery.word_lapse(w, "rcl")
	assert_eq(w["rank"], Mastery.Rank.FAMILIAR, "floor is Familiar")
	assert_eq(w["rcl"], 0, "counter floors at 0")
	assert_eq(w["box"], 0, "box floors at 0")
	return true


# ---------------------------------------------------------------- Srs

func test_srs_next_box() -> bool:
	assert_eq(Srs.next_box(0, Srs.C_CORRECT), 1, "correct moves up one")
	assert_eq(Srs.next_box(8, Srs.C_CORRECT), 8, "capped at MAX_BOX")
	assert_eq(Srs.next_box(3, Srs.C_PARTIAL), 3, "partial keeps the box")
	assert_eq(Srs.next_box(5, Srs.C_WRONG), 3, "wrong drops two")
	assert_eq(Srs.next_box(1, Srs.C_WRONG), 0, "floored at 0")
	return true


func test_srs_review_schedules_due() -> bool:
	var now := 1_000_000
	var w := Mastery.new_word()
	w["rank"] = Mastery.Rank.DISCOVERED
	w = Srs.review(w, Srs.C_CORRECT, now)
	assert_eq(w["box"], 1, "box 1 after first correct")
	assert_eq(w["due"], now + 4 * 3600, "box 1 is due in 4h")
	w = Srs.review(w, Srs.C_CORRECT, now)
	assert_eq(w["due"], now + 24 * 3600, "box 2 is due in 1d")
	assert_true(not Srs.is_due(w, now + 3600), "not due an hour later")
	assert_true(Srs.is_due(w, now + 25 * 3600), "due after a day")
	assert_near(Srs.interval_hours(8), 2880.0, "cap is 120 days")
	assert_near(Srs.interval_hours(99), 2880.0, "box clamped")
	return true


func test_srs_pick_due_orders_and_caps() -> bool:
	var now := 5000
	var words := {}
	for i in 25:
		var w := Mastery.new_word()
		w["rank"] = Mastery.Rank.FAMILIAR
		w["due"] = now - i  # later ids are more overdue
		words["w%02d" % i] = w
	words["future"] = {"rank": Mastery.Rank.FAMILIAR, "due": now + 10, "box": 1, "rec": 0, "rcl": 0, "use": 0, "streak": 0, "lapses": 0}
	words["unseen"] = Mastery.new_word()
	var due := Srs.pick_due(words, now, 20)
	assert_eq(due.size(), 20, "capped at 20")
	assert_eq(due[0], "w24", "most overdue first")
	assert_true("future" not in due, "future word excluded")
	assert_true("unseen" not in due, "unseen word excluded")
	return true


# ---------------------------------------------------------------- Content & Progress (autoloads)

func test_content_loads() -> bool:
	assert_true(content.vocab.size() >= 60, "vocab loaded")
	assert_true(content.grammar.size() >= 8, "grammar loaded")
	assert_true(content.sentences.size() >= 10, "sentences loaded")
	assert_eq(content.scenarios.size(), 1, "one scenario")
	assert_eq(content.kana["hiragana"].size(), 104, "hiragana rows incl. yoon")
	assert_eq(content.word_by_headword("勉強")["reading"], "べんきょう", "lookup by headword")
	assert_true(content.search_vocab("water").size() >= 1, "english search")
	assert_eq(content.random_words(3, wid("私")).size(), 3, "random words")
	for s in content.sentences:
		for acc in s["accepted"]:
			var sorted_acc: Array = acc.duplicate()
			var sorted_tiles: Array = s["tiles"].duplicate()
			sorted_acc.sort()
			sorted_tiles.sort()
			assert_eq(sorted_acc, sorted_tiles, "accepted order %s uses exactly the tiles" % s["id"])
	return true


func test_progress_roundtrip() -> bool:
	progress.persist = false
	progress.reset()
	var clock := [1_700_000_000]  # array: lambdas capture locals by value
	progress.now_provider = func() -> int: return clock[0]
	progress.record_sample(&"sentence_builder", 1.0)
	progress.discover_word(wid("勉強"))
	progress.record_word_answer(wid("勉強"), "rec", Srs.C_CORRECT)
	progress.record_grammar("n5_wa", true)
	progress.add_xp(1200)
	var data: Dictionary = progress.to_dict()
	var json := JSON.stringify(data)
	var parsed: Dictionary = JSON.parse_string(json)
	progress.from_dict(parsed)
	assert_eq(progress.xp, 1200, "xp survives")
	assert_eq(progress.level(), 2, "level derived")
	assert_eq(progress.word(wid("勉強"))["rec"], 1, "word counters survive")
	assert_eq(progress.word(wid("勉強"))["box"], 1, "box survives")
	assert_near(progress.skills[&"grammar"]["perf"], 0.08 * 0.6, "skill perf survives")
	assert_eq(progress.grammar["n5_wa"]["correct"], 1, "grammar record survives")
	assert_eq(progress.scores()[&"listening"], 0, "untouched skill is 0")
	return true


func test_progress_review_flow() -> bool:
	progress.persist = false
	progress.reset()
	var clock := [1_700_000_000]  # array: lambdas capture locals by value
	progress.now_provider = func() -> int: return clock[0]
	progress.discover_word(wid("私"))
	assert_eq(progress.due_words(), [wid("私")], "discovered word is due immediately")
	progress.record_word_answer(wid("私"), "rec", Srs.C_CORRECT)
	assert_eq(progress.due_words().size(), 0, "answered word is scheduled later")
	clock[0] += 5 * 3600
	assert_eq(progress.due_words(), [wid("私")], "due again after 4h")
	progress.record_word_answer(wid("私"), "rec", Srs.C_WRONG)
	assert_eq(progress.word(wid("私"))["box"], 0, "lapse drops to box 0")
	assert_eq(progress.word(wid("私"))["lapses"], 1, "lapse counted")
	assert_true(not progress.exam_unlocked(), "exam locked with zero scores")
	progress.record_kana("あ", true)
	progress.record_kana("あ", true)
	assert_true(progress.kana_mastery() > 0.0, "kana mastery counts streaks")
	return true


# ---------------------------------------------------------------- Recommender & ExamBuilder

func test_recommender_rules() -> bool:
	var zero := {&"vocab": 0, &"grammar": 0, &"reading": 0, &"conversation": 0, &"kanji": 0}
	assert_eq(Recommender.recommend(0.5, 0, false, zero, &"N5"), Recommender.KANA, "kana first")
	assert_eq(Recommender.recommend(0.95, 12, false, zero, &"N5"), Recommender.REVIEW, "big review pile")
	assert_eq(Recommender.recommend(0.95, 0, true, zero, &"N5"), Recommender.ASSESSMENT, "exam when unlocked")
	var weak_grammar := {&"vocab": 80, &"grammar": 10, &"reading": 80, &"conversation": 60, &"kanji": 75}
	assert_eq(Recommender.recommend(0.95, 0, false, weak_grammar, &"N5"), Recommender.SENTENCES, "weakest skill maps to builder")
	assert_eq(Recommender.recommend(0.95, 0, false, weak_grammar, &"N5", [Recommender.SENTENCES, Recommender.SENTENCES]), Recommender.CONVERSATION, "anti-repetition takes the next gap")
	var weak_vocab := {&"vocab": 10, &"grammar": 85, &"reading": 80, &"conversation": 75, &"kanji": 75}
	assert_eq(Recommender.recommend(0.95, 3, false, weak_vocab, &"N5"), Recommender.REVIEW, "vocab with due words -> review")
	assert_eq(Recommender.recommend(0.95, 0, false, weak_vocab, &"N5"), Recommender.DICTIONARY, "vocab without due words -> dictionary")
	return true


func test_exam_builder() -> bool:
	var exam: Array = ExamBuilder.build_exam(content.vocab, content.sentences, content.scenarios)
	assert_eq(exam.size(), 10 + 10 + 8 + 6 + 4, "question count from Phase 1 content")
	for q in exam:
		assert_true((q["options"] as Array).size() >= 2, "question has options")
		assert_true(int(q["answer"]) >= 0 and int(q["answer"]) < (q["options"] as Array).size(), "answer index in range")
		var opts: Array = q["options"]
		var uniq := {}
		for o in opts:
			uniq[o] = true
		assert_eq(uniq.size(), opts.size(), "options are unique (%s)" % q["skill"])
	var flags: Array = []
	for q in exam:
		flags.append(q["skill"] == &"vocab")
	var sections: Dictionary = ExamBuilder.section_scores(exam, flags)
	assert_eq(sections[&"vocab"], 100, "all vocab correct")
	assert_eq(sections[&"grammar"], 0, "no grammar correct")
	var entry: Dictionary = content.word_by_headword("勉強")
	var usage: Dictionary = ExamBuilder.usage_question(entry, content.vocab)
	assert_true(usage["prompt"].contains("［　　］"), "usage question blanks the headword")
	var conj: Dictionary = content.word_by_headword("食べる")
	assert_true(ExamBuilder.usage_question(conj, content.vocab).is_empty(), "no usage question for conjugated verbs")
	return true


func test_screens_instantiate() -> bool:
	progress.persist = false
	progress.reset()
	var main_script: GDScript = load("res://scripts/main.gd")
	for name: StringName in main_script.SCREENS:
		var screen: Control = (main_script.SCREENS[name] as GDScript).new()
		root.add_child(screen)
		await process_frame
		assert_true(screen.get_child_count() > 0, "%s built its widgets" % name)
		screen.queue_free()
		await process_frame
	var label := FuriganaLabel.new()
	label.text = "{私|わたし}は{学生|がくせい}です。"
	label.autowrap = false
	assert_true(label.get_combined_minimum_size().x > 0, "furigana label measures its text")
	assert_near(label.line_height(), 24 * 1.9, "line height is 1.9x base")
	assert_eq(label.ruby_size(), 12, "ruby is half the base")
	return true
