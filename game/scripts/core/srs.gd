extends RefCounted
class_name Srs
## Leitner-style spaced repetition (docs/GAME_DESIGN.md §6.3): one box per word, nine boxes.
## Pure functions over a word record so the schedule can be unit-tested without the scene tree.
##
## The word record fields used here: "box" (int 0..8) and "due" (unix seconds).


## Review interval per box, in hours. Box 0 is "immediate" (same session).
const INTERVALS_H: Array[float] = [0.0, 4.0, 24.0, 72.0, 168.0, 336.0, 720.0, 1440.0, 2880.0]
const MAX_BOX := 8
const HOUR := 3600

## Correctness of one review, matching the GDD's c values: wrong 0, hinted/partial 0.5, correct 1.
const C_WRONG := 0.0
const C_PARTIAL := 0.5
const C_CORRECT := 1.0

## How many other items must come between a box-0 word's two showings in one session.
const IMMEDIATE_GAP := 5


static func interval_hours(box: int) -> float:
	return INTERVALS_H[clampi(box, 0, MAX_BOX)]


static func is_due(word: Dictionary, now: int) -> bool:
	return int(word.get("due", 0)) <= now


## Decide the box a word moves to after one review (GDD §6.3):
##   correct, no hint (c == 1.0):  one box up, capped at MAX_BOX
##   partial / hinted (c == 0.5):  box unchanged
##   wrong (c == 0.0):             two boxes down, floored at 0
## [param box] is the word's current box, [param c] the correctness of this review.
static func next_box(box: int, c: float) -> int:
	# Thresholds rather than equality, so a future grader emitting e.g. 0.75 still lands in the
	# "partial" band instead of silently doing nothing.
	if c >= C_CORRECT:
		return mini(box + 1, MAX_BOX)
	if c <= C_WRONG:
		return maxi(box - 2, 0)
	return clampi(box, 0, MAX_BOX)


## Apply one review and return the updated word record with a new box and due time.
## Only the scheduling fields change here; counters and rank are handled by Mastery.
static func review(word: Dictionary, c: float, now: int) -> Dictionary:
	var out := word.duplicate()
	out["box"] = next_box(int(word.get("box", 0)), c)
	out["due"] = now + int(interval_hours(out["box"]) * HOUR)
	return out


## Order due words most-overdue first and cap the session (GDD §6.3: limit 20).
static func pick_due(words: Dictionary, now: int, limit: int = 20) -> Array[String]:
	var due: Array[String] = []
	for id: String in words:
		var w: Dictionary = words[id]
		# Only words the player chose to study (学習する) or answered in review are scheduled.
		if w.get("srs", false) and is_due(w, now):
			due.append(id)
	due.sort_custom(func(a: String, b: String) -> bool:
		return int(words[a]["due"]) < int(words[b]["due"]))
	if due.size() > limit:
		due.resize(limit)
	return due
