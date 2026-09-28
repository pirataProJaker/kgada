@tool
extends Node3D
class_name WoodenDoor

## Puerta de madera con textura PSX y bisagra interactiva (tecla E).
## Medida estándar correspondiente al marco de puerta: 1.30m ancho x 2.10m alto.

@export var door_width: float = 1.30
@export var door_height: float = 2.10
@export var door_thickness: float = 0.06
@export var open_angle_deg: float = 105.0
@export var angular_speed: float = 220.0

var _is_open := false
var _current_angle := 0.0
var _target_angle := 0.0

var hinge: Node3D
var door_slab: StaticBody3D
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D

func _ready() -> void:
	_setup_door_geometry()

func _setup_door_geometry() -> void:
	# 1. Hinge (Pivote en el marco izquierdo x = -w/2)
	hinge = get_node_or_null("Hinge")
	if hinge == null:
		hinge = Node3D.new()
		hinge.name = "Hinge"
		add_child(hinge)

	hinge.position = Vector3(-door_width * 0.5, 0.0, 0.0)

	# 2. Hoja de la puerta (StaticBody3D)
	door_slab = hinge.get_node_or_null("DoorSlab")
	if door_slab == null:
		door_slab = StaticBody3D.new()
		door_slab.name = "DoorSlab"
		var slab_script = load("res://world/city/door_slab.gd")
		if slab_script:
			door_slab.set_script(slab_script)
		hinge.add_child(door_slab)

	door_slab.position = Vector3(door_width * 0.5, door_height * 0.5, 0.0)

	# 3. Colisión de la hoja
	collision_shape = door_slab.get_node_or_null("CollisionShape3D")
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(door_width, door_height, door_thickness)
		collision_shape.shape = box
		door_slab.add_child(collision_shape)
	elif collision_shape.shape is BoxShape3D:
		collision_shape.shape.size = Vector3(door_width, door_height, door_thickness)

	# 4. Malla texturizada con mapeo UV 0..1 en caras frontal y trasera
	var door_mesh := _generate_door_mesh(door_width, door_height, door_thickness)

	var mat := StandardMaterial3D.new()
	var tex: Texture2D
	if ResourceLoader.exists("res://assets/building/wood_door.png"):
		tex = load("res://assets/building/wood_door.png")
	if tex == null:
		var img := Image.new()
		if img.load("res://assets/building/wood_door.png") == OK:
			tex = ImageTexture.create_from_image(img)
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85

	mesh_instance = door_slab.get_node_or_null("MeshInstance3D")
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		mesh_instance.mesh = door_mesh
		mesh_instance.material_override = mat
		door_slab.add_child(mesh_instance)
	else:
		mesh_instance.mesh = door_mesh
		mesh_instance.material_override = mat

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if hinge == null:
		return
	if absf(_target_angle - _current_angle) > 0.05:
		var step := clampf(_target_angle - _current_angle, -angular_speed * delta, angular_speed * delta)
		_current_angle += step
		hinge.rotation_degrees.y = _current_angle

## Punto de interacción al presionar [E] (ver InteractController)
func interact(interactor: Node = null) -> void:
	toggle_door(interactor)

func toggle_door(interactor: Node = null) -> void:
	_is_open = not _is_open
	if _is_open:
		var open_sign := 1.0
		if interactor and interactor is Node3D:
			var local_pos := to_local(interactor.global_position)
			if local_pos.z > 0.0:
				open_sign = -1.0
			else:
				open_sign = 1.0
		_target_angle = open_angle_deg * open_sign
	else:
		_target_angle = 0.0

static func _generate_door_mesh(w: float, h: float, d: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := w * 0.5
	var hy := h * 0.5
	var hz := d * 0.5

	# Cara frontal (+Z)
	st.set_normal(Vector3(0, 0, 1))
	st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(-hx, -hy, hz))
	st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3(hx, -hy, hz))
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(hx, hy, hz))

	st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(-hx, -hy, hz))
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(hx, hy, hz))
	st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(-hx, hy, hz))

	# Cara trasera (-Z)
	st.set_normal(Vector3(0, 0, -1))
	st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(hx, -hy, -hz))
	st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3(-hx, -hy, -hz))
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(-hx, hy, -hz))

	st.set_uv(Vector2(0, 1)); st.add_vertex(Vector3(hx, -hy, -hz))
	st.set_uv(Vector2(1, 0)); st.add_vertex(Vector3(-hx, hy, -hz))
	st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(hx, hy, -hz))

	# Borde izquierdo (-X)
	st.set_normal(Vector3(-1, 0, 0))
	st.set_uv(Vector2(0.05, 1)); st.add_vertex(Vector3(-hx, -hy, -hz))
	st.set_uv(Vector2(0.05, 1)); st.add_vertex(Vector3(-hx, -hy, hz))
	st.set_uv(Vector2(0.05, 0)); st.add_vertex(Vector3(-hx, hy, hz))

	st.set_uv(Vector2(0.05, 1)); st.add_vertex(Vector3(-hx, -hy, -hz))
	st.set_uv(Vector2(0.05, 0)); st.add_vertex(Vector3(-hx, hy, hz))
	st.set_uv(Vector2(0.05, 0)); st.add_vertex(Vector3(-hx, hy, -hz))

	# Borde derecho (+X)
	st.set_normal(Vector3(1, 0, 0))
	st.set_uv(Vector2(0.95, 1)); st.add_vertex(Vector3(hx, -hy, hz))
	st.set_uv(Vector2(0.95, 1)); st.add_vertex(Vector3(hx, -hy, -hz))
	st.set_uv(Vector2(0.95, 0)); st.add_vertex(Vector3(hx, hy, -hz))

	st.set_uv(Vector2(0.95, 1)); st.add_vertex(Vector3(hx, -hy, hz))
	st.set_uv(Vector2(0.95, 0)); st.add_vertex(Vector3(hx, hy, -hz))
	st.set_uv(Vector2(0.95, 0)); st.add_vertex(Vector3(hx, hy, hz))

	# Borde superior (+Y)
	st.set_normal(Vector3(0, 1, 0))
	st.set_uv(Vector2(0, 0.05)); st.add_vertex(Vector3(-hx, hy, hz))
	st.set_uv(Vector2(1, 0.05)); st.add_vertex(Vector3(hx, hy, hz))
	st.set_uv(Vector2(1, 0.05)); st.add_vertex(Vector3(hx, hy, -hz))

	st.set_uv(Vector2(0, 0.05)); st.add_vertex(Vector3(-hx, hy, hz))
	st.set_uv(Vector2(1, 0.05)); st.add_vertex(Vector3(hx, hy, -hz))
	st.set_uv(Vector2(0, 0.05)); st.add_vertex(Vector3(-hx, hy, -hz))

	# Borde inferior (-Y)
	st.set_normal(Vector3(0, -1, 0))
	st.set_uv(Vector2(0, 0.95)); st.add_vertex(Vector3(-hx, -hy, -hz))
	st.set_uv(Vector2(1, 0.95)); st.add_vertex(Vector3(hx, -hy, -hz))
	st.set_uv(Vector2(1, 0.95)); st.add_vertex(Vector3(hx, -hy, hz))

	st.set_uv(Vector2(0, 0.95)); st.add_vertex(Vector3(-hx, -hy, -hz))
	st.set_uv(Vector2(1, 0.95)); st.add_vertex(Vector3(hx, -hy, hz))
	st.set_uv(Vector2(0, 0.95)); st.add_vertex(Vector3(-hx, -hy, hz))

	return st.commit()
