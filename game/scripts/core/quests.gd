extends RefCounted
class_name Quests
## Daily quests (GDD §5.5). Each quest counts one daily counter up to a target and pays XP once.
## Pure data + a pure evaluator; Progress owns the counters.

const LIST: Array[Dictionary] = [
	{"id": "learn_words", "counter": "words_familiar", "target": 10, "xp": 100,
		"ja": "{新|あたら}しい{単語|たんご}を10{個|こ}{覚|おぼ}える", "en": "Learn 10 new words"},
	{"id": "reviews", "counter": "reviews", "target": 20, "xp": 100,
		"ja": "20{項目|こうもく}を{復習|ふくしゅう}する", "en": "Review 20 items"},
	{"id": "grammar_lesson", "counter": "grammar_lessons", "target": 1, "xp": 150,
		"ja": "{文法|ぶんぽう}レッスンを1つ{終|お}える", "en": "Finish one grammar lesson"},
	{"id": "listening", "counter": "listening", "target": 1, "xp": 100,
		"ja": "{会話|かいわ}を{聞|き}く", "en": "Finish a listening session"},
	{"id": "conversation", "counter": "conversations", "target": 1, "xp": 200,
		"ja": "{会話|かいわ}を{完了|かんりょう}する", "en": "Complete a conversation"},
	{"id": "sentences", "counter": "sentences", "target": 5, "xp": 150,
		"ja": "{文|ぶん}を5つ{作|つく}る", "en": "Build five sentences"},
	{"id": "daily_assessment", "counter": "daily_assessment", "target": 1, "xp": 250,
		"ja": "{毎日|まいにち}の{確認|かくにん}テストを{受|う}ける", "en": "Take the daily check"},
]


## Quests whose counter just reached its target and were not yet paid. [param counters] maps
## counter -> int, [param paid] lists quest ids already paid today.
static func newly_completed(counters: Dictionary, paid: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q in LIST:
		if q["id"] in paid:
			continue
		if int(counters.get(q["counter"], 0)) >= int(q["target"]):
			out.append(q)
	return out


static func quest(id: String) -> Dictionary:
	for q in LIST:
		if q["id"] == id:
			return q
	return {}
