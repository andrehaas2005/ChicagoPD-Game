extends Control
## Mapa simplificado do caso: um botão por local, na posição posicao_mapa. Escolher um local
## gasta o tempo de viagem (GameClock) e emite location_chosen. A delegacia não tem custo.

signal location_chosen(location_id: String)

const CaseQueries = preload("res://scripts/core/case_queries.gd")
const TAMANHO_AREA := Vector2(700, 400)
const TAMANHO_BOTAO := Vector2(210, 56)

var _caso: Dictionary = {}
var _atual := ""
var _cabecalho: Label
var _marcadores: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_to_group("modal")  # o detetive não anda com o mapa aberto

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var caixa := PanelContainer.new()
	caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caixa.offset_left = 260
	caixa.offset_right = -260
	caixa.offset_top = 70
	caixa.offset_bottom = -70
	add_child(caixa)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	caixa.add_child(coluna)

	_cabecalho = Label.new()
	_cabecalho.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cabecalho.add_theme_font_size_override("font_size", 22)
	coluna.add_child(_cabecalho)

	var area := Control.new()
	area.custom_minimum_size = TAMANHO_AREA
	area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	coluna.add_child(area)

	var fundo_mapa := ColorRect.new()
	fundo_mapa.color = Color("#1b2028")
	fundo_mapa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(fundo_mapa)

	_marcadores = Control.new()
	_marcadores.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(_marcadores)

	var fechar := Button.new()
	fechar.text = "Fechar"
	fechar.custom_minimum_size = Vector2(200, 44)
	fechar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fechar.pressed.connect(fechar_mapa)
	coluna.add_child(fechar)


## Mostra o mapa do caso. local_atual não pode ser escolhido (já está lá).
func abrir(caso: Dictionary, local_atual: String) -> void:
	_caso = caso
	_atual = local_atual
	_cabecalho.text = "Mapa de Chicago · %s" % GameClock.format_now()
	for filho in _marcadores.get_children():
		_marcadores.remove_child(filho)
		filho.queue_free()
	var locais := CaseState.locais_visiveis()
	var centros: Array[Vector2] = []
	for local in locais:
		centros.append(_posicao_mapa(local.get("posicao_mapa", null)))
	_separar_marcadores(centros)
	for i in locais.size():
		_marcadores.add_child(_criar_marcador(locais[i], centros[i]))
	visible = true


func fechar_mapa() -> void:
	visible = false


func _criar_marcador(local: Dictionary, centro: Vector2) -> Button:
	var local_id := CaseQueries.texto(local.get("id", ""))
	var custo := CaseQueries.custo_viagem(_caso, local_id)
	var texto_custo := "sem viagem" if custo == 0 else "%d min" % custo

	var linhas := ["%s" % CaseQueries.texto(local.get("nome", local_id)), texto_custo]
	for loc in CaseState.localizacoes_ativas():
		if str(loc["local"]) == local_id:
			var pessoa := CaseQueries.pessoa(_caso, str(loc["person_id"]))
			linhas.append("● %s aqui até %s" % [CaseQueries.texto(pessoa.get("nome", "?")), GameClock.format_at(int(loc["ate_minutos"]))])

	var botao := Button.new()
	botao.text = "\n".join(linhas)
	botao.size = TAMANHO_BOTAO + Vector2(0, 16 * (linhas.size() - 2))
	var canto := centro - TAMANHO_BOTAO / 2.0
	botao.position = Vector2(
		clampf(canto.x, 0.0, TAMANHO_AREA.x - TAMANHO_BOTAO.x),
		clampf(canto.y, 0.0, TAMANHO_AREA.y - TAMANHO_BOTAO.y))
	botao.disabled = local_id == _atual
	botao.pressed.connect(_escolher.bind(local_id))
	return botao


func _escolher(local_id: String) -> void:
	visible = false
	if local_id != _atual:
		GameClock.advance_minutes(CaseQueries.custo_viagem(_caso, local_id))
	location_chosen.emit(local_id)


## Afasta os centros que se sobrepõem, para que os botões nunca fiquem um em cima do outro.
## Os centros ficam dentro da área do mapa. Os dados do caso não são alterados.
func _separar_marcadores(centros: Array[Vector2]) -> void:
	var meia := TAMANHO_BOTAO / 2.0 + Vector2(10, 10)
	var minimo := meia
	var maximo := TAMANHO_AREA - meia
	for _rodada in 100:
		var houve_sobreposicao := false
		for i in centros.size():
			for j in range(i + 1, centros.size()):
				var delta := centros[j] - centros[i]
				var folga := Vector2(meia.x * 2.0 - absf(delta.x), meia.y * 2.0 - absf(delta.y))
				if folga.x <= 0.0 or folga.y <= 0.0:
					continue
				houve_sobreposicao = true
				# Empurra no eixo de menor folga, para separar com o menor deslocamento
				var sentido := Vector2(1, 1)
				if delta.x < 0.0:
					sentido.x = -1.0
				if delta.y < 0.0:
					sentido.y = -1.0
				if folga.x <= folga.y:
					centros[i].x -= sentido.x * folga.x / 2.0
					centros[j].x += sentido.x * folga.x / 2.0
				else:
					centros[i].y -= sentido.y * folga.y / 2.0
					centros[j].y += sentido.y * folga.y / 2.0
		for i in centros.size():
			centros[i] = centros[i].clamp(minimo, maximo)
		if not houve_sobreposicao:
			break


func _posicao_mapa(valor: Variant) -> Vector2:
	if valor is Array and valor.size() == 2:
		return Vector2(float(valor[0]) * TAMANHO_AREA.x, float(valor[1]) * TAMANHO_AREA.y)
	return TAMANHO_AREA / 2.0
