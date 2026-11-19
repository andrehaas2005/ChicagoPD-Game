extends RefCounted
## Regra de acusação: vence quem acusa o culpado correto com todas as pistas necessárias coletadas.


static func avaliar(caso: Dictionary, suspeito: Dictionary) -> Dictionary:
	var solucao: Dictionary = caso.get("solucao", {})
	var culpado_certo := str(suspeito.get("id", "")) == str(solucao.get("culpado", ""))

	var faltando := false
	for pista_id in solucao.get("pistas_necessarias", []):
		if not (str(pista_id) in CaseManager.found_clues):
			faltando = true

	var resolvido := culpado_certo and not faltando
	var motivo := ""
	if resolvido:
		motivo = "O culpado foi identificado e todas as provas foram reunidas."
	elif culpado_certo:
		motivo = "Faltaram provas para sustentar a acusação."
	else:
		motivo = "O suspeito acusado não era o culpado."

	return {
		"solved": resolvido,
		"motivo": motivo,
		"acusado": str(suspeito.get("nome", "")),
		"caso": str(caso.get("titulo", "")),
	}
