extends Node3D
## Visão 3D de um local: cena do local (rua ou interior), pistas, pessoas presentes no horário atual
## e o detetive, que anda pela cena (WASD ou setas). Quando chega perto de uma pista, aparece
## a dica "[E] Examinar" e a tecla E coleta a pista.
## Interiores (delegacia, hospital, apartamento...) vêm de data/ambientes/<id>.json. Ruas usam PREDIOS.
## Quem está onde é decidido por CaseState; aqui só se desenha, se movimenta e se captam entradas.
## Enquadramento de cinema: travelling de entrada ao trocar de local, close-up ao examinar pista,
## luz por ambiente (campo "luz" do JSON) e balanço do detetive ao andar.

signal pista_clicada(clue_id: String, descricao: String)
signal pessoa_clicada(pessoa: Dictionary)

const CLUE_SCRIPT := preload("res://scripts/investigation/clue.gd")
const CINEMA_LUZ := preload("res://scripts/investigation/cinema_luz.gd")
const CaseQueries := preload("res://scripts/core/case_queries.gd")
const MODELO_PESSOA := "res://assets/models/pessoa_courier.glb"
const MODELO_DETETIVE := "res://assets/models/detetive_navegador.glb"
## Um modelo por bloco de PREDIOS, na mesma ordem (CC0, ver assets/models/LICENCAS.md).
const MODELOS_PREDIOS := [
	"res://assets/models/predio_garagem.glb",
	"res://assets/models/predio_cafe.glb",
	"res://assets/models/predio_oficina.glb",
	"res://assets/models/predio_escritorio.glb",
	"res://assets/models/predio_arcade.glb",
]

const COR_PESSOA_PADRAO := Color(0.5, 0.5, 0.5)
const COR_DETETIVE_PADRAO := Color(0.2, 0.4, 0.8)

const VELOCIDADE := 4.0            # metros por segundo
const RAIO_JOGADOR := 0.4          # distância mínima para prédios
const LIMITE_CENARIO := 13.0       # o chão tem 30 m, então o jogador fica dentro dele
const DISTANCIA_PISTA := 1.6       # a partir de quanto a pista pode ser examinada
const SPAWN := Vector3(0, 0, 6)
const DESLOCAMENTO_CAMERA := Vector3(0, 14, 11)
const ALTURA_OLHAR := Vector3(0, 1, 0)   # a câmera olha para o detetive, um pouco acima do chão

## Travelling de entrada: a câmera começa alta e quase em cima do detetive, e desce até o normal.
const DESLOCAMENTO_ENTRADA := Vector3(0, 30, 6)
const DURACAO_ENTRADA := 1.2
## Close-up ao examinar pista: fov menor e câmera mais perto da pista, e volta ao normal.
const FOV_NORMAL := 50.0
const FOV_EXAME := 36.0
const DURACAO_EXAME := 0.5
const DESLOCAMENTO_EXAME := Vector3(0, 2.2, 2.4)   # onde a câmera fica em relação à pista no pico do zoom
## Balanço do detetive ao andar.
const ALTURA_PASSO := 0.06
const INCLINACAO_PASSO := 0.035
const CADENCIA_PASSO := 11.0

## Blocos da cidade: [centro, tamanho]. O centro y é metade da altura, para ficar no chão.
const PREDIOS := [
	[Vector3(-8, 1.5, -7), Vector3(4, 3, 4)],
	[Vector3(7, 2, -8), Vector3(5, 4, 4)],
	[Vector3(-9, 1, 6), Vector3(3, 2, 5)],
	[Vector3(8, 2.5, 6), Vector3(4, 5, 4)],
	[Vector3(0, 1.2, -10), Vector3(7, 2.4, 3)],
]

var _pistas: Dictionary = {}  # clue_id -> nó da pista
var _obstaculos: Array[Rect2] = []  # áreas (x, z) que o detetive não atravessa
var _limite := Vector2(LIMITE_CENARIO, LIMITE_CENARIO)  # metade da largura e da profundidade do chão
var _entrada := SPAWN
var _detetive: Node3D
var _visual_detetive: Node3D  # filho do detetive que recebe o balanço (o modelo fica dentro dele)
var _camera: Camera3D
var _camada_ui: CanvasLayer
var _dica: Label
var _local_atual := ""
var _camera_tween: Tween
var _entrada_ativa := false   # travelling de entrada ainda rodando (exame não interrompe)
var _tempo_passo := 0.0


func _ready() -> void:
	_camada_ui = CanvasLayer.new()
	add_child(_camada_ui)

	_dica = Label.new()
	_dica.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_dica.offset_left = -400
	_dica.offset_right = 400
	_dica.offset_top = 110
	_dica.offset_bottom = 150
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.add_theme_font_size_override("font_size", 20)
	_dica.visible = false
	_camada_ui.add_child(_dica)

	var ajuda := Label.new()
	ajuda.text = "WASD ou setas: andar    E: examinar pista    clique: falar com alguém"
	ajuda.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ajuda.offset_left = 16
	ajuda.offset_top = -36
	ajuda.offset_bottom = -12
	ajuda.add_theme_font_size_override("font_size", 14)
	_camada_ui.add_child(ajuda)


## Reconstrói a cena para o local dado, com o estado atual do caso.
## Faz o travelling de entrada quando o local muda (ou se travelling for true, ex.: voltar ao mesmo local).
## Chamadas repetidas do mesmo local (depois de uma ação) só reconstroem, sem travelling.
func montar(local_id: String, travelling := false) -> void:
	var entrou := travelling or local_id != _local_atual
	_limpar()
	_local_atual = local_id
	var ambiente := CaseQueries.ambiente(CaseManager.current_case, local_id)
	if ambiente == "rua" or not _criar_interior(ambiente):
		_criar_cenario()
	for pista in CaseState.pistas_no_local(local_id):
		_criar_pista(pista)
	var indice := 0
	for pessoa in CaseState.pessoas_no_local(local_id):
		_criar_pessoa(pessoa, indice)
		indice += 1
	_criar_detetive()
	if entrou:
		_iniciar_travelling()


## Marca a pista como coletada sem reconstruir a cena.
func marcar_pista(clue_id: String) -> void:
	if _pistas.has(clue_id):
		_pistas[clue_id].mark_found()


## Close-up curto na pista (fov menor e câmera mais perto, ~0,5 s) e volta ao normal.
## Não bloqueia nada: a coleta acontece no mesmo instante. Ignorado durante o travelling de entrada.
## É chamado sozinho pela tecla E, antes de pista_clicada; não precisa ser chamado pelo investigation.
func animar_exame(clue_id: String) -> void:
	if _camera == null or _detetive == null or not _pistas.has(clue_id) or _entrada_ativa:
		return
	_parar_camera()
	var alvo: Vector3 = _pistas[clue_id].position + Vector3(0, 0.3, 0)
	_camera_tween = create_tween()
	_camera_tween.tween_method(_passo_exame.bind(alvo), 0.0, 1.0, DURACAO_EXAME)


func _limpar() -> void:
	_parar_camera()
	for filho in get_children():
		if filho == _camada_ui:
			continue
		remove_child(filho)
		filho.queue_free()
	_pistas.clear()
	_obstaculos.clear()
	_detetive = null
	_visual_detetive = null
	_camera = null


func _process(delta: float) -> void:
	if _detetive == null:
		return
	var pode := _pode_andar()
	var direcao := Vector3.ZERO
	if pode:
		direcao = _direcao_teclado()
		if direcao != Vector3.ZERO:
			_mover(direcao * VELOCIDADE * delta)
			_detetive.rotation.y = lerp_angle(_detetive.rotation.y, atan2(direcao.x, direcao.z), minf(1.0, delta * 12.0))
	_balancar_detetive(delta, direcao != Vector3.ZERO)
	if not _camera_em_animacao():
		_camera.position = _detetive.position + DESLOCAMENTO_CAMERA
		_camera.look_at(_detetive.position + ALTURA_OLHAR)
	_atualizar_dica(pode)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and _pode_andar():
		var clue_id := _pista_proxima()
		if clue_id != "":
			get_viewport().set_input_as_handled()
			animar_exame(clue_id)
			pista_clicada.emit(clue_id, _pistas[clue_id].description)


# ---------- Câmera ----------

func _camera_em_animacao() -> bool:
	return _camera_tween != null and _camera_tween.is_running()


func _parar_camera() -> void:
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null
	_entrada_ativa = false


func _iniciar_travelling() -> void:
	_parar_camera()
	_entrada_ativa = true
	_camera_tween = create_tween()
	_camera_tween.tween_method(_passo_entrada, 0.0, 1.0, DURACAO_ENTRADA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_camera_tween.finished.connect(func() -> void: _entrada_ativa = false)


## t vai de 0 (câmera alta) a 1 (posição normal). Segue o detetive se ele andar.
func _passo_entrada(t: float) -> void:
	if _camera == null or _detetive == null:
		return
	_camera.position = (_detetive.position + DESLOCAMENTO_ENTRADA).lerp(_detetive.position + DESLOCAMENTO_CAMERA, t)
	_camera.look_at(_detetive.position + ALTURA_OLHAR)


## t vai de 0 a 1; k = sin(t·PI) sobe de 0 a 1 e volta a 0, então a câmera vai e volta.
func _passo_exame(t: float, alvo: Vector3) -> void:
	if _camera == null or _detetive == null:
		return
	var k := sin(t * PI)
	var normal := _detetive.position + DESLOCAMENTO_CAMERA
	_camera.position = normal.lerp(alvo + DESLOCAMENTO_EXAME, k)
	_camera.look_at((_detetive.position + ALTURA_OLHAR).lerp(alvo, k))
	_camera.fov = lerpf(FOV_NORMAL, FOV_EXAME, k)


## Balanço curto do detetive enquanto anda (sobe e desce, com leve inclinação). Volta ao repouso parado.
func _balancar_detetive(delta: float, andando: bool) -> void:
	if _visual_detetive == null:
		return
	if andando:
		_tempo_passo += delta * CADENCIA_PASSO
	var alvo_y := absf(sin(_tempo_passo)) * ALTURA_PASSO if andando else 0.0
	var alvo_z := sin(_tempo_passo) * INCLINACAO_PASSO if andando else 0.0
	var suavidade := minf(1.0, delta * 10.0)
	_visual_detetive.position.y = lerpf(_visual_detetive.position.y, alvo_y, suavidade)
	_visual_detetive.rotation.z = lerpf(_visual_detetive.rotation.z, alvo_z, suavidade)


# ---------- Movimento e interação ----------

## Não anda enquanto há um painel (interrogatório, mapa, acusação...) aberto.
func _pode_andar() -> bool:
	if _detetive == null:
		return false
	for painel in get_tree().get_nodes_in_group("modal"):
		if painel is CanvasItem and painel.is_visible_in_tree():
			return false
	return true


func _direcao_teclado() -> Vector3:
	var x := 0.0
	var z := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		z += 1.0
	var direcao := Vector3(x, 0, z)
	return direcao.normalized() if direcao.length() > 0.0 else Vector3.ZERO


## Move eixo a eixo, para o detetive deslizar ao encostar num prédio em vez de travar.
func _mover(passo: Vector3) -> void:
	var p := _detetive.position
	if not _colide(Vector3(p.x + passo.x, 0, p.z)):
		p.x += passo.x
	if not _colide(Vector3(p.x, 0, p.z + passo.z)):
		p.z += passo.z
	p.x = clampf(p.x, -_limite.x, _limite.x)
	p.z = clampf(p.z, -_limite.y, _limite.y)
	_detetive.position = p


func _colide(pos: Vector3) -> bool:
	if absf(pos.x) > _limite.x or absf(pos.z) > _limite.y:
		return true
	var ponto := Vector2(pos.x, pos.z)
	for area in _obstaculos:
		if area.grow(RAIO_JOGADOR).has_point(ponto):
			return true
	return false


## Pista visível e ainda não coletada mais perto do detetive, dentro do alcance. "" se não houver.
func _pista_proxima() -> String:
	if _detetive == null:
		return ""
	var melhor := ""
	var melhor_distancia := DISTANCIA_PISTA
	for clue_id in _pistas:
		if clue_id in CaseManager.found_clues:
			continue
		var pista: Node3D = _pistas[clue_id]
		var distancia := Vector2(pista.position.x - _detetive.position.x, pista.position.z - _detetive.position.z).length()
		if distancia < melhor_distancia:
			melhor_distancia = distancia
			melhor = clue_id
	return melhor


func _atualizar_dica(pode: bool) -> void:
	var clue_id := _pista_proxima() if pode else ""
	_dica.visible = clue_id != ""
	if clue_id != "":
		_dica.text = "[E] Examinar: %s" % _pistas[clue_id].description


# ---------- Cenário ----------

## Cria câmera, luz principal e ambiente (WorldEnvironment). dados_luz vazio = luz padrão da rua.
func _criar_camera_e_luz(dados_luz: Dictionary, ambiente: Environment) -> void:
	_camera = Camera3D.new()
	_camera.fov = FOV_NORMAL
	add_child(_camera)
	_camera.position = DESLOCAMENTO_CAMERA
	_camera.look_at(Vector3.ZERO)
	_camera.current = true

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55, 30, 0)
	add_child(luz)
	if not dados_luz.is_empty():
		CINEMA_LUZ.aplicar_luz(luz, dados_luz)

	var mundo := WorldEnvironment.new()
	mundo.environment = ambiente
	add_child(mundo)


## Rua: chão de cidade e os cinco blocos de PREDIOS. Luz atual, com névoa leve.
func _criar_cenario() -> void:
	_criar_camera_e_luz({}, CINEMA_LUZ.ambiente_rua())
	_adicionar_caixa(Vector3(0, -0.1, 0), Vector3(30, 0.2, 30), Color(0.25, 0.25, 0.28))
	_limite = Vector2(LIMITE_CENARIO, LIMITE_CENARIO)
	_entrada = SPAWN
	for i in PREDIOS.size():
		_criar_predio(i, PREDIOS[i][0], PREDIOS[i][1])
		var centro: Vector3 = PREDIOS[i][0]
		var tamanho: Vector3 = PREDIOS[i][1]
		_obstaculos.append(Rect2(centro.x - tamanho.x / 2.0, centro.z - tamanho.z / 2.0, tamanho.x, tamanho.z))


## Interior: chão, quatro paredes e móveis descritos em data/ambientes/<id>.json.
## Devolve false se o ambiente não existir, para cair na rua.
func _criar_interior(ambiente_id: String) -> bool:
	var dados := _ler_ambiente(ambiente_id)
	if dados.is_empty():
		return false

	var dados_luz: Dictionary = {}
	if dados.get("luz") is Dictionary:
		dados_luz = dados["luz"]
	_criar_camera_e_luz(dados_luz, CINEMA_LUZ.ambiente_interior(dados_luz))

	var chao: Dictionary = dados.get("chao", {})
	var largura := float(chao.get("largura", 18.0))
	var profundidade := float(chao.get("profundidade", 18.0))
	_adicionar_caixa(Vector3(0, -0.1, 0), Vector3(largura, 0.2, profundidade), Color.from_string(str(chao.get("cor", "")), Color.DIM_GRAY))
	_limite = Vector2(largura / 2.0 - 0.2, profundidade / 2.0 - 0.2)

	var parede: Dictionary = dados.get("parede", {})
	var altura := float(parede.get("altura", 3.0))
	var espessura := float(parede.get("espessura", 0.3))
	var cor_parede := Color.from_string(str(parede.get("cor", "")), Color.GRAY)
	_criar_parede(Vector3(0, altura / 2.0, -profundidade / 2.0), Vector3(largura + espessura, altura, espessura), cor_parede)
	_criar_parede(Vector3(0, altura / 2.0, profundidade / 2.0), Vector3(largura + espessura, altura, espessura), cor_parede)
	_criar_parede(Vector3(-largura / 2.0, altura / 2.0, 0), Vector3(espessura, altura, profundidade), cor_parede)
	_criar_parede(Vector3(largura / 2.0, altura / 2.0, 0), Vector3(espessura, altura, profundidade), cor_parede)

	for movel in dados.get("moveis", []):
		if movel is Dictionary:
			_criar_movel(movel)

	var entrada: Variant = dados.get("entrada", [0, 0])
	_entrada = Vector3(float(entrada[0]), 0, float(entrada[1])) if entrada is Array and entrada.size() == 2 else SPAWN
	return true


func _ler_ambiente(ambiente_id: String) -> Dictionary:
	var caminho := "res://data/ambientes/%s.json" % ambiente_id
	if not FileAccess.file_exists(caminho):
		return {}
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return dados if dados is Dictionary else {}


func _criar_parede(pos: Vector3, tamanho: Vector3, cor: Color) -> void:
	_adicionar_caixa(pos, tamanho, cor)
	_obstaculos.append(Rect2(pos.x - tamanho.x / 2.0, pos.z - tamanho.z / 2.0, tamanho.x, tamanho.z))


## Móvel de interior: o modelo é reduzido (sem deformar) até caber em "tamanho", apoiado no chão
## ou em "altura_base" (ex.: quadro na parede). A área de colisão é o retângulo de "tamanho",
## girado se rotacao for 90 ou 270.
func _criar_movel(movel: Dictionary) -> void:
	var centro_xz: Variant = movel.get("centro", [0, 0])
	var centro := Vector3(float(centro_xz[0]), 0, float(centro_xz[1])) if centro_xz is Array and centro_xz.size() == 2 else Vector3.ZERO
	var tamanho_lista: Variant = movel.get("tamanho", [1, 1, 1])
	var tamanho := Vector3(float(tamanho_lista[0]), float(tamanho_lista[1]), float(tamanho_lista[2]))
	var rotacao := float(movel.get("rotacao", 0))
	var base := float(movel.get("altura_base", 0.0))
	var largura_colisao := tamanho.x
	var profundidade_colisao := tamanho.z
	if int(absf(rotacao)) % 180 == 90:
		largura_colisao = tamanho.z
		profundidade_colisao = tamanho.x
	_obstaculos.append(Rect2(centro.x - largura_colisao / 2.0, centro.z - profundidade_colisao / 2.0, largura_colisao, profundidade_colisao))

	var pivo := Node3D.new()
	pivo.position = Vector3(centro.x, base, centro.z)
	pivo.rotation.y = deg_to_rad(rotacao)
	add_child(pivo)

	var cena := load(str(movel.get("modelo", ""))) as PackedScene
	if cena == null:
		var box := BoxMesh.new()
		box.size = tamanho
		box.material = _material(Color.from_string(str(movel.get("cor", "")), Color.DIM_GRAY))
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.position = Vector3(0, tamanho.y / 2.0, 0)
		pivo.add_child(mesh)
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


## Prédio com modelo 3D, esticado para ocupar exatamente o bloco (o mesmo espaço que a colisão usa).
## Se o modelo não carregar, usa a caixa de antes.
func _criar_predio(indice: int, centro: Vector3, tamanho: Vector3) -> void:
	var cena := load(MODELOS_PREDIOS[indice]) as PackedScene
	if cena == null:
		_adicionar_caixa(centro, tamanho, Color(0.55, 0.5, 0.45))
		return
	var suporte := Node3D.new()
	add_child(suporte)
	suporte.add_child(cena.instantiate())
	var caixa := _caixa_do_modelo(suporte)
	if caixa.size.x <= 0.0 or caixa.size.y <= 0.0 or caixa.size.z <= 0.0:
		suporte.queue_free()
		_adicionar_caixa(centro, tamanho, Color(0.55, 0.5, 0.45))
		return
	var escala := Vector3(tamanho.x / caixa.size.x, tamanho.y / caixa.size.y, tamanho.z / caixa.size.z)
	var meio := caixa.get_center()
	suporte.scale = escala
	suporte.position = Vector3(centro.x - meio.x * escala.x, -caixa.position.y * escala.y, centro.z - meio.z * escala.z)


## Caixa que envolve todas as malhas do modelo, no sistema do suporte.
func _caixa_do_modelo(suporte: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for no in suporte.find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		if malha.mesh == null:
			continue
		var no_no_suporte := suporte.global_transform.affine_inverse() * malha.global_transform
		var caixa_da_malha := no_no_suporte * malha.get_aabb()
		caixa = caixa_da_malha if primeira else caixa.merge(caixa_da_malha)
		primeira = false
	return caixa


func _adicionar_caixa(pos: Vector3, tamanho: Vector3, cor: Color) -> void:
	var box := BoxMesh.new()
	box.size = tamanho
	box.material = _material(cor)

	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = pos
	add_child(mesh)


func _criar_detetive() -> void:
	var cor := Color.from_string(str(GameState.player.get("cor", "")), COR_DETETIVE_PADRAO)
	_detetive = Node3D.new()
	_detetive.position = _entrada
	add_child(_detetive)
	_visual_detetive = Node3D.new()
	_detetive.add_child(_visual_detetive)

	var cena := load(MODELO_DETETIVE) as PackedScene
	if cena == null:
		var modelo := MeshInstance3D.new()
		var malha := CapsuleMesh.new()
		malha.material = _material(cor)
		modelo.mesh = malha
		modelo.position = Vector3(0, 1, 0)
		_visual_detetive.add_child(modelo)
		return

	var modelo := cena.instantiate() as Node3D
	_visual_detetive.add_child(modelo)
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		(no as MeshInstance3D).material_override = _material(cor)


# ---------- Pistas e pessoas ----------

func _criar_pista(pista: Dictionary) -> void:
	var clue := CLUE_SCRIPT.new()
	clue.setup(pista)
	clue.clicked.connect(pista_clicada.emit)
	add_child(clue)
	_pistas[clue.clue_id] = clue
	if clue.clue_id in CaseManager.found_clues:
		clue.mark_found()


func _criar_pessoa(pessoa: Dictionary, indice: int) -> void:
	var corpo := StaticBody3D.new()
	corpo.position = _vetor(pessoa.get("posicao", null), Vector3(-3 + 3 * indice, 1, -3))
	add_child(corpo)

	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.5
	capsula.height = 2.0
	var colisao := CollisionShape3D.new()
	colisao.shape = capsula
	corpo.add_child(colisao)

	_criar_modelo_pessoa(corpo, _cor_pessoa(pessoa))

	var rotulo := Label3D.new()
	rotulo.text = str(pessoa.get("nome", "Pessoa"))
	rotulo.position = Vector3(0, 1.5, 0)
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.font_size = 48
	rotulo.pixel_size = 0.01
	corpo.add_child(rotulo)

	corpo.input_event.connect(_on_pessoa_input.bind(pessoa))


## Modelo 3D da pessoa (CC0, ver assets/models/LICENCAS.md). A origem do modelo fica no chão;
## o corpo está a 1 m do chão, então o modelo desce 1 m. Cor vem do personagem.
func _criar_modelo_pessoa(corpo: Node3D, cor: Color) -> void:
	var cena := load(MODELO_PESSOA) as PackedScene
	if cena == null:
		var modelo := MeshInstance3D.new()
		var malha := CapsuleMesh.new()
		malha.material = _material(cor)
		modelo.mesh = malha
		corpo.add_child(modelo)
		return

	var modelo := cena.instantiate() as Node3D
	modelo.position = Vector3(0, -1, 0)
	corpo.add_child(modelo)
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		(no as MeshInstance3D).material_override = _material(cor)


func _on_pessoa_input(_camera_node: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, pessoa: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pessoa_clicada.emit(pessoa)


func _cor_pessoa(pessoa: Dictionary) -> Color:
	var personagem_id := str(pessoa.get("personagem_id", ""))
	if personagem_id != "":
		var personagem := CharacterRegistry.get_character(personagem_id)
		if not personagem.is_empty():
			return Color.from_string(str(personagem.get("cor", "")), COR_PESSOA_PADRAO)
	return COR_PESSOA_PADRAO


# ---------- Utilidades ----------

func _material(cor: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	return material


func _vetor(valor: Variant, padrao: Vector3) -> Vector3:
	if valor is Array and valor.size() == 3:
		return Vector3(float(valor[0]), float(valor[1]), float(valor[2]))
	return padrao
