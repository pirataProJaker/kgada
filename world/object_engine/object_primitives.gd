class_name ObjectPrimitives
extends RefCounted

## Catálogo Centralizado de Mallas Primitivas Paramétricas para el Motor de Objetos (Play Sector X)
## Proporciona formas geométricas unitarias normalizadas (1x1x1 o radio 0.5) con normales explícitas y UVs.
## Cada tipo de primitiva en pantalla consume exactamente 1 Draw Call, sin importar cuántos miles de objetos la usen.

const DEFAULT_CYLINDER_SEGMENTS: int = 12 # 12 lados: estándar medidor CFE / poste de luz / botes de basura / estética PSX
const DEFAULT_SPHERE_RINGS: int = 8
const DEFAULT_SPHERE_RADIAL: int = 12

static var _cached_primitives: Dictionary = {}


## Retorna la malla correspondiente al nombre de la primitiva ("cube", "cylinder", "cylinder_12", "wedge", "sphere", "capsule", "chamfer")
static func get_mesh(primitive_type: String) -> ArrayMesh:
	var key := primitive_type.to_lower()
	if _cached_primitives.has(key):
		return _cached_primitives[key]

	var mesh: ArrayMesh = null
	match key:
		"cube", "box":
			mesh = _create_unit_cube()
		"cylinder", "pipe", "tube", "cylinder_12", "cylinder_lowpoly":
			mesh = _create_unit_cylinder(DEFAULT_CYLINDER_SEGMENTS)
		"cylinder_smooth", "cylinder_16":
			mesh = _create_unit_cylinder(16)
		"wedge", "prism", "ramp":
			mesh = _create_unit_wedge()
		"sphere", "dome":
			mesh = _create_unit_sphere()
		"capsule":
			mesh = _create_unit_capsule()
		"chamfer", "bevel", "chamfer_box", "beveled_box":
			mesh = _create_unit_chamfer()
		"quad", "panel", "plane", "decal":
			mesh = _create_unit_quad()
		_:
			push_warning("ObjectPrimitives: Primitiva desconocida '%s'. Usando 'cube' por defecto." % primitive_type)
			mesh = _create_unit_cube()

	_cached_primitives[key] = mesh
	return mesh


## Permite registrar dinámicamente una nueva primitiva geométrica base en tiempo de ejecución (+1 draw call solo para esa forma)
static func register_custom_primitive(primitive_name: String, mesh: ArrayMesh) -> void:
	if mesh == null:
		push_error("ObjectPrimitives: No se puede registrar una malla nula para '%s'." % primitive_name)
		return
	_cached_primitives[primitive_name.to_lower()] = mesh


## Retorna la lista de todas las primitivas actualmente disponibles
static func get_available_primitive_names() -> Array[String]:
	return ["cube", "cylinder", "wedge", "sphere", "capsule", "chamfer", "quad"]


# =========================================================================
# GENERADORES DE GEOMETRÍA PARAMÉTRICA UNITARIA
# =========================================================================

## 1. Cubo Unitario (1x1x1) centrado en (0, 0, 0)
static func _create_unit_cube() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := 0.5
	var hy := 0.5
	var hz := 0.5

	var v0 := Vector3(-hx, -hy, -hz)
	var v1 := Vector3( hx, -hy, -hz)
	var v2 := Vector3( hx,  hy, -hz)
	var v3 := Vector3(-hx,  hy, -hz)
	var v4 := Vector3(-hx, -hy,  hz)
	var v5 := Vector3( hx, -hy,  hz)
	var v6 := Vector3( hx,  hy,  hz)
	var v7 := Vector3(-hx,  hy,  hz)

	var u_min := Vector2(0.0, 0.0)
	var u_max := Vector2(1.0, 1.0)

	# 6 Caras con orden Clockwise y normales explícitas planas
	_add_quad(st, v4, v5, v6, v7, Vector3.FORWARD, u_min, u_max) # Frente (+Z)
	_add_quad(st, v1, v0, v3, v2, Vector3.BACK, u_min, u_max)    # Atrás (-Z)
	_add_quad(st, v5, v1, v2, v6, Vector3.RIGHT, u_min, u_max)   # Derecha (+X)
	_add_quad(st, v0, v4, v7, v3, Vector3.LEFT, u_min, u_max)    # Izquierda (-X)
	_add_quad(st, v7, v6, v2, v3, Vector3.UP, u_min, u_max)      # Arriba (+Y): -X a +X es U (0->1), -Z a +Z es V (0->1)
	_add_quad(st, v0, v1, v5, v4, Vector3.DOWN, u_min, u_max)    # Abajo (-Y)

	st.generate_tangents()
	return st.commit()


## 2. Cilindro Unitario (altura 1.0, radio 0.5) centrado en (0, 0, 0)
static func _create_unit_cylinder(segments: int = DEFAULT_CYLINDER_SEGMENTS) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var r := 0.5
	var y_top := 0.5
	var y_bot := -0.5

	for i in range(segments):
		var a0 := float(i) / float(segments) * TAU
		var a1 := float(i + 1) / float(segments) * TAU

		var x0 := cos(a0) * r
		var z0 := sin(a0) * r
		var x1 := cos(a1) * r
		var z1 := sin(a1) * r

		var u0 := float(i) / float(segments)
		var u1 := float(i + 1) / float(segments)

		var n0 := Vector3(cos(a0), 0.0, sin(a0))
		var n1 := Vector3(cos(a1), 0.0, sin(a1))

		# Pared lateral (2 triángulos CW)
		st.set_normal(n0); st.set_uv(Vector2(u0, 1.0)); st.add_vertex(Vector3(x0, y_bot, z0))
		st.set_normal(n1); st.set_uv(Vector2(u1, 1.0)); st.add_vertex(Vector3(x1, y_bot, z1))
		st.set_normal(n1); st.set_uv(Vector2(u1, 0.0)); st.add_vertex(Vector3(x1, y_top, z1))

		st.set_normal(n0); st.set_uv(Vector2(u0, 1.0)); st.add_vertex(Vector3(x0, y_bot, z0))
		st.set_normal(n1); st.set_uv(Vector2(u1, 0.0)); st.add_vertex(Vector3(x1, y_top, z1))
		st.set_normal(n0); st.set_uv(Vector2(u0, 0.0)); st.add_vertex(Vector3(x0, y_top, z0))

		# Tapa superior (+Y)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3(0, y_top, 0))
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5)); st.add_vertex(Vector3(x0, y_top, z0))
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)); st.add_vertex(Vector3(x1, y_top, z1))

		# Tapa inferior (-Y)
		st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3(0, y_bot, 0))
		st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)); st.add_vertex(Vector3(x1, y_bot, z1))
		st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5)); st.add_vertex(Vector3(x0, y_bot, z0))

	st.generate_tangents()
	return st.commit()


## 3. Cuña / Prisma Triangular Unitario (1x1x1) centrado en (0, 0, 0)
## La base está en -Y, la pared vertical en -Z y la rampa desciende hacia +Z
static func _create_unit_wedge() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := 0.5
	var hy := 0.5
	var hz := 0.5

	var v_bfl := Vector3(-hx, -hy,  hz) # Bottom Front Left
	var v_bfr := Vector3( hx, -hy,  hz) # Bottom Front Right
	var v_bbl := Vector3(-hx, -hy, -hz) # Bottom Back Left
	var v_bbr := Vector3( hx, -hy, -hz) # Bottom Back Right
	var v_tbl := Vector3(-hx,  hy, -hz) # Top Back Left
	var v_tbr := Vector3( hx,  hy, -hz) # Top Back Right

	var u_min := Vector2(0.0, 0.0)
	var u_max := Vector2(1.0, 1.0)

	# 1. Base inferior (-Y)
	_add_quad(st, v_bbl, v_bbr, v_bfr, v_bfl, Vector3.DOWN, u_min, u_max)

	# 2. Espalda vertical (-Z)
	_add_quad(st, v_bbr, v_bbl, v_tbl, v_tbr, Vector3.BACK, u_min, u_max)

	# 3. Cara Inclinada / Rampa (normal oblicua hacia +Y y +Z)
	var slope_normal := Vector3(0.0, hz, hy).normalized()
	_add_quad(st, v_tbl, v_tbr, v_bfr, v_bfl, slope_normal, u_min, u_max)

	# 4. Lateral Izquierdo (-X) (Triángulo)
	st.set_normal(Vector3.LEFT); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v_bfl)
	st.set_normal(Vector3.LEFT); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v_bbl)
	st.set_normal(Vector3.LEFT); st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v_tbl)

	# 5. Lateral Derecho (+X) (Triángulo)
	st.set_normal(Vector3.RIGHT); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v_bbr)
	st.set_normal(Vector3.RIGHT); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v_bfr)
	st.set_normal(Vector3.RIGHT); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v_tbr)

	st.generate_tangents()
	return st.commit()


## 4. Esfera Unitaria (diámetro 1.0, radio 0.5) centrada en (0, 0, 0) estilo low-poly PSX
static func _create_unit_sphere(rings: int = DEFAULT_SPHERE_RINGS, radial: int = DEFAULT_SPHERE_RADIAL) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var r := 0.5

	for i in range(rings):
		var theta0 := float(i) / float(rings) * PI
		var theta1 := float(i + 1) / float(rings) * PI

		var y0 := cos(theta0) * r
		var r0 := sin(theta0) * r
		var y1 := cos(theta1) * r
		var r1 := sin(theta1) * r

		var v0_uv := float(i) / float(rings)
		var v1_uv := float(i + 1) / float(rings)

		for j in range(radial):
			var phi0 := float(j) / float(radial) * TAU
			var phi1 := float(j + 1) / float(radial) * TAU

			var u0 := float(j) / float(radial)
			var u1 := float(j + 1) / float(radial)

			var p00 := Vector3(cos(phi0) * r0, y0, sin(phi0) * r0)
			var p10 := Vector3(cos(phi1) * r0, y0, sin(phi1) * r0)
			var p01 := Vector3(cos(phi0) * r1, y1, sin(phi0) * r1)
			var p11 := Vector3(cos(phi1) * r1, y1, sin(phi1) * r1)

			var n00 := p00.normalized()
			var n10 := p10.normalized()
			var n01 := p01.normalized()
			var n11 := p11.normalized()

			if i > 0:
				st.set_normal(n00); st.set_uv(Vector2(u0, v0_uv)); st.add_vertex(p00)
				st.set_normal(n10); st.set_uv(Vector2(u1, v0_uv)); st.add_vertex(p10)
				st.set_normal(n01); st.set_uv(Vector2(u0, v1_uv)); st.add_vertex(p01)

			if i < rings - 1:
				st.set_normal(n10); st.set_uv(Vector2(u1, v0_uv)); st.add_vertex(p10)
				st.set_normal(n11); st.set_uv(Vector2(u1, v1_uv)); st.add_vertex(p11)
				st.set_normal(n01); st.set_uv(Vector2(u0, v1_uv)); st.add_vertex(p01)

	st.generate_tangents()
	return st.commit()


## 5. Cápsula Unitaria (altura total 1.0, radio 0.25)
static func _create_unit_capsule() -> ArrayMesh:
	# Cilindro con tapas hemisféricas simplificadas
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var radius := 0.25
	var cyl_height := 0.50
	var half_h := cyl_height * 0.5
	var segments := 10

	for i in range(segments):
		var a0 := float(i) / float(segments) * TAU
		var a1 := float(i + 1) / float(segments) * TAU

		var x0 := cos(a0) * radius
		var z0 := sin(a0) * radius
		var x1 := cos(a1) * radius
		var z1 := sin(a1) * radius

		var u0 := float(i) / float(segments)
		var u1 := float(i + 1) / float(segments)

		var n0 := Vector3(cos(a0), 0.0, sin(a0))
		var n1 := Vector3(cos(a1), 0.0, sin(a1))

		# Cilindro central
		st.set_normal(n0); st.set_uv(Vector2(u0, 0.75)); st.add_vertex(Vector3(x0, -half_h, z0))
		st.set_normal(n1); st.set_uv(Vector2(u1, 0.75)); st.add_vertex(Vector3(x1, -half_h, z1))
		st.set_normal(n1); st.set_uv(Vector2(u1, 0.25)); st.add_vertex(Vector3(x1,  half_h, z1))

		st.set_normal(n0); st.set_uv(Vector2(u0, 0.75)); st.add_vertex(Vector3(x0, -half_h, z0))
		st.set_normal(n1); st.set_uv(Vector2(u1, 0.25)); st.add_vertex(Vector3(x1,  half_h, z1))
		st.set_normal(n0); st.set_uv(Vector2(u0, 0.25)); st.add_vertex(Vector3(x0,  half_h, z0))

		# Cúpula superior (+Y)
		var top_peak := Vector3(0.0, half_h + radius, 0.0)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(top_peak)
		st.set_normal(n0); st.set_uv(Vector2(u0, 0.25)); st.add_vertex(Vector3(x0, half_h, z0))
		st.set_normal(n1); st.set_uv(Vector2(u1, 0.25)); st.add_vertex(Vector3(x1, half_h, z1))

		# Cúpula inferior (-Y)
		var bot_peak := Vector3(0.0, -half_h - radius, 0.0)
		st.set_normal(Vector3.DOWN); st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(bot_peak)
		st.set_normal(n1); st.set_uv(Vector2(u1, 0.75)); st.add_vertex(Vector3(x1, -half_h, z1))
		st.set_normal(n0); st.set_uv(Vector2(u0, 0.75)); st.add_vertex(Vector3(x0, -half_h, z0))

	st.generate_tangents()
	return st.commit()


## 6. Bisel / Chaflán Unitario (Chamfer Box) con 4 esquinas achaflanadas (1x1x1)
static func _create_unit_chamfer() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := 0.5
	var hy := 0.5
	var hz := 0.5
	var c := 0.15 # Tamaño relativo del bisel / chaflán en esquinas

	var x1 := hx - c
	var y1 := hy - c

	# 8 Puntos perimetrales 2D en plano XY (orden horario mirando hacia +Z)
	var pts: Array[Vector2] = [
		Vector2(-x1,  hy), # 0: Superior-Izquierda
		Vector2( x1,  hy), # 1: Superior-Derecha
		Vector2( hx,  y1), # 2: Derecha-Superior
		Vector2( hx, -y1), # 3: Derecha-Inferior
		Vector2( x1, -hy), # 4: Inferior-Derecha
		Vector2(-x1, -hy), # 5: Inferior-Izquierda
		Vector2(-hx, -y1), # 6: Izquierda-Inferior
		Vector2(-hx,  y1), # 7: Izquierda-Superior
	]

	# 1. Cara frontal (+Z)
	var center_front := Vector3(0.0, 0.0, hz)
	for i in range(8):
		var i_next := (i + 1) % 8
		var v_curr := Vector3(pts[i].x, pts[i].y, hz)
		var v_next := Vector3(pts[i_next].x, pts[i_next].y, hz)

		var uv_curr := Vector2(pts[i].x + 0.5, 0.5 - pts[i].y)
		var uv_next := Vector2(pts[i_next].x + 0.5, 0.5 - pts[i_next].y)
		var uv_cent := Vector2(0.5, 0.5)

		st.set_normal(Vector3.FORWARD)
		st.set_uv(uv_cent); st.add_vertex(center_front)
		st.set_uv(uv_curr); st.add_vertex(v_curr)
		st.set_uv(uv_next); st.add_vertex(v_next)

	# 2. Cara trasera (-Z)
	var center_back := Vector3(0.0, 0.0, -hz)
	for i in range(8):
		var i_next := (i + 1) % 8
		var v_curr := Vector3(pts[i].x, pts[i].y, -hz)
		var v_next := Vector3(pts[i_next].x, pts[i_next].y, -hz)

		var uv_curr := Vector2(0.5 - pts[i].x, 0.5 - pts[i].y)
		var uv_next := Vector2(0.5 - pts[i_next].x, 0.5 - pts[i_next].y)
		var uv_cent := Vector2(0.5, 0.5)

		st.set_normal(Vector3.BACK)
		st.set_uv(uv_cent); st.add_vertex(center_back)
		st.set_uv(uv_next); st.add_vertex(v_next)
		st.set_uv(uv_curr); st.add_vertex(v_curr)

	# 3. 8 Caras perimetrales laterales (conectan frente y dorso)
	for i in range(8):
		var i_next := (i + 1) % 8
		var pA: Vector2 = pts[i]
		var pB: Vector2 = pts[i_next]

		var edge: Vector2 = pB - pA
		var normal_2d := Vector3(edge.y, -edge.x, 0.0).normalized()

		var vA_front := Vector3(pA.x, pA.y,  hz)
		var vB_front := Vector3(pB.x, pB.y,  hz)
		var vB_back  := Vector3(pB.x, pB.y, -hz)
		var vA_back  := Vector3(pA.x, pA.y, -hz)

		st.set_normal(normal_2d); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(vA_front)
		st.set_normal(normal_2d); st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(vB_front)
		st.set_normal(normal_2d); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(vB_back)

		st.set_normal(normal_2d); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(vA_front)
		st.set_normal(normal_2d); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(vB_back)
		st.set_normal(normal_2d); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(vA_back)

	st.generate_tangents()
	return st.commit()


## 7. Cuadrilátero Plano Unitario (Quad / Panel 1x1) centrado en (0, 0, 0) mirando hacia +Z (normal = Vector3.FORWARD)
static func _create_unit_quad() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hx := 0.5
	var hy := 0.5

	var v0 := Vector3(-hx, -hy, 0.0)
	var v1 := Vector3( hx, -hy, 0.0)
	var v2 := Vector3( hx,  hy, 0.0)
	var v3 := Vector3(-hx,  hy, 0.0)

	_add_quad(st, v0, v1, v2, v3, Vector3.FORWARD, Vector2(0.0, 0.0), Vector2(1.0, 1.0))

	st.generate_tangents()
	return st.commit()


# =========================================================================
# UTILIDADES DE CONSTRUCCIÓN
# =========================================================================

static func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, u_min: Vector2, u_max: Vector2) -> void:
	st.set_normal(normal); st.set_uv(Vector2(u_min.x, u_max.y)); st.add_vertex(v0)
	st.set_normal(normal); st.set_uv(Vector2(u_max.x, u_max.y)); st.add_vertex(v1)
	st.set_normal(normal); st.set_uv(Vector2(u_max.x, u_min.y)); st.add_vertex(v2)

	st.set_normal(normal); st.set_uv(Vector2(u_min.x, u_max.y)); st.add_vertex(v0)
	st.set_normal(normal); st.set_uv(Vector2(u_max.x, u_min.y)); st.add_vertex(v2)
	st.set_normal(normal); st.set_uv(Vector2(u_min.x, u_min.y)); st.add_vertex(v3)
