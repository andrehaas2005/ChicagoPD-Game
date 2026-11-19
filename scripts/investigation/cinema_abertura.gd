extends CanvasLayer
## Cartão de abertura do caso: tela preta com o título, o resumo digitado e o carimbo "CASO ABERTO".
## Uso (o integrador chama, sem bloquear nada):
##   var cartao := CINEMA_ABERTURA.new()
##   add_child(cartao)                      # antes de tocar()
##   cartao.terminou.connect(_on_cartao_terminou)
##   cartao.tocar(titulo, resumo)
## Mostra o título, o resumo e o carimbo, e fica na tela até o jogador apertar "Ir para a Delegacia".
## Ao apertar, some com fade, emite terminou() e se libera sozinho.

signal terminou

const DURACAO_FADE := 0.5
const INICIO_DIGITACAO := 0.3
const CARACTERES_POR_SEGUNDO := 40.0
const DIGITACAO_MIN := 0.8
const DIGITACAO_MAX := 1.6
const DURACAO_CARIMBO := 0.25
const ROTACAO_CARIMBO := -12.0  # graus
const COR_CARIMBO := Color(0.85, 0.12, 0.12, 0.9)

var _raiz: Control
var _titulo: Label
var _resumo: Label
var _carimbo: PanelContainer
var _tween: Tween
var _botao: Button


func _ready() -> void:
	layer = 100

	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fundo)

	var caixa := VBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_FULL_RECT)
	caixa.offset_left = 16
	caixa.offset_right = -16
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_theme_constant_override("separation", 28)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(caixa)

	_titulo = _rotulo(52, Color(0.95, 0.93, 0.85))
	_titulo.modulate.a = 0.0
	caixa.add_child(_titulo)

	_resumo = _rotulo(22, Color(0.82, 0.82, 0.8))
	_resumo.visible_ratio = 0.0
	caixa.add_child(_resumo)

	_carimbo = PanelContainer.new()
	var borda := StyleBoxFlat.new()
	borda.draw_center = false
	borda.set_border_width_all(6)
	borda.border_color = COR_CARIMBO
	borda.set_corner_radius_all(6)
	borda.content_margin_left = 20
	borda.content_margin_right = 20
	borda.content_margin_top = 6
	borda.content_margin_bottom = 6
	_carimbo.add_theme_stylebox_override("panel", borda)
	_carimbo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carimbo.modulate.a = 0.0
	_carimbo.rotation = deg_to_rad(ROTACAO_CARIMBO)
	_carimbo.resized.connect(func() -> void: _carimbo.pivot_offset = _carimbo.size / 2.0)
	var texto_carimbo := _rotulo(60, COR_CARIMBO)
	texto_carimbo.text = "CASO ABERTO"
	texto_carimbo.autowrap_mode = TextServer.AUTOWRAP_OFF
	_carimbo.add_child(texto_carimbo)
	_carimbo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caixa.add_child(_carimbo)

	_botao = Button.new()
	_botao.text = "Ir para a Delegacia"
	_botao.custom_minimum_size = Vector2(320, 52)
	_botao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_botao.visible = false
	_botao.pressed.connect(_ao_apertar_botao)
	caixa.add_child(_botao)


## Toca o cartão. Chamar depois de add_child(). Se já houver um cartão tocando, reinicia.
func tocar(titulo: String, resumo: String) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_titulo.text = titulo
	_resumo.text = resumo
	_resumo.visible_ratio = 0.0
	_titulo.modulate.a = 0.0
	_carimbo.modulate.a = 0.0
	_carimbo.scale = Vector2(1.8, 1.8)
	_raiz.modulate.a = 1.0
	_raiz.visible = true

	var digitacao := clampf(float(resumo.length()) / CARACTERES_POR_SEGUNDO, DIGITACAO_MIN, DIGITACAO_MAX)

	_tween = create_tween()
	_tween.tween_property(_titulo, "modulate:a", 1.0, 0.4)
	_tween.parallel().tween_property(_resumo, "visible_ratio", 1.0, digitacao).set_delay(INICIO_DIGITACAO)
	_tween.tween_property(_carimbo, "modulate:a", 1.0, DURACAO_CARIMBO)
	_tween.parallel().tween_property(_carimbo, "scale", Vector2.ONE, DURACAO_CARIMBO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_botao.visible = false
	_tween.finished.connect(_mostrar_botao)


func _mostrar_botao() -> void:
	_botao.visible = true
	_botao.disabled = false


func _ao_apertar_botao() -> void:
	_botao.disabled = true
	var fade := create_tween()
	fade.tween_property(_raiz, "modulate:a", 0.0, DURACAO_FADE)
	fade.finished.connect(_terminar)


func _terminar() -> void:
	terminou.emit()
	queue_free()


func _rotulo(tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rotulo
