class_name ApplianceToaster
extends Node3D

## Tostadora de Pan Procedural con Palanca Deslizante y Rebanadas de Pan
## - Mapeada a la textura res://assets/textures/furniture/toaster.png
## - Carcasa metálica de acero inoxidable con esquinas redondeadas
## - 2 Ranuras superiores para pan con rebanadas de pan tostado móviles
## - Palanca frontal/lateral que baja y sube con animación ("Pop-up!")
## - Diseñada 100% con cubos UV-mapeados para máxima compatibilidad con GPU Instancing

const TEXTURE_PATH: String = "res://assets/textures/furniture/toaster.png"

@export_group("Dimensiones")
@export var width: float = 0.28          ## Ancho total (28cm)
@export var depth: float = 0.17          ## Profundidad (17cm)
@export var height: float = 0.19         ## Altura (19cm)
@export var foot_height: float = 0.015   ## Altura patas de goma (1.5cm)

@export_group("Mecanismo")
@export_range(0.0, 1.0) var lever_ratio: float = 0.0:
	set(val):
		lever_ratio = clampf(val, 0.0, 1.0)
		_update_lever_and_toasts()

const LEVER_TRAVEL: float = 0.055 ## Recorrido vertical de la palanca (5.5cm)

var _body_mesh_instance: MeshInstance3D = null
var _lever_pivot: Node3D = null
var _lever_mesh: MeshInstance3D = null
var _toast_pivot: Node3D = null
var _toasts_mesh: MeshInstance3D = null
var _collision_body: StaticBody3D = null

static var _cached_material: StandardMaterial3D = null
static var _cached_shared_mesh: ArrayMesh = null


## Retorna la malla compartida de la tostadora completa (1 solo Draw Call)
static func get_shared_mesh(w: float = 0.28, d: float = 0.17, h: float = 0.19, f_h: float = 0.015) -> ArrayMesh:
	if _cached_shared_mesh != null:
		return _cached_shared_mesh

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var uv_steel_min := Vector2(0.005, 0.500)
	var uv_steel_max := Vector2(0.484, 0.984)
	var uv_slots_min := Vector2(0.703, 0.500)
	var uv_slots_max := Vector2(0.969, 0.969)
	var uv_track_min := Vector2(0.281, 0.125)
	var uv_track_max := Vector2(0.688, 0.469)
	var uv_plain_min := Vector2(0.005, 0.005)
	var uv_plain_max := Vector2(0.281, 0.484)

	var body_h := h - f_h

	# 1. Cuerpo principal
	var body_center := Vector3(0.0, f_h + body_h * 0.5, 0.0)
	var body_sz := Vector3(w, body_h, d)
	_add_toaster_box_st(st, body_center, body_sz, uv_steel_min, uv_steel_max, uv_slots_min, uv_slots_max, uv_track_min, uv_track_max, uv_plain_min, uv_plain_max)

	# 2. 4 Patitas de goma
	var foot_sz := Vector3(0.024, f_h, 0.024)
	var foot_dx := w * 0.5 - 0.025
	var foot_dz := d * 0.5 - 0.025
	var foot_y := f_h * 0.5
	var foot_uv_min := Vector2(0.85, 0.85)
	var foot_uv_max := Vector2(0.98, 0.98)
	var f_positions: Array[Vector3] = [
		Vector3(-foot_dx, foot_y, -foot_dz),
		Vector3( foot_dx, foot_y, -foot_dz),
		Vector3(-foot_dx, foot_y,  foot_dz),
		Vector3( foot_dx, foot_y,  foot_dz)
	]
	for fp in f_positions:
		_add_simple_box_st(st, fp, foot_sz, foot_uv_min, foot_uv_max)

	# 3. Palanca en reposo
	var lever_sz := Vector3(0.035, 0.016, 0.026)
	var lever_center := Vector3(w * 0.5 + 0.005 + lever_sz.x * 0.5, f_h + body_h * 0.72, 0.0)
	_add_simple_box_st(st, lever_center, lever_sz, Vector2(0.35, 0.25), Vector2(0.55, 0.45))

	# 4. 2 rebanadas de pan tostado
	var slice_w := w * 0.65
	var slice_d := d * 0.28
	var slice_h := 0.11
	var toast_sz := Vector3(slice_w, slice_h, slice_d * 0.45)
	var sep_z := 0.030
	var toast_uv_min := Vector2(0.08, 0.55)
	var toast_uv_max := Vector2(0.40, 0.85)
	var p1 := Vector3(0.0, h + slice_h * 0.05, -sep_z)
	var p2 := Vector3(0.0, h + slice_h * 0.05,  sep_z)
	_add_simple_box_st(st, p1, toast_sz, toast_uv_min, toast_uv_max)
	_add_simple_box_st(st, p2, toast_sz, toast_uv_min, toast_uv_max)

	st.generate_normals()
	st.generate_tangents()
	_cached_shared_mesh = st.commit()
	return _cached_shared_mesh


## Retorna las cajas de colisión para MultiMesh
static func get_collision_boxes(w: float = 0.28, d: float = 0.17, h: float = 0.19) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w + 0.04, h, d)
		}
	]


func _ready() -> void:
	_build_toaster()


func _build_toaster() -> void:
	for child in get_children():
		child.queue_free()

	var mat := _get_or_create_material()
	var body_h := height - foot_height

	# 1. Cuerpo Principal y Patas
	var body_mesh := _build_toaster_body_mesh(width, depth, body_h, foot_height)
	_body_mesh_instance = MeshInstance3D.new()
	_body_mesh_instance.name = "ToasterBodyMesh"
	_body_mesh_instance.mesh = body_mesh
	_body_mesh_instance.material_override = mat
	add_child(_body_mesh_instance)

	# 2. Palanca Mecánica (en el lateral +X de la tostadora)
	_lever_pivot = Node3D.new()
	_lever_pivot.name = "LeverPivot"
	# Posición de reposo de la palanca: en el extremo derecho (+X), altura alta
	_lever_pivot.position = Vector3(width * 0.5 + 0.005, foot_height + body_h * 0.72, 0.0)
	add_child(_lever_pivot)

	var lever_mesh := _build_lever_handle_mesh()
	_lever_mesh = MeshInstance3D.new()
	_lever_mesh.name = "LeverHandle"
	_lever_mesh.mesh = lever_mesh
	_lever_mesh.material_override = mat
	_lever_pivot.add_child(_lever_mesh)

	# 3. Rebanadas de Pan Tostado (en las 2 ranuras superiores)
	_toast_pivot = Node3D.new()
	_toast_pivot.name = "ToastsPivot"
	_toast_pivot.position = Vector3(0.0, height, 0.0)
	add_child(_toast_pivot)

	var toasts_mesh := _build_toasts_mesh(width * 0.65, depth * 0.28, 0.11)
	_toasts_mesh = MeshInstance3D.new()
	_toasts_mesh.name = "ToastSlices"
	_toasts_mesh.mesh = toasts_mesh
	_toasts_mesh.material_override = mat
	_toast_pivot.add_child(_toasts_mesh)

	# 4. Colisiones Físicas Interactivas con tecla [E]
	_setup_collision(width, depth, height)
	_update_lever_and_toasts()


func _update_lever_and_toasts() -> void:
	if _lever_pivot:
		var initial_y := foot_height + (height - foot_height) * 0.72
		_lever_pivot.position.y = initial_y - lever_ratio * LEVER_TRAVEL
	if _toast_pivot:
		# En reposo (lever 0): sobresalen 4.5cm. Al tostar (lever 1): bajan dentro de la ranura.
		_toast_pivot.position.y = height - lever_ratio * 0.055


## Acciona la palanca de la tostadora bajando o botando el pan
func toggle_lever(animated: bool = true) -> void:
	var target := 1.0 if lever_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_BACK if target == 0.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "lever_ratio", target, 0.30)
	else:
		lever_ratio = target


## Punto de interacción al presionar [E] (ver InteractController)
func interact(_interactor: Node = null) -> void:
	toggle_lever()


# =========================================================================
# GENERACIÓN DE GEOMETRÍA (SurfaceTool con cubos exactos)
# =========================================================================

static func _build_toaster_body_mesh(w: float, d: float, h: float, f_h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas toaster.png (64x64):
	# - Acero inoxidable cepillado (frente y costados): X [0..31]/64 = [0.005, 0.484], Y [32..63]/64 = [0.500, 0.984]
	# - Ranuras superiores para pan: X [45..62]/64 = [0.703, 0.969], Y [32..62]/64 = [0.500, 0.969]
	# - Ranura/pista de la palanca: X [18..44]/64 = [0.281, 0.688], Y [8..30]/64 = [0.125, 0.469]
	# - Acero superior/trasero liso: X [0..18]/64 = [0.005, 0.281], Y [0..31]/64 = [0.005, 0.484]
	var uv_steel_min := Vector2(0.005, 0.500)
	var uv_steel_max := Vector2(0.484, 0.984)

	var uv_slots_min := Vector2(0.703, 0.500)
	var uv_slots_max := Vector2(0.969, 0.969)

	var uv_track_min := Vector2(0.281, 0.125)
	var uv_track_max := Vector2(0.688, 0.469)

	var uv_plain_min := Vector2(0.005, 0.005)
	var uv_plain_max := Vector2(0.281, 0.484)

	# 1. Cuerpo principal metálico (Cubo base)
	var body_center := Vector3(0.0, f_h + h * 0.5, 0.0)
	var body_sz := Vector3(w, h, d)
	_add_toaster_box_st(st, body_center, body_sz, uv_steel_min, uv_steel_max, uv_slots_min, uv_slots_max, uv_track_min, uv_track_max, uv_plain_min, uv_plain_max)

	# 2. 4 Patitas de goma antideslizante en la base
	var foot_sz := Vector3(0.024, f_h, 0.024)
	var foot_dx := w * 0.5 - 0.025
	var foot_dz := d * 0.5 - 0.025
	var foot_y := f_h * 0.5
	var foot_uv_min := Vector2(0.85, 0.85)
	var foot_uv_max := Vector2(0.98, 0.98) # Zona oscura

	var f_positions: Array[Vector3] = [
		Vector3(-foot_dx, foot_y, -foot_dz),
		Vector3( foot_dx, foot_y, -foot_dz),
		Vector3(-foot_dx, foot_y,  foot_dz),
		Vector3( foot_dx, foot_y,  foot_dz)
	]
	for fp in f_positions:
		_add_simple_box_st(st, fp, foot_sz, foot_uv_min, foot_uv_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _build_lever_handle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Pequeña palanca que sobresale hacia afuera (+X)
	var lever_sz := Vector3(0.035, 0.016, 0.026)
	var center := Vector3(lever_sz.x * 0.5, 0.0, 0.0)
	var uv_knob_min := Vector2(0.35, 0.25)
	var uv_knob_max := Vector2(0.55, 0.45)
	_add_simple_box_st(st, center, lever_sz, uv_knob_min, uv_knob_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _build_toasts_mesh(slice_w: float, slice_d: float, slice_h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 2 rebanadas de pan tostado dorado en Z = -0.028 y Z = +0.028
	var toast_sz := Vector3(slice_w, slice_h, slice_d * 0.45)
	var sep_z := 0.030
	var uv_toast_min := Vector2(0.08, 0.55)
	var uv_toast_max := Vector2(0.40, 0.85)

	var p1 := Vector3(0.0, -slice_h * 0.45, -sep_z)
	var p2 := Vector3(0.0, -slice_h * 0.45,  sep_z)
	_add_simple_box_st(st, p1, toast_sz, uv_toast_min, uv_toast_max)
	_add_simple_box_st(st, p2, toast_sz, uv_toast_min, uv_toast_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _add_toaster_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_steel_min: Vector2, uv_steel_max: Vector2, uv_top_min: Vector2, uv_top_max: Vector2, uv_right_min: Vector2, uv_right_max: Vector2, uv_plain_min: Vector2, uv_plain_max: Vector2) -> void:
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

	# +Y Cubierta con ranuras para pan
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_top_min, uv_top_max)
	# +X Lado derecho con ranura para la palanca
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_right_min, uv_right_max)
	# +Z Frente con acero cepillado
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_steel_min, uv_steel_max)
	# -Z Parte trasera con acero cepillado
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_steel_min, uv_steel_max)
	# -X Lado izquierdo
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_plain_min, uv_plain_max)
	# -Y Base inferior
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_plain_min, uv_plain_max)


static func _add_simple_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
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


func _setup_collision(w: float, d: float, h: float) -> void:
	var col_body := FurnitureInteractProxy.new()
	col_body.name = "ToasterCollision"
	col_body.target_callable = Callable(self, "toggle_lever")

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w + 0.04, h, d)
	col.shape = box
	col.position = Vector3(0.0, h * 0.5, 0.0)
	col_body.add_child(col)

	_collision_body = col_body
	add_child(_collision_body)


static func _get_or_create_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.28
	mat.metallic = 0.55
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	var img := Image.load_from_file(gpath)
	if img and not img.is_empty():
		mat.albedo_texture = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(TEXTURE_PATH):
		mat.albedo_texture = load(TEXTURE_PATH)

	_cached_material = mat
	return mat
