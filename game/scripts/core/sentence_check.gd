extends RefCounted
class_name SentenceCheck
## Grades a sentence-builder answer against the accepted tile orders of a prompt (GDD §7.3).

enum Result { CORRECT, WRONG_ORDER, WRONG_TILES, WRONG_PARTICLE }

## Single-tile particles recognised for targeted feedback.
const PARTICLES := ["は", "が", "を", "に", "で", "へ", "と", "も", "の", "や", "から", "まで", "より", "か", "ね", "よ", "けど", "し", "って"]


## [param answer] and each accepted order are arrays of tile strings (with furigana markup).
## Returns {result, hint (Japanese markup), first_bad_index, particle, expected}.
static func evaluate(answer: Array, accepted: Array) -> Dictionary:
	var out := {"result": Result.WRONG_TILES, "hint": "", "first_bad_index": -1, "particle": "", "expected": ""}
	if accepted.is_empty():
		push_error("SentenceCheck.evaluate: prompt has no accepted orders")
		return out
	for order in accepted:
		if _same_sequence(answer, order):
			out["result"] = Result.CORRECT
			return out

	# Exactly one particle tile swapped for another particle, everything else matching an order.
	for order: Array in accepted:
		if order.size() != answer.size():
			continue
		var diffs: Array[int] = []
		for i in order.size():
			if answer[i] != order[i]:
				diffs.append(i)
		if diffs.size() == 1 and answer[diffs[0]] in PARTICLES and order[diffs[0]] in PARTICLES:
			out["result"] = Result.WRONG_PARTICLE
			out["first_bad_index"] = diffs[0]
			out["particle"] = answer[diffs[0]]
			out["expected"] = order[diffs[0]]
			out["hint"] = "「%s」が{違|ちが}います。" % answer[diffs[0]]
			return out

	var reference: Array = accepted[0]
	if not _same_multiset(answer, reference):
		var extra := _first_extra(answer, reference)
		if extra != "":
			out["hint"] = "「%s」はこの{文|ぶん}に{要|い}りません。" % extra
			out["first_bad_index"] = answer.find(extra)
			return out
		out["hint"] = "{言葉|ことば}が{足|た}りません。"
		return out

	out["result"] = Result.WRONG_ORDER
	out["hint"] = "{順番|じゅんばん}をもう{一度|いちど}{考|かんが}えましょう。"
	out["first_bad_index"] = _first_divergence(answer, accepted)
	return out


static func is_particle(tile: String) -> bool:
	return tile in PARTICLES


static func _same_sequence(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


static func _same_multiset(a: Array, b: Array) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	x.sort()
	y.sort()
	return _same_sequence(x, y)


static func _first_extra(answer: Array, reference: Array) -> String:
	var pool := reference.duplicate()
	for tile in answer:
		var idx := pool.find(tile)
		if idx == -1:
			return tile
		pool.remove_at(idx)
	return ""


static func _first_divergence(answer: Array, accepted: Array) -> int:
	var best := -1
	for order in accepted:
		var n := mini(answer.size(), order.size())
		var i := 0
		while i < n and answer[i] == order[i]:
			i += 1
		best = maxi(best, i)
	return best


## Tier for the sentence builder from the 文法 score (GDD §7.2).
static func tier_for_score(grammar_score: int) -> int:
	if grammar_score < 40:
		return 1
	if grammar_score < 70:
		return 2
	return 3
