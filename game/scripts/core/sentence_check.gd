extends RefCounted
class_name SentenceCheck
## Grades a sentence-builder answer against the accepted tile orders of a prompt.


enum Result { CORRECT, WRONG_ORDER, WRONG_TILES }


## [param answer] and each accepted order are arrays of tile strings (with furigana markup).
## Returns a Dictionary: result (Result), hint (String, Japanese-first), first_bad_index (int, -1 if n/a).
static func evaluate(answer: Array, accepted: Array) -> Dictionary:
	if accepted.is_empty():
		push_error("SentenceCheck.evaluate: prompt has no accepted orders")
		return {"result": Result.WRONG_TILES, "hint": "", "first_bad_index": -1}
	for order in accepted:
		if _same_sequence(answer, order):
			return {"result": Result.CORRECT, "hint": "", "first_bad_index": -1}

	var reference: Array = accepted[0]
	if not _same_multiset(answer, reference):
		var extra := _first_extra(answer, reference)
		if extra != "":
			return {"result": Result.WRONG_TILES,
				"hint": "「%s」はこの文に要りません。" % Furigana.plain(extra),
				"first_bad_index": answer.find(extra)}
		return {"result": Result.WRONG_TILES, "hint": "言葉が足りません。", "first_bad_index": -1}

	# Same tiles, wrong order: point at the first position that no accepted order allows.
	var bad := _first_divergence(answer, accepted)
	return {"result": Result.WRONG_ORDER, "hint": "順番をもう一度考えましょう。", "first_bad_index": bad}


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
