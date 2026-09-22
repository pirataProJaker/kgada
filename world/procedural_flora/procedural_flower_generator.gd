class_name ProceduralFlowerGenerator
extends RefCounted

## Generador matemático de geometría procedural para flores y plantas.
## Construye mallas ArrayMesh 3D optimizadas (máximo 2 superficies) con
## tallos continuos, hojas curvadas en V y pétalos tridimensionales con ciclo de crecimiento.

const FlowerProfiles = preload("res://world/procedural_flora/procedural_flower_profiles.gd")

class GenerationResult:
	var mesh: ArrayMesh
	var height: float
	var flower_count: int
	var stage_name: String
	var center_position: Vector3
	var flower_positions: Array[Vector3] = []
	var triangle_count: int = 0
	var vertex_count: int = 0

static func generate_flower(profile_id: String, seed_val: int, growth: float, color_idx: int = -1, lod_level: int = 0) -> GenerationResult:
	var profile: Dictionary = FlowerProfiles.get_profile(profile_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var result := GenerationResult.new()
	growth = clampf(growth, 0.0, 1.0)
	
	# Determinar etapa botánica
	var stages: Dictionary = profile["growth_stages"]
	var stage_name := "Floración"
	if growth <= stages["sprout_end"]:
		stage_name = "Brote"
	elif growth <= stages["veg_end"]:
		stage_name = "Vegetativo"
	elif growth <= stages["bud_end"]:
		stage_name = "Capullo"
	result.stage_name = stage_name
	
	# Escala de altura final según perfil y semilla
	var target_height: float = rng.randf_range(profile["min_height"], profile["max_height"])
	
	# Altura según curva de crecimiento:
	# En brote: apenas 5-10% de la altura total
	# En vegetativo: escala del 10% al 85%
	# En capullo/flor: 85% al 100%
	var current_height: float = 0.05
	if growth <= float(stages["sprout_end"]):
		var t: float = growth / maxf(float(stages["sprout_end"]), 0.01)
		current_height = lerpf(0.03, target_height * 0.12, t)
	elif growth <= float(stages["veg_end"]):
		var t: float = (growth - float(stages["sprout_end"])) / (float(stages["veg_end"]) - float(stages["sprout_end"]))
		current_height = lerpf(target_height * 0.12, target_height * 0.85, t)
	else:
		var t: float = (growth - float(stages["veg_end"])) / (1.0 - float(stages["veg_end"]))
		current_height = lerpf(target_height * 0.85, target_height, t)
	
	result.height = current_height
	
	# Selección de paleta de color para la flor
	var palettes: Array = profile["color_palettes"]
	var flower_color: Color = palettes[0]
	if color_idx >= 0 and color_idx < palettes.size():
		flower_color = palettes[color_idx]
	else:
		flower_color = palettes[rng.randi() % palettes.size()]
	
	# SurfaceTools:
	# st_veg: Tallos, ramas, espinas y hojas (Material vegetal)
	# st_flower: Capullos, pétalos y centros (Material floral)
	var st_veg := SurfaceTool.new()
	var st_flower := SurfaceTool.new()
	st_veg.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_flower.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var morphology: String = profile["morphology"]
	var is_rose: bool = profile.get("is_rose", false)
	
	if is_rose and morphology == FlowerProfiles.MORPHOLOGY_SOLITARY:
		_generate_solitary_rose(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result, lod_level)
	elif is_rose and morphology == FlowerProfiles.MORPHOLOGY_SHRUB:
		_generate_shrub_rose(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result, lod_level)
	elif lod_level == 1:
		_generate_generic_lod1(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result)
	elif lod_level >= 2:
		_generate_generic_lod2(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result)
	else:
		match morphology:
			FlowerProfiles.MORPHOLOGY_SHRUB:
				_generate_shrub(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result)
			FlowerProfiles.MORPHOLOGY_CLUSTER:
				_generate_cluster(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result)
			FlowerProfiles.MORPHOLOGY_SPIKE:
				_generate_spike(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result)
			FlowerProfiles.MORPHOLOGY_SOLITARY:
				_generate_solitary(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result)
			FlowerProfiles.MORPHOLOGY_FOCAL:
				_generate_focal(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result)
			_:
				_generate_solitary(st_veg, st_flower, profile, rng, current_height, growth, stages, flower_color, result)
	
	# Generar mallas combinadas con indexación para rendimiento óptimo
	var mesh := ArrayMesh.new()
	var total_tris := 0
	var total_verts := 0
	
	if lod_level == 0:
		st_veg.generate_normals()
	st_veg.index()
	var veg_array = st_veg.commit_to_arrays()
	if veg_array.size() > Mesh.ARRAY_VERTEX and veg_array[Mesh.ARRAY_VERTEX] != null:
		var verts: PackedVector3Array = veg_array[Mesh.ARRAY_VERTEX]
		if verts.size() > 0:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, veg_array)
			total_verts += verts.size()
			if veg_array.size() > Mesh.ARRAY_INDEX and veg_array[Mesh.ARRAY_INDEX] != null and veg_array[Mesh.ARRAY_INDEX].size() > 0:
				var indices: PackedInt32Array = veg_array[Mesh.ARRAY_INDEX]
				total_tris += indices.size() / 3
			else:
				total_tris += verts.size() / 3
	
	# Superficie 1: Flores (preserva _material_flower en todos los LODs con backlight y brillo sedoso)
	if result.flower_count > 0:
		if lod_level == 0:
			st_flower.generate_normals()
		st_flower.index()
		var flower_array = st_flower.commit_to_arrays()
		if flower_array.size() > Mesh.ARRAY_VERTEX and flower_array[Mesh.ARRAY_VERTEX] != null:
			var verts: PackedVector3Array = flower_array[Mesh.ARRAY_VERTEX]
			if verts.size() > 0:
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flower_array)
				total_verts += verts.size()
				if flower_array.size() > Mesh.ARRAY_INDEX and flower_array[Mesh.ARRAY_INDEX] != null and flower_array[Mesh.ARRAY_INDEX].size() > 0:
					var indices: PackedInt32Array = flower_array[Mesh.ARRAY_INDEX]
					total_tris += indices.size() / 3
				else:
					total_tris += verts.size() / 3
	
	result.triangle_count = total_tris
	result.vertex_count = total_verts
	result.mesh = mesh
	return result

# ==============================================================================
# MORFOLOGÍAS BOTÁNICAS
# ==============================================================================

## 0A. ROSA DE CORTE (Solitary Rose): Tallo esbelto erguido, espinas curvadas, hojas compuestas con pecíolo, receptáculo, sépalos y gran rosa aterciopelada
static func _generate_solitary_rose(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult, lod_level: int = 0) -> void:
	if growth <= stages["sprout_end"]:
		_build_sprout(st_veg, height, profile)
		return
	
	# Usamos un generador determinista para el esqueleto basado en rng.seed
	# para garantizar que tallo y flor estén exactamente en las mismas coordenadas en todos los LODs.
	var skel_rng := RandomNumberGenerator.new()
	skel_rng.seed = rng.seed
	
	# Tallo erguido con leve curvatura orgánica natural (sin quiebres bruscos)
	var lean_angle: float = skel_rng.randf_range(0, TAU)
	var lean_dist: float = skel_rng.randf_range(0.008, 0.018)
	var lean_dir := Vector3(cos(lean_angle) * lean_dist, 0, sin(lean_angle) * lean_dist)
	
	var p0 := Vector3.ZERO
	var p1 := Vector3(lean_dir.x * 0.25, height * 0.33, lean_dir.z * 0.25)
	var p2 := Vector3(lean_dir.x * 0.70, height * 0.68, lean_dir.z * 0.70)
	var p3 := Vector3(lean_dir.x, height, lean_dir.z)
	var stem_pts := [p0, p1, p2, p3]
	var up_dir: Vector3 = (p3 - p2).normalized()
	
	if lod_level == 0:
		# Tallo principal robusto con gradiente leñoso en la base a verde arriba
		_build_curved_stem(st_veg, stem_pts, profile["stem_radius"], profile["stem_woody_color"], profile["stem_color"])
		# Espinas afiladas con gancho curvado hacia abajo
		if profile.get("has_thorns", false) and growth > float(stages["veg_end"]) * 0.5:
			_build_rose_hooked_thorns(st_veg, p0, p3, profile["stem_radius"], profile["thorn_color"], rng, growth)
		# Hojas compuestas con pecíolos (ramillas con foliolos plegados)
		_build_rose_compound_foliage(st_veg, p0, p3, profile, rng, growth)
		# Receptáculo y los 5 sépalos arqueados
		_build_rose_calyx(st_veg, p3, up_dir, profile, growth, stages)
		# Flor de Rosa de Alta Fidelidad en capas espiraladas
		if growth > stages["veg_end"]:
			_build_rose_bloom(st_flower, p3, up_dir, profile, rng, growth, stages, flower_color)
			result.flower_count = 1
			result.flower_positions.append(p3)
	elif lod_level == 1:
		# Tallo plano billboard con rotación axial en GPU
		_build_billboard_stem(st_veg, stem_pts, profile["stem_radius"] * 1.1, profile["stem_woody_color"], profile["stem_color"])
		# Hojas en triángulos 2D billboard
		_build_rose_compound_foliage_lod(st_veg, p0, p3, profile, growth, 1)
		# Flor terminal como Prisma Pentagonal 3D con sombreado de rosa rico o Capullo cerrado
		if growth > stages["veg_end"]:
			if growth <= stages["bud_end"]:
				_build_bud_billboard_quad(st_flower, p3, profile["flower_radius"] * 0.55, flower_color)
			else:
				var r: float = profile["flower_radius"] * 1.28 * clampf(growth, 0.5, 1.0)
				var h: float = profile["flower_radius"] * 1.55 * clampf(growth, 0.5, 1.0)
				_build_pentagon_prism_flower(st_flower, p3, up_dir, r, h, flower_color)
			result.flower_count = 1
			result.flower_positions.append(p3)
	else: # lod_level >= 2
		# Tallo plano billboard simplificado
		_build_billboard_stem(st_veg, [p0, p2, p3], profile["stem_radius"] * 1.2, profile["stem_woody_color"], profile["stem_color"])
		# Hojas en triángulo 2D billboard
		_build_rose_compound_foliage_lod(st_veg, p0, p3, profile, growth, 2)
		# Flor terminal como 1 solo triángulo 2D billboard con resalte y terciopelo
		if growth > stages["veg_end"]:
			if growth <= stages["bud_end"]:
				_build_bud_billboard_triangle(st_flower, p3, profile["flower_radius"] * 0.55, flower_color)
			else:
				var r: float = profile["flower_radius"] * 1.25 * clampf(growth, 0.5, 1.0)
				_build_triangle_billboard_flower(st_flower, p3, r, flower_color)
			result.flower_count = 1
			result.flower_positions.append(p3)

## 0B. ROSAL ARBUSTIVO (Shrub Rose): Arbusto denso, frondoso y voluptuoso con separación garantizada entre rosas
static func _generate_shrub_rose(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult, lod_level: int = 0) -> void:
	if growth <= stages["sprout_end"]:
		_build_sprout(st_veg, height, profile)
		return
	
	var total_flowers := 0
	var min_flower_distance: float = 0.20 # Separación limpia para evitar flores empalmadas
	var cane_radius: float = profile["stem_radius"]
	
	# Usamos un generador determinista para el esqueleto (basado en rng.seed)
	# para garantizar que cañas, ramas y flores estén en coordenadas IDÉNTICAS en los 3 LODs.
	var skel_rng := RandomNumberGenerator.new()
	skel_rng.seed = rng.seed
	
	# --- 1. FALDA BASAL DE COBERTURA (4 brotes que cubren la base) ---
	var num_basal_shoots := 4
	for b in range(num_basal_shoots):
		var b_angle: float = (TAU / float(num_basal_shoots)) * float(b) + skel_rng.randf_range(-0.25, 0.25)
		var b_len: float = height * skel_rng.randf_range(0.38, 0.50) * clampf(growth * 1.3, 0.35, 1.0)
		var b_spread: float = b_len * skel_rng.randf_range(0.80, 0.95)
		var bp0 := Vector3.ZERO
		var bp1 := Vector3(cos(b_angle) * (b_spread * 0.50), b_len * 0.30, sin(b_angle) * (b_spread * 0.50))
		var bp2 := Vector3(cos(b_angle) * b_spread, b_len * 0.42, sin(b_angle) * b_spread)
		var b_pts := [bp0, bp1, bp2]
		
		if lod_level == 0:
			_build_curved_stem(st_veg, b_pts, cane_radius * 0.55, profile["stem_woody_color"], profile["stem_color"], 3)
			_build_rose_dense_shrub_foliage(st_veg, b_pts, profile, rng, growth, 3)
		elif lod_level == 1:
			_build_billboard_stem(st_veg, b_pts, cane_radius * 0.65, profile["stem_woody_color"], profile["stem_color"])
			_build_rose_foliage_lod(st_veg, b_pts, profile, growth, 2)
		else: # lod_level >= 2
			_build_billboard_stem(st_veg, [bp0, bp2], cane_radius * 0.65, profile["stem_woody_color"], profile["stem_color"])
			_build_rose_foliage_lod(st_veg, [bp0, bp2], profile, growth, 1)
	
	# --- 2. CAÑAS DEL ARBUSTO (Domo exterior y centro) ---
	var num_outer_canes: int = 5
	var num_inner_canes: int = 2
	var cane_data: Array = []
	
	# A. Cañas Perimetrales (arquitectura abierta en copa/domo: 80% a 90% altura)
	for i in range(num_outer_canes):
		var cane_angle: float = (TAU / float(num_outer_canes)) * float(i) + skel_rng.randf_range(-0.2, 0.2)
		var cane_h: float = height * skel_rng.randf_range(0.80, 0.90)
		var spread_dist: float = cane_h * skel_rng.randf_range(0.42, 0.52)
		var p0 := Vector3.ZERO
		var p1 := Vector3(cos(cane_angle) * (spread_dist * 0.25), cane_h * 0.32, sin(cane_angle) * (spread_dist * 0.25))
		var p2 := Vector3(cos(cane_angle) * (spread_dist * 0.72), cane_h * 0.70, sin(cane_angle) * (spread_dist * 0.72))
		var tip_pos := Vector3(cos(cane_angle) * spread_dist, cane_h * 0.94, sin(cane_angle) * spread_dist)
		cane_data.append({"pts": [p0, p1, p2, tip_pos], "h": cane_h, "angle": cane_angle, "tier": "outer"})
	
	# B. Cañas Centrales (erguidas, coronando el centro: 95% a 102% altura)
	for i in range(num_inner_canes):
		var cane_angle: float = (TAU / float(num_inner_canes)) * float(i) + skel_rng.randf_range(0.3, 0.8)
		var cane_h: float = height * skel_rng.randf_range(0.95, 1.02)
		var spread_dist: float = cane_h * skel_rng.randf_range(0.12, 0.20)
		var p0 := Vector3.ZERO
		var p1 := Vector3(cos(cane_angle) * (spread_dist * 0.20), cane_h * 0.35, sin(cane_angle) * (spread_dist * 0.20))
		var p2 := Vector3(cos(cane_angle) * (spread_dist * 0.60), cane_h * 0.75, sin(cane_angle) * (spread_dist * 0.60))
		var tip_pos := Vector3(cos(cane_angle) * spread_dist, cane_h * 0.98, sin(cane_angle) * spread_dist)
		cane_data.append({"pts": [p0, p1, p2, tip_pos], "h": cane_h, "angle": cane_angle, "tier": "inner"})
	
	# --- 3. CONSTRUCCIÓN DE CAÑAS, ESPUELAS VEGETATIVAS, RAMAS FLORALES Y FLORES ---
	for c_idx in range(cane_data.size()):
		var data: Dictionary = cane_data[c_idx]
		var cane_pts: Array = data["pts"]
		var cane_h: float = float(data["h"])
		var cane_angle: float = float(data["angle"])
		var tier: String = String(data["tier"])
		var p0: Vector3 = cane_pts[0]
		var p1: Vector3 = cane_pts[1]
		var p2: Vector3 = cane_pts[2]
		var tip_pos: Vector3 = cane_pts[3]
		var c_radius: float = cane_radius * skel_rng.randf_range(0.92, 1.15)
		
		# Caña principal
		if lod_level == 0:
			_build_curved_stem(st_veg, cane_pts, c_radius, profile["stem_woody_color"], profile["stem_color"], 3)
			if profile.get("has_thorns", false) and tier == "outer" and growth > float(stages["veg_end"]) * 0.45:
				_build_rose_hooked_thorns(st_veg, p0, tip_pos, c_radius, profile["thorn_color"], rng, growth)
			_build_rose_dense_shrub_foliage(st_veg, cane_pts, profile, rng, growth, 4)
		elif lod_level == 1:
			_build_billboard_stem(st_veg, cane_pts, c_radius * 1.15, profile["stem_woody_color"], profile["stem_color"])
			_build_rose_foliage_lod(st_veg, cane_pts, profile, growth, 3)
		else: # lod_level >= 2
			_build_billboard_stem(st_veg, [p0, p1, tip_pos], c_radius * 1.25, profile["stem_woody_color"], profile["stem_color"])
			_build_rose_foliage_lod(st_veg, [p0, p1, tip_pos], profile, growth, 1)
		
		# Espuela lateral en el tercio inferior para volumen bajo
		if growth > float(stages["veg_end"]) * 0.50 and tier == "outer":
			var s_base: Vector3 = _interpolate_spline_points(cane_pts, 0.40)
			var s_side_sign: float = 1.0 if c_idx % 2 == 0 else -1.0
			var s_rad := Vector3(cos(cane_angle), 0, sin(cane_angle)).normalized()
			var s_tan := s_rad.cross(Vector3.UP).normalized()
			var s_dir := (s_rad * 0.35 + s_tan * (0.80 * s_side_sign) + Vector3(0, 0.20, 0)).normalized()
			var s_len: float = cane_h * 0.20 * clampf(growth * 1.2, 0.4, 1.0)
			var s_tip: Vector3 = s_base + s_dir * s_len
			
			if lod_level == 0:
				_build_curved_stem(st_veg, [s_base, s_tip], c_radius * 0.52, profile["stem_woody_color"], profile["stem_color"], 3)
				_build_rose_dense_shrub_foliage(st_veg, [s_base, s_tip], profile, rng, growth, 2)
			elif lod_level == 1:
				_build_billboard_stem(st_veg, [s_base, s_tip], c_radius * 0.60, profile["stem_woody_color"], profile["stem_color"])
				_build_rose_foliage_lod(st_veg, [s_base, s_tip], profile, growth, 1)
			else:
				_build_billboard_stem(st_veg, [s_base, s_tip], c_radius * 0.65, profile["stem_woody_color"], profile["stem_color"])
		
		# Rama floral lateral en cañas perimetrales alternadas
		if tier == "outer" and (c_idx % 2 == 0) and growth > float(stages["veg_end"]) * 0.72:
			var branch_base: Vector3 = _interpolate_spline_points(cane_pts, 0.65)
			var rad_dir := Vector3(cos(cane_angle), 0, sin(cane_angle)).normalized()
			var side_dir := rad_dir.cross(Vector3.UP).normalized()
			var side_sign: float = -1.0 if c_idx == 0 else 1.0
			var branch_dir := (rad_dir * 0.30 + side_dir * (0.85 * side_sign) + Vector3(0, 0.28, 0)).normalized()
			var branch_len: float = cane_h * 0.24 * clampf(growth * 1.2, 0.4, 1.0)
			var branch_tip: Vector3 = branch_base + branch_dir * branch_len
			var b_up := (branch_dir + Vector3(0, 0.45, 0)).normalized()
			
			if lod_level == 0:
				_build_curved_stem(st_veg, [branch_base, branch_tip], c_radius * 0.58, profile["stem_color"], profile["stem_color"], 3)
				_build_rose_dense_shrub_foliage(st_veg, [branch_base, branch_tip], profile, rng, growth, 2)
			elif lod_level == 1:
				_build_billboard_stem(st_veg, [branch_base, branch_tip], c_radius * 0.65, profile["stem_color"], profile["stem_color"])
				_build_rose_foliage_lod(st_veg, [branch_base, branch_tip], profile, growth, 1)
			else:
				_build_billboard_stem(st_veg, [branch_base, branch_tip], c_radius * 0.70, profile["stem_color"], profile["stem_color"])
			
			# Comprobación estricta de distancia antes de colocar una flor lateral
			if growth > float(stages["veg_end"]):
				if _can_place_flower(branch_tip, result.flower_positions, min_flower_distance):
					total_flowers += 1
					result.flower_positions.append(branch_tip)
					
					var stage_roll: float = skel_rng.randf()
					var is_lat_bud: bool = (growth <= float(stages["bud_end"])) or (stage_roll >= 0.70)
					
					if lod_level == 0:
						_build_rose_calyx(st_veg, branch_tip, b_up, profile, growth, stages)
						if is_lat_bud:
							_build_rose_bud(st_flower, branch_tip, b_up, profile["flower_radius"] * 0.50, flower_color)
						else:
							_build_rose_sub_flower_collar(st_veg, branch_tip, b_up, profile, growth)
							var scale_f: float = 1.0 if stage_roll < 0.40 else skel_rng.randf_range(0.70, 0.88)
							_build_rose_bloom(st_flower, branch_tip, b_up, profile, rng, growth, stages, flower_color, scale_f)
					elif lod_level == 1:
						if is_lat_bud:
							_build_bud_billboard_quad(st_flower, branch_tip, profile["flower_radius"] * 0.50, flower_color)
						else:
							var r_lat: float = profile["flower_radius"] * 1.15 * clampf(growth, 0.5, 1.0)
							var h_lat: float = profile["flower_radius"] * 1.40 * clampf(growth, 0.5, 1.0)
							_build_pentagon_prism_flower(st_flower, branch_tip, b_up, r_lat, h_lat, flower_color)
					else: # lod_level >= 2
						if is_lat_bud:
							_build_bud_billboard_triangle(st_flower, branch_tip, profile["flower_radius"] * 0.50, flower_color)
						else:
							var r_lat: float = profile["flower_radius"] * 1.15 * clampf(growth, 0.5, 1.0)
							_build_triangle_billboard_flower(st_flower, branch_tip, r_lat, flower_color)
		
		# Flor terminal en la punta de la caña
		if growth > float(stages["veg_end"]):
			if _can_place_flower(tip_pos, result.flower_positions, min_flower_distance):
				var bloom_up := (tip_pos - p2).normalized().lerp(Vector3.UP, 0.40).normalized()
				total_flowers += 1
				result.flower_positions.append(tip_pos)
				
				var term_roll: float = skel_rng.randf()
				var is_term_bud: bool = (growth <= float(stages["bud_end"])) or (term_roll >= 0.70)
				
				if lod_level == 0:
					_build_rose_calyx(st_veg, tip_pos, bloom_up, profile, growth, stages)
					if is_term_bud:
						_build_rose_bud(st_flower, tip_pos, bloom_up, profile["flower_radius"] * 0.55, flower_color)
					else:
						_build_rose_sub_flower_collar(st_veg, tip_pos, bloom_up, profile, growth)
						var scale_f: float = 1.0 if term_roll < 0.40 else skel_rng.randf_range(0.75, 0.90)
						_build_rose_bloom(st_flower, tip_pos, bloom_up, profile, rng, growth, stages, flower_color, scale_f)
				elif lod_level == 1:
					if is_term_bud:
						_build_bud_billboard_quad(st_flower, tip_pos, profile["flower_radius"] * 0.55, flower_color)
					else:
						var r_c: float = profile["flower_radius"] * 1.28 * clampf(growth, 0.5, 1.0)
						var h_c: float = profile["flower_radius"] * 1.55 * clampf(growth, 0.5, 1.0)
						_build_pentagon_prism_flower(st_flower, tip_pos, bloom_up, r_c, h_c, flower_color)
				else: # lod_level >= 2
					if is_term_bud:
						_build_bud_billboard_triangle(st_flower, tip_pos, profile["flower_radius"] * 0.55, flower_color)
					else:
						var r_c: float = profile["flower_radius"] * 1.25 * clampf(growth, 0.5, 1.0)
						_build_triangle_billboard_flower(st_flower, tip_pos, r_c, flower_color)
	
	result.flower_count = total_flowers

## 1. ARBUSTO GENÉRICO (Shrub)
static func _generate_shrub(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult) -> void:
	if growth <= stages["sprout_end"]:
		_build_sprout(st_veg, height, profile)
		return
	
	var num_canes: int = rng.randi_range(3, 5) # 3 a 5 cañas leñosas principales
	var total_flowers := 0
	
	for i in range(num_canes):
		var cane_angle: float = (TAU / float(num_canes)) * float(i) + rng.randf_range(-0.35, 0.35)
		var cane_h: float = height * rng.randf_range(0.78, 1.0)
		var cane_radius: float = profile["stem_radius"] * rng.randf_range(0.9, 1.15)
		
		# Curvatura arqueada natural del rosal (base erguida, arco hacia afuera)
		var spread_dist: float = cane_h * rng.randf_range(0.32, 0.46)
		var p0 := Vector3.ZERO
		var p1 := Vector3(cos(cane_angle) * (spread_dist * 0.25), cane_h * 0.32, sin(cane_angle) * (spread_dist * 0.25))
		var p2 := Vector3(cos(cane_angle) * (spread_dist * 0.78), cane_h * 0.72, sin(cane_angle) * (spread_dist * 0.78))
		var tip_pos := Vector3(cos(cane_angle) * spread_dist, cane_h * 0.96, sin(cane_angle) * spread_dist)
		
		var cane_pts := [p0, p1, p2, tip_pos]
		
		# Caña leñosa suave
		_build_curved_stem(st_veg, cane_pts, cane_radius, profile["stem_woody_color"], profile["stem_color"])
		
		# Espinas afiladas a lo largo de la caña leñosa
		if profile.get("has_thorns", false) and growth > stages["veg_end"] * 0.6:
			_build_thorns(st_veg, cane_pts, cane_radius, profile["thorn_color"], rng)
		
		# Hojas compuestas de rosal (ramilletes trifoliados)
		_build_leaves_along_curve(st_veg, cane_pts, profile["leaf_size"], profile["leaf_color"], rng, 6, growth, profile)
		
		# Rama lateral secundaria en cañas largas maduras
		if growth > float(stages["veg_end"]) * 0.85 and rng.randf() < 0.65:
			var branch_dir := (tip_pos - p1).normalized().rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
			var branch_tip := p2 + branch_dir * (cane_h * 0.28) + Vector3(0, 0.05, 0)
			_build_curved_stem(st_veg, [p2, branch_tip], cane_radius * 0.65, profile["stem_color"], profile["stem_color"])
			_build_leaves_along_curve(st_veg, [p2, branch_tip], profile["leaf_size"] * 0.85, profile["leaf_color"], rng, 3, growth, profile)
			
			if growth > stages["veg_end"]:
				_build_flower_head(st_flower, branch_tip, (branch_tip - p2).normalized(), profile, rng, growth, stages, flower_color)
				total_flowers += 1
				result.flower_positions.append(branch_tip)
		
		# Flor o capullo en la punta de cada caña principal
		if growth > stages["veg_end"]:
			var bloom_up := (tip_pos - p2).normalized().lerp(Vector3.UP, 0.45).normalized()
			_build_flower_head(st_flower, tip_pos, bloom_up, profile, rng, growth, stages, flower_color)
			total_flowers += 1
			result.flower_positions.append(tip_pos)
	
	result.flower_count = total_flowers

## 2. MARGARITAS (Cluster): Roseta basal de hojas, abanico de tallos delgados con margaritas
static func _generate_cluster(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult) -> void:
	if growth <= stages["sprout_end"]:
		_build_sprout(st_veg, height, profile)
		return
	
	var count: int = rng.randi_range(profile["flower_count_min"], profile["flower_count_max"])
	
	# Roseta basal de hojas en el piso
	var basal_leaves: int = rng.randi_range(8, 14)
	for i in range(basal_leaves):
		var a: float = (TAU / float(basal_leaves)) * float(i) + rng.randf_range(-0.2, 0.2)
		var leaf_dir := Vector3(cos(a), 0.15, sin(a)).normalized()
		var leaf_len: float = profile["leaf_size"].x * rng.randf_range(0.8, 1.2) * clampf(growth * 1.8, 0.2, 1.0)
		_build_creased_leaf(st_veg, Vector3.ZERO, leaf_dir, leaf_len, profile["leaf_size"].y, profile["leaf_color"])
	
	var total_flowers := 0
	for i in range(count):
		var angle: float = rng.randf_range(0, TAU)
		var dist: float = rng.randf_range(0.02, 0.12)
		var stem_h: float = height * rng.randf_range(0.65, 1.0)
		
		var base := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var lean: float = rng.randf_range(0.04, 0.10)
		var tip := base + Vector3(cos(angle) * lean, stem_h, sin(angle) * lean)
		var mid := base + (tip - base) * 0.5 + Vector3(rng.randf_range(-0.02, 0.02), 0, rng.randf_range(-0.02, 0.02))
		
		_build_curved_stem(st_veg, [base, mid, tip], profile["stem_radius"], profile["stem_color"], profile["stem_color"])
		
		if growth > stages["veg_end"]:
			_build_flower_head(st_flower, tip, (tip - mid).normalized(), profile, rng, growth, stages, flower_color)
			total_flowers += 1
			result.flower_positions.append(tip)
	
	result.flower_count = total_flowers

## 3. LAVANDA (Spike): Espigas verticales de florecillas apiladas
static func _generate_spike(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult) -> void:
	if growth <= stages["sprout_end"]:
		_build_sprout(st_veg, height, profile)
		return
	
	var stem_count: int = rng.randi_range(profile["flower_count_min"], profile["flower_count_max"])
	var total_flowers := 0
	
	for i in range(stem_count):
		var angle: float = (TAU / float(stem_count)) * float(i) + rng.randf_range(-0.25, 0.25)
		var base_dist: float = rng.randf_range(0.03, 0.08)
		var stem_h: float = height * rng.randf_range(0.8, 1.0)
		
		var base := Vector3(cos(angle) * base_dist, 0.0, sin(angle) * base_dist)
		var tip := base + Vector3(cos(angle) * 0.06, stem_h, sin(angle) * 0.06)
		var mid := (base + tip) * 0.5
		
		_build_curved_stem(st_veg, [base, mid, tip], profile["stem_radius"], profile["stem_woody_color"], profile["stem_color"])
		
		# Hojas estrechas lineales en la mitad inferior
		var leaf_nodes: int = 4
		for l in range(leaf_nodes):
			var frac: float = float(l) / float(leaf_nodes) * 0.5 + 0.1
			var pos: Vector3 = base.lerp(tip, frac)
			var l_dir := Vector3(cos(angle + l * 1.2), 0.4, sin(angle + l * 1.2)).normalized()
			_build_creased_leaf(st_veg, pos, l_dir, profile["leaf_size"].x, profile["leaf_size"].y, profile["leaf_color"])
		
		# Espiga de flores en el tercio superior
		if growth > stages["veg_end"]:
			var spike_len: float = profile["spike_length"] * clampf((growth - stages["veg_end"]) / (1.0 - stages["veg_end"]), 0.2, 1.0)
			_build_lavender_spike(st_flower, tip, spike_len, profile, rng, growth, stages, flower_color)
			total_flowers += 1
			result.flower_positions.append(tip)
	
	result.flower_count = total_flowers

## 4. AMAPOLA (Solitary): Tallo esbelto único con gran flor en copa
static func _generate_solitary(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult) -> void:
	if growth <= stages["sprout_end"]:
		_build_sprout(st_veg, height, profile)
		return
	
	# Curva elegante sinuosa típica de la amapola
	var curve_dir := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)).normalized()
	var p0 := Vector3.ZERO
	var p1 := Vector3(curve_dir.x * 0.06, height * 0.35, curve_dir.z * 0.06)
	var p2 := Vector3(-curve_dir.x * 0.04, height * 0.70, -curve_dir.z * 0.04)
	var p3 := Vector3(curve_dir.x * 0.02, height, curve_dir.z * 0.02)
	
	_build_curved_stem(st_veg, [p0, p1, p2, p3], profile["stem_radius"], profile["stem_color"], profile["stem_color"])
	
	# Espinas si el perfil las requiere (Rosal de corte)
	if profile.get("has_thorns", false) and growth > float(stages["veg_end"]) * 0.7:
		_build_thorns(st_veg, [p0, p1, p2, p3], profile["stem_radius"], profile["thorn_color"], rng)

	# Hojas a lo largo del tallo
	_build_leaves_along_curve(st_veg, [p0, p1, p2], profile["leaf_size"], profile["leaf_color"], rng, 3, growth)
	
	if growth > stages["veg_end"]:
		var up_dir: Vector3 = (p3 - p2).normalized()
		_build_flower_head(st_flower, p3, up_dir, profile, rng, growth, stages, flower_color)
		result.flower_count = 1
		result.flower_positions.append(p3)

## 5. GIRASOL (Focal): Tallo robusto, hojas acorazonadas y flor discoide gigante
static func _generate_focal(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult) -> void:
	if growth <= stages["sprout_end"]:
		_build_sprout(st_veg, height, profile)
		return
	
	var lean_dir := Vector3(0.15, 0, 0.05) # Orientación hacia el sol
	var p0 := Vector3.ZERO
	var p1 := Vector3(lean_dir.x * 0.3, height * 0.45, lean_dir.z * 0.3)
	var p2 := Vector3(lean_dir.x * 0.8, height * 0.85, lean_dir.z * 0.8)
	var p3 := Vector3(lean_dir.x * 1.0, height, lean_dir.z * 1.0)
	
	_build_curved_stem(st_veg, [p0, p1, p2, p3], profile["stem_radius"], profile["stem_color"], profile["stem_color"])
	
	# Grandes hojas alternas
	var num_leaves: int = int(lerpf(2, 6, growth))
	for i in range(num_leaves):
		var t: float = float(i + 1) / float(num_leaves + 1) * 0.75
		var pos: Vector3 = p0.lerp(p3, t)
		var angle: float = float(i) * 2.4 # Filotaxis áurea
		var leaf_dir := Vector3(cos(angle), 0.2, sin(angle)).normalized()
		var leaf_w: float = profile["leaf_size"].y * clampf(growth, 0.3, 1.0)
		var leaf_l: float = profile["leaf_size"].x * clampf(growth, 0.3, 1.0)
		_build_creased_leaf(st_veg, pos, leaf_dir, leaf_l, leaf_w, profile["leaf_color"])
	
	# Enorme cabeza solar inclinada
	if growth > stages["veg_end"]:
		var face_dir := (lean_dir + Vector3(0, 0.3, 0)).normalized()
		_build_sunflower_head(st_flower, p3, face_dir, profile, rng, growth, stages, flower_color)
		result.flower_count = 1
		result.flower_positions.append(p3)

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS
# ==============================================================================

## Brote bebé (Etapa 0): Diminuto tallo con 2 hojas cotiledones
static func _build_sprout(st_veg: SurfaceTool, height: float, profile: Dictionary) -> void:
	var tip := Vector3(0, height, 0)
	_build_curved_stem(st_veg, [Vector3.ZERO, tip], profile["stem_radius"] * 0.6, profile["stem_color"], profile["stem_color"])
	
	# 2 hojitas redondeadas a los lados
	var leaf_sz: float = height * 0.6
	_build_creased_leaf(st_veg, tip, Vector3(1, 0.2, 0).normalized(), leaf_sz, leaf_sz * 0.7, profile["leaf_color"])
	_build_creased_leaf(st_veg, tip, Vector3(-1, 0.2, 0).normalized(), leaf_sz, leaf_sz * 0.7, profile["leaf_color"])

## Tallo de sección triangular (3 lados) o rectangular (4 lados) hiper-optimizado (PSX low-poly con Gouraud suave)
static func _build_curved_stem(st: SurfaceTool, points: Array, radius: float, base_color: Color, tip_color: Color, sides: int = 3) -> void:
	if points.size() < 2:
		return
	
	var ring_angles: Array[float] = []
	for i in range(sides):
		ring_angles.append((TAU / float(sides)) * float(i))
	
	var prev_ring: Array[Vector3] = []
	
	for p_idx in range(points.size()):
		var pt: Vector3 = points[p_idx]
		var t: float = float(p_idx) / float(points.size() - 1)
		var current_r: float = radius * lerpf(1.0, 0.65, t)
		var seg_color: Color = base_color.lerp(tip_color, t)
		
		# Orientación del anillo perpendicular a la dirección
		var fwd := Vector3.UP
		if p_idx < points.size() - 1:
			fwd = (points[p_idx + 1] - pt).normalized()
		else:
			fwd = (pt - points[p_idx - 1]).normalized()
		
		var right: Vector3 = fwd.cross(Vector3.FORWARD).normalized()
		if right.length_squared() < 0.01:
			right = fwd.cross(Vector3.RIGHT).normalized()
		var up: Vector3 = right.cross(fwd).normalized()
		
		var current_ring: Array[Vector3] = []
		for a in ring_angles:
			var offset: Vector3 = (right * cos(a) + up * sin(a)) * current_r
			current_ring.append(pt + offset)
		
		if prev_ring.size() > 0:
			for s in range(sides):
				var next_s: int = (s + 1) % sides
				var v00: Vector3 = prev_ring[s]
				var v01: Vector3 = prev_ring[next_s]
				var v10: Vector3 = current_ring[s]
				var v11: Vector3 = current_ring[next_s]
				
				st.set_color(seg_color)
				st.set_uv(Vector2(float(s) / float(sides), t - 0.2))
				st.add_vertex(v00)
				st.add_vertex(v10)
				st.add_vertex(v11)
				
				st.add_vertex(v00)
				st.add_vertex(v11)
				st.add_vertex(v01)
		
		prev_ring = current_ring

## Pecíolo plano ultraligero (exactamente 1 cuadrilátero / 2 triángulos)
static func _build_petiole_quad(st: SurfaceTool, p_start: Vector3, p_end: Vector3, width: float, color: Color) -> void:
	var fwd := (p_end - p_start).normalized()
	var right := fwd.cross(Vector3.UP).normalized() * (width * 0.5)
	if right.length_squared() < 0.0001:
		right = fwd.cross(Vector3.RIGHT).normalized() * (width * 0.5)
	
	st.set_color(color)
	st.add_vertex(p_start - right)
	st.add_vertex(p_end - right)
	st.add_vertex(p_end + right)
	
	st.add_vertex(p_start - right)
	st.add_vertex(p_end + right)
	st.add_vertex(p_start + right)

## Hoja con silueta elíptica anatómica, nervio central en V y sombreado de foliolo
static func _build_creased_leaf(st: SurfaceTool, base_pos: Vector3, direction: Vector3, length: float, width: float, color: Color) -> void:
	var fwd: Vector3 = direction.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = fwd.cross(Vector3.RIGHT).normalized()
	var normal_up: Vector3 = right.cross(fwd).normalized()
	
	# Vértices del foliolo elíptico (base, vientre medio, hombros y punta lanceolada)
	var v_base: Vector3 = base_pos
	var v_tip: Vector3 = base_pos + fwd * length
	
	var mid_dist: float = length * 0.42
	var v_mid_vein: Vector3 = base_pos + fwd * mid_dist
	
	# Alas izquierda y derecha en el vientre más ancho
	var fold_lift: float = width * 0.22
	var v_mid_l: Vector3 = v_mid_vein - right * (width * 0.50) + normal_up * fold_lift
	var v_mid_r: Vector3 = v_mid_vein + right * (width * 0.50) + normal_up * fold_lift
	
	# Hombros superiores antes de converger en la punta
	var sh_dist: float = length * 0.72
	var v_sh_vein: Vector3 = base_pos + fwd * sh_dist
	var v_sh_l: Vector3 = v_sh_vein - right * (width * 0.38) + normal_up * (fold_lift * 0.8)
	var v_sh_r: Vector3 = v_sh_vein + right * (width * 0.38) + normal_up * (fold_lift * 0.8)
	
	var c_vein: Color = color.darkened(0.28) # Nervio central oscuro
	var c_blade: Color = color               # Limbo de la hoja
	
	# 1. Base a vientre medio (ala izquierda y derecha)
	st.set_color(c_vein)
	st.add_vertex(v_base)
	st.set_color(c_blade)
	st.add_vertex(v_mid_l)
	st.set_color(c_vein)
	st.add_vertex(v_mid_vein)
	
	st.set_color(c_vein)
	st.add_vertex(v_base)
	st.set_color(c_vein)
	st.add_vertex(v_mid_vein)
	st.set_color(c_blade)
	st.add_vertex(v_mid_r)
	
	# 2. Vientre medio a hombros
	st.set_color(c_blade)
	st.add_vertex(v_mid_l)
	st.set_color(c_blade)
	st.add_vertex(v_sh_l)
	st.set_color(c_vein)
	st.add_vertex(v_sh_vein)
	
	st.set_color(c_blade)
	st.add_vertex(v_mid_l)
	st.set_color(c_vein)
	st.add_vertex(v_sh_vein)
	st.set_color(c_vein)
	st.add_vertex(v_mid_vein)
	
	st.set_color(c_vein)
	st.add_vertex(v_mid_vein)
	st.set_color(c_vein)
	st.add_vertex(v_sh_vein)
	st.set_color(c_blade)
	st.add_vertex(v_sh_r)
	
	st.set_color(c_vein)
	st.add_vertex(v_mid_vein)
	st.set_color(c_blade)
	st.add_vertex(v_sh_r)
	st.set_color(c_blade)
	st.add_vertex(v_mid_r)
	
	# 3. Hombros a punta lanceolada
	st.set_color(c_blade)
	st.add_vertex(v_sh_l)
	st.set_color(c_blade)
	st.add_vertex(v_tip)
	st.set_color(c_vein)
	st.add_vertex(v_sh_vein)
	
	st.set_color(c_vein)
	st.add_vertex(v_sh_vein)
	st.set_color(c_blade)
	st.add_vertex(v_tip)
	st.set_color(c_blade)
	st.add_vertex(v_sh_r)

## Distribuye hojas a lo largo de una curva de tallo
static func _build_leaves_along_curve(st: SurfaceTool, points: Array, leaf_sz: Vector2, color: Color, rng: RandomNumberGenerator, count: int, growth: float, profile: Dictionary = {}) -> void:
	if points.size() < 2:
		return
	var visible_count: int = int(float(count) * clampf(growth * 1.5, 0.3, 1.0))
	var is_compound: bool = int(profile.get("leaf_count_per_node", 1)) >= 3
	
	for i in range(visible_count):
		var t: float = float(i + 1) / float(count + 1) * 0.75 + 0.1
		var p_idx: int = int(t * float(points.size() - 1))
		var pt: Vector3 = points[clampi(p_idx, 0, points.size() - 1)]
		
		var angle: float = float(i) * 2.1 + rng.randf_range(-0.3, 0.3)
		var leaf_dir := Vector3(cos(angle), 0.35, sin(angle)).normalized()
		var l: float = leaf_sz.x * rng.randf_range(0.85, 1.15) * clampf(growth, 0.4, 1.0)
		var w: float = leaf_sz.y * rng.randf_range(0.85, 1.15) * clampf(growth, 0.4, 1.0)
		
		if is_compound:
			# Foliolo terminal
			_build_creased_leaf(st, pt, leaf_dir, l, w, color)
			# Foliolos laterales (ramillete de rosal)
			var side_r := leaf_dir.cross(Vector3.UP).normalized()
			var l_lat := l * 0.8
			var w_lat := w * 0.85
			var pt_lat: Vector3 = pt + leaf_dir * (l * 0.28)
			var dir_l := (leaf_dir - side_r * 0.52).normalized()
			var dir_r := (leaf_dir + side_r * 0.52).normalized()
			_build_creased_leaf(st, pt_lat, dir_l, l_lat, w_lat, color)
			_build_creased_leaf(st, pt_lat, dir_r, l_lat, w_lat, color)
		else:
			_build_creased_leaf(st, pt, leaf_dir, l, w, color)

## Espinas cónicas pequeñas a lo largo de las cañas
static func _build_thorns(st: SurfaceTool, points: Array, radius: float, color: Color, rng: RandomNumberGenerator) -> void:
	var num_thorns := 6
	for i in range(num_thorns):
		var t: float = float(i + 1) / float(num_thorns + 2)
		var pt: Vector3 = points[0].lerp(points[points.size() - 1], t)
		var a: float = rng.randf_range(0, TAU)
		var outward := Vector3(cos(a), -0.2, sin(a)).normalized()
		var thorn_base: Vector3 = pt + outward * radius
		var thorn_tip: Vector3 = thorn_base + outward * 0.012
		
		# Micro triángulo de espina
		st.set_color(color)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(thorn_base + Vector3(0, 0.004, 0))
		st.add_vertex(thorn_tip)
		st.add_vertex(thorn_base - Vector3(0, 0.004, 0))

## Flor o capullo en la punta de un tallo (Rosal, Margarita, Amapola)
static func _build_flower_head(st_flower: SurfaceTool, tip: Vector3, up_dir: Vector3, profile: Dictionary, rng: RandomNumberGenerator, growth: float, stages: Dictionary, flower_color: Color) -> void:
	var bud_end: float = stages["bud_end"]
	var veg_end: float = stages["veg_end"]
	
	# Determinar si es capullo cerrado o flor abriéndose
	if growth <= bud_end:
		# Capullo verde cerrado
		var bud_scale: float = clampf((growth - veg_end) / (bud_end - veg_end), 0.25, 1.0)
		_build_closed_bud(st_flower, tip, up_dir, profile["flower_radius"] * 0.4 * bud_scale, profile["stem_color"], flower_color)
	else:
		# Flor abriéndose a floración plena
		var bloom_t: float = clampf((growth - bud_end) / (1.0 - bud_end), 0.0, 1.0)
		_build_open_bloom(st_flower, tip, up_dir, profile, rng, bloom_t, flower_color)

## Capullo cerrado (pequeña cápsula con cáliz)
static func _build_closed_bud(st: SurfaceTool, pos: Vector3, up_dir: Vector3, size: float, calyx_color: Color, petal_tint: Color) -> void:
	var right: Vector3 = up_dir.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = up_dir.cross(Vector3.RIGHT).normalized()
	var fwd: Vector3 = right.cross(up_dir).normalized()
	
	# 4 sépalos del cáliz envolviendo el capullo
	var bud_tip: Vector3 = pos + up_dir * size
	for i in range(4):
		var a: float = (TAU / 4.0) * float(i)
		var p_mid: Vector3 = pos + (right * cos(a) + fwd * sin(a)) * (size * 0.5) + up_dir * (size * 0.4)
		
		# Base verde
		st.set_color(calyx_color)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(pos)
		st.add_vertex(p_mid)
		
		# Punta con asomo de color
		st.set_color(petal_tint)
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(bud_tip)

## Flor abierta con pétalos 3D tridimensionales en capas y centro
static func _build_open_bloom(st: SurfaceTool, pos: Vector3, up_dir: Vector3, profile: Dictionary, rng: RandomNumberGenerator, bloom_t: float, flower_color: Color) -> void:
	var max_radius: float = profile["flower_radius"]
	var radius: float = lerpf(max_radius * 0.45, max_radius, bloom_t)
	var spread_angle: float = lerpf(0.2, 1.25, bloom_t) # Ángulo de apertura de los pétalos
	
	var right: Vector3 = up_dir.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = up_dir.cross(Vector3.RIGHT).normalized()
	var fwd: Vector3 = right.cross(up_dir).normalized()
	
	# Centro floral (Disco / Estambres)
	var center_r: float = radius * 0.28
	var center_h: float = radius * 0.14
	_build_flower_center(st, pos, up_dir, center_r, center_h, profile["center_color"])
	
	# Capas de pétalos
	var layers: int = profile["petal_layers"]
	var petals_per_layer: int = profile["petal_count"]
	
	for l in range(layers):
		var layer_frac: float = float(l) / float(max(layers, 1))
		var l_radius: float = radius * lerpf(1.0, 0.72, layer_frac)
		var l_spread: float = spread_angle * lerpf(1.0, 0.65, layer_frac)
		var l_offset_angle: float = float(l) * 0.45
		
		for p in range(petals_per_layer):
			var a: float = (TAU / float(petals_per_layer)) * float(p) + l_offset_angle
			var petal_dir: Vector3 = (right * cos(a) + fwd * sin(a)).normalized()
			
			var is_rose: bool = layers >= 3
			var petal_w: float = l_radius * (0.64 if is_rose else 0.42)
			var side_dir: Vector3 = petal_dir.cross(up_dir).normalized()
			
			# Curvatura del pétalo hacia afuera y arriba (copa de rosa)
			var p_base: Vector3 = pos + petal_dir * (center_r * 0.6)
			var arch_lift: float = radius * (0.12 if is_rose else 0.06)
			var p_tip: Vector3 = pos + (petal_dir * cos(l_spread) + up_dir * sin(l_spread)).normalized() * l_radius
			var p_mid: Vector3 = (p_base + p_tip) * 0.5 + up_dir * arch_lift
			
			var p_left: Vector3 = p_mid - side_dir * (petal_w * 0.5)
			var p_right: Vector3 = p_mid + side_dir * (petal_w * 0.5)
			
			# Tinte de color suave (más oscuro en la base, brillante en la punta)
			var c_base: Color = flower_color.darkened(0.22 if is_rose else 0.15)
			var c_tip: Color = flower_color
			
			st.set_color(c_base)
			st.set_uv(Vector2(0.5, 0.0))
			st.add_vertex(p_base)
			st.set_color(c_tip)
			st.set_uv(Vector2(0.0, 0.5))
			st.add_vertex(p_left)
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(p_tip)
			
			st.set_color(c_base)
			st.set_uv(Vector2(0.5, 0.0))
			st.add_vertex(p_base)
			st.set_color(c_tip)
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(p_tip)
			st.set_uv(Vector2(1.0, 0.5))
			st.add_vertex(p_right)

## Disco central de la flor (Estambres/Receptáculo)
static func _build_flower_center(st: SurfaceTool, pos: Vector3, up_dir: Vector3, radius: float, height: float, color: Color) -> void:
	var right: Vector3 = up_dir.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = up_dir.cross(Vector3.RIGHT).normalized()
	var fwd: Vector3 = right.cross(up_dir).normalized()
	
	var apex: Vector3 = pos + up_dir * height
	var sides := 6
	st.set_color(color)
	
	for i in range(sides):
		var a1: float = (TAU / float(sides)) * float(i)
		var a2: float = (TAU / float(sides)) * float((i + 1) % sides)
		var v1: Vector3 = pos + (right * cos(a1) + fwd * sin(a1)) * radius
		var v2: Vector3 = pos + (right * cos(a2) + fwd * sin(a2)) * radius
		
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(apex)
		st.set_uv(Vector2(cos(a1) * 0.5 + 0.5, sin(a1) * 0.5 + 0.5))
		st.add_vertex(v1)
		st.set_uv(Vector2(cos(a2) * 0.5 + 0.5, sin(a2) * 0.5 + 0.5))
		st.add_vertex(v2)

## Espiga de lavanda (cilindro de florecillas agrupadas)
static func _build_lavender_spike(st: SurfaceTool, tip: Vector3, spike_len: float, profile: Dictionary, rng: RandomNumberGenerator, growth: float, stages: Dictionary, flower_color: Color) -> void:
	var whorls := 7 # Anillos de florecillas
	var base_spike: Vector3 = tip - Vector3.UP * spike_len
	
	for w in range(whorls):
		var t: float = float(w) / float(whorls - 1)
		var pt: Vector3 = base_spike.lerp(tip, t)
		var whorl_r: float = profile["flower_radius"] * lerpf(1.0, 0.4, t)
		var num_florets := 5
		
		for f in range(num_florets):
			var a: float = (TAU / float(num_florets)) * float(f) + t * 2.0
			var f_dir := Vector3(cos(a), 0.25, sin(a)).normalized()
			var floret_pos: Vector3 = pt + f_dir * whorl_r
			
			# Pequeño cáliz de lavanda
			st.set_color(flower_color)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(pt)
			st.add_vertex(floret_pos + Vector3(0, 0.008, 0))
			st.add_vertex(floret_pos - Vector3(0, 0.008, 0))

## Gran flor discoide de Girasol (30 cm de diámetro)
static func _build_sunflower_head(st: SurfaceTool, pos: Vector3, face_dir: Vector3, profile: Dictionary, rng: RandomNumberGenerator, growth: float, stages: Dictionary, flower_color: Color) -> void:
	var bloom_t: float = clampf((growth - stages["bud_end"]) / (1.0 - stages["bud_end"]), 0.1, 1.0)
	var radius: float = profile["flower_radius"] * bloom_t
	var center_r: float = radius * 0.55 # Disco central enorme
	
	var right: Vector3 = face_dir.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = face_dir.cross(Vector3.RIGHT).normalized()
	var up: Vector3 = right.cross(face_dir).normalized()
	
	# Centro discoide marrón
	var center_apex: Vector3 = pos + face_dir * (radius * 0.08)
	var sides := 10
	st.set_color(profile["center_color"])
	for i in range(sides):
		var a1: float = (TAU / float(sides)) * float(i)
		var a2: float = (TAU / float(sides)) * float((i + 1) % sides)
		var v1: Vector3 = pos + (right * cos(a1) + up * sin(a1)) * center_r
		var v2: Vector3 = pos + (right * cos(a2) + up * sin(a2)) * center_r
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(center_apex)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(v1)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(v2)
	
	# Corona de rayos dorados (16 pétalos)
	var ray_count := 16
	var ray_len: float = radius * 0.45
	var ray_w: float = (TAU * center_r / float(ray_count)) * 0.85
	
	for r in range(ray_count):
		var a: float = (TAU / float(ray_count)) * float(r)
		var dir := (right * cos(a) + up * sin(a)).normalized()
		var side := dir.cross(face_dir).normalized()
		
		var p_base: Vector3 = pos + dir * center_r
		var p_tip: Vector3 = p_base + dir * ray_len
		var p_left: Vector3 = p_base + dir * (ray_len * 0.4) - side * (ray_w * 0.5)
		var p_right: Vector3 = p_base + dir * (ray_len * 0.4) + side * (ray_w * 0.5)
		
		st.set_color(flower_color)
		st.set_uv(Vector2(0.5, 0))
		st.add_vertex(p_base)
		st.set_uv(Vector2(0, 0.5))
		st.add_vertex(p_left)
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(p_tip)
		
		st.set_uv(Vector2(0.5, 0))
		st.add_vertex(p_base)
		st.set_uv(Vector2(0.5, 1))
		st.add_vertex(p_tip)
		st.set_uv(Vector2(1, 0.5))
		st.add_vertex(p_right)

# ==============================================================================
# SUB-CONSTRUCTORES BOTÁNICOS ESPECÍFICOS PARA ROSAS DE ALTA FIDELIDAD
# ==============================================================================

## Flor de Rosa de Alta Fidelidad en capas concéntricas espiraladas (Fibonacci Swirl)
## Diseñada con pétalos cóncavos ahuecados, cresta redondeada suave (sin picos triangulares),
## corazón en espiral profundo aterciopelado y pétalos de guarda exteriores curvados.
static func _build_rose_bloom(st: SurfaceTool, pos: Vector3, up_dir: Vector3, profile: Dictionary, rng: RandomNumberGenerator, growth: float, stages: Dictionary, flower_color: Color, override_bloom_t: float = -1.0) -> void:
	var veg_end: float = float(stages["veg_end"])
	var bud_end: float = float(stages["bud_end"])
	
	if growth <= bud_end and override_bloom_t < 0.0:
		var bud_prog: float = clampf((growth - veg_end) / (bud_end - veg_end), 0.25, 1.0)
		_build_rose_bud(st, pos, up_dir, profile["flower_radius"] * 0.55 * bud_prog, flower_color)
		return
	
	var bloom_t: float = clampf((growth - bud_end) / (1.0 - bud_end), 0.0, 1.0)
	if override_bloom_t >= 0.0:
		bloom_t = clampf(override_bloom_t, 0.0, 1.0)
	
	var max_radius: float = float(profile["flower_radius"])
	var r_curr: float = lerpf(max_radius * 0.40, max_radius, bloom_t)
	var size_mult: float = max_radius / 0.052
	var h_scale: float = size_mult * lerpf(0.60, 1.0, bloom_t)
	var r_scale: float = size_mult * (r_curr / max_radius)
	
	var right: Vector3 = up_dir.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = up_dir.cross(Vector3.RIGHT).normalized()
	var fwd: Vector3 = right.cross(up_dir).normalized()
	
	# Arquitectura Botánica de Rosa Híbrida de Té (5 capas / 38 pétalos voluptuosos):
	# Capa 0: Corazón espiral cónico cerrado (6 pétalos muy apretados y esbeltos)
	# Capa 1: Cono interior (7 pétalos envolviendo el corazón)
	# Capa 2: Copa media (8 pétalos voluptuosos que dan cuerpo)
	# Capa 3: Copa exterior (8 pétalos anchos que forman la copa principal)
	# Capa 4: Pétalos de guarda reflexed (9 pétalos exteriores con cresta enrollada hacia afuera)
	var layers_config = [
		{"count": 6, "rb": 0.003, "hb": 0.015, "rm": 0.010, "hm": 0.048, "rt": 0.008, "ht": 0.076, "wm": 0.018, "wt": 0.016, "darken": 0.60, "curl": 0.0},
		{"count": 7, "rb": 0.008, "hb": 0.010, "rm": 0.020, "hm": 0.054, "rt": 0.022, "ht": 0.082, "wm": 0.028, "wt": 0.026, "darken": 0.40, "curl": 0.0},
		{"count": 8, "rb": 0.014, "hb": 0.006, "rm": 0.032, "hm": 0.056, "rt": 0.038, "ht": 0.084, "wm": 0.042, "wt": 0.038, "darken": 0.18, "curl": 0.0},
		{"count": 8, "rb": 0.020, "hb": 0.003, "rm": 0.044, "hm": 0.050, "rt": 0.052, "ht": 0.080, "wm": 0.056, "wt": 0.052, "darken": 0.00, "curl": 0.25},
		{"count": 9, "rb": 0.026, "hb": 0.000, "rm": 0.052, "hm": 0.040, "rt": 0.062, "ht": 0.068, "wm": 0.065, "wt": 0.062, "darken": -0.08, "curl": 0.85}
	]
	
	for l_idx in range(layers_config.size()):
		var cfg: Dictionary = layers_config[l_idx]
		var count: int = cfg["count"]
		var angle_offset: float = float(l_idx) * 2.39996 + 0.12 # Desfasamiento espiral áureo (Phyllotaxis)
		var l_darken: float = float(cfg["darken"])
		var curl_factor: float = float(cfg["curl"]) * bloom_t
		
		# Gradación de color aterciopelado: sombras botánicas ricas y resalte natural preservando la paleta exacta
		var col_mid: Color = flower_color.darkened(l_darken) if l_darken > 0.0 else flower_color.lightened(0.08)
		var col_base: Color = flower_color.darkened(0.55) # Sombra botánica profunda en el receptáculo interior
		var col_rim: Color = flower_color.lightened(0.18)  # Resalte luminoso en el borde exterior del pétalo
		
		var rb: float = float(cfg["rb"]) * r_scale
		var hb: float = float(cfg["hb"]) * h_scale
		var rm: float = float(cfg["rm"]) * r_scale
		var hm: float = float(cfg["hm"]) * h_scale
		var rt: float = float(cfg["rt"]) * r_scale
		var ht: float = float(cfg["ht"]) * h_scale
		var wm: float = float(cfg["wm"]) * r_scale
		var wt: float = float(cfg["wt"]) * r_scale
		
		for p in range(count):
			var a: float = (TAU / float(count)) * float(p) + angle_offset
			var p_dir: Vector3 = (right * cos(a) + fwd * sin(a)).normalized()
			var side: Vector3 = p_dir.cross(up_dir).normalized() # Tangente lateral
			
			# 1. Base del pétalo en el receptáculo
			var v_base: Vector3 = pos + p_dir * rb + up_dir * hb
			
			# 2. Cintura media (Ahuecado hacia adentro: las alas laterales abrazan el centro)
			var v_mid_c: Vector3 = pos + p_dir * rm + up_dir * hm
			var cup_hug: float = wm * 0.18
			var v_mid_l: Vector3 = v_mid_c - side * (wm * 0.50) - p_dir * cup_hug
			var v_mid_r: Vector3 = v_mid_c + side * (wm * 0.50) - p_dir * cup_hug
			
			# 3. Cresta superior redondeada (4 puntos para formar un arco suave, NO pico)
			var eff_rt: float = rt
			var eff_ht: float = ht
			if curl_factor > 0.0:
				eff_rt += 0.008 * curl_factor
				eff_ht -= 0.006 * curl_factor
			
			var v_top_c: Vector3 = pos + p_dir * eff_rt + up_dir * eff_ht
			var shoulder_dip: float = wt * 0.12
			var shoulder_curl: Vector3 = -p_dir * (wm * 0.15) if curl_factor <= 0.0 else p_dir * (wm * 0.08)
			
			var v_top_l: Vector3 = v_top_c - side * (wt * 0.46) - up_dir * shoulder_dip + shoulder_curl
			var v_top_cl: Vector3 = v_top_c - side * (wt * 0.18) + up_dir * (wt * 0.03)
			var v_top_cr: Vector3 = v_top_c + side * (wt * 0.18) + up_dir * (wt * 0.03)
			var v_top_r: Vector3 = v_top_c + side * (wt * 0.46) - up_dir * shoulder_dip + shoulder_curl
			
			# Triangulación limpia de 7 triángulos formando pétalo arqueado suave:
			# Cuadrante inferior (de la base a la cintura):
			st.set_color(col_base)
			st.add_vertex(v_base)
			st.set_color(col_mid)
			st.add_vertex(v_mid_l)
			st.set_color(col_mid)
			st.add_vertex(v_mid_c)
			
			st.set_color(col_base)
			st.add_vertex(v_base)
			st.set_color(col_mid)
			st.add_vertex(v_mid_c)
			st.set_color(col_mid)
			st.add_vertex(v_mid_r)
			
			# Cuadrante superior (de la cintura a la cresta redondeada):
			# Ala izquierda:
			st.set_color(col_mid)
			st.add_vertex(v_mid_l)
			st.set_color(col_rim)
			st.add_vertex(v_top_l)
			st.set_color(col_rim)
			st.add_vertex(v_top_cl)
			
			st.set_color(col_mid)
			st.add_vertex(v_mid_l)
			st.set_color(col_rim)
			st.add_vertex(v_top_cl)
			st.set_color(col_mid)
			st.add_vertex(v_mid_c)
			
			# Centro de la cresta (suavemente arqueado):
			st.set_color(col_mid)
			st.add_vertex(v_mid_c)
			st.set_color(col_rim)
			st.add_vertex(v_top_cl)
			st.set_color(col_rim)
			st.add_vertex(v_top_cr)
			
			# Ala derecha:
			st.set_color(col_mid)
			st.add_vertex(v_mid_c)
			st.set_color(col_rim)
			st.add_vertex(v_top_cr)
			st.set_color(col_mid)
			st.add_vertex(v_mid_r)
			
			st.set_color(col_mid)
			st.add_vertex(v_mid_r)
			st.set_color(col_rim)
			st.add_vertex(v_top_cr)
			st.set_color(col_rim)
			st.add_vertex(v_top_r)

## Capullo cónico cerrado de rosa con pétalos espiralados
static func _build_rose_bud(st_flower: SurfaceTool, pos: Vector3, up_dir: Vector3, size: float, petal_color: Color) -> void:
	var right: Vector3 = up_dir.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = up_dir.cross(Vector3.RIGHT).normalized()
	var fwd: Vector3 = right.cross(up_dir).normalized()
	
	var bud_tip: Vector3 = pos + up_dir * (size * 1.7)
	var num_petals := 6
	var r: float = size * 0.70
	
	for i in range(num_petals):
		var a1: float = (TAU / float(num_petals)) * float(i)
		var a2: float = (TAU / float(num_petals)) * float((i + 1) % num_petals)
		var d1 := (right * cos(a1) + fwd * sin(a1)).normalized()
		var d2 := (right * cos(a2) + fwd * sin(a2)).normalized()
		
		var v1: Vector3 = pos + d1 * r
		var v2: Vector3 = pos + d2 * r
		var mid_h: float = size * 0.85
		var v_mid1: Vector3 = pos + d1 * (r * 1.05) + up_dir * mid_h
		var v_mid2: Vector3 = pos + d2 * (r * 1.05) + up_dir * mid_h
		
		var c_dark := petal_color.darkened(0.35)
		st_flower.set_color(c_dark)
		st_flower.add_vertex(v1)
		st_flower.set_color(petal_color)
		st_flower.add_vertex(v_mid1)
		st_flower.add_vertex(v_mid2)
		
		st_flower.set_color(c_dark)
		st_flower.add_vertex(v1)
		st_flower.set_color(petal_color)
		st_flower.add_vertex(v_mid2)
		st_flower.set_color(c_dark)
		st_flower.add_vertex(v2)
		
		st_flower.set_color(petal_color)
		st_flower.add_vertex(v_mid1)
		st_flower.set_color(petal_color.lightened(0.10))
		st_flower.add_vertex(bud_tip)
		st_flower.set_color(petal_color)
		st_flower.add_vertex(v_mid2)

## Receptáculo verde (Hip) y los 5 Sépalos lanceolados bajo los pétalos
static func _build_rose_calyx(st_veg: SurfaceTool, pos: Vector3, up_dir: Vector3, profile: Dictionary, growth: float, stages: Dictionary) -> void:
	var right: Vector3 = up_dir.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = up_dir.cross(Vector3.RIGHT).normalized()
	var fwd: Vector3 = right.cross(up_dir).normalized()
	
	var sepal_color: Color = Color(0.14, 0.35, 0.10)
	var calyx_color: Color = profile["stem_color"]
	
	# 1. Receptáculo / Hip (urna o bulbo verde: prisma triangular de 3 lados con Gouraud suave)
	var hip_h: float = 0.022
	var hip_r: float = 0.015
	var sides := 3
	var p_top := pos - up_dir * 0.001
	var p_mid := pos - up_dir * (hip_h * 0.45)
	var p_bot := pos - up_dir * hip_h
	
	for i in range(sides):
		var a1: float = (TAU / float(sides)) * float(i)
		var a2: float = (TAU / float(sides)) * float((i + 1) % sides)
		var d1 := (right * cos(a1) + fwd * sin(a1)).normalized()
		var d2 := (right * cos(a2) + fwd * sin(a2)).normalized()
		
		var v_top1: Vector3 = p_top + d1 * (hip_r * 0.95)
		var v_top2: Vector3 = p_top + d2 * (hip_r * 0.95)
		var v_mid1: Vector3 = p_mid + d1 * hip_r
		var v_mid2: Vector3 = p_mid + d2 * hip_r
		var v_bot1: Vector3 = p_bot + d1 * (profile["stem_radius"] * 1.1)
		var v_bot2: Vector3 = p_bot + d2 * (profile["stem_radius"] * 1.1)
		
		st_veg.set_color(calyx_color)
		# Cuadrante superior
		st_veg.add_vertex(v_top1)
		st_veg.add_vertex(v_mid1)
		st_veg.add_vertex(v_mid2)
		st_veg.add_vertex(v_top1)
		st_veg.add_vertex(v_mid2)
		st_veg.add_vertex(v_top2)
		# Cuadrante inferior
		st_veg.add_vertex(v_mid1)
		st_veg.add_vertex(v_bot1)
		st_veg.add_vertex(v_bot2)
		st_veg.add_vertex(v_mid1)
		st_veg.add_vertex(v_bot2)
		st_veg.add_vertex(v_mid2)
	
	# 2. Los 5 Sépalos lanceolados que se extienden y curvan hacia abajo (1 triángulo por sépalo)
	var sepal_len: float = 0.048 * clampf(growth * 1.3, 0.4, 1.0)
	var sepal_w: float = 0.008
	
	for s in range(5):
		var a: float = (TAU / 5.0) * float(s) + 0.20
		var s_dir := (right * cos(a) + fwd * sin(a)).normalized()
		var s_side := s_dir.cross(up_dir).normalized()
		
		var s_base_l: Vector3 = p_mid + s_dir * (hip_r * 0.90) - s_side * (sepal_w * 0.5)
		var s_base_r: Vector3 = p_mid + s_dir * (hip_r * 0.90) + s_side * (sepal_w * 0.5)
		var s_tip: Vector3 = p_mid + s_dir * (sepal_len * 0.75) - up_dir * (sepal_len * 0.65)
		
		st_veg.set_color(sepal_color)
		st_veg.add_vertex(s_base_l)
		st_veg.add_vertex(s_tip)
		st_veg.add_vertex(s_base_r)

## Espinas reales con forma de gancho curvado hacia abajo y base ancha
static func _build_rose_hooked_thorns(st_veg: SurfaceTool, p_start: Vector3, p_end: Vector3, stem_r: float, color: Color, rng: RandomNumberGenerator, growth: float) -> void:
	if growth < 0.35:
		return
	var num_thorns := 6
	for i in range(num_thorns):
		var t: float = float(i + 1) / float(num_thorns + 1) * 0.65 + 0.10
		var pt: Vector3 = p_start.lerp(p_end, t)
		var a: float = float(i) * 2.39996 + rng.randf_range(-0.15, 0.15)
		var out_dir := Vector3(cos(a), 0, sin(a)).normalized()
		var side := out_dir.cross(Vector3.UP).normalized()
		
		# Base de la espina alargada a lo largo del tallo (1.2 cm)
		var base_h := 0.012
		var base_top := pt + out_dir * stem_r + Vector3(0, base_h * 0.5, 0)
		var base_bot := pt + out_dir * stem_r - Vector3(0, base_h * 0.5, 0)
		var base_l := pt + out_dir * stem_r - side * 0.0025
		var base_r := pt + out_dir * stem_r + side * 0.0025
		
		# Punta de la espina curvada hacia abajo
		var hook_len := 0.012
		var tip := pt + out_dir * (stem_r + hook_len) - Vector3(0, 0.006, 0)
		
		st_veg.set_color(color)
		st_veg.add_vertex(base_top)
		st_veg.add_vertex(tip)
		st_veg.add_vertex(base_l)
		
		st_veg.add_vertex(base_top)
		st_veg.add_vertex(base_r)
		st_veg.add_vertex(tip)
		
		st_veg.add_vertex(base_bot)
		st_veg.add_vertex(base_l)
		st_veg.add_vertex(tip)
		
		st_veg.add_vertex(base_bot)
		st_veg.add_vertex(tip)
		st_veg.add_vertex(base_r)

## Hojas de rosal compuestas con pecíolo plano y foliolos anchos plegados en V
static func _build_rose_compound_foliage(st_veg: SurfaceTool, p_start: Vector3, p_end: Vector3, profile: Dictionary, rng: RandomNumberGenerator, growth: float) -> void:
	if growth < 0.25:
		return
	
	var leaf_color: Color = profile["leaf_color"]
	var leaf_sz: Vector2 = profile["leaf_size"]
	var stem_r: float = profile["stem_radius"]
	var petiole_color: Color = profile["stem_color"]
	
	var node_heights = [0.55, 0.78]
	var node_angles = [deg_to_rad(25.0), deg_to_rad(155.0)]
	
	for idx in range(node_heights.size()):
		var t: float = node_heights[idx]
		var pt: Vector3 = p_start.lerp(p_end, t)
		var node_angle: float = node_angles[idx] + rng.randf_range(-0.06, 0.06)
		
		var petiole_dir := Vector3(cos(node_angle), 0.32, sin(node_angle)).normalized()
		var petiole_len: float = 0.088 * clampf(growth * 1.4, 0.3, 1.0)
		var p_base: Vector3 = pt + Vector3(cos(node_angle), 0, sin(node_angle)) * stem_r
		var p_mid: Vector3 = p_base + petiole_dir * (petiole_len * 0.46)
		var p_tip: Vector3 = p_base + petiole_dir * petiole_len
		
		# Pecíolo plano ultraligero (2 triángulos)
		_build_petiole_quad(st_veg, p_base, p_tip, 0.005, petiole_color)
		
		# 1. Foliolo Terminal Grande (2 triángulos)
		var term_l: float = leaf_sz.x * clampf(growth, 0.4, 1.0)
		var term_w: float = leaf_sz.y * clampf(growth, 0.4, 1.0)
		var term_dir := (petiole_dir + Vector3(0, -0.15, 0)).normalized()
		_build_creased_leaf(st_veg, p_tip, term_dir, term_l, term_w, leaf_color)
		
		# 2. Par de Foliolos Laterales en p_mid (4 triángulos)
		var side_r := petiole_dir.cross(Vector3.UP).normalized()
		var lat_l: float = term_l * 0.84
		var lat_w: float = term_w * 0.84
		var dir_l := (petiole_dir - side_r * 0.70 + Vector3(0, -0.12, 0)).normalized()
		var dir_r := (petiole_dir + side_r * 0.70 + Vector3(0, -0.12, 0)).normalized()
		_build_creased_leaf(st_veg, p_mid, dir_l, lat_l, lat_w, leaf_color)
		_build_creased_leaf(st_veg, p_mid, dir_r, lat_l, lat_w, leaf_color)

## Verifica que una posición de flor no esté a menos de `min_dist` de ninguna otra flor
## (Evita por completo el error de flores encimadas o dobles alargadas)
static func _can_place_flower(pos: Vector3, existing_positions: Array[Vector3], min_dist: float = 0.20) -> bool:
	for p in existing_positions:
		if pos.distance_to(p) < min_dist:
			return false
	return true

## Interpola suavemente a lo largo de una lista de puntos de spline
static func _interpolate_spline_points(points: Array, t: float) -> Vector3:
	if points.size() < 2:
		return points[0] if points.size() == 1 else Vector3.ZERO
	var segs: int = points.size() - 1
	var scaled_t: float = clampf(t, 0.0, 1.0) * float(segs)
	var idx: int = clampi(int(scaled_t), 0, segs - 1)
	var local_t: float = scaled_t - float(idx)
	return (points[idx] as Vector3).lerp(points[idx + 1] as Vector3, local_t)

## Follaje denso y frondoso para rosal arbustivo (pecíolo plano ultraligero y foliolos anatómicos en V)
static func _build_rose_dense_shrub_foliage(st_veg: SurfaceTool, points: Array, profile: Dictionary, rng: RandomNumberGenerator, growth: float, leaf_count: int = 6) -> void:
	if points.size() < 2 or growth < 0.20:
		return
	
	var leaf_color: Color = profile["leaf_color"]
	var leaf_sz: Vector2 = profile["leaf_size"]
	var stem_r: float = profile["stem_radius"]
	var petiole_color: Color = profile["stem_color"]
	
	var active_leaves: int = int(float(leaf_count) * clampf(growth * 1.3, 0.35, 1.0))
	
	for i in range(active_leaves):
		var t: float = lerpf(0.12, 0.94, float(i + 1) / float(leaf_count + 1))
		var pt: Vector3 = _interpolate_spline_points(points, t)
		
		# Variación botánica de tono: verde bosque oscuro profundo y fuerte
		var node_leaf_color: Color = leaf_color
		if t < 0.35:
			node_leaf_color = leaf_color.darkened(0.20)
		elif t > 0.80:
			node_leaf_color = leaf_color.lerp(Color(0.020, 0.14, 0.026), 0.25)
		
		var angle: float = float(i) * 2.39996 + rng.randf_range(-0.15, 0.15)
		var petiole_dir := Vector3(cos(angle), rng.randf_range(0.18, 0.36), sin(angle)).normalized()
		var petiole_len: float = rng.randf_range(0.075, 0.110) * clampf(growth * 1.3, 0.4, 1.0)
		
		var p_base: Vector3 = pt + Vector3(cos(angle), 0, sin(angle)) * stem_r
		var p_mid: Vector3 = p_base + petiole_dir * (petiole_len * 0.48)
		var p_tip: Vector3 = p_base + petiole_dir * petiole_len
		
		# Pecíolo plano ultraligero
		_build_petiole_quad(st_veg, p_base, p_tip, 0.005, petiole_color)
		
		# 1. Foliolo terminal prominente (tamaño generoso para follaje frondoso)
		var term_l: float = leaf_sz.x * rng.randf_range(1.20, 1.40) * clampf(growth, 0.4, 1.0)
		var term_w: float = leaf_sz.y * rng.randf_range(1.15, 1.35) * clampf(growth, 0.4, 1.0)
		var term_dir := (petiole_dir + Vector3(0, -0.12, 0)).normalized()
		_build_creased_leaf(st_veg, p_tip, term_dir, term_l, term_w, node_leaf_color)
		
		# 2. Foliolos laterales en p_mid
		var side_r := petiole_dir.cross(Vector3.UP).normalized()
		var lat_l: float = term_l * 0.88
		var lat_w: float = term_w * 0.88
		var dir_l := (petiole_dir - side_r * 0.68 + Vector3(0, -0.10, 0)).normalized()
		var dir_r := (petiole_dir + side_r * 0.68 + Vector3(0, -0.10, 0)).normalized()
		_build_creased_leaf(st_veg, p_mid, dir_l, lat_l, lat_w, node_leaf_color)
		_build_creased_leaf(st_veg, p_mid, dir_r, lat_l, lat_w, node_leaf_color)
		
		# 3. Hojas compuestas pentafoliadas: solo en la base inferior (t < 0.35)
		if growth > 0.42 and t < 0.35:
			var p_low: Vector3 = p_base + petiole_dir * (petiole_len * 0.26)
			var low_l: float = term_l * 0.74
			var low_w: float = term_w * 0.74
			var dir_low_l := (petiole_dir - side_r * 0.72 + Vector3(0, -0.08, 0)).normalized()
			var dir_low_r := (petiole_dir + side_r * 0.72 + Vector3(0, -0.08, 0)).normalized()
			_build_creased_leaf(st_veg, p_low, dir_low_l, low_l, low_w, node_leaf_color)
			_build_creased_leaf(st_veg, p_low, dir_low_r, low_l, low_w, node_leaf_color)

## Collar de 5 hojas directamente bajo la flor para enmarcar cada rosa en una cuna verde
static func _build_rose_sub_flower_collar(st_veg: SurfaceTool, pos: Vector3, up_dir: Vector3, profile: Dictionary, growth: float) -> void:
	if growth < 0.40:
		return
	var leaf_color: Color = profile["leaf_color"]
	var leaf_sz: Vector2 = profile["leaf_size"]
	var right: Vector3 = up_dir.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = up_dir.cross(Vector3.RIGHT).normalized()
	var fwd: Vector3 = right.cross(up_dir).normalized()
	
	var collar_count := 5
	var base_pt := pos - up_dir * 0.028
	for i in range(collar_count):
		var a: float = (TAU / float(collar_count)) * float(i) + 0.25
		var out_dir := (right * cos(a) + fwd * sin(a) - up_dir * 0.18).normalized()
		var l: float = leaf_sz.x * 0.90 * clampf(growth, 0.4, 1.0)
		var w: float = leaf_sz.y * 0.90 * clampf(growth, 0.4, 1.0)
		_build_creased_leaf(st_veg, base_pt, out_dir, l, w, leaf_color)

# ==============================================================================
# GENERADORES DE LOD ULTRA-OPTIMIZADOS (LOD 1 Y LOD 2)
# ==============================================================================
## Follaje en triángulo 2D billboard en GPU para Rosal Arbustivo en LOD 1 y LOD 2 (1 tri por foliolo)
static func _build_rose_foliage_lod(st_veg: SurfaceTool, points: Array, profile: Dictionary, growth: float, leaf_count: int = 4) -> void:
	if points.size() < 2 or growth < 0.20:
		return
	
	var leaf_color: Color = profile["leaf_color"]
	var base_leaf_sz: Vector2 = profile["leaf_size"] * 1.8 * clampf(growth, 0.4, 1.0)
	var active_leaves: int = int(float(leaf_count) * clampf(growth * 1.3, 0.35, 1.0))
	
	for i in range(active_leaves):
		var t: float = lerpf(0.18, 0.88, float(i + 1) / float(leaf_count + 1))
		var pt: Vector3 = _interpolate_spline_points(points, t)
		var angle: float = float(i) * 2.39996 + 0.35
		var petiole_dir := Vector3(cos(angle), 0.25, sin(angle)).normalized()
		var leaf_pos: Vector3 = pt + petiole_dir * (base_leaf_sz.x * 0.45)
		
		# Variación de tono botánico verde vivo
		var node_col: Color = leaf_color
		if t < 0.35:
			node_col = leaf_color.darkened(0.12)
		elif t > 0.75:
			node_col = leaf_color.lerp(Color(0.05, 0.28, 0.07), 0.25)
		
		var leaf_rot: float = sin(angle) * 0.45
		_build_billboard_leaf_triangle(st_veg, leaf_pos, base_leaf_sz, node_col, leaf_rot)

## Follaje compuesto en triángulo 2D para Rosa Solitaria en LOD 1 y 2
static func _build_rose_compound_foliage_lod(st_veg: SurfaceTool, p_base: Vector3, p_tip: Vector3, profile: Dictionary, growth: float, lod_level: int) -> void:
	if growth < 0.25:
		return
	var leaf_color: Color = profile["leaf_color"]
	var leaf_sz: Vector2 = profile["leaf_size"] * 1.8 * clampf(growth, 0.4, 1.0)
	var heights = [0.35, 0.65] if lod_level == 1 else [0.50]
	for idx in range(heights.size()):
		var t: float = heights[idx]
		var pt: Vector3 = p_base.lerp(p_tip, t)
		var sign_side: float = 1.0 if idx % 2 == 0 else -1.0
		var leaf_pos: Vector3 = pt + Vector3(0.06 * sign_side, 0, 0.02)
		var rot: float = 0.35 * sign_side
		_build_billboard_leaf_triangle(st_veg, leaf_pos, leaf_sz, leaf_color, rot)

static func _generate_generic_lod1(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult) -> void:
	var tip := Vector3(0, height, 0)
	_build_billboard_stem(st_veg, [Vector3.ZERO, tip * 0.5, tip], profile["stem_radius"], profile["stem_woody_color"], profile["stem_color"])
	_build_billboard_leaf_triangle(st_veg, tip * 0.5, profile["leaf_size"] * 1.5, profile["leaf_color"])
	if growth > float(stages["veg_end"]):
		var r: float = profile.get("flower_radius", 0.05) * 0.9
		var h: float = profile.get("flower_height", r * 0.85) * 0.8
		_build_pentagon_prism_flower(st_flower, tip, Vector3.UP, r, h, flower_color)
		result.flower_count = 1
		result.flower_positions.append(tip)

static func _generate_generic_lod2(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult) -> void:
	var tip := Vector3(0, height, 0)
	_build_billboard_stem(st_veg, [Vector3.ZERO, tip], profile["stem_radius"], profile["stem_woody_color"], profile["stem_color"])
	_build_billboard_leaf_triangle(st_veg, tip * 0.5, profile["leaf_size"] * 1.8, profile["leaf_color"])
	if growth > float(stages["veg_end"]):
		_build_triangle_billboard_flower(st_flower, tip, profile.get("flower_radius", 0.05), flower_color)
		result.flower_count = 1
		result.flower_positions.append(tip)

## Cinta plana 2D de tallo con rotación axial en GPU (1 quad = 2 tris por tramo)
static func _build_billboard_stem(st: SurfaceTool, points: Array, radius: float, base_color: Color, tip_color: Color) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var pa: Vector3 = points[i]
		var pb: Vector3 = points[i + 1]
		var ta: float = float(i) / float(points.size() - 1)
		var tb: float = float(i + 1) / float(points.size() - 1)
		var col_a: Color = base_color.lerp(tip_color, ta)
		var col_b: Color = base_color.lerp(tip_color, tb)
		var dir: Vector3 = (pb - pa).normalized()
		var ra: float = radius * lerpf(1.0, 0.72, ta)
		var rb: float = radius * lerpf(1.0, 0.72, tb)
		
		# UV.y == 2.0 activa el billboard axial de tallo en el shader
		# UV.x almacena el radio lateral (+/-)
		# NORMAL almacena el vector director del segmento
		# Triángulo 1: V0 (pa, left), V1 (pa, right), V2 (pb, right)
		st.set_normal(dir)
		st.set_uv(Vector2(-ra, 2.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_a)
		st.add_vertex(pa)
		
		st.set_normal(dir)
		st.set_uv(Vector2(ra, 2.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_a)
		st.add_vertex(pa)
		
		st.set_normal(dir)
		st.set_uv(Vector2(rb, 2.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_b)
		st.add_vertex(pb)
		
		# Triángulo 2: V0 (pa, left), V2 (pb, right), V3 (pb, left)
		st.set_normal(dir)
		st.set_uv(Vector2(-ra, 2.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_a)
		st.add_vertex(pa)
		
		st.set_normal(dir)
		st.set_uv(Vector2(rb, 2.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_b)
		st.add_vertex(pb)
		
		st.set_normal(dir)
		st.set_uv(Vector2(-rb, 2.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_b)
		st.add_vertex(pb)

## Hoja como 1 solo triángulo 2D billboard en GPU (1 tri por foliolo)
static func _build_billboard_leaf_triangle(st: SurfaceTool, pos: Vector3, size: Vector2, color: Color, rot: float = 0.0) -> void:
	var hx: float = size.x * 0.50
	var hy: float = size.y * 0.60
	# Color verde bosque profundo idéntico al full HD sin blanqueamiento
	var col_base := color.darkened(0.15)
	var col_blade := color
	
	var c := cos(rot)
	var s := sin(rot)
	
	# UV.y == 1.0 activa billboard esférico en shader
	# UV2 almacena el offset local 2D rotado
	# V0: ápice superior de la hoja
	var off0 := Vector2(0.0, hy)
	var r_off0 := Vector2(off0.x * c - off0.y * s, off0.x * s + off0.y * c)
	st.set_normal(Vector3.ZERO)
	st.set_uv(Vector2(0.5, 1.0))
	st.set_uv2(r_off0)
	st.set_color(col_blade)
	st.add_vertex(pos)
	
	# V1: base izquierda
	var off1 := Vector2(-hx, -hy * 0.45)
	var r_off1 := Vector2(off1.x * c - off1.y * s, off1.x * s + off1.y * c)
	st.set_normal(Vector3.ZERO)
	st.set_uv(Vector2(0.0, 1.0))
	st.set_uv2(r_off1)
	st.set_color(col_base)
	st.add_vertex(pos)
	
	# V2: base derecha
	var off2 := Vector2(hx, -hy * 0.45)
	var r_off2 := Vector2(off2.x * c - off2.y * s, off2.x * s + off2.y * c)
	st.set_normal(Vector3.ZERO)
	st.set_uv(Vector2(1.0, 1.0))
	st.set_uv2(r_off2)
	st.set_color(col_base)
	st.add_vertex(pos)

## Flor como Prisma Pentagonal 3D (LOD 1: pentágono base + pentágono copa = 15 tris con color puro fiel y estirado a escala 1:1)
static func _build_pentagon_prism_flower(st: SurfaceTool, pos: Vector3, up_dir: Vector3, radius: float, height: float, flower_color: Color) -> void:
	var up := up_dir.normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01:
		right = up.cross(Vector3.RIGHT).normalized()
	var fwd := right.cross(up).normalized()
	
	# Proporciones estiradas y robustas para calzar 1:1 con la rosa en Full HD
	var r_bot: float = radius * 0.55
	var r_top: float = radius * 1.00
	var p_bot: Vector3 = pos
	var p_top: Vector3 = pos + up * height
	
	var b_pts: Array[Vector3] = []
	var t_pts: Array[Vector3] = []
	
	for i in range(5):
		var a: float = (TAU / 5.0) * float(i)
		var dir := right * cos(a) + fwd * sin(a)
		b_pts.append(p_bot + dir * r_bot)
		t_pts.append(p_top + dir * r_top)
	
	# Cromatismo idéntico a las capas exteriores de LOD 0 (sin desaturar hacia rosa pálido/blanco)
	var sat_col: Color = flower_color
	if flower_color.r > flower_color.g and flower_color.r > flower_color.b and flower_color.v > 0.2:
		sat_col = Color(minf(flower_color.r * 1.12, 1.0), flower_color.g * 0.60, flower_color.b * 0.60)
	elif flower_color.r > 0.8 and flower_color.g > 0.7: # Amarillo dorado
		sat_col = Color(flower_color.r, flower_color.g, flower_color.b * 0.50)
	
	var col_base: Color = sat_col.darkened(0.40)   # Sombra aterciopelada en la base del cáliz
	var col_rim: Color = sat_col                   # Color puro y vibrante de la rosa
	var col_center: Color = sat_col.darkened(0.30) # Espiral profunda del centro del capullo
	
	# UV.y == 0.0 indica geometría 3D normal
	# 5 caras laterales (5 quads = 10 tris)
	for i in range(5):
		var next_i: int = (i + 1) % 5
		var b1 := b_pts[i]
		var b2 := b_pts[next_i]
		var t1 := t_pts[i]
		var t2 := t_pts[next_i]
		
		# Normal analítica outward de la cara lateral
		var face_mid := (b1 + b2) * 0.5
		var face_norm := ((face_mid - p_bot).normalized() + up * 0.15).normalized()
		
		# Triángulo 1: b1 (base) -> t1 (cresta) -> t2 (cresta)
		st.set_normal(face_norm)
		st.set_uv(Vector2(0.0, 0.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_base)
		st.add_vertex(b1)
		
		st.set_normal(face_norm)
		st.set_uv(Vector2(0.0, 0.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_rim)
		st.add_vertex(t1)
		
		st.set_normal(face_norm)
		st.set_uv(Vector2(0.0, 0.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_rim)
		st.add_vertex(t2)
		
		# Triángulo 2: b1 (base) -> t2 (cresta) -> b2 (base)
		st.set_normal(face_norm)
		st.set_uv(Vector2(0.0, 0.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_base)
		st.add_vertex(b1)
		
		st.set_normal(face_norm)
		st.set_uv(Vector2(0.0, 0.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_rim)
		st.add_vertex(t2)
		
		st.set_normal(face_norm)
		st.set_uv(Vector2(0.0, 0.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_base)
		st.add_vertex(b2)
	
	# Tapa superior en abanico cónico central (5 tris = 15 tris total)
	# Centro elevado con tono de espiral interior rodeado por pétalos de color pleno
	var p_center: Vector3 = p_top + up * (height * 0.18)
	for i in range(5):
		var next_i: int = (i + 1) % 5
		st.set_normal(up)
		st.set_uv(Vector2(0.0, 0.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_center)
		st.add_vertex(p_center)
		
		st.set_normal(up)
		st.set_uv(Vector2(0.0, 0.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_rim)
		st.add_vertex(t_pts[i])
		
		st.set_normal(up)
		st.set_uv(Vector2(0.0, 0.0))
		st.set_uv2(Vector2.ZERO)
		st.set_color(col_rim)
		st.add_vertex(t_pts[next_i])

## Flor como 1 solo triángulo 2D billboard en GPU (LOD 2 = 1 tri con silueta de copa y color puro 1:1)
static func _build_triangle_billboard_flower(st: SurfaceTool, pos: Vector3, radius: float, flower_color: Color) -> void:
	var top_y: float = radius * 0.95
	var top_x: float = radius * 1.05
	var bot_y: float = -radius * 0.50
	
	var sat_col: Color = flower_color
	if flower_color.r > flower_color.g and flower_color.r > flower_color.b and flower_color.v > 0.2:
		sat_col = Color(minf(flower_color.r * 1.12, 1.0), flower_color.g * 0.60, flower_color.b * 0.60)
	elif flower_color.r > 0.8 and flower_color.g > 0.7:
		sat_col = Color(flower_color.r, flower_color.g, flower_color.b * 0.50)
	
	var col_rim: Color = sat_col                   # Color puro y vibrante idéntico al original
	var col_base: Color = sat_col.darkened(0.40)   # Sombra en el cáliz
	
	# UV.y == 1.0 activa billboard esférico en shader
	# Silueta de copa floral (V0 arriba-izq con color puro, V1 arriba-der con color puro, V2 abajo en cáliz)
	st.set_normal(Vector3.ZERO)
	st.set_uv(Vector2(0.0, 1.0))
	st.set_uv2(Vector2(-top_x, top_y))
	st.set_color(col_rim)
	st.add_vertex(pos)
	
	st.set_normal(Vector3.ZERO)
	st.set_uv(Vector2(1.0, 1.0))
	st.set_uv2(Vector2(top_x, top_y))
	st.set_color(col_rim)
	st.add_vertex(pos)
	
	st.set_normal(Vector3.ZERO)
	st.set_uv(Vector2(0.5, 1.0))
	st.set_uv2(Vector2(0.0, bot_y))
	st.set_color(col_base)
	st.add_vertex(pos)

## Capullo cerrado de rosa como prisma/diamante de 4 lados en billboard 2D que siempre voltea al jugador (2 tris)
static func _build_bud_billboard_quad(st_flower: SurfaceTool, pos: Vector3, size: float, flower_color: Color) -> void:
	var bud_h: float = size * 1.55  # ~0.052m alto
	var bud_w: float = size * 0.95  # ~0.032m ancho en el vientre
	var base_y: float = -size * 0.15 # ~ -0.005m en la base
	
	var sat_col: Color = flower_color
	if flower_color.r > flower_color.g and flower_color.r > flower_color.b and flower_color.v > 0.2:
		sat_col = Color(minf(flower_color.r * 1.12, 1.0), flower_color.g * 0.60, flower_color.b * 0.60)
	
	# Color del capullo: punta suave más clara, cuerpo vivo, cáliz inferior sombreado
	var col_tip: Color = sat_col.lightened(0.18) if sat_col.v < 0.85 else sat_col
	var col_waist: Color = sat_col
	var col_base: Color = sat_col.darkened(0.40)
	
	# UV.y == 1.0 activa billboard esférico en shader (siempre voltea hacia el jugador/cámara)
	# 4 lados en silueta de diamante / prisma cerrado (2 triángulos):
	# V0: punta superior cerrada (0, bud_h)
	# V1: hombro izquierdo (-bud_w * 0.5, bud_h * 0.45)
	# V2: hombro derecho (bud_w * 0.5, bud_h * 0.45)
	# V3: base inferior en el cáliz (0, base_y)
	
	# Triángulo superior: V0 (punta), V1 (izq), V2 (der)
	st_flower.set_normal(Vector3.ZERO)
	st_flower.set_uv(Vector2(0.5, 1.0))
	st_flower.set_uv2(Vector2(0.0, bud_h))
	st_flower.set_color(col_tip)
	st_flower.add_vertex(pos)
	
	st_flower.set_normal(Vector3.ZERO)
	st_flower.set_uv(Vector2(0.0, 1.0))
	st_flower.set_uv2(Vector2(-bud_w * 0.5, bud_h * 0.45))
	st_flower.set_color(col_waist)
	st_flower.add_vertex(pos)
	
	st_flower.set_normal(Vector3.ZERO)
	st_flower.set_uv(Vector2(1.0, 1.0))
	st_flower.set_uv2(Vector2(bud_w * 0.5, bud_h * 0.45))
	st_flower.set_color(col_waist)
	st_flower.add_vertex(pos)
	
	# Triángulo inferior: V1 (izq), V3 (base), V2 (der)
	st_flower.set_normal(Vector3.ZERO)
	st_flower.set_uv(Vector2(0.0, 1.0))
	st_flower.set_uv2(Vector2(-bud_w * 0.5, bud_h * 0.45))
	st_flower.set_color(col_waist)
	st_flower.add_vertex(pos)
	
	st_flower.set_normal(Vector3.ZERO)
	st_flower.set_uv(Vector2(0.5, 1.0))
	st_flower.set_uv2(Vector2(0.0, base_y))
	st_flower.set_color(col_base)
	st_flower.add_vertex(pos)
	
	st_flower.set_normal(Vector3.ZERO)
	st_flower.set_uv(Vector2(1.0, 1.0))
	st_flower.set_uv2(Vector2(bud_w * 0.5, bud_h * 0.45))
	st_flower.set_color(col_waist)
	st_flower.add_vertex(pos)

## Capullo cerrado en LOD 2 como triángulo 2D billboard esbelto (1 tri)
static func _build_bud_billboard_triangle(st_flower: SurfaceTool, pos: Vector3, size: float, flower_color: Color) -> void:
	var bud_h: float = size * 1.50
	var bud_w: float = size * 0.75
	var sat_col: Color = flower_color
	if flower_color.r > flower_color.g and flower_color.r > flower_color.b and flower_color.v > 0.2:
		sat_col = Color(minf(flower_color.r * 1.12, 1.0), flower_color.g * 0.60, flower_color.b * 0.60)
	
	st_flower.set_normal(Vector3.ZERO)
	st_flower.set_uv(Vector2(0.5, 1.0))
	st_flower.set_uv2(Vector2(0.0, bud_h))
	st_flower.set_color(sat_col.lightened(0.15))
	st_flower.add_vertex(pos)
	
	st_flower.set_normal(Vector3.ZERO)
	st_flower.set_uv(Vector2(0.0, 1.0))
	st_flower.set_uv2(Vector2(-bud_w * 0.5, 0.0))
	st_flower.set_color(sat_col.darkened(0.35))
	st_flower.add_vertex(pos)
	
	st_flower.set_normal(Vector3.ZERO)
	st_flower.set_uv(Vector2(1.0, 1.0))
	st_flower.set_uv2(Vector2(bud_w * 0.5, 0.0))
	st_flower.set_color(sat_col.darkened(0.35))
	st_flower.add_vertex(pos)






