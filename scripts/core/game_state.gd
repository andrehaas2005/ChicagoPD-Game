extends Node
## Autoload: estado geral da partida (detetive do jogador, caso atual, casos resolvidos)
## e troca de cenas. Formato em docs/CONTRATOS.md.

const SCENES := {
	"menu": "res://scenes/menu.tscn",
	"character_select": "res://scenes/character_select.tscn",
	"case_select": "res://scenes/case_select.tscn",
	"investigation": "res://scenes/investigation.tscn",
	"result": "res://scenes/result.tscn",
}

signal case_finished(case_id: String, solved: bool)

const DURACAO_TRANSICAO := 0.4  # segundos de fade preto antes e depois da troca de cena

var player: Dictionary = {}
var current_case_id := ""
var solved_cases: Array[String] = []

var _camada_transicao: CanvasLayer
var _veu: ColorRect
var _trocando := false


func _ready() -> void:
	# Camada persistente (autoload), acima de qualquer cena, usada só para o fade preto.
	_camada_transicao = CanvasLayer.new()
	_camada_transicao.layer = 128
	add_child(_camada_transicao)
	_veu = ColorRect.new()
	_veu.color = Color.BLACK
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veu.visible = false
	_veu.modulate.a = 0.0
	_camada_transicao.add_child(_veu)


func set_player(data: Dictionary) -> void:
	player = data.duplicate()


func has_player() -> bool:
	return not player.is_empty()


## Define o caso atual e carrega seus dados. Retorna false se o caso não existir.
func start_case(case_id: String) -> bool:
	current_case_id = case_id
	return CaseManager.load_case("%s/%s.json" % [CaseManager.CASES_DIR, case_id])


## Registra o resultado do caso atual.
func finish_case(solved: bool) -> void:
	if solved and current_case_id not in solved_cases:
		solved_cases.append(current_case_id)
	case_finished.emit(current_case_id, solved)


## Troca de cena com fade preto: escurece, troca, espera o frame em que a nova cena entra e clareia.
## Chamadas feitas durante uma troca são ignoradas. Não precisa de await.
func go_to(scene_key: String) -> void:
	if not SCENES.has(scene_key):
		push_error("Cena desconhecida: %s" % scene_key)
		return
	if _trocando:
		return
	_trocando = true
	await _fade(1.0)
	get_tree().change_scene_to_file(SCENES[scene_key])
	# change_scene_to_file troca a cena no fim do frame; só depois disso o fade pode clarear.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade(0.0)
	_trocando = false


func _fade(alpha_final: float) -> void:
	_veu.visible = true
	_veu.mouse_filter = Control.MOUSE_FILTER_STOP if alpha_final > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_veu, "modulate:a", alpha_final, DURACAO_TRANSICAO)
	await tween.finished
	if alpha_final <= 0.0:
		_veu.visible = false
