extends Control
## Escolha ou criação do detetive do jogador. Duas abas: personagens da franquia
## e criação de um detetive original. Interface construída por código.

const COR_FUNDO := Color("#14171c")
const COR_CARD := Color("#1f242c")
const COR_DESTAQUE := Color("#e8c15a")
const COR_ERRO := Color("#e06c6c")
const CARGOS := ["Detetive", "Detetive Sênior", "Sargento", "Investigador Particular"]
const CORES := {
	"Azul aço": "#3a5a7a",
	"Vinho": "#8b2e2e",
	"Verde": "#2e6b4f",
	"Ocre": "#7a5c2e",
	"Roxo": "#5b3a7a",
	"Grafite": "#4a4a4a",
	"Ciano": "#1f6f8b",
}

var _campo_nome: LineEdit
var _seletor_cargo: OptionButton
var _seletor_cor: OptionButton
var _erro: Label


func _ready() -> void:
	_construir_interface()


func _construir_interface() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(PRESET_FULL_RECT)
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(PRESET_FULL_RECT)
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margem.add_theme_constant_override(lado, 16)
	add_child(margem)

	var principal := VBoxContainer.new()
	principal.add_theme_constant_override("separation", 12)
	margem.add_child(principal)

	var topo := HBoxContainer.new()
	principal.add_child(topo)
	topo.add_child(_criar_botao("Voltar", _on_voltar, Vector2(120, 40)))

	var titulo := Label.new()
	titulo.text = "Escolha o detetive"
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", COR_DESTAQUE)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(titulo)

	var abas := TabContainer.new()
	abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	principal.add_child(abas)

	abas.add_child(_criar_aba_personagens())
	abas.set_tab_title(0, "Escolher personagem")
	abas.add_child(_criar_aba_criar())
	abas.set_tab_title(1, "Criar novo detetive")


func _criar_aba_personagens() -> Control:
	var rolagem := ScrollContainer.new()
	rolagem.name = "Personagens"
	rolagem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 12)
	rolagem.add_child(lista)

	# Agrupa os personagens jogáveis pela franquia, mantendo a ordem do registro
	var por_franquia := {}
	var ordem_franquias: Array[String] = []
	for personagem in CharacterRegistry.list_characters():
		if not personagem.get("jogavel", false):
			continue
		var franquia := str(personagem.get("franquia", "Outros"))
		if not por_franquia.has(franquia):
			por_franquia[franquia] = []
			ordem_franquias.append(franquia)
		por_franquia[franquia].append(personagem)

	if ordem_franquias.is_empty():
		var vazio := Label.new()
		vazio.text = "Nenhum personagem disponível. Use \"Criar novo detetive\"."
		lista.add_child(vazio)

	for franquia in ordem_franquias:
		var cabecalho := Label.new()
		cabecalho.text = franquia
		cabecalho.add_theme_font_size_override("font_size", 22)
		lista.add_child(cabecalho)
		for personagem in por_franquia[franquia]:
			lista.add_child(_criar_card_personagem(personagem))
	return rolagem


func _criar_card_personagem(personagem: Dictionary) -> Control:
	var cor := Color.from_string(str(personagem.get("cor", "")), Color.GRAY)
	var painel := _criar_painel()
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 16)
	painel.add_child(linha)

	var quadrado := ColorRect.new()
	quadrado.color = cor
	quadrado.custom_minimum_size = Vector2(56, 56)
	linha.add_child(quadrado)

	var texto := VBoxContainer.new()
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(texto)

	var nome := Label.new()
	nome.text = str(personagem.get("nome", "Sem nome"))
	nome.add_theme_font_size_override("font_size", 20)
	texto.add_child(nome)

	var cargo := Label.new()
	cargo.text = str(personagem.get("cargo", ""))
	cargo.add_theme_color_override("font_color", COR_DESTAQUE)
	texto.add_child(cargo)

	var descricao := Label.new()
	descricao.text = str(personagem.get("descricao", ""))
	descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descricao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.add_child(descricao)

	var escolher := _criar_botao("Escolher", _on_personagem_escolhido.bind(personagem), Vector2(140, 44))
	escolher.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(escolher)
	return painel


func _criar_aba_criar() -> Control:
	var centro := CenterContainer.new()
	centro.name = "Criar"

	var formulario := VBoxContainer.new()
	formulario.custom_minimum_size = Vector2(480, 0)
	formulario.add_theme_constant_override("separation", 10)
	centro.add_child(formulario)

	formulario.add_child(_criar_rotulo("Nome do detetive"))
	_campo_nome = LineEdit.new()
	_campo_nome.placeholder_text = "Ex.: Ana Costa"
	_campo_nome.max_length = 40
	formulario.add_child(_campo_nome)

	formulario.add_child(_criar_rotulo("Cargo"))
	_seletor_cargo = OptionButton.new()
	for cargo in CARGOS:
		_seletor_cargo.add_item(cargo)
	formulario.add_child(_seletor_cargo)

	formulario.add_child(_criar_rotulo("Cor do distintivo"))
	_seletor_cor = OptionButton.new()
	for nome_cor in CORES:
		_seletor_cor.add_item(nome_cor)
		_seletor_cor.set_item_metadata(_seletor_cor.item_count - 1, CORES[nome_cor])
	formulario.add_child(_seletor_cor)

	_erro = Label.new()
	_erro.add_theme_color_override("font_color", COR_ERRO)
	_erro.visible = false
	formulario.add_child(_erro)

	formulario.add_child(_criar_botao("Confirmar", _on_confirmar, Vector2(480, 48)))
	return centro


func _criar_botao(texto: String, acao: Callable, minimo: Vector2) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = minimo
	botao.pressed.connect(acao)
	return botao


func _criar_rotulo(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	return rotulo


func _criar_painel() -> PanelContainer:
	var painel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_CARD
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(16)
	painel.add_theme_stylebox_override("panel", estilo)
	return painel


func _on_personagem_escolhido(personagem: Dictionary) -> void:
	GameState.set_player({
		"nome": str(personagem.get("nome", "")),
		"origem": "franquia",
		"character_id": str(personagem.get("id", "")),
		"cargo": str(personagem.get("cargo", "")),
		"cor": str(personagem.get("cor", "")),
	})
	GameState.go_to("case_select")


func _on_confirmar() -> void:
	var nome := _campo_nome.text.strip_edges()
	if nome.is_empty():
		_erro.text = "Digite um nome para o detetive."
		_erro.visible = true
		_campo_nome.grab_focus()
		return
	_erro.visible = false
	var cargo := _seletor_cargo.get_item_text(_seletor_cargo.selected)
	var cor := str(_seletor_cor.get_item_metadata(_seletor_cor.selected))
	GameState.set_player({
		"nome": nome,
		"origem": "criado",
		"character_id": "",
		"cargo": cargo,
		"cor": cor,
	})
	GameState.go_to("case_select")


func _on_voltar() -> void:
	GameState.go_to("menu")
