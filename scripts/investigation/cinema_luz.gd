extends RefCounted
## Iluminação de cinema por ambiente. Sem class_name de propósito: carregar por preload.
## Os dados vêm do campo opcional "luz" de data/ambientes/<id>.json, ex.: {"cor": "#ffd9a0", "energia": 1.0}.
## Ruas não passam por aqui para a luz (mantêm a DirectionalLight3D padrão); só ganham névoa leve.

const COR_FUNDO_INTERIOR := Color(0.02, 0.02, 0.03)
const COR_NEVOA := Color(0.55, 0.58, 0.62)
const DENSIDADE_NEVOA := 0.012


## Aplica cor e energia do ambiente na luz principal.
static func aplicar_luz(luz: DirectionalLight3D, dados: Dictionary) -> void:
	luz.light_color = _cor(dados)
	luz.light_energy = _energia(dados)


## Ambiente de interior: fundo escuro e luz ambiente da mesma cor da luz principal, mais fraca.
static func ambiente_interior(dados: Dictionary) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COR_FUNDO_INTERIOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _cor(dados).darkened(0.45)
	env.ambient_light_energy = 0.5 * _energia(dados)
	return env


## Ambiente de rua: só névoa leve no fundo da cidade.
static func ambiente_rua() -> Environment:
	var env := Environment.new()
	env.fog_enabled = true
	env.fog_light_color = COR_NEVOA
	env.fog_density = DENSIDADE_NEVOA
	return env


static func _cor(dados: Dictionary) -> Color:
	return Color.from_string(str(dados.get("cor", "")), Color.WHITE)


static func _energia(dados: Dictionary) -> float:
	return float(dados.get("energia", 1.0))
