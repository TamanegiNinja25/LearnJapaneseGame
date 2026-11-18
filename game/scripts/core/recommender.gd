extends RefCounted
class_name Recommender
## Picks the dashboard's recommended next activity (docs/GAME_DESIGN.md §10.1). Pure function:
## every input arrives in one Dictionary so tests can build any situation.
##
## Input keys: kana_mastery (0..1), due_count, exam_unlocked, scores, stage, history (Array of
## activity keys the player started from 次にやること, most recent last; see [method key]),
## daily_done (bool), daily_score (0..100), familiar_words, budget_left (new words still allowed
## today), weakest_grammar_correct (correct answers of the least-covered grammar point), tts (bool:
## a Japanese voice is available), roll (any int; picks the random alternative, so tests can fix it).
## Output: {"screen": StringName, "mode": String, "reason": String (markup)}.

const KANA_TARGET := 0.9
const REVIEW_PILE := 10
const DAILY_EXAM_SCORE := 80
const DAILY_MIN_WORDS := 50
## After this many attempts in a row at the same suggestion, suggest a random different activity.
const REPEAT_LIMIT := 3

const KANA := &"kana"
const REVIEW := &"review"
const DICTIONARY := &"dictionary"
const SENTENCES := &"sentences"
const GRAMMAR := &"grammar"
const CONVERSATION := &"conversation"
const ASSESSMENT := &"assessment"
const KANJI := &"kanji"
const LISTENING := &"listening"
const WRITING := &"writing"

const REASON := {
	"kana": "まずはかなを{覚|おぼ}えましょう。",
	"review": "{復習|ふくしゅう}が{溜|た}まっています。",
	"exam": "{昇級試験|しょうきゅうしけん}を{受|う}けられます！",
	"daily": "{今日|きょう}の{確認|かくにん}テストをしましょう。",
	"vocab": "{新|あたら}しい{言葉|ことば}を{学習|がくしゅう}しましょう。",
	"vocab_review": "{覚|おぼ}えた{言葉|ことば}を{復習|ふくしゅう}しましょう。",
	"grammar": "{文|ぶん}を{作|つく}る{練習|れんしゅう}をしましょう。",
	"grammar_lesson": "{新|あたら}しい{文法|ぶんぽう}を{学|まな}びましょう。",
	"reading": "{例文|れいぶん}を{読|よ}む{練習|れんしゅう}をしましょう。",
	"conversation": "{会話|かいわ}で{使|つか}ってみましょう。",
	"kanji": "{漢字|かんじ}を{覚|おぼ}えましょう。",
	"listening": "{日本語|にほんご}を{聞|き}いてみましょう。",
	"writing": "{漢字|かんじ}を{書|か}いて{覚|おぼ}えましょう。",
}
## Put before the reason when the suggestion was shuffled after REPEAT_LIMIT identical attempts.
const SHUFFLED_REASON := "{気分転換|きぶんてんかん}に、{別|べつ}の{練習|れんしゅう}をしましょう。"


static func recommend(s: Dictionary) -> Dictionary:
	var first := _rule_based(s)
	if first["mode"] == "gate":
		return first  # the stage exam is never shuffled away
	var history: Array = s.get("history", [])
	if history.size() < REPEAT_LIMIT:
		return first
	for entry in history.slice(-REPEAT_LIMIT):
		if String(entry) != key(first):
			return first
	var others: Array[Dictionary] = []
	for option in alternatives(s):
		if key(option) != key(first):
			others.append(option)
	if others.is_empty():
		return first
	var pick := others[absi(int(s.get("roll", 0))) % others.size()].duplicate()
	pick["reason"] = SHUFFLED_REASON + String(pick["reason"])
	pick["shuffled"] = true
	return pick


## Identifies an activity in the history: "review:reading", "kanji:".
static func key(rec: Dictionary) -> String:
	return "%s:%s" % [rec["screen"], rec["mode"]]


## The activity that trains [param skill] best right now (GDD §10.1 rule 5 mapping).
static func for_skill(skill: StringName, s: Dictionary) -> Dictionary:
	return _for_skill(skill, s)


## One activity per skill, without duplicates: the pool the random alternative is drawn from.
static func alternatives(s: Dictionary) -> Array[Dictionary]:
	var skills: Array[StringName] = []
	skills.assign(Mastery.SKILLS)
	if not s.get("tts", false):
		skills.erase(&"listening")
	var out: Array[Dictionary] = []
	var seen := {}
	for skill in skills:
		var rec := _for_skill(skill, s)
		if not seen.has(key(rec)):
			seen[key(rec)] = true
			out.append(rec)
	return out


static func _rule_based(s: Dictionary) -> Dictionary:
	var stage: StringName = s.get("stage", &"N5")
	var scores: Dictionary = s.get("scores", {})
	if float(s.get("kana_mastery", 1.0)) < KANA_TARGET:
		return _out(KANA, "", "kana")
	if int(s.get("due_count", 0)) >= REVIEW_PILE:
		return _out(REVIEW, "", "review")
	if s.get("exam_unlocked", false) and s.get("daily_done", false) and int(s.get("daily_score", 0)) >= DAILY_EXAM_SCORE:
		return _out(ASSESSMENT, "gate", "exam")
	if not s.get("daily_done", false) and int(s.get("familiar_words", 0)) >= DAILY_MIN_WORDS:
		return _out(ASSESSMENT, "daily", "daily")
	var by_gap := Mastery.skills_by_gap(scores, stage)
	if s.get("tts", false) and not by_gap.has(&"listening"):
		by_gap.append(&"listening")  # optional skill: offered last when a voice exists
	if by_gap.is_empty():
		return _out(DICTIONARY, "", "vocab")
	return _for_skill(by_gap[0], s)


static func _for_skill(skill: StringName, s: Dictionary) -> Dictionary:
	match skill:
		&"vocab":
			if int(s.get("budget_left", 0)) > 0:
				return _out(DICTIONARY, "", "vocab")
			return _out(REVIEW, "", "vocab_review")
		&"grammar":
			if int(s.get("weakest_grammar_correct", 99)) < Mastery.GRAMMAR_COVERED_AT:
				return _out(GRAMMAR, "", "grammar_lesson")
			return _out(SENTENCES, "", "grammar")
		&"reading":
			return _out(REVIEW, "reading", "reading")
		&"conversation":
			return _out(CONVERSATION, "", "conversation")
		&"kanji":
			return _out(KANJI, "", "kanji")
		&"listening":
			return _out(LISTENING, "", "listening")
		&"writing":
			return _out(WRITING, "", "writing")
	return _out(DICTIONARY, "", "vocab")


static func _out(screen: StringName, mode: String, reason_key: String) -> Dictionary:
	return {"screen": screen, "mode": mode, "reason": REASON[reason_key]}
