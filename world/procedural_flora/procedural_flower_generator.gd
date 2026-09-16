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

static func generate_flower(profile_id: String, seed_val: int, growth: float, color_idx: int = -1) -> GenerationResult:
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
	if growth <= stages["sprout_end"]:
		var t := growth / maxf(stages["sprout_end"], 0.01)
		current_height = lerpf(0.03, target_height * 0.12, t)
	elif growth <= stages["veg_end"]:
		var t := (growth - stages["sprout_end"]) / (stages["veg_end"] - stages["sprout_end"])
		current_height = lerpf(target_height * 0.12, target_height * 0.85, t)
	else:
		var t := (growth - stages["veg_end"]) / (1.0 - stages["veg_end"])
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
	
	# Generar mallas combinadas
	var mesh := ArrayMesh.new()
	st_veg.generate_normals()
	var veg_array = st_veg.commit_to_arrays()
	if veg_array.size() > 0 and (veg_array[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, veg_array)
	
	st_flower.generate_normals()
	var flower_array = st_flower.commit_to_arrays()
	if flower_array.size() > 0 and (flower_array[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flower_array)
	
	result.mesh = mesh
	return result

# ==============================================================================
# MORFOLOGÍAS BOTÁNICAS
# ==============================================================================

## 1. ARBUSTO DE ROSAS (Shrub): Ramas leñosas, espinas, múltiples rosas a distintas alturas
static func _generate_shrub(st_veg: SurfaceTool, st_flower: SurfaceTool, profile: Dictionary, rng: RandomNumberGenerator, height: float, growth: float, stages: Dictionary, flower_color: Color, result: GenerationResult) -> void:
	if growth <= stages["sprout_end"]:
		_build_sprout(st_veg, height, profile)
		return
	
	var num_canes: int = rng.randi_range(3, 5) # 3 a 5 cañas leñosas principales
	var total_flowers := 0
	
	for i in range(num_canes):
		var cane_angle: float = (TAU / float(num_canes)) * float(i) + rng.randf_range(-0.3, 0.3)
		var cane_h: float = height * rng.randf_range(0.75, 1.0)
		var cane_radius: float = profile["stem_radius"] * rng.randf_range(0.85, 1.15)
		
		# Curva arqueda natural de las ramas de rosal
		var spread_dist: float = cane_h * 0.35
		var tip_pos := Vector3(
			cos(cane_angle) * spread_dist,
			cane_h,
			sin(cane_angle) * spread_dist
		)
		
		var mid_pos := Vector3(
			cos(cane_angle) * (spread_dist * 0.4),
			cane_h * 0.55,
			sin(cane_angle) * (spread_dist * 0.4)
		)
		
		# Tallo leñoso arqueado
		_build_curved_stem(st_veg, [Vector3.ZERO, mid_pos, tip_pos], cane_radius, profile["stem_woody_color"], profile["stem_color"])
		
		# Espinas a lo largo de la caña
		if profile["has_thorns"] and growth > stages["veg_end"] * 0.7:
			_build_thorns(st_veg, [Vector3.ZERO, mid_pos, tip_pos], cane_radius, profile["thorn_color"], rng)
		
		# Hojas compuestas de rosal (grupos de 3-5 foliolos)
		_build_leaves_along_curve(st_veg, [Vector3.ZERO, mid_pos, tip_pos], profile["leaf_size"], profile["leaf_color"], rng, 4, growth)
		
		# Flor o capullo en la punta de cada caña
		if growth > stages["veg_end"]:
			_build_flower_head(st_flower, tip_pos, Vector3.UP.rotated(Vector3(sin(cane_angle), 0, -cos(cane_angle)), 0.35), profile, rng, growth, stages, flower_color)
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
	
	# Hojas lobuladas a lo largo de la parte baja
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

## Tallo cilíndrico suave continuo a lo largo de una spline de puntos
static func _build_curved_stem(st: SurfaceTool, points: Array, radius: float, base_color: Color, tip_color: Color) -> void:
	if points.size() < 2:
		return
	
	var sides: int = 5 # Cilindro de 5 caras (ultraligero y suficiente para tallos finos)
	var ring_angles: Array[float] = []
	for i in range(sides):
		ring_angles.append((TAU / float(sides)) * float(i))
	
	var prev_ring: Array[Vector3] = []
	
	for p_idx in range(points.size()):
		var pt: Vector3 = points[p_idx]
		var t: float = float(p_idx) / float(points.size() - 1)
		var current_r: float = radius * lerpf(1.0, 0.65, t)
		var seg_color: Color = base_color.lerp(tip_color, t)
		
		# Calcular orientación del anillo perpendicular a la dirección
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
			# Unir con quads (2 triángulos por lado)
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

## Hoja con pliegue en V (3D orgánica en lugar de plano plano)
static func _build_creased_leaf(st: SurfaceTool, base_pos: Vector3, direction: Vector3, length: float, width: float, color: Color) -> void:
	var fwd: Vector3 = direction.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = fwd.cross(Vector3.RIGHT).normalized()
	var normal_up: Vector3 = right.cross(fwd).normalized()
	
	# Vértices de la hoja
	var v_base: Vector3 = base_pos
	var v_tip: Vector3 = base_pos + fwd * length
	var mid_dist: float = length * 0.45
	var v_mid: Vector3 = base_pos + fwd * mid_dist
	
	# Alas izquierda y derecha dobladas hacia arriba formando un nervio central en V
	var fold_lift: float = width * 0.22
	var v_left: Vector3 = v_mid - right * (width * 0.5) + normal_up * fold_lift
	var v_right: Vector3 = v_mid + right * (width * 0.5) + normal_up * fold_lift
	
	st.set_color(color)
	
	# Ala izquierda
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(v_base)
	st.set_uv(Vector2(0.0, 0.5))
	st.add_vertex(v_left)
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(v_tip)
	
	# Ala derecha
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(v_base)
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(v_tip)
	st.set_uv(Vector2(1.0, 0.5))
	st.add_vertex(v_right)

## Distribuye hojas a lo largo de una curva de tallo
static func _build_leaves_along_curve(st: SurfaceTool, points: Array, leaf_sz: Vector2, color: Color, rng: RandomNumberGenerator, count: int, growth: float) -> void:
	if points.size() < 2:
		return
	var visible_count: int = int(float(count) * clampf(growth * 1.5, 0.3, 1.0))
	
	for i in range(visible_count):
		var t: float = float(i + 1) / float(count + 1) * 0.75 + 0.1
		var p_idx: int = int(t * float(points.size() - 1))
		var pt: Vector3 = points[clampi(p_idx, 0, points.size() - 1)]
		
		var angle: float = float(i) * 2.1 + rng.randf_range(-0.3, 0.3)
		var leaf_dir := Vector3(cos(angle), 0.35, sin(angle)).normalized()
		var l: float = leaf_sz.x * rng.randf_range(0.85, 1.15) * clampf(growth, 0.4, 1.0)
		var w: float = leaf_sz.y * rng.randf_range(0.85, 1.15) * clampf(growth, 0.4, 1.0)
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
			
			# Curvatura del pétalo hacia afuera y arriba
			var p_base: Vector3 = pos + petal_dir * (center_r * 0.7)
			var p_tip: Vector3 = pos + (petal_dir * cos(l_spread) + up_dir * sin(l_spread)).normalized() * l_radius
			var p_mid: Vector3 = (p_base + p_tip) * 0.5 + up_dir * (radius * 0.08)
			
			var petal_w: float = (l_radius * 0.42)
			var side_dir: Vector3 = petal_dir.cross(up_dir).normalized()
			
			var p_left: Vector3 = p_mid - side_dir * (petal_w * 0.5)
			var p_right: Vector3 = p_mid + side_dir * (petal_w * 0.5)
			
			# Tinte de color suave (más oscuro en la base, brillante en la punta)
			var c_base: Color = flower_color.darkened(0.18)
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
