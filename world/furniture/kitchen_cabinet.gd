class_name KitchenCabinet
extends Node3D

## Gabinete de Cocina y Alacena Procedural con Puertas Abatibles
## - Soporta Mueble Bajo con Encimera de Granito (BASE_COUNTER) y Alacena Aérea (WALL_HANGING)
## - Mapeado a la textura res://assets/textures/furniture/cabinets.png
## - 2 Puertas de madera abatibles independientes (bisagra izquierda y derecha)
## - Cavidad interior hueca con repisa para almacenar vajilla y despensa
## - Diseñado 100% con cubos UV-mapeados para máxima optimización y GPU Instancing

const TEXTURE_PATH: String = "res://assets/textures/furniture/cabinets.png"

enum CabinetType {
	BASE_COUNTER = 0, ## Mueble bajo mesada con cubierta de granito, cajón superior y zócalo
	WALL_HANGING = 1  ## Alacena superior aérea de pared con 2 puertas
}

@export var cabinet_type: CabinetType = CabinetType.BASE_COUNTER:
	set(val):
		cabinet_type = val
		if is_inside_tree():
			_build_cabinet()

@export_group("Dimensiones")
@export var width: float = 0.85         ## Ancho total (85cm)
@export var depth: float = 0.60         ## Profundidad (60cm en base, 36cm en aéreo)
@export var height: float = 0.86        ## Altura (86cm en base, 68cm en aéreo)
@export var wall_thickness: float = 0.030 ## Grosor de paredes laterales (3cm)
@export var door_thickness: float = 0.025 ## Grosor de las puertas (2.5cm)

@export_group("Apertura de Puertas")
@export_range(0.0, 1.0) var left_door_open_ratio: float = 0.0:
	set(val):
		left_door_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angles()

@export_range(0.0, 1.0) var right_door_open_ratio: float = 0.0:
	set(val):
		right_door_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angles()

const MAX_DOOR_ANGLE: float = deg_to_rad(105.0)

var _body_mesh_instance: MeshInstance3D = null
var _left_door_pivot: Node3D = null
var _left_door_mesh_instance: MeshInstance3D = null
var _right_door_pivot: Node3D = null
var _right_door_mesh_instance: MeshInstance3D = null
var _collision_body: StaticBody3D = null

static var _cached_material: StandardMaterial3D = null
static var _cached_base_mesh: ArrayMesh = null
static var _cached_wall_mesh: ArrayMesh = null
static var _cached_door_mesh: ArrayMesh = null
static var _cached_complete_base_mesh: ArrayMesh = null
static var _cached_complete_wall_mesh: ArrayMesh = null


## Retorna la malla compartida del gabinete para GPU Instancing
static func get_shared_body_mesh(type: int = 0) -> ArrayMesh:
	if type == 0: # BASE_COUNTER
		if _cached_base_mesh == null:
			var is_base := true
			var kick_h := 0.08
			var kick_inset := 0.04
			var counter_t := 0.038
			var drawer_h := 0.12
			var doors_y_bottom := kick_h
			var doors_y_top := 0.90 - counter_t - drawer_h
			var doors_h := doors_y_top - doors_y_bottom
			var body_d := 0.65 - 0.025
			_cached_base_mesh = _build_cabinet_body_mesh(0.85, body_d, 0.90, 0.025, is_base, kick_h, kick_inset, counter_t, drawer_h, doors_h)
		return _cached_base_mesh
	else: # WALL_HANGING
		if _cached_wall_mesh == null:
			var is_base := false
			var kick_h := 0.0
			var kick_inset := 0.0
			var counter_t := 0.0
			var drawer_h := 0.0
			var doors_h := 0.70
			var body_d := 0.38 - 0.025
			_cached_wall_mesh = _build_cabinet_body_mesh(0.85, body_d, 0.70, 0.025, is_base, kick_h, kick_inset, counter_t, drawer_h, doors_h)
		return _cached_wall_mesh


## Retorna la malla compartida completa (cuerpo + 2 puertas cerradas) para GPU Instancing en 1 Draw Call
static func get_shared_mesh(type: int = 0) -> ArrayMesh:
	if type == 0:
		if _cached_complete_base_mesh != null:
			return _cached_complete_base_mesh
		var body := get_shared_body_mesh(0)
		var w := 0.85
		var body_d := 0.65 - 0.025
		var kick_h := 0.08
		var counter_t := 0.038
		var drawer_h := 0.12
		var doors_y_bottom := kick_h
		var doors_y_top := 0.90 - counter_t - drawer_h
		var doors_h := doors_y_top - doors_y_bottom
		var single_door_w := (w - 0.008) * 0.5
		var door_t := 0.025
		var door_mesh := _build_single_door_mesh(single_door_w, doors_h, door_t)
		var hinge_z := body_d * 0.5

		var left_t := Transform3D(Basis.IDENTITY, Vector3(-w * 0.5, doors_y_bottom, hinge_z))
		var right_t := Transform3D(Basis.IDENTITY, Vector3(w * 0.5 - single_door_w, doors_y_bottom, hinge_z))

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(body, 0, Transform3D.IDENTITY)
		st.append_from(door_mesh, 0, left_t)
		st.append_from(door_mesh, 0, right_t)
		st.generate_normals()
		st.generate_tangents()
		_cached_complete_base_mesh = st.commit()
		return _cached_complete_base_mesh
	else:
		if _cached_complete_wall_mesh != null:
			return _cached_complete_wall_mesh
		var body := get_shared_body_mesh(1)
		var w := 0.85
		var body_d := 0.38 - 0.025
		var doors_h := 0.70
		var single_door_w := (w - 0.008) * 0.5
		var door_t := 0.025
		var door_mesh := _build_single_door_mesh(single_door_w, doors_h, door_t)
		var hinge_z := body_d * 0.5

		var left_t := Transform3D(Basis.IDENTITY, Vector3(-w * 0.5, 0.0, hinge_z))
		var right_t := Transform3D(Basis.IDENTITY, Vector3(w * 0.5 - single_door_w, 0.0, hinge_z))

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(body, 0, Transform3D.IDENTITY)
		st.append_from(door_mesh, 0, left_t)
		st.append_from(door_mesh, 0, right_t)
		st.generate_normals()
		st.generate_tangents()
		_cached_complete_wall_mesh = st.commit()
		return _cached_complete_wall_mesh


## Retorna las cajas de colisión para el sistema MultiMesh
static func get_collision_boxes(type: int = 0, w: float = 0.85, d: float = 0.65, h: float = 0.90) -> Array[Dictionary]:
	var eff_d := d if type == 0 else minf(d, 0.38)
	var eff_h := h if type == 0 else minf(h, 0.70)
	return [
		{
			"position": Vector3(0.0, eff_h * 0.5, 0.0),
			"size": Vector3(w, eff_h, eff_d)
		}
	]


func _ready() -> void:
	_build_cabinet()


func _build_cabinet() -> void:
	for child in get_children():
		child.queue_free()

	var mat := _get_or_create_material()

	var effective_depth := depth
	var effective_height := height
	if cabinet_type == CabinetType.WALL_HANGING:
		effective_depth = minf(depth, 0.38)
		effective_height = minf(height, 0.70)

	var is_base := (cabinet_type == CabinetType.BASE_COUNTER)
	var kick_h := 0.08 if is_base else 0.0
	var kick_inset := 0.04 if is_base else 0.0
	var counter_t := 0.038 if is_base else 0.0
	var drawer_h := 0.12 if is_base else 0.0

	var doors_y_bottom := kick_h
	var doors_y_top := effective_height - counter_t - drawer_h
	var doors_h := doors_y_top - doors_y_bottom

	var body_d := effective_depth - door_thickness

	# 1. Cuerpo / Carcasa del Gabinete
	var body_mesh := _build_cabinet_body_mesh(width, body_d, effective_height, wall_thickness, is_base, kick_h, kick_inset, counter_t, drawer_h, doors_h)
	_body_mesh_instance = MeshInstance3D.new()
	_body_mesh_instance.name = "CabinetBodyMesh"
	_body_mesh_instance.mesh = body_mesh
	_body_mesh_instance.material_override = mat
	add_child(_body_mesh_instance)

	# 2. Puerta Izquierda (Bisagra en X = -half_w)
	var half_w := width * 0.5
	var single_door_w := (width - 0.008) * 0.5
	var hinge_z := body_d * 0.5

	_left_door_pivot = Node3D.new()
	_left_door_pivot.name = "LeftDoorPivot"
	_left_door_pivot.position = Vector3(-half_w, doors_y_bottom, hinge_z)
	add_child(_left_door_pivot)

	var door_mesh := _build_single_door_mesh(single_door_w, doors_h, door_thickness)
	_left_door_mesh_instance = MeshInstance3D.new()
	_left_door_mesh_instance.name = "LeftDoorMesh"
	_left_door_mesh_instance.mesh = door_mesh
	_left_door_mesh_instance.material_override = mat
	_left_door_mesh_instance.position = Vector3(0.0, 0.0, 0.0) # Se extiende hacia +X
	_left_door_pivot.add_child(_left_door_mesh_instance)

	# 3. Puerta Derecha (Bisagra en X = +half_w)
	_right_door_pivot = Node3D.new()
	_right_door_pivot.name = "RightDoorPivot"
	_right_door_pivot.position = Vector3(half_w, doors_y_bottom, hinge_z)
	add_child(_right_door_pivot)

	_right_door_mesh_instance = MeshInstance3D.new()
	_right_door_mesh_instance.name = "RightDoorMesh"
	_right_door_mesh_instance.mesh = door_mesh
	_right_door_mesh_instance.material_override = mat
	_right_door_mesh_instance.position = Vector3(-single_door_w, 0.0, 0.0) # Se extiende hacia -X
	_right_door_pivot.add_child(_right_door_mesh_instance)

	_setup_collision(width, body_d, effective_height, single_door_w, doors_h, door_thickness)
	_update_door_angles()


func _update_door_angles() -> void:
	if _left_door_pivot:
		# Bisagra izquierda rota hacia afuera en sentido horario negativo (-Y)
		_left_door_pivot.rotation.y = -left_door_open_ratio * MAX_DOOR_ANGLE
	if _right_door_pivot:
		# Bisagra derecha rota hacia afuera en sentido horario positivo (+Y)
		_right_door_pivot.rotation.y = right_door_open_ratio * MAX_DOOR_ANGLE


## Abre o cierra la puerta izquierda
func toggle_left_door(animated: bool = true) -> void:
	var target := 1.0 if left_door_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "left_door_open_ratio", target, 0.40)
	else:
		left_door_open_ratio = target


## Abre o cierra la puerta derecha
func toggle_right_door(animated: bool = true) -> void:
	var target := 1.0 if right_door_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "right_door_open_ratio", target, 0.40)
	else:
		right_door_open_ratio = target


## Abre o cierra ambas puertas simultáneamente
func toggle_doors(animated: bool = true) -> void:
	var target := 1.0 if (left_door_open_ratio < 0.5 or right_door_open_ratio < 0.5) else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "left_door_open_ratio", target, 0.40)
		tween.parallel().tween_property(self, "right_door_open_ratio", target, 0.40)
	else:
		left_door_open_ratio = target
		right_door_open_ratio = target


## Punto de interacción al presionar [E] (ver InteractController)
func interact(_interactor: Node = null) -> void:
	toggle_doors()


# =========================================================================
# GENERACIÓN DE GEOMETRÍA (SurfaceTool)
# =========================================================================

static func _build_cabinet_body_mesh(w: float, d: float, h: float, wall_t: float, is_base: bool, kick_h: float, kick_inset: float, counter_t: float, drawer_h: float, doors_h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas cabinets.png (256x256):
	# - Granito: X [0..161]/256 = [0.005, 0.628], Y [0..88]/256 = [0.005, 0.343]
	# - Madera clara lateral: X [0..88]/256 = [0.005, 0.344], Y [89..255]/256 = [0.348, 0.995]
	# - Falso cajón superior: X [89..159]/256 = [0.348, 0.621], Y [95..115]/256 = [0.371, 0.449]
	# - Zócalo de madera cálida: X [89..159]/256 = [0.348, 0.621], Y [216..255]/256 = [0.845, 0.995]
	var uv_granite_min := Vector2(0.005, 0.005)
	var uv_granite_max := Vector2(0.628, 0.343)

	var uv_wood_min := Vector2(0.005, 0.348)
	var uv_wood_max := Vector2(0.344, 0.995)

	var uv_drawer_min := Vector2(0.348, 0.371)
	var uv_drawer_max := Vector2(0.621, 0.449)

	var uv_kick_min := Vector2(0.348, 0.845)
	var uv_kick_max := Vector2(0.621, 0.995)

	var hw := w * 0.5
	var hd := d * 0.5

	# 1. Pared Posterior (Fondo de madera)
	_add_box_st(st, Vector3(0.0, h * 0.5, -hd + wall_t * 0.5), Vector3(w, h, wall_t), uv_wood_min, uv_wood_max)

	# 2. Paredes Laterales de Madera Clara
	var side_d := d - wall_t
	var side_z := wall_t * 0.5
	_add_box_st(st, Vector3(-hw + wall_t * 0.5, h * 0.5, side_z), Vector3(wall_t, h, side_d), uv_wood_min, uv_wood_max)
	_add_box_st(st, Vector3(hw - wall_t * 0.5, h * 0.5, side_z), Vector3(wall_t, h, side_d), uv_wood_min, uv_wood_max)

	# 3. Base / Piso inferior del mueble
	var floor_y := kick_h + wall_t * 0.5
	_add_box_st(st, Vector3(0.0, floor_y, side_z), Vector3(w - wall_t * 2.0, wall_t, side_d), uv_wood_min, uv_wood_max)

	# 4. Repisa central interior divisoria
	var shelf_y := kick_h + doors_h * 0.5
	_add_box_st(st, Vector3(0.0, shelf_y, side_z - 0.01), Vector3(w - wall_t * 2.0 - 0.01, 0.018, side_d - 0.02), uv_wood_min, uv_wood_max)

	if is_base:
		# 5. Zócalo retranqueado inferior (Kickplate frontal)
		var kick_z := hd - kick_inset - 0.015
		_add_box_st(st, Vector3(0.0, kick_h * 0.5, kick_z), Vector3(w, kick_h, 0.03), uv_kick_min, uv_kick_max)

		# 6. Falsa faja / cajón superior de madera
		var drawer_y := h - counter_t - drawer_h * 0.5
		var drawer_z := hd - wall_t * 0.5
		_add_box_st(st, Vector3(0.0, drawer_y, drawer_z), Vector3(w, drawer_h, wall_t), uv_drawer_min, uv_drawer_max)

		# 7. Cubierta de Granito superior con voladizo frontal y lateral de 2cm
		var counter_w := w + 0.02
		var counter_d := d + 0.03
		var counter_z := side_z + 0.015
		var counter_y := h - counter_t * 0.5
		_add_countertop_st(st, Vector3(0.0, counter_y, counter_z), Vector3(counter_w, counter_t, counter_d), uv_granite_min, uv_granite_max)
	else:
		# Techo superior de madera en alacena aérea
		var roof_y := h - wall_t * 0.5
		_add_box_st(st, Vector3(0.0, roof_y, side_z), Vector3(w - wall_t * 2.0, wall_t, side_d), uv_wood_min, uv_wood_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Construye una hoja de puerta con panel biselado exactamente encuadrado
static func _build_single_door_mesh(w: float, h: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Puerta con marco y panel biselado shaker:
	# X [89..159]/256 = [0.348, 0.621], Y [115..216]/256 = [0.449, 0.844]
	var uv_door_front_min := Vector2(0.348, 0.449)
	var uv_door_front_max := Vector2(0.621, 0.844)

	var uv_wood_min := Vector2(0.005, 0.348)
	var uv_wood_max := Vector2(0.344, 0.995)

	var center := Vector3(w * 0.5, h * 0.5, thick * 0.5)
	var size := Vector3(w, h, thick)

	_add_door_box_st(st, center, size, uv_door_front_min, uv_door_front_max, uv_wood_min, uv_wood_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _add_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var v0 := center + Vector3(-hx, -hy, -hz)
	var v1 := center + Vector3( hx, -hy, -hz)
	var v2 := center + Vector3( hx,  hy, -hz)
	var v3 := center + Vector3(-hx,  hy, -hz)
	var v4 := center + Vector3(-hx, -hy,  hz)
	var v5 := center + Vector3( hx, -hy,  hz)
	var v6 := center + Vector3( hx,  hy,  hz)
	var v7 := center + Vector3(-hx,  hy,  hz)

	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_min, uv_max)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_min, uv_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_min, uv_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_min, uv_max)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_min, uv_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_min, uv_max)


static func _add_countertop_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var v0 := center + Vector3(-hx, -hy, -hz)
	var v1 := center + Vector3( hx, -hy, -hz)
	var v2 := center + Vector3( hx,  hy, -hz)
	var v3 := center + Vector3(-hx,  hy, -hz)
	var v4 := center + Vector3(-hx, -hy,  hz)
	var v5 := center + Vector3( hx, -hy,  hz)
	var v6 := center + Vector3( hx,  hy,  hz)
	var v7 := center + Vector3(-hx,  hy,  hz)

	# Granito en todas las caras visibles de la cubierta
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_min, uv_max)
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_min, uv_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_min, uv_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_min, uv_max)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_min, uv_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_min, uv_max)


static func _add_door_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_front_min: Vector2, uv_front_max: Vector2, uv_wood_min: Vector2, uv_wood_max: Vector2) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var v0 := center + Vector3(-hx, -hy, -hz)
	var v1 := center + Vector3( hx, -hy, -hz)
	var v2 := center + Vector3( hx,  hy, -hz)
	var v3 := center + Vector3(-hx,  hy, -hz)
	var v4 := center + Vector3(-hx, -hy,  hz)
	var v5 := center + Vector3( hx, -hy,  hz)
	var v6 := center + Vector3( hx,  hy,  hz)
	var v7 := center + Vector3(-hx,  hy,  hz)

	# +Z Frente con marco y moldura de madera biselada
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_front_min, uv_front_max)
	# Cantos y dorso con madera clara
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_wood_min, uv_wood_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_wood_min, uv_wood_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_wood_min, uv_wood_max)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_wood_min, uv_wood_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_wood_min, uv_wood_max)


static func _add_quad_st(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, norm: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
	var u0 := Vector2(uv_min.x, uv_max.y)
	var u1 := Vector2(uv_max.x, uv_max.y)
	var u2 := Vector2(uv_max.x, uv_min.y)
	var u3 := Vector2(uv_min.x, uv_min.y)

	st.set_normal(norm); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(u1); st.add_vertex(v1)
	st.set_normal(norm); st.set_uv(u2); st.add_vertex(v2)

	st.set_normal(norm); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(u2); st.add_vertex(v2)
	st.set_normal(norm); st.set_uv(u3); st.add_vertex(v3)


func _setup_collision(w: float, d: float, h: float, door_w: float, door_h: float, door_t: float) -> void:
	var body_col_body := FurnitureInteractProxy.new()
	body_col_body.name = "CabinetCollision"
	body_col_body.target_callable = Callable(self, "toggle_doors")

	var body_col := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(w, h, d)
	body_col.shape = body_box
	body_col.position = Vector3(0.0, h * 0.5, 0.0)
	body_col_body.add_child(body_col)

	_collision_body = body_col_body
	add_child(_collision_body)

	# Colisión de la puerta izquierda
	if _left_door_pivot:
		var l_col_body := FurnitureInteractProxy.new()
		l_col_body.name = "LeftDoorCollision"
		l_col_body.target_callable = Callable(self, "toggle_left_door")
		var l_col := CollisionShape3D.new()
		var l_box := BoxShape3D.new()
		l_box.size = Vector3(door_w, door_h, door_t)
		l_col.shape = l_box
		l_col.position = Vector3(door_w * 0.5, door_h * 0.5, door_t * 0.5)
		l_col_body.add_child(l_col)
		_left_door_pivot.add_child(l_col_body)

	# Colisión de la puerta derecha
	if _right_door_pivot:
		var r_col_body := FurnitureInteractProxy.new()
		r_col_body.name = "RightDoorCollision"
		r_col_body.target_callable = Callable(self, "toggle_right_door")
		var r_col := CollisionShape3D.new()
		var r_box := BoxShape3D.new()
		r_box.size = Vector3(door_w, door_h, door_t)
		r_col.shape = r_box
		r_col.position = Vector3(-door_w * 0.5, door_h * 0.5, door_t * 0.5)
		r_col_body.add_child(r_col)
		_right_door_pivot.add_child(r_col_body)


static func _get_or_create_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.45
	mat.metallic = 0.05
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	var img := Image.load_from_file(gpath)
	if img and not img.is_empty():
		mat.albedo_texture = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(TEXTURE_PATH):
		mat.albedo_texture = load(TEXTURE_PATH)

	_cached_material = mat
	return mat
