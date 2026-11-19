extends Node
## Autoload: relógio do caso. O caso dura 48 horas de jogo; 0 minutos = dia 1, 08:00.
## Reviravoltas agendadas disparam o signal `reveal` quando o tempo passa do horário delas.

const DAY_START_HOUR := 8
const LIMIT_MINUTES := 2880
const MINUTES_PER_DAY := 1440

signal time_changed(minutes: int)
signal time_expired()
signal reveal(text: String, clue_id: String)

var _now := 0
var _expired := false
var _reversals: Array[Dictionary] = []


## Volta para o dia 1, 08:00 e remove as reviravoltas agendadas.
func reset() -> void:
	_now = 0
	_expired = false
	_reversals.clear()


## Agenda as reviravoltas do caso: lista de {hora, descricao, revela_pista}.
## `hora` é absoluta, contada a partir do dia 1, 08:00. Chamado por CaseState.reset().
func schedule_reversals(events: Array) -> void:
	_reversals.clear()
	for evento in events:
		if typeof(evento) != TYPE_DICTIONARY:
			continue
		var pista: Variant = evento.get("revela_pista", null)
		_reversals.append({
			"minutes": int(evento.get("hora", 0)) * 60,
			"text": str(evento.get("descricao", "")),
			"clue_id": "" if pista == null else str(pista),
			"fired": false,
		})


## Minutos desde o início (0 = dia 1, 08:00).
func now_minutes() -> int:
	return _now


func is_expired() -> bool:
	return _expired


## Avança o tempo. Dispara reviravoltas vencidas, emite time_changed e, ao chegar
## em LIMIT_MINUTES, emite time_expired (uma única vez).
func advance_minutes(minutos: int) -> void:
	if _expired or minutos <= 0:
		return
	_now = mini(_now + minutos, LIMIT_MINUTES)
	_disparar_reviravoltas()
	time_changed.emit(_now)
	if _now >= LIMIT_MINUTES:
		_expired = true
		time_expired.emit()


## Ex.: "Dia 2 · 14:30".
func format_now() -> String:
	return format_at(_now)


## Formata um instante (em minutos desde o início). Ex.: "Dia 1 · 08:00".
@warning_ignore("integer_division")
func format_at(minutos: int) -> String:
	var total := _total(minutos)
	var dia := total / MINUTES_PER_DAY + 1
	var hora := (total % MINUTES_PER_DAY) / 60
	var minuto := total % 60
	return "Dia %d · %02d:%02d" % [dia, hora, minuto]


## (dia 1..3, hora 0..23) do instante atual, para checar rotinas.
@warning_ignore("integer_division")
func day_and_hour() -> Vector2i:
	var total := _total(_now)
	return Vector2i(total / MINUTES_PER_DAY + 1, (total % MINUTES_PER_DAY) / 60)


func _total(minutos: int) -> int:
	return DAY_START_HOUR * 60 + minutos


func _disparar_reviravoltas() -> void:
	for evento in _reversals:
		if not evento["fired"] and int(evento["minutes"]) <= _now:
			evento["fired"] = true
			reveal.emit(str(evento["text"]), str(evento["clue_id"]))
