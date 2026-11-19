extends Control
## HUD da investigação: título, local, relógio, progresso, painel de informação, ações do
## local e aviso de plantão. Só botões e painéis recebem cliques; o resto passa para o 3D.

const PLANTAO_SEGUNDOS := 7.0
const COR_DESTAQUE := Color("#e8c15a")
const COR_LABORATORIO := Color("#e0a050")

var _titulo: Label
var _local: Label
var _tempo: Label
var _pistas: Label
var _laboratorio: Label
var _info: Label
var _acoes: VBoxContainer
var _plantao: PanelContainer
var _plantao_texto: Label
var _plantao_timer: Timer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir()


func set_titulo(texto: String) -> void:
	_titulo.text = texto


## Atualiza o cabeçalho: local atual, horário, progresso de pistas e laboratório ("" esconde).
func atualizar_status(local_nome: String, tempo: String, pistas: String, laboratorio: String) -> void:
	_local.text = local_nome
	_tempo.text = tempo
	_pistas.text = pistas
	_laboratorio.text = laboratorio
	_laboratorio.visible = laboratorio != ""


func definir_info(texto: String) -> void:
	_info.text = texto


## acoes: Array de {texto: String, acao: Callable, ativo: bool}.
func definir_acoes(acoes: Array) -> void:
	for filho in _acoes.get_children():
		_acoes.remove_child(filho)
		filho.queue_free()
	for acao in acoes:
		var botao := Button.new()
		botao.text = str(acao.get("texto", ""))
		botao.custom_minimum_size = Vector2(0, 44)
		botao.disabled = not bool(acao.get("ativo", true))
		botao.pressed.connect(acao["acao"])
		_acoes.add_child(botao)


## Mostra um aviso de plantão. Some sozinho depois de alguns segundos ou com um clique.
func mostrar_plantao(texto: String) -> void:
	_plantao_texto.text = texto
	_plantao.visible = true
	_plantao_timer.start(PLANTAO_SEGUNDOS)


func _construir() -> void:
	_titulo = _novo_rotulo(26, Color.WHITE)
	_titulo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_titulo.offset_top = 12
	_titulo.offset_bottom = 52
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_titulo)

	_local = _novo_rotulo(20, COR_DESTAQUE)
	_local.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_local.offset_left = 16
	_local.offset_top = 16
	_local.offset_right = 520
	_local.offset_bottom = 46
	add_child(_local)

	var status := VBoxContainer.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -330
	status.offset_right = -16
	status.offset_top = 16
	status.offset_bottom = 120
	add_child(status)
	_tempo = _novo_rotulo(20, Color.WHITE)
	_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_tempo)
	_pistas = _novo_rotulo(18, Color.WHITE)
	_pistas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_pistas)
	_laboratorio = _novo_rotulo(18, COR_LABORATORIO)
	_laboratorio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(_laboratorio)

	_plantao = PanelContainer.new()
	_plantao.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_plantao.offset_left = -330
	_plantao.offset_right = 330
	_plantao.offset_top = 64
	_plantao.offset_bottom = 150
	_plantao.mouse_filter = Control.MOUSE_FILTER_STOP
	_plantao.visible = false
	_plantao.gui_input.connect(_on_plantao_input)
	add_child(_plantao)
	_plantao_texto = _novo_rotulo(18, Color("#ffd27a"))
	_plantao_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plantao_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plantao.add_child(_plantao_texto)

	_plantao_timer = Timer.new()
	_plantao_timer.one_shot = true
	_plantao_timer.timeout.connect(_plantao.hide)
	add_child(_plantao_timer)

	var painel := PanelContainer.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	painel.offset_left = 16
	painel.offset_top = -120
	painel.offset_right = 820
	painel.offset_bottom = -16
	add_child(painel)
	_info = _novo_rotulo(18, Color.WHITE)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.text = "Clique nas pistas e nas pessoas para examiná-las."
	painel.add_child(_info)

	var rolagem := ScrollContainer.new()
	rolagem.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	rolagem.offset_left = -260
	rolagem.offset_top = 130
	rolagem.offset_right = -16
	rolagem.offset_bottom = -16
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(rolagem)
	_acoes = VBoxContainer.new()
	_acoes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_acoes.add_theme_constant_override("separation", 8)
	rolagem.add_child(_acoes)


func _novo_rotulo(tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo


func _on_plantao_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed:
		_plantao.visible = false
