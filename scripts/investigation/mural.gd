extends Control
## Mural de pistas: quadro de cortiça com as pistas coletadas (cartões à esquerda) e os
## suspeitos e testemunhas (cartões à direita). O jogador liga uma pista a uma pessoa
## clicando primeiro na pista e depois na pessoa. Clicar na fita de uma ligação a remove.
## As ligações ficam só em memória, em `ligacoes` (não passam por CaseState).
##
## Uso típico (a partir da cena de investigação):
##   var m := preload("res://scripts/investigation/mural.gd").new()
##   camada.add_child(m)
##   m.fechar.connect(...)
##   m.abrir(CaseManager.current_case)

const CaseQueries = preload("res://scripts/core/case_queries.gd")

signal fechar

const COR_CORTICA := Color(0.55, 0.37, 0.2)
const COR_CORTICA_ESCURA := Color(0.4, 0.26, 0.13)
const COR_PAPEL := Color(0.93, 0.89, 0.8)
const COR_FITA := Color(0.8, 0.1, 0.1)
const COR_PINO := Color(0.95, 0.8, 0.2)
const COR_CARTAO := Color.WHITE
const COR_BORDA := Color(0.25, 0.25, 0.25)
const COR_SELECAO := Color(0.95, 0.7, 0.05)

const CARTAO_LARGURA := 230.0
const CARTAO_ALTURA_MAX := 92.0
const ESPACO := 12.0
const MARGEM := 24.0
const TOPO_CARTOES := 84.0
const ALTURA_FAIXA := 56.0
const TOLERANCIA_CLIQUE := 10.0
const PASSOS_FITA := 16

## Ligações pista-pessoa: Array de {pista_id: String, suspeito_id: String}.
var ligacoes: Array = []

var _caso: Dictionary = {}
var _caso_id := ""
var _pista_selecionada := ""
var _cartoes_pista: Dictionary = {}   # pista_id -> Button
var _cartoes_pessoa: Dictionary = {}  # suspeito_id -> Button
var _fundo: ColorRect
var _fios: Control
var _faixa: ColorRect
var _titulo: Label
var _botao_fechar: Button
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_to_group("modal")  # o detetive não anda enquanto o mural está visível

	_fundo = ColorRect.new()
	_fundo.color = COR_CORTICA
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)

	# Sombra mais escura na borda, para dar a cara de cortiça gasta.
	var borda := ColorRect.new()
	borda.color = COR_CORTICA_ESCURA
	borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	borda.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	borda.modulate = Color(1, 1, 1, 0.35)
	add_child(borda)

	_fios = Control.new()
	_fios.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fios.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fios.draw.connect(_desenhar_fios)
	add_child(_fios)

	_faixa = ColorRect.new()
	_faixa.color = COR_PAPEL
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_faixa)

	_titulo = Label.new()
	_titulo.text = "Mural de pistas"
	_titulo.add_theme_font_size_override("font_size", 22)
	_titulo.add_theme_color_override("font_color", Color.BLACK)
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_titulo)

	_botao_fechar = Button.new()
	_botao_fechar.text = "Fechar"
	_botao_fechar.custom_minimum_size = Vector2(110, 34)
	_botao_fechar.pressed.connect(_fechar)
	add_child(_botao_fechar)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", COR_PAPEL)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	resized.connect(_reposicionar)


## Monta os cartões das pistas coletadas e das pessoas do caso e mostra o mural.
## As ligações feitas continuam valendo enquanto o caso for o mesmo.
func abrir(caso: Dictionary) -> void:
	var novo_id := CaseQueries.texto(caso.get("id", ""))
	if novo_id != _caso_id:
		ligacoes.clear()
	_caso = caso
	_caso_id = novo_id
	_pista_selecionada = ""
	_limpar_cartoes()

	for pista in CaseQueries.pistas(caso):
		var pista_id := CaseQueries.texto(pista.get("id", ""))
		if not (pista_id in CaseManager.found_clues):
			continue
		var cartao := _criar_cartao(CaseQueries.texto(pista.get("descricao", "")), true)
		cartao.pressed.connect(_on_pista_pressed.bind(pista_id))
		add_child(cartao)
		_cartoes_pista[pista_id] = cartao

	for pessoa in CaseQueries.pessoas(caso):
		var pessoa_id := CaseQueries.texto(pessoa.get("id", ""))
		var texto := _texto_cartao(pessoa)
		var cartao := _criar_cartao(texto, false)
		cartao.pressed.connect(_on_pessoa_pressed.bind(pessoa_id))
		var detalhes := Button.new()
		detalhes.text = "Detalhes"
		detalhes.focus_mode = Control.FOCUS_NONE
		detalhes.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		detalhes.offset_left = -92
		detalhes.offset_top = -26
		detalhes.offset_right = -4
		detalhes.offset_bottom = -4
		detalhes.add_theme_font_size_override("font_size", 12)
		detalhes.pressed.connect(_mostrar_detalhes.bind(pessoa_id))
		cartao.add_child(detalhes)
		add_child(cartao)
		_cartoes_pessoa[pessoa_id] = cartao

	ligacoes = ligacoes.filter(func(l): return _cartoes_pista.has(l["pista_id"]) and _cartoes_pessoa.has(l["suspeito_id"]))
	_status.text = "Clique numa pista e depois num suspeito para ligá-los. Clique na fita para remover."
	visible = true
	_reposicionar()
	_atualizar_destaques()


## Confere o mural contra a solução do caso. `culpado_id` é o suspeito certo e
## `pistas_necessarias` as pistas-chave. Correto quando todas as pistas-chave foram coletadas
## e o culpado está ligado a pelo menos uma delas no mural.
## Devolve {"correto": bool, "texto": String}.
func verificar_ligacoes(culpado_id: String, pistas_necessarias: Array) -> Dictionary:
	var sem_coleta: Array[String] = []
	var sem_ligacao: Array[String] = []
	var ligado_a_chave := false
	for item in pistas_necessarias:
		var pista_id := str(item)
		if not (pista_id in CaseManager.found_clues):
			sem_coleta.append(pista_id)
		if _ligacao_existe(pista_id, culpado_id):
			ligado_a_chave = true
		else:
			sem_ligacao.append(pista_id)

	var correto := sem_coleta.is_empty() and ligado_a_chave
	var partes: Array[String] = []
	if sem_coleta.is_empty():
		partes.append("Todas as pistas necessárias foram coletadas.")
	else:
		partes.append("Faltam pistas necessárias: %s." % _lista_pistas(sem_coleta))
	if ligado_a_chave:
		partes.append("O suspeito certo está ligado a pelo menos uma pista-chave.")
	else:
		partes.append("O suspeito certo não está ligado a nenhuma pista-chave no mural.")
	if not sem_ligacao.is_empty():
		partes.append("Pistas-chave ainda sem ligação ao culpado: %s." % _lista_pistas(sem_ligacao))
	return {"correto": correto, "texto": " ".join(partes)}


# ---------- Cliques ----------

func _on_pista_pressed(pista_id: String) -> void:
	_pista_selecionada = "" if _pista_selecionada == pista_id else pista_id
	if _pista_selecionada == "":
		_status.text = "Pista desmarcada."
	else:
		_status.text = "Pista marcada. Agora clique num suspeito."
	_atualizar_destaques()


func _on_pessoa_pressed(pessoa_id: String) -> void:
	if _pista_selecionada == "":
		_status.text = "Clique numa pista primeiro."
		return
	if _ligacao_existe(_pista_selecionada, pessoa_id):
		_status.text = "Essa pista já está ligada a esse suspeito."
		return
	ligacoes.append({"pista_id": _pista_selecionada, "suspeito_id": pessoa_id})
	_status.text = "Pista ligada a %s." % CaseQueries.texto(CaseQueries.pessoa(_caso, pessoa_id).get("nome", pessoa_id))
	_pista_selecionada = ""
	_atualizar_destaques()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var indice := _indice_ligacao_em(event.position)
	if indice >= 0:
		ligacoes.remove_at(indice)
		_status.text = "Ligação removida."
		_fios.queue_redraw()
		accept_event()
		return
	if _pista_selecionada != "":
		_pista_selecionada = ""
		_status.text = "Pista desmarcada."
		_atualizar_destaques()


func _fechar() -> void:
	visible = false
	fechar.emit()


# ---------- Desenho ----------

func _desenhar_fios() -> void:
	for ligacao in ligacoes:
		var pontos := _pontos_fita(ligacao)
		if pontos.size() < 2:
			continue
		_fios.draw_polyline(pontos, COR_FITA, 4.0, true)
		_fios.draw_circle(pontos[0], 5.0, COR_PINO)
		_fios.draw_circle(pontos[pontos.size() - 1], 5.0, COR_PINO)


## Pontos da fita de uma ligação: sai da borda direita da pista e chega na borda esquerda
## da pessoa, com uma flexão para baixo (a fita fica frouxa).
func _pontos_fita(ligacao: Dictionary) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	var cartao_pista: Button = _cartoes_pista.get(ligacao["pista_id"])
	var cartao_pessoa: Button = _cartoes_pessoa.get(ligacao["suspeito_id"])
	if cartao_pista == null or cartao_pessoa == null:
		return pontos
	var a := cartao_pista.position + Vector2(cartao_pista.size.x, cartao_pista.size.y / 2.0)
	var b := cartao_pessoa.position + Vector2(0, cartao_pessoa.size.y / 2.0)
	var flexao := clampf(a.distance_to(b) * 0.15, 10.0, 70.0)
	for i in range(PASSOS_FITA + 1):
		var t := float(i) / PASSOS_FITA
		var p := a.lerp(b, t)
		p.y += sin(PI * t) * flexao
		pontos.append(p)
	return pontos


func _indice_ligacao_em(ponto: Vector2) -> int:
	for i in range(ligacoes.size()):
		var pontos := _pontos_fita(ligacoes[i])
		for j in range(pontos.size() - 1):
			if _distancia_segmento(ponto, pontos[j], pontos[j + 1]) <= TOLERANCIA_CLIQUE:
				return i
	return -1


func _distancia_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var comprimento_2 := ab.length_squared()
	if comprimento_2 == 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / comprimento_2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---------- Layout e estilo ----------

func _reposicionar() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	_faixa.position = Vector2.ZERO
	_faixa.size = Vector2(size.x, ALTURA_FAIXA)
	_titulo.position = Vector2(MARGEM, 14)
	_botao_fechar.position = Vector2(size.x - _botao_fechar.custom_minimum_size.x - MARGEM, 11)
	_status.position = Vector2(MARGEM, size.y - 34)
	_status.size = Vector2(size.x - 2 * MARGEM, 24)

	var altura_util := size.y - TOPO_CARTOES - MARGEM - 40.0
	var pistas: Array = []
	for pista_id in _cartoes_pista:
		pistas.append(_cartoes_pista[pista_id])
	var pessoas: Array = []
	for pessoa_id in _cartoes_pessoa:
		pessoas.append(_cartoes_pessoa[pessoa_id])

	var colunas_pistas := 1 if pistas.size() <= 5 else 2
	var colunas_pessoas := 1 if pessoas.size() <= 5 else 2
	_dispor(pistas, MARGEM, colunas_pistas, altura_util)
	var largura_pessoas := colunas_pessoas * CARTAO_LARGURA + (colunas_pessoas - 1) * ESPACO
	_dispor(pessoas, size.x - MARGEM - largura_pessoas, colunas_pessoas, altura_util)
	_fios.queue_redraw()


## Dispõe os cartões em colunas (preenchendo cada coluna de cima para baixo).
func _dispor(cartoes: Array, x_inicial: float, colunas: int, altura_util: float) -> void:
	if cartoes.is_empty():
		return
	var linhas := ceili(float(cartoes.size()) / colunas)
	var altura := minf(CARTAO_ALTURA_MAX, (altura_util - ESPACO * (linhas - 1)) / linhas)
	for i in range(cartoes.size()):
		var coluna := i / linhas
		var linha := i % linhas
		var cartao: Button = cartoes[i]
		cartao.position = Vector2(x_inicial + coluna * (CARTAO_LARGURA + ESPACO), TOPO_CARTOES + linha * (altura + ESPACO))
		cartao.size = Vector2(CARTAO_LARGURA, altura)


func _criar_cartao(texto: String, e_pista: bool) -> Button:
	var cartao := Button.new()
	cartao.text = ""
	cartao.clip_contents = true
	cartao.focus_mode = Control.FOCUS_NONE
	cartao.add_theme_stylebox_override("normal", _estilo_cartao(COR_BORDA))
	cartao.add_theme_stylebox_override("hover", _estilo_cartao(COR_BORDA))
	cartao.add_theme_stylebox_override("pressed", _estilo_cartao(COR_BORDA))
	cartao.add_theme_stylebox_override("focus", _estilo_cartao(COR_BORDA))

	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.clip_text = true
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", 14 if e_pista else 16)
	rotulo.add_theme_color_override("font_color", Color.BLACK)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotulo.offset_left = 10
	rotulo.offset_top = 6
	rotulo.offset_right = -10
	rotulo.offset_bottom = -6 if e_pista else -30  # cartão de pessoa reserva espaço para o botão Detalhes
	cartao.add_child(rotulo)
	return cartao


func _estilo_cartao(cor_borda: Color) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_CARTAO
	estilo.border_color = cor_borda
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(3)
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 4
	estilo.shadow_offset = Vector2(2, 3)
	return estilo


## Destaca a pista selecionada e atualiza o aspecto de cada cartão.
func _atualizar_destaques() -> void:
	for pista_id in _cartoes_pista:
		var cor := COR_SELECAO if pista_id == _pista_selecionada else COR_BORDA
		_aplicar_borda(_cartoes_pista[pista_id], cor)
	for pessoa_id in _cartoes_pessoa:
		_aplicar_borda(_cartoes_pessoa[pessoa_id], COR_BORDA)
	_fios.queue_redraw()


func _aplicar_borda(cartao: Button, cor: Color) -> void:
	for estado in ["normal", "hover", "pressed", "focus"]:
		cartao.add_theme_stylebox_override(estado, _estilo_cartao(cor))


func _limpar_cartoes() -> void:
	for cartao in _cartoes_pista.values() + _cartoes_pessoa.values():
		remove_child(cartao)
		cartao.queue_free()
	_cartoes_pista.clear()
	_cartoes_pessoa.clear()


func _ligacao_existe(pista_id: String, pessoa_id: String) -> bool:
	for ligacao in ligacoes:
		if ligacao["pista_id"] == pista_id and ligacao["suspeito_id"] == pessoa_id:
			return true
	return false


func _rotulo_tipo(pessoa: Dictionary) -> String:
	return "Testemunha" if CaseQueries.texto(pessoa.get("tipo", "")) == "testemunha" else "Suspeito"


func _lista_pistas(ids: Array[String]) -> String:
	var nomes: Array[String] = []
	for pista_id in ids:
		var descricao := CaseQueries.texto(CaseQueries.pista(_caso, pista_id).get("descricao", pista_id))
		nomes.append(descricao.left(40))
	return ", ".join(nomes)


# ---------- Detalhes de um suspeito ou testemunha ----------

var _detalhes: PanelContainer
var _detalhes_texto: RichTextLabel


func _mostrar_detalhes(pessoa_id: String) -> void:
	if _detalhes == null:
		_detalhes = PanelContainer.new()
		_detalhes.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_detalhes.offset_left = -330
		_detalhes.offset_right = 330
		_detalhes.offset_top = -270
		_detalhes.offset_bottom = 270
		_detalhes.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_detalhes)
		var coluna := VBoxContainer.new()
		coluna.add_theme_constant_override("separation", 10)
		_detalhes.add_child(coluna)
		_detalhes_texto = RichTextLabel.new()
		_detalhes_texto.bbcode_enabled = true
		_detalhes_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detalhes_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_detalhes_texto.custom_minimum_size = Vector2(600, 420)
		coluna.add_child(_detalhes_texto)
		var fechar_detalhes := Button.new()
		fechar_detalhes.text = "Fechar detalhes"
		fechar_detalhes.pressed.connect(func() -> void: _detalhes.visible = false)
		coluna.add_child(fechar_detalhes)
	_detalhes_texto.text = _texto_detalhes(CaseQueries.pessoa(_caso, pessoa_id))
	_detalhes.visible = true


## Texto dos detalhes: motivo, álibi, depoimentos ouvidos, segredos revelados e provas coletadas
## que se relacionam com a pessoa (pelos dados do caso, só o que o jogador já encontrou).
func _texto_detalhes(pessoa: Dictionary) -> String:
	var pid := CaseQueries.texto(pessoa.get("id", ""))
	if not _conhecida(pessoa):
		return "[b]????[/b]  [color=#b0a890]%s[/color]\n\nAinda não há informação sobre esta pessoa. Interrogue-a ou espere um resultado de laboratório que a ligue a alguma prova.\n\n[b]Motivo[/b]\n????\n\n[b]Álibi[/b]\n????\n\n[b]Depoimentos ouvidos[/b]\n????\n\n[b]Provas que se relacionam com ela[/b]\n????" % _rotulo_tipo(pessoa)
	var linhas: Array[String] = []
	linhas.append("[b]%s[/b]  [color=#b0a890]%s[/color]" % [CaseQueries.texto(pessoa.get("nome", pid)), _rotulo_tipo(pessoa)])
	linhas.append("\n[b]Motivo[/b]\n%s" % CaseQueries.texto(pessoa.get("motivo", "")))
	if CaseQueries.texto(pessoa.get("tipo", "")) == "suspeito":
		linhas.append("\n[b]Atitude[/b]: %s" % CaseQueries.texto(pessoa.get("atitude", "")))

	var alibi: Variant = pessoa.get("alibi", null)
	if alibi is Dictionary:
		linhas.append("\n[b]Álibi declarado[/b]\n\"%s\"" % CaseQueries.texto(alibi.get("texto", "")))
		if CaseState.alibi_exposto(pid):
			linhas.append("[color=#ff8a80]Este álibi já foi contestado por provas.[/color]")

	linhas.append("\n[b]Depoimentos ouvidos[/b]")
	var depoimentos := CaseState.depoimentos_de(pid)
	if depoimentos.is_empty():
		linhas.append("Nenhum depoimento ainda. Interrogue esta pessoa para ouvir o que ela diz.")
	for item in depoimentos:
		linhas.append("P: %s\nR: %s" % [str(item["pergunta"]), str(item["resposta"])])
		if str(item["prova"]) != "":
			linhas.append("[i](você apresentou: %s)[/i]" % _descricao_de(str(item["prova"])))

	var segredos_mostrados := false
	for segredo in pessoa.get("segredos", []):
		if segredo is Dictionary and ("%s:%s" % [pid, CaseQueries.texto(segredo.get("id", ""))]) in CaseState.segredos_revelados:
			if not segredos_mostrados:
				linhas.append("\n[b]Segredos revelados[/b]")
				segredos_mostrados = true
			linhas.append("• %s" % CaseQueries.texto(segredo.get("descricao", "")))

	var relacionadas := _provas_relacionadas(pessoa)
	linhas.append("\n[b]Provas coletadas que se relacionam com ele[/b]")
	if relacionadas.is_empty():
		linhas.append("Nenhuma prova coletada se relaciona diretamente com esta pessoa ainda.")
	for pista_id in relacionadas:
		linhas.append("• %s" % _descricao_de(pista_id))
	return "\n".join(linhas)


## Provas (já coletadas) citadas nos dados da pessoa: álibi, segredos, respostas com prova e pistas reveladas.
func _provas_relacionadas(pessoa: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var candidatas: Array = []
	var alibi: Variant = pessoa.get("alibi", null)
	if alibi is Dictionary:
		candidatas.append_array(alibi.get("exposto_por", []))
	for segredo in pessoa.get("segredos", []):
		if segredo is Dictionary:
			candidatas.append_array(segredo.get("revelado_por_provas", []))
			candidatas.append(CaseQueries.texto(segredo.get("revela_pista", "")))
	for pergunta in pessoa.get("interrogatorio", []):
		if pergunta is Dictionary:
			var com_prova: Variant = pergunta.get("resposta_com_prova", {})
			if com_prova is Dictionary:
				candidatas.append_array(com_prova.keys())
			candidatas.append(CaseQueries.texto(pergunta.get("revela_pista", "")))
	for pista_id in candidatas:
		var texto_id := str(pista_id)
		if texto_id != "" and not (texto_id in ids) and _relacao_visivel(pessoa, texto_id):
			ids.append(texto_id)
	return ids


## Uma pessoa só fica conhecida depois de ser ouvida, ou quando um segredo dela é revelado.
## (Encontrar uma pista que contesta o álibi não basta: é preciso ouvir a pessoa ou ter laudo.)
func _conhecida(pessoa: Dictionary) -> bool:
	var pid := CaseQueries.texto(pessoa.get("id", ""))
	if not CaseState.depoimentos_de(pid).is_empty():
		return true
	for segredo in pessoa.get("segredos", []):
		if segredo is Dictionary and ("%s:%s" % [pid, CaseQueries.texto(segredo.get("id", ""))]) in CaseState.segredos_revelados:
			return true
	return false


## Uma prova só se liga à pessoa quando a prova foi coletada e há resultado de laboratório liberado
## para ela, ou quando a própria pessoa a viu num depoimento.
func _relacao_visivel(pessoa: Dictionary, pista_id: String) -> bool:
	if not (pista_id in CaseManager.found_clues):
		return false
	if CaseState.status_lab(pista_id) == "liberado":
		return true
	for item in CaseState.depoimentos_de(CaseQueries.texto(pessoa.get("id", ""))):
		if str(item["prova"]) == pista_id:
			return true
	return false


## Texto do cartão: nome, tipo e motivo quando conhecida; senão "????".
func _texto_cartao(pessoa: Dictionary) -> String:
	if not _conhecida(pessoa):
		return "????  ·  %s\n????" % _rotulo_tipo(pessoa)
	var motivo := CaseQueries.texto(pessoa.get("motivo", ""))
	return "%s · %s\n%s" % [CaseQueries.texto(pessoa.get("nome", "")), _rotulo_tipo(pessoa), motivo.left(80) + ("…" if motivo.length() > 80 else "")]


func _descricao_de(pista_id: String) -> String:
	return CaseQueries.texto(CaseQueries.pista(_caso, pista_id).get("descricao", pista_id))

