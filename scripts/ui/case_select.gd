extends Control
## Seleção de caso: um card por caso, com selos de crossover e de resolvido.
## Interface construída por código.

const COR_FUNDO := Color("#14171c")
const COR_CARD := Color("#1f242c")
const COR_DESTAQUE := Color("#e8c15a")
const COR_CROSSOVER := Color("#3a5a7a")
const COR_RESOLVIDO := Color("#2e6b4f")
const COR_ERRO := Color("#e06c6c")

var _aviso: Label


func _ready() -> void:
	if not GameState.has_player():
		GameState.go_to("character_select")
		return
	_construir_interface()


func _construir_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(PRESET_FULL_RECT)
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margem.add_theme_constant_override(lado, 16)
	add_child(margem)

	var principal := VBoxContainer.new()
	principal.add_theme_constant_override("separation", 12)
	margem.add_child(principal)

	# Topo: voltar, título e nome do detetive
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 16)
	principal.add_child(topo)

	var voltar := Button.new()
	voltar.text = "Voltar"
	voltar.custom_minimum_size = Vector2(120, 40)
	voltar.pressed.connect(_on_voltar)
	topo.add_child(voltar)

	var titulo := Label.new()
	titulo.text = "Seleção de caso"
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", COR_DESTAQUE)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(titulo)

	var detetive := Label.new()
	detetive.text = "Detetive: %s" % str(GameState.player.get("nome", ""))
	detetive.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(detetive)

	_aviso = Label.new()
	_aviso.add_theme_color_override("font_color", COR_ERRO)
	_aviso.visible = false
	principal.add_child(_aviso)

	# Lista de casos
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	principal.add_child(rolagem)

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 12)
	rolagem.add_child(lista)

	var ids := CaseManager.list_case_ids()
	if ids.is_empty():
		var vazio := Label.new()
		vazio.text = "Nenhum caso disponível."
		lista.add_child(vazio)
	for case_id in ids:
		lista.add_child(_criar_card_caso(case_id))


func _criar_card_caso(case_id: String) -> Control:
	var caso := CaseManager.get_case(case_id)
	var painel := _criar_painel()
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 16)
	painel.add_child(linha)

	var texto := VBoxContainer.new()
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.add_theme_constant_override("separation", 6)
	linha.add_child(texto)

	var cabecalho := HBoxContainer.new()
	cabecalho.add_theme_constant_override("separation", 8)
	texto.add_child(cabecalho)

	var titulo := Label.new()
	titulo.text = str(caso.get("titulo", case_id))
	titulo.add_theme_font_size_override("font_size", 22)
	cabecalho.add_child(titulo)

	if case_id in GameState.solved_cases:
		cabecalho.add_child(_criar_selo("Resolvido", COR_RESOLVIDO))

	var crossover: Variant = caso.get("crossover")
	if typeof(crossover) == TYPE_STRING and not String(crossover).is_empty():
		cabecalho.add_child(_criar_selo("Crossover: %s" % String(crossover), COR_CROSSOVER))

	var local := Label.new()
	local.text = "Local: %s" % str(caso.get("local", ""))
	local.add_theme_color_override("font_color", COR_DESTAQUE)
	texto.add_child(local)

	var resumo := Label.new()
	resumo.text = str(caso.get("resumo", ""))
	resumo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resumo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.add_child(resumo)

	var jogar := Button.new()
	jogar.text = "Jogar"
	jogar.custom_minimum_size = Vector2(140, 44)
	jogar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	jogar.pressed.connect(_on_jogar.bind(case_id))
	linha.add_child(jogar)
	return painel


func _criar_selo(texto: String, cor: Color) -> PanelContainer:
	var selo := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_corner_radius_all(6)
	estilo.set_content_margin_all(4)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	selo.add_theme_stylebox_override("panel", estilo)

	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", 14)
	selo.add_child(rotulo)
	return selo


func _criar_painel() -> PanelContainer:
	var painel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_CARD
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(16)
	painel.add_theme_stylebox_override("panel", estilo)
	return painel


func _on_jogar(case_id: String) -> void:
	if not GameState.start_case(case_id):
		_aviso.text = "Não foi possível carregar o caso %s." % case_id
		_aviso.visible = true
		return
	GameState.go_to("investigation")


func _on_voltar() -> void:
	GameState.go_to("menu")
