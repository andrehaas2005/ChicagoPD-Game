extends Node
## Autoload: lista e busca personagens em res://data/characters/.
## Formato em docs/CONTRATOS.md.

const CHARACTERS_DIR := "res://data/characters"


## Todos os personagens, ordenados por franquia e nome.
func list_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(CHARACTERS_DIR)
	if dir == null:
		push_error("Pasta de personagens não encontrada: %s" % CHARACTERS_DIR)
		return result
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var data := _read_json("%s/%s" % [CHARACTERS_DIR, file_name])
		if not data.is_empty():
			result.append(data)
	result.sort_custom(func(a, b): return str(a.get("franquia", "")) + str(a.get("nome", "")) < str(b.get("franquia", "")) + str(b.get("nome", "")))
	return result


## Personagem pelo ID, ou {} se não existir.
func get_character(character_id: String) -> Dictionary:
	return _read_json("%s/%s.json" % [CHARACTERS_DIR, character_id])


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON inválido em: %s" % path)
		return {}
	return parsed
