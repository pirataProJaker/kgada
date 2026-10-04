class_name FurniturePropsBuilder
extends RefCounted

## Generador de Mallas Primarias y Props de Consumo (Play Sector X)
## Carga y compila directamente las mallas primarias ultraligeras (12 a 304 tris)
## del paquete PSX con mapeo UV 100% exacto y calibrado al atlas oficial (props_atlas).
## Optimizadas para GPU Instancing: 1 solo draw call por tipo de mueble o prop.

const OBJ_DIR := "res://assets/textures/furniture/psx_pack/psx-furniture-free/obj/"
const TEXTURE_PATH := "res://assets/textures/furniture/furniture_props_atlas.png"

const LINENS_TEXTURE_PATH := "res://assets/textures/furniture/bed_linens_master_atlas.png"

# Caché estático de mallas generadas
static var _mesh_cache: Dictionary = {}
static var _cached_props_texture: Texture2D = null
static var _cached_props_material: StandardMaterial3D = null
static var _cached_linens_texture: Texture2D = null
static var _cached_linens_material: StandardMaterial3D = null


# =========================================================================
# GESTIÓN DE TEXTURA Y MATERIAL
# =========================================================================

## Retorna la textura del atlas de accesorios de forma resiliente
static func get_props_texture() -> Texture2D:
	if _cached_props_texture != null:
		return _cached_props_texture
	var gpath := ProjectSettings.globalize_path(TEXTURE_PATH)
	if FileAccess.file_exists(gpath):
		var img := Image.load_from_file(gpath)
		if img and not img.is_empty():
			_cached_props_texture = ImageTexture.create_from_image(img)
			return _cached_props_texture
	if ResourceLoader.exists(TEXTURE_PATH):
		_cached_props_texture = load(TEXTURE_PATH)
	return _cached_props_texture


## Retorna la textura del atlas maestro de ropa de cama (40 patrones de sábanas y cobijas + colchón y almohada)
static func get_linens_texture() -> Texture2D:
	if _cached_linens_texture != null:
		return _cached_linens_texture
	var gpath := ProjectSettings.globalize_path(LINENS_TEXTURE_PATH)
	if FileAccess.file_exists(gpath):
		var img := Image.load_from_file(gpath)
		if img and not img.is_empty():
			_cached_linens_texture = ImageTexture.create_from_image(img)
			return _cached_linens_texture
	if ResourceLoader.exists(LINENS_TEXTURE_PATH):
		_cached_linens_texture = load(LINENS_TEXTURE_PATH)
	return _cached_linens_texture


## Retorna un material StandardMaterial3D configurado con el atlas para nodos independientes
static func get_props_material(roughness: float = 0.65, metallic: float = 0.02) -> StandardMaterial3D:
	if _cached_props_material != null:
		return _cached_props_material
	_cached_props_material = StandardMaterial3D.new()
	_cached_props_material.roughness = roughness
	_cached_props_material.metallic = metallic
	_cached_props_material.cull_mode = BaseMaterial3D.CULL_DISABLED # Doble cara para que objetos con apertura superior (como tazas) sean 100% sólidos por dentro
	_cached_props_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_cached_props_material.albedo_texture = get_props_texture()
	return _cached_props_material


## Retorna un material StandardMaterial3D configurado con el atlas de sábanas y cobijas
static func get_linens_material(roughness: float = 0.65, metallic: float = 0.01) -> StandardMaterial3D:
	if _cached_linens_material != null:
		return _cached_linens_material
	_cached_linens_material = StandardMaterial3D.new()
	_cached_linens_material.roughness = roughness
	_cached_linens_material.metallic = metallic
	_cached_linens_material.metallic_specular = 0.35
	_cached_linens_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cached_linens_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_cached_linens_material.albedo_texture = get_linens_texture()
	return _cached_linens_material


# =========================================================================
# CARGADOR DE MALLAS WAVEFRONT OBJ DE ALTO RENDIMIENTO
# =========================================================================

## Carga un archivo OBJ nativo y construye un ArrayMesh en memoria
static func load_obj_mesh(filename: String, target_obj: String = "", max_faces: int = -1, vertex_offset: Vector3 = Vector3.ZERO, mirror_x: bool = false, face_start: int = 0) -> ArrayMesh:
	var cache_key := "%s|%s|%d|%s|%s|%d" % [filename, target_obj, max_faces, str(vertex_offset), str(mirror_x), face_start]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var gpath := ProjectSettings.globalize_path(OBJ_DIR + filename)
	if not FileAccess.file_exists(gpath):
		printerr("[FurniturePropsBuilder] No se encontró el archivo OBJ: ", gpath)
		return null

	var file := FileAccess.open(gpath, FileAccess.READ)
	if file == null:
		printerr("[FurniturePropsBuilder] Error al abrir el archivo OBJ: ", gpath)
		return null

	var vs: Array[Vector3] = []
	var vts: Array[Vector2] = []
	var vns: Array[Vector3] = []

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var current_o := "default"
	var faces_processed := 0
	var triangles_added := 0

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		var parts := line.split(" ", false)
		if parts.is_empty():
			continue

		var cmd := parts[0]
		if cmd == "v" and parts.size() >= 4:
			var vx := parts[1].to_float()
			var vy := parts[2].to_float()
			var vz := parts[3].to_float()
			if mirror_x:
				vx = -vx
			vs.append(Vector3(vx, vy, vz) + vertex_offset)
		elif cmd == "vt" and parts.size() >= 3:
			vts.append(Vector2(parts[1].to_float(), 1.0 - parts[2].to_float()))
		elif cmd == "vn" and parts.size() >= 4:
			var nx := parts[1].to_float()
			var ny := parts[2].to_float()
			var nz := parts[3].to_float()
			if mirror_x:
				nx = -nx
			vns.append(Vector3(nx, ny, nz))
		elif cmd == "o" and parts.size() >= 2:
			current_o = parts[1]
		elif cmd == "f" and parts.size() >= 4:
			if target_obj != "" and current_o != target_obj:
				continue
			if faces_processed < face_start:
				faces_processed += 1
				continue
			if max_faces > 0 and (faces_processed - face_start) >= max_faces:
				break

			faces_processed += 1
			var face_verts: Array[Dictionary] = []
			for i in range(1, parts.size()):
				var token := parts[i]
				var indices := token.split("/")
				var vi := indices[0].to_int() - 1
				var vti := -1
				var vni := -1
				if indices.size() > 1 and not indices[1].is_empty():
					vti = indices[1].to_int() - 1
				if indices.size() > 2 and not indices[2].is_empty():
					vni = indices[2].to_int() - 1
				face_verts.append({"v": vi, "vt": vti, "vn": vni})

			var n_verts := face_verts.size()
			if n_verts >= 3:
				for i in range(1, n_verts - 1):
					if mirror_x:
						_add_triangle(st, vs, vts, vns, face_verts[0], face_verts[i], face_verts[i + 1])
					else:
						_add_triangle(st, vs, vts, vns, face_verts[0], face_verts[i + 1], face_verts[i])
					triangles_added += 1

	file.close()

	if triangles_added == 0:
		return null

	st.generate_tangents()
	var mesh := st.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


static func _add_triangle(st: SurfaceTool, vs: Array[Vector3], vts: Array[Vector2], vns: Array[Vector3], v0: Dictionary, v1: Dictionary, v2: Dictionary) -> void:
	for fv in [v0, v1, v2]:
		if fv.vn >= 0 and fv.vn < vns.size():
			st.set_normal(vns[fv.vn])
		if fv.vt >= 0 and fv.vt < vts.size():
			st.set_uv(vts[fv.vt])
		if fv.v >= 0 and fv.v < vs.size():
			st.add_vertex(vs[fv.v])


# =========================================================================
# ACCESORIOS Y CONSUMIBLES (100% TEXTURA EXACTA DEL ATLAS)
# =========================================================================

## Cartón de Leche (30 tris) - Blanco con franja azul "MILK"
static func get_milk_mesh() -> ArrayMesh:
	return load_obj_mesh("milk.obj")


## Caja de Cereal Corn Flakes (12 tris) - Amarillo con texto rojo frontal
static func get_cereal_mesh() -> ArrayMesh:
	return load_obj_mesh("cereal_corn.obj")


## Lata de Sopa (72 tris) - Campbell roja y blanca
static func get_soup_can_mesh() -> ArrayMesh:
	return load_obj_mesh("can_soup.obj")


## Lata de Cerveza Lager (72 tris) - Plateada y azul
static func get_beer_can_mesh() -> ArrayMesh:
	return load_obj_mesh("beer_can.obj")


## Taza de Café (44 tris) - Blanca de cerámica con asa
static func get_mug_mesh() -> ArrayMesh:
	return load_obj_mesh("mug.obj")


## Plato de Cerámica (96 tris) - Cerámica blanca
static func get_plate_mesh() -> ArrayMesh:
	return load_obj_mesh("plate.obj")


## Periódico Daily News (12 tris) - Doblado
static func get_newspaper_mesh() -> ArrayMesh:
	return load_obj_mesh("newspaper.obj")


## Pila de Libros (48 tris) - 3 libros apilados
static func get_book_stack_mesh() -> ArrayMesh:
	return load_obj_mesh("book_stack.obj")


## Tapete Trenzado Circular (60 tris) - Anillos concéntricos (Retrocompatibilidad)
static func get_rug_braided_mesh(_radius: float = 0.85) -> ArrayMesh:
	return get_rug_rectangular_mesh()


## Alfombra Rectangular Plana (2 tris) con relación de aspecto natural 1.46 (W=1.75m, L=1.20m)
static func get_rug_rectangular_mesh(width: float = 1.75, length: float = 1.20) -> ArrayMesh:
	var cache_key := "rug_rectangular|%.2f|%.2f" % [width, length]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := width * 0.5
	var hz := length * 0.5
	var y := 0.005 # 5mm sobre el piso

	# Plano rectangular 2D horizontal superior con normales hacia arriba (+Y)
	var v0 := Vector3(-hx, y, -hz)
	var v1 := Vector3( hx, y, -hz)
	var v2 := Vector3( hx, y,  hz)
	var v3 := Vector3(-hx, y,  hz)

	var norm := Vector3.UP

	# Triángulo 1: v0 -> v3 -> v2
	st.set_normal(norm); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v3)
	st.set_normal(norm); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v2)

	# Triángulo 2: v0 -> v2 -> v1
	st.set_normal(norm); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v2)
	st.set_normal(norm); st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v1)

	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[cache_key] = m
	return m


## Malla de Plano Unitario Horizontal 1x1m para Suelo (2 tris, Normal +Y)
static func get_unit_floor_quad_mesh() -> ArrayMesh:
	return get_rug_rectangular_mesh(1.0, 1.0)


## Malla de Plano Unitario Vertical 1x1m para Muros (2 tris, Normal +Z hacia el observador)
static func get_unit_wall_quad_mesh() -> ArrayMesh:
	var cache_key := "unit_wall_quad_1x1"
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := 0.5
	var hy := 0.5
	var z := 0.005 # 5mm sobre el muro

	var v0 := Vector3(-hx, -hy, z)
	var v1 := Vector3( hx, -hy, z)
	var v2 := Vector3( hx,  hy, z)
	var v3 := Vector3(-hx,  hy, z)

	var norm := Vector3.BACK # +Z hacia el observador

	st.set_normal(norm); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v1)
	st.set_normal(norm); st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)

	st.set_normal(norm); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
	st.set_normal(norm); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v3)

	st.generate_tangents()
	var m := st.commit()
	_mesh_cache[cache_key] = m
	return m


## Cuadro de Paisaje (50 tris) - Marco de madera con pintura de colinas
static func get_picture_landscape_mesh(_w: float = 0.70, _h: float = 0.50, _d: float = 0.03) -> ArrayMesh:
	return load_obj_mesh("picture_landscape.obj")


## Mesa de Centro de Roble (88 tris)
static func get_coffee_table_mesh() -> ArrayMesh:
	return load_obj_mesh("coffee_table_oak.obj")


## Libro modular individual con portada auténtica (Bible, Atlas, Recipes, Novel)
static func get_book_mesh(book_type: String = "bible") -> ArrayMesh:
	var cache_key := "modular_book_" + book_type
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var sz := Vector3(0.045, 0.24, 0.18)
	var hw := sz.x * 0.5
	var hh := sz.y
	var hd := sz.z * 0.5

	# UVs exactas de portadas en el atlas (verificadas con book_stack.obj)
	var uv_cover_min: Vector2
	var uv_cover_max: Vector2
	match book_type:
		"bible":
			uv_cover_min = Vector2(0.2505, 0.1255); uv_cover_max = Vector2(0.2808, 0.1714)
		"atlas":
			uv_cover_min = Vector2(0.2817, 0.1255); uv_cover_max = Vector2(0.3120, 0.1714)
		"recipes":
			uv_cover_min = Vector2(0.3130, 0.1255); uv_cover_max = Vector2(0.3433, 0.1714)
		"novel", _:
			uv_cover_min = Vector2(0.3442, 0.1255); uv_cover_max = Vector2(0.3745, 0.1714)

	# Lomo y páginas
	var uv_spine_min := Vector2(0.3755, 0.1255)
	var uv_spine_max := Vector2(0.3901, 0.1714)
	var uv_pages_min := Vector2(0.6567, 0.1880)
	var uv_pages_max := Vector2(0.6714, 0.2026)

	# Vértices del libro en posición vertical sobre la repisa
	var v_front_bottom_left  := Vector3(-hw, 0.0,  hd) # frente lomo abajo izq
	var v_front_bottom_right := Vector3( hw, 0.0,  hd) # frente lomo abajo der
	var v_front_top_right    := Vector3( hw,  hh,  hd) # frente lomo arriba der
	var v_front_top_left     := Vector3(-hw,  hh,  hd) # frente lomo arriba izq

	var v_back_bottom_left   := Vector3(-hw, 0.0, -hd) # fondo páginas abajo izq
	var v_back_bottom_right  := Vector3( hw, 0.0, -hd) # fondo páginas abajo der
	var v_back_top_right     := Vector3( hw,  hh, -hd) # fondo páginas arriba der
	var v_back_top_left      := Vector3(-hw,  hh, -hd) # fondo páginas arriba izq

	# 1. Lomo frontal (+Z, mira hacia el jugador en la estantería)
	_add_quad_st(st, v_front_bottom_left, v_front_bottom_right, v_front_top_right, v_front_top_left, Vector3.FORWARD, uv_spine_min, uv_spine_max)
	# 2. Portada lateral (+X)
	_add_quad_st(st, v_front_bottom_right, v_back_bottom_right, v_back_top_right, v_front_top_right, Vector3.RIGHT, uv_cover_min, uv_cover_max)
	# 3. Contraportada lateral (-X)
	_add_quad_st(st, v_back_bottom_left, v_front_bottom_left, v_front_top_left, v_back_top_left, Vector3.LEFT, uv_cover_min, uv_cover_max)
	# 4. Páginas posteriores (-Z, hacia el fondo del mueble)
	_add_quad_st(st, v_back_bottom_right, v_back_bottom_left, v_back_top_left, v_back_top_right, Vector3.BACK, uv_pages_min, uv_pages_max)
	# 5. Páginas superiores (+Y)
	_add_quad_st(st, v_front_top_left, v_front_top_right, v_back_top_right, v_back_top_left, Vector3.UP, uv_pages_min, uv_pages_max)
	# 6. Páginas inferiores (-Y)
	_add_quad_st(st, v_back_bottom_left, v_back_bottom_right, v_front_bottom_right, v_front_bottom_left, Vector3.DOWN, uv_pages_min, uv_pages_max)

	st.generate_tangents()
	var mesh := st.commit()
	_mesh_cache[cache_key] = mesh
	return mesh


static func _add_quad_st(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, norm: Vector3, uv_min: Vector2, uv_max: Vector2) -> void:
	var u0 := Vector2(uv_min.x, uv_max.y)
	var u1 := Vector2(uv_max.x, uv_max.y)
	var u2 := Vector2(uv_max.x, uv_min.y)
	var u3 := Vector2(uv_min.x, uv_min.y)

	# Triángulo 1: (v0, v2, v1) con orientación hacia el exterior
	st.set_normal(norm); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(u2); st.add_vertex(v2)
	st.set_normal(norm); st.set_uv(u1); st.add_vertex(v1)

	# Triángulo 2: (v0, v3, v2) con orientación hacia el exterior
	st.set_normal(norm); st.set_uv(u0); st.add_vertex(v0)
	st.set_normal(norm); st.set_uv(u3); st.add_vertex(v3)
	st.set_normal(norm); st.set_uv(u2); st.add_vertex(v2)


# =========================================================================
# MALLAS DE MOBILIARIO PRINCIPAL (100% TEXTURA EXACTA DEL ATLAS)
# =========================================================================

## Cama Individual de Roble Completa Clásica (208 tris) - Retrocompatibilidad
static func get_bed_mesh() -> ArrayMesh:
	return load_obj_mesh("bed_single_oak.obj")


## Armazón de Cama de Roble (120 tris / 60 caras) - Solo madera: cabecero, piecero, largueros y patas
static func get_bed_frame_mesh() -> ArrayMesh:
	return load_obj_mesh("bed_single_oak.obj", "", 60, Vector3.ZERO, false, 0)


## Helper para calcular coordenadas UV normalizadas en la cuadrícula 8x8 de ropa de cama
static func get_bed_cell_uv(c: int, r: int, u: float, v: float) -> Vector2:
	var u_min := float(c) / 8.0
	var u_max := float(c + 1) / 8.0
	var v_min := float(r) / 8.0
	var v_max := float(r + 1) / 8.0
	return Vector2(lerpf(u_min, u_max, clampf(u, 0.0, 1.0)), lerpf(v_min, v_max, clampf(v, 0.0, 1.0)))


## Malla del Colchón con Sábana Bajera (16 patrones de sábanas) o Colchón Desnudo (is_bare = true)
static func get_bed_mattress_mesh(sheet_id: int = 0, is_bare: bool = false, dirt_pct: float = 0.0) -> ArrayMesh:
	var cache_key := "bed_mattress|%d|%s|%.2f" % [sheet_id, str(is_bare), dirt_pct]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c := 0
	var r := 5 # Fila 5, Col 0: Colchón vintage rayado
	if not is_bare:
		var sid := clampi(sheet_id, 0, 15)
		c = sid % 8
		r = sid / 8

	var tint := Color.WHITE.lerp(Color(0.68, 0.62, 0.48, 1.0), clampf(dirt_pct, 0.0, 1.0))
	st.set_color(tint)

	var x0 := -0.465; var x1 := 0.465
	var y0 := 0.380; var y1 := 0.585
	var z0 := -0.970; var z1 := 0.970

	# Cara superior subdividida en 4 segmentos en Z para textura perfectamente ortogonal sin distorsión
	var z_segments := 4
	for s in range(z_segments):
		var sz0 := lerpf(z0, z1, float(s) / float(z_segments))
		var sz1 := lerpf(z0, z1, float(s + 1) / float(z_segments))
		var sv0 := float(s) / float(z_segments)
		var sv1 := float(s + 1) / float(z_segments)

		_add_quad_st_direct(st, Vector3.UP,
			Vector3(x0, y1, sz0), get_bed_cell_uv(c, r, 0.0, sv0),
			Vector3(x0, y1, sz1), get_bed_cell_uv(c, r, 0.0, sv1),
			Vector3(x1, y1, sz1), get_bed_cell_uv(c, r, 1.0, sv1),
			Vector3(x1, y1, sz0), get_bed_cell_uv(c, r, 1.0, sv0))

	# Lateral izquierdo (-X)
	_add_quad_st_direct(st, Vector3.LEFT,
		Vector3(x0, y1, z1), get_bed_cell_uv(c, r, 0.0, 0.1),
		Vector3(x0, y0, z1), get_bed_cell_uv(c, r, 0.0, 0.3),
		Vector3(x0, y0, z0), get_bed_cell_uv(c, r, 1.0, 0.3),
		Vector3(x0, y1, z0), get_bed_cell_uv(c, r, 1.0, 0.1))

	# Lateral derecho (+X)
	_add_quad_st_direct(st, Vector3.RIGHT,
		Vector3(x1, y1, z0), get_bed_cell_uv(c, r, 0.0, 0.1),
		Vector3(x1, y0, z0), get_bed_cell_uv(c, r, 0.0, 0.3),
		Vector3(x1, y0, z1), get_bed_cell_uv(c, r, 1.0, 0.3),
		Vector3(x1, y1, z1), get_bed_cell_uv(c, r, 1.0, 0.1))

	# Piecero (+Z)
	_add_quad_st_direct(st, Vector3(0, 0, 1),
		Vector3(x0, y1, z1), get_bed_cell_uv(c, r, 0.0, 0.1),
		Vector3(x1, y1, z1), get_bed_cell_uv(c, r, 1.0, 0.1),
		Vector3(x1, y0, z1), get_bed_cell_uv(c, r, 1.0, 0.3),
		Vector3(x0, y0, z1), get_bed_cell_uv(c, r, 0.0, 0.3))

	# Cabecero (-Z)
	_add_quad_st_direct(st, Vector3(0, 0, -1),
		Vector3(x1, y1, z0), get_bed_cell_uv(c, r, 0.0, 0.1),
		Vector3(x0, y1, z0), get_bed_cell_uv(c, r, 1.0, 0.1),
		Vector3(x0, y0, z0), get_bed_cell_uv(c, r, 1.0, 0.3),
		Vector3(x1, y0, z0), get_bed_cell_uv(c, r, 0.0, 0.3))

	var m := st.commit()
	_mesh_cache[cache_key] = m
	return m


## Malla de Cobija Tendida (MADE) con caídas laterales y doblez hacia la almohada (24 patrones)
static func get_bed_quilt_made_mesh(blanket_id: int = 12, dirt_pct: float = 0.0) -> ArrayMesh:
	var cache_key := "bed_quilt_made|%d|%.2f" % [blanket_id, dirt_pct]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var bid := clampi(blanket_id, 0, 23)
	var c := bid % 8
	var r := 2 + (bid / 8)

	var tint := Color.WHITE.lerp(Color(0.68, 0.62, 0.48, 1.0), clampf(dirt_pct, 0.0, 1.0))
	st.set_color(tint)

	var x0 := -0.475; var x1 := 0.475
	var z0 := -0.320; var z1 := 0.990
	var y_top := 0.595
	var y_drop := 0.440
	var drop_x0 := -0.490; var drop_x1 := 0.490
	var drop_z1 := 1.005

	# Superficie superior
	_add_quad_st_direct(st, Vector3.UP,
		Vector3(x0, y_top, z0), get_bed_cell_uv(c, r, 0.0, 0.0),
		Vector3(x0, y_top, z1), get_bed_cell_uv(c, r, 0.0, 1.0),
		Vector3(x1, y_top, z1), get_bed_cell_uv(c, r, 1.0, 1.0),
		Vector3(x1, y_top, z0), get_bed_cell_uv(c, r, 1.0, 0.0))

	# Caída lateral izquierda (-X)
	_add_quad_st_direct(st, Vector3.LEFT,
		Vector3(x0, y_top, z1), get_bed_cell_uv(c, r, 0.0, 1.0),
		Vector3(drop_x0, y_drop, z1), get_bed_cell_uv(c, r, 0.05, 1.0),
		Vector3(drop_x0, y_drop, z0), get_bed_cell_uv(c, r, 0.05, 0.0),
		Vector3(x0, y_top, z0), get_bed_cell_uv(c, r, 0.0, 0.0))

	# Caída lateral derecha (+X)
	_add_quad_st_direct(st, Vector3.RIGHT,
		Vector3(x1, y_top, z0), get_bed_cell_uv(c, r, 1.0, 0.0),
		Vector3(drop_x1, y_drop, z0), get_bed_cell_uv(c, r, 0.95, 0.0),
		Vector3(drop_x1, y_drop, z1), get_bed_cell_uv(c, r, 0.95, 1.0),
		Vector3(x1, y_top, z1), get_bed_cell_uv(c, r, 1.0, 1.0))

	# Caída piecero (+Z)
	_add_quad_st_direct(st, Vector3(0, 0, 1),
		Vector3(x0, y_top, z1), get_bed_cell_uv(c, r, 0.0, 1.0),
		Vector3(x1, y_top, z1), get_bed_cell_uv(c, r, 1.0, 1.0),
		Vector3(drop_x1, y_drop, drop_z1), get_bed_cell_uv(c, r, 1.0, 0.95),
		Vector3(drop_x0, y_drop, drop_z1), get_bed_cell_uv(c, r, 0.0, 0.95))

	# Doblez cabecero
	_add_quad_st_direct(st, Vector3(0, 0, -1),
		Vector3(x1, y_top, z0), get_bed_cell_uv(c, r, 1.0, 0.0),
		Vector3(x0, y_top, z0), get_bed_cell_uv(c, r, 0.0, 0.0),
		Vector3(x0, y_top - 0.02, z0 - 0.02), get_bed_cell_uv(c, r, 0.0, 0.05),
		Vector3(x1, y_top - 0.02, z0 - 0.02), get_bed_cell_uv(c, r, 1.0, 0.05))

	var m := st.commit()
	_mesh_cache[cache_key] = m
	return m


## Malla de Cobija Destendida (UNMADE) arrugada asimétricamente hacia los pies (24 patrones)
static func get_bed_quilt_unmade_mesh(blanket_id: int = 12, dirt_pct: float = 0.0) -> ArrayMesh:
	var cache_key := "bed_quilt_unmade|%d|%.2f" % [blanket_id, dirt_pct]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var bid := clampi(blanket_id, 0, 23)
	var c := bid % 8
	var r := 2 + (bid / 8)

	var tint := Color.WHITE.lerp(Color(0.68, 0.62, 0.48, 1.0), clampf(dirt_pct, 0.0, 1.0))
	st.set_color(tint)

	var p_points := [
		[Vector3(-0.46, 0.60, 0.35), Vector3(-0.15, 0.65, 0.22), Vector3(0.18, 0.62, 0.15), Vector3(0.48, 0.59, 0.28)],
		[Vector3(-0.48, 0.63, 0.58), Vector3(-0.18, 0.67, 0.48), Vector3(0.15, 0.64, 0.42), Vector3(0.49, 0.61, 0.52)],
		[Vector3(-0.47, 0.61, 0.82), Vector3(-0.16, 0.64, 0.76), Vector3(0.16, 0.62, 0.72), Vector3(0.48, 0.60, 0.80)],
		[Vector3(-0.46, 0.59, 1.00), Vector3(-0.15, 0.61, 1.00), Vector3(0.16, 0.60, 1.00), Vector3(0.47, 0.59, 1.00)],
		[Vector3(-0.48, 0.46, 1.02), Vector3(-0.15, 0.46, 1.02), Vector3(0.16, 0.46, 1.02), Vector3(0.49, 0.46, 1.02)]
	]

	for i in range(p_points.size() - 1):
		var row_a: Array = p_points[i]
		var row_b: Array = p_points[i + 1]
		var v_ratio_a := float(i) / float(p_points.size() - 1)
		var v_ratio_b := float(i + 1) / float(p_points.size() - 1)

		for j in range(row_a.size() - 1):
			var u_ratio_a := float(j) / float(row_a.size() - 1)
			var u_ratio_b := float(j + 1) / float(row_a.size() - 1)

			var v0: Vector3 = row_a[j]
			var v1: Vector3 = row_b[j]
			var v2: Vector3 = row_b[j + 1]
			var v3: Vector3 = row_a[j + 1]

			var uv0 := get_bed_cell_uv(c, r, u_ratio_a, v_ratio_a)
			var uv1 := get_bed_cell_uv(c, r, u_ratio_a, v_ratio_b)
			var uv2 := get_bed_cell_uv(c, r, u_ratio_b, v_ratio_b)
			var uv3 := get_bed_cell_uv(c, r, u_ratio_b, v_ratio_a)

			var n0 := (v1 - v0).cross(v3 - v0).normalized()
			if n0.length_squared() < 0.001: n0 = Vector3.UP

			_add_quad_st_direct(st, n0, v0, uv0, v1, uv1, v2, uv2, v3, uv3)

	# Caída lateral arrugada izquierda
	_add_quad_st_direct(st, Vector3.LEFT,
		Vector3(-0.46, 0.60, 0.35), get_bed_cell_uv(c, r, 0.0, 0.2),
		Vector3(-0.49, 0.45, 0.40), get_bed_cell_uv(c, r, 0.05, 0.25),
		Vector3(-0.49, 0.45, 0.95), get_bed_cell_uv(c, r, 0.05, 0.90),
		Vector3(-0.46, 0.59, 1.00), get_bed_cell_uv(c, r, 0.0, 0.95))

	var m := st.commit()
	_mesh_cache[cache_key] = m
	return m


## Malla de Almohada Suave (con inclinación de 14° y desacomodo si is_unmade = true)
static func get_bed_pillow_mesh(is_unmade: bool = false, dirt_pct: float = 0.0) -> ArrayMesh:
	var cache_key := "bed_pillow|%s|%.2f" % [str(is_unmade), dirt_pct]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c := 2; var r := 5 # Fila 5, Col 2: Almohada suave blanca

	var tint := Color.WHITE.lerp(Color(0.68, 0.62, 0.48, 1.0), clampf(dirt_pct, 0.0, 1.0))
	st.set_color(tint)

	var rot_y := 0.0
	var offset_pos := Vector3(0.0, 0.0, -0.72)
	if is_unmade:
		rot_y = deg_to_rad(14.0)
		offset_pos = Vector3(0.04, 0.0, -0.70)

	var basis := Basis(Vector3.UP, rot_y)

	var hw := 0.28; var hd := 0.16
	var y_base := 0.588; var y_mid := 0.625; var y_apex := 0.670

	var grid_pts := [
		[Vector3(-hw, y_base, -hd), Vector3(0.0, y_mid, -hd), Vector3(hw, y_base, -hd)],
		[Vector3(-hw, y_mid, 0.0),  Vector3(0.0, y_apex, 0.0), Vector3(hw, y_mid, 0.0)],
		[Vector3(-hw, y_base, hd),  Vector3(0.0, y_mid, hd),  Vector3(hw, y_base, hd)]
	]

	for i in range(2):
		for j in range(2):
			var v0: Vector3 = basis * grid_pts[i][j] + offset_pos
			var v1: Vector3 = basis * grid_pts[i + 1][j] + offset_pos
			var v2: Vector3 = basis * grid_pts[i + 1][j + 1] + offset_pos
			var v3: Vector3 = basis * grid_pts[i][j + 1] + offset_pos

			var u0 := float(j) * 0.5; var u1 := float(j + 1) * 0.5
			var v_u0 := float(i) * 0.5; var v_u1 := float(i + 1) * 0.5

			var uv0 := get_bed_cell_uv(c, r, u0, v_u0)
			var uv1 := get_bed_cell_uv(c, r, u0, v_u1)
			var uv2 := get_bed_cell_uv(c, r, u1, v_u1)
			var uv3 := get_bed_cell_uv(c, r, u1, v_u0)

			var n := (v1 - v0).cross(v3 - v0).normalized()
			if n.length_squared() < 0.001: n = Vector3.UP
			_add_quad_st_direct(st, n, v0, uv0, v1, uv1, v2, uv2, v3, uv3)

	var b_tl := basis * Vector3(-hw, y_base, -hd) + offset_pos
	var b_tr := basis * Vector3(hw, y_base, -hd) + offset_pos
	var b_br := basis * Vector3(hw, y_base, hd) + offset_pos
	var b_bl := basis * Vector3(-hw, y_base, hd) + offset_pos
	_add_quad_st_direct(st, Vector3.DOWN,
		b_tl, get_bed_cell_uv(c, r, 0.0, 0.0),
		b_tr, get_bed_cell_uv(c, r, 1.0, 0.0),
		b_br, get_bed_cell_uv(c, r, 1.0, 1.0),
		b_bl, get_bed_cell_uv(c, r, 0.0, 1.0))

	var m := st.commit()
	_mesh_cache[cache_key] = m
	return m


## Helper de adición directa de quad con orden hacia el exterior
static func _add_quad_st_direct(st: SurfaceTool, n: Vector3, v0: Vector3, uv0: Vector2, v1: Vector3, uv1: Vector2, v2: Vector3, uv2: Vector2, v3: Vector3, uv3: Vector2) -> void:
	st.set_normal(n); st.set_uv(uv0); st.add_vertex(v0)
	st.set_normal(n); st.set_uv(uv1); st.add_vertex(v1)
	st.set_normal(n); st.set_uv(uv2); st.add_vertex(v2)

	st.set_normal(n); st.set_uv(uv0); st.add_vertex(v0)
	st.set_normal(n); st.set_uv(uv2); st.add_vertex(v2)
	st.set_normal(n); st.set_uv(uv3); st.add_vertex(v3)


## Malla combinada unificada con 2 superficies (Surface 0: Madera, Surface 1: Ropa de cama)
static func get_bed_custom_mesh(state: int = 0, sheet_id: int = 0, blanket_id: int = 12, has_pillow: bool = true, dirt_pct: float = 0.0) -> ArrayMesh:
	var cache_key := "bed_custom|%d|%d|%d|%s|%.2f" % [state, sheet_id, blanket_id, str(has_pillow), dirt_pct]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var combined := ArrayMesh.new()

	# Superficie 0: Armazón de madera (props_material)
	var frame_m := get_bed_frame_mesh()
	if frame_m and frame_m.get_surface_count() > 0:
		var arrays := frame_m.surface_get_arrays(0)
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		combined.surface_set_material(0, get_props_material(0.65, 0.02))

	# Superficie 1: Ropa de cama (colchón + cobija + almohada) con linens_material
	var st_linens := SurfaceTool.new()
	st_linens.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Colchón
	var is_bare: bool = (state == 3) # BARE_MATTRESS
	var mat_m := get_bed_mattress_mesh(sheet_id, is_bare, dirt_pct)
	if mat_m and mat_m.get_surface_count() > 0:
		st_linens.append_from(mat_m, 0, Transform3D.IDENTITY)

	# 2. Cobija
	if state == 0: # MADE
		var q_m := get_bed_quilt_made_mesh(blanket_id, dirt_pct)
		if q_m and q_m.get_surface_count() > 0:
			st_linens.append_from(q_m, 0, Transform3D.IDENTITY)
	elif state == 1: # UNMADE
		var q_m := get_bed_quilt_unmade_mesh(blanket_id, dirt_pct)
		if q_m and q_m.get_surface_count() > 0:
			st_linens.append_from(q_m, 0, Transform3D.IDENTITY)

	# 3. Almohada
	if has_pillow:
		var p_m := get_bed_pillow_mesh(state == 1, dirt_pct)
		if p_m and p_m.get_surface_count() > 0:
			st_linens.append_from(p_m, 0, Transform3D.IDENTITY)

	var linens_mesh := st_linens.commit()
	if linens_mesh and linens_mesh.get_surface_count() > 0:
		var l_arrays := linens_mesh.surface_get_arrays(0)
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, l_arrays)
		combined.surface_set_material(1, get_linens_material(0.75, 0.01))

	_mesh_cache[cache_key] = combined
	return combined


## Armazón de Mesa de Noche (160 tris)
static func get_nightstand_frame_mesh() -> ArrayMesh:
	return load_obj_mesh("nightstand_oak.obj", "nightstand_oak")


## Cajón Deslizante de Mesa de Noche (72 tris)
static func get_nightstand_drawer_mesh() -> ArrayMesh:
	return load_obj_mesh("nightstand_oak.obj", "nightstand_oak_drawer")


## Mesa de Noche Completa Unificada (232 tris)
static func get_nightstand_complete_mesh() -> ArrayMesh:
	return load_obj_mesh("nightstand_oak.obj")


## Armario de Roble - Armazón Interior con Barra y Repisa (192 tris)
static func get_wardrobe_body_mesh() -> ArrayMesh:
	return load_obj_mesh("wardrobe_oak.obj", "wardrobe_oak")


## Armario de Roble - Puerta Izquierda Persiana con Bisagra en el Borde (12 tris)
static func get_wardrobe_door_left_mesh() -> ArrayMesh:
	return load_obj_mesh("wardrobe_oak.obj", "wardrobe_oak_door_l", -1, Vector3(0.495, 0.0, -0.300))


## Armario de Roble - Puerta Derecha Persiana con Bisagra en el Borde (12 tris)
static func get_wardrobe_door_right_mesh() -> ArrayMesh:
	return load_obj_mesh("wardrobe_oak.obj", "wardrobe_oak_door_r", -1, Vector3(-0.495, 0.0, -0.300))


## Armario de Roble Completo Unificado (216 tris)
static func get_wardrobe_complete_mesh() -> ArrayMesh:
	return load_obj_mesh("wardrobe_oak.obj")


## Librero Alto Vacío sin libros (120 tris / 60 caras)
static func get_bookcase_empty_mesh() -> ArrayMesh:
	return load_obj_mesh("bookcase_tall.obj", "", 60)


## Librero Alto con Libros Pre-renderizados (204 tris)
static func get_bookcase_complete_mesh() -> ArrayMesh:
	return load_obj_mesh("bookcase_tall.obj")


## Fregadero Blanco - Armazón con Encimera, Cubeta Inox y Grifería (SIN PUERTAS, 135 caras)
static func get_sink_cabinet_mesh() -> ArrayMesh:
	return load_obj_mesh("sink_unit_white.obj", "sink_unit_white", 135)


## Fregadero Blanco - Puerta Izquierda con Bisagra en el Borde Izquierdo (12 tris)
static func get_sink_door_left_mesh() -> ArrayMesh:
	return load_obj_mesh("sink_unit_white.obj", "sink_unit_white_door", -1, Vector3(0.490, 0.0, -0.300))


## Fregadero Blanco - Puerta Derecha Original con Bisagra en el Borde Derecho (12 tris)
static func get_sink_door_right_mesh() -> ArrayMesh:
	return load_obj_mesh("sink_unit_white.obj", "sink_unit_white", 6, Vector3(-0.490, 0.0, -0.300), false, 135)


## Fregadero Blanco - Puerta genérica (compatibilidad)
static func get_sink_door_mesh() -> ArrayMesh:
	return get_sink_door_left_mesh()


## Fregadero Blanco Completo con Ambas Puertas Cerradas (304 tris)
static func get_sink_complete_mesh() -> ArrayMesh:
	return load_obj_mesh("sink_unit_white.obj")
