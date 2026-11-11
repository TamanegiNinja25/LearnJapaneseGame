extends Node
## Autoload "Progress": the player's save state and the only place that mutates it.
## Rules live in Mastery and Srs (pure); this node applies them, derives scores and persists.
## Save layout follows docs/GAME_DESIGN.md §11.7 (Phase 1 subset).

signal scores_changed(scores: Dictionary)
signal word_changed(word_id: String, word: Dictionary)
signal stage_changed(stage: StringName)
signal xp_changed(xp: int)
signal english_mode_changed(mode: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## English assistance modes (concept §4). Higher = more English shown.
enum EnglishMode { JAPANESE_ONLY, EXPLANATIONS, TRANSLATIONS, BILINGUAL }

var stage: StringName = &"N5"
var xp: int = 0
var english_mode: int = EnglishMode.TRANSLATIONS
var skills: Dictionary = {}       # StringName -> {perf, n}
var words: Dictionary = {}        # word_id -> Mastery.new_word()
var kana: Dictionary = {}         # kana char -> {"streak": int}
var grammar: Dictionary = {}      # grammar id -> {"attempts": int, "correct": int}
var scenarios: Dictionary = {}    # scenario id -> {"completions": int, "best": float}
var prompts: Dictionary = {}      # prompt id -> {"attempts": int, "best_c": float}
var assessments: Array = []       # [{date, stage, sections: {skill: pct}, passed}]
var cooldown_until: int = 0
var daily: Dictionary = {}        # {"date": "YYYY-MM-DD", "assessment_done": bool, "new_words": int}
var study_days: Array = []
var recommend_history: Array = []
var cleared_stages: Array = []

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


func reset() -> void:
	stage = &"N5"
	xp = 0
	english_mode = EnglishMode.TRANSLATIONS
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
	daily = {"date": "", "assessment_done": false, "new_words": 0}
	study_days = []
	recommend_history = []
	cleared_stages = []


# ---------------------------------------------------------------- samples & scores

## Record one answer of [param activity] with correctness [param c] in {0, 0.5, 1}.
func record_sample(activity: StringName, c: float, from_assessment: bool = false) -> void:
	var weights := Mastery.samples_for(activity, from_assessment)
	for skill: StringName in weights:
		skills[skill] = Mastery.apply_sample(skills[skill], c, float(weights[skill]))
	scores_changed.emit(scores())


## Coverage of the current stage's inventory for the three inventory skills (GDD §5.2).
func coverage(skill: StringName) -> float:
	match skill:
		&"vocab":
			var total := ContentDB.vocab.size()
			return 0.0 if total == 0 else float(count_words_at_least(Mastery.Rank.LEARNED)) / total
		&"kanji":
			var with_kanji := 0
			var learned := 0
			for entry in ContentDB.vocab:
				if entry["headword"] != entry["reading"]:
					with_kanji += 1
					if rank_of(entry["id"]) >= Mastery.Rank.LEARNED:
						learned += 1
			return 0.0 if with_kanji == 0 else float(learned) / with_kanji
		&"grammar":
			var total := ContentDB.grammar.size()
			if total == 0:
				return 0.0
			var covered := 0
			for g in ContentDB.grammar:
				if int(grammar.get(g["id"], {}).get("correct", 0)) >= Mastery.GRAMMAR_COVERED_AT:
					covered += 1
			return float(covered) / total
		_:
			return 0.0


## Current 0..100 score per skill.
func scores() -> Dictionary:
	var out := {}
	for skill in Mastery.SKILLS:
		out[skill] = Mastery.score(skills[skill], skill, coverage(skill))
	return out


func gate_status() -> Dictionary:
	return Mastery.evaluate_gate(scores(), stage)


func exam_unlocked() -> bool:
	return Mastery.exam_unlocked(scores(), stage) and now() >= cooldown_until


## Record a finished gate exam. [param sections] maps skill -> percent. Returns the gate result.
func record_exam(sections: Dictionary) -> Dictionary:
	var result := Mastery.evaluate_gate(sections, stage)
	assessments.append({"date": today(), "stage": String(stage), "sections": _stringify_keys(sections), "passed": result["passed"]})
	if result["passed"]:
		add_xp(Mastery.EXAM_PASS_XP)
		advance_stage()
		cooldown_until = 0
	else:
		cooldown_until = now() + Mastery.EXAM_COOLDOWN_SECONDS
	save_game()
	return result


func advance_stage() -> void:
	if String(stage) not in cleared_stages:
		cleared_stages.append(String(stage))
	var next := Mastery.next_stage(stage)
	if next != stage:
		stage = next
		stage_changed.emit(stage)
	scores_changed.emit(scores())


func add_xp(amount: int) -> void:
	xp += amount
	xp_changed.emit(xp)


func level() -> int:
	return Mastery.level_for_xp(xp)


func set_english_mode(mode: int) -> void:
	english_mode = clampi(mode, EnglishMode.JAPANESE_ONLY, EnglishMode.BILINGUAL)
	english_mode_changed.emit(english_mode)
	save_game()


func show_english() -> bool:
	return english_mode >= EnglishMode.TRANSLATIONS


func show_explanations() -> bool:
	return english_mode >= EnglishMode.EXPLANATIONS


# ---------------------------------------------------------------- words

func word(word_id: String) -> Dictionary:
	if not words.has(word_id):
		words[word_id] = Mastery.new_word()
	return words[word_id]


func rank_of(word_id: String) -> int:
	return int(word(word_id)["rank"])


## Opening an entry discovers the word (UNSEEN -> DISCOVERED) and schedules an immediate review.
func discover_word(word_id: String) -> void:
	var w := word(word_id)
	if int(w["rank"]) == Mastery.Rank.UNSEEN:
		w["rank"] = Mastery.Rank.DISCOVERED
		w["box"] = 0
		w["due"] = now()
		touch_today()
		daily["new_words"] = int(daily.get("new_words", 0)) + 1
		word_changed.emit(word_id, w)
		save_game()


## Record an answer about a word on [param dimension] ("rec", "rcl", "use") with correctness c.
## Counters and rank follow Mastery; the box and due time follow Srs when [param reschedule].
func record_word_answer(word_id: String, dimension: String, c: float, reschedule: bool = true) -> void:
	var w := word(word_id)
	if c >= Srs.C_CORRECT:
		w = Mastery.word_correct(w, dimension)
	elif c <= Srs.C_WRONG:
		w = Mastery.word_lapse(w, dimension)
	elif int(w["rank"]) == Mastery.Rank.UNSEEN:
		w["rank"] = Mastery.Rank.DISCOVERED
	if reschedule:
		# A lapse already moved the box down two in Mastery.word_lapse; Srs.review handles the
		# correct/partial transitions and always recomputes the due time.
		w = Srs.review(w, c if c > Srs.C_WRONG else Srs.C_PARTIAL, now())
		w["rank"] = Mastery.promoted_rank(w) if c >= Srs.C_CORRECT else w["rank"]
	words[word_id] = w
	word_changed.emit(word_id, w)
	save_game()


func due_words(limit: int = 20) -> Array[String]:
	return Srs.pick_due(words, now(), limit)


func due_count() -> int:
	return Srs.pick_due(words, now(), 1000).size()


func count_words_at_least(rank: int) -> int:
	var n := 0
	for id: String in words:
		if int(words[id]["rank"]) >= rank:
			n += 1
	return n


# ---------------------------------------------------------------- kana, grammar, prompts, scenarios

func record_kana(ch: String, correct: bool) -> void:
	var k: Dictionary = kana.get(ch, {"streak": 0})
	k["streak"] = (int(k["streak"]) + 1) if correct else 0
	kana[ch] = k
	record_sample(&"kana", Srs.C_CORRECT if correct else Srs.C_WRONG)
	if correct:
		add_xp(Mastery.XP[&"kana"])


## Share of kana (both scripts) answered correctly at least twice in a row.
func kana_mastery() -> float:
	var total := 0
	var known := 0
	for table in ["hiragana", "katakana"]:
		for row in ContentDB.kana.get(table, []):
			total += 1
			if int(kana.get(row["kana"], {}).get("streak", 0)) >= 2:
				known += 1
	return 0.0 if total == 0 else float(known) / total


func record_grammar(grammar_id: String, correct: bool) -> void:
	var g: Dictionary = grammar.get(grammar_id, {"attempts": 0, "correct": 0})
	g["attempts"] = int(g["attempts"]) + 1
	if correct:
		g["correct"] = int(g["correct"]) + 1
	grammar[grammar_id] = g


func record_prompt(prompt_id: String, c: float) -> void:
	var p: Dictionary = prompts.get(prompt_id, {"attempts": 0, "best_c": 0.0})
	p["attempts"] = int(p["attempts"]) + 1
	p["best_c"] = maxf(float(p["best_c"]), c)
	prompts[prompt_id] = p


func record_scenario(scenario_id: String, score: float) -> void:
	var s: Dictionary = scenarios.get(scenario_id, {"completions": 0, "best": 0.0})
	s["completions"] = int(s["completions"]) + 1
	s["best"] = maxf(float(s["best"]), score)
	scenarios[scenario_id] = s


# ---------------------------------------------------------------- daily

## Roll the daily record over when the date changes, and record today as a study day.
func touch_today() -> void:
	var t := today()
	if daily.get("date", "") != t:
		daily = {"date": t, "assessment_done": false, "new_words": 0}
	if t not in study_days:
		study_days.append(t)
		save_game()


func days_studied() -> int:
	return study_days.size()


# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "stage": String(stage), "xp": xp, "english_mode": english_mode,
		"skills": _stringify_keys(skills), "words": words, "kana": kana, "grammar": grammar,
		"scenarios": scenarios, "prompts": prompts, "assessments": assessments,
		"cooldown_until": cooldown_until, "daily": daily, "study_days": study_days,
		"recommend_history": recommend_history, "cleared_stages": cleared_stages,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	stage = StringName(String(data.get("stage", "N5")))
	xp = int(data.get("xp", 0))
	english_mode = int(data.get("english_mode", EnglishMode.TRANSLATIONS))
	var saved_skills: Dictionary = data.get("skills", {})
	for skill in Mastery.SKILLS:
		var s: Dictionary = saved_skills.get(String(skill), {})
		skills[skill] = {"perf": float(s.get("perf", 0.0)), "n": float(s.get("n", 0.0))}
	words = data.get("words", {})
	for id: String in words:
		var base := Mastery.new_word()
		for key: String in words[id]:
			base[key] = words[id][key]
		for key: String in ["rank", "rec", "rcl", "use", "box", "due", "streak", "lapses"]:
			base[key] = int(base[key])
		words[id] = base
	kana = data.get("kana", {})
	grammar = data.get("grammar", {})
	scenarios = data.get("scenarios", {})
	prompts = data.get("prompts", {})
	assessments = data.get("assessments", [])
	cooldown_until = int(data.get("cooldown_until", 0))
	daily = data.get("daily", daily)
	study_days = data.get("study_days", [])
	recommend_history = data.get("recommend_history", [])
	cleared_stages = data.get("cleared_stages", [])


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


func _stringify_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		out[String(key)] = d[key]
	return out
