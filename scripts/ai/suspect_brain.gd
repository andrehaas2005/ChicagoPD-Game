class_name SuspectBrain
extends RefCounted
## Cérebro de um suspeito ou testemunha (formato v2, docs/DESIGN_V2.md seções 4 e 6).
## As respostas são escolhidas por regras, sem aleatoriedade, então o jogo é reproduzível.
## Não depende de cena: recebe o dicionário do suspeito e mantém o estado do interrogatório.

const FRASES_TOM := {
	"nervoso": ["Eu já disse que não sei!", "Para de me olhar desse jeito.", "Não tenho mais nada pra dizer."],
	"agressivo": ["Eu já disse que não sei!", "Cansei dessas perguntas.", "Some daqui com isso, detetive."],
	"arrogante": ["Que pergunta patética.", "Você realmente acha que eu vou responder isso?", "Perda de tempo, detetive."],
	"calmo": [],
}
const PRESSAO_MINIMA_PARA_TOM := 2
const FRASE_CONFRONTO_ALIBI := "Tá bom, essa prova derruba meu álibi. Eu menti sobre onde estava."
const PREFIXO_QUEBRA := "Tá bom, vou falar a verdade."

var subject_id := ""
var atitude := "calmo"
var limiar_pressao := 3
var pressao := 0
var segredos_revelados: Array[String] = []
var alibi_exposto := false

var _alibi: Dictionary = {}
var _segredos: Array[Dictionary] = []
var _perguntas: Array[Dictionary] = []
var _perguntas_feitas: Array[String] = []


func _init(data: Dictionary = {}) -> void:
	if not data.is_empty():
		setup(data)


## Carrega o suspeito ou testemunha (formato v2) e zera o estado.
func setup(data: Dictionary) -> void:
	subject_id = _texto(data, "id")
	var atitude_data := _texto(data, "atitude")
	atitude = atitude_data if atitude_data != "" else "calmo"
	limiar_pressao = int(data.get("limiar_pressao", 3))

	var alibi_data: Variant = data.get("alibi", {})
	_alibi = (alibi_data as Dictionary).duplicate(true) if alibi_data is Dictionary else {}

	_segredos.clear()
	var segredos_data: Array = data.get("segredos", [])
	for segredo in segredos_data:
		if segredo is Dictionary:
			_segredos.append((segredo as Dictionary).duplicate(true))

	_perguntas.clear()
	var perguntas_data: Array = data.get("interrogatorio", [])
	for i in perguntas_data.size():
		var pergunta: Dictionary = (perguntas_data[i] as Dictionary).duplicate(true)
		if _texto(pergunta, "id") == "":
			pergunta["id"] = "perg_%d" % (i + 1)
		_perguntas.append(pergunta)

	reset()


## Zera o estado do interrogatório (pressão, segredos, álibi e perguntas feitas).
func reset() -> void:
	pressao = 0
	segredos_revelados.clear()
	alibi_exposto = false
	_perguntas_feitas.clear()


## Faz uma pergunta. presented_clue_id é a prova apresentada junto (ou "").
## Retorna {resposta, pressao_delta, revela_pista, revela_segredos, alibi_exposto, ja_perguntada}.
## alibi_exposto e revela_segredos só são verdadeiros na chamada em que o fato acontece.
func ask(question_id: String, presented_clue_id: String = "") -> Dictionary:
	var pergunta := _buscar_pergunta(question_id)
	if pergunta.is_empty():
		push_warning("Pergunta desconhecida para %s: %s" % [subject_id, question_id])
		return _resultado_vazio(false)

	if question_id in _perguntas_feitas:
		return _resultado_vazio(true)

	_perguntas_feitas.append(question_id)

	var resposta := _texto(pergunta, "resposta")
	var respostas_com_prova: Dictionary = _dicionario(pergunta, "resposta_com_prova")
	var tem_resposta_com_prova := presented_clue_id != "" and respostas_com_prova.has(presented_clue_id)
	if tem_resposta_com_prova:
		resposta = str(respostas_com_prova[presented_clue_id])

	# (f) Prova que expõe o álibi falso: a resposta é a de confronto.
	var alibi_exposto_agora := false
	if _alibi_falso() and presented_clue_id != "" and presented_clue_id in _lista(_alibi, "exposto_por"):
		if not alibi_exposto:
			alibi_exposto = true
			alibi_exposto_agora = true
		if not tem_resposta_com_prova:
			resposta = FRASE_CONFRONTO_ALIBI

	# (c) Pressão: a pergunta soma o delta, nunca abaixo de zero.
	var pressao_delta := int(pergunta.get("pressao", 0))
	pressao = maxi(0, pressao + pressao_delta)

	# (d) Segredos revelados por prova com pressão suficiente.
	var revela_segredos: Array[String] = []
	if presented_clue_id != "" and pressao >= limiar_pressao:
		for segredo in _segredos:
			var segredo_id := _texto(segredo, "id")
			if segredo_id in segredos_revelados:
				continue
			if presented_clue_id in _lista(segredo, "revelado_por_provas"):
				segredos_revelados.append(segredo_id)
				revela_segredos.append(segredo_id)
				resposta += " %s %s" % [PREFIXO_QUEBRA, _texto(segredo, "descricao")]

	var tom := _tom_da_resposta()
	if tom != "":
		resposta = "%s %s" % [tom, resposta]

	return {
		"resposta": resposta,
		"pressao_delta": pressao_delta,
		"revela_pista": _texto(pergunta, "revela_pista"),
		"revela_segredos": revela_segredos,
		"alibi_exposto": alibi_exposto_agora,
		"ja_perguntada": false,
	}


## Perguntas que ainda não foram feitas, na ordem do arquivo.
func perguntas_disponiveis() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for pergunta in _perguntas:
		if _texto(pergunta, "id") not in _perguntas_feitas:
			lista.append(pergunta.duplicate(true))
	return lista


## Todas as perguntas do suspeito, feitas ou não, com ID garantido.
func todas_perguntas() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for pergunta in _perguntas:
		lista.append(pergunta.duplicate(true))
	return lista


func foi_perguntada(question_id: String) -> bool:
	return question_id in _perguntas_feitas


## Descrição de um segredo pelo ID, ou o próprio ID se não existir.
func descricao_segredo(segredo_id: String) -> String:
	for segredo in _segredos:
		if _texto(segredo, "id") == segredo_id:
			return _texto(segredo, "descricao")
	return segredo_id


func _buscar_pergunta(question_id: String) -> Dictionary:
	for pergunta in _perguntas:
		if _texto(pergunta, "id") == question_id:
			return pergunta
	return {}


func _tom_da_resposta() -> String:
	var frases: Array = FRASES_TOM.get(atitude, [])
	if frases.is_empty():
		return ""
	var usa_tom := atitude == "arrogante" or pressao >= PRESSAO_MINIMA_PARA_TOM
	if not usa_tom:
		return ""
	# Usa o número de perguntas feitas para escolher a frase, sem aleatoriedade.
	return str(frases[(_perguntas_feitas.size() - 1) % frases.size()])


func _alibi_falso() -> bool:
	return bool(_alibi.get("falso", false))


func _resultado_vazio(ja_perguntada: bool) -> Dictionary:
	var revela_segredos: Array[String] = []
	return {
		"resposta": "",
		"pressao_delta": 0,
		"revela_pista": "",
		"revela_segredos": revela_segredos,
		"alibi_exposto": false,
		"ja_perguntada": ja_perguntada,
	}


static func _texto(dados: Dictionary, chave: String) -> String:
	var valor: Variant = dados.get(chave)
	return valor if valor is String else ""


static func _lista(dados: Dictionary, chave: String) -> Array:
	var valor: Variant = dados.get(chave)
	return valor if valor is Array else []


static func _dicionario(dados: Dictionary, chave: String) -> Dictionary:
	var valor: Variant = dados.get(chave)
	return valor if valor is Dictionary else {}
