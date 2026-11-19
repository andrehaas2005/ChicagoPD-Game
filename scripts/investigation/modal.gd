extends Control
## Painel modal genérico: título, textos e botões numa lista rolável.
## Bloqueia os cliques no cenário 3D enquanto estiver aberto.

var _conteudo: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_to_group("modal")  # o detetive não anda enquanto um painel modal está visível

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var caixa := PanelContainer.new()
	caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caixa.offset_left = 300
	caixa.offset_right = -300
	caixa.offset_top = 80
	caixa.offset_bottom = -80
	add_child(caixa)

	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caixa.add_child(rolagem)

	_conteudo = VBoxContainer.new()
	_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conteudo.add_theme_constant_override("separation", 10)
	rolagem.add_child(_conteudo)


## Limpa o conteúdo, põe o título e mostra o painel.
func abrir(titulo: String) -> void:
	for filho in _conteudo.get_children():
		_conteudo.remove_child(filho)
		filho.queue_free()
	var rotulo := Label.new()
	rotulo.text = titulo
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", 24)
	_conteudo.add_child(rotulo)
	visible = true


func adicionar_texto(texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conteudo.add_child(rotulo)


## Adiciona um controle qualquer (ex.: caixa de seleção) ao conteúdo.
func adicionar_controle(controle: Control) -> void:
	_conteudo.add_child(controle)


func adicionar_botao(texto: String, acao: Callable) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(0, 44)
	botao.pressed.connect(acao)
	_conteudo.add_child(botao)


func fechar() -> void:
	visible = false
