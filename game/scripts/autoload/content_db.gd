extends Node
## Autoload "ContentDB": loads every content JSON once at startup and exposes typed lookups.
## Content is read-only; player state lives in the Progress autoload.

const CONTENT_DIR := "res://content/"

var kana: Dictionary = {}                 # {"hiragana": [...], "katakana": [...]}
var vocab: Array[Dictionary] = []         # vocab_n5.json entries
var grammar: Array[Dictionary] = []
var sentences: Array[Dictionary] = []
var scenarios: Array[Dictionary] = []

var _vocab_by_id: Dictionary = {}
var _vocab_by_headword: Dictionary = {}
var _grammar_by_id: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	kana = _load_json("kana.json", {})
	vocab.assign(_load_json("vocab_n5.json", []))
	grammar.assign(_load_json("grammar_n5.json", []))
	sentences.assign(_load_json("sentences_n5.json", []))
	scenarios.assign(_load_json("scenarios_n5.json", []))
	_vocab_by_id.clear()
	_vocab_by_headword.clear()
	for entry in vocab:
		_vocab_by_id[entry["id"]] = entry
		_vocab_by_headword[entry["headword"]] = entry
	for g in grammar:
		_grammar_by_id[g["id"]] = g


func word(id: String) -> Dictionary:
	return _vocab_by_id.get(id, {})


func word_by_headword(headword: String) -> Dictionary:
	return _vocab_by_headword.get(headword, {})


func grammar_point(id: String) -> Dictionary:
	return _grammar_by_id.get(id, {})


## Case-insensitive substring search over headword, reading and English gloss.
func search_vocab(query: String) -> Array[Dictionary]:
	var q := query.strip_edges().to_lower()
	if q == "":
		return vocab.duplicate()
	var out: Array[Dictionary] = []
	for entry in vocab:
		if q in entry["headword"] or q in entry["reading"] or q in String(entry["english"]).to_lower():
			out.append(entry)
	return out


## [param n] random vocab entries different from [param exclude_id].
func random_words(n: int, exclude_id: String = "") -> Array[Dictionary]:
	var pool := vocab.filter(func(e: Dictionary) -> bool: return e["id"] != exclude_id)
	pool.shuffle()
	var out: Array[Dictionary] = []
	for i in mini(n, pool.size()):
		out.append(pool[i])
	return out


func _load_json(file: String, fallback: Variant) -> Variant:
	var path := CONTENT_DIR + file
	if not FileAccess.file_exists(path):
		push_error("ContentDB: missing %s" % path)
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("ContentDB: invalid JSON in %s" % path)
		return fallback
	return parsed
