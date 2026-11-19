extends Node
## Autoload: estado do caso em andamento. As pistas coletadas ficam em CaseManager.found_clues;
## aqui ficam laboratório, intimações, pistas liberadas por reviravoltas, segredos e alibis expostos.
## Consultas sobre o caso (locais, pessoas, rotinas) ficam em case_queries.gd.

const CaseQueries = preload("res://scripts/core/case_queries.gd")
const TEMPO_INTIMACAO_MINUTOS := 120
const TEMPO_DICA_MINUTOS := 60

signal lab_ready(clue_id: String, conclusao: String)
signal clue_unlocked(clue_id: String)
signal alibi_exposed(suspect_id: String)
## Emitido pela investigação quando o jogador inicia um interrogatório (30 min já gastos).
## Quem interroga conecta a este signal. location_id é o local onde ocorre.
signal interrogation_requested(character_id: String, location_id: String)
## Emitido a cada fala do capitão (dica ou recusa de dica). O feed de plantão escuta este signal.
signal dica_capitao_dada(texto: String)

var labs_pendentes: Array[Dictionary] = []  # {clue_id, ready_at_minutes}
var labs_liberados: Array[Dictionary] = []  # {clue_id, conclusao}
var intimacoes: Array[Dictionary] = []  # {id, chegada_em_minutos}
var pistas_liberadas: Array[String] = []  # pistas liberadas por reviravoltas
var segredos_revelados: Array[String] = []
var alibis_expostos: Array[String] = []
var mandatos_concedidos: Array[String] = []  # ids de mandatos já concedidos pelo juiz
var consultas_feitas: Array[String] = []  # ids de consultas ao sistema já realizadas
var locais_revelados: Array[String] = []  # locais ocultos que já apareceram no mapa
var localizacoes: Array[Dictionary] = []  # {person_id, local, ate_minutos}: onde a pessoa foi localizada
var dicas_usadas: int = 0  # quantas vezes o jogador pediu dica ao capitão neste caso
var absolvidos: Array[String] = []  # réus absolvidos em julgamento: deixam de ser suspeitos
var depoimentos: Array[Dictionary] = []  # {person_id, pergunta, resposta, prova}: o que o jogador já ouviu


func _ready() -> void:
	GameClock.time_changed.connect(_on_time_changed)
	GameClock.reveal.connect(_on_reveal)
	CaseManager.clue_found.connect(_on_clue_found)


## Limpa o estado e agenda as reviravoltas do caso atual. Chamado ao iniciar o caso.
func reset() -> void:
	labs_pendentes.clear()
	labs_liberados.clear()
	intimacoes.clear()
	pistas_liberadas.clear()
	segredos_revelados.clear()
	alibis_expostos.clear()
	mandatos_concedidos.clear()
	consultas_feitas.clear()
	locais_revelados.clear()
	localizacoes.clear()
	absolvidos.clear()
	depoimentos.clear()
	dicas_usadas = 0
	GameClock.reset()
	GameClock.schedule_reversals(CaseManager.current_case.get("reviravoltas", []))


# ---------- Laboratório ----------

## Envia uma pista coletada ao laboratório do caso. Não gasta tempo; o resultado chega depois.
func send_to_lab(clue_id: String) -> bool:
	if not (clue_id in CaseManager.found_clues) or status_lab(clue_id) != "":
		return false
	var lab := CaseQueries.laboratorio(CaseManager.current_case, clue_id)
	if lab.is_empty():
		return false
	var minutos := int(round(float(lab.get("tempo_horas", 0)) * 60.0))
	labs_pendentes.append({"clue_id": clue_id, "ready_at_minutes": GameClock.now_minutes() + minutos})
	check_labs()
	return true


## Libera os resultados de laboratório cujo prazo já passou. Emite lab_ready para cada um.
func check_labs() -> void:
	var agora := GameClock.now_minutes()
	for lab in labs_pendentes.duplicate():
		if int(lab["ready_at_minutes"]) > agora:
			continue
		labs_pendentes.erase(lab)
		var clue_id := str(lab["clue_id"])
		var conclusao := CaseQueries.texto(CaseQueries.laboratorio(CaseManager.current_case, clue_id).get("conclusao", ""))
		labs_liberados.append({"clue_id": clue_id, "conclusao": conclusao})
		lab_ready.emit(clue_id, conclusao)


## "pendente", "liberado" ou "" (nunca enviada).
func status_lab(clue_id: String) -> String:
	for lab in labs_pendentes:
		if str(lab["clue_id"]) == clue_id:
			return "pendente"
	for lab in labs_liberados:
		if str(lab["clue_id"]) == clue_id:
			return "liberado"
	return ""


## Pistas coletadas que têm laboratório e ainda não foram enviadas.
func pistas_para_lab() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var caso := CaseManager.current_case
	for pista in CaseQueries.pistas(caso):
		var clue_id := CaseQueries.texto(pista.get("id", ""))
		if not (clue_id in CaseManager.found_clues):
			continue
		if CaseQueries.laboratorio(caso, clue_id).is_empty() or status_lab(clue_id) != "":
			continue
		lista.append(pista)
	return lista


# ---------- Intimações ----------

## Intima uma testemunha. Ela chega à delegacia em TEMPO_INTIMACAO_MINUTOS (não gasta tempo agora).
func subpoena(witness_id: String) -> bool:
	var pessoa := CaseQueries.pessoa(CaseManager.current_case, witness_id)
	if pessoa.is_empty() or str(pessoa.get("tipo", "")) != "testemunha" or not bool(pessoa.get("intimavel", false)):
		return false
	if not intimacao(witness_id).is_empty():
		return false
	intimacoes.append({"id": witness_id, "chegada_em_minutos": GameClock.now_minutes() + TEMPO_INTIMACAO_MINUTOS})
	return true


## Intimação da testemunha, ou {} se ela não foi intimada.
func intimacao(person_id: String) -> Dictionary:
	for item in intimacoes:
		if str(item["id"]) == person_id:
			return item
	return {}


## Testemunhas que podem ser intimadas agora (intimavel e ainda sem intimação).
func testemunhas_intimaveis() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for pessoa in CaseQueries.pessoas(CaseManager.current_case):
		if str(pessoa.get("tipo", "")) != "testemunha" or not bool(pessoa.get("intimavel", false)):
			continue
		if intimacao(str(pessoa.get("id", ""))).is_empty():
			lista.append(pessoa)
	return lista


# ---------- Presença, locais e pistas ----------

## True se a pessoa está no local agora: pela rotina, ou por intimação já chegada (delegacia).
## Suspeito sem rotina fica sempre na delegacia.
func is_present(character_id: String, location_id: String) -> bool:
	var caso := CaseManager.current_case
	var pessoa := CaseQueries.pessoa(caso, character_id)
	if pessoa.is_empty() or character_id in absolvidos:
		return false
	for loc in localizacoes_ativas():
		if str(loc["person_id"]) == character_id and str(loc["local"]) == location_id:
			return true
	var rotina: Array = pessoa.get("rotina", [])
	var dia_hora := GameClock.day_and_hour()
	if CaseQueries.em_rotina(rotina, dia_hora.x, dia_hora.y, location_id):
		return true
	if CaseQueries.tipo_local(caso, location_id) != CaseQueries.TIPO_DELEGACIA:
		return false
	if _intimacao_chegou(character_id):
		return true
	return rotina.is_empty() and str(pessoa.get("tipo", "")) == "suspeito"


## Pessoas (suspeitos e testemunhas) presentes no local agora.
func pessoas_no_local(location_id: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for pessoa in CaseQueries.pessoas(CaseManager.current_case):
		if is_present(str(pessoa.get("id", "")), location_id):
			lista.append(pessoa)
	return lista


## Pistas do local, incluindo as sem local (disponíveis em qualquer lugar) e as já coletadas.
## Pistas ocultas por reviravolta só aparecem depois de liberadas.
func pistas_no_local(location_id: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for pista in CaseQueries.pistas(CaseManager.current_case):
		var local := CaseQueries.texto(pista.get("local", ""))
		if local != "" and local != location_id:
			continue
		if is_clue_visible(CaseQueries.texto(pista.get("id", ""))):
			lista.append(pista)
	return lista


func is_clue_visible(clue_id: String) -> bool:
	if not CaseQueries.pista_oculta(CaseManager.current_case, clue_id):
		return true
	return clue_id in pistas_liberadas


# ---------- Mandados, consultas e localizações ----------

## Locais do caso que já podem aparecer no mapa (os ocultos só depois de revelados).
func locais_visiveis() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for local in CaseQueries.locais(CaseManager.current_case):
		if not CaseQueries.local_oculto(local) or CaseQueries.texto(local.get("id", "")) in locais_revelados:
			lista.append(local)
	return lista


## Localizações de pessoas que ainda valem agora (ex.: celular ativo nesta hora).
func localizacoes_ativas() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var agora := GameClock.now_minutes()
	for loc in localizacoes:
		if agora < int(loc["ate_minutos"]):
			lista.append(loc)
	return lista


## Pede o mandado ao juiz. Gasta o tempo do pedido. Concede se as pistas justificativas
## encontradas bastam; senão, nega com o motivo do juiz. Devolve {ok, texto}.
func pedir_mandato(mandato_id: String) -> Dictionary:
	var caso := CaseManager.current_case
	var mandato := CaseQueries.mandato(caso, mandato_id)
	if mandato.is_empty():
		return {"ok": false, "texto": "Mandado inexistente."}
	if mandato_id in mandatos_concedidos:
		return {"ok": false, "texto": "Este mandado já foi concedido."}
	GameClock.advance_minutes(int(mandato.get("custo_minutos", 60)))
	var achadas := 0
	for pista_id in mandato.get("justificativa", []):
		if str(pista_id) in CaseManager.found_clues:
			achadas += 1
	if achadas < int(mandato.get("pistas_minimas", 1)):
		return {"ok": false, "texto": CaseQueries.texto(mandato.get("motivo_negativa", "O juiz não viu indícios suficientes."))}
	mandatos_concedidos.append(mandato_id)
	var local_busca := CaseQueries.texto(mandato.get("revela_local", ""))
	if local_busca != "" and not (local_busca in locais_revelados):
		locais_revelados.append(local_busca)  # o endereço do suspeito aparece no mapa
	for pista_id in mandato.get("revela_pistas", []):
		_liberar_pista(str(pista_id))
	return {"ok": true, "texto": CaseQueries.texto(mandato.get("concedido_texto", "Mandado concedido."))}


## Roda uma consulta ao sistema (endereço, telefone, histórico ou localização do celular).
## Precisa do mandado da consulta. Gasta o tempo da consulta. Devolve {ok, texto}.
func consultar(consulta_id: String) -> Dictionary:
	var caso := CaseManager.current_case
	var consulta := CaseQueries.consulta(caso, consulta_id)
	if consulta.is_empty():
		return {"ok": false, "texto": "Consulta inexistente."}
	if consulta_id in consultas_feitas:
		return {"ok": false, "texto": "Esta consulta já foi feita."}
	if not (str(consulta.get("requer_mandato", "")) in mandatos_concedidos):
		return {"ok": false, "texto": "Sem mandado, a sala de dados não libera este registro."}
	GameClock.advance_minutes(int(consulta.get("custo_minutos", 30)))
	consultas_feitas.append(consulta_id)
	var revela_local := CaseQueries.texto(consulta.get("revela_local", ""))
	if revela_local != "" and not (revela_local in locais_revelados):
		locais_revelados.append(revela_local)
	var loc: Variant = consulta.get("localizacao", null)
	if loc is Dictionary:
		localizacoes.append({
			"person_id": CaseQueries.texto(consulta.get("alvo", "")),
			"local": CaseQueries.texto(loc.get("local", "")),
			"ate_minutos": int(round(float(loc.get("ate_hora", 0)) * 60.0)),
		})
	for pista_id in consulta.get("revela_pistas", []):
		_liberar_pista(str(pista_id))
	return {"ok": true, "texto": CaseQueries.texto(consulta.get("resultado", ""))}


func _liberar_pista(clue_id: String) -> void:
	if clue_id == "" or clue_id in pistas_liberadas:
		return
	pistas_liberadas.append(clue_id)
	clue_unlocked.emit(clue_id)


func revelar_segredo(secret_id: String) -> void:
	if not (secret_id in segredos_revelados):
		segredos_revelados.append(secret_id)


## Guarda uma pergunta e a resposta que o jogador recebeu (aparece nos detalhes do mural).
func registrar_depoimento(person_id: String, pergunta: String, resposta: String, prova_id: String) -> void:
	depoimentos.append({"person_id": person_id, "pergunta": pergunta, "resposta": resposta, "prova": prova_id})


func depoimentos_de(person_id: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for item in depoimentos:
		if str(item["person_id"]) == person_id:
			lista.append(item)
	return lista


func alibi_exposto(suspect_id: String) -> bool:
	return suspect_id in alibis_expostos


func _intimacao_chegou(person_id: String) -> bool:
	var item := intimacao(person_id)
	return not item.is_empty() and GameClock.now_minutes() >= int(item["chegada_em_minutos"])


# ---------- Capitão ----------

## Dica do capitão: aponta o local da primeira pista necessária que o jogador ainda não tem.
## Gasta TEMPO_DICA_MINUTOS (só quando há dica a dar). Não revela a pista nem o culpado.
## Devolve {ok, texto} e emite dica_capitao_dada.
func dica_capitao() -> Dictionary:
	var caso := CaseManager.current_case
	if caso.is_empty():
		return _fala_capitao(false, "Não há caso em andamento.")
	if GameClock.is_expired():
		return _fala_capitao(false, "O prazo acabou. Não há mais tempo para pistas.")
	var solucao: Dictionary = caso.get("solucao", {})
	var pendente := ""
	for clue_id in solucao.get("pistas_necessarias", []):
		if not (str(clue_id) in CaseManager.found_clues):
			pendente = str(clue_id)
			break
	if pendente == "":
		var a_ouvir := _pessoa_a_ouvir()
		if a_ouvir.is_empty():
			return _fala_capitao(false, "O capitão já sabe o que você sabe. Vá para a acusação.")
		GameClock.advance_minutes(TEMPO_DICA_MINUTOS)
		dicas_usadas += 1
		return _fala_capitao(true, "O capitão olha o mural e diz: 'Você já tem a prova sobre %s. Falta ouvir %s, que pode explicá-la.'" % [a_ouvir["prova"], a_ouvir["nome"]])
	GameClock.advance_minutes(TEMPO_DICA_MINUTOS)
	dicas_usadas += 1
	var local_id := CaseQueries.texto(CaseQueries.pista(caso, pendente).get("local", ""))
	var local_nome := CaseQueries.texto(CaseQueries.local_por_id(caso, local_id).get("nome", ""))
	if local_nome == "":
		return _fala_capitao(true, "O capitão olha o mural e diz: 'Ainda falta uma peça. Revise o que já coletou e volte aos locais.'")
	return _fala_capitao(true, "O capitão olha o mural e diz: 'Você ainda não tem nada sólido sobre este ponto. Procure no %s.'" % local_nome)


## Uma pessoa ainda não ouvida que se liga a uma prova já coletada (álibi, segredo ou resposta com prova).
## Devolve {nome, prova} ou {} se não houver.
func _pessoa_a_ouvir() -> Dictionary:
	for pessoa in CaseQueries.pessoas(CaseManager.current_case):
		var pid := CaseQueries.texto(pessoa.get("id", ""))
		if not depoimentos_de(pid).is_empty():
			continue
		var provas: Array = []
		var alibi: Variant = pessoa.get("alibi", null)
		if alibi is Dictionary:
			provas.append_array(alibi.get("exposto_por", []))
		for segredo in pessoa.get("segredos", []):
			if segredo is Dictionary:
				provas.append_array(segredo.get("revelado_por_provas", []))
		for pergunta in pessoa.get("interrogatorio", []):
			if pergunta is Dictionary and pergunta.get("resposta_com_prova", null) is Dictionary:
				provas.append_array(pergunta["resposta_com_prova"].keys())
		for prova_id in provas:
			if str(prova_id) in CaseManager.found_clues:
				var descricao := CaseQueries.texto(CaseQueries.pista(CaseManager.current_case, str(prova_id)).get("descricao", ""))
				return {"nome": CaseQueries.texto(pessoa.get("nome", pid)), "prova": descricao.left(60)}
	return {}


func _fala_capitao(ok: bool, texto: String) -> Dictionary:
	dica_capitao_dada.emit(texto)
	return {"ok": ok, "texto": texto}


# ---------- Eventos ----------

func _on_time_changed(_minutos: int) -> void:
	check_labs()


func _on_reveal(_text: String, clue_id: String) -> void:
	if clue_id == "" or clue_id in pistas_liberadas:
		return
	pistas_liberadas.append(clue_id)
	clue_unlocked.emit(clue_id)


func _on_clue_found(_clue_id: String) -> void:
	for pessoa in CaseQueries.pessoas(CaseManager.current_case):
		var suspect_id := CaseQueries.texto(pessoa.get("id", ""))
		var alibi: Variant = pessoa.get("alibi", null)
		if not alibi is Dictionary or not bool(alibi.get("falso", false)) or suspect_id in alibis_expostos:
			continue
		for pista_id in alibi.get("exposto_por", []):
			if str(pista_id) in CaseManager.found_clues:
				alibis_expostos.append(suspect_id)
				alibi_exposed.emit(suspect_id)
				break
