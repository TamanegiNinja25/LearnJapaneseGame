extends RefCounted
class_name Recommender
## Picks the dashboard's recommended next activity (docs/GAME_DESIGN.md §10.1, Phase 1 rules).
## Pure function: every input is passed in so it can be unit-tested.

const KANA_TARGET := 0.9
const REVIEW_PILE := 10

## Screen names, matching main.gd's SCREENS keys.
const KANA := &"kana"
const REVIEW := &"review"
const DICTIONARY := &"dictionary"
const SENTENCES := &"sentences"
const CONVERSATION := &"conversation"
const ASSESSMENT := &"assessment"

const SKILL_TO_SCREEN := {
	&"vocab": DICTIONARY, &"grammar": SENTENCES, &"reading": REVIEW,
	&"conversation": CONVERSATION, &"kanji": REVIEW, &"listening": REVIEW,
}

## Japanese-first reasons shown under the recommendation.
const REASON := {
	KANA: "まずはかなを{覚|おぼ}えましょう。",
	REVIEW: "{復習|ふくしゅう}が{溜|た}まっています。",
	DICTIONARY: "{新|あたら}しい{言葉|ことば}を{見|み}つけましょう。",
	SENTENCES: "{文|ぶん}を{作|つく}る{練習|れんしゅう}をしましょう。",
	CONVERSATION: "{会話|かいわ}で{使|つか}ってみましょう。",
	ASSESSMENT: "{昇級試験|しょうきゅうしけん}を{受|う}けられます！",
}


## [param history] holds the last recommendations (most recent last).
static func recommend(kana_mastery: float, due_count: int, exam_unlocked: bool, scores: Dictionary,
		stage: StringName, history: Array = []) -> StringName:
	if kana_mastery < KANA_TARGET:
		return KANA
	if due_count >= REVIEW_PILE:
		return REVIEW
	if exam_unlocked:
		return ASSESSMENT
	var by_gap := Mastery.skills_by_gap(scores, stage)
	var first := _screen_for(by_gap[0] if by_gap.size() > 0 else &"vocab", due_count)
	# Anti-repetition: if the same activity was recommended twice in a row, take the next gap.
	if history.size() >= 2 and history[-1] == first and history[-2] == first and by_gap.size() > 1:
		return _screen_for(by_gap[1], due_count)
	return first


static func _screen_for(skill: StringName, due_count: int) -> StringName:
	var screen: StringName = SKILL_TO_SCREEN.get(skill, DICTIONARY)
	# 語彙: the dictionary feeds new words; once there is anything to review, reviewing wins.
	if skill == &"vocab" and due_count > 0:
		return REVIEW
	return screen
