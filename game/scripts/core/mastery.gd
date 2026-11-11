extends RefCounted
class_name Mastery
## Pure rules for skill scores, proficiency gates, XP levels and per-word mastery ranks.
## Implements docs/GAME_DESIGN.md §5 and §6. No node access, no I/O: everything here is
## unit-tested headlessly in tests/test_runner.gd.


## The six tracked skills, in dashboard order. Keys are also used in the save file.
const SKILLS: Array[StringName] = [&"vocab", &"grammar", &"reading", &"listening", &"conversation", &"kanji"]

const SKILL_LABEL_JA := {
	&"vocab": "{語彙|ごい}", &"grammar": "{文法|ぶんぽう}", &"reading": "{読解|どっかい}",
	&"listening": "{聴解|ちょうかい}", &"conversation": "{会話|かいわ}", &"kanji": "{漢字|かんじ}",
}
const SKILL_LABEL_EN := {
	&"vocab": "Vocabulary", &"grammar": "Grammar", &"reading": "Reading",
	&"listening": "Listening", &"conversation": "Conversation", &"kanji": "Kanji",
}

## Stages in order. Content exists for N5 only in Phase 1; later stages are gated but empty.
const STAGES: Array[StringName] = [&"N5", &"N4", &"N3", &"N2", &"N1", &"MASTERY"]
const STAGE_LABEL_JA := {
	&"N5": "N5 {初級|しょきゅう}", &"N4": "N4 {初中級|しょちゅうきゅう}", &"N3": "N3 {中級|ちゅうきゅう}",
	&"N2": "N2 {中上級|ちゅうじょうきゅう}", &"N1": "N1 {上級|じょうきゅう}", &"MASTERY": "{完全習得|かんぜんしゅうとく}",
}

## Gate thresholds (percent) per stage exam (GDD §5.4). Listening is optional until TTS ships
## (Phase 7), so it is absent from the N5 gate.
const GATES := {
	&"N5": {&"vocab": 85, &"grammar": 90, &"reading": 85, &"conversation": 80, &"kanji": 80},
	&"N4": {&"vocab": 85, &"grammar": 90, &"reading": 85, &"listening": 85, &"conversation": 82, &"kanji": 80},
	&"N3": {&"vocab": 85, &"grammar": 88, &"reading": 85, &"listening": 85, &"conversation": 85, &"kanji": 82},
	&"N2": {&"vocab": 85, &"grammar": 88, &"reading": 85, &"listening": 85, &"conversation": 88, &"kanji": 85},
	&"N1": {&"vocab": 85, &"grammar": 88, &"reading": 85, &"listening": 85, &"conversation": 90, &"kanji": 85},
}

## The exam unlocks when every mandatory score is at least threshold - EXAM_MARGIN (GDD §5.4 rule 1).
const EXAM_MARGIN := 15
const EXAM_COOLDOWN_SECONDS := 24 * 3600
const EXAM_PASS_XP := 1000

## Skill score formula (GDD §5.2).
const ALPHA := 0.08
const CONFIDENCE_SAMPLES := 30.0
## Coverage weight per skill: inventory skills blend coverage 50/50 with performance.
const COVERAGE_WEIGHT := {&"vocab": 0.5, &"kanji": 0.5, &"grammar": 0.5, &"reading": 0.0, &"listening": 0.0, &"conversation": 0.0}
## A grammar point counts as covered after this many correct answers.
const GRAMMAR_COVERED_AT := 3
## Assessment samples weigh more than practice samples.
const ASSESSMENT_WEIGHT := 1.5

## Per-word mastery ranks (GDD §6.1).
enum Rank { UNSEEN, DISCOVERED, FAMILIAR, LEARNED, PROFICIENT, MASTERED }
const RANK_LABEL_JA := ["{未知|みち}", "{発見|はっけん}", "{見覚|みおぼ}え", "{学習済|がくしゅうず}み", "{使|つか}える", "{習得|しゅうとく}"]
const RANK_LABEL_EN := ["Unseen", "Discovered", "Familiar", "Learned", "Proficient", "Mastered"]

## Activity -> {skill: weight} (GDD §5.3). Each answer emits one sample per listed skill.
const ACTIVITY_WEIGHTS := {
	&"kana": {&"reading": 0.2},
	&"review_recognition": {&"vocab": 1.0},
	&"review_recognition_kanji": {&"vocab": 1.0, &"kanji": 0.3},
	&"review_recall": {&"vocab": 1.0},
	&"review_kanji_reading": {&"vocab": 0.3, &"kanji": 1.0},
	&"review_example_reading": {&"vocab": 0.3, &"reading": 1.0},
	&"grammar_quiz": {&"grammar": 1.0, &"reading": 0.2},
	&"sentence_builder": {&"vocab": 0.2, &"grammar": 0.6, &"reading": 0.2},
	&"scenario_turn": {&"vocab": 0.2, &"grammar": 0.2, &"conversation": 0.6},
}

## XP per item (GDD §5.5).
const XP := {&"kana": 2, &"review": 5, &"sentence": 20, &"sentence_hinted": 10, &"scenario_turn": 15,
	&"grammar_quiz": 10, &"scenario_complete": 200, &"daily_assessment": 250}


# ---------------------------------------------------------------- skill scores

## A fresh per-skill record.
static func new_skill() -> Dictionary:
	return {"perf": 0.0, "n": 0.0}


## Apply one sample: [param c] is correctness in {0, 0.5, 1}, [param w] the sample weight.
## perf <- perf + alpha * w * (c - perf);  n <- n + w
static func apply_sample(skill: Dictionary, c: float, w: float) -> Dictionary:
	var perf := float(skill.get("perf", 0.0))
	var n := float(skill.get("n", 0.0))
	c = clampf(c, 0.0, 1.0)
	return {"perf": clampf(perf + ALPHA * w * (c - perf), 0.0, 1.0), "n": n + w}


## score = round(100 * (covw * cov + (1 - covw) * perf * confidence)), confidence = min(1, n / 30).
static func score(skill: Dictionary, key: StringName, coverage: float) -> int:
	var covw := float(COVERAGE_WEIGHT.get(key, 0.0))
	var perf := float(skill.get("perf", 0.0))
	var confidence := minf(1.0, float(skill.get("n", 0.0)) / CONFIDENCE_SAMPLES)
	return roundi(100.0 * (covw * clampf(coverage, 0.0, 1.0) + (1.0 - covw) * perf * confidence))


## Emit the samples one activity answer produces. Returns {skill: weight} scaled for assessments.
static func samples_for(activity: StringName, from_assessment: bool = false) -> Dictionary:
	var weights: Dictionary = ACTIVITY_WEIGHTS.get(activity, {})
	if not from_assessment:
		return weights
	var scaled := {}
	for skill: StringName in weights:
		scaled[skill] = float(weights[skill]) * ASSESSMENT_WEIGHT
	return scaled


# ---------------------------------------------------------------- gates & stages

## Evaluate the gate for [param stage] against score ints. Returns
## {passed: bool, failing: Array[StringName], required: Dictionary}.
static func evaluate_gate(scores: Dictionary, stage: StringName) -> Dictionary:
	var required: Dictionary = GATES.get(stage, {})
	var failing: Array[StringName] = []
	for skill: StringName in required:
		if int(scores.get(skill, 0)) < int(required[skill]):
			failing.append(skill)
	return {"passed": failing.is_empty(), "failing": failing, "required": required}


## True when every mandatory score is within EXAM_MARGIN of its threshold (GDD §5.4 rule 1).
static func exam_unlocked(scores: Dictionary, stage: StringName) -> bool:
	var required: Dictionary = GATES.get(stage, {})
	for skill: StringName in required:
		if int(scores.get(skill, 0)) < int(required[skill]) - EXAM_MARGIN:
			return false
	return not required.is_empty()


static func next_stage(stage: StringName) -> StringName:
	var i := STAGES.find(stage)
	if i == -1 or i + 1 >= STAGES.size():
		return stage
	return STAGES[i + 1]


## Mandatory skills for a stage sorted by gap (threshold - score), largest first.
static func skills_by_gap(scores: Dictionary, stage: StringName) -> Array[StringName]:
	var required: Dictionary = GATES.get(stage, GATES[&"N5"])
	var keys: Array[StringName] = []
	for skill: StringName in required:
		keys.append(skill)
	keys.sort_custom(func(a: StringName, b: StringName) -> bool:
		var gap_a := int(required[a]) - int(scores.get(a, 0))
		var gap_b := int(required[b]) - int(scores.get(b, 0))
		return gap_a > gap_b)
	return keys


# ---------------------------------------------------------------- XP

## Level L needs 500 * L * (L - 1) cumulative XP: L2 at 1000, L5 at 10000, L10 at 45000.
static func level_for_xp(xp: int) -> int:
	return int(floor((1.0 + sqrt(1.0 + float(xp) / 125.0)) / 2.0))


static func xp_for_level(level: int) -> int:
	return 500 * level * (level - 1)


# ---------------------------------------------------------------- word ranks

## A fresh per-word record (GDD §6.1 / §11.7).
static func new_word() -> Dictionary:
	return {"rank": Rank.UNSEEN, "rec": 0, "rcl": 0, "use": 0, "box": 0, "due": 0, "streak": 0, "lapses": 0}


## The rank a word has earned from its counters, box and streak (GDD §6.1 table). Promotion is
## capped at one rank above [param current] per call.
static func promoted_rank(word: Dictionary) -> int:
	var current := int(word.get("rank", Rank.UNSEEN))
	if current == Rank.UNSEEN:
		return Rank.UNSEEN
	var rec := int(word.get("rec", 0))
	var rcl := int(word.get("rcl", 0))
	var use := int(word.get("use", 0))
	var box := int(word.get("box", 0))
	var streak := int(word.get("streak", 0))
	var earned := Rank.DISCOVERED
	if rec >= 2:
		earned = Rank.FAMILIAR
	if rec >= 4 and rcl >= 2:
		earned = Rank.LEARNED
	if rcl >= 4 and use >= 2 and box >= 4:
		earned = Rank.PROFICIENT
	if use >= 4 and box >= 6 and streak >= 6:
		earned = Rank.MASTERED
	return clampi(earned, current, current + 1)


## Record a correct answer on [param dimension] ("rec", "rcl" or "use"). Returns the new record.
static func word_correct(word: Dictionary, dimension: String) -> Dictionary:
	var out := word.duplicate()
	if int(out["rank"]) == Rank.UNSEEN:
		out["rank"] = Rank.DISCOVERED
	out[dimension] = int(out.get(dimension, 0)) + 1
	out["streak"] = int(out.get("streak", 0)) + 1
	out["rank"] = promoted_rank(out)
	return out


## Record a lapse on [param dimension] (GDD §6.2): streak 0, lapses +1, counter -2 (floor 0),
## box -2 (floor 0), rank -1 if at least Learned. Floor is Familiar.
static func word_lapse(word: Dictionary, dimension: String) -> Dictionary:
	var out := word.duplicate()
	if int(out["rank"]) == Rank.UNSEEN:
		out["rank"] = Rank.DISCOVERED
	out["streak"] = 0
	out["lapses"] = int(out.get("lapses", 0)) + 1
	out[dimension] = maxi(0, int(out.get(dimension, 0)) - 2)
	out["box"] = maxi(0, int(out.get("box", 0)) - 2)
	if int(out["rank"]) >= Rank.LEARNED:
		out["rank"] = maxi(int(out["rank"]) - 1, Rank.FAMILIAR)
	return out
