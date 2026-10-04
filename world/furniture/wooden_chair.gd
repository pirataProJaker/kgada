class_name WoodenChair
extends Node3D

## Modelo 3D de Silla de Madera Ergonómica (Estilo Refinado / Carpintería Fina)
## Genera geometría optimizada en un solo draw call con colisiones físicas precisas.
## Soporta texturas de madera refinada y GPU Instancing vía MultiMeshInstance3D.

enum WoodFinish {
	ROBLE_CLARO = 0,  ## Roble claro refinado
	NOGAL_OSCURO = 1, ## Nogal oscuro elegante
	CAOBA_ROJIZA = 2, ## Caoba / Cedro rojizo cálido
	PINO_NATURAL = 3  ## Pino natural / Miel dorado
}

const TEXTURE_PATHS: Dictionary = {
	WoodFinish.ROBLE_CLARO: "res://assets/textures/house/pared_madera.png",
	WoodFinish.NOGAL_OSCURO: "res://assets/textures/house/pared_madera2.png"
}

@export var finish: WoodFinish = WoodFinish.ROBLE_CLARO:
	set(val):
		finish = val
		if is_inside_tree():
			_rebuild()

@export var seat_height: float = 0.45 ## Altura del asiento al suelo (estándar ergonómico 45cm)
@export var seat_width: float = 0.44  ## Ancho del asiento (44cm)
@export var seat_depth: float = 0.44  ## Profundidad del asiento (44cm)
@export var back_height: float = 0.88 ## Altura total del respaldo (88cm)

var _mesh_instance: MeshInstance3D = null
var _collision_body: StaticBody3D = null
static var _material_cache: Dictionary = {}
static var _cached_shared_mesh: ArrayMesh = null


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "ChairMesh"
	
	if is_equal_approx(seat_width, 0.44) and is_equal_approx(seat_depth, 0.44) and is_equal_approx(seat_height, 0.45) and is_equal_approx(back_height, 0.88):
		_mesh_instance.mesh = get_shared_mesh()
	else:
		_mesh_instance.mesh = build_chair_mesh(seat_width, seat_depth, seat_height, back_height)

	_mesh_instance.material_override = _get_or_create_material(finish)
	add_child(_mesh_instance)

	_setup_collision()


## Retorna la malla compartida en memoria (generada una sola vez para miles de instancias)
static func get_shared_mesh() -> ArrayMesh:
	if _cached_shared_mesh == null:
		_cached_shared_mesh = build_chair_mesh(0.44, 0.44, 0.45, 0.88)
	return _cached_shared_mesh


## Construye la geometría 3D de la silla mediante SurfaceTool
static func build_chair_mesh(s_w: float = 0.44, s_d: float = 0.44, s_h: float = 0.45, b_h: float = 0.88) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var leg_t := 0.040      # Grosor de patas: 4cm x 4cm
	var seat_t := 0.035     # Grosor de la tabla del asiento: 3.5cm
	var apron_h := 0.050    # Altura del faldón bajo el asiento: 5cm
	var apron_t := 0.020    # Grosor del faldón: 2cm

	var half_w := s_w * 0.5
	var half_d := s_d * 0.5
	var leg_inset := 0.030

	var lx := half_w - leg_inset - leg_t * 0.5
	var lz_front := half_d - leg_inset - leg_t * 0.5
	var lz_back := -half_d + leg_inset + leg_t * 0.5

	# 1. Asiento (Tabla de madera maciza)
	_add_box(st, Vector3(0.0, s_h - seat_t * 0.5, 0.0), Vector3(s_w, seat_t, s_d), 0)

	# 2. Patas Delanteras (desde y=0 hasta la base del asiento)
	var front_leg_h := s_h - seat_t
	_add_box(st, Vector3(-lx, front_leg_h * 0.5, lz_front), Vector3(leg_t, front_leg_h, leg_t), 1)
	_add_box(st, Vector3(lx, front_leg_h * 0.5, lz_front), Vector3(leg_t, front_leg_h, leg_t), 1)

	# 3. Patas Traseras Continuas (desde y=0 hasta la cima del respaldo en una sola pieza de ebanistería)
	var back_leg_h := b_h
	_add_box(st, Vector3(-lx, back_leg_h * 0.5, lz_back), Vector3(leg_t, back_leg_h, leg_t), 1)
	_add_box(st, Vector3(lx, back_leg_h * 0.5, lz_back), Vector3(leg_t, back_leg_h, leg_t), 1)

	# 4. Faldones estructurales perimetrales debajo del asiento
	var apron_y := s_h - seat_t - apron_h * 0.5
	var apron_span_x := (lx * 2.0) - leg_t
	var apron_span_z := (lz_front - lz_back) - leg_t

	# Faldón Frontal y Trasero
	_add_box(st, Vector3(0.0, apron_y, lz_front), Vector3(apron_span_x, apron_h, apron_t), 0)
	_add_box(st, Vector3(0.0, apron_y, lz_back), Vector3(apron_span_x, apron_h, apron_t), 0)

	# Faldones Laterales
	var mid_lz := (lz_front + lz_back) * 0.5
	_add_box(st, Vector3(-lx, apron_y, mid_lz), Vector3(apron_t, apron_h, apron_span_z), 2)
	_add_box(st, Vector3(lx, apron_y, mid_lz), Vector3(apron_t, apron_h, apron_span_z), 2)

	# 5. Travesaños inferiores de refuerzo (a 12cm del piso para máxima estabilidad)
	var rung_y := 0.12
	var rung_t := 0.022
	_add_box(st, Vector3(-lx, rung_y, mid_lz), Vector3(rung_t, rung_t, apron_span_z), 2)
	_add_box(st, Vector3(lx, rung_y, mid_lz), Vector3(rung_t, rung_t, apron_span_z), 2)
	_add_box(st, Vector3(0.0, rung_y, lz_back), Vector3(apron_span_x, rung_t, rung_t), 0)

	# 6. Respaldo (Ebanistería ergonómica)
	var top_rail_h := 0.065
	var top_rail_t := 0.030
	var top_rail_w := (lx * 2.0) + leg_t * 1.5
	_add_box(st, Vector3(0.0, b_h - top_rail_h * 0.5, lz_back), Vector3(top_rail_w, top_rail_h, top_rail_t), 0)

	var mid_rail_y := s_h + 0.08
	var mid_rail_h := 0.035
	_add_box(st, Vector3(0.0, mid_rail_y, lz_back), Vector3(apron_span_x, mid_rail_h, 0.022), 0)

	var slat_bottom := mid_rail_y + mid_rail_h * 0.5
	var slat_top := b_h - top_rail_h
	var slat_h := slat_top - slat_bottom
	var slat_y := (slat_top + slat_bottom) * 0.5
	var slat_w := 0.038
	var slat_t := 0.016

	for sx in [-0.085, 0.0, 0.085]:
		_add_box(st, Vector3(sx, slat_y, lz_back), Vector3(slat_w, slat_h, slat_t), 1)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Agrega una caja al SurfaceTool con normales exactas y UVs orientadas según la veta de la madera
static func _add_box(st: SurfaceTool, center: Vector3, size: Vector3, grain_axis: int) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var uv_s := 2.0

	var v_lbd := center + Vector3(-hx, -hy, -hz) # 0: Izq-Abajo-Atras
	var v_rbd := center + Vector3( hx, -hy, -hz) # 1: Der-Abajo-Atras
	var v_rtd := center + Vector3( hx,  hy, -hz) # 2: Der-Arriba-Atras
	var v_ltd := center + Vector3(-hx,  hy, -hz) # 3: Izq-Arriba-Atras
	var v_lbf := center + Vector3(-hx, -hy,  hz) # 4: Izq-Abajo-Frente
	var v_rbf := center + Vector3( hx, -hy,  hz) # 5: Der-Abajo-Frente
	var v_rtf := center + Vector3( hx,  hy,  hz) # 6: Der-Arriba-Frente
	var v_ltf := center + Vector3(-hx,  hy,  hz) # 7: Izq-Arriba-Frente

	# Cara +Y (Superior)
	var u_top := size.x * uv_s if grain_axis != 0 else size.x * uv_s * 1.5
	var v_top := size.z * uv_s
	_add_quad(st, v_ltd, v_ltf, v_rtf, v_rtd, Vector3.UP,
		Vector2(0.0, 0.0), Vector2(0.0, v_top), Vector2(u_top, v_top), Vector2(u_top, 0.0))

	# Cara -Y (Inferior)
	_add_quad(st, v_lbd, v_rbd, v_rbf, v_lbf, Vector3.DOWN,
		Vector2(0.0, 0.0), Vector2(size.x * uv_s, 0.0), Vector2(size.x * uv_s, size.z * uv_s), Vector2(0.0, size.z * uv_s))

	# Cara +Z (Frontal)
	_add_quad(st, v_lbf, v_rbf, v_rtf, v_ltf, Vector3.FORWARD,
		Vector2(0.0, size.y * uv_s), Vector2(size.x * uv_s, size.y * uv_s), Vector2(size.x * uv_s, 0.0), Vector2(0.0, 0.0))

	# Cara -Z (Trasera)
	_add_quad(st, v_rbd, v_lbd, v_ltd, v_rtd, Vector3.BACK,
		Vector2(0.0, size.y * uv_s), Vector2(size.x * uv_s, size.y * uv_s), Vector2(size.x * uv_s, 0.0), Vector2(0.0, 0.0))

	# Cara +X (Derecha)
	_add_quad(st, v_rbf, v_rbd, v_rtd, v_rtf, Vector3.RIGHT,
		Vector2(0.0, size.y * uv_s), Vector2(size.z * uv_s, size.y * uv_s), Vector2(size.z * uv_s, 0.0), Vector2(0.0, 0.0))

	# Cara -X (Izquierda)
	_add_quad(st, v_lbd, v_lbf, v_ltf, v_ltd, Vector3.LEFT,
		Vector2(0.0, size.y * uv_s), Vector2(size.z * uv_s, size.y * uv_s), Vector2(size.z * uv_s, 0.0), Vector2(0.0, 0.0))


static func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, n: Vector3, u0: Vector2, u1: Vector2, u2: Vector2, u3: Vector2) -> void:
	st.set_normal(n); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(n); st.set_uv(u1); st.add_vertex(v1)
	st.set_normal(n); st.set_uv(u2); st.add_vertex(v2)

	st.set_normal(n); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(n); st.set_uv(u2); st.add_vertex(v2)
	st.set_normal(n); st.set_uv(u3); st.add_vertex(v3)


## Define las cajas de colisión precisas para la silla
static func get_collision_boxes(s_w: float = 0.44, s_d: float = 0.44, s_h: float = 0.45, b_h: float = 0.88) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	# 1. Asiento / base
	boxes.append({
		"size": Vector3(s_w, s_h, s_d),
		"position": Vector3(0.0, s_h * 0.5, 0.0)
	})
	# 2. Respaldo
	var back_h := b_h - s_h
	boxes.append({
		"size": Vector3(s_w, back_h, 0.08),
		"position": Vector3(0.0, s_h + back_h * 0.5, -s_d * 0.5 + 0.04)
	})
	return boxes


func _setup_collision() -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "ChairCollision"

	for b_dict in get_collision_boxes(seat_width, seat_depth, seat_height, back_height):
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b_dict["size"]
		col.shape = box
		col.position = b_dict["position"]
		_collision_body.add_child(col)

	add_child(_collision_body)


static func _get_or_create_material(p_finish: int) -> StandardMaterial3D:
	if _material_cache.has(p_finish):
		return _material_cache[p_finish]

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.55
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var tex_path: String = TEXTURE_PATHS.get(p_finish, "")
	var tex: Texture2D = null
	if not tex_path.is_empty():
		var global_path := ProjectSettings.globalize_path(tex_path)
		var img := Image.load_from_file(global_path)
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
		elif ResourceLoader.exists(tex_path):
			tex = load(tex_path)

	if tex:
		mat.albedo_texture = tex
		mat.albedo_color = Color(1.0, 1.0, 1.0)
	elif p_finish == WoodFinish.CAOBA_ROJIZA:
		var tex_dark: String = TEXTURE_PATHS.get(WoodFinish.NOGAL_OSCURO, "")
		var gpath := ProjectSettings.globalize_path(tex_dark)
		var img := Image.load_from_file(gpath)
		if img and not img.is_empty():
			mat.albedo_texture = ImageTexture.create_from_image(img)
			mat.albedo_color = Color(1.15, 0.88, 0.75)
		else:
			mat.albedo_color = Color(0.55, 0.28, 0.20)
	elif p_finish == WoodFinish.PINO_NATURAL:
		var tex_light: String = TEXTURE_PATHS.get(WoodFinish.ROBLE_CLARO, "")
		var gpath := ProjectSettings.globalize_path(tex_light)
		var img := Image.load_from_file(gpath)
		if img and not img.is_empty():
			mat.albedo_texture = ImageTexture.create_from_image(img)
			mat.albedo_color = Color(1.10, 1.02, 0.82)
		else:
			mat.albedo_color = Color(0.80, 0.65, 0.40)
	else:
		mat.albedo_color = Color(0.68, 0.48, 0.32)

	_material_cache[p_finish] = mat
	return mat
