extends RefCounted
class_name ProceduralTreeGenerator

const ProceduralTreeProfiles = preload("res://world/procedural_trees/procedural_tree_profiles.gd")
## Motor de generacion procedural para arboles hiperoptimizados.
## Utiliza primitivas geometricas 3D reutilizables (troncos de cono/prismas hexagonales
## y hojas de 1 triangulo) ensambladas en buffers de MultiMeshInstance3D (GPU Instancing).
## Genera uniones continuas sin huecos, ramas firmemente ancladas y follaje adherido a los brotes.

# Cache de mallas primitivas compartidas en VRAM
static var _frustum_mesh: ArrayMesh = null
static var _leaf_mesh: ArrayMesh = null

# Factor de conicidad del tronco de cono maestro
const FRUSTUM_TOP_TAPER := 0.82


## Retorna la malla unitaria del tronco de cono / prisma hexagonal (sin tapas, normales correctas).
static func get_frustum_mesh() -> ArrayMesh:
	if _frustum_mesh != null:
		return _frustum_mesh
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var sides := 8
	var angle_step := TAU / float(sides)
	
	# Radio base = 1.0 en Y=0; radio superior = FRUSTUM_TOP_TAPER en Y=1.0
	for i in range(sides):
		var a0 := i * angle_step
		var a1 := (i + 1) * angle_step
		
		var b0 := Vector3(cos(a0), 0.0, sin(a0))
		var b1 := Vector3(cos(a1), 0.0, sin(a1))
		var t0 := Vector3(cos(a0) * FRUSTUM_TOP_TAPER, 1.0, sin(a0) * FRUSTUM_TOP_TAPER)
		var t1 := Vector3(cos(a1) * FRUSTUM_TOP_TAPER, 1.0, sin(a1) * FRUSTUM_TOP_TAPER)
		
		var u0 := float(i) / float(sides)
		var u1 := float(i + 1) / float(sides)
		
		# Cara lateral cuadrilateral (2 triangulos con normales hacia afuera)
		# Triangulo 1 (b0, b1, t0)
		var n1 := (b1 - b0).cross(t0 - b0).normalized()
		st.set_normal(n1)
		st.set_uv(Vector2(u0, 0.0))
		st.add_vertex(b0)
		st.set_normal(n1)
		st.set_uv(Vector2(u1, 0.0))
		st.add_vertex(b1)
		st.set_normal(n1)
		st.set_uv(Vector2(u0, 1.0))
		st.add_vertex(t0)
		
		# Triangulo 2 (b1, t1, t0)
		var n2 := (t1 - b1).cross(t0 - b1).normalized()
		st.set_normal(n2)
		st.set_uv(Vector2(u1, 0.0))
		st.add_vertex(b1)
		st.set_normal(n2)
		st.set_uv(Vector2(u1, 1.0))
		st.add_vertex(t1)
		st.set_normal(n2)
		st.set_uv(Vector2(u0, 1.0))
		st.add_vertex(t0)
	
	_frustum_mesh = st.commit()
	return _frustum_mesh


## Retorna la malla unitaria de hoja de 1 solo triangulo.
## La base del tallo se extiende hasta Y = -0.15 para que penetre dentro de la corteza
## de la ramita, y las UVs van de (0.5, 1.0) en la base a (0.5, 0.0) en la punta apical.
static func get_leaf_mesh() -> ArrayMesh:
	if _leaf_mesh != null:
		return _leaf_mesh
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Triangulo con base sumergida en Y=-0.15 para anclar el tallo dentro de la madera
	var v0 := Vector3(-0.5, -0.15, 0.0) # Base izquierda
	var v1 := Vector3(0.5, -0.15, 0.0)  # Base derecha
	var v2 := Vector3(0.0, 1.0, 0.0)    # Punta
	
	var normal := Vector3(0.0, 0.0, 1.0)
	
	# En Godot, V=1.0 es la base de la textura y V=0.0 es la punta superior
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(v0)
	
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(v1)
	
	st.set_normal(normal)
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(v2)
	
	_leaf_mesh = st.commit()
	return _leaf_mesh


## Estructura con los resultados de la generacion para todos los LODs.
class TreeGenerationResult:
	var seed_used: int = 0
	var profile: ProceduralTreeProfiles.TreeProfile = null
	
	var lod0_branches_count: int = 0
	var lod0_leaves_count: int = 0
	var lod1_branches_count: int = 0
	var lod1_leaves_count: int = 0
	var lod2_branches_count: int = 0
	var lod2_leaves_count: int = 0
	
	var mm_branches_lod0: MultiMesh = null
	var mm_leaves_lod0: MultiMesh = null
	var mm_branches_lod1: MultiMesh = null
	var mm_leaves_lod1: MultiMesh = null
	var mm_branches_lod2: MultiMesh = null
	var mm_leaves_lod2: MultiMesh = null


## Genera un arbol completo garantizando uniones continuas y follaje adherido.
static func generate_tree(profile: ProceduralTreeProfiles.TreeProfile, tree_seed: int) -> TreeGenerationResult:
	var res := TreeGenerationResult.new()
	res.seed_used = tree_seed
	res.profile = profile
	
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	
	var branches_lod0: Array[Transform3D] = []
	var branches_lod1: Array[Transform3D] = []
	var branches_lod2: Array[Transform3D] = []
	
	var branch_custom_lod0: Array[Color] = []
	var branch_custom_lod1: Array[Color] = []
	var branch_custom_lod2: Array[Color] = []
	
	var leaves_lod0: Array[Transform3D] = []
	var leaves_lod1: Array[Transform3D] = []
	var leaves_lod2: Array[Transform3D] = []
	
	var leaf_colors_lod0: Array[Color] = []
	var leaf_colors_lod1: Array[Color] = []
	var leaf_colors_lod2: Array[Color] = []
	
	# -------------------------------------------------------------
	# 1. TRONCO PRINCIPAL (Conos encadenados con solapamiento sin cortes)
	# -------------------------------------------------------------
	var total_height := rng.randf_range(profile.trunk_height_min, profile.trunk_height_max)
	var seg_count := profile.trunk_segments
	var base_seg_height := total_height / float(seg_count)
	
	# Puntos de anclaje a lo largo del tronco para las ramas
	var branch_attachment_nodes: Array[Dictionary] = []
	
	var current_pos := Vector3.ZERO
	var current_dir := Vector3.UP
	var current_radius := profile.trunk_radius_base
	var trunk_v_accum := 0.0
	var trunk_u_base := rng.randf()
	
	for i in range(seg_count):
		var height_ratio := float(i) / float(seg_count)
		
		# Solapamiento: el segmento penetra en el anterior para evitar cortes/huecos al inclinarse
		var overlap := current_radius * 0.40 if i > 0 else 0.0
		var seg_height := base_seg_height + overlap
		var seg_start_pos := current_pos - current_dir * overlap
		
		# Giro aleatorio del prisma para romper cualquier alineacion de caras
		var twist := rng.randf_range(0.0, TAU)
		var xform := _build_segment_transform(seg_start_pos, current_dir, current_radius, seg_height, twist)
		branches_lod0.append(xform)
		branches_lod1.append(xform)
		branches_lod2.append(xform) # El tronco siempre existe en todos los LODs
		
		# UV continuo vertical y desfase horizontal por instancia (rompe patron repetitivo)
		var seg_v_len := seg_height * 0.28
		var c_data := Color(trunk_u_base + rng.randf_range(-0.15, 0.15), trunk_v_accum, seg_v_len, 1.0)
		branch_custom_lod0.append(c_data)
		branch_custom_lod1.append(c_data)
		branch_custom_lod2.append(c_data)
		trunk_v_accum += seg_v_len
		
		# Guardar nodo para salida de ramas principales
		if height_ratio >= profile.branch_start_ratio:
			branch_attachment_nodes.append({
				"pos": current_pos + current_dir * (base_seg_height * 0.5),
				"dir": current_dir,
				"radius": current_radius * 0.90,
				"height_ratio": height_ratio
			})
		
		# Calcular la inclinacion del siguiente segmento (tangencial natural)
		var max_tilt := deg_to_rad(profile.trunk_max_tilt_deg)
		var tilt_axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
		if tilt_axis.length_squared() < 0.001:
			tilt_axis = Vector3.RIGHT
		
		var tilt_angle := rng.randf_range(-max_tilt, max_tilt)
		var next_dir := current_dir.rotated(tilt_axis, tilt_angle).normalized()
		# Mantener tendencia hacia arriba
		if next_dir.dot(Vector3.UP) < 0.70:
			next_dir = (next_dir + Vector3.UP * 0.5).normalized()
		
		# Avanzar posicion y radio superior
		current_pos += current_dir * base_seg_height
		current_dir = next_dir
		current_radius *= FRUSTUM_TOP_TAPER
	
	# -------------------------------------------------------------
	# 2. RAMIFICACION JERARQUICA: 3 NIVELES (RAMAS SOBRE RAMAS)
	# -------------------------------------------------------------
	var leaf_tips: Array[Dictionary] = []
	var num_primary := profile.branch_density
	
	for b_idx in range(num_primary):
		if branch_attachment_nodes.is_empty():
			break
		
		var node_t := float(b_idx) / float(num_primary)
		var node_idx := int(node_t * float(branch_attachment_nodes.size() - 1))
		var node: Dictionary = branch_attachment_nodes[node_idx]
		
		var h_ratio: float = node["height_ratio"]
		var trunk_n_pos: Vector3 = node["pos"]
		var trunk_n_rad: float = node["radius"]
		
		# Angulo horizontal aureo alrededor del tronco (filotaxis)
		var azimuth := float(b_idx) * 2.399963 + rng.randf_range(-0.25, 0.25)
		var radial_horiz := Vector3(cos(azimuth), 0.0, sin(azimuth)).normalized()
		
		# Anclaje profundo dentro del tronco
		var b_pos := trunk_n_pos + radial_horiz * (trunk_n_rad * 0.65)
		var elev_rad := deg_to_rad(profile.branch_elevation_deg + rng.randf_range(-6.0, 6.0))
		var b_dir := (radial_horiz * cos(elev_rad) + Vector3.UP * sin(elev_rad)).normalized()
		
		# Longitud y proporciones
		var length_factor := (1.0 - h_ratio * 0.50) * profile.branch_length_ratio
		var b_total_len := total_height * length_factor * rng.randf_range(0.85, 1.15)
		var b_seg_count := profile.branch_segments
		var b_seg_len := b_total_len / float(b_seg_count)
		var b_radius := trunk_n_rad * profile.branch_radius_ratio
		
		var is_major_branch := (b_idx % 2 == 0)
		
		# Puntos donde naceran ramas secundarias
		var secondary_spawn_points: Array[Dictionary] = []
		
		# Construir segmentos de la rama primaria (Nivel 1)
		var b_u_offset := rng.randf()
		var b_v_accum := rng.randf_range(0.0, 5.0)
		for s in range(b_seg_count):
			var s_overlap := b_radius * 0.35 if s > 0 else 0.0
			var s_height := b_seg_len + s_overlap
			var s_start := b_pos - b_dir * s_overlap
			
			var twist := rng.randf_range(0.0, TAU)
			var b_xform := _build_segment_transform(s_start, b_dir, b_radius, s_height, twist)
			branches_lod0.append(b_xform)
			
			var s_v_len := s_height * 0.32
			var b_custom := Color(b_u_offset, b_v_accum, s_v_len, 1.0)
			branch_custom_lod0.append(b_custom)
			
			if is_major_branch or s < 2:
				branches_lod1.append(b_xform)
				branch_custom_lod1.append(b_custom)
			if is_major_branch and s == 0:
				branches_lod2.append(b_xform)
				branch_custom_lod2.append(b_custom)
			
			b_v_accum += s_v_len
			b_pos += b_dir * b_seg_len
			b_radius *= FRUSTUM_TOP_TAPER
			
			# Curvatura por droop
			if profile.branch_droop > 0.0:
				var droop_step := profile.branch_droop * (float(s + 1) / float(b_seg_count)) * 0.30
				b_dir = (b_dir + Vector3.DOWN * droop_step).normalized()
			
			# Guardar punto para rama secundaria
			if s >= 1:
				secondary_spawn_points.append({
					"pos": b_pos,
					"dir": b_dir,
					"radius": b_radius,
					"side_sign": 1.0 if (s % 2 == 0) else -1.0
				})
				# Relleno de follaje en el cuerpo de la rama principal (elimina el esqueleto pelado)
				leaf_tips.append({
					"pos": b_pos - b_dir * (b_seg_len * 0.5),
					"dir": b_dir,
					"radius": b_radius,
					"height": b_pos.y
				})
		
		# La punta de la rama primaria recibe hojas
		leaf_tips.append({
			"pos": b_pos,
			"dir": b_dir,
			"radius": b_radius,
			"height": b_pos.y
		})
		
		# --- NIVEL 2: RAMAS SECUNDARIAS (Bifurcaciones laterales) ---
		var num_sec := profile.secondary_branches_per_branch
		for sec_i in range(num_sec):
			if secondary_spawn_points.is_empty():
				break
			var sp_node: Dictionary = secondary_spawn_points[sec_i % secondary_spawn_points.size()]
			var sp_pos: Vector3 = sp_node["pos"]
			var sp_dir: Vector3 = sp_node["dir"]
			var sp_rad: float = sp_node["radius"] * 0.70
			var side_sign: float = -1.0 if (sec_i % 2 == 1) else 1.0
			
			var side_vec := sp_dir.cross(Vector3.UP).normalized() * side_sign
			var sec_dir := (sp_dir * 0.50 + side_vec * 0.75 + Vector3.UP * 0.15).normalized()
			var sec_len := b_seg_len * 0.85
			var sec_pos := sp_pos - sp_dir * (sp_rad * 0.25) # Anclada dentro de la rama primaria
			
			# Puntos para brotes terciarios
			var twig_spawn_points: Array[Dictionary] = []
			var sec_u := rng.randf()
			var sec_v_accum := rng.randf_range(0.0, 5.0)
			
			for s2 in range(2):
				var s2_overlap := sp_rad * 0.30 if s2 > 0 else 0.0
				var s2_h := sec_len + s2_overlap
				var s2_start := sec_pos - sec_dir * s2_overlap
				
				var twist := rng.randf_range(0.0, TAU)
				var sec_xform := _build_segment_transform(s2_start, sec_dir, sp_rad, s2_h, twist)
				branches_lod0.append(sec_xform)
				
				var s2_v_len := s2_h * 0.38
				var sec_custom := Color(sec_u, sec_v_accum, s2_v_len, 1.0)
				branch_custom_lod0.append(sec_custom)
				
				if is_major_branch:
					branches_lod1.append(sec_xform)
					branch_custom_lod1.append(sec_custom)
				
				sec_v_accum += s2_v_len
				sec_pos += sec_dir * sec_len
				sp_rad *= FRUSTUM_TOP_TAPER
				
				twig_spawn_points.append({
					"pos": sec_pos,
					"dir": sec_dir,
					"radius": sp_rad,
					"side_sign": -side_sign if (s2 == 1) else side_sign
				})
				
				# Relleno de hojas a lo largo de las ramas secundarias
				leaf_tips.append({
					"pos": sec_pos - sec_dir * (sec_len * 0.4),
					"dir": sec_dir,
					"radius": sp_rad,
					"height": sec_pos.y
				})
			
			# Punta de la rama secundaria recibe hojas
			leaf_tips.append({
				"pos": sec_pos,
				"dir": sec_dir,
				"radius": sp_rad,
				"height": sec_pos.y
			})
			
			# --- NIVEL 3: BROTES TERCIARIOS (Twigs que rellenan el volumen exterior) ---
			var num_twigs := profile.twigs_per_secondary
			for tw_i in range(num_twigs):
				if twig_spawn_points.is_empty():
					break
				var tw_sp: Dictionary = twig_spawn_points[tw_i % twig_spawn_points.size()]
				var tw_pos: Vector3 = tw_sp["pos"]
				var tw_p_dir: Vector3 = tw_sp["dir"]
				var tw_rad: float = tw_sp["radius"] * 0.65
				var tw_side: float = float(tw_sp["side_sign"]) * (1.0 if tw_i == 0 else -1.0)
				
				var tw_side_vec := tw_p_dir.cross(Vector3.UP).normalized() * tw_side
				var tw_dir := (tw_p_dir * 0.50 + tw_side_vec * 0.70 + Vector3.UP * 0.20).normalized()
				var tw_len := sec_len * 0.75
				var tw_start := tw_pos - tw_p_dir * (tw_rad * 0.25)
				
				var twist := rng.randf_range(0.0, TAU)
				var tw_xform := _build_segment_transform(tw_start, tw_dir, tw_rad, tw_len, twist)
				branches_lod0.append(tw_xform)
				branch_custom_lod0.append(Color(rng.randf(), rng.randf_range(0.0, 5.0), tw_len * 0.45, 1.0))
				
				var twig_tip_pos := tw_start + tw_dir * tw_len
				leaf_tips.append({
					"pos": twig_tip_pos,
					"dir": tw_dir,
					"radius": tw_rad * FRUSTUM_TOP_TAPER,
					"height": twig_tip_pos.y
				})
	
	# Punta apical del tronco principal y copa superior
	leaf_tips.append({
		"pos": current_pos,
		"dir": current_dir,
		"radius": current_radius,
		"height": current_pos.y
	})
	leaf_tips.append({
		"pos": current_pos - current_dir * (base_seg_height * 0.35),
		"dir": current_dir,
		"radius": current_radius,
		"height": current_pos.y
	})
	
	# -------------------------------------------------------------
	# 3. GENERACION DE HOJAS REDISTRIBUIDAS POR TODA LA COPA
	# -------------------------------------------------------------
	if profile.has_leaves and profile.leaves_per_tip > 0:
		for tip in leaf_tips:
			var tip_pos: Vector3 = tip["pos"]
			var tip_dir: Vector3 = tip["dir"]
			var tip_rad: float = tip["radius"]
			var tip_h: float = tip["height"]
			
			var count_per_tip := profile.leaves_per_tip
			
			var ref_axis := Vector3.UP if absf(tip_dir.dot(Vector3.UP)) < 0.90 else Vector3.RIGHT
			var perp_u := tip_dir.cross(ref_axis).normalized()
			var perp_v := perp_u.cross(tip_dir).normalized()
			
			for l in range(count_per_tip):
				var leaf_ratio := float(l) / float(count_per_tip)
				var leaf_angle := leaf_ratio * TAU + rng.randf_range(-0.35, 0.35)
				var radial_leaf := (perp_u * cos(leaf_angle) + perp_v * sin(leaf_angle)).normalized()
				var roll := rng.randf_range(-PI, PI)
				var mirror_h := (rng.randf() < 0.5)
				var leaf_size_var := profile.leaf_size * rng.randf_range(0.85, 1.20)
				
				var leaf_xform: Transform3D
				
				if profile.leaf_conical_cluster:
					# Coniferas: agujas en capas cónicas alrededor del brote
					var dist_back := (1.0 - leaf_ratio) * profile.leaf_spread_radius
					var ring_r := (0.35 + leaf_ratio * 0.65) * profile.leaf_spread_radius * 0.40
					var l_base := tip_pos - tip_dir * dist_back + radial_leaf * (tip_rad * 0.5 + ring_r)
					var l_dir := (radial_leaf * 0.70 + tip_dir * 0.60 + Vector3.UP * 0.15).normalized()
					leaf_xform = _build_leaf_transform(l_base, l_dir, leaf_size_var, roll, mirror_h)
				elif profile.id == "weeping_willow":
					# Sauce lloron: frondas colgantes que caen hacia abajo
					var dist_back := rng.randf_range(0.0, profile.leaf_spread_radius * 0.70)
					var l_base := tip_pos - tip_dir * dist_back + radial_leaf * (tip_rad * 0.75)
					var l_dir := (Vector3.DOWN * 0.85 + radial_leaf * 0.25 + tip_dir * 0.15).normalized()
					leaf_xform = _build_leaf_transform(l_base, l_dir, leaf_size_var * 1.30, roll * 0.4, mirror_h)
				else:
					# Arboles de hoja ancha: abanicos orientados en abanico 3D
					var dist_back := rng.randf_range(0.0, profile.leaf_spread_radius * 0.50)
					var l_base := tip_pos - tip_dir * dist_back + radial_leaf * (tip_rad * 0.75)
					var l_dir := (radial_leaf * 0.75 + tip_dir * 0.35 + Vector3.UP * 0.20).normalized()
					leaf_xform = _build_leaf_transform(l_base, l_dir, leaf_size_var, roll, mirror_h)
				
				# Tonalidad y gradiente natural
				var height_norm := clampf(tip_h / total_height, 0.0, 1.0)
				var leaf_color := profile.leaf_color_primary.lerp(
					profile.leaf_color_secondary,
					clampf(height_norm * 0.7 + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
				)
				leaf_color = leaf_color.lightened(rng.randf_range(-0.05, 0.06))
				
				# --- LOD 0: 100% de hojas a escala normal ---
				leaves_lod0.append(leaf_xform)
				leaf_colors_lod0.append(leaf_color)
				
				# --- LOD 1: ~40% de hojas, escala 1.65x para tapar huecos a media distancia ---
				if l % 3 == 0 or l == 0:
					var xf_lod1 := leaf_xform
					xf_lod1.basis = xf_lod1.basis * 1.65
					leaves_lod1.append(xf_lod1)
					leaf_colors_lod1.append(leaf_color)
				
				# --- LOD 2: ~15% de hojas, escala 2.40x para siluetas lejanas ---
				if l % 7 == 0:
					var xf_lod2 := leaf_xform
					xf_lod2.basis = xf_lod2.basis * 2.40
					leaves_lod2.append(xf_lod2)
					leaf_colors_lod2.append(leaf_color)
	
	# Conteos de instancias
	res.lod0_branches_count = branches_lod0.size()
	res.lod0_leaves_count = leaves_lod0.size()
	res.lod1_branches_count = branches_lod1.size()
	res.lod1_leaves_count = leaves_lod1.size()
	res.lod2_branches_count = branches_lod2.size()
	res.lod2_leaves_count = leaves_lod2.size()
	
	# Construccion de los MultiMeshes en GPU
	var frustum := get_frustum_mesh()
	var leaf_m := get_leaf_mesh()
	
	res.mm_branches_lod0 = _build_multimesh(frustum, branches_lod0, [], branch_custom_lod0)
	res.mm_leaves_lod0 = _build_multimesh(leaf_m, leaves_lod0, leaf_colors_lod0)
	
	res.mm_branches_lod1 = _build_multimesh(frustum, branches_lod1, [], branch_custom_lod1)
	res.mm_leaves_lod1 = _build_multimesh(leaf_m, leaves_lod1, leaf_colors_lod1)
	
	res.mm_branches_lod2 = _build_multimesh(frustum, branches_lod2, [], branch_custom_lod2)
	res.mm_leaves_lod2 = _build_multimesh(leaf_m, leaves_lod2, leaf_colors_lod2)
	
	return res


## Construye un Transform3D ortonormal que alinea el eje Y local con `dir`,
## escalando X y Z al radio y Y a la altura, con un giro aleatorio `twist` alrededor de su eje.
static func _build_segment_transform(pos: Vector3, dir: Vector3, radius: float, height: float, twist: float = 0.0) -> Transform3D:
	var up := dir.normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.92 else Vector3.UP
	var right := up.cross(ref).normalized()
	var forward := right.cross(up).normalized()
	
	var basis := Basis(right * radius, up * height, forward * radius)
	if absf(twist) > 0.0001:
		basis = basis.rotated(up, twist)
	return Transform3D(basis, pos)


## Construye la transformacion de una hoja triangular con su base en `pos`,
## su punta a lo largo de `dir`, angulo `roll` en 3D y opcion de espejado horizontal.
static func _build_leaf_transform(pos: Vector3, dir: Vector3, size: float, roll: float = 0.0, mirror_h: bool = false) -> Transform3D:
	var up := dir.normalized()
	var ref := Vector3.UP if absf(up.dot(Vector3.UP)) < 0.90 else Vector3.RIGHT
	var right := up.cross(ref).normalized()
	var forward := right.cross(up).normalized()
	
	if mirror_h:
		right = -right
	
	var basis := Basis(right * size, up * size, forward * size)
	if absf(roll) > 0.001:
		basis = basis.rotated(up, roll)
	return Transform3D(basis, pos)


## Construye un recurso MultiMesh con matrices de transformacion, colores y custom_data por instancia.
static func _build_multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], custom_data: Array[Color] = []) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.use_custom_data = not custom_data.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors and i < colors.size():
			mm.set_instance_color(i, colors[i])
		if mm.use_custom_data and i < custom_data.size():
			mm.set_instance_custom_data(i, custom_data[i])
	
	return mm
