class_name ApplianceStove
extends Node3D

## Estufa Doméstica Procedural con Quemadores y Puerta de Horno Abatible
## - Mapeado a la textura res://assets/textures/furniture/estufa.png
## - Quemadores eléctricos/gas superiores en la cubierta
## - Copete trasero con perillas y display digital
## - Puerta del horno abatible hacia abajo (bisagra inferior con manija y cristal)
## - Cavidad interna del horno con rejilla metálica interior
## - Cajón inferior y laterales metálicos con desgaste

const TEXTURE_PATH: String = "res://assets/textures/furniture/estufa.png"

@export_group("Dimensiones")
@export var width: float = 0.75             ## Ancho de la estufa (75cm estándar)
@export var depth: float = 0.65             ## Profundidad de la estufa (65cm)
@export var height_cooktop: float = 0.86    ## Altura hasta la meseta/quemadores (86cm)
@export var backguard_height: float = 0.16  ## Altura del copete posterior con perillas (16cm)
@export var door_thickness: float = 0.05    ## Grosor de la puerta del horno (5cm)

@export_group("Apertura de Horno")
@export_range(0.0, 1.0) var oven_open_ratio: float = 0.0:
	set(val):
		oven_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angle()

const MAX_OVEN_ANGLE: float = deg_to_rad(88.0) # Abre hacia abajo ~88 grados

# Nodos internos
var _body_mesh_instance: MeshInstance3D = null
var _oven_pivot: Node3D = null
var _oven_door_mesh_instance: MeshInstance3D = null
var _body_collision: StaticBody3D = null
var _oven_collision: CollisionShape3D = null

static var _cached_material: StandardMaterial3D = null
static var _cached_body_mesh: ArrayMesh = null
static var _cached_door_mesh: ArrayMesh = null
static var _cached_complete_mesh: ArrayMesh = null


## Retorna la malla compartida del cuerpo para GPU Instancing
static func get_shared_body_mesh() -> ArrayMesh:
	if _cached_body_mesh == null:
		var drawer_h := 0.20
		var oven_h := 0.90 - drawer_h - 0.04
		var body_d := 0.68 - 0.05
		_cached_body_mesh = _build_stove_body_mesh(0.76, body_d, 0.90, 0.24, drawer_h, oven_h)
	return _cached_body_mesh


## Retorna la malla compartida de la puerta del horno
static func get_shared_door_mesh() -> ArrayMesh:
	if _cached_door_mesh == null:
		var drawer_h := 0.20
		var oven_h := 0.90 - drawer_h - 0.04
		_cached_door_mesh = _build_oven_door_mesh(0.76, oven_h, 0.05)
	return _cached_door_mesh


## Retorna la malla compartida completa (cuerpo + puerta cerrada) para GPU Instancing en 1 Draw Call
static func get_shared_mesh() -> ArrayMesh:
	if _cached_complete_mesh != null:
		return _cached_complete_mesh

	var body := get_shared_body_mesh()
	var door := get_shared_door_mesh()

	var drawer_h := 0.20
	var body_d := 0.68 - 0.05
	var door_xform := Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_h, body_d * 0.5))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(body, 0, Transform3D.IDENTITY)
	st.append_from(door, 0, door_xform)
	st.generate_normals()
	st.generate_tangents()
	_cached_complete_mesh = st.commit()
	return _cached_complete_mesh


## Retorna las cajas de colisión para el sistema MultiMesh
static func get_collision_boxes(w: float = 0.76, d: float = 0.68, h: float = 0.90, bg_h: float = 0.24) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w, h, d)
		},
		{
			"position": Vector3(0.0, h + bg_h * 0.5, -d * 0.5 + 0.04),
			"size": Vector3(w, bg_h, 0.08)
		}
	]


func _ready() -> void:
	_build_stove()


func _build_stove() -> void:
	for child in get_children():
		child.queue_free()

	var mat := _get_or_create_material()

	var drawer_h := 0.20
	var oven_h := height_cooktop - drawer_h - 0.04
	var body_d := depth - door_thickness

	var is_default_dim := (
		is_equal_approx(width, 0.76)
		and is_equal_approx(depth, 0.68)
		and is_equal_approx(height_cooktop, 0.90)
		and is_equal_approx(backguard_height, 0.24)
		and is_equal_approx(door_thickness, 0.05)
	)

	# 1. Cuerpo principal (Cubierta con quemadores, copete con perillas, cavidad del horno y cajón)
	var body_mesh: ArrayMesh
	if is_default_dim:
		body_mesh = get_shared_body_mesh()
	else:
		body_mesh = _build_stove_body_mesh(width, body_d, height_cooktop, backguard_height, drawer_h, oven_h)

	_body_mesh_instance = MeshInstance3D.new()
	_body_mesh_instance.name = "StoveBodyMesh"
	_body_mesh_instance.mesh = body_mesh
	_body_mesh_instance.material_override = mat
	add_child(_body_mesh_instance)

	# 2. Puerta del Horno (Pivote inferior en Y = drawer_h, Z frontal)
	var hinge_z := body_d * 0.5
	_oven_pivot = Node3D.new()
	_oven_pivot.name = "OvenDoorPivot"
	_oven_pivot.position = Vector3(0.0, drawer_h, hinge_z)
	add_child(_oven_pivot)

	var door_mesh := _build_oven_door_mesh(width, oven_h, door_thickness)
	_oven_door_mesh_instance = MeshInstance3D.new()
	_oven_door_mesh_instance.name = "OvenDoorMesh"
	_oven_door_mesh_instance.mesh = door_mesh
	_oven_door_mesh_instance.material_override = mat
	_oven_door_mesh_instance.position = Vector3(0.0, 0.0, 0.0)
	_oven_pivot.add_child(_oven_door_mesh_instance)

	_setup_collision(width, body_d, height_cooktop, backguard_height, drawer_h, oven_h, door_thickness)
	_update_door_angle()


func _update_door_angle() -> void:
	if _oven_pivot:
		# La bisagra inferior rota hacia el frente en el eje X (+X para abatir hacia adelante)
		_oven_pivot.rotation.x = oven_open_ratio * MAX_OVEN_ANGLE


## Abre o cierra la puerta del horno
func toggle_oven(animated: bool = true) -> void:
	var target := 1.0 if oven_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "oven_open_ratio", target, 0.40)
	else:
		oven_open_ratio = target


## Punto de interacción al presionar [E] (ver InteractController)
func interact(_interactor: Node = null) -> void:
	toggle_oven()


# =========================================================================
# GENERACIÓN DE GEOMETRÍA (SurfaceTool)
# =========================================================================

## Construye el cuerpo de la estufa
static func _build_stove_body_mesh(w: float, d: float, h: float, bg_h: float, drawer_h: float, oven_h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas estufa.png (256x256):
	# - Quemadores (+Y cubierta): X [126..255] / 256 = [0.492, 0.996], Y [0..98] / 256 = [0.004, 0.380]
	# - Copete (+Z perillas/reloj): X [0..125] / 256 = [0.004, 0.488], Y [0..98] / 256 = [0.004, 0.380]
	# - Cajón inferior (+Z): X [119..255] / 256 = [0.468, 0.996], Y [200..255] / 256 = [0.781, 0.996]
	# - Laterales (-X y +X): X [0..118] / 256 = [0.004, 0.460], Y [99..255] / 256 = [0.388, 0.996]
	var uv_burners_min := Vector2(0.495, 0.005)
	var uv_burners_max := Vector2(0.995, 0.380)

	var uv_backguard_min := Vector2(0.005, 0.005)
	var uv_backguard_max := Vector2(0.485, 0.380)

	var uv_drawer_min := Vector2(0.468, 0.781)
	var uv_drawer_max := Vector2(0.995, 0.996)

	var uv_side_min := Vector2(0.005, 0.390)
	var uv_side_max := Vector2(0.460, 0.995)

	var hw := w * 0.5
	var hd := d * 0.5
	var wall_t := 0.040

	# 1. Base / Cajón inferior frontal (hasta Y = drawer_h)
	_add_box_with_uvs(st, Vector3(0.0, drawer_h * 0.5, 0.0), Vector3(w, drawer_h, d),
		uv_side_min, uv_side_max, uv_drawer_min, uv_drawer_max)

	# 2. Pared Posterior del Horno
	var oven_bottom := drawer_h
	var oven_top := drawer_h + oven_h
	var back_z := -hd + wall_t * 0.5
	_add_box_st(st, Vector3(0.0, (oven_bottom + h) * 0.5, back_z), Vector3(w, h - oven_bottom, wall_t), uv_side_min, uv_side_max)

	# 3. Paredes Laterales de la Estufa (desde drawer_h hasta la cubierta)
	var side_d := d - wall_t
	var side_z := wall_t * 0.5
	var side_h := h - oven_bottom
	var side_y := oven_bottom + side_h * 0.5
	_add_box_st(st, Vector3(-hw + wall_t * 0.5, side_y, side_z), Vector3(wall_t, side_h, side_d), uv_side_min, uv_side_max)
	_add_box_st(st, Vector3(hw - wall_t * 0.5, side_y, side_z), Vector3(wall_t, side_h, side_d), uv_side_min, uv_side_max)

	# 4. Marco superior frontal sobre la puerta del horno
	var top_lip_h := h - oven_top
	var top_lip_y := oven_top + top_lip_h * 0.5
	_add_box_st(st, Vector3(0.0, top_lip_y, hd - wall_t * 0.5), Vector3(w, top_lip_h, wall_t), uv_side_min, uv_side_max)

	# 5. Cubierta Superior con los 4 Quemadores (Cooktop en +Y)
	var cooktop_y := h - 0.015
	_add_cooktop_st(st, Vector3(0.0, cooktop_y, side_z), Vector3(w, 0.03, side_d), uv_burners_min, uv_burners_max, uv_side_min, uv_side_max)

	# 6. Copete Posterior con Panel de Control (Perillas y Reloj digital)
	var bg_t := 0.06
	var bg_y := h + bg_h * 0.5
	var bg_z := -hd + bg_t * 0.5
	_add_backguard_st(st, Vector3(0.0, bg_y, bg_z), Vector3(w, bg_h, bg_t), uv_backguard_min, uv_backguard_max, uv_side_min, uv_side_max)

	# 7. Rejilla metálica interior del horno
	var rack_w := w - wall_t * 2.0 - 0.02
	var rack_d := side_d - 0.05
	var rack_y := oven_bottom + oven_h * 0.45
	_add_box_st(st, Vector3(0.0, rack_y, side_z), Vector3(rack_w, 0.012, rack_d), uv_side_min, uv_side_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Construye la puerta abatible del horno
static func _build_oven_door_mesh(w: float, h: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas estufa.png:
	# Puerta del horno frontal con manija y cristal:
	# X [119..255] / 256 = [0.468, 0.996], Y [99..199] / 256 = [0.388, 0.778]
	var uv_door_front_min := Vector2(0.468, 0.388)
	var uv_door_front_max := Vector2(0.995, 0.778)
	var uv_metal_min := Vector2(0.005, 0.390)
	var uv_metal_max := Vector2(0.460, 0.995)

	# El pivote está en la base inferior (y=0, z=0 del nodo de la puerta)
	# La puerta se extiende hacia arriba en +Y y hacia adelante en +Z
	var center := Vector3(0.0, h * 0.5, thick * 0.5)
	var size := Vector3(w, h, thick)

	_add_door_box_st(st, center, size, uv_door_front_min, uv_door_front_max, uv_metal_min, uv_metal_max)

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


static func _add_box_with_uvs(st: SurfaceTool, center: Vector3, size: Vector3, uv_side_min: Vector2, uv_side_max: Vector2, uv_front_min: Vector2, uv_front_max: Vector2) -> void:
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

	# +Z Cara frontal (Cajón inferior)
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_front_min, uv_front_max)
	# Resto de caras con textura lateral
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_side_min, uv_side_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_side_min, uv_side_max)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_side_min, uv_side_max)


static func _add_cooktop_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_top_min: Vector2, uv_top_max: Vector2, uv_side_min: Vector2, uv_side_max: Vector2) -> void:
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

	# Cara +Y (Quemadores en la cubierta)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_top_min, uv_top_max)
	# Cantos
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_side_min, uv_side_max)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_side_min, uv_side_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_side_min, uv_side_max)


static func _add_backguard_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_panel_min: Vector2, uv_panel_max: Vector2, uv_side_min: Vector2, uv_side_max: Vector2) -> void:
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

	# Cara +Z (Panel de control con perillas y display)
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_panel_min, uv_panel_max)
	# Cantos
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_side_min, uv_side_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_side_min, uv_side_max)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_side_min, uv_side_max)


static func _add_door_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_front_min: Vector2, uv_front_max: Vector2, uv_side_min: Vector2, uv_side_max: Vector2) -> void:
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

	# +Z Frente exterior de la puerta del horno (Manija y ventana)
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_front_min, uv_front_max)
	# -Z Interior hacia el horno
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_side_min, uv_side_max)
	# Cantos
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_side_min, uv_side_max)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_side_min, uv_side_max)


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


func _setup_collision(w: float, d: float, h: float, bg_h: float, drawer_h: float, oven_h: float, door_t: float) -> void:
	var body_col_body := FurnitureInteractProxy.new()
	body_col_body.name = "StoveCollision"
	body_col_body.target_callable = Callable(self, "toggle_oven")

	# 1. Cuerpo principal
	var body_shape := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(w, h, d)
	body_shape.shape = body_box
	body_shape.position = Vector3(0.0, h * 0.5, 0.0)
	body_col_body.add_child(body_shape)

	# 2. Copete posterior
	var bg_shape := CollisionShape3D.new()
	var bg_box := BoxShape3D.new()
	bg_box.size = Vector3(w, bg_h, 0.08)
	bg_shape.shape = bg_box
	bg_shape.position = Vector3(0.0, h + bg_h * 0.5, -d * 0.5 + 0.04)
	body_col_body.add_child(bg_shape)

	_body_collision = body_col_body
	add_child(_body_collision)

	# 3. Puerta del horno (hijo del pivote para rotar)
	if _oven_pivot:
		var door_body := FurnitureInteractProxy.new()
		door_body.name = "OvenDoorCollision"
		door_body.target_callable = Callable(self, "toggle_oven")
		var door_shape := CollisionShape3D.new()
		var door_box := BoxShape3D.new()
		door_box.size = Vector3(w, oven_h, door_t)
		door_shape.shape = door_box
		door_shape.position = Vector3(0.0, oven_h * 0.5, door_t * 0.5)
		door_body.add_child(door_shape)
		_oven_pivot.add_child(door_body)


static func _get_or_create_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.40 # Esmaltado semibrillante de estufa
	mat.metallic = 0.20  # Superficie metálica
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	var img := Image.load_from_file(gpath)
	if img and not img.is_empty():
		mat.albedo_texture = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(TEXTURE_PATH):
		mat.albedo_texture = load(TEXTURE_PATH)

	_cached_material = mat
	return mat
