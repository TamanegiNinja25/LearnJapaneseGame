extends RefCounted
class_name Romaji
## Wapuro-style romaji → hiragana conversion for typed answers, so players without a Japanese
## IME can still type ひらがな. Follows common IME rules: double consonant → っ, "nn"/"n'" → ん,
## "n" before a consonant → ん, "xtu"/"ltu" → small っ, "-" → ー. Unconvertible input is kept.

const TABLE := {
	"a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
	"ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
	"sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
	"ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
	"na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
	"ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
	"ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
	"ya": "や", "yu": "ゆ", "yo": "よ",
	"ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
	"la": "ら", "li": "り", "lu": "る", "le": "れ", "lo": "ろ",
	"wa": "わ", "wo": "を", "wi": "うぃ", "we": "うぇ",
	"ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
	"za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
	"da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
	"ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
	"pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
	"kya": "きゃ", "kyu": "きゅ", "kyo": "きょ", "sya": "しゃ", "syu": "しゅ", "syo": "しょ",
	"sha": "しゃ", "shu": "しゅ", "sho": "しょ", "she": "しぇ",
	"tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ", "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ", "che": "ちぇ",
	"nya": "にゃ", "nyu": "にゅ", "nyo": "にょ", "hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ",
	"mya": "みゃ", "myu": "みゅ", "myo": "みょ", "rya": "りゃ", "ryu": "りゅ", "ryo": "りょ",
	"gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ", "ja": "じゃ", "ju": "じゅ", "jo": "じょ", "je": "じぇ",
	"jya": "じゃ", "jyu": "じゅ", "jyo": "じょ", "zya": "じゃ", "zyu": "じゅ", "zyo": "じょ",
	"bya": "びゃ", "byu": "びゅ", "byo": "びょ", "pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",
	"dya": "ぢゃ", "dyu": "ぢゅ", "dyo": "ぢょ",
	"fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ", "thi": "てぃ", "dhi": "でぃ", "tsa": "つぁ",
	"xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ", "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ",
	"xtu": "っ", "ltu": "っ", "xtsu": "っ", "ltsu": "っ",
	"nn": "ん", "n'": "ん", "-": "ー", ",": "、", ".": "。", "?": "？", "!": "！",
}
const VOWELS := "aeiou"


## Convert a romaji string to hiragana. Kana and kanji already in the string pass through.
## A trailing lone "n" stays as "n" while typing; pass [param final] = true to turn it into ん.
static func to_hiragana(text: String, final: bool = false) -> String:
	var src := text.to_lower()
	var out := ""
	var i := 0
	while i < src.length():
		var ch := src[i]
		# Double consonant (not n) → っ
		if i + 1 < src.length() and ch == src[i + 1] and ch not in VOWELS and ch != "n" and ch.unicode_at(0) < 128 and ch >= "a" and ch <= "z":
			out += "っ"
			i += 1
			continue
		# "nn" + vowel/y: the first n is ん and the second starts the next mora (konnichiha).
		if ch == "n" and i + 2 < src.length() and src[i + 1] == "n" and (src[i + 2] in VOWELS or src[i + 2] == "y"):
			out += "ん"
			i += 1
			continue
		# n before a consonant (not y, not n) → ん
		if ch == "n" and i + 1 < src.length():
			var nx := src[i + 1]
			if nx not in VOWELS and nx != "y" and nx != "n" and nx != "'" and nx >= "a" and nx <= "z":
				out += "ん"
				i += 1
				continue
		var matched := false
		for size in [4, 3, 2, 1]:
			if i + size <= src.length():
				var chunk := src.substr(i, size)
				if TABLE.has(chunk):
					out += TABLE[chunk]
					i += size
					matched = true
					break
		if not matched:
			out += text[i]
			i += 1
	if final and out.ends_with("n"):
		out = out.substr(0, out.length() - 1) + "ん"
	return out


## True when the text still has unconverted ASCII letters.
static func has_latin(text: String) -> bool:
	for ch in text:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z"):
			return true
	return false
