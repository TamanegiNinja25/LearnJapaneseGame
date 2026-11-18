extends RefCounted
class_name StrokeMatch
## Judges one hand-drawn stroke against the expected KanjiVG stroke (both in the 109 x 109 box).
## Pure functions: the writing screen converts pad coordinates before calling [method judge].
##
## Both strokes are resampled to SAMPLES evenly spaced points and compared point by point, so
## the shape, the position and the direction all count: a stroke drawn backwards matches the
## reversed curve and is reported as "direction". Dots (very short strokes) only need to land
## near the right place.

const SAMPLES := 24
## Mean distance (KanjiVG units, ~1/109 of the box) allowed between drawn and expected points.
const TOLERANCE := 17.0
## The drawn stroke must start and end this close to the expected start and end.
const END_TOLERANCE := 26.0
## Strokes shorter than this are dots/ticks: judged by position only.
const DOT_LENGTH := 14.0
const DOT_TOLERANCE := 20.0
## A drawn stroke shorter than this is a tap, not a stroke.
const MIN_LENGTH := 3.0


static func length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total


## [param n] points spaced evenly along the polyline (first and last points kept).
static func resample(pts: PackedVector2Array, n: int = SAMPLES) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.is_empty():
		return out
	var total := length(pts)
	if pts.size() == 1 or total <= 0.0:
		for i in n:
			out.append(pts[0])
		return out
	var step := total / float(n - 1)
	out.append(pts[0])
	var seg := 1
	var walked := 0.0  # distance from pts[0] to pts[seg - 1]
	for k in range(1, n - 1):
		var target := step * k
		while seg < pts.size() - 1 and walked + pts[seg - 1].distance_to(pts[seg]) < target:
			walked += pts[seg - 1].distance_to(pts[seg])
			seg += 1
		var a := pts[seg - 1]
		var b := pts[seg]
		var span := a.distance_to(b)
		out.append(a.lerp(b, clampf((target - walked) / span, 0.0, 1.0) if span > 0.0 else 0.0))
	out.append(pts[pts.size() - 1])
	return out


static func _mean_distance(a: PackedVector2Array, b: PackedVector2Array, reverse_b: bool) -> float:
	var sum := 0.0
	for i in a.size():
		sum += a[i].distance_to(b[b.size() - 1 - i] if reverse_b else b[i])
	return sum / float(a.size())


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / float(maxi(1, pts.size()))


## {"ok": bool, "reason": "ok" | "short" | "direction" | "shape", "error": mean distance}
static func judge(drawn: PackedVector2Array, expected: PackedVector2Array) -> Dictionary:
	var drawn_len := length(drawn)
	var expected_len := length(expected)
	if expected_len < DOT_LENGTH:
		var near := _centroid(drawn).distance_to(_centroid(expected))
		var ok := near <= DOT_TOLERANCE and drawn_len <= expected_len + 30.0
		return {"ok": ok, "reason": "ok" if ok else "shape", "error": near}
	if drawn.size() < 2 or drawn_len < MIN_LENGTH:
		return {"ok": false, "reason": "short", "error": INF}
	var a := resample(drawn)
	var b := resample(expected)
	var forward := _mean_distance(a, b, false)
	var backward := _mean_distance(a, b, true)
	var ends_ok := a[0].distance_to(b[0]) <= END_TOLERANCE and a[a.size() - 1].distance_to(b[b.size() - 1]) <= END_TOLERANCE
	var ratio := drawn_len / expected_len
	if forward <= TOLERANCE and ends_ok and ratio > 0.45 and ratio < 2.0:
		return {"ok": true, "reason": "ok", "error": forward}
	if backward <= TOLERANCE and backward < forward:
		return {"ok": false, "reason": "direction", "error": backward}
	return {"ok": false, "reason": "shape", "error": forward}


## Points from a square pad of [param side] pixels (origin top-left) into the 109 box.
static func to_box(pts: PackedVector2Array, side: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var k := 109.0 / maxf(1.0, side)
	for p in pts:
		out.append(p * k)
	return out
