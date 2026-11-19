extends RefCounted
## Regras do julgamento (sem visual): deliberação do júri e roteiro das falas do tribunal.
## Regra do jogo: o réu só é condenado se os 12 jurados votarem culpado (unanimidade).
## Sem unanimidade, ou se o júri absolver, o réu é absolvido e deixa de ser suspeito.

const CaseQueries = preload("res://scripts/core/case_queries.gd")
const JURADOS := 12


## Decide o veredito. Depende das provas levadas ao júri (provas_ids) e de quem é o réu.
## Devolve {condenado, unanime, votos_culpado, minutos, forca, culpado}.
static func deliberar(caso: Dictionary, acusado_id: String, provas_ids: Array) -> Dictionary:
	var solucao: Dictionary = caso.get("solucao", {})
	var necessarias: Array = solucao.get("pistas_necessarias", [])
	var achadas := 0
	for pista_id in necessarias:
		if str(pista_id) in provas_ids:
			achadas += 1
	var forca := float(achadas) / maxf(1.0, float(necessarias.size()))
	var culpado := acusado_id == CaseQueries.texto(solucao.get("culpado", ""))

	var votos := 0
	if culpado:
		if forca >= 1.0:
			votos = JURADOS
		elif forca >= 0.75:
			votos = 11
		elif forca >= 0.5:
			votos = 9
		else:
			votos = 6
	else:
		# Réu inocente: até com provas fracas, o júri quase nunca fecha em culpado.
		votos = 2 if forca >= 0.5 else 0

	var condenado := votos == JURADOS
	var unanime := votos == JURADOS or votos == 0
	var minutos := 30 + 15 * provas_ids.size() + (0 if culpado else 20) + int(round(forca * 20.0))
	return {
		"condenado": condenado,
		"unanime": unanime,
		"votos_culpado": votos,
		"minutos": minutos,
		"forca": forca,
		"culpado": culpado,
	}


## Falas do julgamento antes da deliberação: promotor, defesa e réu.
## Cada fala é {quem, texto, plano}. quem: "juiz", "promotor", "defesa" ou "reu".
## plano: "geral" (plano aberto da sala) ou "quem" (close no falante).
static func roteiro_argumentos(caso: Dictionary, acusado_id: String, provas_ids: Array) -> Array[Dictionary]:
	var pessoa := CaseQueries.pessoa(caso, acusado_id)
	var nome := CaseQueries.texto(pessoa.get("nome", "o réu"))
	var titulo := CaseQueries.texto(caso.get("titulo", "Caso"))
	var falas: Array[Dictionary] = []

	falas.append(_fala("juiz", "Tribunal em sessão. %s. O Estado contra %s." % [titulo, nome], "geral"))
	falas.append(_fala("promotor", "Senhoras e senhores do júri, vamos mostrar que %s cometeu este crime." % nome, "quem"))
	var numero := 1
	for pista_id in provas_ids:
		var pista := CaseQueries.pista(caso, str(pista_id))
		falas.append(_fala("promotor", "Prova %d: %s" % [numero, CaseQueries.texto(pista.get("descricao", ""))], "quem"))
		numero += 1
	if provas_ids.is_empty():
		falas.append(_fala("promotor", "Não temos provas materiais por enquanto, mas pedimos que o júri considere o caso como um todo.", "quem"))
	falas.append(_fala("promotor", "Diante destas provas, pedimos a condenação de %s." % nome, "quem"))

	var alibi: Variant = pessoa.get("alibi", null)
	var texto_alibi := "sem álibi declarado"
	var alibi_falso := false
	if alibi is Dictionary:
		texto_alibi = CaseQueries.texto(alibi.get("texto", texto_alibi))
		alibi_falso = bool(alibi.get("falso", false))
	falas.append(_fala("defesa", "Meu cliente, %s, afirma: \"%s\"" % [nome, texto_alibi], "quem"))
	if alibi_falso:
		falas.append(_fala("defesa", "A acusação diz que o álibi é falso. Ela precisa provar isso além de qualquer dúvida razoável.", "quem"))
	falas.append(_fala("defesa", "Nenhuma destas provas coloca meu cliente, de forma certa, na cena do crime. Pedimos a absolvição.", "quem"))
	falas.append(_fala("reu", "Eu não fiz isso.", "quem"))
	falas.append(_fala("juiz", "O júri vai se retirar para deliberar.", "geral"))
	return falas


## Falas depois da deliberação: o júri volta, o presidente lê o veredito e o juiz encerra.
static func roteiro_veredito(resultado: Dictionary) -> Array[Dictionary]:
	var falas: Array[Dictionary] = []
	falas.append(_fala("juiz", "O júri retornou. Presidente do júri, qual é o veredito?", "geral"))
	if not bool(resultado.get("unanime", false)):
		falas.append(_fala("juiz", "O júri não chegou a um veredito unânime. Sem unanimidade, o réu é absolvido.", "geral"))
	elif bool(resultado.get("condenado", false)):
		falas.append(_fala("presidente", "Culpado.", "quem"))
		falas.append(_fala("juiz", "O réu será levado à cadeia. Tribunal dispensado.", "geral"))
	else:
		falas.append(_fala("presidente", "Não culpado.", "quem"))
		falas.append(_fala("juiz", "O réu está absolvido e liberado. Tribunal dispensado.", "geral"))
	return falas


static func _fala(quem: String, texto: String, plano: String) -> Dictionary:
	return {"quem": quem, "texto": texto, "plano": plano}
