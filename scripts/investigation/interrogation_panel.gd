class_name InterrogationPanel
extends Control
## Painel modal de interrogatório de um suspeito ou testemunha (formato v2), com visual noir.
## As respostas vêm de SuspectBrain. Cada pergunta feita gasta 30 minutos do relógio (GameClock).
## Habilidades do detetive (GameState.player["habilidades"], valores de 1 a 3), aplicadas no painel:
## - empatia 3: uma pergunta empática não alivia a pressão (o alívio é anulado);
## - lábia 3: uma pergunta agressiva pesa +1 de pressão extra;
## - lábia 1: uma pergunta agressiva faz o suspeito se fechar (a pressão não sobe).
## - observação 3: mostra uma dica extra sobre a pergunta selecionada.
## Não captura o mouse fora do painel. Fecha com o botão "Encerrar interrogatório" ou com Esc.

signal closed(subject_id: String, summary: Dictionary)

const MINUTOS_POR_PERGUNTA := 30
const HABILIDADES_PADRAO := {"observacao": 2, "empatia": 2, "labia": 2}
const TEXTOS_ATITUDE := {
	"calmo": "Calmo",
	"nervoso": "Nervoso",
	"arrogante": "Arrogante",
	"agressivo": "Agressivo",
}
const DICAS_ATITUDE := {
	"calmo": "Ele parece tranquilo, sem pressa.",
	"nervoso": "Ele mexe nas mãos e evita o seu olhar.",
	"arrogante": "Ele sorri de canto, como se a conversa fosse um favor.",
	"agressivo": "Ele está tenso, pronto para reagir a qualquer pressão.",
}
const COR_DESTAQUE := "#ffcc33"
const COR_ALERTA := "#ff6655"
const ALTURA_BARRA := 64
const ALTURA_LEGENDA := 100
const ESPACO_INFERIOR := ALTURA_BARRA + 24

var _subject: Dictionary = {}
var _provas_disponiveis: Array[String] = []
var _brain: SuspectBrain = null
var _pistas_reveladas: Array[String] = []
var _perguntas_por_id: Dictionary = {}
var _pergunta_selecionada := ""
var _fechou_na_ultima := false
var _construido := false
var _tween_legenda: Tween = null
var _tween_foco: Tween = null

var _titulo_label: Label
var _nome_label: Label
var _atitude_label: Label
var _reacao_label: Label
var _tensao_bar: ProgressBar
var _tensao_texto_label: Label
var _habilidades_label: Label
var _retrato_detetive: PanelContainer
var _retrato_suspeito: PanelContainer
var _inicial_detetive: Label
var _nome_detetive: Label
var _inicial_suspeito: Label
var _nome_suspeito: Label
var _lista_perguntas: VBoxContainer
var _grupo: ButtonGroup
var _botoes: Dictionary = {}  # id da pergunta -> Button
var _selecionada_label: Label
var _perguntar_botao: Button
var _prova_option: OptionButton
var _apresentar_botao: Button
var _sem_provas_label: Label
var _transcricao: RichTextLabel
var _legenda_falante: Label
var _legenda_texto: Label


## Define o suspeito ou testemunha (formato v2) e as provas que o jogador pode apresentar.
func setup(subject: Dictionary, available_clue_ids: Array[String]) -> void:
	_subject = subject.duplicate(true)
	_provas_disponiveis = available_clue_ids.duplicate()
	_brain = SuspectBrain.new(_subject)
	_pistas_reveladas.clear()
	_pergunta_selecionada = ""
	if _construido:
		_preencher()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_construir()
	_construido = true
	_preencher()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_encerrar()
		get_viewport().set_input_as_handled()


# ---------- Montagem da interface ----------

func _construir() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.035, 0.04, 0.05, 0.94)
	fundo.mouse_filter = MOUSE_FILTER_IGNORE
	fundo.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(fundo)

	# Vinheta: escurece as bordas com um gradiente radial.
	var vinheta := TextureRect.new()
	vinheta.texture = _textura_vinheta()
	vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	vinheta.mouse_filter = MOUSE_FILTER_IGNORE
	vinheta.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(vinheta)

	var margem := MarginContainer.new()
	margem.mouse_filter = MOUSE_FILTER_IGNORE
	margem.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_left", 32)
	margem.add_theme_constant_override("margin_right", 32)
	margem.add_theme_constant_override("margin_top", ALTURA_BARRA + 20)
	margem.add_theme_constant_override("margin_bottom", ESPACO_INFERIOR)
	add_child(margem)

	var raiz := VBoxContainer.new()
	raiz.mouse_filter = MOUSE_FILTER_IGNORE
	raiz.add_theme_constant_override("separation", 14)
	margem.add_child(raiz)

	raiz.add_child(_construir_cabecalho())
	raiz.add_child(HSeparator.new())

	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 24)
	raiz.add_child(corpo)
	corpo.add_child(_construir_coluna_perguntas())
	corpo.add_child(_construir_centro())

	# Letterbox (cinemascope) e legenda ficam por cima do conteúdo, sem bloquear o mouse.
	add_child(_construir_barra_superior())
	add_child(_construir_barra_inferior())


func _construir_barra_superior() -> Control:
	var barra := Control.new()
	barra.anchor_left = 0.0
	barra.anchor_right = 1.0
	barra.anchor_top = 0.0
	barra.anchor_bottom = 0.0
	barra.offset_bottom = ALTURA_BARRA
	barra.mouse_filter = MOUSE_FILTER_IGNORE
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.mouse_filter = MOUSE_FILTER_IGNORE
	fundo.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	barra.add_child(fundo)
	var titulo := _rotulo("INTERROGATÓRIO", 13, Color(0.6, 0.6, 0.62))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.mouse_filter = MOUSE_FILTER_IGNORE
	titulo.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	barra.add_child(titulo)
	return barra


func _construir_barra_inferior() -> Control:
	var barra := Control.new()
	barra.anchor_left = 0.0
	barra.anchor_right = 1.0
	barra.anchor_top = 1.0
	barra.anchor_bottom = 1.0
	barra.offset_top = -ALTURA_BARRA
	barra.offset_bottom = 0.0
	barra.mouse_filter = MOUSE_FILTER_IGNORE
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.mouse_filter = MOUSE_FILTER_IGNORE
	fundo.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	barra.add_child(fundo)
	var caixa := HBoxContainer.new()
	caixa.mouse_filter = MOUSE_FILTER_IGNORE
	caixa.alignment = BoxContainer.ALIGNMENT_END
	caixa.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	caixa.offset_left = 32.0
	caixa.offset_right = -32.0
	caixa.offset_top = 12.0
	caixa.offset_bottom = -12.0
	var encerrar := Button.new()
	encerrar.text = "Encerrar interrogatório"
	encerrar.pressed.connect(_encerrar)
	caixa.add_child(encerrar)
	barra.add_child(caixa)
	return barra


func _construir_legenda() -> Control:
	var caixa_legenda := PanelContainer.new()
	caixa_legenda.custom_minimum_size = Vector2(0, ALTURA_LEGENDA)
	caixa_legenda.mouse_filter = MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	estilo.content_margin_left = 28.0
	estilo.content_margin_right = 28.0
	estilo.content_margin_top = 14.0
	estilo.content_margin_bottom = 14.0
	caixa_legenda.add_theme_stylebox_override("panel", estilo)

	var linhas := VBoxContainer.new()
	linhas.mouse_filter = MOUSE_FILTER_IGNORE
	linhas.add_theme_constant_override("separation", 6)
	_legenda_falante = _rotulo("", 15, Color(1.0, 0.8, 0.2))
	_legenda_texto = _rotulo("", 24, Color(0.95, 0.93, 0.86))
	_legenda_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legenda_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linhas.add_child(_legenda_falante)
	linhas.add_child(_legenda_texto)
	caixa_legenda.add_child(linhas)
	return caixa_legenda


func _construir_cabecalho() -> Control:
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 28)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo_label = _rotulo("", 14, Color(0.7, 0.68, 0.6))
	_nome_label = _rotulo("", 26, Color(0.95, 0.93, 0.86))
	_atitude_label = _rotulo("", 16, Color(0.85, 0.83, 0.76))
	_habilidades_label = _rotulo("", 13, Color(0.7, 0.68, 0.6))
	_reacao_label = _rotulo("", 18, Color(0.85, 0.83, 0.76))
	textos.add_child(_titulo_label)
	textos.add_child(_nome_label)
	textos.add_child(_atitude_label)
	textos.add_child(_reacao_label)
	textos.add_child(_habilidades_label)
	caixa.add_child(textos)

	var tensao := VBoxContainer.new()
	tensao.custom_minimum_size.x = 340
	var tensao_titulo := _rotulo("Pressão", 13, Color(0.7, 0.68, 0.6))
	_tensao_bar = ProgressBar.new()
	_tensao_bar.min_value = 0
	_tensao_bar.max_value = 1
	_tensao_bar.step = 1
	_tensao_bar.show_percentage = false
	_tensao_bar.custom_minimum_size.y = 22
	_tensao_texto_label = _rotulo("", 13, Color(0.7, 0.68, 0.6))
	tensao.add_child(tensao_titulo)
	tensao.add_child(_tensao_bar)
	tensao.add_child(_tensao_texto_label)
	caixa.add_child(tensao)
	return caixa


func _construir_coluna_perguntas() -> Control:
	var coluna := VBoxContainer.new()
	coluna.custom_minimum_size.x = 440
	coluna.add_theme_constant_override("separation", 6)

	coluna.add_child(_rotulo("Perguntas", 15, Color(0.85, 0.83, 0.76)))

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.custom_minimum_size = Vector2(0, 110)  # sem altura mínima a lista de perguntas some
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)

	_lista_perguntas = VBoxContainer.new()
	_lista_perguntas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_perguntas.add_theme_constant_override("separation", 6)
	rolagem.add_child(_lista_perguntas)

	_selecionada_label = _rotulo("", 14, Color(0.85, 0.83, 0.76))
	_selecionada_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_selecionada_label)

	_perguntar_botao = Button.new()
	_perguntar_botao.text = "Fazer pergunta selecionada"
	_perguntar_botao.pressed.connect(_on_perguntar_pressed)
	coluna.add_child(_perguntar_botao)

	coluna.add_child(_rotulo("Apresentar prova:", 14, Color(0.85, 0.83, 0.76)))

	_prova_option = OptionButton.new()
	_prova_option.clip_text = true
	_prova_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_child(_prova_option)

	_apresentar_botao = Button.new()
	_apresentar_botao.text = "Apresentar prova à pergunta selecionada"
	_apresentar_botao.pressed.connect(_on_apresentar_pressed)
	coluna.add_child(_apresentar_botao)

	var dica := _rotulo("A prova só tem efeito sobre a pergunta selecionada.", 13, Color(0.6, 0.6, 0.62))
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(dica)

	_sem_provas_label = _rotulo("Você não tem provas para apresentar.", 13, Color(0.6, 0.6, 0.62))
	coluna.add_child(_sem_provas_label)
	return coluna


## Coluna central: os dois retratos (plano e contraplano) em cima e o registro da conversa embaixo.
func _construir_centro() -> Control:
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 12)

	var retratos := HBoxContainer.new()
	retratos.alignment = BoxContainer.ALIGNMENT_CENTER
	retratos.add_theme_constant_override("separation", 40)
	_retrato_detetive = _construir_retrato(Color(0.14, 0.19, 0.27), true)
	_retrato_suspeito = _construir_retrato(Color(0.3, 0.14, 0.12), false)
	retratos.add_child(_retrato_detetive)
	retratos.add_child(_retrato_suspeito)
	coluna.add_child(retratos)

	coluna.add_child(_construir_transcricao())
	return coluna


## Retrato simples: bloco colorido com a inicial grande e o nome. Escurece quando não está em foco.
func _construir_retrato(cor: Color, eh_detetive: bool) -> PanelContainer:
	var retrato := PanelContainer.new()
	retrato.mouse_filter = MOUSE_FILTER_IGNORE
	retrato.custom_minimum_size = Vector2(190, 110)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.set_border_width_all(2)
	estilo.border_color = Color(0.75, 0.68, 0.5, 0.55)
	retrato.add_theme_stylebox_override("panel", estilo)

	var caixa := VBoxContainer.new()
	caixa.mouse_filter = MOUSE_FILTER_IGNORE
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	var inicial := _rotulo("?", 40, Color(0.95, 0.93, 0.86))
	inicial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nome := _rotulo("", 13, Color(0.8, 0.78, 0.7))
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(inicial)
	caixa.add_child(nome)
	retrato.add_child(caixa)
	# Guarda as referências para atualizar o texto depois.
	if eh_detetive:
		_inicial_detetive = inicial
		_nome_detetive = nome
	else:
		_inicial_suspeito = inicial
		_nome_suspeito = nome
	return retrato


func _construir_transcricao() -> Control:
	var painel := PanelContainer.new()
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	painel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_transcricao = RichTextLabel.new()
	_transcricao.bbcode_enabled = true
	_transcricao.scroll_following = true
	_transcricao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_transcricao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var caixa := VBoxContainer.new()
	caixa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caixa.add_theme_constant_override("separation", 8)
	caixa.add_child(_transcricao)
	caixa.add_child(_construir_legenda())
	painel.add_child(caixa)
	return painel


# ---------- Preenchimento com os dados do suspeito ----------

func _preencher() -> void:
	if _brain == null:
		return
	var nome := str(_subject.get("nome", ""))
	var eh_testemunha := str(_subject.get("tipo", "")) == "testemunha"
	_titulo_label.text = "Testemunha" if eh_testemunha else "Suspeito"
	_nome_label.text = nome
	var atitude := str(_subject.get("atitude", "calmo"))
	_atitude_label.text = "Atitude: %s" % str(TEXTOS_ATITUDE.get(atitude, "Calmo"))
	_habilidades_label.text = _texto_habilidades()

	var nome_detetive := str(GameState.player.get("nome", "Detetive"))
	_inicial_detetive.text = _inicial(nome_detetive)
	_nome_detetive.text = "DETETIVE"
	_inicial_suspeito.text = _inicial(nome)
	_nome_suspeito.text = nome.to_upper()

	_pergunta_selecionada = ""
	_fechou_na_ultima = false
	for filho in _lista_perguntas.get_children():
		_lista_perguntas.remove_child(filho)
		filho.queue_free()
	_botoes.clear()
	_perguntas_por_id.clear()
	_grupo = ButtonGroup.new()
	for pergunta in _brain.todas_perguntas():
		var pergunta_id := str(pergunta.get("id", ""))
		_perguntas_por_id[pergunta_id] = pergunta
		var botao := Button.new()
		botao.text = str(pergunta.get("pergunta", pergunta_id))
		botao.toggle_mode = true
		botao.button_group = _grupo
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		botao.custom_minimum_size = Vector2(0, 40)
		botao.toggled.connect(_on_pergunta_alternada.bind(pergunta_id))
		botao.disabled = _brain.foi_perguntada(pergunta_id)
		_lista_perguntas.add_child(botao)
		_botoes[pergunta_id] = botao

	_prova_option.clear()
	for prova_id in _provas_disponiveis:
		_prova_option.add_item(_descricao_pista(prova_id))
		_prova_option.set_item_metadata(_prova_option.item_count - 1, prova_id)

	_transcricao.clear()
	_transcricao.append_text("[i]Você senta na frente de %s.[/i]\n" % nome)
	_mostrar_legenda("", "Você senta na frente de %s." % nome)
	_destacar("suspeito")
	_atualizar_estado()


func _atualizar_estado() -> void:
	if _brain == null:
		return
	var tem_selecao := _pergunta_selecionada != ""
	if tem_selecao:
		_selecionada_label.text = _texto_selecao()
	else:
		_selecionada_label.text = "Escolha uma pergunta na lista."
	var tem_prova := _prova_option.item_count > 0
	_perguntar_botao.disabled = not tem_selecao
	_apresentar_botao.disabled = not (tem_selecao and tem_prova)
	_prova_option.disabled = not tem_prova
	_sem_provas_label.visible = not tem_prova
	_atualizar_pressao()


## Barra de pressão (0 até o limiar), texto de reação e contagem.
func _atualizar_pressao() -> void:
	var limiar := maxi(1, _brain.limiar_pressao)
	_tensao_bar.max_value = limiar
	_tensao_bar.value = mini(_brain.pressao, limiar)
	_tensao_texto_label.text = "%d / %d" % [mini(_brain.pressao, limiar), limiar]

	var reacao := "fechado"
	var cor := Color(0.7, 0.68, 0.6)
	if _brain.pressao >= _brain.limiar_pressao:
		reacao = "quebrou"
		cor = Color(COR_ALERTA)
	elif _fechou_na_ultima:
		reacao = "fechado"
	elif _brain.pressao >= 2:
		reacao = "abalado"
		cor = Color(COR_DESTAQUE)
	elif _brain.pressao == 1:
		reacao = "inquieto"
	_reacao_label.text = "Reação: %s" % reacao
	_reacao_label.add_theme_color_override("font_color", cor)


## Texto da pergunta selecionada. Com observação 3, inclui uma dica extra sobre o suspeito.
func _texto_selecao() -> String:
	var texto := "Pergunta selecionada: %s" % str(_botoes[_pergunta_selecionada].text)
	if int(_habilidades()["observacao"]) >= 3:
		var dica := "Observação: %s" % str(DICAS_ATITUDE.get(_brain.atitude, DICAS_ATITUDE["calmo"]))
		var pergunta: Dictionary = _perguntas_por_id.get(_pergunta_selecionada, {})
		if not (pergunta.get("resposta_com_prova", {}) as Dictionary).is_empty() and not _brain.foi_perguntada(_pergunta_selecionada):
			dica += " Alguma prova pode abalar essa resposta."
		texto += "\n%s" % dica
	return texto


# ---------- Ações ----------

func _on_pergunta_alternada(ligada: bool, pergunta_id: String) -> void:
	if ligada:
		_pergunta_selecionada = pergunta_id
	elif _pergunta_selecionada == pergunta_id:
		_pergunta_selecionada = ""
	_atualizar_estado()


func _on_perguntar_pressed() -> void:
	_fazer_pergunta("")


func _on_apresentar_pressed() -> void:
	var indice := _prova_option.selected
	if indice < 0:
		return
	_fazer_pergunta(str(_prova_option.get_item_metadata(indice)))


## Faz a pergunta selecionada, com a prova indicada (ou sem prova se prova_id for "").
func _fazer_pergunta(prova_id: String) -> void:
	if _brain == null or _pergunta_selecionada == "":
		return
	var pergunta_id := _pergunta_selecionada
	if _brain.foi_perguntada(pergunta_id):
		return
	var pergunta: Dictionary = _perguntas_por_id.get(pergunta_id, {})
	var ajuste := _aplicar_habilidades(pergunta)

	_destacar("detetive")
	var resultado := _brain.ask(pergunta_id, prova_id)
	if resultado["ja_perguntada"]:
		return
	GameClock.advance_minutes(MINUTOS_POR_PERGUNTA)

	var botao: Button = _botoes[pergunta_id]
	_transcricao.append_text("\n[b]Você:[/b] %s\n" % botao.text)
	if prova_id != "":
		_transcricao.append_text("[i]Apresenta: %s[/i]\n" % _descricao_pista(prova_id))
	if _fechou_na_ultima:
		_transcricao.append_text("[i]Sua lábia não foi suficiente: ele se fecha.[/i]\n")
	elif ajuste > 0 and int(pergunta.get("pressao", 0)) > 0:
		_transcricao.append_text("[i]Sua lábia faz a pressão pesar mais.[/i]\n")
	elif ajuste > 0:
		_transcricao.append_text("[i]Sua empatia impede que a pergunta gentil alivie a pressão.[/i]\n")

	var resposta := str(resultado["resposta"])
	CaseState.registrar_depoimento(str(_subject.get("id", "")), botao.text, resposta, prova_id)
	_transcricao.append_text("[b]%s:[/b] %s\n" % [str(_subject.get("nome", "")), resposta])
	_mostrar_legenda(str(_subject.get("nome", "")), resposta)
	_destacar("suspeito")

	var pista_id := str(resultado["revela_pista"])
	if pista_id != "":
		CaseManager.mark_clue_found(pista_id)
		if pista_id not in _pistas_reveladas:
			_pistas_reveladas.append(pista_id)
		_transcricao.append_text("[color=%s][b]Nova pista: %s[/b][/color]\n" % [COR_DESTAQUE, _descricao_pista(pista_id)])

	for segredo_id in resultado["revela_segredos"]:
		_transcricao.append_text("[color=%s][b]Segredo revelado: %s[/b][/color]\n" % [COR_DESTAQUE, _brain.descricao_segredo(str(segredo_id))])

	if resultado["alibi_exposto"]:
		_transcricao.append_text("[color=%s][b]Seu álibi não se sustenta.[/b][/color]\n" % COR_ALERTA)

	# A pergunta já foi feita: solta a seleção e desabilita o botão.
	_pergunta_selecionada = ""
	botao.set_pressed_no_signal(false)
	botao.disabled = true
	_atualizar_estado()


## Aplica o efeito das habilidades antes de SuspectBrain.ask. Retorna o ajuste de pressão aplicado.
## Não muda as regras de resposta: só ajusta a pressão inicial da pergunta.
func _aplicar_habilidades(pergunta: Dictionary) -> int:
	var habil := _habilidades()
	var delta := int(pergunta.get("pressao", 0))
	var ajuste := 0
	_fechou_na_ultima = false
	if delta > 0 and int(habil["labia"]) == 1:
		_fechou_na_ultima = true
		ajuste = -1
	elif delta > 0 and int(habil["labia"]) == 3:
		ajuste = 1
	elif delta < 0 and int(habil["empatia"]) == 3:
		ajuste = 1
	if ajuste != 0:
		_brain.pressao = maxi(0, _brain.pressao + ajuste)
	return ajuste


## Habilidades do detetive, de 1 a 3. Usa 2 em tudo se não existir em GameState.player.
func _habilidades() -> Dictionary:
	var dados: Variant = GameState.player.get("habilidades", {})
	var resultado := {}
	for chave in HABILIDADES_PADRAO:
		var padrao: int = HABILIDADES_PADRAO[chave]
		var valor: Variant = padrao
		if dados is Dictionary:
			valor = (dados as Dictionary).get(chave, padrao)
		resultado[chave] = clampi(int(valor), 1, 3)
	return resultado


func _texto_habilidades() -> String:
	var habil := _habilidades()
	return "Observação %d/3  ·  Empatia %d/3  ·  Lábia %d/3" % [habil["observacao"], habil["empatia"], habil["labia"]]


## Plano e contraplano: quem fala fica em foco, o outro escurece.
func _destacar(quem: String) -> void:
	if _retrato_detetive == null:
		return
	if _tween_foco != null:
		_tween_foco.kill()
	var escuro := Color(0.4, 0.4, 0.45)
	_tween_foco = create_tween().set_parallel(true)
	_tween_foco.tween_property(_retrato_detetive, "modulate", Color.WHITE if quem == "detetive" else escuro, 0.35)
	_tween_foco.tween_property(_retrato_suspeito, "modulate", Color.WHITE if quem == "suspeito" else escuro, 0.35)


## Legenda com digitação letra a letra. Falante vazio esconde o nome (narração).
func _mostrar_legenda(falante: String, texto: String) -> void:
	_legenda_falante.visible = falante != ""
	_legenda_falante.text = falante.to_upper()
	_legenda_texto.text = texto
	if _tween_legenda != null:
		_tween_legenda.kill()
	var total := texto.length()
	_legenda_texto.visible_characters = 0
	_tween_legenda = create_tween()
	_tween_legenda.tween_property(_legenda_texto, "visible_characters", total, clampf(total * 0.03, 0.3, 4.0))


func _encerrar() -> void:
	var segredos: Array[String] = []
	var alibi_exposto := false
	if _brain != null:
		segredos = _brain.segredos_revelados.duplicate()
		alibi_exposto = _brain.alibi_exposto
	var resumo := {
		"segredos_revelados": segredos,
		"pistas_reveladas": _pistas_reveladas.duplicate(),
		"alibi_exposto": alibi_exposto,
	}
	for sid in segredos:
		CaseState.revelar_segredo("%s:%s" % [str(_subject.get("id", "")), sid])  # id composto: segredo_1 se repete entre suspeitos
	closed.emit(str(_subject.get("id", "")), resumo)
	queue_free()


## Descrição de uma pista do caso atual, ou o próprio ID se não existir.
func _descricao_pista(clue_id: String) -> String:
	var pistas: Array = CaseManager.current_case.get("pistas", [])
	for pista in pistas:
		if pista is Dictionary and str(pista.get("id", "")) == clue_id:
			return str(pista.get("descricao", clue_id))
	return clue_id


# ---------- Utilitários visuais ----------

func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # quebra de linha: senão o nome longo empurra a tela para fora
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo


func _inicial(nome: String) -> String:
	return nome.substr(0, 1).to_upper() if nome != "" else "?"


func _textura_vinheta() -> GradientTexture2D:
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradiente.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.95)])
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 256
	textura.height = 256
	return textura
