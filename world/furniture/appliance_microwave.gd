class_name ApplianceMicrowave
extends Node3D

## Horno de Microondas Procedural con Puerta Abatible y Cavidad Interior
## - Mapeado a la textura res://assets/textures/furniture/microondas.png
## - Puerta con ventana ahumada abatible (bisagra izquierda)
## - Panel de control frontal fijo a la derecha (pantalla digital y teclado táctil)
## - Cavidad interior hueca con paredes oscuras y plato giratorio
## - Rejilla de ventilación en lateral izquierdo y carcasa metálica
## - Diseñado 100% con cubos UV-mapeados para compatibilidad total con GPU Instancing

const TEXTURE_PATH: String = "res://assets/textures/furniture/microondas.png"

@export_group("Dimensiones")
@export var width: float = 0.42         ## Ancho total (42cm - la mitad del mueble bajo de 85cm)
@export var depth: float = 0.30         ## Profundidad total (30cm)
@export var height: float = 0.24        ## Altura total (24cm)
@export var wall_thickness: float = 0.022 ## Grosor de paredes de la carcasa (2.2cm)
@export var door_thickness: float = 0.022 ## Grosor de la puerta (2.2cm)

@export_group("Apertura")
@export_range(0.0, 1.0) var door_open_ratio: float = 0.0:
	set(val):
		door_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angle()

const MAX_DOOR_ANGLE: float = deg_to_rad(95.0)

# Proporción de la ventana vs panel de control según la textura microondas.png:
# Ventana: X [51..108] = 57 px
# Panel control: X [108..127] = 19 px
# Total frente: 76 px
const DOOR_WIDTH_RATIO: float = 57.0 / 76.0 # ~0.75

var _body_mesh_instance: MeshInstance3D = null
var _door_pivot: Node3D = null
var _door_mesh_instance: MeshInstance3D = null
var _body_collision: StaticBody3D = null

static var _cached_material: StandardMaterial3D = null
static var _cached_body_mesh: ArrayMesh = null
static var _cached_door_mesh: ArrayMesh = null
static var _cached_complete_mesh: ArrayMesh = null


## Retorna la malla compartida del cuerpo para GPU Instancing
static func get_shared_body_mesh() -> ArrayMesh:
	if _cached_body_mesh == null:
		var w := 0.42
		var d := 0.35
		var h := 0.28
		var dt := 0.025
		var wt := 0.022
		var bd := d - dt
		var dw := w * 0.70
		var pw := w - dw
		_cached_body_mesh = _build_microwave_body_mesh(w, bd, h, wt, dw, pw, dt)
	return _cached_body_mesh


## Retorna la malla compartida de la puerta para GPU Instancing
static func get_shared_door_mesh() -> ArrayMesh:
	if _cached_door_mesh == null:
		var w := 0.42
		var h := 0.28
		var dt := 0.025
		var dw := w * 0.70
		_cached_door_mesh = _build_microwave_door_mesh(dw, h, dt)
	return _cached_door_mesh


## Retorna la malla compartida completa (cuerpo + puerta cerrada) para GPU Instancing en 1 Draw Call
static func get_shared_mesh() -> ArrayMesh:
	if _cached_complete_mesh != null:
		return _cached_complete_mesh

	var body := get_shared_body_mesh()
	var door := get_shared_door_mesh()

	var w := 0.42
	var d := 0.35
	var dt := 0.025
	var bd := d - dt
	var hinge_x := -w * 0.5
	var hinge_z := bd * 0.5
	var door_xform := Transform3D(Basis.IDENTITY, Vector3(hinge_x, 0.0, hinge_z))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(body, 0, Transform3D.IDENTITY)
	st.append_from(door, 0, door_xform)
	st.generate_normals()
	st.generate_tangents()
	_cached_complete_mesh = st.commit()
	return _cached_complete_mesh


## Retorna las cajas de colisión para el sistema MultiMesh
static func get_collision_boxes(w: float = 0.42, d: float = 0.35, h: float = 0.28) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w, h, d)
		}
	]


func _ready() -> void:
	_build_microwave()


func _build_microwave() -> void:
	for child in get_children():
		child.queue_free()

	var mat := _get_or_create_material()
	var body_d := depth - door_thickness
	var door_w := width * DOOR_WIDTH_RATIO
	var panel_w := width - door_w

	var is_default_dim := (
		is_equal_approx(width, 0.42)
		and is_equal_approx(depth, 0.35)
		and is_equal_approx(height, 0.28)
		and is_equal_approx(door_thickness, 0.025)
	)

	# 1. Carcasa / Cuerpo Principal
	var body_mesh: ArrayMesh
	if is_default_dim:
		body_mesh = get_shared_body_mesh()
	else:
		body_mesh = _build_microwave_body_mesh(width, body_d, height, wall_thickness, door_w, panel_w, door_thickness)

	_body_mesh_instance = MeshInstance3D.new()
	_body_mesh_instance.name = "MicrowaveBodyMesh"
	_body_mesh_instance.mesh = body_mesh
	_body_mesh_instance.material_override = mat
	add_child(_body_mesh_instance)

	# 2. Puerta Abatible (Bisagra en el extremo izquierdo de la ventana, X = -half_w)
	var hinge_x := -width * 0.5
	var hinge_z := body_d * 0.5

	_door_pivot = Node3D.new()
	_door_pivot.name = "MicrowaveDoorPivot"
	_door_pivot.position = Vector3(hinge_x, 0.0, hinge_z)
	add_child(_door_pivot)

	var door_mesh := _build_microwave_door_mesh(door_w, height, door_thickness)
	_door_mesh_instance = MeshInstance3D.new()
	_door_mesh_instance.name = "MicrowaveDoorMesh"
	_door_mesh_instance.mesh = door_mesh
	_door_mesh_instance.material_override = mat
	_door_mesh_instance.position = Vector3(0.0, 0.0, 0.0) # Se extiende hacia +X
	_door_pivot.add_child(_door_mesh_instance)

	# 3. Colisiones físicas
	_setup_collision(width, body_d, height, door_w, door_thickness)
	_update_door_angle()


func _update_door_angle() -> void:
	if _door_pivot:
		# Bisagra a la izquierda rota hacia afuera en sentido horario negativo (-Y)
		_door_pivot.rotation.y = -door_open_ratio * MAX_DOOR_ANGLE


## Abre o cierra la puerta del microondas
func toggle_door(animated: bool = true) -> void:
	var target := 1.0 if door_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "door_open_ratio", target, 0.35)
	else:
		door_open_ratio = target


## Punto de interacción al presionar [E] (ver InteractController)
func interact(_interactor: Node = null) -> void:
	toggle_door()


# =========================================================================
# GENERACIÓN DE GEOMETRÍA (SurfaceTool con cubos exactos)
# =========================================================================

static func _build_microwave_body_mesh(w: float, d: float, h: float, wall_t: float, door_w: float, panel_w: float, door_t: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas microondas.png (128x128):
	# - Metal superior liso: X [0..50]/128 = [0.005, 0.390], Y [0..42]/128 = [0.005, 0.328]
	# - Rejilla ventilación (-X): X [0..50]/128 = [0.005, 0.390], Y [43..88]/128 = [0.336, 0.688]
	# - Panel frontal de control / teclado (+X frontal): X [108..127]/128 = [0.844, 0.992], Y [43..88]/128 = [0.336, 0.688]
	# - Cavidad interior / caja oscura: X [60..123]/128 = [0.469, 0.961], Y [93..124]/128 = [0.726, 0.968]
	var uv_metal_min := Vector2(0.005, 0.005)
	var uv_metal_max := Vector2(0.390, 0.328)

	var uv_vent_min := Vector2(0.005, 0.336)
	var uv_vent_max := Vector2(0.390, 0.688)

	var uv_panel_min := Vector2(0.844, 0.336)
	var uv_panel_max := Vector2(0.992, 0.688)

	var uv_cavity_min := Vector2(0.469, 0.726)
	var uv_cavity_max := Vector2(0.961, 0.968)

	var hw := w * 0.5
	var hd := d * 0.5

	# 1. Pared Posterior (Back)
	_add_box_st(st, Vector3(0.0, h * 0.5, -hd + wall_t * 0.5), Vector3(w, h, wall_t), uv_metal_min, uv_metal_max)

	# 2. Pared Izquierda con Ventilación (-X)
	var side_d := d - wall_t
	var side_z := wall_t * 0.5
	_add_box_st(st, Vector3(-hw + wall_t * 0.5, h * 0.5, side_z), Vector3(wall_t, h, side_d), uv_vent_min, uv_vent_max)

	# 3. Pared Derecha Metálica (+X)
	_add_box_st(st, Vector3(hw - wall_t * 0.5, h * 0.5, side_z), Vector3(wall_t, h, side_d), uv_metal_min, uv_metal_max)

	# 4. Techo Superior Metálico (+Y)
	_add_box_st(st, Vector3(0.0, h - wall_t * 0.5, side_z), Vector3(w - wall_t * 2.0, wall_t, side_d), uv_metal_min, uv_metal_max)

	# 5. Base Inferior (-Y)
	_add_box_st(st, Vector3(0.0, wall_t * 0.5, side_z), Vector3(w - wall_t * 2.0, wall_t, side_d), uv_metal_min, uv_metal_max)

	# 6. Panel Frontal Fijo de Control a la derecha (+X)
	# Ocupa el frente desde el borde derecho de la puerta hasta el extremo derecho del mueble
	var panel_center_x := hw - panel_w * 0.5
	var panel_center_z := hd + door_t * 0.5
	_add_control_panel_box_st(st, Vector3(panel_center_x, h * 0.5, panel_center_z), Vector3(panel_w, h, door_t), uv_panel_min, uv_panel_max, uv_metal_min, uv_metal_max)

	# 7. Pared interior divisoria entre la cavidad de cocción y la electrónica del panel
	var cavity_right_x := hw - panel_w
	_add_box_st(st, Vector3(cavity_right_x - wall_t * 0.5, h * 0.5, side_z), Vector3(wall_t, h - wall_t * 2.0, side_d), uv_cavity_min, uv_cavity_max)

	# 8. Fondo de la cavidad interior oscura
	var cavity_w := door_w - wall_t
	var cavity_center_x := -hw + wall_t + cavity_w * 0.5
	_add_box_st(st, Vector3(cavity_center_x, h * 0.5, -hd + wall_t + 0.005), Vector3(cavity_w, h - wall_t * 2.0, 0.01), uv_cavity_min, uv_cavity_max)

	# 9. Plato giratorio interior en el fondo de la cavidad
	var plate_size := Vector3(cavity_w * 0.85, 0.010, side_d * 0.80)
	_add_box_st(st, Vector3(cavity_center_x, wall_t + 0.006, side_z), plate_size, uv_cavity_min, uv_cavity_max)

	# 10. Cuatro patitas de goma en las esquinas inferiores
	var leg_size := Vector3(0.025, 0.012, 0.025)
	var lx := hw - 0.04
	var lz := hd - 0.04
	for px in [-lx, lx]:
		for pz in [-lz, lz]:
			_add_box_st(st, Vector3(px, 0.006, pz), leg_size, uv_cavity_min, uv_cavity_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _build_microwave_door_mesh(w: float, h: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Ventana de la puerta: X [51..108]/128 = [0.398, 0.844], Y [43..88]/128 = [0.336, 0.688]
	var uv_front_min := Vector2(0.398, 0.336)
	var uv_front_max := Vector2(0.844, 0.688)

	var uv_metal_min := Vector2(0.005, 0.005)
	var uv_metal_max := Vector2(0.390, 0.328)

	# Pivote en X = 0 (borde izquierdo de la puerta), Z = 0
	var center := Vector3(w * 0.5, h * 0.5, thick * 0.5)
	var size := Vector3(w, h, thick)

	_add_door_box_st(st, center, size, uv_front_min, uv_front_max, uv_metal_min, uv_metal_max)

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


static func _add_door_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_front_min: Vector2, uv_front_max: Vector2, uv_metal_min: Vector2, uv_metal_max: Vector2) -> void:
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

	# +Z Frente de la puerta (Ventana con marco)
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_front_min, uv_front_max)
	# Cantos y dorso en gris metálico
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_metal_min, uv_metal_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_metal_min, uv_metal_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_metal_min, uv_metal_max)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_metal_min, uv_metal_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_metal_min, uv_metal_max)


static func _add_control_panel_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_panel_min: Vector2, uv_panel_max: Vector2, uv_metal_min: Vector2, uv_metal_max: Vector2) -> void:
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

	# +Z Frente con display digital y botones
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_panel_min, uv_panel_max)
	# Cantos y lados en metal gris
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_metal_min, uv_metal_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_metal_min, uv_metal_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_metal_min, uv_metal_max)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_metal_min, uv_metal_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_metal_min, uv_metal_max)


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


func _setup_collision(w: float, d: float, h: float, door_w: float, door_t: float) -> void:
	var body_col_body := FurnitureInteractProxy.new()
	body_col_body.name = "MicrowaveCollision"
	body_col_body.target_callable = Callable(self, "toggle_door")

	var body_col := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(w, h, d)
	body_col.shape = body_box
	body_col.position = Vector3(0.0, h * 0.5, 0.0)
	body_col_body.add_child(body_col)

	_body_collision = body_col_body
	add_child(_body_collision)

	if _door_pivot:
		var door_body := FurnitureInteractProxy.new()
		door_body.name = "DoorCollision"
		door_body.target_callable = Callable(self, "toggle_door")
		var door_col := CollisionShape3D.new()
		var door_box := BoxShape3D.new()
		door_box.size = Vector3(door_w, h, door_t)
		door_col.shape = door_box
		door_col.position = Vector3(door_w * 0.5, h * 0.5, door_t * 0.5)
		door_body.add_child(door_col)
		_door_pivot.add_child(door_body)


static func _get_or_create_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.35
	mat.metallic = 0.25
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	var img := Image.load_from_file(gpath)
	if img and not img.is_empty():
		mat.albedo_texture = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(TEXTURE_PATH):
		mat.albedo_texture = load(TEXTURE_PATH)

	_cached_material = mat
	return mat
