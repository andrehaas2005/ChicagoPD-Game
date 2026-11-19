extends Node
## Autoload: carrega e lista os casos a partir de arquivos JSON em res://data/cases/.
## Formato dos casos em docs/CONTRATOS.md.

const CASES_DIR := "res://data/cases"

signal case_loaded(case_data: Dictionary)
signal clue_found(clue_id: String)

var current_case: Dictionary = {}
var found_clues: Array[String] = []


## Carrega um caso e o define como caso atual.
func load_case(path: String) -> bool:
	var data := _read_json(path)
	if data.is_empty():
		return false
	current_case = data
	found_clues.clear()
	case_loaded.emit(current_case)
	return true


## Lê um caso sem alterar o caso atual. Retorna {} se não existir.
func get_case(case_id: String) -> Dictionary:
	return _read_json("%s/%s.json" % [CASES_DIR, case_id])


## IDs de todos os casos, ordenados pelo campo "ordem".
func list_case_ids() -> Array[String]:
	var entries: Array[Dictionary] = []
	var dir := DirAccess.open(CASES_DIR)
	if dir == null:
		push_error("Pasta de casos não encontrada: %s" % CASES_DIR)
		return []
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var data := _read_json("%s/%s" % [CASES_DIR, file_name])
		if not data.is_empty():
			entries.append({"id": data.get("id", file_name.get_basename()), "ordem": int(data.get("ordem", 0))})
	entries.sort_custom(func(a, b): return a["ordem"] < b["ordem"])

	var ids: Array[String] = []
	for entry in entries:
		ids.append(entry["id"])
	return ids


## Registra uma pista como encontrada. Ignora se já tiver sido registrada.
func mark_clue_found(clue_id: String) -> void:
	if clue_id in found_clues:
		return
	found_clues.append(clue_id)
	clue_found.emit(clue_id)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Arquivo não encontrado: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON inválido em: %s" % path)
		return {}
	return parsed
