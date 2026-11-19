extends Control
## Tela de resultado do caso. O resultado é preenchido por investigation.gd
## (variável estática `resultado`) antes de trocar para esta cena.
## Sequência: motivo, revisão das pistas da solução (em ordem), culpado e motivo correto.
## O texto aparece digitado; "Pular" mostra tudo de uma vez.

const CaseQueries = preload("res://scripts/core/case_queries.gd")

static var resultado: Dictionary = {}

const INTERVALO_ENTRE_LINHAS := 0.3
const VELOCIDADE_DIGITACAO := 0.025  # segundos por caractere

var _tween: Tween
var _textos: Array[Label] = []  # labels digitadas, na ordem de exibição
var _botao_pular: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var solvido := bool(resultado.get("solved", false))
	var vazio := resultado.is_empty()

	var fundo := ColorRect.new()
	fundo.color = Color(0.16, 0.12, 0.04) if solvido else Color(0.16, 0.16, 0.17)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rolagem)

	var centro := CenterContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size = Vector2(640, 0)
	caixa.add_theme_constant_override("separation", 18)
	centro.add_child(caixa)

	var cor_texto := Color(0.96, 0.92, 0.8) if solvido else Color(0.88, 0.88, 0.88)
	var cor_secundaria := Color(0.75, 0.7, 0.55) if solvido else Color(0.65, 0.65, 0.65)

	# Título e motivo
	var titulo := _rotulo("", 40, cor_texto, true)
	titulo.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35) if solvido else Color(0.8, 0.8, 0.8))
	caixa.add_child(titulo)

	if vazio:
		titulo.text = "Nenhum resultado registrado"
		_mostrar_sem_animacao(titulo)
	else:
		titulo.text = "Caso resolvido!" if solvido else "Caso não resolvido"
		var caso_titulo := str(resultado.get("caso", ""))
		if caso_titulo != "":
			caixa.add_child(_rotulo(caso_titulo, 16, cor_secundaria, false))
		var motivo_texto := str(resultado.get("motivo", ""))
		var acusado := str(resultado.get("acusado", ""))
		if acusado != "":
			motivo_texto += "\nAcusado: %s." % acusado
		caixa.add_child(_digitavel(motivo_texto, 20, cor_texto))

		var caso: Dictionary = CaseManager.current_case
		if not caso.is_empty():
			_montar_revisao(caixa, caso, cor_texto, cor_secundaria)

	var rodape := HBoxContainer.new()
	rodape.alignment = BoxContainer.ALIGNMENT_CENTER
	rodape.add_theme_constant_override("separation", 16)
	caixa.add_child(rodape)

	_botao_pular = Button.new()
	_botao_pular.text = "Pular"
	_botao_pular.custom_minimum_size = Vector2(160, 52)
	_botao_pular.pressed.connect(_pular)
	rodape.add_child(_botao_pular)

	var botao := Button.new()
	botao.text = "Voltar aos casos"
	botao.custom_minimum_size = Vector2(260, 52)
	botao.pressed.connect(func() -> void: GameState.go_to("case_select"))
	rodape.add_child(botao)

	_iniciar_sequencia()


## Revisão: pistas da solução em ordem, culpado e motivo correto.
func _montar_revisao(caixa: VBoxContainer, caso: Dictionary, cor_texto: Color, cor_secundaria: Color) -> void:
	var solucao: Dictionary = caso.get("solucao", {})

	caixa.add_child(_rotulo("Revisão das provas", 20, cor_secundaria, false))
	var numero := 1
	for pista_id in solucao.get("pistas_necessarias", []):
		var id := str(pista_id)
		var descricao := CaseQueries.texto(CaseQueries.pista(caso, id).get("descricao", id))
		var encontrada := id in CaseManager.found_clues
		var situacao := "encontrada" if encontrada else "não encontrada"
		var cor := cor_texto if encontrada else cor_secundaria
		caixa.add_child(_digitavel("%d. %s (%s)" % [numero, descricao, situacao], 16, cor))
		numero += 1

	var culpado_id := CaseQueries.texto(solucao.get("culpado", ""))
	var culpado := CaseQueries.pessoa(caso, culpado_id)
	var nome := CaseQueries.texto(culpado.get("nome", culpado_id))
	caixa.add_child(_rotulo("Culpado", 20, cor_secundaria, false))
	caixa.add_child(_digitavel(nome, 26, Color(0.95, 0.8, 0.35) if resultado.get("solved", false) else cor_texto))
	var motivo_correto := CaseQueries.texto(solucao.get("motivo_correto", ""))
	if motivo_correto != "":
		caixa.add_child(_digitavel(motivo_correto, 18, cor_texto))


func _rotulo(texto: String, tamanho: int, cor: Color, centralizado: bool) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centralizado:
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return rotulo


## Label que é digitada na sequência (visible_characters animado) e começa escondida.
func _digitavel(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := _rotulo(texto, tamanho, cor, false)
	rotulo.visible_characters = 0
	_textos.append(rotulo)
	return rotulo


func _mostrar_sem_animacao(rotulo: Label) -> void:
	rotulo.visible_characters = -1


func _iniciar_sequencia() -> void:
	if _textos.is_empty():
		_botao_pular.visible = false
		return
	_tween = create_tween()
	for rotulo in _textos:
		var total := rotulo.text.length()
		var duracao := maxf(0.2, total * VELOCIDADE_DIGITACAO)
		_tween.tween_property(rotulo, "visible_characters", total, duracao).from(0)
		_tween.tween_interval(INTERVALO_ENTRE_LINHAS)
	_tween.finished.connect(_terminar_sequencia)


func _pular() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_terminar_sequencia()


func _terminar_sequencia() -> void:
	for rotulo in _textos:
		rotulo.visible_characters = -1
	_botao_pular.visible = false
