class_name VehiclePart
extends Node3D

## Nodo 3D interactivo para cualquier pieza vehicular modular (Play Sector X)
## Soporta estados: Instalada en socket, desmontada como prop físico, o sostenida en manos.

signal interacted(player)
signal state_changed()

@export var data: VehiclePartData = null
@export var is_hinged: bool = false
@export var open_angle_deg: float = 65.0
@export var open_axis: Vector3 = Vector3.UP

var current_socket: Node = null
var is_open: bool = false
var _target_rot: Basis = Basis.IDENTITY
var _animating: bool = false

var mesh_instance: MeshInstance3D = null


func _ready() -> void:
	_target_rot = transform.basis


func _process(delta: float) -> void:
	if _animating and is_hinged:
		transform.basis = transform.basis.slerp(_target_rot, delta * 8.0)
		if transform.basis.is_equal_approx(_target_rot):
			transform.basis = _target_rot
			_animating = false


## Alterna la apertura de puertas, capó o maletero
func toggle_open() -> void:
	if not is_hinged:
		return
	is_open = !is_open
	_animating = true
	var angle := deg_to_rad(open_angle_deg if is_open else 0.0)
	_target_rot = Basis(open_axis.normalized(), angle)
	state_changed.emit()


## Retorna el texto del prompt para la interacción en primera persona
func get_interaction_prompt() -> String:
	if data == null:
		return "Interactuar"
	if is_hinged:
		var action := "Cerrar" if is_open else "Abrir"
		return "%s %s [E]" % [action, data.display_name]
	if current_socket != null:
		return "Desmontar %s [Mantener E]" % data.display_name
	return "Recoger %s [E]" % data.display_name


## Configura la malla visual de esta pieza
func set_mesh(m: Mesh, mat: Material = null) -> void:
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "PartMesh"
		add_child(mesh_instance)
	mesh_instance.mesh = m
	if mat != null:
		mesh_instance.material_override = mat
