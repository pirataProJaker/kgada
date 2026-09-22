class_name WildDaisy
extends Node3D

## Margarita blanca silvestre (Bellis perennis).
## Geometría low-poly optimizada con disco central dorado, pétalos blancos radiantes
## y tallo esbelto con hojas basales.
## Diseñada tanto para uso individual como para instanciamiento masivo (MultiMesh).

const VEGETATION_SHADER = preload("res://world/vegetation/common/vegetation_shader.gdshader")

@export var daisy_seed: int = 12345
@export var flower_scale: float = 1.0

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	if get_child_count() == 0:
		generate()

func generate() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()
	
	var mesh = create_mesh(daisy_seed, flower_scale)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	
	var mat = ShaderMaterial.new()
	mat.shader = VEGETATION_SHADER
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

## Genera un ArrayMesh procedural para la margarita
static func create_mesh(seed_val: int = 0, scale_f: float = 1.0) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 12345
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Paleta de colores fiel a la Foto 1
	var col_stem := Color(0.14, 0.44, 0.12)
	var col_stem_base := Color(0.09, 0.26, 0.07)
	var col_center_apex := Color(1.0, 0.78, 0.04) # Botón amarillo dorado brillante
	var col_center_rim := Color(0.88, 0.56, 0.02)  # Ámbar suave
	var col_petal_tip := Color(1.0, 1.0, 1.0)      # Blanco puro radiante
	var col_petal_base := Color(0.90, 0.93, 0.88)  # Base con sombreado sutil
	var col_leaf := Color(0.16, 0.46, 0.12)
	
	var stem_h: float = rng.randf_range(0.18, 0.26) * scale_f
	var center_r: float = rng.randf_range(0.024, 0.030) * scale_f
	var petal_len: float = rng.randf_range(0.050, 0.065) * scale_f
	var petal_w: float = petal_len * 0.28
	
	# Curvatura natural del tallo
	var bend_x: float = rng.randf_range(-0.025, 0.025) * scale_f
	var bend_z: float = rng.randf_range(-0.025, 0.025) * scale_f
	var p_base := Vector3.ZERO
	var p_mid := Vector3(bend_x * 0.6, stem_h * 0.5, bend_z * 0.6)
	var p_top := Vector3(bend_x, stem_h, bend_z)
	
	# 1. TALLO (Prisma de 3 lados con 2 segmentos = 12 triángulos)
	var r_stem: float = 0.0035 * scale_f
	for seg in range(2):
		var y0 = p_base.y if seg == 0 else p_mid.y
		var y1 = p_mid.y if seg == 0 else p_top.y
		var c0 = p_base if seg == 0 else p_mid
		var c1 = p_mid if seg == 0 else p_top
		var col0 = col_stem_base if seg == 0 else col_stem
		var col1 = col_stem
		
		for side in range(3):
			var a0 = float(side) * TAU / 3.0
			var a1 = float(side + 1) * TAU / 3.0
			
			var v0 = c0 + Vector3(cos(a0) * r_stem, 0, sin(a0) * r_stem)
			var v1 = c0 + Vector3(cos(a1) * r_stem, 0, sin(a1) * r_stem)
			var v2 = c1 + Vector3(cos(a1) * r_stem * 0.9, 0, sin(a1) * r_stem * 0.9)
			var v3 = c1 + Vector3(cos(a0) * r_stem * 0.9, 0, sin(a0) * r_stem * 0.9)
			
			# Quad de lado
			st.set_color(col0); st.add_vertex(v0)
			st.set_color(col0); st.add_vertex(v1)
			st.set_color(col1); st.add_vertex(v2)
			
			st.set_color(col0); st.add_vertex(v0)
			st.set_color(col1); st.add_vertex(v2)
			st.set_color(col1); st.add_vertex(v3)
	
	# 2. HOJAS BASALES (2 hojas alargadas triangulares cerca del suelo)
	for l in range(2):
		var l_angle = float(l) * PI + rng.randf_range(-0.3, 0.3)
		var l_len = rng.randf_range(0.045, 0.075) * scale_f
		var l_w = l_len * 0.35
		var l_up = rng.randf_range(0.015, 0.035) * scale_f
		
		var l_tip = p_base + Vector3(cos(l_angle) * l_len, l_up, sin(l_angle) * l_len)
		var l_side1 = p_base + Vector3(cos(l_angle + 0.4) * l_w, 0.005, sin(l_angle + 0.4) * l_w)
		var l_side2 = p_base + Vector3(cos(l_angle - 0.4) * l_w, 0.005, sin(l_angle - 0.4) * l_w)
		
		st.set_color(col_stem_base); st.add_vertex(l_side1)
		st.set_color(col_leaf); st.add_vertex(l_tip)
		st.set_color(col_stem_base); st.add_vertex(l_side2)
	
	# 3. RECEPTÁCULO / CÁLIZ Y CABEZA FLORAL ORIENTADA
	# Inclinación natural hacia el sol/espectador (~18 a 32 grados)
	var tilt_ang: float = rng.randf_range(0.30, 0.55)
	var tilt_yaw: float = rng.randf() * TAU
	var head_up := Vector3(sin(tilt_ang) * cos(tilt_yaw), cos(tilt_ang), sin(tilt_ang) * sin(tilt_yaw)).normalized()
	var head_right := Vector3.UP.cross(head_up).normalized()
	if head_right.length_squared() < 0.001:
		head_right = Vector3.RIGHT
	var head_fwd := head_up.cross(head_right).normalized()
	
	var num_rim: int = 7
	var calyx_bottom = p_top - head_up * (0.010 * scale_f)
	var rim_pts: Array[Vector3] = []
	for i in range(num_rim):
		var ang = float(i) * TAU / float(num_rim)
		var offset = (head_right * cos(ang) + head_fwd * sin(ang)) * center_r
		rim_pts.append(p_top + offset)
	
	for i in range(num_rim):
		var i_next = (i + 1) % num_rim
		st.set_color(col_stem); st.add_vertex(calyx_bottom)
		st.set_color(col_stem); st.add_vertex(rim_pts[i])
		st.set_color(col_stem); st.add_vertex(rim_pts[i_next])
	
	# 4. BOTÓN CENTRAL DORADO (Domo abovedado amarillo)
	var dome_apex = p_top + head_up * (0.010 * scale_f)
	for i in range(num_rim):
		var i_next = (i + 1) % num_rim
		st.set_color(col_center_apex); st.add_vertex(dome_apex)
		st.set_color(col_center_rim);  st.add_vertex(rim_pts[i_next])
		st.set_color(col_center_rim);  st.add_vertex(rim_pts[i])
	
	# 5. PÉTALOS BLANCOS RADIANTES (14 a 16 pétalos)
	var num_petals: int = rng.randi_range(14, 16)
	for p in range(num_petals):
		var base_ang = float(p) * TAU / float(num_petals) + rng.randf_range(-0.06, 0.06)
		var cup_up = rng.randf_range(0.002, 0.008) * scale_f
		
		var dir_p = (head_right * cos(base_ang) + head_fwd * sin(base_ang)).normalized()
		var p_root = p_top + dir_p * (center_r * 0.95)
		var p_tip = p_top + dir_p * (center_r + petal_len) + head_up * cup_up
		
		# Ancho del pétalo a mitad de camino
		var mid_pos = p_root.lerp(p_tip, 0.52)
		var perp = head_up.cross(dir_p).normalized() * (petal_w * 0.5)
		var p_left = mid_pos + perp
		var p_right = mid_pos - perp
		
		# Triángulo 1: raíz -> derecha -> izquierda
		st.set_color(col_petal_base); st.add_vertex(p_root)
		st.set_color(col_petal_tip);  st.add_vertex(p_right)
		st.set_color(col_petal_tip);  st.add_vertex(p_left)
		
		# Triángulo 2: punta -> izquierda -> derecha
		st.set_color(col_petal_tip);  st.add_vertex(p_tip)
		st.set_color(col_petal_tip);  st.add_vertex(p_left)
		st.set_color(col_petal_tip);  st.add_vertex(p_right)
	
	st.generate_normals()
	return st.commit()
