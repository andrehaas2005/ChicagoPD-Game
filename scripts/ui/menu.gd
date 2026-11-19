extends Control
## Menu principal: título e botões de navegação. Interface construída por código.

const COR_FUNDO := Color("#14171c")
const COR_TITULO := Color("#e8c15a")


func _ready() -> void:
	_construir_interface()


func _construir_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(PRESET_FULL_RECT)
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(PRESET_FULL_RECT)
	add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size = Vector2(320, 0)
	caixa.add_theme_constant_override("separation", 16)
	centro.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "ChicagoPD"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_color", COR_TITULO)
	caixa.add_child(titulo)

	var subtitulo := Label.new()
	subtitulo.text = "Investigação policial em Chicago"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(subtitulo)

	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 24)
	caixa.add_child(espaco)

	caixa.add_child(_criar_botao("Novo jogo", _on_novo_jogo))
	caixa.add_child(_criar_botao("Trocar detetive", _on_trocar_detetive))
	caixa.add_child(_criar_botao("Sair", _on_sair))


func _criar_botao(texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(320, 52)
	botao.pressed.connect(acao)
	return botao


func _on_novo_jogo() -> void:
	if GameState.has_player():
		GameState.go_to("case_select")
	else:
		GameState.go_to("character_select")


func _on_trocar_detetive() -> void:
	GameState.go_to("character_select")


func _on_sair() -> void:
	get_tree().quit()
