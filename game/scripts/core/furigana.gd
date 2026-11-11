extends RefCounted
class_name Furigana
## Parses the content markup "{漢字|かんじ}" into segments the UI can draw with ruby text.
##
## Content authors write kanji words as {base|reading}; everything outside braces is plain kana
## or punctuation. tools/validate_content.py guarantees that no kanji appears outside a group.


## One drawn unit: [code]base[/code] is the text on the main line, [code]ruby[/code] the reading
## above it ("" for plain segments).
static func parse(text: String) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var plain := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "{":
			var close := text.find("}", i)
			var bar := text.find("|", i)
			if close == -1 or bar == -1 or bar > close:
				plain += ch
				i += 1
				continue
			if plain != "":
				segments.append({"base": plain, "ruby": ""})
				plain = ""
			segments.append({"base": text.substr(i + 1, bar - i - 1), "ruby": text.substr(bar + 1, close - bar - 1)})
			i = close + 1
		else:
			plain += ch
			i += 1
	if plain != "":
		segments.append({"base": plain, "ruby": ""})
	return segments


## The sentence as it would be written: kanji kept, markup removed.
static func plain(text: String) -> String:
	var out := ""
	for seg in parse(text):
		out += seg["base"]
	return out


## The sentence entirely in kana (every kanji group replaced by its reading).
static func reading(text: String) -> String:
	var out := ""
	for seg in parse(text):
		out += seg["ruby"] if seg["ruby"] != "" else seg["base"]
	return out


## True when the text contains at least one kanji group.
static func has_kanji(text: String) -> bool:
	for seg in parse(text):
		if seg["ruby"] != "":
			return true
	return false
