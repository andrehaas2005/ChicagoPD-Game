extends Node3D
## Controlador da investigação. Mostra o local atual em 3D e o HUD, e coordena as ações:
## mapa e viagem, pistas, laboratório, intimação, interrogatório e acusação.
## Regras ficam em CaseState, GameClock e acusacao.gd.

const LOCATION_VIEW_SCRIPT := preload("res://scripts/investigation/location_view.gd")
const HUD_SCRIPT := preload("res://scripts/investigation/hud.gd")
const MODAL_SCRIPT := preload("res://scripts/investigation/modal.gd")
const MAP_SCRIPT := preload("res://scripts/investigation/map_panel.gd")
const ACUSACAO = preload("res://scripts/investigation/acusacao.gd")
const RESULT_SCRIPT := preload("res://scripts/investigation/result.gd")
const CaseQueries = preload("res://scripts/core/case_queries.gd")
const MURAL_SCRIPT := preload("res://scripts/investigation/mural.gd")
const TIMELINE_SCRIPT := preload("res://scripts/investigation/timeline.gd")
const FEED_SCRIPT := preload("res://scripts/investigation/feed.gd")
const LAB_MINIJOGO_SCRIPT := preload("res://scripts/investigation/lab_minijogo.gd")
const CINEMA_ABERTURA := preload("res://scripts/investigation/cinema_abertura.gd")
const TRIBUNAL_SCRIPT := preload("res://scripts/investigation/tribunal.gd")

const CUSTO_INVESTIGAR_AREA := 60
const CUSTO_INTERROGATORIO := 30
const LOCAL_INICIAL := "delegacia"

var _caso: Dictionary = {}
var _local_id := LOCAL_INICIAL
var _encerrado := false
var _cena
var _hud
var _modal
var _mapa
var _camada
var _mural
var _timeline
var _feed


func _ready() -> void:
	if CaseManager.current_case.is_empty():
		GameState.go_to("case_select")
		return

	_caso = CaseManager.current_case
	CaseState.reset()
	_montar_interface()
	_feed.limpar()

	GameClock.time_changed.connect(_on_time_changed)
	GameClock.time_expired.connect(_on_tempo_esgotado)
	GameClock.reveal.connect(_on_reveal)
	CaseState.lab_ready.connect(_on_lab_ready)
	CaseManager.clue_found.connect(_on_clue_found)
	_iniciar_com_cartao()


## Cartão de abertura do caso; a primeira cena só é montada depois, para o travelling não rodar escondido.
func _iniciar_com_cartao() -> void:
	var cartao := CINEMA_ABERTURA.new()
	add_child(cartao)
	cartao.terminou.connect(_entrar_local.bind(LOCAL_INICIAL))
	cartao.tocar(str(_caso.get("titulo", "Sem título")), CaseQueries.texto(_caso.get("resumo", "")))


# ---------- Interface ----------

func _montar_interface() -> void:
	_cena = LOCATION_VIEW_SCRIPT.new()
	add_child(_cena)
	_cena.pista_clicada.connect(_on_pista_clicada)
	_cena.pessoa_clicada.connect(_pedir_interrogatorio)

	var camada := CanvasLayer.new()
	add_child(camada)
	_camada = camada
	_hud = HUD_SCRIPT.new()
	camada.add_child(_hud)
	_feed = FEED_SCRIPT.new()
	camada.add_child(_feed)  # antes do modal: os painéis de ação ficam por cima do feed
	_modal = MODAL_SCRIPT.new()
	camada.add_child(_modal)
	_mapa = MAP_SCRIPT.new()
	camada.add_child(_mapa)
	_mapa.location_chosen.connect(_entrar_local)
	_timeline = TIMELINE_SCRIPT.new()
	camada.add_child(_timeline)  # por último: fica por cima do HUD
	_hud.set_titulo(str(_caso.get("titulo", "Sem título")))


func _entrar_local(local_id: String) -> void:
	_local_id = local_id
	_atualizar()


## Reconstrói a cena 3D e o HUD com o estado atual. Não chamar a partir de um clique
## em pista, pois reconstruir a cena libera o nó clicado.
func _atualizar() -> void:
	if _encerrado:
		return
	_cena.montar(_local_id)
	_atualizar_status()
	_montar_acoes()


func _atualizar_status() -> void:
	if _encerrado:
		return
	var visiveis := 0
	var achadas := 0
	for pista in CaseQueries.pistas(_caso):
		var clue_id := CaseQueries.texto(pista.get("id", ""))
		if not CaseState.is_clue_visible(clue_id):
			continue
		visiveis += 1
		if clue_id in CaseManager.found_clues:
			achadas += 1
	var pendentes := CaseState.labs_pendentes.size()
	var laboratorio := "Laboratório: %d pendente(s)" % pendentes if pendentes > 0 else ""
	var nome_local := CaseQueries.texto(CaseQueries.local_por_id(_caso, _local_id).get("nome", _local_id))
	_hud.atualizar_status(nome_local, GameClock.format_now(), "Pistas: %d/%d" % [achadas, visiveis], laboratorio)


func _montar_acoes() -> void:
	var acoes: Array = []
	if CaseQueries.tipo_local(_caso, _local_id) == CaseQueries.TIPO_DELEGACIA:
		acoes.append(_acao("Interrogar", _listar_interrogaveis))
		acoes.append(_acao("Enviar pista ao laboratório", _listar_envio_lab))
		acoes.append(_acao("Laboratório", _mostrar_laboratorio))
		acoes.append(_acao("Intimar testemunha", _listar_intimacoes))
		acoes.append(_acao("Pedir mandado ao juiz", _listar_mandatos))
		acoes.append(_acao("Consultar sistema", _listar_consultas))
		acoes.append(_acao("Pedir dica ao capitão (60 min)", _pedir_dica))
		acoes.append(_acao("Acusar", _listar_acusados))
	else:
		acoes.append(_acao("Investigar a área (%d min)" % CUSTO_INVESTIGAR_AREA, _investigar_area))
		acoes.append(_acao("Interrogar no local (%d min)" % CUSTO_INTERROGATORIO, _listar_interrogaveis))
	acoes.append(_acao("Mural de pistas", _abrir_mural))
	acoes.append(_acao("Linha do tempo", _abrir_linha_do_tempo))
	if CaseQueries.locais(_caso).size() > 1:
		acoes.append(_acao("Mapa", _abrir_mapa))
	acoes.append(_acao("Sair do caso", func() -> void: GameState.go_to("case_select")))
	_hud.definir_acoes(acoes)


func _acao(texto: String, metodo: Callable) -> Dictionary:
	return {"texto": texto, "acao": metodo, "ativo": true}


# ---------- Tempo e eventos ----------

func _on_time_changed(_minutos: int) -> void:
	_atualizar()


func _on_tempo_esgotado() -> void:
	_encerrar({
		"solved": false,
		"motivo": "O prazo de 48 horas expirou",
		"acusado": "",
		"caso": str(_caso.get("titulo", "")),
	})


func _on_reveal(texto: String, _clue_id: String) -> void:
	_hud.mostrar_plantao(texto)


func _on_lab_ready(clue_id: String, conclusao: String) -> void:
	_hud.mostrar_plantao("Laboratório pronto: %s\n%s" % [_descricao_pista(clue_id), conclusao])


func _on_clue_found(clue_id: String) -> void:
	_cena.marcar_pista(clue_id)
	_atualizar_status()


func _encerrar(resultado: Dictionary) -> void:
	if _encerrado:
		return
	_encerrado = true
	RESULT_SCRIPT.resultado = resultado
	GameState.finish_case(bool(resultado.get("solved", false)))
	GameState.go_to("result")


func _descricao_pista(clue_id: String) -> String:
	return CaseQueries.texto(CaseQueries.pista(_caso, clue_id).get("descricao", clue_id))


# ---------- Pistas e área ----------

func _on_pista_clicada(clue_id: String, descricao: String) -> void:
	if _encerrado:
		return
	CaseManager.mark_clue_found(clue_id)
	_hud.definir_info("Pista coletada: %s" % descricao)


func _investigar_area() -> void:
	_modal.fechar()
	GameClock.advance_minutes(CUSTO_INVESTIGAR_AREA)
	if _encerrado:
		return
	var achadas: PackedStringArray = []
	for pista in CaseState.pistas_no_local(_local_id):
		var clue_id := CaseQueries.texto(pista.get("id", ""))
		if not (clue_id in CaseManager.found_clues):
			CaseManager.mark_clue_found(clue_id)
			achadas.append(CaseQueries.texto(pista.get("descricao", clue_id)))
	if achadas.is_empty():
		_hud.definir_info("Investigação da área concluída (%d min). Nada novo neste local." % CUSTO_INVESTIGAR_AREA)
	else:
		_hud.definir_info("Investigação da área concluída (%d min). Pistas coletadas:\n- %s" % [CUSTO_INVESTIGAR_AREA, "\n- ".join(achadas)])
	_atualizar()


func _abrir_mapa() -> void:
	_modal.fechar()
	_mapa.abrir(_caso, _local_id)


# ---------- Interrogatório ----------

func _listar_interrogaveis() -> void:
	_modal.abrir("Interrogar")
	var pessoas := CaseState.pessoas_no_local(_local_id)
	if pessoas.is_empty():
		_modal.adicionar_texto("Ninguém disponível neste local no horário atual.")
	for pessoa in pessoas:
		_modal.adicionar_botao("%s (%s)" % [CaseQueries.texto(pessoa.get("nome", "?")), CaseQueries.texto(pessoa.get("tipo", ""))], _pedir_interrogatorio.bind(pessoa))
	_modal.adicionar_botao("Fechar", _modal.fechar)


func _pedir_interrogatorio(pessoa: Dictionary) -> void:
	_modal.abrir("Interrogar %s" % CaseQueries.texto(pessoa.get("nome", "?")))
	_modal.adicionar_texto("Cada pergunta leva %d minutos." % CUSTO_INTERROGATORIO)
	_modal.adicionar_botao("Começar interrogatório", _interrogar.bind(pessoa))
	_modal.adicionar_botao("Cancelar", _modal.fechar)


## Abre o painel de interrogatório. O tempo é cobrado pelo próprio painel, por pergunta.
func _interrogar(pessoa: Dictionary) -> void:
	_modal.fechar()
	if _encerrado:
		return
	var camada := CanvasLayer.new()
	add_child(camada)
	var painel: InterrogationPanel = InterrogationPanel.new()
	camada.add_child(painel)
	painel.add_to_group("modal")  # o detetive não anda durante o interrogatório
	painel.setup(pessoa, CaseManager.found_clues.duplicate())
	painel.closed.connect(_on_interrogatorio_fechado.bind(camada))
	_hud.definir_info("Interrogatório de %s em andamento." % CaseQueries.texto(pessoa.get("nome", "?")))


func _on_interrogatorio_fechado(_subject_id: String, summary: Dictionary, camada: CanvasLayer) -> void:
	camada.queue_free()
	var partes: PackedStringArray = []
	if not summary.get("pistas_reveladas", []).is_empty():
		partes.append("Pistas reveladas: %d" % summary["pistas_reveladas"].size())
	if not summary.get("segredos_revelados", []).is_empty():
		partes.append("Segredos revelados: %d" % summary["segredos_revelados"].size())
	if summary.get("alibi_exposto", false):
		partes.append("Álibi exposto")
	_hud.definir_info("Interrogatório encerrado. %s" % (", ".join(partes) if not partes.is_empty() else "Nada de novo."))
	_atualizar()


# ---------- Delegacia: laboratório e intimação ----------

func _listar_envio_lab() -> void:
	_modal.abrir("Enviar pista ao laboratório")
	var pistas := CaseState.pistas_para_lab()
	if pistas.is_empty():
		_modal.adicionar_texto("Nenhuma pista coletada pode ser analisada agora.")
	for pista in pistas:
		_modal.adicionar_botao(CaseQueries.texto(pista.get("descricao", "")), _enviar_lab.bind(CaseQueries.texto(pista.get("id", ""))))
	_modal.adicionar_botao("Fechar", _modal.fechar)


func _enviar_lab(clue_id: String) -> void:
	_modal.fechar()
	if CaseState.send_to_lab(clue_id):
		_hud.definir_info("Pista enviada ao laboratório. Veja o resultado em Laboratório.")
		_abrir_minijogo_lab(clue_id)
	else:
		_hud.definir_info("Não foi possível enviar esta pista ao laboratório.")
	_atualizar_status()


func _mostrar_laboratorio() -> void:
	_modal.abrir("Laboratório")
	if CaseState.labs_pendentes.is_empty() and CaseState.labs_liberados.is_empty():
		_modal.adicionar_texto("Nenhuma prova enviada ainda.")
	for lab in CaseState.labs_pendentes:
		_modal.adicionar_texto("Em análise: %s\nResultado em %s." % [_descricao_pista(str(lab["clue_id"])), GameClock.format_at(int(lab["ready_at_minutes"]))])
	for lab in CaseState.labs_liberados:
		_modal.adicionar_texto("Resultado: %s\n%s" % [_descricao_pista(str(lab["clue_id"])), str(lab["conclusao"])])
	_modal.adicionar_botao("Fechar", _modal.fechar)


func _listar_intimacoes() -> void:
	_modal.abrir("Intimar testemunha")
	_modal.adicionar_texto("A testemunha chega à delegacia %d minutos depois da intimação." % CaseState.TEMPO_INTIMACAO_MINUTOS)
	var testemunhas := CaseState.testemunhas_intimaveis()
	if testemunhas.is_empty():
		_modal.adicionar_texto("Não há testemunhas a intimar.")
	for testemunha in testemunhas:
		_modal.adicionar_botao(CaseQueries.texto(testemunha.get("nome", "?")), _intimar.bind(CaseQueries.texto(testemunha.get("id", ""))))
	_modal.adicionar_botao("Fechar", _modal.fechar)


func _intimar(person_id: String) -> void:
	_modal.fechar()
	if CaseState.subpoena(person_id):
		var chegada := CaseState.intimacao(person_id)
		_hud.definir_info("Testemunha intimada. Chega à delegacia em %s." % GameClock.format_at(int(chegada["chegada_em_minutos"])))
	else:
		_hud.definir_info("Não foi possível intimar esta testemunha.")
	_atualizar_status()


# ---------- Mandados e consultas (só na delegacia) ----------

const ROTULO_TIPO_CONSULTA := {
	"endereco": "Endereço",
	"telefone": "Telefone",
	"historico": "Histórico do celular",
	"agora": "Celular ativo agora",
}


func _listar_mandatos() -> void:
	_modal.abrir("Pedir mandado ao juiz")
	_modal.adicionar_texto("O juiz só concede com indícios: pistas que apontam para a pessoa. Cada pedido leva o tempo indicado.")
	var pendentes := 0
	for mandato in CaseQueries.mandatos(_caso):
		var mandato_id := CaseQueries.texto(mandato.get("id", ""))
		if mandato_id in CaseState.mandatos_concedidos:
			continue
		pendentes += 1
		var alvo := CaseQueries.pessoa(_caso, CaseQueries.texto(mandato.get("alvo", "")))
		var tipo := "Busca e apreensão" if CaseQueries.texto(mandato.get("tipo", "")) == "busca" else "Registros de telefone e dados"
		_modal.adicionar_botao("%s: %s (%d min)" % [tipo, CaseQueries.texto(alvo.get("nome", "?")), int(mandato.get("custo_minutos", 60))], _pedir_mandato.bind(mandato_id))
	if pendentes == 0:
		_modal.adicionar_texto("Nenhum mandado a pedir.")
	_modal.adicionar_botao("Fechar", _modal.fechar)


func _pedir_mandato(mandato_id: String) -> void:
	var resultado := CaseState.pedir_mandato(mandato_id)
	_mostrar_resultado_sistema("Juiz de plantão", str(resultado.get("texto", "")))
	if not _encerrado:
		_atualizar()


func _listar_consultas() -> void:
	_modal.abrir("Consultar sistema")
	_modal.adicionar_texto("A sala de dados (tecnologia) só libera registros com mandado concedido.")
	var disponiveis := 0
	for consulta in CaseQueries.consultas(_caso):
		var consulta_id := CaseQueries.texto(consulta.get("id", ""))
		if consulta_id in CaseState.consultas_feitas or not (CaseQueries.texto(consulta.get("requer_mandato", "")) in CaseState.mandatos_concedidos):
			continue
		disponiveis += 1
		var alvo := CaseQueries.pessoa(_caso, CaseQueries.texto(consulta.get("alvo", "")))
		var rotulo := str(ROTULO_TIPO_CONSULTA.get(CaseQueries.texto(consulta.get("tipo", "")), "Consulta"))
		_modal.adicionar_botao("%s: %s (%d min)" % [rotulo, CaseQueries.texto(alvo.get("nome", "?")), int(consulta.get("custo_minutos", 30))], _consultar.bind(consulta_id))
	if disponiveis == 0:
		_modal.adicionar_texto("Nenhuma consulta disponível. Peça mandados ao juiz quando tiver indícios.")
	_modal.adicionar_botao("Fechar", _modal.fechar)


func _consultar(consulta_id: String) -> void:
	var resultado := CaseState.consultar(consulta_id)
	_mostrar_resultado_sistema("Sala de dados", str(resultado.get("texto", "")))
	if not _encerrado:
		_atualizar()


## Mostra a resposta do juiz ou da sala de dados no modal, com o botão de fechar.
func _mostrar_resultado_sistema(origem: String, texto: String) -> void:
	_modal.abrir(origem)
	_modal.adicionar_texto(texto)
	_modal.adicionar_botao("Fechar", _modal.fechar)


# ---------- Acusação (só na delegacia) ----------

func _listar_acusados() -> void:
	_modal.abrir("Acusar suspeito")
	_modal.adicionar_texto("Escolha quem é o culpado. A decisão encerra o caso.")
	for suspeito in CaseQueries.pessoas(_caso):
		if str(suspeito.get("tipo", "")) == "suspeito" and not (CaseQueries.texto(suspeito.get("id", "")) in CaseState.absolvidos):
			_modal.adicionar_botao(CaseQueries.texto(suspeito.get("nome", "?")), _pedir_acusacao.bind(suspeito))
	_modal.adicionar_botao("Cancelar", _modal.fechar)


func _pedir_acusacao(suspeito: Dictionary) -> void:
	_modal.abrir("Levar ao julgamento")
	_modal.adicionar_texto("Acusar %s. Escolha as provas que o promotor apresenta ao júri:" % CaseQueries.texto(suspeito.get("nome", "?")))
	if _mural != null:
		var solucao: Dictionary = _caso.get("solucao", {})
		var verificacao: Dictionary = _mural.verificar_ligacoes(CaseQueries.texto(solucao.get("culpado", "")), solucao.get("pistas_necessarias", []))
		_modal.adicionar_texto("Mural: %s" % str(verificacao.get("texto", "")))
	var marcadas: Array = []  # [CheckBox, id da pista]
	for pista_id in CaseManager.found_clues:
		var caixa := CheckBox.new()
		caixa.text = _descricao_pista(str(pista_id))
		caixa.button_pressed = true
		_modal.adicionar_controle(caixa)
		marcadas.append([caixa, str(pista_id)])
	if marcadas.is_empty():
		_modal.adicionar_texto("Nenhuma prova coletada: o júri vai julgar sem provas materiais.")
	_modal.adicionar_botao("Levar ao júri", _levar_a_julgamento.bind(suspeito, marcadas))
	_modal.adicionar_botao("Voltar à lista", _listar_acusados)


## Leva o réu ao tribunal com as provas marcadas. O resultado volta por _on_julgamento_concluido.
func _levar_a_julgamento(suspeito: Dictionary, marcadas: Array) -> void:
	_modal.fechar()
	var provas: Array = []
	for item in marcadas:
		if item[0].button_pressed:
			provas.append(item[1])
	_cena.visible = false
	_camada.visible = false
	var tribunal = TRIBUNAL_SCRIPT.new()
	add_child(tribunal)
	tribunal.concluido.connect(_on_julgamento_concluido.bind(tribunal, suspeito))
	tribunal.iniciar(_caso, CaseQueries.texto(suspeito.get("id", "")), provas)


func _on_julgamento_concluido(resultado: Dictionary, tribunal, suspeito: Dictionary) -> void:
	tribunal.queue_free()
	_cena.visible = true
	_camada.visible = true
	GameClock.advance_minutes(int(resultado.get("minutos", 0)))
	if _encerrado:
		return
	var nome := CaseQueries.texto(suspeito.get("nome", "?"))
	if bool(resultado.get("condenado", false)):
		_encerrar(ACUSACAO.avaliar(_caso, suspeito))
		return
	var suspeito_id := CaseQueries.texto(suspeito.get("id", ""))
	if not (suspeito_id in CaseState.absolvidos):
		CaseState.absolvidos.append(suspeito_id)
	_hud.definir_info("%s foi absolvido. Deixa de ser suspeito; a investigação continua." % nome)
	_atualizar()


# ---------- Cinema, mural, linha do tempo, dica e laboratório ----------

func _abrir_mural() -> void:
	_modal.fechar()
	if _mural == null:
		_mural = MURAL_SCRIPT.new()
		_mural.name = "Mural"
		_hud.get_parent().add_child(_mural)
	_mural.abrir(_caso)


func _abrir_linha_do_tempo() -> void:
	_modal.fechar()
	_timeline.abrir(_caso)


func _pedir_dica() -> void:
	var resultado: Dictionary = CaseState.dica_capitao()
	_hud.definir_info(str(resultado.get("texto", "")))
	if not _encerrado:
		_atualizar()


## Minijogo do laboratório: acertar as marcas adianta o resultado em 2 horas.
func _abrir_minijogo_lab(clue_id: String) -> void:
	var minijogo := LAB_MINIJOGO_SCRIPT.new()
	_modal.get_parent().add_child(minijogo)
	minijogo.resultado.connect(_on_lab_minijogo_resultado)
	minijogo.iniciar(clue_id, _descricao_pista(clue_id))


func _on_lab_minijogo_resultado(clue_id: String, sucesso: bool) -> void:
	if not sucesso or _encerrado:
		return
	for lab in CaseState.labs_pendentes:
		if str(lab["clue_id"]) == clue_id:
			lab["ready_at_minutes"] = maxi(GameClock.now_minutes(), int(lab["ready_at_minutes"]) - 120)
	CaseState.check_labs()
	_hud.definir_info("Análise rápida: o laboratório confirmou as marcas.")

