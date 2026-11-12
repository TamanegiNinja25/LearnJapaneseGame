extends RefCounted
class_name AnswerMatch
## Grades free-text answers (typed via IME or romaji) against accepted answers. Pure functions.
##
## Normalisation: strip spaces and sentence punctuation, katakana → hiragana, full-width ASCII →
## half-width. An answer matches when its normalised form equals any accepted form, comparing
## both the written form and the all-kana reading (so みずをください matches 水をください).

const PARTICLES := ["は", "が", "を", "に", "で", "へ", "と", "も", "の", "や", "から", "まで", "より", "か", "ね", "よ"]
const STRIP := " 　。、．，,.!！?？「」『』…"


static func normalise(text: String) -> String:
	var out := ""
	for ch in text:
		if STRIP.contains(ch):
			continue
		var code := ch.unicode_at(0)
		if code >= 0x30A1 and code <= 0x30F6:  # katakana → hiragana
			out += String.chr(code - 0x60)
		elif code >= 0xFF01 and code <= 0xFF5E:  # full-width ASCII
			out += String.chr(code - 0xFEE0)
		else:
			out += ch
	return out.to_lower()


## All the forms an accepted answer may take. Accepted entries can be plain strings or markup;
## markup yields both its written and its kana form.
static func forms(accepted: Array) -> Array[String]:
	var out: Array[String] = []
	for a: String in accepted:
		for f in [Furigana.plain(a), Furigana.reading(a)]:
			var n := normalise(f)
			if n != "" and n not in out:
				out.append(n)
	return out


## Grade [param typed] against [param accepted]. Returns {correct: bool, hint_ja: String,
## closest: String}. When the answer differs from an accepted form by exactly one particle, the
## hint names the particle (GDD §7.3 particle feedback, reused for typed answers).
static func grade(typed: String, accepted: Array) -> Dictionary:
	var t := normalise(Romaji.to_hiragana(typed, true))
	var all := forms(accepted)
	if t == "":
		return {"correct": false, "hint_ja": "{何|なに}か{入力|にゅうりょく}してください。", "closest": ""}
	if t in all:
		return {"correct": true, "hint_ja": "", "closest": t}
	var best := ""
	var best_d := 1 << 30
	for f in all:
		var d := distance(t, f)
		if d < best_d:
			best_d = d
			best = f
	var particle := particle_diff(t, best)
	if particle != "":
		return {"correct": false, "hint_ja": "「%s」をもう{一度|いちど}{考|かんが}えましょう。" % particle, "closest": best}
	if best_d <= 2:
		return {"correct": false, "hint_ja": "おしい！{少|すこ}しだけ{違|ちが}います。", "closest": best}
	return {"correct": false, "hint_ja": "", "closest": best}


## If [param a] and [param b] differ only by one particle substitution, return the particle used
## in [param a]; otherwise "".
static func particle_diff(a: String, b: String) -> String:
	var prefix := 0
	while prefix < mini(a.length(), b.length()) and a[prefix] == b[prefix]:
		prefix += 1
	var suffix := 0
	while suffix < mini(a.length(), b.length()) - prefix and a[a.length() - 1 - suffix] == b[b.length() - 1 - suffix]:
		suffix += 1
	var mid_a := a.substr(prefix, a.length() - prefix - suffix)
	var mid_b := b.substr(prefix, b.length() - prefix - suffix)
	if mid_a != mid_b and mid_a in PARTICLES and mid_b in PARTICLES:
		return mid_a
	return ""


## Levenshtein distance (small strings only).
static func distance(a: String, b: String) -> int:
	var prev: Array[int] = []
	for j in b.length() + 1:
		prev.append(j)
	for i in range(1, a.length() + 1):
		var cur: Array[int] = [i]
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur.append(mini(mini(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost))
		prev = cur
	return prev[b.length()]
