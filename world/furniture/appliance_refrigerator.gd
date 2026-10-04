class_name ApplianceRefrigerator
extends Node3D

## Refrigerador Doméstico Procedural con Puertas Abatibles
## - Mapeado a la textura res://assets/textures/furniture/refrigerador.png
## - Puerta superior de congelador abatible (bisagra derecha)
## - Puerta principal inferior abatible (bisagra derecha)
## - Cavidad interna con repisas interiores visibles al abrir
## - Colisiones físicas precisas que giran con las puertas

const TEXTURE_PATH: String = "res://assets/textures/furniture/refrigerador.png"

@export_group("Dimensiones")
@export var width: float = 0.72       ## Ancho total (72cm)
@export var depth: float = 0.68       ## Profundidad total (68cm)
@export var height: float = 1.68      ## Altura total (1.68m)
@export var wall_thickness: float = 0.045 ## Grosor de las paredes aislantes (4.5cm)
@export var door_thickness: float = 0.055 ## Grosor de las puertas (5.5cm)

@export_group("Apertura de Puertas")
@export_range(0.0, 1.0) var freezer_open_ratio: float = 0.0:
	set(val):
		freezer_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angles()

@export_range(0.0, 1.0) var main_door_open_ratio: float = 0.0:
	set(val):
		main_door_open_ratio = clampf(val, 0.0, 1.0)
		_update_door_angles()

const MAX_DOOR_ANGLE: float = deg_to_rad(110.0) # Apertura de hasta 110 grados

# Nodos internos
var _body_mesh_instance: MeshInstance3D = null
var _freezer_pivot: Node3D = null
var _freezer_mesh_instance: MeshInstance3D = null
var _main_door_pivot: Node3D = null
var _main_door_mesh_instance: MeshInstance3D = null
var _body_collision: StaticBody3D = null
var _freezer_collision: CollisionShape3D = null
var _main_door_collision: CollisionShape3D = null

static var _cached_material: StandardMaterial3D = null
static var _cached_body_mesh: ArrayMesh = null
static var _cached_freezer_mesh: ArrayMesh = null
static var _cached_main_door_mesh: ArrayMesh = null
static var _cached_complete_mesh: ArrayMesh = null


## Retorna la malla compartida del cuerpo para GPU Instancing
static func get_shared_body_mesh() -> ArrayMesh:
	if _cached_body_mesh == null:
		var grille_h := 0.10
		var main_door_h := (1.68 - grille_h) * 0.58
		var main_door_y_top := grille_h + main_door_h
		_cached_body_mesh = _build_cabinet_mesh(0.72, 0.68 - 0.055, 1.68, 0.045, grille_h, main_door_y_top)
	return _cached_body_mesh


## Retorna la malla compartida completa (cuerpo + 2 puertas cerradas) para GPU Instancing en 1 Draw Call
static func get_shared_mesh() -> ArrayMesh:
	if _cached_complete_mesh != null:
		return _cached_complete_mesh

	var grille_h := 0.10
	var h := 1.68
	var w := 0.72
	var d := 0.68
	var door_t := 0.055
	var body_d := d - door_t
	var main_door_h := (h - grille_h) * 0.58
	var freezer_door_h := (h - grille_h) * 0.40
	var gap := (h - grille_h) * 0.02
	var main_door_y_bottom := grille_h
	var main_door_y_top := main_door_y_bottom + main_door_h
	var freezer_door_y_bottom := main_door_y_top + gap

	var body := get_shared_body_mesh()
	var freezer := _build_door_mesh(w, freezer_door_h, door_t, true)
	var main_door := _build_door_mesh(w, main_door_h, door_t, false)

	var hinge_x := w * 0.5
	var hinge_z := body_d * 0.5

	var freezer_xform := Transform3D(Basis.IDENTITY, Vector3(hinge_x - w, freezer_door_y_bottom, hinge_z))
	var main_xform := Transform3D(Basis.IDENTITY, Vector3(hinge_x - w, main_door_y_bottom, hinge_z))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(body, 0, Transform3D.IDENTITY)
	st.append_from(freezer, 0, freezer_xform)
	st.append_from(main_door, 0, main_xform)
	st.generate_normals()
	st.generate_tangents()
	_cached_complete_mesh = st.commit()
	return _cached_complete_mesh


## Retorna las cajas de colisión para el sistema MultiMesh
static func get_collision_boxes(w: float = 0.72, d: float = 0.68, h: float = 1.68) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, h * 0.5, 0.0),
			"size": Vector3(w, h, d)
		}
	]


func _ready() -> void:
	_build_refrigerator()


## Reconstruye toda la geometría del refrigerador y sus puertas
func _build_refrigerator() -> void:
	for child in get_children():
		child.queue_free()

	var mat := _get_or_create_material()

	# Alturas clave (en Y relativa desde y=0)
	var grille_h := 0.10
	var main_door_h := (height - grille_h) * 0.58
	var freezer_door_h := (height - grille_h) * 0.40
	var gap := (height - grille_h) * 0.02

	var main_door_y_bottom := grille_h
	var main_door_y_top := main_door_y_bottom + main_door_h
	var freezer_door_y_bottom := main_door_y_top + gap
	var freezer_door_y_top := freezer_door_y_bottom + freezer_door_h

	# 1. Cuerpo / Gabinete Principal (sin las puertas frontales)
	var body_depth := depth - door_thickness
	var is_default_dim := (
		is_equal_approx(width, 0.72)
		and is_equal_approx(depth, 0.68)
		and is_equal_approx(height, 1.68)
		and is_equal_approx(wall_thickness, 0.045)
		and is_equal_approx(door_thickness, 0.055)
	)

	var body_mesh: ArrayMesh
	if is_default_dim:
		body_mesh = get_shared_body_mesh()
	else:
		body_mesh = _build_cabinet_mesh(width, body_depth, height, wall_thickness, grille_h, main_door_y_top)

	_body_mesh_instance = MeshInstance3D.new()
	_body_mesh_instance.name = "CabinetMesh"
	_body_mesh_instance.mesh = body_mesh
	_body_mesh_instance.material_override = mat
	add_child(_body_mesh_instance)

	# 2. Puerta del Congelador (Pivote en la esquina frontal DERECHA)
	# Nota: En refrigerador.png las manijas están a la izquierda, por lo que la bisagra está en +X (derecha).
	var hinge_x := width * 0.5
	var hinge_z := body_depth * 0.5

	_freezer_pivot = Node3D.new()
	_freezer_pivot.name = "FreezerDoorPivot"
	_freezer_pivot.position = Vector3(hinge_x, freezer_door_y_bottom, hinge_z)
	add_child(_freezer_pivot)

	var freezer_mesh := _build_door_mesh(width, freezer_door_h, door_thickness, true)
	_freezer_mesh_instance = MeshInstance3D.new()
	_freezer_mesh_instance.name = "FreezerDoorMesh"
	_freezer_mesh_instance.mesh = freezer_mesh
	_freezer_mesh_instance.material_override = mat
	_freezer_mesh_instance.position = Vector3(-width, 0.0, 0.0) # Desplazado respecto al pivote
	_freezer_pivot.add_child(_freezer_mesh_instance)

	# 3. Puerta Principal Inferior
	_main_door_pivot = Node3D.new()
	_main_door_pivot.name = "MainDoorPivot"
	_main_door_pivot.position = Vector3(hinge_x, main_door_y_bottom, hinge_z)
	add_child(_main_door_pivot)

	var main_door_mesh := _build_door_mesh(width, main_door_h, door_thickness, false)
	_main_door_mesh_instance = MeshInstance3D.new()
	_main_door_mesh_instance.name = "MainDoorMesh"
	_main_door_mesh_instance.mesh = main_door_mesh
	_main_door_mesh_instance.material_override = mat
	_main_door_mesh_instance.position = Vector3(-width, 0.0, 0.0)
	_main_door_pivot.add_child(_main_door_mesh_instance)

	# 4. Configurar Colisiones
	_setup_collision(width, body_depth, height, wall_thickness, freezer_door_h, main_door_h, door_thickness)
	_update_door_angles()


func _update_door_angles() -> void:
	if _freezer_pivot:
		# La bisagra derecha rota en sentido positivo horario hacia afuera
		_freezer_pivot.rotation.y = freezer_open_ratio * MAX_DOOR_ANGLE
	if _main_door_pivot:
		_main_door_pivot.rotation.y = main_door_open_ratio * MAX_DOOR_ANGLE


## Abre o cierra la puerta del congelador de forma animada o instantánea
func toggle_freezer(animated: bool = true) -> void:
	var target := 1.0 if freezer_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "freezer_open_ratio", target, 0.45)
	else:
		freezer_open_ratio = target


## Abre o cierra la puerta principal del refrigerador
func toggle_main_door(animated: bool = true) -> void:
	var target := 1.0 if main_door_open_ratio < 0.5 else 0.0
	if animated and is_inside_tree():
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "main_door_open_ratio", target, 0.45)
	else:
		main_door_open_ratio = target


## Punto de interacción al presionar [E] (ver InteractController)
func interact(_interactor: Node = null) -> void:
	toggle_main_door()


# =========================================================================
# GENERACIÓN DE GEOMETRÍA (SurfaceTool)
# =========================================================================

## Construye la caja del gabinete con interior hueco, repisas y rejilla inferior
static func _build_cabinet_mesh(w: float, d: float, h: float, wall_t: float, grille_h: float, shelf_sep_y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Atlas UVs:
	# Metal gris cuerpo: X in [85/256, 255/256] = [0.332, 0.996], Y in [0, 1]
	# Rejilla inferior: X in [0, 84/256] = [0.0, 0.328], Y in [243/256, 255/256] = [0.949, 1.0]
	var uv_metal_min := Vector2(0.35, 0.1)
	var uv_metal_max := Vector2(0.95, 0.9)
	var uv_grille_min := Vector2(0.01, 0.949)
	var uv_grille_max := Vector2(0.325, 0.998)

	var hw := w * 0.5
	var hd := d * 0.5

	# 1. Pared Posterior (Back)
	_add_box_st(st, Vector3(0.0, h * 0.5, -hd + wall_t * 0.5), Vector3(w, h, wall_t), uv_metal_min, uv_metal_max)

	# 2. Pared Izquierda (Left)
	var side_d := d - wall_t
	var side_z := wall_t * 0.5
	_add_box_st(st, Vector3(-hw + wall_t * 0.5, h * 0.5, side_z), Vector3(wall_t, h, side_d), uv_metal_min, uv_metal_max)

	# 3. Pared Derecha (Right)
	_add_box_st(st, Vector3(hw - wall_t * 0.5, h * 0.5, side_z), Vector3(wall_t, h, side_d), uv_metal_min, uv_metal_max)

	# 4. Techo Superior (Top)
	_add_box_st(st, Vector3(0.0, h - wall_t * 0.5, side_z), Vector3(w - wall_t * 2.0, wall_t, side_d), uv_metal_min, uv_metal_max)

	# 5. Base Inferior (Floor del refri)
	_add_box_st(st, Vector3(0.0, grille_h + wall_t * 0.5, side_z), Vector3(w - wall_t * 2.0, wall_t, side_d), uv_metal_min, uv_metal_max)

	# 6. Rejilla inferior de ventilación frontal (Z frontal)
	var grille_z := hd - wall_t * 0.5
	_add_box_st(st, Vector3(0.0, grille_h * 0.5, grille_z), Vector3(w, grille_h, wall_t), uv_grille_min, uv_grille_max)

	# 7. Divisor horizontal entre Congelador y Nevera
	var inner_w := w - wall_t * 2.0
	_add_box_st(st, Vector3(0.0, shelf_sep_y, side_z), Vector3(inner_w, wall_t, side_d), uv_metal_min, uv_metal_max)

	# 8. Repisas interiores de cristal / rejilla (2 en nevera, 1 en congelador)
	var shelf_t := 0.015
	var shelf_d := side_d - 0.04
	var shelf_z := side_z - 0.02
	# Nevera: repisa media y repisa alta
	var n_bottom := grille_h + wall_t
	var n_h := shelf_sep_y - n_bottom
	_add_box_st(st, Vector3(0.0, n_bottom + n_h * 0.35, shelf_z), Vector3(inner_w - 0.01, shelf_t, shelf_d), uv_metal_min, uv_metal_max)
	_add_box_st(st, Vector3(0.0, n_bottom + n_h * 0.70, shelf_z), Vector3(inner_w - 0.01, shelf_t, shelf_d), uv_metal_min, uv_metal_max)
	# Congelador: repisa central
	var f_bottom := shelf_sep_y + wall_t
	var f_h := (h - wall_t) - f_bottom
	_add_box_st(st, Vector3(0.0, f_bottom + f_h * 0.50, shelf_z), Vector3(inner_w - 0.01, shelf_t, shelf_d), uv_metal_min, uv_metal_max)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Construye una puerta (congelador o nevera) con textura frontal del atlas y bordes metálicos
static func _build_door_mesh(w: float, h: float, thick: float, is_freezer: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# UVs del frente según el atlas refrigerador.png:
	# Puerta freezer: X in [0.005, 0.325], Y in [0.005, 0.502]
	# Puerta nevera:  X in [0.005, 0.325], Y in [0.510, 0.945]
	var uv_front_min: Vector2
	var uv_front_max: Vector2
	if is_freezer:
		uv_front_min = Vector2(0.005, 0.005)
		uv_front_max = Vector2(0.325, 0.502)
	else:
		uv_front_min = Vector2(0.005, 0.510)
		uv_front_max = Vector2(0.325, 0.945)

	var uv_metal_min := Vector2(0.35, 0.1)
	var uv_metal_max := Vector2(0.95, 0.9)

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

	# +Z (Frontal)
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_min, uv_max)
	# -Z (Trasera)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_min, uv_max)
	# +X (Derecha)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_min, uv_max)
	# -X (Izquierda)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_min, uv_max)
	# +Y (Arriba)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_min, uv_max)
	# -Y (Abajo)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_min, uv_max)


static func _add_door_box_st(st: SurfaceTool, center: Vector3, size: Vector3, uv_front_min: Vector2, uv_front_max: Vector2, uv_body_min: Vector2, uv_body_max: Vector2) -> void:
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

	# +Z (Cara frontal exterior con manija y relieve gráfico)
	_add_quad_st(st, v4, v5, v6, v7, Vector3.FORWARD, uv_front_min, uv_front_max)
	# -Z (Cara interior de la puerta hacia la nevera)
	_add_quad_st(st, v1, v0, v3, v2, Vector3.BACK, uv_body_min, uv_body_max)
	# +X (Canto derecho)
	_add_quad_st(st, v5, v1, v2, v6, Vector3.RIGHT, uv_body_min, uv_body_max)
	# -X (Canto izquierdo)
	_add_quad_st(st, v0, v4, v7, v3, Vector3.LEFT, uv_body_min, uv_body_max)
	# +Y (Canto superior)
	_add_quad_st(st, v3, v7, v6, v2, Vector3.UP, uv_body_min, uv_body_max)
	# -Y (Canto inferior)
	_add_quad_st(st, v0, v1, v5, v4, Vector3.DOWN, uv_body_min, uv_body_max)


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


func _setup_collision(w: float, d: float, h: float, wall_t: float, f_door_h: float, m_door_h: float, door_t: float) -> void:
	var body_col_body := FurnitureInteractProxy.new()
	body_col_body.name = "RefrigeratorCollision"
	body_col_body.target_callable = Callable(self, "toggle_main_door")

	# Colisión sólida del gabinete (bloque trasero y laterales)
	var back_shape := CollisionShape3D.new()
	var back_box := BoxShape3D.new()
	back_box.size = Vector3(w, h, d)
	back_shape.shape = back_box
	back_shape.position = Vector3(0.0, h * 0.5, 0.0)
	body_col_body.add_child(back_shape)

	_body_collision = body_col_body
	add_child(_body_collision)

	# Colisiones en los pivotes de las puertas para que roten con ellas
	if _freezer_pivot:
		var f_col_body := FurnitureInteractProxy.new()
		f_col_body.name = "FreezerDoorCollision"
		f_col_body.target_callable = Callable(self, "toggle_freezer")
		var f_col := CollisionShape3D.new()
		var f_box := BoxShape3D.new()
		f_box.size = Vector3(w, f_door_h, door_t)
		f_col.shape = f_box
		f_col.position = Vector3(-w * 0.5, f_door_h * 0.5, door_t * 0.5)
		f_col_body.add_child(f_col)
		_freezer_pivot.add_child(f_col_body)

	if _main_door_pivot:
		var m_col_body := FurnitureInteractProxy.new()
		m_col_body.name = "MainDoorCollision"
		m_col_body.target_callable = Callable(self, "toggle_main_door")
		var m_col := CollisionShape3D.new()
		var m_box := BoxShape3D.new()
		m_box.size = Vector3(w, m_door_h, door_t)
		m_col.shape = m_box
		m_col.position = Vector3(-w * 0.5, m_door_h * 0.5, door_t * 0.5)
		m_col_body.add_child(m_col)
		_main_door_pivot.add_child(m_col_body)


static func _get_or_create_material() -> StandardMaterial3D:
	if _cached_material != null:
		return _cached_material

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.35 # Acabado esmaltado liso brillante de refrigerador
	mat.metallic = 0.15  # Brillo metálico electrodoméstico
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	var img := Image.load_from_file(gpath)
	if img and not img.is_empty():
		mat.albedo_texture = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(TEXTURE_PATH):
		mat.albedo_texture = load(TEXTURE_PATH)

	_cached_material = mat
	return mat
