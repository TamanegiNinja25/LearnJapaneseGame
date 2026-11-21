extends RefCounted
class_name StyleDrills
## Questions for the 表現 screen (GDD §9.5): register rewrites (polite ↔ casual ↔ honorific, from
## rewrites_<stage>.json) and "spot the unnatural reply" built from conversation scenarios. Pure
## functions; the screen shuffles and records answers.
##
## A question is {"id", "prompt" (markup), "prompt_en", "context" (markup, may be ""), "options":
## Array[String] (markup), "answer": int, "feedback_ja", "feedback_en", "activity": StringName}.

const REGISTER_JA := {"polite": "{丁寧|ていねい}", "casual": "{普通|ふつう}", "honorific": "{尊敬語|そんけいご}"}
const REGISTER_EN := {"polite": "polite", "casual": "casual", "honorific": "honorific"}


## A rewrite drill as a question; [param order] (a permutation of 0..2) places the answer.
static func rewrite_question(item: Dictionary, order: Array = [0, 1, 2]) -> Dictionary:
	var choices: Array = [item["answer"]]
	choices.append_array(item.get("distractors", []))
	var options: Array[String] = []
	var answer := 0
	for i in order.size():
		var pick: int = order[i]
		if pick >= choices.size():
			continue
		if pick == 0:
			answer = options.size()
		options.append(String(choices[pick]))
	var to: String = item.get("to_register", "casual")
	return {
		"id": item["id"],
		"context": item["from"],
		"prompt": ("%sの{言|い}い{方|かた}にしましょう。" % REGISTER_JA[to]) if REGISTER_JA.has(to) else "{言|い}い{換|か}えましょう。",
		"prompt_en": "Say it in the %s style. (%s)" % [REGISTER_EN.get(to, to), item.get("en", "")],
		"options": options,
		"answer": answer,
		"feedback_ja": "",
		"feedback_en": String(item.get("note", "")),
		"activity": &"rewrite",
	}


## Every scenario turn that has both a correct reply and an unnatural one, as "which reply would
## a native speaker not say?". Options: the correct reply, the unnatural one, and one more reply
## (close or wrong) when the turn has it.
static func unnatural_questions(scenarios: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sc in scenarios:
		var turns: Array = sc.get("turns", [])
		for t in turns.size():
			var turn: Dictionary = turns[t]
			var correct: Dictionary = {}
			var odd: Dictionary = {}
			for opt: Dictionary in turn.get("options", []):
				if opt.get("verdict") == "correct" and correct.is_empty():
					correct = opt
				elif opt.get("verdict") == "unnatural" and odd.is_empty():
					odd = opt
			if correct.is_empty() or odd.is_empty():
				continue
			out.append({
				"id": "%s#%d" % [sc["id"], t],
				"context": "%s：%s" % [turn.get("speaker", ""), turn.get("line_ja", "")],
				"prompt": "{自然|しぜん}じゃない{返事|へんじ}はどれですか。",
				"prompt_en": "Which reply would a native speaker not say? (%s)" % turn.get("line_en", ""),
				"options": [String(correct["ja"]), String(odd["ja"])] as Array[String],
				"answer": 1,
				"feedback_ja": String(odd.get("feedback_ja", "")),
				"feedback_en": String(odd.get("feedback_en", "")),
				"activity": &"naturalness",
			})
	return out


## Shuffle a question's options, keeping the answer index right.
static func shuffled(q: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := q.duplicate()
	var idx: Array = range((q["options"] as Array).size())
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var opts: Array[String] = []
	for i in idx:
		opts.append(q["options"][i])
	out["options"] = opts
	out["answer"] = idx.find(int(q["answer"]))
	return out

