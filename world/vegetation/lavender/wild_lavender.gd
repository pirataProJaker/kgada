class_name WildLavender
extends Node3D

## Lavanda silvestre / espiga floral esbelta (Lavandula angustifolia / Salvia pratensis).
## Caracterizada por su porte alto y estilizado, hojas lanceoladas en la base
## y verticilos escalonados de flores púrpuras y violetas a lo largo del tallo superior.
## Ideal para crear siluetas naturales en lomas y praderas recortadas contra el horizonte.

const VEGETATION_SHADER = preload("res://world/vegetation/common/vegetation_shader.gdshader")

@export var lavender_seed: int = 12345
@export var plant_scale: float = 1.0

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	if get_child_count() == 0:
		generate()

func generate() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()
	
	var mesh = create_mesh(lavender_seed, plant_scale)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	
	var mat = ShaderMaterial.new()
	mat.shader = VEGETATION_SHADER
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

## Genera un ArrayMesh procedural para la espiga de lavanda
static func create_mesh(seed_val: int = 0, scale_f: float = 1.0) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 12345
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Paleta de colores
	var col_stem := Color(0.18, 0.44, 0.12)
	var col_stem_base := Color(0.10, 0.28, 0.08)
	var col_leaf_base := Color(0.15, 0.38, 0.10)
	var col_leaf_tip := Color(0.35, 0.64, 0.22)
	
	var col_floret_deep := Color(0.32, 0.12, 0.52)  # Púrpura oscuro saturado en cáliz
	var col_floret_mid := Color(0.64, 0.36, 0.90)   # Lavanda/violeta vivo
	var col_floret_tip := Color(0.88, 0.78, 0.98)   # Lila luminoso en las puntas
	
	var height: float = rng.randf_range(0.65, 0.90) * scale_f
	var r_stem: float = 0.0045 * scale_f
	
	# Sutil flexión orgánica del tallo
	var sway_x: float = rng.randf_range(-0.035, 0.035) * scale_f
	var sway_z: float = rng.randf_range(-0.035, 0.035) * scale_f
	
	# 1. TALLO VERTICAL (Prisma esbelto de 3 lados en 4 segmentos)
	var seg_count: int = 4
	var stem_nodes: Array[Vector3] = []
	for s in range(seg_count + 1):
		var t = float(s) / float(seg_count)
		var curve = sin(t * PI * 0.8)
		var pos = Vector3(sway_x * curve, height * t, sway_z * curve)
		stem_nodes.append(pos)
	
	for s in range(seg_count):
		var p0 = stem_nodes[s]
		var p1 = stem_nodes[s + 1]
		var col0 = col_stem_base.lerp(col_stem, float(s) / float(seg_count))
		var col1 = col_stem_base.lerp(col_stem, float(s + 1) / float(seg_count))
		var r0 = r_stem * (1.0 - float(s) * 0.12)
		var r1 = r_stem * (1.0 - float(s + 1) * 0.12)
		
		for side in range(3):
			var a0 = float(side) * TAU / 3.0
			var a1 = float(side + 1) * TAU / 3.0
			
			var v0 = p0 + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var v1 = p0 + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var v2 = p1 + Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			var v3 = p1 + Vector3(cos(a0) * r1, 0, sin(a0) * r1)
			
			st.set_color(col0); st.add_vertex(v0)
			st.set_color(col0); st.add_vertex(v1)
			st.set_color(col1); st.add_vertex(v2)
			
			st.set_color(col0); st.add_vertex(v0)
			st.set_color(col1); st.add_vertex(v2)
			st.set_color(col1); st.add_vertex(v3)
	
	# 2. HOJAS BASALES LANCEOLADAS (5 a 6 hojas largas apuntando hacia afuera y arriba)
	var leaf_count: int = rng.randi_range(5, 7)
	for i in range(leaf_count):
		var a = float(i) * TAU / float(leaf_count) + rng.randf_range(-0.2, 0.2)
		var l_len = rng.randf_range(0.08, 0.15) * scale_f
		var l_up = rng.randf_range(0.03, 0.08) * scale_f
		var l_w = l_len * 0.16
		
		var base_y = rng.randf_range(0.02, 0.08) * scale_f
		var leaf_base = Vector3(0, base_y, 0)
		var leaf_tip = leaf_base + Vector3(cos(a) * l_len, l_up, sin(a) * l_len)
		
		# Ancho del foliolo
		var leaf_mid = leaf_base.lerp(leaf_tip, 0.4)
		var side_vec = Vector3(-sin(a), 0, cos(a)) * (l_w * 0.5)
		var v_left = leaf_mid + side_vec
		var v_right = leaf_mid - side_vec
		
		# 2 triángulos por hoja lanceolada
		st.set_color(col_leaf_base); st.add_vertex(leaf_base)
		st.set_color(col_leaf_base); st.add_vertex(v_right)
		st.set_color(col_leaf_base); st.add_vertex(v_left)
		
		st.set_color(col_leaf_tip);  st.add_vertex(leaf_tip)
		st.set_color(col_leaf_base); st.add_vertex(v_left)
		st.set_color(col_leaf_base); st.add_vertex(v_right)
	
	# 3. ESPIGA DE VERTICILOS FLORALES (4 a 5 niveles escalonados en el tercio superior)
	var whorl_count: int = rng.randi_range(4, 6)
	var spike_start: float = height * 0.52
	var spike_end: float = height * 0.98
	
	for w in range(whorl_count):
		var t_whorl = float(w) / float(whorl_count - 1)
		var whorl_y = lerpf(spike_start, spike_end, t_whorl)
		
		# Posición central interpolada en el tallo
		var seg_idx = clamp(int(t_whorl * float(seg_count)), 0, seg_count - 1)
		var local_t = (whorl_y - stem_nodes[seg_idx].y) / maxf(stem_nodes[seg_idx + 1].y - stem_nodes[seg_idx].y, 0.001)
		var whorl_center = stem_nodes[seg_idx].lerp(stem_nodes[seg_idx + 1], clampf(local_t, 0.0, 1.0))
		
		# Radio del verticilo: decrece ligeramente hacia la punta
		var whorl_r: float = lerpf(0.042, 0.026, t_whorl) * scale_f
		var floret_h: float = lerpf(0.036, 0.024, t_whorl) * scale_f
		
		# Cada verticilo tiene 5 florecillas en estrella
		var petal_count: int = 5
		var whorl_rot = float(w) * 0.628 # Rotación alterna en espiral
		
		for p in range(petal_count):
			var a_p = whorl_rot + float(p) * TAU / float(petal_count) + rng.randf_range(-0.1, 0.1)
			var floret_dir = Vector3(cos(a_p), 0.25, sin(a_p)).normalized()
			
			var f_base = whorl_center
			var f_tip = whorl_center + floret_dir * whorl_r + Vector3(0, floret_h * 0.5, 0)
			
			var perp = Vector3(-sin(a_p), 0, cos(a_p)) * (whorl_r * 0.35)
			var f_l = f_base.lerp(f_tip, 0.45) + perp
			var f_r = f_base.lerp(f_tip, 0.45) - perp
			
			# Triángulo inferior (cáliz oscuro)
			st.set_color(col_floret_deep); st.add_vertex(f_base)
			st.set_color(col_floret_mid);  st.add_vertex(f_r)
			st.set_color(col_floret_mid);  st.add_vertex(f_l)
			
			# Triángulo superior (pétalo lila claro)
			st.set_color(col_floret_tip);  st.add_vertex(f_tip)
			st.set_color(col_floret_mid);  st.add_vertex(f_l)
			st.set_color(col_floret_mid);  st.add_vertex(f_r)
	
	# 4. CAPULLO TERMINAL EN LA CIMA (Corona pequeña de 3 triángulos en la punta)
	var top_tip = stem_nodes[seg_count] + Vector3(0, 0.018 * scale_f, 0)
	var top_base = stem_nodes[seg_count]
	for c in range(3):
		var a0 = float(c) * TAU / 3.0
		var a1 = float(c + 1) * TAU / 3.0
		var v0 = top_base + Vector3(cos(a0) * 0.008 * scale_f, 0, sin(a0) * 0.008 * scale_f)
		var v1 = top_base + Vector3(cos(a1) * 0.008 * scale_f, 0, sin(a1) * 0.008 * scale_f)
		
		st.set_color(col_floret_deep); st.add_vertex(v0)
		st.set_color(col_floret_tip);  st.add_vertex(top_tip)
		st.set_color(col_floret_deep); st.add_vertex(v1)
	
	st.generate_normals()
	return st.commit()
