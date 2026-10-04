class_name WoodenTable
extends Node3D

## Modelo 3D de Mesa de Madera Maciza (Estilo Refinado / Comedor Contemporáneo)
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

@export var table_length: float = 1.40       ## Longitud de la mesa (1.40m para 4 a 6 comensales)
@export var table_width: float = 0.85        ## Ancho de la mesa (0.85m)
@export var table_height: float = 0.75       ## Altura estándar ergonómica de mesa (75cm)
@export var tabletop_thickness: float = 0.040 ## Grosor del tablón de la cubierta (4cm)
@export var leg_thickness: float = 0.070      ## Grosor de las 4 patas cuadradas (7cm x 7cm)

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
	_mesh_instance.name = "TableMesh"

	if is_equal_approx(table_length, 1.40) and is_equal_approx(table_width, 0.85) and is_equal_approx(table_height, 0.75) and is_equal_approx(tabletop_thickness, 0.040) and is_equal_approx(leg_thickness, 0.070):
		_mesh_instance.mesh = get_shared_mesh()
	else:
		_mesh_instance.mesh = build_table_mesh(table_length, table_width, table_height, tabletop_thickness, leg_thickness)

	_mesh_instance.material_override = _get_or_create_material(finish)
	add_child(_mesh_instance)

	_setup_collision()


## Retorna la malla compartida en memoria (generada una sola vez para miles de instancias)
static func get_shared_mesh() -> ArrayMesh:
	if _cached_shared_mesh == null:
		_cached_shared_mesh = build_table_mesh(1.40, 0.85, 0.75, 0.040, 0.070)
	return _cached_shared_mesh


## Construye la geometría 3D de la mesa mediante SurfaceTool
static func build_table_mesh(t_len: float = 1.40, t_wid: float = 0.85, t_h: float = 0.75, t_thick: float = 0.040, leg_t: float = 0.070) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var apron_h := 0.070   # Altura del faldón estructural: 7cm
	var apron_t := 0.025   # Grosor del faldón: 2.5cm
	var leg_inset := 0.045 # Retranqueo de las patas respecto al borde de la cubierta: 4.5cm

	var half_l := t_len * 0.5
	var half_w := t_wid * 0.5

	var lx := half_l - leg_inset - leg_t * 0.5
	var lz := half_w - leg_inset - leg_t * 0.5

	# 1. Cubierta de Mesa (Tablón macizo superior)
	var top_y := t_h - t_thick * 0.5
	_add_box(st, Vector3(0.0, top_y, 0.0), Vector3(t_len, t_thick, t_wid), 0)

	# 2. Las 4 Patas Robustas Cuadradas (desde y=0 hasta la base del tablón)
	var leg_h := t_h - t_thick
	var leg_y := leg_h * 0.5
	var leg_size := Vector3(leg_t, leg_h, leg_t)

	_add_box(st, Vector3(-lx, leg_y, -lz), leg_size, 1) # Trasera Izquierda
	_add_box(st, Vector3(lx, leg_y, -lz), leg_size, 1)  # Trasera Derecha
	_add_box(st, Vector3(-lx, leg_y, lz), leg_size, 1)  # Delantera Izquierda
	_add_box(st, Vector3(lx, leg_y, lz), leg_size, 1)   # Delantera Derecha

	# 3. Faldón Perimetral Estructural (Apron rails que unen las patas y soportan la cubierta)
	var apron_y := t_h - t_thick - apron_h * 0.5
	var apron_span_x := (lx * 2.0) - leg_t
	var apron_span_z := (lz * 2.0) - leg_t

	# Faldones longitudinales (Largo)
	_add_box(st, Vector3(0.0, apron_y, -lz), Vector3(apron_span_x, apron_h, apron_t), 0)
	_add_box(st, Vector3(0.0, apron_y, lz), Vector3(apron_span_x, apron_h, apron_t), 0)

	# Faldones transversales (Ancho)
	_add_box(st, Vector3(-lx, apron_y, 0.0), Vector3(apron_t, apron_h, apron_span_z), 2)
	_add_box(st, Vector3(lx, apron_y, 0.0), Vector3(apron_t, apron_h, apron_span_z), 2)

	# 4. Bloques de refuerzo en las 4 esquinas internas
	var bracket_size := Vector3(0.05, 0.05, 0.05)
	var bx := lx - leg_t * 0.5 - 0.025
	var bz := lz - leg_t * 0.5 - 0.025
	var by := t_h - t_thick - 0.025

	_add_box(st, Vector3(-bx, by, -bz), bracket_size, 1)
	_add_box(st, Vector3(bx, by, -bz), bracket_size, 1)
	_add_box(st, Vector3(-bx, by, bz), bracket_size, 1)
	_add_box(st, Vector3(bx, by, bz), bracket_size, 1)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Agrega una caja al SurfaceTool con normales exactas y UVs orientadas según la veta de la madera
static func _add_box(st: SurfaceTool, center: Vector3, size: Vector3, grain_axis: int) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var uv_s := 1.8

	var v_lbd := center + Vector3(-hx, -hy, -hz) # 0: Izq-Abajo-Atras
	var v_rbd := center + Vector3( hx, -hy, -hz) # 1: Der-Abajo-Atras
	var v_rtd := center + Vector3( hx,  hy, -hz) # 2: Der-Arriba-Atras
	var v_ltd := center + Vector3(-hx,  hy, -hz) # 3: Izq-Arriba-Atras
	var v_lbf := center + Vector3(-hx, -hy,  hz) # 4: Izq-Abajo-Frente
	var v_rbf := center + Vector3( hx, -hy,  hz) # 5: Der-Abajo-Frente
	var v_rtf := center + Vector3( hx,  hy,  hz) # 6: Der-Arriba-Frente
	var v_ltf := center + Vector3(-hx,  hy,  hz) # 7: Izq-Arriba-Frente

	# Cara +Y (Superior / Cubierta de Mesa)
	var u_top := size.x * uv_s if grain_axis != 0 else size.x * uv_s * 1.2
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
		Vector2(0.0, size.y * uv_s), Vector2(size.x * uv_s, size.y * uv_s), Vector2(size.z * uv_s, 0.0), Vector2(0.0, 0.0))


static func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, n: Vector3, u0: Vector2, u1: Vector2, u2: Vector2, u3: Vector2) -> void:
	st.set_normal(n); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(n); st.set_uv(u1); st.add_vertex(v1)
	st.set_normal(n); st.set_uv(u2); st.add_vertex(v2)

	st.set_normal(n); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(n); st.set_uv(u2); st.add_vertex(v2)
	st.set_normal(n); st.set_uv(u3); st.add_vertex(v3)


## Define las cajas de colisión precisas para la mesa (cubierta + 4 patas individuales)
static func get_collision_boxes(t_len: float = 1.40, t_wid: float = 0.85, t_h: float = 0.75, t_thick: float = 0.040, leg_t: float = 0.070) -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []

	# 1. Colisión de la cubierta superior (bloque plano)
	boxes.append({
		"size": Vector3(t_len, t_thick + 0.06, t_wid),
		"position": Vector3(0.0, t_h - (t_thick + 0.06) * 0.5, 0.0)
	})

	# 2. Colisión individual para cada pata (permite meter sillas debajo y pasar proyectiles/raycasts)
	var leg_inset := 0.045
	var half_l := t_len * 0.5
	var half_w := t_wid * 0.5
	var lx := half_l - leg_inset - leg_t * 0.5
	var lz := half_w - leg_inset - leg_t * 0.5
	var leg_h := t_h - t_thick - 0.06
	var leg_y := leg_h * 0.5

	for pos_x in [-lx, lx]:
		for pos_z in [-lz, lz]:
			boxes.append({
				"size": Vector3(leg_t, leg_h, leg_t),
				"position": Vector3(pos_x, leg_y, pos_z)
			})

	return boxes


func _setup_collision() -> void:
	_collision_body = StaticBody3D.new()
	_collision_body.name = "TableCollision"

	for b_dict in get_collision_boxes(table_length, table_width, table_height, tabletop_thickness, leg_thickness):
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
