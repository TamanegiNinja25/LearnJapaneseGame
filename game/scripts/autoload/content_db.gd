extends Node
## Autoload "ContentDB": loads every content JSON once at startup and exposes typed lookups.
## Files are named <kind>_<stage>[_suffix].json (docs/CONTENT_GUIDE.md); every file of a kind and
## stage is merged. Content is read-only; player state lives in the Progress autoload.

const CONTENT_DIR := "res://content/"
const KINDS: Array[String] = ["vocab", "kanji", "grammar", "sentences", "scenarios", "passages", "anchors"]
const STAGE_KEYS := {&"N5": "n5", &"N4": "n4", &"N3": "n3", &"N2": "n2", &"N1": "n1", &"MASTERY": "mastery"}

var kana: Dictionary = {}

## All stages merged (kept for screens that browse everything).
var vocab: Array[Dictionary] = []
var grammar: Array[Dictionary] = []
var sentences: Array[Dictionary] = []
var scenarios: Array[Dictionary] = []
var passages: Array[Dictionary] = []
var anchors: Array[Dictionary] = []
var kanji: Array[Dictionary] = []

## stage key ("n5") -> kind -> Array[Dictionary]
var _by_stage: Dictionary = {}
var _vocab_by_id: Dictionary = {}
var _vocab_by_headword: Dictionary = {}
var _grammar_by_id: Dictionary = {}
var _scenario_by_id: Dictionary = {}
var _kanji_by_char: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	kana = _load_json(CONTENT_DIR + "kana.json", {})
	_by_stage.clear()
	for stage_key: String in STAGE_KEYS.values():
		_by_stage[stage_key] = {}
		for kind in KINDS:
			_by_stage[stage_key][kind] = []
	for file in _content_files():
		var m := _parse_name(file)
		if m.is_empty():
			continue
		var data: Variant = _load_json(CONTENT_DIR + file, [])
		if data is Array:
			(_by_stage[m["stage"]][m["kind"]] as Array).append_array(data)
	vocab.assign(_merged("vocab"))
	grammar.assign(_merged("grammar"))
	sentences.assign(_merged("sentences"))
	scenarios.assign(_merged("scenarios"))
	passages.assign(_merged("passages"))
	anchors.assign(_merged("anchors"))
	kanji.assign(_merged("kanji"))
	_vocab_by_id.clear()
	_vocab_by_headword.clear()
	for e in vocab:
		_vocab_by_id[e["id"]] = e
		if not _vocab_by_headword.has(e["headword"]):
			_vocab_by_headword[e["headword"]] = e
	_grammar_by_id.clear()
	for g in grammar:
		_grammar_by_id[g["id"]] = g
	_scenario_by_id.clear()
	for s in scenarios:
		_scenario_by_id[s["id"]] = s
	_kanji_by_char.clear()
	for k in kanji:
		_kanji_by_char[k["kanji"]] = k


# ---------------------------------------------------------------- stage views

static func stage_key(stage: StringName) -> String:
	return STAGE_KEYS.get(stage, "n5")


## Items of one kind for exactly one stage.
func stage_items(kind: String, stage: StringName) -> Array:
	return (_by_stage.get(stage_key(stage), {}) as Dictionary).get(kind, [])


## Items of one kind for every stage up to and including [param stage] (unlocked content).
func unlocked_items(kind: String, stage: StringName) -> Array:
	var out: Array = []
	for s: StringName in Mastery.STAGES:
		out.append_array(stage_items(kind, s))
		if s == stage:
			break
	return out


## Everything the gate exam of [param stage] draws from.
func stage_pack(stage: StringName) -> Dictionary:
	var pack := {}
	for kind in KINDS:
		pack[kind] = stage_items(kind, stage)
	# Stages without their own words (Mastery) reuse the previous stage's vocabulary for the
	# vocab/kanji sections so an exam can always be assembled.
	if (pack["vocab"] as Array).size() < 10:
		pack["vocab"] = unlocked_items("vocab", stage)
	return pack


func has_stage_content(stage: StringName) -> bool:
	for kind in ["grammar", "sentences", "scenarios"]:
		if not stage_items(kind, stage).is_empty():
			return true
	return false


# ---------------------------------------------------------------- lookups

func word(id: String) -> Dictionary:
	return _vocab_by_id.get(id, {})


func word_by_headword(headword: String) -> Dictionary:
	return _vocab_by_headword.get(headword, {})


func grammar_point(id: String) -> Dictionary:
	return _grammar_by_id.get(id, {})


func scenario(id: String) -> Dictionary:
	return _scenario_by_id.get(id, {})


func kanji_info(ch: String) -> Dictionary:
	return _kanji_by_char.get(ch, {})


## Case-insensitive substring search over headword, reading and English, limited to [param pool].
func search_vocab(query: String, pool: Array = []) -> Array[Dictionary]:
	var source: Array = pool if not pool.is_empty() else vocab
	var q := query.strip_edges().to_lower()
	var kana_q := Romaji.to_hiragana(q, true) if Romaji.has_latin(q) else q
	var out: Array[Dictionary] = []
	for e in source:
		if q == "" or q in e["headword"] or q in e["reading"] or kana_q in e["reading"] or q in String(e["english"]).to_lower():
			out.append(e)
	return out


## [param n] random vocab entries different from [param exclude_id].
func random_words(n: int, exclude_id: String = "", pool: Array = []) -> Array[Dictionary]:
	var source: Array = pool if not pool.is_empty() else vocab
	var filtered := source.filter(func(e: Dictionary) -> bool: return e["id"] != exclude_id)
	filtered.shuffle()
	var out: Array[Dictionary] = []
	for i in mini(n, filtered.size()):
		out.append(filtered[i])
	return out


# ---------------------------------------------------------------- loading

func _content_files() -> PackedStringArray:
	var files := DirAccess.get_files_at(CONTENT_DIR)
	var out := PackedStringArray()
	for f in files:
		# Exported builds may list remapped names; only plain .json files are content.
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out


static func _parse_name(file: String) -> Dictionary:
	var base := file.get_basename()
	var parts := base.split("_")
	if parts.size() < 2 or parts[0] not in KINDS or parts[1] not in STAGE_KEYS.values():
		return {}
	return {"kind": parts[0], "stage": parts[1]}


func _merged(kind: String) -> Array:
	var out: Array = []
	for stage_key: String in STAGE_KEYS.values():
		out.append_array(_by_stage[stage_key][kind])
	return out


func _load_json(path: String, fallback: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("ContentDB: missing %s" % path)
		return fallback
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("ContentDB: invalid JSON in %s" % path)
		return fallback
	return parsed
