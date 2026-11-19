extends Node3D
## Cena do julgamento: sala do Tribunal Criminal (data/ambientes/tribunal.json), com juiz, promotor,
## defesa, réu, testemunha, júri (12 jurados), público e o detetive na galeria.
## A câmera faz plano geral e close em quem fala; as falas aparecem como legenda digitada.
## Regras (veredito, roteiro) ficam em julgamento.gd. Ao terminar, emite concluido(resultado).

signal concluido(resultado: Dictionary)
signal _continuar_pressionado

const JULGAMENTO := preload("res://scripts/investigation/julgamento.gd")
const CaseQueries := preload("res://scripts/core/case_queries.gd")
const MODELO_PESSOA := "res://assets/models/pessoa_courier.glb"
const MODELO_DETETIVE := "res://assets/models/detetive_navegador.glb"
const COR_PADRAO_DETETIVE := Color(0.2, 0.4, 0.8)

const POS_GERAL := Vector3(-1.5, 8.6, 9.0)
const OLHAR_GERAL := Vector3(0, 0.6, -4.0)
const DURACAO_CAMERA := 1.0
const CARACTERES_POR_SEGUNDO := 38.0
const SEGUNDOS_POR_MINUTO := 0.05       # tempo real da deliberação: 1 min de jogo = 0,05 s
const NOMES_FALANTE := {
	"juiz": "JUIZ",
	"promotor": "PROMOTOR",
	"defesa": "DEFESA",
	"reu": "RÉU",
	"presidente": "PRESIDENTE DO JÚRI",
}

var _caso: Dictionary = {}
var _acusado_id := ""
var _provas: Array = []
var _atores: Dictionary = {}  # chave -> {no: Node3D, base: Vector3}
var _camera: Camera3D
var _olhar_atual := OLHAR_GERAL
var _olhar_alvo := OLHAR_GERAL
var _ui: CanvasLayer
var _falante: Label
var _texto: Label
var _continuar: Button
var _deliberacao: ColorRect
var _contagem: Label
var _carimbo: Label
var _tween_fala: Tween


func _process(delta: float) -> void:
	if _camera == null:
		return
	_olhar_atual = _olhar_atual.lerp(_olhar_alvo, minf(1.0, delta * 4.0))
	_camera.look_at(_olhar_atual)


## Monta a sala e inicia o julgamento. provas_ids são as pistas que o jogador levou ao júri.
func iniciar(caso: Dictionary, acusado_id: String, provas_ids: Array) -> void:
	_caso = caso
	_acusado_id = acusado_id
	_provas = provas_ids.duplicate()
	var dados := _ler_sala()
	if dados.is_empty():
		push_error("tribunal.json não encontrado")
		concluido.emit({"acusado_id": acusado_id, "condenado": false, "unanime": false, "minutos": 0, "culpado": false})
		return
	_construir_sala(dados)
	_construir_figuras(dados)
	_construir_ui()
	_executar()


func _executar() -> void:
	_mirar(POS_GERAL, OLHAR_GERAL, false)
	var resultado := JULGAMENTO.deliberar(_caso, _acusado_id, _provas)
	await _rodar_falas(JULGAMENTO.roteiro_argumentos(_caso, _acusado_id, _provas))
	await _deliberar(resultado)
	await _rodar_falas(JULGAMENTO.roteiro_veredito(resultado))
	_mostrar_carimbo(bool(resultado.get("condenado", false)))
	await get_tree().create_timer(2.0).timeout
	concluido.emit({
		"acusado_id": _acusado_id,
		"condenado": resultado.get("condenado", false),
		"unanime": resultado.get("unanime", false),
		"minutos": resultado.get("minutos", 0),
		"culpado": resultado.get("culpado", false),
	})


# ---------- Falas e câmera ----------

func _rodar_falas(falas: Array[Dictionary]) -> void:
	for fala in falas:
		await _falar(fala)


func _falar(fala: Dictionary) -> void:
	var quem := str(fala.get("quem", "juiz"))
	if str(fala.get("plano", "geral")) == "quem" and _atores.has(quem):
		var base: Vector3 = _atores[quem]["base"]
		_mirar(base + Vector3(0, 1.9, 2.8), base + Vector3(0, 1.3, 0), true)
	else:
		_mirar(POS_GERAL, OLHAR_GERAL, true)

	_falante.text = str(NOMES_FALANTE.get(quem, quem.to_upper()))
	var texto := str(fala.get("texto", ""))
	_texto.text = texto
	_texto.visible_ratio = 0.0
	_continuar.visible = false
	var duracao := clampf(float(texto.length()) / CARACTERES_POR_SEGUNDO, 0.8, 4.5)
	if _tween_fala and _tween_fala.is_valid():
		_tween_fala.kill()
	_tween_fala = create_tween()
	_tween_fala.tween_property(_texto, "visible_ratio", 1.0, duracao)
	await _tween_fala.finished
	_continuar.visible = true
	await _continuar_pressionado


## Move a câmera até a posição e o olhar pedidos. Com suave=false, corta direto.
func _mirar(pos: Vector3, olhar: Vector3, suave: bool) -> void:
	_olhar_alvo = olhar
	if not suave:
		_camera.position = pos
		_olhar_atual = olhar
		return
	var tween := create_tween()
	tween.tween_property(_camera, "position", pos, DURACAO_CAMERA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------- Deliberação ----------

func _deliberar(resultado: Dictionary) -> void:
	var total := int(resultado.get("minutos", 0))
	_deliberacao.visible = true
	_contagem.text = _texto_tempo(total)
	var segundos := clampf(float(total) * SEGUNDOS_POR_MINUTO, 3.0, 8.0)
	var tween := create_tween()
	tween.tween_method(func(valor: float) -> void: _contagem.text = _texto_tempo(total - int(round(valor * total))), 0.0, 1.0, segundos)
	await tween.finished
	_deliberacao.visible = false


func _texto_tempo(minutos: int) -> String:
	return "Tempo de deliberação: %dh %02dmin" % [minutos / 60, minutos % 60]


func _mostrar_carimbo(condenado: bool) -> void:
	_carimbo.text = "CULPADO" if condenado else "ABSOLVIDO"
	_carimbo.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15) if condenado else Color(0.2, 0.7, 0.3))
	_carimbo.visible = true
	_carimbo.scale = Vector2(2.2, 2.2)
	_carimbo.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_carimbo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_carimbo, "modulate:a", 1.0, 0.25)


# ---------- Sala ----------

func _ler_sala() -> Dictionary:
	if not FileAccess.file_exists("res://data/ambientes/tribunal.json"):
		return {}
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ambientes/tribunal.json"))
	return dados if dados is Dictionary else {}


func _construir_sala(dados: Dictionary) -> void:
	var luz_dados: Dictionary = dados.get("luz", {})
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0d0a08")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3a2c20")
	env.ambient_light_energy = 0.8
	ambiente.environment = env
	add_child(ambiente)

	var luz := DirectionalLight3D.new()
	luz.light_color = Color.from_string(str(luz_dados.get("cor", "")), Color("#ffe2b8"))
	luz.light_energy = float(luz_dados.get("energia", 1.1))
	luz.rotation_degrees = Vector3(-60, 20, 0)
	add_child(luz)
	for pos in [Vector3(0, 3.6, -5.0), Vector3(-4.0, 3.6, -1.0), Vector3(4.0, 3.6, -1.0)]:
		var lampada := OmniLight3D.new()
		lampada.position = pos
		lampada.light_color = Color("#ffd49a")
		lampada.light_energy = 1.4
		lampada.omni_range = 9.0
		add_child(lampada)

	_camera = Camera3D.new()
	_camera.fov = 56.0
	_camera.current = true
	add_child(_camera)
	_camera.position = POS_GERAL
	_camera.look_at(OLHAR_GERAL)

	var chao: Dictionary = dados.get("chao", {})
	var largura := float(chao.get("largura", 22.0))
	var profundidade := float(chao.get("profundidade", 18.0))
	_caixa(Vector3(0, -0.1, 0), Vector3(largura, 0.2, profundidade), Color.from_string(str(chao.get("cor", "")), Color("#6b4a2b")))

	var parede: Dictionary = dados.get("parede", {})
	var altura := float(parede.get("altura", 4.2))
	var espessura := float(parede.get("espessura", 0.3))
	var cor_parede := Color.from_string(str(parede.get("cor", "")), Color("#4a2c17"))
	_caixa(Vector3(0, altura / 2.0, -profundidade / 2.0), Vector3(largura + espessura, altura, espessura), cor_parede)
	_caixa(Vector3(0, altura / 2.0, profundidade / 2.0), Vector3(largura + espessura, altura, espessura), cor_parede)
	_caixa(Vector3(-largura / 2.0, altura / 2.0, 0), Vector3(espessura, altura, profundidade), cor_parede)
	_caixa(Vector3(largura / 2.0, altura / 2.0, 0), Vector3(espessura, altura, profundidade), cor_parede)

	var estrado: Dictionary = dados.get("estrado", {})
	if not estrado.is_empty():
		var c: Array = estrado.get("centro", [0, 0])
		var t: Array = estrado.get("tamanho", [1, 0.4, 1])
		_caixa(Vector3(float(c[0]), 0.2, float(c[1])), Vector3(float(t[0]), 0.4, float(t[2])), Color("#4a3320"))

	for interna in dados.get("paredes_internas", []):
		var c: Array = interna.get("centro", [0, 0])
		var t: Array = interna.get("tamanho", [1, 1, 0.1])
		_caixa(Vector3(float(c[0]), float(t[1]) / 2.0, float(c[1])), Vector3(float(t[0]), float(t[1]), float(t[2])), Color.from_string(str(interna.get("cor", "")), Color("#8a5a2c")))

	for movel in dados.get("moveis", []):
		if movel is Dictionary:
			_criar_movel(movel)


func _construir_figuras(dados: Dictionary) -> void:
	var atores: Dictionary = dados.get("atores", {})
	for chave in atores:
		var ator: Dictionary = atores[chave]
		var pos := _xz(ator.get("pos", [0, 0]), float(ator.get("y", 0.0)))
		var no := _figura(pos, Color.from_string(str(ator.get("cor", "")), Color.GRAY), str(ator.get("rotulo", chave)))
		_atores[str(chave)] = {"no": no, "base": pos}

	# O primeiro jurado é o presidente do júri, já criado em "atores".
	var jurados: Array = dados.get("jurados", [])
	for i in range(1, jurados.size()):
		_figura(_xz(jurados[i], 0.0), Color("#4b4f5c"), "")  # sem rótulo: só o presidente é identificado

	for pos_lista in dados.get("publico", []):
		_figura(_xz(pos_lista, 0.0), Color("#8a7a5c"), "", 26)

	var detetive: Array = dados.get("detetive", [-2.0, 5.7])
	var cor_detetive := Color.from_string(str(GameState.player.get("cor", "")), COR_PADRAO_DETETIVE)
	var nome := str(GameState.player.get("nome", "DETETIVE")).to_upper()
	_figura(_xz(detetive, 0.0), cor_detetive, nome, 30, MODELO_DETETIVE)


func _xz(valor: Variant, y: float) -> Vector3:
	if valor is Array and valor.size() == 2:
		return Vector3(float(valor[0]), y, float(valor[1]))
	return Vector3(0, y, 0)


## Figura de pessoa tingida e virada para o juiz (-Z). Rótulo flutua acima da cabeça.
func _figura(pos: Vector3, cor: Color, rotulo: String, tamanho_rotulo := 36, modelo := MODELO_PESSOA) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = pos
	raiz.rotation.y = PI
	add_child(raiz)
	var cena := load(modelo) as PackedScene
	if cena:
		var corpo := cena.instantiate() as Node3D
		raiz.add_child(corpo)
		for no in corpo.find_children("*", "MeshInstance3D", true, false):
			(no as MeshInstance3D).material_override = _material(cor)
	if rotulo != "":
		var texto := Label3D.new()
		texto.text = rotulo
		texto.position = Vector3(0, 2.15, 0)
		texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		texto.font_size = tamanho_rotulo
		texto.pixel_size = 0.01
		texto.modulate = Color(1, 0.95, 0.85)
		raiz.add_child(texto)
	return raiz


## Móvel com modelo, reduzido sem deformar até caber em "tamanho" (como na investigação).
func _criar_movel(movel: Dictionary) -> void:
	var c: Array = movel.get("centro", [0, 0])
	var t: Array = movel.get("tamanho", [1, 1, 1])
	var tamanho := Vector3(float(t[0]), float(t[1]), float(t[2]))
	var pivo := Node3D.new()
	pivo.position = Vector3(float(c[0]), float(movel.get("altura_base", 0.0)), float(c[1]))
	pivo.rotation.y = deg_to_rad(float(movel.get("rotacao", 0)))
	add_child(pivo)
	var cena := load(str(movel.get("modelo", ""))) as PackedScene
	if cena == null:
		return
	var suporte := Node3D.new()
	pivo.add_child(suporte)
	suporte.add_child(cena.instantiate())
	var caixa := _caixa_do_modelo(suporte)
	if caixa.size.x <= 0.0 or caixa.size.y <= 0.0 or caixa.size.z <= 0.0:
		return
	var escala := minf(tamanho.x / caixa.size.x, minf(tamanho.y / caixa.size.y, tamanho.z / caixa.size.z))
	var meio := caixa.get_center()
	suporte.scale = Vector3.ONE * escala
	suporte.position = Vector3(-meio.x * escala, -caixa.position.y * escala, -meio.z * escala)


func _caixa_do_modelo(suporte: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for no in suporte.find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		if malha.mesh == null:
			continue
		var relativo := suporte.global_transform.affine_inverse() * malha.global_transform
		var caixa_da_malha := relativo * malha.get_aabb()
		caixa = caixa_da_malha if primeira else caixa.merge(caixa_da_malha)
		primeira = false
	return caixa


func _caixa(pos: Vector3, tamanho: Vector3, cor: Color) -> void:
	var box := BoxMesh.new()
	box.size = tamanho
	box.material = _material(cor)
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = pos
	add_child(mesh)


func _material(cor: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	return material


# ---------- Interface (legenda, letterbox, deliberação, carimbo) ----------

func _construir_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)

	for topo in [true, false]:
		var barra := ColorRect.new()
		barra.color = Color.BLACK
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		barra.anchor_left = 0.0
		barra.anchor_right = 1.0
		if topo:
			barra.anchor_top = 0.0
			barra.anchor_bottom = 0.0
			barra.offset_bottom = 56
		else:
			barra.anchor_top = 1.0
			barra.anchor_bottom = 1.0
			barra.offset_top = -56
		_ui.add_child(barra)

	var titulo := Label.new()
	titulo.text = "TRIBUNAL CRIMINAL DO CONDADO DE COOK"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.anchor_right = 1.0
	titulo.offset_top = 16
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	_ui.add_child(titulo)

	var caixa := PanelContainer.new()
	caixa.anchor_left = 0.0
	caixa.anchor_right = 1.0
	caixa.anchor_top = 1.0
	caixa.anchor_bottom = 1.0
	caixa.offset_left = 40
	caixa.offset_right = -40
	caixa.offset_top = -200
	caixa.offset_bottom = -68
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.0, 0.0, 0.0, 0.74)
	estilo.content_margin_left = 28
	estilo.content_margin_right = 28
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	caixa.add_theme_stylebox_override("panel", estilo)
	_ui.add_child(caixa)
	var linhas := VBoxContainer.new()
	linhas.add_theme_constant_override("separation", 6)
	caixa.add_child(linhas)
	_falante = _rotulo(15, Color(1.0, 0.8, 0.2))
	_texto = _rotulo(22, Color(0.95, 0.93, 0.86))
	linhas.add_child(_falante)
	linhas.add_child(_texto)

	_continuar = Button.new()
	_continuar.text = "Continuar"
	_continuar.custom_minimum_size = Vector2(220, 44)
	_continuar.anchor_left = 1.0
	_continuar.anchor_right = 1.0
	_continuar.anchor_top = 1.0
	_continuar.anchor_bottom = 1.0
	_continuar.offset_left = -260
	_continuar.offset_right = -40
	_continuar.offset_top = -62
	_continuar.offset_bottom = -18
	_continuar.visible = false
	_continuar.pressed.connect(func() -> void:
		_continuar.visible = false
		_continuar_pressionado.emit())
	_ui.add_child(_continuar)

	_deliberacao = ColorRect.new()
	_deliberacao.color = Color(0, 0, 0, 0.92)
	_deliberacao.anchor_right = 1.0
	_deliberacao.anchor_bottom = 1.0
	_deliberacao.visible = false
	_ui.add_child(_deliberacao)
	var centro := VBoxContainer.new()
	centro.anchor_right = 1.0
	centro.anchor_bottom = 1.0
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_theme_constant_override("separation", 18)
	_deliberacao.add_child(centro)
	var aviso := _rotulo(30, Color(0.95, 0.93, 0.86))
	aviso.text = "O júri se retira para deliberar.\nO julgamento está suspenso."
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.add_child(aviso)
	_contagem = _rotulo(20, Color(0.8, 0.78, 0.7))
	_contagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.add_child(_contagem)

	_carimbo = _rotulo(92, Color(0.85, 0.15, 0.15))
	_carimbo.anchor_right = 1.0
	_carimbo.anchor_bottom = 1.0
	_carimbo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carimbo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_carimbo.visible = false
	_ui.add_child(_carimbo)


func _rotulo(tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo
