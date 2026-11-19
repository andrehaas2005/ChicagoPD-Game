extends StaticBody3D
## Pista clicável no cenário. A cena de investigação cria uma instância para cada
## pista do caso, a partir dos dados do JSON.

signal clicked(clue_id: String, description: String)

const MODELO_PISTA := "res://assets/models/pista_marcador.glb"

var clue_id := ""
var description := ""
var _material: StandardMaterial3D


func setup(pista: Dictionary) -> void:
	clue_id = pista.get("id", "")
	description = pista.get("descricao", "")

	var pos: Array = pista.get("posicao", [0, 0.15, 0])
	position = Vector3(pos[0], pos[1], pos[2])

	var size := Vector3(0.5, 0.3, 0.5)

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.8, 0.0)
	_criar_visual()

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	input_event.connect(_on_input_event)


## Marca a pista como encontrada: muda a cor para verde e deixa de ser clicável.
func mark_found() -> void:
	if _material:
		_material.albedo_color = Color(0.2, 0.8, 0.2)
	input_ray_pickable = false


## Modelo 3D do marcador de evidência (CC0, ver assets/models/LICENCAS.md).
## Se o arquivo não existir, usa um cubo como antes.
func _criar_visual() -> void:
	var cena := load(MODELO_PISTA) as PackedScene
	if cena == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 0.3, 0.5)
		box.material = _material
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		add_child(mesh)
		return

	var modelo := cena.instantiate()
	add_child(modelo)
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		(no as MeshInstance3D).material_override = _material


func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(clue_id, description)
