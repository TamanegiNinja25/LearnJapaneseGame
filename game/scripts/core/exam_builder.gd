extends RefCounted
class_name ExamBuilder
## Assembles multiple-choice questions for the gate exam and the review queue from content data
## (docs/GAME_DESIGN.md §9.1, Phase 1 subset). Pure functions over arrays so they are testable.
##
## A question: {"skill": StringName, "activity": StringName, "prompt": String (markup),
##   "prompt_en": String, "options": Array[String] (markup), "answer": int, "word_id": String,
##   "dimension": String}

## Section sizes for the N5 gate exam. 会話 draws from the scenario pool; when the pool is
## smaller than the quota, the section simply has fewer questions.
const SECTIONS := {&"vocab": 10, &"grammar": 10, &"reading": 8, &"kanji": 6, &"conversation": 6}
const OPTION_COUNT := 4


static func build_exam(vocab: Array, sentences: Array, scenarios: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pool := vocab.duplicate()
	pool.shuffle()
	var kanji_pool := vocab.filter(func(e: Dictionary) -> bool: return e["headword"] != e["reading"])
	kanji_pool.shuffle()
	# 語彙: 5 recognition + 5 recall
	for i in mini(5, pool.size()):
		out.append(recognition_question(pool[i], vocab))
	for i in mini(5, pool.size() - 5):
		out.append(recall_question(pool[5 + i], vocab))
	# 文法: pick the correct sentence order
	var sents := sentences.duplicate()
	sents.shuffle()
	for i in mini(SECTIONS[&"grammar"], sents.size()):
		out.append(order_question(sents[i]))
	# 読解: example sentence -> meaning
	var with_examples := vocab.filter(func(e: Dictionary) -> bool: return not (e["examples"] as Array).is_empty())
	with_examples.shuffle()
	for i in mini(SECTIONS[&"reading"], with_examples.size()):
		out.append(example_reading_question(with_examples[i], with_examples))
	# 漢字: kanji form -> reading
	for i in mini(SECTIONS[&"kanji"], kanji_pool.size()):
		out.append(kanji_reading_question(kanji_pool[i], kanji_pool))
	# 会話: scenario turns
	var turns: Array = []
	for sc in scenarios:
		for turn in sc["turns"]:
			turns.append(turn)
	turns.shuffle()
	for i in mini(SECTIONS[&"conversation"], turns.size()):
		out.append(scenario_question(turns[i]))
	return out


## Score a finished exam: {skill: percent} over the questions of each section.
static func section_scores(questions: Array, correct_flags: Array) -> Dictionary:
	var totals := {}
	var hits := {}
	for i in questions.size():
		var skill: StringName = questions[i]["skill"]
		totals[skill] = int(totals.get(skill, 0)) + 1
		if i < correct_flags.size() and correct_flags[i]:
			hits[skill] = int(hits.get(skill, 0)) + 1
	var out := {}
	for skill: StringName in totals:
		out[skill] = roundi(100.0 * float(hits.get(skill, 0)) / float(totals[skill]))
	return out


# ---------------------------------------------------------------- question factories

static func headword_markup(entry: Dictionary) -> String:
	if entry["headword"] == entry["reading"]:
		return entry["headword"]
	return "{%s|%s}" % [entry["headword"], entry["reading"]]


## JP (with ruby) -> English meaning.
static func recognition_question(entry: Dictionary, vocab: Array) -> Dictionary:
	var distractors := _others(entry, vocab, func(e: Dictionary) -> bool: return e["category"] == entry["category"])
	var options: Array = [String(entry["english"])]
	for d in distractors:
		options.append(String(d["english"]))
	return _finish({"skill": &"vocab", "activity": &"review_recognition_kanji" if entry["headword"] != entry["reading"] else &"review_recognition",
		"prompt": headword_markup(entry), "prompt_en": "What does this word mean?",
		"word_id": entry["id"], "dimension": "rec"}, options)


## English meaning -> JP word.
static func recall_question(entry: Dictionary, vocab: Array) -> Dictionary:
	var distractors := _others(entry, vocab, func(e: Dictionary) -> bool: return e["category"] == entry["category"])
	var options: Array = [headword_markup(entry)]
	for d in distractors:
		options.append(headword_markup(d))
	return _finish({"skill": &"vocab", "activity": &"review_recall",
		"prompt": "「%s」" % Furigana.plain(String(entry["english"]).split(";")[0]), "prompt_en": "Which word means this?",
		"word_id": entry["id"], "dimension": "rcl"}, options)


## Kanji form (no ruby) -> reading.
static func kanji_reading_question(entry: Dictionary, kanji_pool: Array) -> Dictionary:
	var distractors := _others(entry, kanji_pool, func(_e: Dictionary) -> bool: return true)
	var options: Array = [String(entry["reading"])]
	for d in distractors:
		options.append(String(d["reading"]))
	return _finish({"skill": &"kanji", "activity": &"review_kanji_reading",
		"prompt": entry["headword"], "prompt_en": "How is this read?", "hide_ruby": true,
		"word_id": entry["id"], "dimension": "rec"}, options)


## Example sentence -> English meaning.
static func example_reading_question(entry: Dictionary, pool: Array) -> Dictionary:
	var ex: Dictionary = entry["examples"][0]
	var distractors := _others(entry, pool, func(_e: Dictionary) -> bool: return true)
	var options: Array = [String(ex["en"])]
	for d in distractors:
		options.append(String(d["examples"][0]["en"]))
	return _finish({"skill": &"reading", "activity": &"review_example_reading",
		"prompt": ex["ja"], "prompt_en": "What does this sentence mean?",
		"word_id": entry["id"], "dimension": "rec"}, options)


## Usage: the headword is blanked out of its example sentence; choose the word that fits.
## Returns {} when the example does not contain the headword verbatim (conjugated verbs).
static func usage_question(entry: Dictionary, vocab: Array) -> Dictionary:
	var ex: Dictionary = entry["examples"][0]
	var token := headword_markup(entry)
	if not String(ex["ja"]).contains(token):
		return {}
	var distractors := _others(entry, vocab, func(e: Dictionary) -> bool: return e["category"] == entry["category"])
	var options: Array = [token]
	for d in distractors:
		options.append(headword_markup(d))
	return _finish({"skill": &"vocab", "activity": &"review_recall",
		"prompt": String(ex["ja"]).replace(token, "［　　］"), "prompt_en": ex["en"],
		"word_id": entry["id"], "dimension": "use"}, options)


## Sentence order: the accepted order versus shuffles of the same tiles / a distractor swap.
static func order_question(prompt: Dictionary) -> Dictionary:
	var accepted: Array = prompt["accepted"]
	var tiles: Array = prompt["tiles"]
	var correct := "".join(accepted[0])
	var options: Array = [correct]
	var guard := 0
	while options.size() < OPTION_COUNT and guard < 40:
		guard += 1
		var candidate: Array
		if (prompt["distractors"] as Array).size() > 0 and guard % 2 == 0:
			candidate = (accepted[0] as Array).duplicate()
			var swap_at := randi() % candidate.size()
			candidate[swap_at] = prompt["distractors"][randi() % (prompt["distractors"] as Array).size()]
		else:
			candidate = tiles.duplicate()
			candidate.shuffle()
		var joined := "".join(candidate)
		var is_accepted := false
		for acc in accepted:
			if "".join(acc) == joined:
				is_accepted = true
		if not is_accepted and joined not in options:
			options.append(joined)
	return _finish({"skill": &"grammar", "activity": &"grammar_quiz",
		"prompt": "「%s」" % prompt["prompt_en"], "prompt_en": "Which sentence is correct?",
		"word_id": "", "dimension": "", "grammar": prompt["grammar"]}, options)


## One scenario turn as a question: the NPC line is the prompt, the correct option wins.
static func scenario_question(turn: Dictionary) -> Dictionary:
	var options: Array = []
	var answer := 0
	var opts: Array = turn["options"]
	for i in opts.size():
		options.append(opts[i]["ja"])
		if opts[i]["verdict"] == "correct":
			answer = i
	# Reorder so the correct option is first, then _finish shuffles.
	var correct: String = options[answer]
	options.remove_at(answer)
	options.push_front(correct)
	return _finish({"skill": &"conversation", "activity": &"scenario_turn",
		"prompt": "%s「%s」" % [turn["speaker"], turn["line_ja"]], "prompt_en": turn["line_en"],
		"word_id": "", "dimension": ""}, options)


# ---------------------------------------------------------------- helpers

## Up to OPTION_COUNT-1 entries different from [param entry], preferring those matching [param prefer].
static func _others(entry: Dictionary, pool: Array, prefer: Callable) -> Array:
	var same: Array = []
	var rest: Array = []
	for e in pool:
		if e["id"] == entry["id"] or e["english"] == entry["english"]:
			continue
		if prefer.call(e):
			same.append(e)
		else:
			rest.append(e)
	same.shuffle()
	rest.shuffle()
	var out := same.slice(0, OPTION_COUNT - 1)
	if out.size() < OPTION_COUNT - 1:
		out.append_array(rest.slice(0, OPTION_COUNT - 1 - out.size()))
	return out


## Shuffle options (first entry is the correct one) and record the answer index.
static func _finish(q: Dictionary, options: Array) -> Dictionary:
	var correct: String = options[0]
	var shuffled := options.duplicate()
	shuffled.shuffle()
	q["options"] = shuffled
	q["answer"] = shuffled.find(correct)
	return q
