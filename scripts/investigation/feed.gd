extends PanelContainer
## Feed de plantão: lista de mensagens com horário, alimentada pelo mundo vivo.
## Mostra rotinas que começam (horário já passado pelo relógio), pistas liberadas,
## resultados de laboratório, revelações de reviravoltas e falas do capitão.
## Não altera o jogo: só registra o que acontece. Chamar limpar() ao iniciar o caso.

const MAX_MENSAGENS := 30
const MINUTOS_DIA := 1440
const INICIO_DIA_HORA := 8
const CaseQueries = preload("res://scripts/core/case_queries.gd")

## Disparado a cada mensagem nova (para o HUD ou outro sistema reagir, se quiser).
signal novidade(texto: String)

var _lista: VBoxContainer
var _ultimo_minuto := 0  # último instante notado pelo relógio, para não repetir rotinas


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	offset_left = 16
	offset_top = 56
	offset_right = 336
	offset_bottom = -136
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # o painel deixa os cliques passarem para o 3D

	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.mouse_filter = Control.MOUSE_FILTER_PASS  # rola com a roda, mas deixa cliques passarem
	add_child(rolagem)

	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	rolagem.add_child(_lista)

	GameClock.time_changed.connect(_on_time_changed)
	GameClock.reveal.connect(_on_reveal)
	CaseState.clue_unlocked.connect(_on_clue_unlocked)
	CaseState.lab_ready.connect(_on_lab_ready)
	CaseState.alibi_exposed.connect(_on_alibi_exposed)
	CaseState.dica_capitao_dada.connect(_on_dica_capitao)


## Esvazia o feed e zera o último horário notado. Chamar depois de CaseState.reset().
func limpar() -> void:
	visible = false
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	_ultimo_minuto = 0


## Adiciona uma mensagem com o horário atual do relógio (mais nova no topo).
func adicionar(texto: String) -> void:
	_registrar(texto, GameClock.now_minutes())


func _registrar(texto: String, minutos: int) -> void:
	visible = true  # o feed só aparece quando tem alguma mensagem
	var rotulo := Label.new()
	rotulo.text = "%s\n%s" % [GameClock.format_at(minutos), texto]
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo.add_theme_font_size_override("font_size", 15)
	_lista.add_child(rotulo)
	_lista.move_child(rotulo, 0)
	while _lista.get_child_count() > MAX_MENSAGENS:
		var antiga := _lista.get_child(_lista.get_child_count() - 1)
		_lista.remove_child(antiga)
		antiga.queue_free()
	novidade.emit(texto)


# ---------- Eventos do mundo ----------

## Rotinas que começaram entre o último horário notado e agora viram mensagens, em ordem.
func _on_time_changed(minutos: int) -> void:
	var de := _ultimo_minuto
	_ultimo_minuto = minutos
	if minutos <= de or CaseManager.current_case.is_empty():
		return
	var eventos: Array = []  # cada item: [minutos_absolutos, texto]
	for pessoa in CaseQueries.pessoas(CaseManager.current_case):
		var nome := CaseQueries.texto(pessoa.get("nome", "?"))
		for janela in pessoa.get("rotina", []):
			if not janela is Dictionary:
				continue
			var inicio := _minuto_da_janela(int(janela.get("dia", 0)), int(janela.get("de_hora", 0)))
			if inicio <= de or inicio > minutos:
				continue
			var local_nome := _nome_local(CaseQueries.texto(janela.get("local", "")))
			eventos.append([inicio, "%s foi visto chegando a %s." % [nome, local_nome]])
	eventos.sort_custom(func(a, b): return a[0] < b[0])
	for evento in eventos:
		_registrar(str(evento[1]), int(evento[0]))


func _on_reveal(texto: String, _clue_id: String) -> void:
	if texto != "":
		_registrar(texto, _minuto_de_reviravolta("", texto))


func _on_clue_unlocked(clue_id: String) -> void:
	var caso := CaseManager.current_case
	var local_id := CaseQueries.texto(CaseQueries.pista(caso, clue_id).get("local", ""))
	var texto := "Nova pista liberada."
	if local_id != "":
		texto = "Nova pista liberada no %s." % _nome_local(local_id)
	_registrar(texto, _minuto_de_reviravolta(clue_id, ""))


func _on_lab_ready(_clue_id: String, conclusao: String) -> void:
	adicionar("Laboratório: %s" % (conclusao if conclusao != "" else "resultado pronto."))


func _on_alibi_exposed(suspect_id: String) -> void:
	var pessoa := CaseQueries.pessoa(CaseManager.current_case, suspect_id)
	adicionar("A versão de %s sobre o paradeiro não bate com as provas." % CaseQueries.texto(pessoa.get("nome", "?")))


func _on_dica_capitao(texto: String) -> void:
	adicionar("Capitão: %s" % texto)


# ---------- Auxiliares ----------

## Minutos desde o início do caso (0 = dia 1, 08:00) em que a janela começa.
func _minuto_da_janela(dia: int, hora: int) -> int:
	return (dia - 1) * MINUTOS_DIA + hora * 60 - INICIO_DIA_HORA * 60


## Horário agendado da reviravolta (hora * 60) que libera a pista ou traz o texto dado.
## Sem reviravolta correspondente, usa o horário atual. Evita carimbar com o relógio já avançado.
func _minuto_de_reviravolta(clue_id: String, texto: String) -> int:
	for evento in CaseManager.current_case.get("reviravoltas", []):
		if not evento is Dictionary:
			continue
		var mesma_pista := clue_id != "" and CaseQueries.texto(evento.get("revela_pista", "")) == clue_id
		var mesmo_texto := texto != "" and CaseQueries.texto(evento.get("descricao", "")) == texto
		if mesma_pista or mesmo_texto:
			return int(evento.get("hora", 0)) * 60
	return GameClock.now_minutes()


func _nome_local(local_id: String) -> String:
	var local := CaseQueries.local_por_id(CaseManager.current_case, local_id)
	return CaseQueries.texto(local.get("nome", local_id))
