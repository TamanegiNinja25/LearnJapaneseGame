extends Node
## Autoload "Progress": the player's save state and the only place that mutates it.
## Rules live in Mastery, Srs and Quests (pure); this node applies them, derives scores and
## persists. Save layout follows docs/GAME_DESIGN.md §11.7.

signal scores_changed(scores: Dictionary)
signal word_changed(word_id: String, word: Dictionary)
signal rank_up(word_id: String, rank: int)
signal stage_changed(stage: StringName)
signal xp_changed(xp: int)
signal english_mode_changed(mode: int)
signal settings_changed
signal quest_completed(quest: Dictionary)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const REVIEW_SAMPLES := 200

## English assistance modes (concept §4). Higher = more English shown.
enum EnglishMode { JAPANESE_ONLY, EXPLANATIONS, TRANSLATIONS, BILINGUAL }
## Default assistance per stage; applied on stage-up unless the player chose a mode by hand.
const STAGE_ENGLISH := {&"N5": EnglishMode.TRANSLATIONS, &"N4": EnglishMode.TRANSLATIONS, &"N3": EnglishMode.EXPLANATIONS,
	&"N2": EnglishMode.EXPLANATIONS, &"N1": EnglishMode.JAPANESE_ONLY, &"MASTERY": EnglishMode.JAPANESE_ONLY}

## New-word budget (GDD §13 question 8, resolved): base 10, +5 when recent review accuracy is
## high and the pile is small, -5 when the pile is large.
const BUDGET_BASE := 10

var stage: StringName = &"N5"
var xp: int = 0
var english_mode: int = EnglishMode.TRANSLATIONS
var settings: Dictionary = {}
var skills: Dictionary = {}       # StringName -> {perf, n}
var words: Dictionary = {}        # word_id -> Mastery.new_word() + {"srs": bool}
var kana: Dictionary = {}         # kana char -> {"streak": int}
var grammar: Dictionary = {}      # grammar id -> {"attempts", "correct", "lesson_done"}
var scenarios: Dictionary = {}    # scenario id -> {"completions", "best"}
var prompts: Dictionary = {}      # prompt id -> {"attempts", "best_c"}
var assessments: Array = []       # [{date, stage, sections, passed, items}]
var cooldown_until: int = 0
var consecutive_fails: int = 0
var daily: Dictionary = {}
var study_days: Array = []
var recommend_history: Array = []
var cleared_stages: Array = []
var recent_samples: Array = []    # ring buffer of {t, skill, w, c, source}
var reports: Array = []           # player reports of rejected-but-natural answers (GDD §13 q4)

## Overridable clock so tests can control "now".
var now_provider: Callable = func() -> int: return int(Time.get_unix_time_from_system())
## When false (tests), nothing touches the disk.
var persist := true


func _ready() -> void:
	reset()
	load_game()
	touch_today()


func now() -> int:
	return now_provider.call()


func today() -> String:
	return Time.get_date_string_from_unix_time(now())


func default_settings() -> Dictionary:
	return {"theme": "light", "font": "noto", "english_auto": true, "tts_rate": 1.0, "voice": "", "onboarded": false,
		"typed_answers": false, "beginner_english": true, "ui_scale": 0.0}


func reset() -> void:
	stage = &"N5"
	xp = 0
	english_mode = EnglishMode.TRANSLATIONS
	settings = default_settings()
	skills = {}
	for skill in Mastery.SKILLS:
		skills[skill] = Mastery.new_skill()
	words = {}
	kana = {}
	grammar = {}
	scenarios = {}
	prompts = {}
	assessments = []
	cooldown_until = 0
	consecutive_fails = 0
	daily = _new_daily("")
	study_days = []
	recommend_history = []
	cleared_stages = []
	recent_samples = []
	reports = []


# ---------------------------------------------------------------- settings

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit()
	save_game()


func setting(key: String) -> Variant:
	return settings.get(key, default_settings().get(key))


func set_english_mode(mode: int, by_player: bool = true) -> void:
	english_mode = clampi(mode, EnglishMode.JAPANESE_ONLY, EnglishMode.BILINGUAL)
	if by_player:
		settings["english_auto"] = false
	english_mode_changed.emit(english_mode)
	save_game()


## Beginner help: until the player reaches N4, English is shown everywhere (meanings, UI labels,
## answer translations) regardless of the assistance mode. Can be switched off in 設定.
func beginner() -> bool:
	return stage == &"N5" and bool(setting("beginner_english"))


func show_english() -> bool:
	return beginner() or english_mode >= EnglishMode.TRANSLATIONS


func show_explanations() -> bool:
	return beginner() or english_mode >= EnglishMode.EXPLANATIONS


## UI scale factor: the player's choice, or automatic (larger on touch screens).
func ui_scale() -> float:
	var chosen := float(setting("ui_scale"))
	if chosen > 0.0:
		return chosen
	return 1.15 if DisplayServer.is_touchscreen_available() else 1.0


# ---------------------------------------------------------------- samples & scores

## Record one answer of [param activity] with correctness [param c] in {0, 0.5, 1}.
func record_sample(activity: StringName, c: float, from_assessment: bool = false) -> void:
	var weights := Mastery.samples_for(activity, from_assessment)
	for skill: StringName in weights:
		skills[skill] = Mastery.apply_sample(skills[skill], c, float(weights[skill]))
		recent_samples.append({"t": now(), "skill": String(skill), "w": weights[skill], "c": c, "source": String(activity)})
	if recent_samples.size() > REVIEW_SAMPLES:
		recent_samples = recent_samples.slice(recent_samples.size() - REVIEW_SAMPLES)
	scores_changed.emit(scores())


## Coverage of the current stage's inventory for the three inventory skills (GDD §5.2).
func coverage(skill: StringName) -> float:
	match skill:
		&"vocab":
			var pool := ContentDB.stage_items("vocab", stage)
			if pool.is_empty():
				return 1.0
			var n := 0
			for e in pool:
				if rank_of(e["id"]) >= Mastery.Rank.LEARNED:
					n += 1
			return float(n) / pool.size()
		&"kanji":
			var chars := ContentDB.stage_items("kanji", stage)
			if chars.is_empty():
				return 1.0
			var learned_chars := {}
			for id: String in words:
				if int(words[id]["rank"]) >= Mastery.Rank.LEARNED:
					for ch in ContentDB.word(id).get("kanji", []):
						learned_chars[ch] = true
			var n := 0
			for k in chars:
				if learned_chars.has(k["kanji"]):
					n += 1
			return float(n) / chars.size()
		&"grammar":
			var pool := ContentDB.stage_items("grammar", stage)
			if pool.is_empty():
				return 1.0
			var n := 0
			for g in pool:
				if int(grammar.get(g["id"], {}).get("correct", 0)) >= Mastery.GRAMMAR_COVERED_AT:
					n += 1
			return float(n) / pool.size()
		_:
			return 0.0


func scores() -> Dictionary:
	var out := {}
	for skill in Mastery.SKILLS:
		out[skill] = Mastery.score(skills[skill], skill, coverage(skill))
	return out


func gate_status() -> Dictionary:
	return Mastery.evaluate_gate(scores(), stage)


func exam_unlocked() -> bool:
	return stage != &"MASTERY" or not cleared_stages.has("MASTERY") \
		if Mastery.exam_unlocked(scores(), stage) and now() >= cooldown_until else false


func on_cooldown() -> bool:
	return now() < cooldown_until


## Item ids used in the last three sittings, so a new exam avoids repeats (GDD §9.1).
func recent_exam_items() -> Dictionary:
	var out := {}
	for a in assessments.slice(maxi(0, assessments.size() - 3)):
		for id in a.get("items", []):
			out[id] = true
	return out


## Record a finished gate exam. [param sections] maps skill -> percent. Returns the gate result.
func record_exam(sections: Dictionary, item_ids: Array = []) -> Dictionary:
	var result := Mastery.evaluate_gate(sections, stage)
	assessments.append({"date": today(), "stage": String(stage), "sections": _stringify_keys(sections),
		"passed": result["passed"], "items": item_ids})
	if result["passed"]:
		consecutive_fails = 0
		cooldown_until = 0
		add_xp(Mastery.EXAM_PASS_XP)
		advance_stage()
	else:
		consecutive_fails += 1
		cooldown_until = now() + Mastery.exam_cooldown_seconds(consecutive_fails)
	save_game()
	return result


## Record the daily check (GDD §9.4).
func record_daily(score: int) -> void:
	touch_today()
	var first: bool = not daily.get("assessment_done", false)
	daily["assessment_done"] = true
	daily["assessment_score"] = maxi(int(daily.get("assessment_score", 0)), score)
	if first:
		bump_daily("daily_assessment")
	save_game()


func advance_stage() -> void:
	if String(stage) not in cleared_stages:
		cleared_stages.append(String(stage))
	var next := Mastery.next_stage(stage)
	if next != stage:
		stage = next
		if setting("english_auto"):
			set_english_mode(STAGE_ENGLISH.get(stage, english_mode), false)
		stage_changed.emit(stage)
	scores_changed.emit(scores())


func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp)


func level() -> int:
	return Mastery.level_for_xp(xp)


# ---------------------------------------------------------------- words

func word(word_id: String) -> Dictionary:
	if not words.has(word_id):
		words[word_id] = Mastery.new_word()
	return words[word_id]


func rank_of(word_id: String) -> int:
	return int(words[word_id]["rank"]) if words.has(word_id) else Mastery.Rank.UNSEEN


func in_srs(word_id: String) -> bool:
	return words.has(word_id) and words[word_id].get("srs", false)


## Opening an entry (or meeting a word in any activity) discovers it: UNSEEN -> DISCOVERED.
func discover_word(word_id: String) -> void:
	var w := word(word_id)
	if int(w["rank"]) == Mastery.Rank.UNSEEN:
		w["rank"] = Mastery.Rank.DISCOVERED
		word_changed.emit(word_id, w)
		save_game()


## New words the player may still add to reviews today.
func new_word_budget() -> int:
	var budget := BUDGET_BASE
	var due := due_count()
	var acc := review_accuracy()
	if acc >= 0.85 and due < 20:
		budget += 5
	if due >= 40:
		budget -= 5
	return maxi(5, budget)


func budget_left() -> int:
	touch_today()
	return maxi(0, new_word_budget() - int(daily.get("new_words", 0)))


## 学習する: add a word to the review queue (box 0, due now). Returns false when today's budget
## is used up or the word is already in reviews.
func study_word(word_id: String) -> bool:
	if in_srs(word_id):
		return false
	if budget_left() <= 0:
		return false
	var w := word(word_id)
	if int(w["rank"]) == Mastery.Rank.UNSEEN:
		w["rank"] = Mastery.Rank.DISCOVERED
	w["srs"] = true
	w["box"] = 0
	w["due"] = now()
	daily["new_words"] = int(daily.get("new_words", 0)) + 1
	word_changed.emit(word_id, w)
	save_game()
	return true


## Accuracy of the last review answers (0..1, 1.0 when there is no history).
func review_accuracy() -> float:
	var total := 0
	var hits := 0.0
	for s in recent_samples:
		if String(s["source"]).begins_with("review_") and s["skill"] == "vocab":
			total += 1
			hits += float(s["c"])
	return 1.0 if total == 0 else hits / total


## Record an answer about a word on [param dimension] ("rec", "rcl", "use") with correctness c.
## Counters and rank follow Mastery; the box and due time follow Srs when [param reschedule]
## (which also puts the word into reviews).
func record_word_answer(word_id: String, dimension: String, c: float, reschedule: bool = true) -> void:
	var w := word(word_id)
	var before := int(w["rank"])
	if c >= Srs.C_CORRECT:
		w = Mastery.word_correct(w, dimension)
	elif c <= Srs.C_WRONG:
		w = Mastery.word_lapse(w, dimension, now())
	elif int(w["rank"]) == Mastery.Rank.UNSEEN:
		w["rank"] = Mastery.Rank.DISCOVERED
	if reschedule:
		# A lapse already moved the box down two in Mastery.word_lapse; Srs.review handles the
		# correct/partial transitions and recomputes the due time.
		w = Srs.review(w, c if c > Srs.C_WRONG else Srs.C_PARTIAL, now())
		if c >= Srs.C_CORRECT:
			w["rank"] = Mastery.promoted_rank(w)
		w["srs"] = true
		bump_daily("reviews")
	words[word_id] = w
	var after := int(w["rank"])
	if after > before:
		if after == Mastery.Rank.FAMILIAR:
			bump_daily("words_familiar")
		if after >= Mastery.Rank.LEARNED:
			rank_up.emit(word_id, after)
		_refresh_known_bases()
	word_changed.emit(word_id, w)
	save_game()


func due_words(limit: int = 20) -> Array[String]:
	return Srs.pick_due(words, now(), limit)


func due_count() -> int:
	return Srs.pick_due(words, now(), 100000).size()


func count_words_at_least(rank: int) -> int:
	var n := 0
	for id: String in words:
		if int(words[id]["rank"]) >= rank:
			n += 1
	return n


## Word ids at rank ≥ Discovered (the exam's "known" pool).
func known_word_ids() -> Dictionary:
	var out := {}
	for id: String in words:
		if int(words[id]["rank"]) >= Mastery.Rank.DISCOVERED:
			out[id] = true
	return out


## Kanji runs of well-known words, so Japanese-only mode can hide their furigana (concept §4).
func _refresh_known_bases() -> void:
	var bases := {}
	if english_mode == EnglishMode.JAPANESE_ONLY:
		for id: String in words:
			if int(words[id]["rank"]) >= Mastery.Rank.PROFICIENT:
				var hw: String = ContentDB.word(id).get("headword", "")
				var run := ""
				for ch in hw:
					var c := ch.unicode_at(0)
					if (c >= 0x4E00 and c <= 0x9FFF) or c == 0x3005:
						run += ch
					elif run != "":
						bases[run] = true
						run = ""
				if run != "":
					bases[run] = true
	FuriganaLabel.known_bases = bases


# ---------------------------------------------------------------- kana, grammar, prompts, scenarios

func record_kana(ch: String, correct: bool) -> void:
	var k: Dictionary = kana.get(ch, {"streak": 0})
	k["streak"] = (int(k["streak"]) + 1) if correct else 0
	kana[ch] = k
	record_sample(&"kana", Srs.C_CORRECT if correct else Srs.C_WRONG)
	if correct:
		add_xp(Mastery.XP[&"kana"])


## Share of the core kana (basic, dakuten, handakuten in both scripts) answered correctly at
## least twice in a row. Yōon are practised but not required.
func kana_mastery() -> float:
	var total := 0
	var known := 0
	for table in ["hiragana", "katakana"]:
		for row in ContentDB.kana.get(table, []):
			if row.get("group", "basic") == "yoon":
				continue
			total += 1
			if int(kana.get(row["kana"], {}).get("streak", 0)) >= 2:
				known += 1
	return 0.0 if total == 0 else float(known) / total


func record_grammar(grammar_id: String, correct: bool) -> void:
	var g: Dictionary = grammar.get(grammar_id, {"attempts": 0, "correct": 0, "lesson_done": false})
	g["attempts"] = int(g["attempts"]) + 1
	if correct:
		g["correct"] = int(g["correct"]) + 1
	grammar[grammar_id] = g


func finish_grammar_lesson(grammar_id: String, correct_count: int) -> void:
	var g: Dictionary = grammar.get(grammar_id, {"attempts": 0, "correct": 0, "lesson_done": false})
	if correct_count >= 5:
		g["lesson_done"] = true
	grammar[grammar_id] = g
	bump_daily("grammar_lessons")
	save_game()


## Correct answers of the least-covered grammar point in the current stage (for the recommender).
func weakest_grammar() -> Dictionary:
	var best := {}
	var best_n := 1 << 30
	for g in ContentDB.stage_items("grammar", stage):
		var n := int(grammar.get(g["id"], {}).get("correct", 0))
		if n < best_n:
			best_n = n
			best = g
	return {"point": best, "correct": best_n if not best.is_empty() else 99}


func record_prompt(prompt_id: String, c: float) -> void:
	var p: Dictionary = prompts.get(prompt_id, {"attempts": 0, "best_c": 0.0})
	p["attempts"] = int(p["attempts"]) + 1
	p["best_c"] = maxf(float(p["best_c"]), c)
	prompts[prompt_id] = p
	bump_daily("sentences")


func record_scenario(scenario_id: String, score: float) -> void:
	var s: Dictionary = scenarios.get(scenario_id, {"completions": 0, "best": 0.0})
	s["completions"] = int(s["completions"]) + 1
	s["best"] = maxf(float(s["best"]), score)
	scenarios[scenario_id] = s
	bump_daily("conversations")


func report_natural(prompt_id: String, answer: Array) -> void:
	reports.append({"date": today(), "prompt": prompt_id, "answer": answer})
	save_game()


# ---------------------------------------------------------------- daily

func _new_daily(date: String) -> Dictionary:
	return {"date": date, "counters": {}, "paid": [], "new_words": 0, "assessment_done": false,
		"assessment_score": 0, "scenarios_rewarded": []}


## Roll the daily record over when the date changes, and record today as a study day.
func touch_today() -> void:
	var t := today()
	if daily.get("date", "") != t:
		daily = _new_daily(t)
	if t not in study_days:
		study_days.append(t)
		save_game()


## Count one daily event and pay any quest it completes.
func bump_daily(counter: String, amount: int = 1) -> void:
	touch_today()
	var counters: Dictionary = daily.get("counters", {})
	counters[counter] = int(counters.get(counter, 0)) + amount
	daily["counters"] = counters
	var paid: Array = daily.get("paid", [])
	for q in Quests.newly_completed(counters, paid):
		paid.append(q["id"])
		add_xp(int(q["xp"]))
		quest_completed.emit(q)
	daily["paid"] = paid


func daily_counter(counter: String) -> int:
	return int(daily.get("counters", {}).get(counter, 0)) if daily.get("date", "") == today() else 0


func quest_paid(id: String) -> bool:
	return daily.get("date", "") == today() and id in daily.get("paid", [])


func days_studied() -> int:
	return study_days.size()


func streak_days() -> int:
	var n := 0
	var t := now()
	while Time.get_date_string_from_unix_time(t - n * 86400) in study_days:
		n += 1
	return n


# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "stage": String(stage), "xp": xp, "english_mode": english_mode,
		"settings": settings, "skills": _stringify_keys(skills), "words": words, "kana": kana,
		"grammar": grammar, "scenarios": scenarios, "prompts": prompts, "assessments": assessments,
		"cooldown_until": cooldown_until, "consecutive_fails": consecutive_fails, "daily": daily,
		"study_days": study_days, "recommend_history": recommend_history, "cleared_stages": cleared_stages,
		"recent_samples": recent_samples, "reports": reports,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	stage = StringName(String(data.get("stage", "N5")))
	xp = int(data.get("xp", 0))
	english_mode = int(data.get("english_mode", EnglishMode.TRANSLATIONS))
	var saved_settings: Dictionary = data.get("settings", {})
	for key: String in saved_settings:
		settings[key] = saved_settings[key]
	var saved_skills: Dictionary = data.get("skills", {})
	for skill in Mastery.SKILLS:
		var s: Dictionary = saved_skills.get(String(skill), {})
		skills[skill] = {"perf": float(s.get("perf", 0.0)), "n": float(s.get("n", 0.0))}
	var version := int(data.get("version", 1))
	words = data.get("words", {})
	for id: String in words:
		var base := Mastery.new_word()
		for key: String in words[id]:
			base[key] = words[id][key]
		for key: String in ["rank", "rec", "rcl", "use", "box", "due", "streak", "lapses"]:
			base[key] = int(base[key])
		if version < 2:
			base["srs"] = true  # v1 scheduled every discovered word
		words[id] = base
	kana = data.get("kana", {})
	grammar = data.get("grammar", {})
	scenarios = data.get("scenarios", {})
	prompts = data.get("prompts", {})
	assessments = data.get("assessments", [])
	cooldown_until = int(data.get("cooldown_until", 0))
	consecutive_fails = int(data.get("consecutive_fails", 0))
	var d: Dictionary = data.get("daily", {})
	daily = _new_daily(String(d.get("date", "")))
	for key: String in d:
		daily[key] = d[key]
	study_days = data.get("study_days", [])
	recommend_history = data.get("recommend_history", [])
	cleared_stages = data.get("cleared_stages", [])
	recent_samples = data.get("recent_samples", [])
	reports = data.get("reports", [])
	_refresh_known_bases()


## Write-to-temp-then-rename so a crash mid-write never corrupts the save (GDD §11.7).
func save_game() -> void:
	if not persist:
		return
	var tmp := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Progress: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	var dir := DirAccess.open("user://")
	if dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())
	dir.rename(tmp.get_file(), SAVE_PATH.get_file())


func load_game() -> bool:
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is not Dictionary:
		push_error("Progress: save file is corrupt; starting fresh")
		return false
	from_dict(parsed)
	scores_changed.emit(scores())
	return true


## Erase all progress (settings are kept).
func wipe() -> void:
	var keep := settings.duplicate()
	reset()
	settings = keep
	settings["onboarded"] = true
	touch_today()
	save_game()
	scores_changed.emit(scores())
	xp_changed.emit(xp)
	stage_changed.emit(stage)


func _stringify_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		out[String(key)] = d[key]
	return out
