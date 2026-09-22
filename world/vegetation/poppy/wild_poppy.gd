class_name WildPoppy
extends Node3D

## Amapola silvestre roja (Papaver rhoeas).
## Flor silvestre de pradera caracterizada por 4 pétalos acopados de color rojo carmesí vivo,
## centro oscuro estaminado y tallo esbelto y sinuoso.
## Aporta acentos cromáticos cálidos y vibrantes a los paisajes de pradera.

const VEGETATION_SHADER = preload("res://world/vegetation/common/vegetation_shader.gdshader")

@export var poppy_seed: int = 12345
@export var flower_scale: float = 1.0

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	if get_child_count() == 0:
		generate()

func generate() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()
	
	var mesh = create_mesh(poppy_seed, flower_scale)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	
	var mat = ShaderMaterial.new()
	mat.shader = VEGETATION_SHADER
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

## Genera un ArrayMesh procedural para la amapola silvestre
static func create_mesh(seed_val: int = 0, scale_f: float = 1.0) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 12345
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Paleta cromática
	var col_stem := Color(0.16, 0.38, 0.12)
	var col_stem_base := Color(0.10, 0.24, 0.08)
	var col_petal_base := Color(0.12, 0.02, 0.04)   # Base negra/púrpura oscura característica
	var col_petal_mid := Color(0.85, 0.08, 0.08)    # Rojo carmesí intenso
	var col_petal_tip := Color(0.96, 0.18, 0.12)    # Borde traslúcido iluminado por el sol
	var col_center := Color(0.06, 0.03, 0.04)       # Botón de estambres negro aterciopelado
	
	var stem_h: float = rng.randf_range(0.24, 0.36) * scale_f
	var r_cup: float = rng.randf_range(0.042, 0.055) * scale_f
	
	# Curvatura sinuosa típica del tallo de amapola
	var bend_x: float = rng.randf_range(-0.035, 0.035) * scale_f
	var bend_z: float = rng.randf_range(-0.035, 0.035) * scale_f
	var p_base := Vector3.ZERO
	var p_mid := Vector3(bend_x * 0.7, stem_h * 0.45, bend_z * 0.7)
	var p_top := Vector3(bend_x, stem_h, bend_z)
	
	# 1. TALLO DELGADO (Prisma triangular en 2 tramos = 12 triángulos)
	var r_stem: float = 0.0030 * scale_f
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
	
	# 2. BOTÓN CENTRAL NEGRO (Cono pequeño invertido de 4 lados)
	var r_center: float = 0.010 * scale_f
	var h_center: float = 0.008 * scale_f
	var center_apex = p_top + Vector3(0, h_center, 0)
	for i in range(4):
		var a0 = float(i) * TAU / 4.0
		var a1 = float(i + 1) * TAU / 4.0
		var v0 = p_top + Vector3(cos(a0) * r_center, 0.002, sin(a0) * r_center)
		var v1 = p_top + Vector3(cos(a1) * r_center, 0.002, sin(a1) * r_center)
		
		st.set_color(col_center); st.add_vertex(center_apex)
		st.set_color(col_center); st.add_vertex(v1)
		st.set_color(col_center); st.add_vertex(v0)
	
	# 3. 4 PÉTALOS ACOPADOS (Superpuestos en forma de copa abierta)
	var petal_count: int = 4
	for p in range(petal_count):
		var base_a = float(p) * TAU / 4.0 + rng.randf_range(-0.1, 0.1)
		var cup_up = rng.randf_range(0.022, 0.035) * scale_f
		var p_root = p_top + Vector3(cos(base_a) * (r_center * 0.8), 0.002, sin(base_a) * (r_center * 0.8))
		
		# Extremo del pétalo
		var p_tip = p_top + Vector3(cos(base_a) * r_cup, cup_up, sin(base_a) * r_cup)
		
		# Alas laterales para dar forma abombada
		var p_mid_pt = p_root.lerp(p_tip, 0.6)
		var span = r_cup * 0.65
		var perp = Vector3(-sin(base_a), 0, cos(base_a)) * span
		var v_left = p_mid_pt + perp
		var v_right = p_mid_pt - perp
		
		# Triángulo 1: Base oscura
		st.set_color(col_petal_base); st.add_vertex(p_root)
		st.set_color(col_petal_mid);  st.add_vertex(v_right)
		st.set_color(col_petal_mid);  st.add_vertex(v_left)
		
		# Triángulo 2: Extremo iluminado
		st.set_color(col_petal_tip);  st.add_vertex(p_tip)
		st.set_color(col_petal_mid);  st.add_vertex(v_left)
		st.set_color(col_petal_mid);  st.add_vertex(v_right)
	
	st.generate_normals()
	return st.commit()
