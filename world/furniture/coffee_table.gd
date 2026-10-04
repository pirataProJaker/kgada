class_name CoffeeTable
extends Node3D

## Mesa de Centro (Coffee Table) Procedural con Cajón Deslizante
## - Mapeada a la textura res://assets/textures/furniture/coffee_table.png
## - Tablero superior de madera cálida con textura de duelas
## - 4 Patas sólidas de madera y bastidor perimetral
## - Cajón central deslizable con frontal enmarcado y cavidad interior de almacenamiento
## - Diseñada 100% con cubos UV-mapeados para máxima compatibilidad con GPU Instancing

const TEXTURE_PATH: String = "res://assets/textures/furniture/coffee_table.png"

@export_group("Dimensiones")
@export var width: float = 0.95           ## Ancho/Largo total (95cm)
@export var depth: float = 0.55           ## Fondo total (55cm)
@export var height: float = 0.44          ## Altura total (44cm)
@export var top_thickness: float = 0.038  ## Grosor del tablero superior (3.8cm)
@export var leg_size: float = 0.055       ## Grosor cuadrado de patas (5.5cm)
@export var apron_height: float = 0.12    ## Altura del bastidor/faldón (12cm)

@export_group("Cajón")
@export_range(0.0, 1.0) var drawer_open_ratio: float = 0.0:
	set(val):
		drawer_open_ratio = clampf(val, 0.0, 1.0)
		_update_drawer_position()

const DRAWER_TRAVEL: float = 0.26 ## Recorrido deslizante hacia adelante (26cm)

var _frame_mesh_instance: MeshInstance3D = null
var _drawer_pivot: Node3D = null
var _drawer_mesh_instance: MeshInstance3D = null
var _table_collision: StaticBody3D = null

static var _cached_material: StandardMaterial3D = null
static var _cached_shared_mesh: ArrayMesh = null


## Retorna la malla compartida de la mesa de centro para GPU Instancing
static func get_shared_mesh() -> ArrayMesh:
	if _cached_shared_mesh == null:
		var leg_h := 0.45 - 0.035
		var drawer_w := 0.95 * 0.52
		var drawer_d := 0.55 * 0.75
		var drawer_h := 0.12 * 0.88
		var drawer_y := leg_h - 0.12 + (0.12 - drawer_h) * 0.5
		var frame := _build_frame_mesh(0.95, 0.55, 0.45, 0.035, 0.055, leg_h, 0.12, drawer_w)
		var drawer := _build_drawer_mesh(drawer_w, drawer_d, drawer_h)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(frame, 0, Transform3D.IDENTITY)
		st.append_from(drawer, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, drawer_y, 0.55 * 0.5 - 0.015)))
		st.generate_normals()
		st.generate_tangents()
		_cached_shared_mesh = st.commit()
	return _cached_shared_mesh


## Retorna las cajas de colisión para el sistema MultiMesh
static func get_collision_boxes(w: float = 0.95, d: float = 0.55, h: float = 0.45) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w, h, d)
		}
	]


func _ready() -> void:
	_build_coffee_table()


func _build_coffee_table() -> void:
	for child in get_children():
		child.queue_free()

	var mat := _get_or_create_material()
	var leg_h := height - top_thickness
	var drawer_w := width * 0.52
	var drawer_d := depth * 0.75
	var drawer_h := apron_height * 0.88
	var drawer_y := leg_h - apron_height + (apron_height - drawer_h) * 0.5

	# 1. Armazón / Bastidor (Tablero, 4 patas y faldones con hueco frontal para cajón)
	var frame_mesh := _build_frame_mesh(width, depth, height, top_thickness, leg_size, leg_h, apron_height, drawer_w)
	_frame_mesh_instance = MeshInstance3D.new()
	_frame_mesh_instance.name = "TableFrameMesh"
	_frame_mesh_instance.mesh = frame_mesh
	_frame_mesh_instance.material_override = mat
	add_child(_frame_mesh_instance)

	# 2. Cajón Deslizante (Pivote en la posición inicial cerrada)
	_drawer_pivot = Node3D.new()
	_drawer_pivot.name = "DrawerPivot"
	_drawer_pivot.position = Vector3(0.0, drawer_y, depth * 0.5 - 0.015)
	add_child(_drawer_pivot)

	var drawer_mesh := _build_drawer_mesh(drawer_w, drawer_d, drawer_h)
	_drawer_mesh_instance = MeshInstance3D.new()
	_drawer_mesh_instance.name = "DrawerMesh"
	_drawer_mesh_instance.mesh = drawer_mesh
	_drawer_mesh_instance.material_override = mat
	_drawer_pivot.add_child(_drawer_mesh_instance)

	# 3. Colisiones Físicas Interactivas con tecla [E]
	_setup_collision(width, depth, height, drawer_w, drawer_d, drawer_h, drawer_y)
	_update_drawer_position()


func _update_drawer_position() -> void:
	if _drawer_pivot:
		# Se desliza en +Z (hacia el frente de la mesa)
		_drawer_pivot.position.z = (depth * 0.5 - 0.015) + drawer_open_ratio * DRAWER_TRAVEL


## Abre o cierra el cajón de la mesita
func toggle_drawer(animated: bool = true) -> void:
	var target := 1.0 if drawer_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "drawer_open_ratio", target, 0.38)
	else:
		drawer_open_ratio = target


## Punto de interacción al presionar [E] (ver InteractController)
func interact(_interactor: Node = null) -> void:
	toggle_drawer()


# =========================================================================
# GENERACIÓN DE GEOMETRÍA (SurfaceTool)
# =========================================================================

static func _build_frame_mesh(w: float, d: float, h: float, t_t: float, l_sz: float, l_h: float, ap_h: float, dr_w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas coffee_table.png (128x128):
	# - Tablero de duelas de madera: X [1..93]/128, Y [25..84]/128
	# - Frente de cajón enmarcado: X [1..92]/128 = [0.008, 0.719], Y [80..126]/128 = [0.625, 0.984]
	# - Patas y listones de bastidor: X [94..127]/128 = [0.734, 0.992], Y [10..60]/128 = [0.078, 0.469]
	var uv_top_min := Vector2(2.0 / 128.0, 26.0 / 128.0)
	var uv_top_max := Vector2(92.0 / 128.0, 83.0 / 128.0)

	var uv_leg_min := Vector2(0.734, 0.078)
	var uv_leg_max := Vector2(0.992, 0.469)

	# 1. Tablero Superior
	var top_center := Vector3(0.0, h - t_t * 0.5, 0.0)
	var top_sz := Vector3(w, t_t, d)
	_add_box_st(st, top_center, top_sz, uv_top_min, uv_top_max, uv_leg_min, uv_leg_max)

	# 2. 4 Patas
	var leg_dx := w * 0.5 - l_sz * 0.5 - 0.02
	var leg_dz := d * 0.5 - l_sz * 0.5 - 0.02
	var leg_y := l_h * 0.5
	var leg_sz_v := Vector3(l_sz, l_h, l_sz)

	var leg_pos: Array[Vector3] = [
		Vector3(-leg_dx, leg_y, -leg_dz),
		Vector3( leg_dx, leg_y, -leg_dz),
		Vector3(-leg_dx, leg_y,  leg_dz),
		Vector3( leg_dx, leg_y,  leg_dz)
	]
	for lp in leg_pos:
		_add_simple_box_st(st, lp, leg_sz_v, uv_leg_min, uv_leg_max)

	# 3. Faldones perimetrales (Bastidor)
	var apron_y := l_h - ap_h * 0.5
	var apron_t := 0.024
	var side_apron_l := d - (l_sz + 0.02) * 2.0
	var back_apron_l := w - (l_sz + 0.02) * 2.0

	# Faldón Izquierdo (-X)
	_add_simple_box_st(st, Vector3(-leg_dx, apron_y, 0.0), Vector3(apron_t, ap_h, side_apron_l), uv_leg_min, uv_leg_max)
	# Faldón Derecho (+X)
	_add_simple_box_st(st, Vector3( leg_dx, apron_y, 0.0), Vector3(apron_t, ap_h, side_apron_l), uv_leg_min, uv_leg_max)
	# Faldón Trasero (-Z)
	_add_simple_box_st(st, Vector3(0.0, apron_y, -leg_dz), Vector3(back_apron_l, ap_h, apron_t), uv_leg_min, uv_leg_max)

	# Faldones frontales (+Z): Dejan el hueco central de ancho dr_w para el cajón
	var front_sub_w := (back_apron_l - dr_w) * 0.5
	if front_sub_w > 0.02:
		var front_dx := leg_dx - l_sz * 0.5 - front_sub_w * 0.5
		_add_simple_box_st(st, Vector3(-front_dx, apron_y, leg_dz), Vector3(front_sub_w, ap_h, apron_t), uv_leg_min, uv_leg_max)
		_add_simple_box_st(st, Vector3( front_dx, apron_y, leg_dz), Vector3(front_sub_w, ap_h, apron_t), uv_leg_min, uv_leg_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _build_drawer_mesh(dw: float, dd: float, dh: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas:
	# - Frente de cajón con marco biselado: X [1..92]/128 = [0.008, 0.719], Y [80..126]/128 = [0.625, 0.984]
	# - Laterales e interior: X [94..127]/128 = [0.734, 0.992], Y [62..126]/128 = [0.484, 0.984]
	var uv_front_min := Vector2(0.008, 0.625)
	var uv_front_max := Vector2(0.719, 0.984)

	var uv_wood_min := Vector2(0.734, 0.484)
	var uv_wood_max := Vector2(0.992, 0.984)

	var wall_t := 0.020
	var front_t := 0.022

	# 1. Tapa frontal con moldura/marco
	var front_center := Vector3(0.0, dh * 0.5, 0.0)
	var front_sz := Vector3(dw, dh, front_t)
	_add_drawer_front_st(st, front_center, front_sz, uv_front_min, uv_front_max, uv_wood_min, uv_wood_max)

	# 2. Caja interior del cajón (se extiende hacia -Z)
	var box_d := dd - front_t
	var box_cz := -front_t * 0.5 - box_d * 0.5

	# Fondo
	_add_simple_box_st(st, Vector3(0.0, wall_t * 0.5, box_cz), Vector3(dw - 0.04, wall_t, box_d), uv_wood_min, uv_wood_max)
	# Lateral izquierdo (-X)
	_add_simple_box_st(st, Vector3(-(dw * 0.5 - 0.02 - wall_t * 0.5), dh * 0.5, box_cz), Vector3(wall_t, dh, box_d), uv_wood_min, uv_wood_max)
	# Lateral derecho (+X)
	_add_simple_box_st(st, Vector3( (dw * 0.5 - 0.02 - wall_t * 0.5), dh * 0.5, box_cz), Vector3(wall_t, dh, box_d), uv_wood_min, uv_wood_max)
	# Trasera (-Z)
	_add_simple_box_st(st, Vector3(0.0, dh * 0.5, -front_t * 0.5 - box_d + wall_t * 0.5), Vector3(dw - 0.04, dh, wall_t), uv_wood_min, uv_wood_max)

	# 3. Jaladera / Tirador de madera en el centro de la tapa frontal
	var pull_sz := Vector3(0.07, 0.016, 0.018)
	var pull_c := Vector3(0.0, dh * 0.5, front_t * 0.5 + pull_sz.z * 0.5)
	_add_simple_box_st(st, pull_c, pull_sz, uv_wood_min, uv_wood_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _add_drawer_front_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_front_min: Vector2, uv_front_max: Vector2, uv_side_min: Vector2, uv_side_max: Vector2) -> void:
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

	# +Z Cara frontal enmarcada
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_front_min, uv_front_max)
	# Cantos y trasera
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_side_min, uv_side_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_side_min, uv_side_max)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_side_min, uv_side_max)


static func _add_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_top_min: Vector2, uv_top_max: Vector2, uv_side_min: Vector2, uv_side_max: Vector2) -> void:
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

	# +Y Cubierta con duelas (v7, v6, v2, v3 orienta X con U y Z con V)
	_add_quad_st(st, v7, v6, v2, v3, Vector3.UP, uv_top_min, uv_top_max)
	# -Y Base inferior con duelas
	_add_quad_st(st, v4, v0, v1, v5, Vector3.DOWN, uv_top_min, uv_top_max)
	# Cantos
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_side_min, uv_side_max)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_side_min, uv_side_max)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_side_min, uv_side_max)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_side_min, uv_side_max)


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


func _setup_collision(w: float, d: float, h: float, dw: float, dd: float, dh: float, _dy: float) -> void:
	var table_col_body := FurnitureInteractProxy.new()
	table_col_body.name = "TableCollision"
	table_col_body.target_callable = Callable(self, "toggle_drawer")

	var top_col := CollisionShape3D.new()
	var top_box := BoxShape3D.new()
	top_box.size = Vector3(w, h, d)
	top_col.shape = top_box
	top_col.position = Vector3(0.0, h * 0.5, 0.0)
	table_col_body.add_child(top_col)

	_table_collision = table_col_body
	add_child(_table_collision)

	if _drawer_pivot:
		var drawer_col_body := FurnitureInteractProxy.new()
		drawer_col_body.name = "DrawerCollision"
		drawer_col_body.target_callable = Callable(self, "toggle_drawer")
		var d_col := CollisionShape3D.new()
		var d_box := BoxShape3D.new()
		d_box.size = Vector3(dw, dh, dd)
		d_col.shape = d_box
		d_col.position = Vector3(0.0, dh * 0.5, -dd * 0.5)
		drawer_col_body.add_child(d_col)
		_drawer_pivot.add_child(drawer_col_body)


static func _get_or_create_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.42
	mat.metallic = 0.06
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	var img := Image.load_from_file(gpath)
	if img and not img.is_empty():
		mat.albedo_texture = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(TEXTURE_PATH):
		mat.albedo_texture = load(TEXTURE_PATH)

	_cached_material = mat
	return mat
