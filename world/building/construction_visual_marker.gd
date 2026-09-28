extends Node3D
class_name ConstructionVisualMarker
## Genera en 3D la representación visual del trazado entre puntos de construcción
## según la herramienta equipada:
## - Palo: Raya en la tierra + montículos de tierra en cada vértice.
## - Cuaderno/Estacas: Estacas verticales clavadas + cuerda tensada.
## - Plano de cal: Franja de cal blanca pulverizada en el suelo.

@export var marker_type: String = "dirt_scrape" # "dirt_scrape", "stake_rope", "cal_line"

var points: Array[Vector3] = []
var marker_nodes: Array[Node3D] = []

func setup(p_marker_type: String, p_points: Array = []) -> void:
	marker_type = p_marker_type
	points.clear()
	for pt in p_points:
		if pt is Vector3:
			points.append(pt)
	rebuild()

func clear() -> void:
	setup("", [])

func rebuild() -> void:
	for n in marker_nodes:
		if is_instance_valid(n):
			n.queue_free()
	marker_nodes.clear()

	if points.is_empty():
		return

	# Si es un trazado vertical con altura (Pared):
	# "debe verse con una linea toda su orilla y ya"
	if _is_3d_vertical_outline():
		_build_wall_outline_3d()
		return

	match marker_type:
		"dirt_scrape":
			_build_dirt_scrape()
		"stake_rope":
			_build_stake_rope()
		"cal_line":
			_build_cal_line()
		_:
			_build_dirt_scrape()

func _is_3d_vertical_outline() -> bool:
	if points.size() < 4:
		return false
	var first_y := points[0].y
	for pt in points:
		if absf(pt.y - first_y) > 0.08:
			return true
	return false

## Trazado perimetral de Pared 3D ("debe verse con una linea toda su orilla y ya")
func _build_wall_outline_3d() -> void:
	if points.size() < 2:
		return

	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	match marker_type:
		"stake_rope":
			line_mat.albedo_color = Color(0.92, 0.82, 0.58) # Cuerda de cáñamo clara
		"cal_line":
			line_mat.albedo_color = Color(0.96, 0.96, 0.94) # Cal pulverizada blanca
		_:
			# Por defecto / Palo: Línea dorada nítida de replanteo
			line_mat.albedo_color = Color(1.0, 0.85, 0.32)

	# 1. Trazar segmentos de línea cilíndricos a lo largo de todo el bucle perimetral
	var radius := 0.022
	for i in range(points.size() - 1):
		var p_start := points[i]
		var p_end := points[i + 1]
		var dist := p_start.distance_to(p_end)
		if dist < 0.02:
			continue

		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = dist
		cyl.radial_segments = 8
		cyl.rings = 1
		seg.mesh = cyl
		seg.material_override = line_mat
		seg.position = (p_start + p_end) * 0.5

		var dir := (p_end - p_start).normalized()
		if absf(dir.y) > 0.999:
			if dir.y < 0.0:
				seg.transform.basis = Basis(Vector3.RIGHT, PI)
		else:
			var right := dir.cross(Vector3.UP).normalized()
			var forward := right.cross(dir).normalized()
			seg.transform.basis = Basis(right, dir, forward)

		add_child(seg)
		marker_nodes.append(seg)

	# 2. Esferas de unión en los vértices únicos para sellar esquinas
	var unique_pts := _get_unique_points()
	for pt in unique_pts:
		var corner := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = radius * 1.35
		sph.height = radius * 2.7
		sph.radial_segments = 8
		sph.rings = 4
		corner.mesh = sph
		corner.material_override = line_mat
		corner.position = pt
		add_child(corner)
		marker_nodes.append(corner)

## Helper para obtener vértices únicos (evitando duplicar estacas/montículos en bucles cerrados)
func _get_unique_points() -> Array[Vector3]:
	var unique: Array[Vector3] = []
	for pt in points:
		var exists := false
		for u in unique:
			if u.distance_squared_to(pt) < 0.01:
				exists = true
				break
		if not exists:
			unique.append(pt)
	return unique

const ScrapedDirtModelBuilderScript = preload("res://world/building/scraped_dirt_model_builder.gd")

## Trazado de Palo: Modelo 3D de orilla raspada en tierra con textura real y 3 niveles de LOD
func _build_dirt_scrape() -> void:
	if points.size() < 2:
		return
	var lod_model := ScrapedDirtModelBuilderScript.create_lod_scraped_perimeter(points)
	add_child(lod_model)
	marker_nodes.append(lod_model)

## Trazado de Cuaderno: Estacas de madera clavadas y cuerda tensada
func _build_stake_rope() -> void:
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.28, 0.16)
	wood_mat.roughness = 0.85

	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.85, 0.75, 0.55)
	rope_mat.roughness = 0.9

	var stake_height := 0.45

	# Estacas en cada esquina única
	var unique_corners := _get_unique_points()
	for pt in unique_corners:
		var stake := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = stake_height
		stake.mesh = cyl
		stake.material_override = wood_mat
		stake.position = pt + Vector3(0, stake_height * 0.5, 0)
		add_child(stake)
		marker_nodes.append(stake)

	# Cuerda tensada entre las cabezas de las estacas
	if points.size() >= 2:
		for i in range(points.size() - 1):
			var p0 := points[i] + Vector3(0, stake_height * 0.85, 0)
			var p1 := points[i + 1] + Vector3(0, stake_height * 0.85, 0)
			var dist := p0.distance_to(p1)
			if dist < 0.05:
				continue
			var dir := (p1 - p0).normalized()
			var mid := (p0 + p1) * 0.5

			var rope := MeshInstance3D.new()
			var rope_cyl := CylinderMesh.new()
			rope_cyl.top_radius = 0.012
			rope_cyl.bottom_radius = 0.012
			rope_cyl.height = dist
			rope.mesh = rope_cyl
			rope.material_override = rope_mat
			rope.position = mid

			if not dir.is_equal_approx(Vector3.UP) and not dir.is_equal_approx(Vector3.DOWN):
				rope.transform.basis = Basis.looking_at(dir, Vector3.UP).rotated(Vector3.RIGHT, deg_to_rad(90))

			add_child(rope)
			marker_nodes.append(rope)

## Trazado de Plano: Polvo blanco de cal industrial en el suelo
func _build_cal_line() -> void:
	var cal_mat := StandardMaterial3D.new()
	cal_mat.albedo_color = Color(0.96, 0.96, 0.94)
	cal_mat.roughness = 0.98

	# Marcadores en cruz de cal en cada esquina única
	var unique_corners := _get_unique_points()
	for pt in unique_corners:
		var cross1 := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.015, 0.35)
		cross1.mesh = box
		cross1.material_override = cal_mat
		cross1.position = pt + Vector3(0, 0.01, 0)
		add_child(cross1)
		marker_nodes.append(cross1)

		var cross2 := MeshInstance3D.new()
		var box2 := BoxMesh.new()
		box2.size = Vector3(0.35, 0.015, 0.08)
		cross2.mesh = box2
		cross2.material_override = cal_mat
		cross2.position = pt + Vector3(0, 0.01, 0)
		add_child(cross2)
		marker_nodes.append(cross2)

	# Línea continua de cal a lo largo de toda la orilla
	if points.size() >= 2:
		for i in range(points.size() - 1):
			var p0 := points[i]
			var p1 := points[i + 1]
			var dist := p0.distance_to(p1)
			if dist < 0.05:
				continue
			var dir := (p1 - p0).normalized()
			var mid := (p0 + p1) * 0.5

			var line := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.10, 0.012, dist)
			line.mesh = box
			line.material_override = cal_mat
			line.position = mid + Vector3(0, 0.01, 0)

			if not dir.is_equal_approx(Vector3.UP) and not dir.is_equal_approx(Vector3.DOWN):
				line.transform.basis = Basis.looking_at(dir, Vector3.UP)

			add_child(line)
			marker_nodes.append(line)
