extends RefCounted
## Consultas puras sobre o dicionário do caso (sem estado próprio).
## Casos v1, sem "locais", são tratados como uma única delegacia.

const TIPO_DELEGACIA := "delegacia"
const LOCAL_DELEGACIA_PADRAO := {"id": "delegacia", "nome": "Delegacia do 21º Distrito", "tipo": "delegacia", "custo_minutos": 0}


## Texto seguro para valores que podem ser null no JSON.
static func texto(valor: Variant) -> String:
	return "" if valor == null else str(valor)


## Locais do caso. Sem "locais", devolve só a delegacia.
static func locais(caso: Dictionary) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var dados: Variant = caso.get("locais", [])
	if dados is Array:
		for item in dados:
			if item is Dictionary:
				lista.append(item)
	if lista.is_empty():
		lista.append(LOCAL_DELEGACIA_PADRAO.duplicate())
	return lista


static func local_por_id(caso: Dictionary, local_id: String) -> Dictionary:
	for local in locais(caso):
		if texto(local.get("id", "")) == local_id:
			return local
	return {}


static func tipo_local(caso: Dictionary, local_id: String) -> String:
	return texto(local_por_id(caso, local_id).get("tipo", ""))


## Minutos de viagem até o local. Delegacia e locais desconhecidos custam 0.
static func custo_viagem(caso: Dictionary, local_id: String) -> int:
	var local := local_por_id(caso, local_id)
	if local.is_empty() or texto(local.get("tipo", "")) == TIPO_DELEGACIA:
		return 0
	return int(local.get("custo_minutos", 0))


static func pistas(caso: Dictionary) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var dados: Variant = caso.get("pistas", [])
	if dados is Array:
		for item in dados:
			if item is Dictionary:
				lista.append(item)
	return lista


static func pista(caso: Dictionary, clue_id: String) -> Dictionary:
	for item in pistas(caso):
		if texto(item.get("id", "")) == clue_id:
			return item
	return {}


## Dados de laboratório da pista, ou {} se ela não tem laboratório.
static func laboratorio(caso: Dictionary, clue_id: String) -> Dictionary:
	var lab: Variant = pista(caso, clue_id).get("laboratorio", null)
	return lab if lab is Dictionary else {}


## Suspeitos e testemunhas em uma lista só. Cada item ganha "tipo" (suspeito/testemunha) se faltar.
static func pessoas(caso: Dictionary) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for grupo in [["suspeitos", "suspeito"], ["testemunhas", "testemunha"]]:
		var dados: Variant = caso.get(grupo[0], [])
		if not dados is Array:
			continue
		for item in dados:
			if item is Dictionary:
				var copia: Dictionary = item.duplicate()
				if not copia.has("tipo"):
					copia["tipo"] = grupo[1]
				lista.append(copia)
	return lista


static func pessoa(caso: Dictionary, person_id: String) -> Dictionary:
	for item in pessoas(caso):
		if texto(item.get("id", "")) == person_id:
			return item
	return {}


## True se alguma janela da rotina cobre o dia, a hora e o local informados.
static func em_rotina(rotina: Array, dia: int, hora: int, local_id: String) -> bool:
	for janela in rotina:
		if not janela is Dictionary:
			continue
		if int(janela.get("dia", 0)) != dia or texto(janela.get("local", "")) != local_id:
			continue
		if hora >= int(janela.get("de_hora", 0)) and hora < int(janela.get("ate_hora", 0)):
			return true
	return false


## IDs das pistas que só aparecem por uma reviravolta.
static func pistas_de_reviravolta(caso: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var dados: Variant = caso.get("reviravoltas", [])
	if not dados is Array:
		return ids
	for evento in dados:
		if evento is Dictionary:
			var clue_id := texto(evento.get("revela_pista", ""))
			if clue_id != "" and not (clue_id in ids):
				ids.append(clue_id)
	return ids


## Locais ocultos começam fora do mapa e só aparecem depois de uma consulta que os revela.
static func local_oculto(local: Dictionary) -> bool:
	return bool(local.get("oculto", false))


## Pistas que só aparecem depois de liberadas: marcadas com "oculta" no JSON, ou por reviravolta.
static func pista_oculta(caso: Dictionary, clue_id: String) -> bool:
	return bool(pista(caso, clue_id).get("oculta", false)) or clue_id in pistas_de_reviravolta(caso)


## Lista de itens de um campo do caso (mandatos, consultas), ignorando entradas inválidas.
static func _lista_de(caso: Dictionary, campo: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var dados: Variant = caso.get(campo, [])
	if dados is Array:
		for item in dados:
			if item is Dictionary:
				lista.append(item)
	return lista


static func mandatos(caso: Dictionary) -> Array[Dictionary]:
	return _lista_de(caso, "mandatos")


static func mandato(caso: Dictionary, mandato_id: String) -> Dictionary:
	for item in mandatos(caso):
		if texto(item.get("id", "")) == mandato_id:
			return item
	return {}


static func consultas(caso: Dictionary) -> Array[Dictionary]:
	return _lista_de(caso, "consultas")


static func consulta(caso: Dictionary, consulta_id: String) -> Dictionary:
	for item in consultas(caso):
		if texto(item.get("id", "")) == consulta_id:
			return item
	return {}


## Ambiente 3D do local: o campo "ambiente" do JSON, ou "delegacia" / "rua" pelo tipo.
## Corresponde a data/ambientes/<id>.json; "rua" usa o cenário de cidade.
static func ambiente(caso: Dictionary, local_id: String) -> String:
	var local := local_por_id(caso, local_id)
	var explicito := texto(local.get("ambiente", ""))
	if explicito != "":
		return explicito
	return "delegacia" if texto(local.get("tipo", "")) == TIPO_DELEGACIA else "rua"
