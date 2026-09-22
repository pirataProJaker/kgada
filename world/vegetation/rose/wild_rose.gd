class_name WildRose
extends Node3D

## Rosa silvestre y de jardín low-poly optimizada para instanciamiento masivo (MultiMesh).
## Diseñada con arquitectura botánica de rosa: tallo leñoso verde bosque con espinas sutiles,
## foliolos dentados en V, cáliz con sépalos extendidos y corola en capas espiraladas aterciopeladas.
## Proporciona tanto mallas de rosas individuales como racimos/arbustos tupidos de 3-4 rosas.

const VEGETATION_SHADER = preload("res://world/vegetation/common/vegetation_shader.gdshader")

# Paletas de color estándar de rosas
const COLOR_CRIMSON = Color(0.82, 0.05, 0.12)    # Rojo carmesí clásico aterciopelado
const COLOR_DEEP_RED = Color(0.56, 0.02, 0.08)   # Rojo sangre / Baccara profundo
const COLOR_CORAL = Color(0.94, 0.36, 0.28)      # Rosa coral / salmón luminoso
const COLOR_PASTEL_PINK = Color(0.94, 0.54, 0.66)# Rosa suave pastel
const COLOR_WHITE = Color(0.96, 0.95, 0.90)      # Blanco marfil puro
const COLOR_YELLOW = Color(0.96, 0.82, 0.14)     # Amarillo dorado cálido

@export var rose_seed: int = 12345
@export var flower_scale: float = 1.0
@export var flower_color: Color = COLOR_CRIMSON

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	if get_child_count() == 0:
		generate()

func generate() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()
	
	var mesh = create_single_rose_mesh(rose_seed, flower_scale, flower_color)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	
	var mat = ShaderMaterial.new()
	mat.shader = VEGETATION_SHADER
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

## Genera la malla de una sola rosa esbelta (aprox. 42 triángulos)
static func create_single_rose_mesh(seed_val: int = 0, scale_f: float = 1.0, col_rose: Color = COLOR_CRIMSON) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 12345
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Colores vegetales
	var col_stem_base := Color(0.08, 0.18, 0.06)  # Tallo leñoso oscuro
	var col_stem := Color(0.12, 0.32, 0.10)       # Tallo verde bosque
	var col_leaf := Color(0.08, 0.26, 0.08)       # Hoja de rosal verde oscuro ceroso
	var col_leaf_rim := Color(0.18, 0.44, 0.14)   # Borde de hoja con luz
	var col_sepal := Color(0.14, 0.36, 0.10)      # Sépalos
	
	var height: float = rng.randf_range(0.38, 0.52) * scale_f
	var r_stem: float = 0.0055 * scale_f
	var flower_r: float = rng.randf_range(0.055, 0.072) * scale_f
	
	var bend_x: float = rng.randf_range(-0.025, 0.025) * scale_f
	var bend_z: float = rng.randf_range(-0.025, 0.025) * scale_f
	var p_base := Vector3.ZERO
	var p_mid := Vector3(bend_x * 0.6, height * 0.52, bend_z * 0.6)
	var p_top := Vector3(bend_x, height, bend_z)
	
	# 1. TALLO ERGUIDO (Prisma de 3 lados en 2 segmentos = 12 triángulos)
	for seg in range(2):
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
			
			st.set_color(col0); st.add_vertex(v0)
			st.set_color(col0); st.add_vertex(v1)
			st.set_color(col1); st.add_vertex(v2)
			
			st.set_color(col0); st.add_vertex(v0)
			st.set_color(col1); st.add_vertex(v2)
			st.set_color(col1); st.add_vertex(v3)
			
	# 2. HOJAS COMPUESTAS DE ROSAL (2 ramillas con foliolos en V a distintas alturas = 8 triángulos)
	for l_idx in range(2):
		var t = 0.38 if l_idx == 0 else 0.70
		var l_pt = p_base.lerp(p_top, t)
		var l_angle = float(l_idx) * PI + rng.randf_range(-0.35, 0.35)
		var l_dir = Vector3(cos(l_angle), 0.32, sin(l_angle)).normalized()
		var l_len = rng.randf_range(0.08, 0.12) * scale_f
		var l_w = l_len * 0.42
		
		var l_tip = l_pt + l_dir * l_len
		var l_side = Vector3(-sin(l_angle), 0, cos(l_angle)) * (l_w * 0.5)
		var l_mid = l_pt.lerp(l_tip, 0.45)
		
		# Foliolo terminal en V
		var v_left = l_mid - l_side + Vector3(0, 0.012 * scale_f, 0)
		var v_right = l_mid + l_side + Vector3(0, 0.012 * scale_f, 0)
		
		st.set_color(col_leaf); st.add_vertex(l_pt)
		st.set_color(col_leaf); st.add_vertex(v_right)
		st.set_color(col_leaf_rim); st.add_vertex(v_left)
		
		st.set_color(col_leaf_rim); st.add_vertex(l_tip)
		st.set_color(col_leaf); st.add_vertex(v_left)
		st.set_color(col_leaf); st.add_vertex(v_right)
		
	# 3. CÁLIZ Y SÉPALOS (Receptáculo cónico verde debajo de la flor = 5 triángulos)
	var sepal_h = 0.014 * scale_f
	var sepal_r = flower_r * 0.45
	var p_calyx = p_top - Vector3(0, sepal_h, 0)
	for s in range(5):
		var a0 = float(s) * TAU / 5.0
		var a1 = float(s + 1) * TAU / 5.0
		var tip_a = a0 + 0.5 * (TAU / 5.0)
		var s_tip = p_top + Vector3(cos(tip_a) * sepal_r * 1.35, -sepal_h * 0.6, sin(tip_a) * sepal_r * 1.35)
		var s_v0 = p_top + Vector3(cos(a0) * sepal_r, 0, sin(a0) * sepal_r)
		var s_v1 = p_top + Vector3(cos(a1) * sepal_r, 0, sin(a1) * sepal_r)
		
		st.set_color(col_sepal); st.add_vertex(p_calyx)
		st.set_color(col_sepal); st.add_vertex(s_v1)
		st.set_color(col_sepal); st.add_vertex(s_v0)
		
		st.set_color(col_sepal); st.add_vertex(s_tip)
		st.set_color(col_sepal); st.add_vertex(s_v0)
		st.set_color(col_sepal); st.add_vertex(s_v1)

	# 4. COROLA FLORAL DE ROSA EN CAPAS CONCÉNTRICAS (Flor voluptuosa aterciopelada)
	_build_rose_bloom_mesh(st, p_top, flower_r, col_rose, rng, scale_f)
	
	st.generate_normals()
	return st.commit()

## Genera un racimo/mata tupida de 3 rosas juntas con follaje arbustivo (aprox. 95 triángulos)
static func create_rose_cluster_mesh(seed_val: int = 0, scale_f: float = 1.0, col_rose: Color = COLOR_CRIMSON) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 54321
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var col_stem := Color(0.10, 0.28, 0.08)
	var col_leaf := Color(0.07, 0.24, 0.07)
	var col_leaf_tip := Color(0.16, 0.42, 0.12)
	
	# Racimo de 3 rosas en tríada orgánica
	var rose_offsets = [
		{"pos": Vector3(-0.08, 0.46, 0.04) * scale_f, "r": 0.062 * scale_f, "scale": 1.05},
		{"pos": Vector3(0.09, 0.52, -0.05) * scale_f, "r": 0.068 * scale_f, "scale": 1.15},
		{"pos": Vector3(0.01, 0.38, 0.08) * scale_f, "r": 0.054 * scale_f, "scale": 0.90}
	]
	
	# Follaje arbustivo basal denso (6 hojas en domo que abrazan el racimo = 12 triángulos)
	for i in range(6):
		var a = float(i) * TAU / 6.0 + rng.randf_range(-0.15, 0.15)
		var l_len = rng.randf_range(0.12, 0.18) * scale_f
		var l_w = l_len * 0.45
		var l_base = Vector3(cos(a) * 0.03, 0.04 * scale_f, sin(a) * 0.03)
		var l_tip = l_base + Vector3(cos(a) * l_len, 0.08 * scale_f, sin(a) * l_len)
		var l_mid = l_base.lerp(l_tip, 0.45)
		var l_side = Vector3(-sin(a), 0, cos(a)) * (l_w * 0.5)
		
		var v_l = l_mid - l_side + Vector3(0, 0.02 * scale_f, 0)
		var v_r = l_mid + l_side + Vector3(0, 0.02 * scale_f, 0)
		
		st.set_color(col_leaf); st.add_vertex(l_base)
		st.set_color(col_leaf); st.add_vertex(v_r)
		st.set_color(col_leaf_tip); st.add_vertex(v_l)
		
		st.set_color(col_leaf_tip); st.add_vertex(l_tip)
		st.set_color(col_leaf); st.add_vertex(v_l)
		st.set_color(col_leaf); st.add_vertex(v_r)
		
	# Tallo y flor para cada rosa del racimo
	for ro in rose_offsets:
		var p_top: Vector3 = ro["pos"]
		var fl_r: float = ro["r"]
		
		# Tallo arqueado desde el centro hacia la flor (6 triángulos)
		var p_base = Vector3(p_top.x * 0.25, 0.0, p_top.z * 0.25)
		var p_mid = p_base.lerp(p_top, 0.5) + Vector3(rng.randf_range(-0.02, 0.02), 0, rng.randf_range(-0.02, 0.02))
		var r_st = 0.005 * scale_f
		
		for seg in range(2):
			var c0 = p_base if seg == 0 else p_mid
			var c1 = p_mid if seg == 0 else p_top
			for s in range(3):
				var a0 = float(s) * TAU / 3.0
				var a1 = float(s + 1) * TAU / 3.0
				var v0 = c0 + Vector3(cos(a0) * r_st, 0, sin(a0) * r_st)
				var v1 = c0 + Vector3(cos(a1) * r_st, 0, sin(a1) * r_st)
				var v2 = c1 + Vector3(cos(a1) * r_st * 0.85, 0, sin(a1) * r_st * 0.85)
				var v3 = c1 + Vector3(cos(a0) * r_st * 0.85, 0, sin(a0) * r_st * 0.85)
				st.set_color(col_stem); st.add_vertex(v0)
				st.set_color(col_stem); st.add_vertex(v1)
				st.set_color(col_stem); st.add_vertex(v2)
				st.set_color(col_stem); st.add_vertex(v0)
				st.set_color(col_stem); st.add_vertex(v2)
				st.set_color(col_stem); st.add_vertex(v3)
				
		# Corola floral de la rosa
		_build_rose_bloom_mesh(st, p_top, fl_r, col_rose, rng, scale_f)
		
	st.generate_normals()
	return st.commit()

## Construye la geometría 3D de la flor de rosa (corola concéntrica con pétalos en espiral)
static func _build_rose_bloom_mesh(st: SurfaceTool, pos: Vector3, radius: float, base_col: Color, rng: RandomNumberGenerator, scale_f: float) -> void:
	# Gradación cromática aterciopelada
	var col_dark := base_col.darkened(0.40)  # Núcleo interior profundo
	var col_mid := base_col                  # Cuerpo voluptuoso
	var col_rim := base_col.lightened(0.18)  # Borde de pétalos iluminado
	
	# Capa 1: Copa Exterior de Pétalos Abiertos (6 pétalos en abanico = 12 triángulos)
	var num_outer := 6
	var r_outer := radius
	var h_outer := radius * 0.45
	for p in range(num_outer):
		var a0 = float(p) * TAU / float(num_outer) + 0.1
		var a1 = float(p + 1) * TAU / float(num_outer) + 0.1
		var a_mid = (a0 + a1) * 0.5
		
		var p_base = pos + Vector3(cos(a_mid) * r_outer * 0.25, -0.01 * scale_f, sin(a_mid) * r_outer * 0.25)
		var p_l = pos + Vector3(cos(a0) * r_outer * 0.82, h_outer * 0.4, sin(a0) * r_outer * 0.82)
		var p_r = pos + Vector3(cos(a1) * r_outer * 0.82, h_outer * 0.4, sin(a1) * r_outer * 0.82)
		var p_tip = pos + Vector3(cos(a_mid) * r_outer * 1.05, h_outer * 0.75, sin(a_mid) * r_outer * 1.05)
		
		# Pétalo abombado exterior
		st.set_color(col_dark); st.add_vertex(p_base)
		st.set_color(col_mid);  st.add_vertex(p_r)
		st.set_color(col_mid);  st.add_vertex(p_l)
		
		st.set_color(col_rim);  st.add_vertex(p_tip)
		st.set_color(col_mid);  st.add_vertex(p_l)
		st.set_color(col_mid);  st.add_vertex(p_r)
		
	# Capa 2: Copa Media Envolvente (5 pétalos concéntricos en espiral = 10 triángulos)
	var num_mid := 5
	var r_mid := radius * 0.65
	var h_mid := radius * 0.65
	for p in range(num_mid):
		var a0 = float(p) * TAU / float(num_mid) + 0.65
		var a1 = float(p + 1) * TAU / float(num_mid) + 0.65
		var a_mid = (a0 + a1) * 0.5
		
		var p_b = pos + Vector3(cos(a_mid) * r_mid * 0.20, 0.005 * scale_f, sin(a_mid) * r_mid * 0.20)
		var p_l = pos + Vector3(cos(a0) * r_mid * 0.85, h_mid * 0.5, sin(a0) * r_mid * 0.85)
		var p_r = pos + Vector3(cos(a1) * r_mid * 0.85, h_mid * 0.5, sin(a1) * r_mid * 0.85)
		var p_tip = pos + Vector3(cos(a_mid) * r_mid * 0.95, h_mid, sin(a_mid) * r_mid * 0.95)
		
		st.set_color(col_dark); st.add_vertex(p_b)
		st.set_color(col_mid);  st.add_vertex(p_r)
		st.set_color(col_mid);  st.add_vertex(p_l)
		
		st.set_color(col_rim);  st.add_vertex(p_tip)
		st.set_color(col_mid);  st.add_vertex(p_l)
		st.set_color(col_mid);  st.add_vertex(p_r)

	# Capa 3: Corazón Central Espiralado (Botón de pétalos apretados = 5 triángulos)
	var r_core := radius * 0.32
	var h_core := radius * 0.80
	var core_apex = pos + Vector3(0, h_core, 0)
	for p in range(5):
		var a0 = float(p) * TAU / 5.0 + 1.2
		var a1 = float(p + 1) * TAU / 5.0 + 1.2
		var p0 = pos + Vector3(cos(a0) * r_core, h_mid * 0.4, sin(a0) * r_core)
		var p1 = pos + Vector3(cos(a1) * r_core, h_mid * 0.4, sin(a1) * r_core)
		
		st.set_color(col_dark); st.add_vertex(core_apex)
		st.set_color(col_mid);  st.add_vertex(p1)
		st.set_color(col_dark); st.add_vertex(p0)
