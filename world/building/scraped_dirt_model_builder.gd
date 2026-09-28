extends RefCounted
class_name ScrapedDirtModelBuilder
## Generador procedural ultra-optimizado de trazado 3D de tierra rascada ("dirt scrape")
## con perfil volumétrico real (surco central excavado y montículos de tierra levantada),
## textura de suelo suministrada por el usuario, y 3 niveles de LOD nativos para GPU.

const DIRT_TEX_PATH := "res://assets/building/scraped_dirt_texture.png"
static var _dirt_mat: StandardMaterial3D = null

static func get_dirt_material() -> StandardMaterial3D:
	if _dirt_mat != null:
		return _dirt_mat

	_dirt_mat = StandardMaterial3D.new()
	var tex: Texture2D = null

	# 1. Carga normal vía ResourceLoader si ya fue importada por Godot
	if ResourceLoader.exists(DIRT_TEX_PATH):
		tex = load(DIRT_TEX_PATH) as Texture2D

	# 2. Respaldo a prueba de fallos vía Image (funciona incluso antes de reimportación)
	if tex == null:
		var global_p := ProjectSettings.globalize_path(DIRT_TEX_PATH)
		if FileAccess.file_exists(global_p):
			var img := Image.load_from_file(global_p)
			if img and not img.is_empty():
				tex = ImageTexture.create_from_image(img)

	if tex:
		_dirt_mat.albedo_texture = tex
		_dirt_mat.albedo_color = Color(0.92, 0.88, 0.84)
	else:
		_dirt_mat.albedo_color = Color(0.25, 0.17, 0.11)

	_dirt_mat.roughness = 0.96
	_dirt_mat.metallic = 0.0
	_dirt_mat.metallic_specular = 0.15
	_dirt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dirt_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return _dirt_mat

## Construye un Node3D con las mallas LOD0, LOD1 y LOD2 configuradas con visibility_range
static func create_lod_scraped_perimeter(points: Array[Vector3]) -> Node3D:
	var container := Node3D.new()
	container.name = "ScrapedEarth3D_LOD"

	if points.size() < 2:
		return container

	var mat := get_dirt_material()

	# LOD 0: 0m - 16m (Perfil 3D detallado con surco, doble cresta y montículos)
	var lod0_mesh := build_lod0_mesh(points, mat)
	var inst0 := MeshInstance3D.new()
	inst0.name = "LOD0_Detailed"
	inst0.mesh = lod0_mesh
	inst0.visibility_range_begin = 0.0
	inst0.visibility_range_end = 16.0
	inst0.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	container.add_child(inst0)

	# LOD 1: 16m - 42m (Perfil 3D simplificado de 3 vértices transversales)
	var lod1_mesh := build_lod1_mesh(points, mat)
	var inst1 := MeshInstance3D.new()
	inst1.name = "LOD1_Medium"
	inst1.mesh = lod1_mesh
	inst1.visibility_range_begin = 16.0
	inst1.visibility_range_end = 42.0
	inst1.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	container.add_child(inst1)

	# LOD 2: 42m - 90m (Banda plana ribbon ultra-económica, 2 tris por orilla)
	var lod2_mesh := build_lod2_mesh(points, mat)
	var inst2 := MeshInstance3D.new()
	inst2.name = "LOD2_Ribbon"
	inst2.mesh = lod2_mesh
	inst2.visibility_range_begin = 42.0
	inst2.visibility_range_end = 90.0
	inst2.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	container.add_child(inst2)

	return container

## Obtiene esquinas únicas de un array de puntos
static func get_unique_corners(pts: Array[Vector3]) -> Array[Vector3]:
	var unique: Array[Vector3] = []
	for p in pts:
		var dup := false
		for u in unique:
			if u.distance_squared_to(p) < 0.01:
				dup = true
				break
		if not dup:
			unique.append(p)
	return unique

# ==============================================================================
# LOD 0: PERFIL 3D VOLUMÉTRICO COMPLETO (~180 TRIÁNGULOS TOTALES)
# ==============================================================================
static func build_lod0_mesh(points: Array[Vector3], mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	# Perfil transversal: [offset_x, height_y, uv_v]
	# 5 puntos que crean el surco central excavado y las dos crestas laterales
	var profile: Array[Vector3] = [
		Vector3(-0.16, 0.006, 0.00), # Pie exterior (ras de suelo)
		Vector3(-0.08, 0.045, 0.25), # Cresta exterior levantada
		Vector3(0.000, 0.012, 0.50), # Fondo del surco central rascado por el palo
		Vector3(0.08, 0.045, 0.75),  # Cresta interior levantada
		Vector3(0.16, 0.006, 1.00)   # Pie interior (ras de suelo)
	]

	# 1. Tramos perimetrales
	for i in range(points.size() - 1):
		var pA := points[i]
		var pB := points[i + 1]
		var dist := pA.distance_to(pB)
		if dist < 0.05:
			continue

		var dir := (pB - pA).normalized()
		var norm := Vector3(dir.z, 0, -dir.x).normalized()

		var num_segs := maxi(1, int(roundf(dist / 0.5)))
		var u_tiling := dist / 0.65

		for s in range(num_segs):
			var t0 := float(s) / float(num_segs)
			var t1 := float(s + 1) / float(num_segs)
			var u0 := t0 * u_tiling
			var u1 := t1 * u_tiling

			var pos0 := pA.lerp(pB, t0)
			var pos1 := pA.lerp(pB, t1)

			for k in range(profile.size() - 1):
				var p_k0 := profile[k]
				var p_k1 := profile[k + 1]

				var pt00 := pos0 + norm * p_k0.x + Vector3.UP * p_k0.y
				var pt01 := pos0 + norm * p_k1.x + Vector3.UP * p_k1.y
				var pt10 := pos1 + norm * p_k0.x + Vector3.UP * p_k0.y
				var pt11 := pos1 + norm * p_k1.x + Vector3.UP * p_k1.y

				# Triángulo 1 (Winding hacia arriba)
				st.set_uv(Vector2(u0, p_k0.z))
				st.add_vertex(pt00)
				st.set_uv(Vector2(u1, p_k1.z))
				st.add_vertex(pt11)
				st.set_uv(Vector2(u0, p_k1.z))
				st.add_vertex(pt01)

				# Triángulo 2 (Winding hacia arriba)
				st.set_uv(Vector2(u0, p_k0.z))
				st.add_vertex(pt00)
				st.set_uv(Vector2(u1, p_k0.z))
				st.add_vertex(pt10)
				st.set_uv(Vector2(u1, p_k1.z))
				st.add_vertex(pt11)

	# 2. Montículos de tierra en cada esquina ("montañita de tierra")
	var corners := get_unique_corners(points)
	var num_fan := 8
	var mound_radius := 0.28
	var mound_height := 0.065

	for c in corners:
		var apex := c + Vector3(0, mound_height, 0)
		for j in range(num_fan):
			var a0 := float(j) * TAU / float(num_fan)
			var a1 := float(j + 1) * TAU / float(num_fan)

			var r0 := c + Vector3(cos(a0) * mound_radius, 0.006, sin(a0) * mound_radius)
			var r1 := c + Vector3(cos(a1) * mound_radius, 0.006, sin(a1) * mound_radius)

			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(apex)
			st.set_uv(Vector2(0.5 + cos(a1) * 0.45, 0.5 + sin(a1) * 0.45))
			st.add_vertex(r1)
			st.set_uv(Vector2(0.5 + cos(a0) * 0.45, 0.5 + sin(a0) * 0.45))
			st.add_vertex(r0)

	st.generate_normals()
	return st.commit()

# ==============================================================================
# LOD 1: PERFIL 3D MEDIO SIMPLIFICADO (~50 TRIÁNGULOS TOTALES)
# ==============================================================================
static func build_lod1_mesh(points: Array[Vector3], mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	var profile: Array[Vector3] = [
		Vector3(-0.14, 0.006, 0.0),
		Vector3(0.000, 0.038, 0.5),
		Vector3(0.14, 0.006, 1.0)
	]

	for i in range(points.size() - 1):
		var pA := points[i]
		var pB := points[i + 1]
		var dist := pA.distance_to(pB)
		if dist < 0.05:
			continue

		var dir := (pB - pA).normalized()
		var norm := Vector3(dir.z, 0, -dir.x).normalized()
		var u_tiling := dist / 0.8

		var pt00 := pA + norm * profile[0].x + Vector3.UP * profile[0].y
		var pt01 := pA + norm * profile[1].x + Vector3.UP * profile[1].y
		var pt02 := pA + norm * profile[2].x + Vector3.UP * profile[2].y

		var pt10 := pB + norm * profile[0].x + Vector3.UP * profile[0].y
		var pt11 := pB + norm * profile[1].x + Vector3.UP * profile[1].y
		var pt12 := pB + norm * profile[2].x + Vector3.UP * profile[2].y

		# Franja 1
		st.set_uv(Vector2(0, 0.0))
		st.add_vertex(pt00)
		st.set_uv(Vector2(u_tiling, 0.5))
		st.add_vertex(pt11)
		st.set_uv(Vector2(0, 0.5))
		st.add_vertex(pt01)

		st.set_uv(Vector2(0, 0.0))
		st.add_vertex(pt00)
		st.set_uv(Vector2(u_tiling, 0.0))
		st.add_vertex(pt10)
		st.set_uv(Vector2(u_tiling, 0.5))
		st.add_vertex(pt11)

		# Franja 2
		st.set_uv(Vector2(0, 0.5))
		st.add_vertex(pt01)
		st.set_uv(Vector2(u_tiling, 1.0))
		st.add_vertex(pt12)
		st.set_uv(Vector2(0, 1.0))
		st.add_vertex(pt02)

		st.set_uv(Vector2(0, 0.5))
		st.add_vertex(pt01)
		st.set_uv(Vector2(u_tiling, 0.5))
		st.add_vertex(pt11)
		st.set_uv(Vector2(u_tiling, 1.0))
		st.add_vertex(pt12)

	# Montículos simplificados (pirámide de 4 lados)
	var corners := get_unique_corners(points)
	for c in corners:
		var apex := c + Vector3(0, 0.050, 0)
		for j in range(4):
			var a0 := float(j) * TAU / 4.0
			var a1 := float(j + 1) * TAU / 4.0
			var r0 := c + Vector3(cos(a0) * 0.22, 0.006, sin(a0) * 0.22)
			var r1 := c + Vector3(cos(a1) * 0.22, 0.006, sin(a1) * 0.22)

			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(apex)
			st.set_uv(Vector2(0.5 + cos(a1) * 0.45, 0.5 + sin(a1) * 0.45))
			st.add_vertex(r1)
			st.set_uv(Vector2(0.5 + cos(a0) * 0.45, 0.5 + sin(a0) * 0.45))
			st.add_vertex(r0)

	st.generate_normals()
	return st.commit()

# ==============================================================================
# LOD 2: BANDA PLANA RIBBON (EXACTAMENTE 2 TRIÁNGULOS POR ORILLA)
# ==============================================================================
static func build_lod2_mesh(points: Array[Vector3], mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)

	var half_w := 0.13
	var y_elev := 0.008

	for i in range(points.size() - 1):
		var pA := points[i]
		var pB := points[i + 1]
		var dist := pA.distance_to(pB)
		if dist < 0.05:
			continue

		var dir := (pB - pA).normalized()
		var norm := Vector3(dir.z, 0, -dir.x).normalized()
		var u_tiling := dist / 1.0

		var pt00 := pA - norm * half_w + Vector3.UP * y_elev
		var pt01 := pA + norm * half_w + Vector3.UP * y_elev
		var pt10 := pB - norm * half_w + Vector3.UP * y_elev
		var pt11 := pB + norm * half_w + Vector3.UP * y_elev

		st.set_uv(Vector2(0, 0.0))
		st.add_vertex(pt00)
		st.set_uv(Vector2(u_tiling, 1.0))
		st.add_vertex(pt11)
		st.set_uv(Vector2(0, 1.0))
		st.add_vertex(pt01)

		st.set_uv(Vector2(0, 0.0))
		st.add_vertex(pt00)
		st.set_uv(Vector2(u_tiling, 0.0))
		st.add_vertex(pt10)
		st.set_uv(Vector2(u_tiling, 1.0))
		st.add_vertex(pt11)

	st.generate_normals()
	return st.commit()
