extends SceneTree
## Valida data/characters e data/cases contra docs/CONTRATOS.md (formato v1)
## e docs/DESIGN_V2.md (formato v2, detectado pela presença de "locais" ou "duracao_horas").
##
## Uso:
##   godot --headless --path <projeto> -s res://tools/validar_dados.gd
##       valida data/cases (a subpasta rascunho/ é ignorada)
##   godot --headless --path <projeto> -s res://tools/validar_dados.gd -- --rascunhos
##       valida só data/cases/rascunho/
##   godot --headless --path <projeto> -s res://tools/validar_dados.gd -- --rascunhos --arquivo=caso_004.json
##       valida um único arquivo da pasta escolhida
##   godot --headless --path <projeto> -s res://tools/validar_dados.gd -- --pasta=res://outra/pasta
##       valida outra pasta de casos
## Sai com código 1 se houver algum erro.

const DIR_PERSONAGENS := "res://data/characters"
const DIR_CASOS := "res://data/cases"
const DIR_RASCUNHOS := "res://data/cases/rascunho"
const FRANQUIAS := ["Chicago PD", "Chicago Fire", "Chicago Med", "Law & Order: SVU", "Original"]
const CAMPOS_PERSONAGEM := ["id", "nome", "franquia", "cargo", "descricao", "cor", "jogavel"]
const CAMPOS_CASO := ["id", "titulo", "resumo", "local", "ordem", "crossover", "personagens", "pistas", "suspeitos", "solucao"]
const CAMPOS_PISTA := ["id", "descricao", "posicao"]
const CAMPOS_SUSPEITO := ["id", "nome", "personagem_id", "motivo", "posicao", "interrogatorio"]
const CAMPOS_INTERROGATORIO := ["pergunta", "resposta", "revela_pista"]
const Y_PISTA := 0.15
const Y_PESSOA := 1.0
const LIMITE_CHAO := 8.0

# Formato v2 (DESIGN_V2.md, seção 6)
const CAMPOS_CASO_V2 := ["id", "titulo", "resumo", "ordem", "crossover", "duracao_horas", "personagens", "locais", "pistas", "suspeitos", "testemunhas", "solucao"]
const CAMPOS_LOCAL_V2 := ["id", "nome", "tipo"]
const CAMPOS_PISTA_V2 := ["id", "descricao", "local", "posicao"]
const CAMPOS_SUSPEITO_V2 := ["id", "nome", "tipo", "personagem_id", "motivo", "posicao", "rotina", "atitude", "limiar_pressao", "alibi", "segredos", "interrogatorio"]
const CAMPOS_TESTEMUNHA_V2 := ["id", "tipo", "nome", "motivo", "posicao", "rotina", "intimavel", "interrogatorio"]
const CAMPOS_ROTINA_V2 := ["dia", "de_hora", "ate_hora", "local"]
const CAMPOS_INTERROGATORIO_V2 := ["id", "pergunta", "resposta", "pressao", "revela_pista"]
const CAMPOS_ALIBI_V2 := ["texto", "falso", "exposto_por"]
const CAMPOS_SEGREDO_V2 := ["id", "descricao", "revelado_com_pressao", "revelado_por_provas", "revela_pista"]
const CAMPOS_REVIRAVOLTA_V2 := ["hora", "descricao"]
const CAMPOS_SOLUCAO_V2 := ["culpado", "pistas_necessarias", "motivo_correto"]
const DURACAO_V2 := 48.0
const ATITUDES_V2 := ["calmo", "nervoso", "arrogante", "agressivo"]
const TIPOS_LOCAL_V2 := ["delegacia", "rua"]

var erros: Array[String] = []
## IDs de suspeitos e testemunhas do caso v2 em validação (devem ser únicos entre si).
var _ids_pessoas: Array = []


func _init() -> void:
	var args := _argumentos()
	var pasta_casos := DIR_CASOS
	if args.has("rascunhos"):
		pasta_casos = DIR_RASCUNHOS
	if args.has("pasta"):
		pasta_casos = str(args["pasta"])

	var personagens := _ler_pasta(DIR_PERSONAGENS)
	var casos := _ler_pasta(pasta_casos)
	if args.has("arquivo"):
		casos = _filtrar_arquivo(casos, str(args["arquivo"]), pasta_casos)

	var ids_personagens := validar_personagens(personagens)
	validar_casos(casos, ids_personagens)

	if erros.is_empty():
		print("OK: %d personagens e %d casos validados (%s)." % [personagens.size(), casos.size(), pasta_casos])
		quit(0)
	else:
		for erro in erros:
			print("ERRO: " + erro)
		print("Validação falhou com %d erro(s)." % erros.size())
		quit(1)


## Lê argumentos depois de "--" na linha de comando. "--chave=valor" vira {chave: valor}; "--chave" vira {chave: true}.
func _argumentos() -> Dictionary:
	var resultado := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var partes := arg.substr(2).split("=", true, 1)
			resultado[partes[0]] = partes[1] if partes.size() > 1 else true
	return resultado


func _filtrar_arquivo(entradas: Array, nome: String, pasta: String) -> Array:
	var filtradas: Array = []
	for entrada in entradas:
		if entrada["arquivo"] == nome:
			filtradas.append(entrada)
	if filtradas.is_empty():
		_erro("Arquivo '%s' não encontrado em %s" % [nome, pasta])
	return filtradas


## Lê todos os .json de uma pasta (sem recursão: subpastas como rascunho/ não entram). Retorna [{arquivo, caminho, dados}].
func _ler_pasta(pasta: String) -> Array:
	var resultado: Array = []
	var dir := DirAccess.open(pasta)
	if dir == null:
		_erro("Pasta não encontrada: %s" % pasta)
		return resultado
	for nome in dir.get_files():
		if not nome.ends_with(".json"):
			continue
		var caminho := "%s/%s" % [pasta, nome]
		var arquivo := FileAccess.open(caminho, FileAccess.READ)
		var parsed: Variant = null
		if arquivo != null:
			parsed = JSON.parse_string(arquivo.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			_erro("%s: JSON inválido ou não é um objeto" % caminho)
			continue
		resultado.append({"arquivo": nome, "caminho": caminho, "dados": parsed})
	return resultado


## Retorna a lista de IDs de personagens válidos.
func validar_personagens(entradas: Array) -> Array:
	var ids: Array = []
	for entrada in entradas:
		var caminho: String = entrada["caminho"]
		var dados: Dictionary = entrada["dados"]
		var base: String = entrada["arquivo"].get_basename()
		_campos_obrigatorios(dados, CAMPOS_PERSONAGEM, caminho)

		var id := str(dados.get("id", ""))
		if id != base:
			_erro("%s: id '%s' deve ser igual ao nome do arquivo ('%s')" % [caminho, id, base])
		if id in ids:
			_erro("%s: id '%s' duplicado" % [caminho, id])
		ids.append(id)

		var franquia := str(dados.get("franquia", ""))
		if franquia not in FRANQUIAS:
			_erro("%s: franquia '%s' inválida" % [caminho, franquia])

		var cor := str(dados.get("cor", ""))
		if not (cor.begins_with("#") and Color.html_is_valid(cor)):
			_erro("%s: cor '%s' não é hex válido" % [caminho, cor])

		if typeof(dados.get("jogavel")) != TYPE_BOOL:
			_erro("%s: 'jogavel' deve ser true ou false" % caminho)
	return ids


func validar_casos(entradas: Array, ids_personagens: Array) -> void:
	var ids_casos: Array = []
	for entrada in entradas:
		var caminho: String = entrada["caminho"]
		var caso: Dictionary = entrada["dados"]
		var base: String = entrada["arquivo"].get_basename()
		var v2 := _eh_v2(caso)
		_campos_obrigatorios(caso, CAMPOS_CASO_V2 if v2 else CAMPOS_CASO, caminho)

		var id := str(caso.get("id", ""))
		if id != base:
			_erro("%s: id '%s' deve ser igual ao nome do arquivo ('%s')" % [caminho, id, base])
		if id in ids_casos:
			_erro("%s: id '%s' duplicado" % [caminho, id])
		ids_casos.append(id)

		if not _eh_numero(caso.get("ordem")):
			_erro("%s: 'ordem' deve ser número" % caminho)

		var crossover = caso.get("crossover")
		if crossover != null and typeof(crossover) != TYPE_STRING:
			_erro("%s: 'crossover' deve ser texto ou null" % caminho)

		var personagens: Variant = caso.get("personagens", [])
		if typeof(personagens) != TYPE_ARRAY:
			_erro("%s: 'personagens' deve ser uma lista" % caminho)
		else:
			for pid in personagens:
				if str(pid) not in ids_personagens:
					_erro("%s: personagem '%s' não existe em data/characters" % [caminho, str(pid)])

		if v2:
			_validar_caso_v2(caso, caminho, ids_personagens)
		else:
			_validar_caso_v1(caso, caminho, ids_personagens)


func _validar_caso_v1(caso: Dictionary, caminho: String, ids_personagens: Array) -> void:
	var ids_pistas := _validar_pistas(caso, caminho)
	var ids_suspeitos := _validar_suspeitos(caso, caminho, ids_pistas, ids_personagens)
	_validar_solucao(caso, caminho, ids_suspeitos, ids_pistas)


func _validar_pistas(caso: Dictionary, caminho: String) -> Array:
	var ids: Array = []
	var pistas: Variant = caso.get("pistas", [])
	if typeof(pistas) != TYPE_ARRAY:
		_erro("%s: 'pistas' deve ser uma lista" % caminho)
		return ids
	for pista in pistas:
		if typeof(pista) != TYPE_DICTIONARY:
			_erro("%s: pista inválida (não é objeto)" % caminho)
			continue
		_campos_obrigatorios(pista, CAMPOS_PISTA, caminho)
		var pid := str(pista.get("id", ""))
		if pid in ids:
			_erro("%s: pista '%s' duplicada" % [caminho, pid])
		ids.append(pid)
		_validar_posicao(pista, "%s pista '%s'" % [caminho, pid], Y_PISTA)
	return ids


func _validar_suspeitos(caso: Dictionary, caminho: String, ids_pistas: Array, ids_personagens: Array) -> Array:
	var ids: Array = []
	var suspeitos: Variant = caso.get("suspeitos", [])
	if typeof(suspeitos) != TYPE_ARRAY:
		_erro("%s: 'suspeitos' deve ser uma lista" % caminho)
		return ids
	for suspeito in suspeitos:
		if typeof(suspeito) != TYPE_DICTIONARY:
			_erro("%s: suspeito inválido (não é objeto)" % caminho)
			continue
		_campos_obrigatorios(suspeito, CAMPOS_SUSPEITO, caminho)
		var sid := str(suspeito.get("id", ""))
		var rotulo := "%s suspeito '%s'" % [caminho, sid]
		if sid in ids:
			_erro("%s: id de suspeito duplicado no caso" % rotulo)
		ids.append(sid)

		var pessoa_id = suspeito.get("personagem_id")
		if pessoa_id != null and str(pessoa_id) not in ids_personagens:
			_erro("%s: personagem_id '%s' não existe" % [rotulo, str(pessoa_id)])

		_validar_posicao(suspeito, rotulo, Y_PESSOA)

		var interrogatorio: Variant = suspeito.get("interrogatorio", [])
		if typeof(interrogatorio) != TYPE_ARRAY or interrogatorio.size() < 2:
			_erro("%s: 'interrogatorio' deve ser uma lista com pelo menos 2 perguntas" % rotulo)
			continue
		for item in interrogatorio:
			if typeof(item) != TYPE_DICTIONARY:
				_erro("%s: interrogatório inválido (não é objeto)" % rotulo)
				continue
			_campos_obrigatorios(item, CAMPOS_INTERROGATORIO, rotulo)
			var revela = item.get("revela_pista")
			if revela != null and str(revela) not in ids_pistas:
				_erro("%s: revela_pista '%s' não existe neste caso" % [rotulo, str(revela)])
	return ids


func _validar_solucao(caso: Dictionary, caminho: String, ids_suspeitos: Array, ids_pistas: Array) -> void:
	var solucao: Variant = caso.get("solucao")
	if typeof(solucao) != TYPE_DICTIONARY:
		_erro("%s: 'solucao' deve ser um objeto" % caminho)
		return
	var culpado = solucao.get("culpado")
	if str(culpado) not in ids_suspeitos:
		_erro("%s: culpado '%s' não é suspeito deste caso" % [caminho, str(culpado)])
	var necessarias: Variant = solucao.get("pistas_necessarias", [])
	if typeof(necessarias) != TYPE_ARRAY or necessarias.is_empty():
		_erro("%s: 'pistas_necessarias' deve ter pelo menos uma pista" % caminho)
		return
	for pid in necessarias:
		if str(pid) not in ids_pistas:
			_erro("%s: pista necessária '%s' não existe neste caso" % [caminho, str(pid)])


# ---------------------------------------------------------------- formato v2

func _eh_v2(caso: Dictionary) -> bool:
	return caso.has("locais") or caso.has("duracao_horas")


func _validar_caso_v2(caso: Dictionary, caminho: String, ids_personagens: Array) -> void:
	_ids_pessoas = []
	var duracao: Variant = caso.get("duracao_horas")
	if not _eh_numero(duracao) or not is_equal_approx(float(duracao), DURACAO_V2):
		_erro("%s: 'duracao_horas' deve ser %s" % [caminho, str(DURACAO_V2)])

	var ids_locais := _validar_locais_v2(caso, caminho)
	var ids_pistas := _validar_pistas_v2(caso, caminho, ids_locais)
	var ids_suspeitos := _validar_suspeitos_v2(caso, caminho, ids_pistas, ids_locais, ids_personagens)
	_validar_testemunhas_v2(caso, caminho, ids_pistas, ids_locais, ids_personagens)
	_validar_reviravoltas_v2(caso, caminho, ids_pistas)
	_validar_solucao_v2(caso, caminho, ids_suspeitos, ids_pistas)
	_validar_mandatos_consultas_v2(caso, caminho, ids_pistas, ids_locais)
	_validar_ambientes_v2(caso, caminho)


## Mandatos (juiz), consultas (sala de dados), locais ocultos e pistas ocultas (DESIGN_V2.md, seção 10).
## Opcionais: um caso sem essas listas continua válido.
func _validar_mandatos_consultas_v2(caso: Dictionary, caminho: String, ids_pistas: Array, ids_locais: Array) -> void:
	var mandatos := _lista_opcional(caso, "mandatos", caminho)
	var consultas := _lista_opcional(caso, "consultas", caminho)
	var ids_mandatos: Array = []
	var revelados_por_mandato_ou_consulta: Array = []
	var locais_revelados: Array = []

	for mandato in mandatos:
		_campos_obrigatorios(mandato, ["id", "tipo", "alvo", "justificativa", "pistas_minimas"], caminho)
		var rotulo := "%s mandato '%s'" % [caminho, str(mandato.get("id", ""))]
		ids_mandatos.append(str(mandato.get("id", "")))
		if str(mandato.get("tipo", "")) not in ["busca", "registros"]:
			_erro("%s: 'tipo' deve ser 'busca' ou 'registros'" % rotulo)
		if str(mandato.get("alvo", "")) not in _ids_pessoas:
			_erro("%s: alvo '%s' não é pessoa deste caso" % [rotulo, str(mandato.get("alvo", ""))])
		var justificativa: Variant = mandato.get("justificativa")
		if typeof(justificativa) != TYPE_ARRAY or justificativa.is_empty():
			_erro("%s: 'justificativa' deve ser uma lista com ao menos uma pista" % rotulo)
		else:
			for pid in justificativa:
				if str(pid) not in ids_pistas:
					_erro("%s: justificativa cita pista '%s' inexistente" % [rotulo, str(pid)])
			if not _eh_inteiro(mandato.get("pistas_minimas"), 1, justificativa.size()):
				_erro("%s: 'pistas_minimas' deve ser inteiro entre 1 e o tamanho da justificativa" % rotulo)
		for pid in mandato.get("revela_pistas", []):
			if str(pid) not in ids_pistas:
				_erro("%s: revela_pistas cita '%s' inexistente" % [rotulo, str(pid)])
			else:
				revelados_por_mandato_ou_consulta.append(str(pid))
		if mandato.has("revela_local"):
			if str(mandato.get("revela_local", "")) not in ids_locais:
				_erro("%s: revela_local '%s' não existe" % [rotulo, str(mandato.get("revela_local", ""))])
			else:
				locais_revelados.append(str(mandato.get("revela_local", "")))

	for consulta in consultas:
		_campos_obrigatorios(consulta, ["id", "tipo", "alvo", "requer_mandato"], caminho)
		var rotulo := "%s consulta '%s'" % [caminho, str(consulta.get("id", ""))]
		if str(consulta.get("tipo", "")) not in ["endereco", "telefone", "historico", "agora"]:
			_erro("%s: 'tipo' deve ser endereco, telefone, historico ou agora" % rotulo)
		if str(consulta.get("alvo", "")) not in _ids_pessoas:
			_erro("%s: alvo '%s' não é pessoa deste caso" % [rotulo, str(consulta.get("alvo", ""))])
		if str(consulta.get("requer_mandato", "")) not in ids_mandatos:
			_erro("%s: requer_mandato '%s' não existe" % [rotulo, str(consulta.get("requer_mandato", ""))])
		if consulta.has("revela_local"):
			var rl := str(consulta.get("revela_local", ""))
			if rl not in ids_locais:
				_erro("%s: revela_local '%s' não existe" % [rotulo, rl])
			else:
				locais_revelados.append(rl)
		if consulta.has("localizacao"):
			var loc: Variant = consulta.get("localizacao")
			if typeof(loc) != TYPE_DICTIONARY or str(loc.get("local", "")) not in ids_locais:
				_erro("%s: 'localizacao.local' deve ser um local existente" % rotulo)
			elif not _eh_numero(loc.get("ate_hora")) or float(loc.get("ate_hora")) < 0.0 or float(loc.get("ate_hora")) > 48.0:
				_erro("%s: 'localizacao.ate_hora' deve estar entre 0 e 48" % rotulo)
			else:
				locais_revelados.append(str(loc.get("local", "")))
		for pid in consulta.get("revela_pistas", []):
			if str(pid) not in ids_pistas:
				_erro("%s: revela_pistas cita '%s' inexistente" % [rotulo, str(pid)])
			else:
				revelados_por_mandato_ou_consulta.append(str(pid))

	for local in caso.get("locais", []):
		if local is Dictionary and bool(local.get("oculto", false)) and str(local.get("id", "")) not in locais_revelados:
			_erro("%s local '%s' é oculto mas nenhuma consulta o revela" % [caminho, str(local.get("id", ""))])
	for pista in caso.get("pistas", []):
		if pista is Dictionary and bool(pista.get("oculta", false)) and str(pista.get("id", "")) not in revelados_por_mandato_ou_consulta:
			_erro("%s pista '%s' é oculta mas nenhum mandato ou consulta a libera" % [caminho, str(pista.get("id", ""))])


## Ambiente 3D de cada local (campo "ambiente"): "rua" ou o id de data/ambientes/<id>.json.
## Cada ambiente precisa ter chão, paredes e móveis, e os modelos dos móveis precisam existir.
func _validar_ambientes_v2(caso: Dictionary, caminho: String) -> void:
	for local in caso.get("locais", []):
		if not local is Dictionary or not local.has("ambiente"):
			continue
		var amb := str(local.get("ambiente", ""))
		if amb == "rua":
			continue
		var arquivo := "res://data/ambientes/%s.json" % amb
		if not FileAccess.file_exists(arquivo):
			_erro("%s local '%s': ambiente '%s' não existe em data/ambientes/" % [caminho, str(local.get("id", "")), amb])
			continue
		var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(arquivo))
		if not dados is Dictionary:
			_erro("%s: %s não é um JSON válido" % [caminho, arquivo])
			continue
		for movel in dados.get("moveis", []):
			if not movel is Dictionary or not FileAccess.file_exists(str(movel.get("modelo", ""))):
				_erro("%s: móvel de '%s' aponta para modelo inexistente: %s" % [caminho, amb, str(movel.get("modelo", "")) if movel is Dictionary else "?"])


func _lista_opcional(caso: Dictionary, campo: String, caminho: String) -> Array:
	if not caso.has(campo):
		return []
	var dados: Variant = caso.get(campo)
	if typeof(dados) != TYPE_ARRAY:
		_erro("%s: '%s' deve ser uma lista" % [caminho, campo])
		return []
	var itens: Array = []
	for item in dados:
		if typeof(item) == TYPE_DICTIONARY:
			itens.append(item)
		else:
			_erro("%s: item de '%s' não é objeto" % [caminho, campo])
	return itens


func _validar_locais_v2(caso: Dictionary, caminho: String) -> Array:
	var ids: Array = []
	var locais: Variant = caso.get("locais")
	if typeof(locais) != TYPE_ARRAY:
		_erro("%s: 'locais' deve ser uma lista" % caminho)
		return ids
	var delegacias := 0
	for local in locais:
		if typeof(local) != TYPE_DICTIONARY:
			_erro("%s: local inválido (não é objeto)" % caminho)
			continue
		_campos_obrigatorios(local, CAMPOS_LOCAL_V2, caminho)
		var lid := str(local.get("id", ""))
		var rotulo := "%s local '%s'" % [caminho, lid]
		if lid in ids:
			_erro("%s: id de local duplicado" % rotulo)
		ids.append(lid)

		var tipo := str(local.get("tipo", ""))
		if tipo not in TIPOS_LOCAL_V2:
			_erro("%s: tipo '%s' inválido (use delegacia ou rua)" % [rotulo, tipo])
		if tipo == "delegacia":
			delegacias += 1
			if lid != "delegacia":
				_erro("%s: o local de tipo delegacia deve ter id 'delegacia'" % rotulo)
		elif tipo == "rua":
			var custo: Variant = local.get("custo_minutos")
			if not _eh_numero(custo) or float(custo) < 30.0 or float(custo) > 120.0:
				_erro("%s: 'custo_minutos' deve ser número entre 30 e 120" % rotulo)
			_validar_posicao_mapa(local, rotulo)

	if delegacias != 1:
		_erro("%s: 'locais' deve ter exatamente um local de tipo delegacia (id 'delegacia')" % caminho)
	return ids


func _validar_posicao_mapa(local: Dictionary, rotulo: String) -> void:
	var pos: Variant = local.get("posicao_mapa")
	if typeof(pos) != TYPE_ARRAY or pos.size() != 2:
		_erro("%s: 'posicao_mapa' deve ser [x, y] com valores entre 0 e 1" % rotulo)
		return
	for valor in pos:
		if not _eh_numero(valor) or float(valor) < 0.0 or float(valor) > 1.0:
			_erro("%s: 'posicao_mapa' deve conter números entre 0 e 1" % rotulo)
			return


func _validar_pistas_v2(caso: Dictionary, caminho: String, ids_locais: Array) -> Array:
	var ids: Array = []
	var pistas: Variant = caso.get("pistas")
	if typeof(pistas) != TYPE_ARRAY:
		_erro("%s: 'pistas' deve ser uma lista" % caminho)
		return ids
	for pista in pistas:
		if typeof(pista) != TYPE_DICTIONARY:
			_erro("%s: pista inválida (não é objeto)" % caminho)
			continue
		_campos_obrigatorios(pista, CAMPOS_PISTA_V2, caminho)
		var pid := str(pista.get("id", ""))
		var rotulo := "%s pista '%s'" % [caminho, pid]
		if pid in ids:
			_erro("%s: pista duplicada" % rotulo)
		ids.append(pid)
		if str(pista.get("local", "")) not in ids_locais:
			_erro("%s: local '%s' não existe neste caso" % [rotulo, str(pista.get("local"))])
		_validar_posicao(pista, rotulo, Y_PISTA)

		var lab: Variant = pista.get("laboratorio")
		if lab != null:
			if typeof(lab) != TYPE_DICTIONARY:
				_erro("%s: 'laboratorio' deve ser objeto ou ausente" % rotulo)
			else:
				var tempo: Variant = lab.get("tempo_horas")
				if not _eh_numero(tempo) or float(tempo) < 0.0:
					_erro("%s: laboratorio.tempo_horas deve ser número >= 0" % rotulo)
				if typeof(lab.get("conclusao")) != TYPE_STRING:
					_erro("%s: laboratorio.conclusao deve ser texto" % rotulo)
	return ids


func _validar_suspeitos_v2(caso: Dictionary, caminho: String, ids_pistas: Array, ids_locais: Array, ids_personagens: Array) -> Array:
	var ids: Array = []
	var suspeitos: Variant = caso.get("suspeitos")
	if typeof(suspeitos) != TYPE_ARRAY:
		_erro("%s: 'suspeitos' deve ser uma lista" % caminho)
		return ids
	for suspeito in suspeitos:
		if typeof(suspeito) != TYPE_DICTIONARY:
			_erro("%s: suspeito inválido (não é objeto)" % caminho)
			continue
		_campos_obrigatorios(suspeito, CAMPOS_SUSPEITO_V2, caminho)
		var sid := str(suspeito.get("id", ""))
		var rotulo := "%s suspeito '%s'" % [caminho, sid]
		_registrar_id_pessoa(sid, rotulo)
		ids.append(sid)

		if str(suspeito.get("tipo", "")) != "suspeito":
			_erro("%s: tipo deve ser 'suspeito'" % rotulo)
		_validar_personagem_id(suspeito, rotulo, ids_personagens)
		_validar_posicao(suspeito, rotulo, Y_PESSOA)
		_validar_rotina_v2(suspeito, rotulo, ids_locais)

		if str(suspeito.get("atitude", "")) not in ATITUDES_V2:
			_erro("%s: atitude '%s' inválida (use calmo, nervoso, arrogante ou agressivo)" % [rotulo, str(suspeito.get("atitude"))])
		var limiar: Variant = suspeito.get("limiar_pressao")
		if not _eh_inteiro(limiar, 1, 5):
			_erro("%s: 'limiar_pressao' deve ser inteiro entre 1 e 5" % rotulo)

		_validar_alibi_v2(suspeito, rotulo, ids_pistas)
		_validar_segredos_v2(suspeito, rotulo, ids_pistas)
		_validar_interrogatorio_v2(suspeito, rotulo, ids_pistas)
	return ids


func _validar_testemunhas_v2(caso: Dictionary, caminho: String, ids_pistas: Array, ids_locais: Array, ids_personagens: Array) -> void:
	var testemunhas: Variant = caso.get("testemunhas")
	if typeof(testemunhas) != TYPE_ARRAY:
		_erro("%s: 'testemunhas' deve ser uma lista" % caminho)
		return
	for testemunha in testemunhas:
		if typeof(testemunha) != TYPE_DICTIONARY:
			_erro("%s: testemunha inválida (não é objeto)" % caminho)
			continue
		_campos_obrigatorios(testemunha, CAMPOS_TESTEMUNHA_V2, caminho)
		var tid := str(testemunha.get("id", ""))
		var rotulo := "%s testemunha '%s'" % [caminho, tid]
		_registrar_id_pessoa(tid, rotulo)

		if str(testemunha.get("tipo", "")) != "testemunha":
			_erro("%s: tipo deve ser 'testemunha'" % rotulo)
		_validar_personagem_id(testemunha, rotulo, ids_personagens)
		_validar_posicao(testemunha, rotulo, Y_PESSOA)
		_validar_rotina_v2(testemunha, rotulo, ids_locais)
		if typeof(testemunha.get("intimavel")) != TYPE_BOOL:
			_erro("%s: 'intimavel' deve ser true ou false" % rotulo)
		_validar_interrogatorio_v2(testemunha, rotulo, ids_pistas)


func _validar_reviravoltas_v2(caso: Dictionary, caminho: String, ids_pistas: Array) -> void:
	if not caso.has("reviravoltas"):
		return
	var reviravoltas: Variant = caso.get("reviravoltas")
	if typeof(reviravoltas) != TYPE_ARRAY:
		_erro("%s: 'reviravoltas' deve ser uma lista" % caminho)
		return
	for reviravolta in reviravoltas:
		if typeof(reviravolta) != TYPE_DICTIONARY:
			_erro("%s: reviravolta inválida (não é objeto)" % caminho)
			continue
		_campos_obrigatorios(reviravolta, CAMPOS_REVIRAVOLTA_V2, caminho)
		var hora: Variant = reviravolta.get("hora")
		if not _eh_numero(hora) or float(hora) < 0.0 or float(hora) > 48.0:
			_erro("%s: reviravolta 'hora' deve ser número entre 0 e 48" % caminho)
		var revela: Variant = reviravolta.get("revela_pista")
		if revela != null and str(revela) not in ids_pistas:
			_erro("%s: reviravolta revela_pista '%s' não existe neste caso" % [caminho, str(revela)])


func _validar_solucao_v2(caso: Dictionary, caminho: String, ids_suspeitos: Array, ids_pistas: Array) -> void:
	var solucao: Variant = caso.get("solucao")
	if typeof(solucao) != TYPE_DICTIONARY:
		_erro("%s: 'solucao' deve ser um objeto" % caminho)
		return
	_campos_obrigatorios(solucao, CAMPOS_SOLUCAO_V2, caminho)
	if str(solucao.get("culpado")) not in ids_suspeitos:
		_erro("%s: culpado '%s' não é suspeito deste caso" % [caminho, str(solucao.get("culpado"))])
	var necessarias: Variant = solucao.get("pistas_necessarias", [])
	if typeof(necessarias) != TYPE_ARRAY or necessarias.size() < 2:
		_erro("%s: 'pistas_necessarias' deve ter pelo menos 2 pistas" % caminho)
	else:
		for pid in necessarias:
			if str(pid) not in ids_pistas:
				_erro("%s: pista necessária '%s' não existe neste caso" % [caminho, str(pid)])
	if typeof(solucao.get("motivo_correto")) != TYPE_STRING:
		_erro("%s: 'motivo_correto' deve ser texto" % caminho)


func _registrar_id_pessoa(pid: String, rotulo: String) -> void:
	if pid in _ids_pessoas:
		_erro("%s: id duplicado entre suspeitos e testemunhas" % rotulo)
	_ids_pessoas.append(pid)


func _validar_personagem_id(pessoa: Dictionary, rotulo: String, ids_personagens: Array) -> void:
	var pessoa_id = pessoa.get("personagem_id")
	if pessoa_id != null and str(pessoa_id) not in ids_personagens:
		_erro("%s: personagem_id '%s' não existe" % [rotulo, str(pessoa_id)])


func _validar_rotina_v2(pessoa: Dictionary, rotulo: String, ids_locais: Array) -> void:
	var rotina: Variant = pessoa.get("rotina")
	if typeof(rotina) != TYPE_ARRAY:
		_erro("%s: 'rotina' deve ser uma lista" % rotulo)
		return
	for janela in rotina:
		if typeof(janela) != TYPE_DICTIONARY:
			_erro("%s: janela de rotina inválida (não é objeto)" % rotulo)
			continue
		_campos_obrigatorios(janela, CAMPOS_ROTINA_V2, rotulo)
		if not _eh_inteiro(janela.get("dia"), 1, 3):
			_erro("%s: rotina 'dia' deve ser 1, 2 ou 3" % rotulo)
		var de: Variant = janela.get("de_hora")
		var ate: Variant = janela.get("ate_hora")
		var horas_ok := _eh_numero(de) and _eh_numero(ate) and float(de) >= 0.0 and float(ate) <= 24.0
		if not horas_ok:
			_erro("%s: rotina 'de_hora' e 'ate_hora' devem estar entre 0 e 24" % rotulo)
		elif float(de) >= float(ate):
			_erro("%s: rotina 'de_hora' deve ser menor que 'ate_hora'" % rotulo)
		if str(janela.get("local", "")) not in ids_locais:
			_erro("%s: rotina aponta para local '%s' que não existe" % [rotulo, str(janela.get("local"))])


func _validar_alibi_v2(suspeito: Dictionary, rotulo: String, ids_pistas: Array) -> void:
	var alibi: Variant = suspeito.get("alibi")
	if typeof(alibi) != TYPE_DICTIONARY:
		_erro("%s: 'alibi' deve ser objeto" % rotulo)
		return
	_campos_obrigatorios(alibi, CAMPOS_ALIBI_V2, rotulo)
	if typeof(alibi.get("falso")) != TYPE_BOOL:
		_erro("%s: alibi.falso deve ser true ou false" % rotulo)
	var exposto: Variant = alibi.get("exposto_por", [])
	if typeof(exposto) != TYPE_ARRAY:
		_erro("%s: alibi.exposto_por deve ser uma lista" % rotulo)
		return
	for pid in exposto:
		if str(pid) not in ids_pistas:
			_erro("%s: alibi.exposto_por aponta para pista '%s' que não existe" % [rotulo, str(pid)])
	if alibi.get("falso") == true and exposto.is_empty():
		_erro("%s: alibi falso exige alibi.exposto_por com pelo menos uma pista" % rotulo)


func _validar_segredos_v2(suspeito: Dictionary, rotulo: String, ids_pistas: Array) -> void:
	var segredos: Variant = suspeito.get("segredos")
	if typeof(segredos) != TYPE_ARRAY:
		_erro("%s: 'segredos' deve ser uma lista" % rotulo)
		return
	for segredo in segredos:
		if typeof(segredo) != TYPE_DICTIONARY:
			_erro("%s: segredo inválido (não é objeto)" % rotulo)
			continue
		_campos_obrigatorios(segredo, CAMPOS_SEGREDO_V2, rotulo)
		var srotulo := "%s segredo '%s'" % [rotulo, str(segredo.get("id", ""))]
		if typeof(segredo.get("revelado_com_pressao")) != TYPE_BOOL:
			_erro("%s: 'revelado_com_pressao' deve ser true ou false" % srotulo)
		var provas: Variant = segredo.get("revelado_por_provas")
		if typeof(provas) != TYPE_ARRAY:
			_erro("%s: 'revelado_por_provas' deve ser uma lista" % srotulo)
		else:
			for pid in provas:
				if str(pid) not in ids_pistas:
					_erro("%s: revelado_por_provas aponta para pista '%s' que não existe" % [srotulo, str(pid)])
		var revela: Variant = segredo.get("revela_pista")
		if revela != null and str(revela) not in ids_pistas:
			_erro("%s: revela_pista '%s' não existe neste caso" % [srotulo, str(revela)])


func _validar_interrogatorio_v2(pessoa: Dictionary, rotulo: String, ids_pistas: Array) -> void:
	var interrogatorio: Variant = pessoa.get("interrogatorio")
	if typeof(interrogatorio) != TYPE_ARRAY or interrogatorio.size() < 2:
		_erro("%s: 'interrogatorio' deve ser uma lista com pelo menos 2 perguntas" % rotulo)
		return
	var ids_perguntas: Array = []
	for item in interrogatorio:
		if typeof(item) != TYPE_DICTIONARY:
			_erro("%s: interrogatório inválido (não é objeto)" % rotulo)
			continue
		_campos_obrigatorios(item, CAMPOS_INTERROGATORIO_V2, rotulo)
		var pid := str(item.get("id", ""))
		if pid in ids_perguntas:
			_erro("%s: id de pergunta '%s' duplicado" % [rotulo, pid])
		ids_perguntas.append(pid)
		if not _eh_inteiro(item.get("pressao"), -1, 1):
			_erro("%s: pergunta '%s' tem pressao inválida (use -1, 0 ou 1)" % [rotulo, pid])
		var revela: Variant = item.get("revela_pista")
		if revela != null and str(revela) not in ids_pistas:
			_erro("%s: revela_pista '%s' não existe neste caso" % [rotulo, str(revela)])
		if item.has("resposta_com_prova"):
			var com_prova: Variant = item.get("resposta_com_prova")
			if typeof(com_prova) != TYPE_DICTIONARY:
				_erro("%s: resposta_com_prova da pergunta '%s' deve ser objeto" % [rotulo, pid])
				continue
			for chave in com_prova.keys():
				if str(chave) not in ids_pistas:
					_erro("%s: resposta_com_prova aponta para pista '%s' que não existe" % [rotulo, str(chave)])
				if typeof(com_prova[chave]) != TYPE_STRING:
					_erro("%s: resposta_com_prova['%s'] deve ser texto" % [rotulo, str(chave)])


# ---------------------------------------------------------------- utilidades

func _validar_posicao(obj: Dictionary, rotulo: String, y_esperado: float) -> void:
	var pos: Variant = obj.get("posicao")
	if typeof(pos) != TYPE_ARRAY or pos.size() != 3:
		_erro("%s: 'posicao' deve ser [x, y, z]" % rotulo)
		return
	for valor in pos:
		if not _eh_numero(valor):
			_erro("%s: 'posicao' deve conter só números" % rotulo)
			return
	var x := float(pos[0])
	var y := float(pos[1])
	var z := float(pos[2])
	if not is_equal_approx(y, y_esperado):
		_erro("%s: y deve ser %s, é %s" % [rotulo, str(y_esperado), str(y)])
	if absf(x) > LIMITE_CHAO or absf(z) > LIMITE_CHAO:
		_erro("%s: posicao [%s, %s] fora do chão (x e z entre -8 e 8)" % [rotulo, str(x), str(z)])


func _campos_obrigatorios(dados: Dictionary, campos: Array, caminho: String) -> void:
	for campo in campos:
		if not dados.has(campo):
			_erro("%s: campo obrigatório ausente '%s'" % [caminho, campo])


func _eh_numero(valor: Variant) -> bool:
	return typeof(valor) == TYPE_INT or typeof(valor) == TYPE_FLOAT


## JSON.parse_string devolve todo número como float; aceita 1.0 como inteiro.
func _eh_inteiro(valor: Variant, minimo: int, maximo: int) -> bool:
	if not _eh_numero(valor):
		return false
	var v := float(valor)
	return is_equal_approx(v, roundf(v)) and v >= minimo and v <= maximo


func _erro(mensagem: String) -> void:
	erros.append(mensagem)
