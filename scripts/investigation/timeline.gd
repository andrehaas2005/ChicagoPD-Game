extends Control
## Linha do tempo das 48 horas: uma faixa por pessoa, com a rotina planejada e as
## localizações reveladas por consulta. O cursor de visualização só mostra a rotina
## em outro horário; não altera o relógio nem o estado do jogo.

## Disparado quando o painel é fechado.
signal fechar()

const CaseQueries = preload("res://scripts/core/case_queries.gd")
const MINUTOS_DIA := 1440
const DURACAO := 2880
const INICIO_DIA_HORA := 8
const PX_HORA := 28.0
const LARGURA_NOMES := 170.0
const ALTURA_LINHA := 44.0
const ALTURA_CABECALHO := 46.0
const PASSO_MINUTOS := 15

const COR_FUNDO := Color("#15171c")
const COR_GRADE := Color(1, 1, 1, 0.12)
const COR_TEXTO := Color("#e8e8e8")
const COR_SUSPEITO := Color("#8a3b3b")
const COR_TESTEMUNHA := Color("#2f6a7a")
const COR_LOCALIZADO := Color("#e8c15a")
const COR_AGORA := Color("#ff5a5a")
const COR_VISAO := Color(1, 1, 1, 0.9)

var _caso: Dictionary = {}
var _pessoas: Array[Dictionary] = []
var _visao := 0  # minutos (desde dia 1, 08:00) mostrados pelo cursor de visualização
var _arrastando := false
var _lienzo: Control
var _legenda: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_to_group("modal")  # o detetive não anda enquanto o painel está visível
	GameClock.time_changed.connect(_on_time_changed)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.75)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var caixa := PanelContainer.new()
	caixa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caixa.offset_left = 16
	caixa.offset_right = -16
	caixa.offset_top = 16
	caixa.offset_bottom = -16
	add_child(caixa)

	var conteudo := VBoxContainer.new()
	caixa.add_child(conteudo)

	var titulo := Label.new()
	titulo.text = "Linha do tempo (48 horas)"
	titulo.add_theme_font_size_override("font_size", 22)
	conteudo.add_child(titulo)

	_legenda = Label.new()
	conteudo.add_child(_legenda)

	var controles := HBoxContainer.new()
	controles.add_theme_constant_override("separation", 8)
	conteudo.add_child(controles)
	_novo_botao(controles, "« 1 h", _mover.bind(-60))
	_novo_botao(controles, "1 h »", _mover.bind(60))
	_novo_botao(controles, "Agora", _voltar_para_agora)
	_novo_botao(controles, "Fechar", ocultar)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conteudo.add_child(rolagem)

	_lienzo = Control.new()
	_lienzo.mouse_filter = Control.MOUSE_FILTER_STOP
	_lienzo.draw.connect(_desenhar)
	_lienzo.gui_input.connect(_on_lienzo_input)
	rolagem.add_child(_lienzo)


## Mostra a linha do tempo do caso. O cursor de visualização começa no horário atual.
func abrir(caso: Dictionary) -> void:
	_caso = caso
	_pessoas = CaseQueries.pessoas(caso)
	_visao = GameClock.now_minutes()
	_lienzo.custom_minimum_size = Vector2(
		LARGURA_NOMES + 48.0 * PX_HORA + 8.0,
		ALTURA_CABECALHO + maxi(_pessoas.size(), 1) * ALTURA_LINHA + 8.0
	)
	visible = true
	_atualizar()


## Esconde o painel e emite fechar().
func ocultar() -> void:
	visible = false
	_arrastando = false
	fechar.emit()


func _novo_botao(pai: Control, texto: String, acao: Callable) -> void:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(0, 44)
	botao.pressed.connect(acao)
	pai.add_child(botao)


func _mover(delta: int) -> void:
	_visao = clampi(_visao + delta, 0, DURACAO)
	_atualizar()


func _voltar_para_agora() -> void:
	_visao = GameClock.now_minutes()
	_atualizar()


func _atualizar() -> void:
	_legenda.text = "Visualizando: %s   |   Agora: %s" % [GameClock.format_at(_visao), GameClock.format_now()]
	_lienzo.queue_redraw()


func _on_time_changed(_minutos: int) -> void:
	if visible:
		_atualizar()


# ---------- Entrada ----------

func _on_lienzo_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = evento.pressed
		if evento.pressed:
			_definir_visao_pelo_x(evento.position.x)
		_lienzo.accept_event()
	elif evento is InputEventMouseMotion and _arrastando:
		_definir_visao_pelo_x(evento.position.x)
		_lienzo.accept_event()


func _definir_visao_pelo_x(x: float) -> void:
	_visao = clampi(_minuto_de_x(x), 0, DURACAO)
	_atualizar()


# ---------- Desenho ----------

func _desenhar() -> void:
	var fonte := ThemeDB.fallback_font
	var largura := _lienzo.custom_minimum_size.x
	var altura := _lienzo.custom_minimum_size.y
	_lienzo.draw_rect(Rect2(Vector2.ZERO, Vector2(largura, altura)), COR_FUNDO)

	# Cabeçalho: marcas a cada 6 horas, com o dia e a hora do relógio do caso.
	for minuto in range(0, DURACAO + 1, 360):
		var x := _x_de_minuto(minuto)
		var total := INICIO_DIA_HORA * 60 + minuto
		var dia := total / MINUTOS_DIA + 1
		var hora := (total % MINUTOS_DIA) / 60
		_lienzo.draw_line(Vector2(x, ALTURA_CABECALHO - 8.0), Vector2(x, altura), COR_GRADE, 1.0)
		_lienzo.draw_string(fonte, Vector2(x + 4.0, 22.0), "D%d %02dh" % [dia, hora], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COR_TEXTO)

	var localizados := CaseState.localizacoes_ativas()
	var agora := GameClock.now_minutes()

	for i in range(_pessoas.size()):
		var pessoa := _pessoas[i]
		var pessoa_id := CaseQueries.texto(pessoa.get("id", ""))
		var y := ALTURA_CABECALHO + i * ALTURA_LINHA
		if i % 2 == 0:
			_lienzo.draw_rect(Rect2(0, y, largura, ALTURA_LINHA), Color(1, 1, 1, 0.03))
		_lienzo.draw_string(fonte, Vector2(6.0, y + 27.0), CaseQueries.texto(pessoa.get("nome", "?")), HORIZONTAL_ALIGNMENT_LEFT, LARGURA_NOMES - 12.0, 14, COR_TEXTO)

		var cor := COR_TESTEMUNHA if CaseQueries.texto(pessoa.get("tipo", "")) == "testemunha" else COR_SUSPEITO
		for janela in pessoa.get("rotina", []):
			if not janela is Dictionary:
				continue
			var ini := clampi(_minuto_da_janela(int(janela.get("dia", 0)), int(janela.get("de_hora", 0))), 0, DURACAO)
			var fim := clampi(_minuto_da_janela(int(janela.get("dia", 0)), int(janela.get("ate_hora", 0))), 0, DURACAO)
			if fim <= ini:
				continue
			var local_nome := _nome_local(CaseQueries.texto(janela.get("local", "")))
			_desenhar_bloco(fonte, Rect2(_x_de_minuto(ini), y + 6.0, _x_de_minuto(fim) - _x_de_minuto(ini), ALTURA_LINHA - 12.0), cor, local_nome, ini <= _visao and _visao < fim)

		for loc in localizados:
			if CaseQueries.texto(loc.get("person_id", "")) != pessoa_id:
				continue
			var fim_loc := clampi(int(loc.get("ate_minutos", 0)), 0, DURACAO)
			if fim_loc <= agora:
				continue
			var texto_loc := "Localizado: %s" % _nome_local(CaseQueries.texto(loc.get("local", "")))
			_desenhar_bloco(fonte, Rect2(_x_de_minuto(agora), y + 6.0, _x_de_minuto(fim_loc) - _x_de_minuto(agora), ALTURA_LINHA - 12.0), COR_LOCALIZADO, texto_loc, false)

	# Cursores: vermelho = agora (relógio); branco = visualização do jogador.
	_lienzo.draw_line(Vector2(_x_de_minuto(agora), ALTURA_CABECALHO - 8.0), Vector2(_x_de_minuto(agora), altura), COR_AGORA, 2.0)
	_lienzo.draw_line(Vector2(_x_de_minuto(_visao), ALTURA_CABECALHO - 8.0), Vector2(_x_de_minuto(_visao), altura), COR_VISAO, 2.0)


## Bloco de rotina ou localização. Com destaque, desenha contorno (horário visualizado).
func _desenhar_bloco(fonte: Font, area: Rect2, cor: Color, texto: String, destaque: bool) -> void:
	_lienzo.draw_rect(area, cor)
	if destaque:
		_lienzo.draw_rect(area, COR_VISAO, false, 2.0)
	_lienzo.draw_string(fonte, area.position + Vector2(4.0, 18.0), texto, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 8.0, 12, COR_TEXTO)


# ---------- Auxiliares ----------

func _x_de_minuto(minuto: int) -> float:
	return LARGURA_NOMES + float(minuto) / 60.0 * PX_HORA


func _minuto_de_x(x: float) -> int:
	var minuto := (x - LARGURA_NOMES) / PX_HORA * 60.0
	return int(round(minuto / PASSO_MINUTOS)) * PASSO_MINUTOS


## Minutos desde o início do caso (0 = dia 1, 08:00) em que a janela (dia, hora) começa.
func _minuto_da_janela(dia: int, hora: int) -> int:
	return (dia - 1) * MINUTOS_DIA + hora * 60 - INICIO_DIA_HORA * 60


func _nome_local(local_id: String) -> String:
	var local := CaseQueries.local_por_id(_caso, local_id)
	return CaseQueries.texto(local.get("nome", local_id))
