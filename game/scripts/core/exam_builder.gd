extends RefCounted
class_name ExamBuilder
## Assembles multiple-choice questions for the gate exam, the daily check and the review queue
## (docs/GAME_DESIGN.md §9). Pure functions over plain content arrays.
##
## A question: {"skill", "activity", "prompt" (markup), "prompt_en", "options" (markup),
##   "answer" (index), "word_id", "dimension", "item_id" (for no-repeat), "hide_ruby"?,
##   "audio"? (plain text to speak), "context"? (markup passage shown above the prompt),
##   "why_ja"?, "why_en"?, "grammar"? (ids)}

const OPTION_COUNT := 4
## N5 gate composition (GDD §9.1). Listening is added only when the stage requires it.
const SECTIONS := {&"vocab": 10, &"grammar": 10, &"reading": 8, &"kanji": 6, &"conversation": 6}
const LISTENING_QUESTIONS := 6
const MAX_ANCHOR_VARIANTS := 3
const UNSEEN_SHARE := 0.2


## Build a gate exam. [param pack] holds the stage's content arrays: vocab, grammar, sentences,
## scenarios, passages, anchors. [param known] is the set of word ids at rank ≥ Discovered,
## [param exclude] item ids used in the last sittings, [param listening] whether to add a
## listening section (a Japanese voice exists and the stage requires it).
static func build_exam(pack: Dictionary, known: Dictionary = {}, exclude: Dictionary = {}, listening: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var vocab: Array = pack.get("vocab", [])
	var words := pick_words(vocab, known, exclude, 10)
	for i in mini(5, words.size()):
		out.append(recognition_question(words[i], vocab))
	for i in range(5, mini(10, words.size())):
		out.append(recall_question(words[i], vocab))

	# 文法: 6 particle + 4 conjugation items from grammar quizzes, topped up with order questions.
	var items := grammar_items(pack.get("grammar", []), exclude)
	var particle := items.filter(func(q: Dictionary) -> bool: return q["kind"] == "particle")
	var conj := items.filter(func(q: Dictionary) -> bool: return q["kind"] == "conjugation")
	var other := items.filter(func(q: Dictionary) -> bool: return q["kind"] != "particle" and q["kind"] != "conjugation")
	var grammar_qs: Array = particle.slice(0, 6) + conj.slice(0, 4)
	for q in other:
		if grammar_qs.size() >= SECTIONS[&"grammar"]:
			break
		grammar_qs.append(q)
	var sents: Array = pack.get("sentences", []).duplicate()
	sents.shuffle()
	for s in sents:
		if grammar_qs.size() >= SECTIONS[&"grammar"]:
			break
		grammar_qs.append(order_question(s))
	out.append_array(grammar_qs)

	# 読解: 4 example-sentence meanings + up to 4 passage questions (two passages × two questions).
	var with_examples := vocab.filter(func(e: Dictionary) -> bool: return not (e["examples"] as Array).is_empty() and not exclude.has("ex:" + e["id"]))
	with_examples.shuffle()
	var reading_qs: Array = []
	for i in mini(4, with_examples.size()):
		reading_qs.append(example_reading_question(with_examples[i], with_examples))
	var passages: Array = pack.get("passages", []).filter(func(p: Dictionary) -> bool: return not exclude.has(p["id"]))
	if passages.is_empty():
		passages = pack.get("passages", []).duplicate()
	passages.shuffle()
	for p in passages.slice(0, 2):
		for q in passage_questions(p).slice(0, 2):
			reading_qs.append(q)
	var extra := 4
	while reading_qs.size() < SECTIONS[&"reading"] and extra < with_examples.size():
		reading_qs.append(example_reading_question(with_examples[extra], with_examples))
		extra += 1
	out.append_array(reading_qs)

	# 漢字: kanji form → reading
	var kanji_pool := vocab.filter(func(e: Dictionary) -> bool: return e["headword"] != e["reading"] and not (e.get("kanji", []) as Array).is_empty() or (e["headword"] != e["reading"] and Furigana.has_kanji("{%s|%s}" % [e["headword"], e["reading"]])))
	var kanji_words := pick_words(kanji_pool, known, exclude, SECTIONS[&"kanji"], "kj:")
	for w in kanji_words:
		out.append(kanji_reading_question(w, kanji_pool))

	# 会話: scenario turns
	var turns: Array = []
	for sc in pack.get("scenarios", []):
		for i in (sc["turns"] as Array).size():
			if not exclude.has("%s#%d" % [sc["id"], i]):
				turns.append(scenario_question(sc["turns"][i], "%s#%d" % [sc["id"], i]))
	turns.shuffle()
	out.append_array(turns.slice(0, SECTIONS[&"conversation"]))

	# 聴解: hear an example sentence, pick its meaning.
	if listening:
		var lpool := with_examples.duplicate()
		lpool.shuffle()
		for i in mini(LISTENING_QUESTIONS, lpool.size()):
			out.append(listening_question(lpool[i], with_examples))

	# Anchors: up to three variants replace questions of the same section (GDD §9.2).
	var anchors: Array = pack.get("anchors", []).duplicate()
	anchors.shuffle()
	var used := 0
	for a in anchors:
		for v in anchor_questions(a):
			if used >= MAX_ANCHOR_VARIANTS:
				break
			if exclude.has(v["item_id"]):
				continue
			var idx := _last_index_of_skill(out, v["skill"])
			if idx >= 0:
				out[idx] = v
				used += 1
		if used >= MAX_ANCHOR_VARIANTS:
			break
	return out


## Daily check (GDD §9.4): 10 questions, extra weight on the two weakest skills.
static func build_daily(pack: Dictionary, known: Dictionary, weakest: Array, listening: bool = false) -> Array[Dictionary]:
	var full := build_exam(pack, known, {}, listening)
	var by_skill := {}
	for q in full:
		by_skill.get_or_add(q["skill"], []).append(q)
	var quota := {}
	for skill: StringName in by_skill:
		quota[skill] = 1
	for i in mini(2, weakest.size()):
		if quota.has(weakest[i]):
			quota[weakest[i]] = 3
	var out: Array[Dictionary] = []
	for skill: StringName in quota:
		var qs: Array = by_skill[skill]
		qs.shuffle()
		out.append_array(qs.slice(0, int(quota[skill])))
	var rest: Array = []
	for skill: StringName in by_skill:
		for q in by_skill[skill]:
			if q not in out:
				rest.append(q)
	rest.shuffle()
	while out.size() < 10 and not rest.is_empty():
		out.append(rest.pop_back())
	out.shuffle()
	return out.slice(0, 10)


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


## Choose [param n] words: known first (rank ≥ Discovered), at most UNSEEN_SHARE unseen, skipping
## excluded ids; falls back to unseen words when the player knows too few.
static func pick_words(pool: Array, known: Dictionary, exclude: Dictionary, n: int, prefix: String = "") -> Array:
	var seen_words: Array = []
	var unseen: Array = []
	for e in pool:
		if exclude.has(prefix + e["id"]):
			continue
		if known.has(e["id"]):
			seen_words.append(e)
		else:
			unseen.append(e)
	seen_words.shuffle()
	unseen.shuffle()
	var max_unseen := maxi(1, int(round(n * UNSEEN_SHARE)))
	var out: Array = seen_words.slice(0, n - mini(max_unseen, unseen.size())) if seen_words.size() >= n else seen_words.duplicate()
	var i := 0
	while out.size() < n and i < unseen.size():
		out.append(unseen[i])
		i += 1
	var j := out.size()
	while out.size() < n and j < seen_words.size():
		out.append(seen_words[j])
		j += 1
	out.shuffle()
	return out


# ---------------------------------------------------------------- question factories

static func headword_markup(entry: Dictionary) -> String:
	if entry.is_empty():
		return ""
	if entry["headword"] == entry["reading"] or not Furigana.has_kanji("{%s|x}" % entry["headword"]) and _no_kanji(entry["headword"]):
		return entry["headword"]
	# Keep okurigana outside the ruby group when the reading ends with the same kana.
	var hw: String = entry["headword"]
	var rd: String = entry["reading"]
	var lead := ""
	while hw.length() > 0 and rd.length() > 0 and _is_kana(hw[0]) and hw[0] == rd[0]:
		lead += hw[0]
		hw = hw.substr(1)
		rd = rd.substr(1)
	var tail := ""
	while hw.length() > 1 and rd.length() > 1 and _is_kana(hw[hw.length() - 1]) and hw[hw.length() - 1] == rd[rd.length() - 1]:
		tail = hw[hw.length() - 1] + tail
		hw = hw.substr(0, hw.length() - 1)
		rd = rd.substr(0, rd.length() - 1)
	return "%s{%s|%s}%s" % [lead, hw, rd, tail]


static func _is_kana(ch: String) -> bool:
	var c := ch.unicode_at(0)
	return (c >= 0x3041 and c <= 0x309F) or (c >= 0x30A0 and c <= 0x30FF)


static func _no_kanji(text: String) -> bool:
	for ch in text:
		var c := ch.unicode_at(0)
		if (c >= 0x4E00 and c <= 0x9FFF) or c == 0x3005:
			return false
	return true


static func recognition_question(entry: Dictionary, vocab: Array) -> Dictionary:
	var distractors := _others(entry, vocab, func(e: Dictionary) -> bool: return e["category"] == entry["category"])
	var options: Array = [_short_gloss(entry["english"])]
	for d in distractors:
		options.append(_short_gloss(d["english"]))
	return _finish({"skill": &"vocab", "activity": &"review_recognition_kanji" if not _no_kanji(entry["headword"]) else &"review_recognition",
		"prompt": headword_markup(entry), "prompt_en": "What does this word mean?", "item_id": entry["id"],
		"word_id": entry["id"], "dimension": "rec", "audio": entry["reading"]}, options)


static func recall_question(entry: Dictionary, vocab: Array) -> Dictionary:
	var distractors := _others(entry, vocab, func(e: Dictionary) -> bool: return e["category"] == entry["category"])
	var options: Array = [headword_markup(entry)]
	for d in distractors:
		options.append(headword_markup(d))
	return _finish({"skill": &"vocab", "activity": &"review_recall",
		"prompt": "「%s」" % _short_gloss(entry["english"]), "prompt_en": "Which word means this?", "item_id": entry["id"],
		"word_id": entry["id"], "dimension": "rcl", "typed_answers": [entry["headword"], entry["reading"]]}, options)


static func kanji_reading_question(entry: Dictionary, kanji_pool: Array) -> Dictionary:
	var distractors := _others(entry, kanji_pool, func(e: Dictionary) -> bool:
		return e["reading"].length() == entry["reading"].length())
	var options: Array = [String(entry["reading"])]
	for d in distractors:
		if String(d["reading"]) not in options:
			options.append(String(d["reading"]))
	return _finish({"skill": &"kanji", "activity": &"review_kanji_reading", "item_id": "kj:" + entry["id"],
		"prompt": headword_markup(entry), "prompt_en": "How is this read?", "hide_ruby": true,
		"word_id": entry["id"], "dimension": "rec", "typed_answers": [entry["reading"]]}, options)


static func example_reading_question(entry: Dictionary, pool: Array) -> Dictionary:
	var ex: Dictionary = entry["examples"][0]
	var distractors := _others(entry, pool, func(_e: Dictionary) -> bool: return true)
	var options: Array = [String(ex["en"])]
	for d in distractors:
		var en := String(d["examples"][0]["en"])
		if en not in options:
			options.append(en)
	return _finish({"skill": &"reading", "activity": &"review_example_reading", "item_id": "ex:" + entry["id"],
		"prompt": ex["ja"], "prompt_en": "What does this sentence mean?", "audio": Furigana.reading(ex["ja"]),
		"word_id": entry["id"], "dimension": "rec"}, options)


static func listening_question(entry: Dictionary, pool: Array) -> Dictionary:
	var q := example_reading_question(entry, pool)
	q["skill"] = &"listening"
	q["activity"] = &"listening"
	q["item_id"] = "li:" + entry["id"]
	q["prompt"] = "♪ もう{一度|いちど}{聞|き}くには ▶ を{押|お}してください。"
	q["prompt_en"] = "Listen and choose the meaning."
	q["listen_only"] = true
	q["reveal"] = entry["examples"][0]["ja"]
	q["word_id"] = ""
	return q


## Usage: the headword is blanked out of its example sentence; choose the word that fits.
## Returns {} when the example does not contain the headword verbatim (e.g. conjugated verbs).
static func usage_question(entry: Dictionary, vocab: Array) -> Dictionary:
	var ex: Dictionary = entry["examples"][0]
	var token := headword_markup(entry)
	if not String(ex["ja"]).contains(token):
		return {}
	var distractors := _others(entry, vocab, func(e: Dictionary) -> bool: return e["category"] == entry["category"])
	var options: Array = [token]
	for d in distractors:
		options.append(headword_markup(d))
	return _finish({"skill": &"vocab", "activity": &"review_recall", "item_id": "us:" + entry["id"],
		"prompt": String(ex["ja"]).replace(token, "［　］"), "prompt_en": ex["en"],
		"word_id": entry["id"], "dimension": "use"}, options)


## Grammar quiz items of every point, shuffled, as questions; skips excluded item ids.
static func grammar_items(grammar: Array, exclude: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in grammar:
		var items: Array = g.get("items", [])
		for i in items.size():
			var id := "%s#%d" % [g["id"], i]
			if exclude.has(id):
				continue
			out.append(grammar_item_question(g, i))
	out.shuffle()
	return out


static func grammar_item_question(g: Dictionary, index: int) -> Dictionary:
	var item: Dictionary = g["items"][index]
	return {"skill": &"grammar", "activity": &"grammar_quiz", "kind": item.get("kind", "choice"),
		"prompt": item["ja"], "prompt_en": "Fill the blank.", "options": item["options"], "answer": int(item["answer"]),
		"item_id": "%s#%d" % [g["id"], index], "word_id": "", "dimension": "", "grammar": [g["id"]],
		"why_ja": item.get("why_ja", ""), "why_en": item.get("why_en", "")}


static func order_question(prompt: Dictionary) -> Dictionary:
	var accepted: Array = prompt["accepted"]
	var tiles: Array = prompt["tiles"]
	var options: Array = ["".join(accepted[0])]
	var guard := 0
	while options.size() < OPTION_COUNT and guard < 60:
		guard += 1
		var candidate: Array
		var distractors: Array = prompt.get("distractors", [])
		if distractors.size() > 0 and guard % 2 == 0:
			candidate = (accepted[0] as Array).duplicate()
			candidate[randi() % candidate.size()] = distractors[randi() % distractors.size()]
		else:
			candidate = tiles.duplicate()
			candidate.shuffle()
		var joined := "".join(candidate)
		var ok := true
		for acc in accepted:
			if "".join(acc) == joined:
				ok = false
		if ok and joined not in options:
			options.append(joined)
	return _finish({"skill": &"grammar", "activity": &"grammar_quiz", "kind": "order", "item_id": prompt["id"],
		"prompt": "「%s」" % prompt["prompt_en"], "prompt_en": "Which sentence is correct?",
		"word_id": "", "dimension": "", "grammar": prompt["grammar"]}, options)


static func scenario_question(turn: Dictionary, item_id: String = "") -> Dictionary:
	var options: Array = []
	var why_ja := ""
	var why_en := ""
	for opt in turn["options"]:
		if opt["verdict"] == "correct":
			options.push_front(opt["ja"])
			why_ja = opt.get("feedback_ja", "")
			why_en = opt.get("feedback_en", "")
		else:
			options.append(opt["ja"])
	return _finish({"skill": &"conversation", "activity": &"scenario_turn", "item_id": item_id,
		"prompt": "%s「%s」" % [turn["speaker"], turn["line_ja"]], "prompt_en": turn["line_en"],
		"audio": Furigana.reading(turn["line_ja"]), "word_id": "", "dimension": "",
		"why_ja": why_ja, "why_en": why_en}, options)


static func passage_questions(p: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var qs: Array = p["questions"]
	for i in qs.size():
		var q: Dictionary = qs[i]
		out.append({"skill": &"reading", "activity": &"passage", "item_id": p["id"],
			"context": p["text_ja"], "context_title": p["title_ja"], "prompt": q["q_ja"], "prompt_en": q["q_en"],
			"options": q["options"], "answer": int(q["answer"]), "word_id": "", "dimension": "",
			"why_ja": q.get("why_ja", ""), "why_en": q.get("why_en", "")})
	return out


static func anchor_questions(a: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var vs: Array = a["variants"]
	for i in vs.size():
		var v: Dictionary = vs[i]
		var skill := StringName(v["section"])
		out.append({"skill": skill, "activity": StringName("anchor_" + String(skill)), "item_id": "%s#%d" % [a["id"], i],
			"context": a["ja"], "prompt": v["prompt_ja"], "prompt_en": v["prompt_en"], "options": v["options"],
			"answer": int(v["answer"]), "word_id": "", "dimension": "", "why_ja": v.get("why_ja", ""), "why_en": v.get("why_en", "")})
	out.shuffle()
	return out


# ---------------------------------------------------------------- helpers

static func _short_gloss(english: String) -> String:
	var parts := english.split(";")
	var out := parts[0].strip_edges()
	if parts.size() > 1 and out.length() < 14:
		out += "; " + parts[1].strip_edges()
	return out


static func _others(entry: Dictionary, pool: Array, prefer: Callable) -> Array:
	var same: Array = []
	var rest: Array = []
	var gloss := _short_gloss(entry["english"])
	for e in pool:
		if e["id"] == entry["id"] or _short_gloss(e["english"]) == gloss or e["headword"] == entry["headword"]:
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


static func _last_index_of_skill(qs: Array, skill: StringName) -> int:
	for i in range(qs.size() - 1, -1, -1):
		if qs[i]["skill"] == skill and not String(qs[i].get("activity", "")).begins_with("anchor_"):
			return i
	return -1


## Shuffle options (first entry is the correct one) and record the answer index.
static func _finish(q: Dictionary, options: Array) -> Dictionary:
	var correct: String = options[0]
	var uniq: Array = []
	for o in options:
		if o not in uniq:
			uniq.append(o)
	uniq.shuffle()
	q["options"] = uniq
	q["answer"] = uniq.find(correct)
	return q
