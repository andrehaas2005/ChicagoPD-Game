extends Control
## Minijogo de análise do laboratório. Camada de interface: não altera CaseState.
## O jogador vê as marcas observadas na pista e escolhe, numa grade 3x3, as peças que
## batem com elas. Dois erros seguidos da escolha encerram a análise sem acerto.
##
## Sinais:
##   resultado(clue_id, sucesso): emitido uma vez, ao concluir a análise (acerto ou falha).
##   fechar(): emitido ao sair do minijogo (botão Continuar, ou Cancelar antes de concluir).
##     Cancelar não emite resultado: o laboratório segue o prazo normal.
## Depois de fechar, o minijogo se remove com queue_free(). O integrador decide o efeito.

signal resultado(clue_id: String, sucesso: bool)
signal fechar

const TENTATIVAS := 2
const TAMANHO_GRADE := 9
const MAX_MARCAS := 3
const MARCAS_POSSIVEIS := ["Sangue", "Fibra", "Digital", "Vidro", "Tinta", "Metal", "Cimento", "Couro", "Pólvora"]

var _clue_id := ""
var _marcas: Array[String] = []
var _selecionadas: Array[String] = []
var _tentativas_restantes := TENTATIVAS
var _concluido := false
var _botoes: Dictionary = {}  # marca -> Button
var _aviso: Label
var _lista_marcas: Label
var _area_acoes: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_to_group("modal")  # o detetive não anda durante a análise


## Abre o minijogo para a pista. `marcas` (opcional) são as marcas observadas na pista.
## Sem `marcas`, as marcas são as palavras de MARCAS_POSSIVEIS que aparecem em `descricao`.
func iniciar(clue_id: String, descricao: String, marcas: Array = []) -> void:
	_clue_id = clue_id
	_marcas = _resolver_marcas(descricao, marcas)
	_selecionadas.clear()
	_tentativas_restantes = TENTATIVAS
	_concluido = false
	_montar(descricao)
	visible = true


func _resolver_marcas(descricao: String, marcas: Array) -> Array[String]:
	var lista: Array[String] = []
	for marca in marcas:
		if str(marca) != "" and not (str(marca) in lista):
			lista.append(str(marca))
	if lista.is_empty():
		var texto := descricao.to_lower()
		for palavra in MARCAS_POSSIVEIS:
			if texto.contains(palavra.to_lower()):
				lista.append(palavra)
	# Completa até 2 marcas com um critério fixo (sem dados novos): a ordem depende do ID da pista.
	var deslocamento := absi(hash(_clue_id))
	var i := 0
	while lista.size() < 2 and i < MARCAS_POSSIVEIS.size():
		var candidata: String = MARCAS_POSSIVEIS[(deslocamento + i) % MARCAS_POSSIVEIS.size()]
		if not (candidata in lista):
			lista.append(candidata)
		i += 1
	while lista.size() > MAX_MARCAS:
		lista.pop_back()
	return lista


func _montar(descricao: String) -> void:
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	_botoes.clear()

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(560, 0)
	centro.add_child(painel)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 12)
	painel.add_child(caixa)

	var titulo := Label.new()
	titulo.text = "Laboratório: análise da prova"
	titulo.add_theme_font_size_override("font_size", 24)
	caixa.add_child(titulo)

	var pista := Label.new()
	pista.text = descricao
	pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(pista)

	_lista_marcas = Label.new()
	_lista_marcas.text = "Marcas observadas: %s. Escolha %d peça(s) da grade que batem com elas." % [", ".join(_marcas), _marcas.size()]
	_lista_marcas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(_lista_marcas)

	caixa.add_child(_montar_grade())

	_aviso = Label.new()
	_aviso.text = "Tentativas restantes: %d" % _tentativas_restantes
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(_aviso)

	_area_acoes = HBoxContainer.new()
	_area_acoes.add_theme_constant_override("separation", 12)
	_area_acoes.alignment = BoxContainer.ALIGNMENT_END
	caixa.add_child(_area_acoes)
	_mostrar_acoes_iniciais()


func _montar_grade() -> GridContainer:
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 8)
	var pecas: Array[String] = _marcas.duplicate()
	for palavra in MARCAS_POSSIVEIS:
		if pecas.size() >= TAMANHO_GRADE:
			break
		if not (palavra in pecas):
			pecas.append(palavra)
	pecas.shuffle()
	for marca in pecas:
		var peca := Button.new()
		peca.text = marca
		peca.toggle_mode = true
		peca.custom_minimum_size = Vector2(150, 72)
		peca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		peca.toggled.connect(_ao_alternar_peca.bind(marca))
		grade.add_child(peca)
		_botoes[marca] = peca
	return grade


func _mostrar_acoes_iniciais() -> void:
	for filho in _area_acoes.get_children():
		_area_acoes.remove_child(filho)
		filho.queue_free()
	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.custom_minimum_size = Vector2(140, 44)
	cancelar.pressed.connect(_fechar)
	_area_acoes.add_child(cancelar)
	var confirmar := Button.new()
	confirmar.text = "Confirmar escolha"
	confirmar.custom_minimum_size = Vector2(200, 44)
	confirmar.pressed.connect(_confirmar_escolha)
	_area_acoes.add_child(confirmar)


func _mostrar_acao_final() -> void:
	for filho in _area_acoes.get_children():
		_area_acoes.remove_child(filho)
		filho.queue_free()
	var continuar := Button.new()
	continuar.text = "Continuar"
	continuar.custom_minimum_size = Vector2(200, 44)
	continuar.pressed.connect(_fechar)
	_area_acoes.add_child(continuar)


func _ao_alternar_peca(pressionada: bool, marca: String) -> void:
	if _concluido:
		return
	if pressionada:
		if _selecionadas.size() >= _marcas.size():
			_botoes[marca].set_pressed_no_signal(false)
			_aviso.text = "Você já escolheu %d peça(s). Desmarque uma antes." % _marcas.size()
			return
		_selecionadas.append(marca)
	else:
		_selecionadas.erase(marca)


func _confirmar_escolha() -> void:
	if _concluido:
		return
	if _selecionadas.size() != _marcas.size():
		_aviso.text = "Escolha exatamente %d peça(s)." % _marcas.size()
		return
	var acertou := true
	for marca in _marcas:
		if not (marca in _selecionadas):
			acertou = false
	if acertou:
		_concluir(true)
		return
	_tentativas_restantes -= 1
	if _tentativas_restantes <= 0:
		_concluir(false)
	else:
		_aviso.text = "Nenhuma combinação confere. Tentativas restantes: %d." % _tentativas_restantes


func _concluir(sucesso: bool) -> void:
	_concluido = true
	for botao in _botoes.values():
		botao.disabled = true
	_aviso.text = "Análise concluída: as marcas conferem. O resultado sai mais cedo." if sucesso else "Análise concluída sem correspondência. O resultado segue o prazo normal."
	_mostrar_acao_final()
	resultado.emit(_clue_id, sucesso)


func _fechar() -> void:
	visible = false
	fechar.emit()
	queue_free()
